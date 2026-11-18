// What the view's own check must not say of a UI that is right: each case
// was reported on a reviewed page of examples/showcase, and a model told of
// it rewrote what was correct. The last group is what must still be said.
import 'dart:io';

import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<List<String>> _shown(WidgetTester tester, String notation) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1280, 800);
  addTearDown(tester.view.reset);
  final problems = <String>[];
  final ds = await tester.runAsync(() => api.DesignSystem.load((ref) async {
        final file = File('design_systems/cards/$ref');
        return file.existsSync() ? file.readAsStringSync() : null;
      }, problems: problems));
  expect(problems, isEmpty);
  final session = UiSession(designSystem: ds);
  addTearDown(session.dispose);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: CodelesslyView(session: session))));
  final result = await session.applyNotation(Stream.value(notation));
  await tester.pump(const Duration(milliseconds: 600));
  expect(result.errors, isEmpty);
  return [for (final d in session.shownDiagnostics()) '${d.code}: ${d.message}'];
}

void main() {
  group('not reported', () {
    testWidgets('a block that draws with a painter (Media), alone or in a grid', (tester) async {
      expect(await _shown(tester, 'Page\n  Section\n    Media kind="harbor"\n'), isEmpty);
      expect(await _shown(tester, 'Page\n  Section\n    Grid cols=2\n      Media kind="shoe"\n      Media kind="dunes" tone="dusk"\n'), isEmpty);
    });

    testWidgets('a block that only wraps what is put in it (WideScroll)', (tester) async {
      expect(await _shown(tester, 'Page\n  Section\n    WideScroll\n      Text "inside"\n'), isEmpty);
    });

    testWidgets('rows an if leaves out, a list with no items, a text whose value is empty', (tester) async {
      expect(
          await _shown(tester, '''
state tasks=[{"t":"A","col":"Done","time":"","tags":[]},{"t":"B","col":"Todo","time":"2 s","tags":["x"]}]
Page
  Section
    each t in tasks
      if t.col=="Todo"
        Row gap=8
          Text "{t.t}" grow
          Text "{t.time}"
    each t in tasks
      Row gap=8
        Text "{t.t}"
        Text "{t.time}"
        each g in t.tags
          Text "{g}"
'''),
          isEmpty);
    });

    testWidgets('a value that is empty on purpose, and one beside another with no text between', (tester) async {
      expect(
          await _shown(tester, '''
state sel=""
state batters=[{"name":"Priya Nair","on":true},{"name":"Asha Verma","on":false}]
Page
  Section
    Text "Picked: {sel}"
    each b in batters
      Text "{b.name}{b.on ? ' *' : ''}"
'''),
          isEmpty);
    });

    testWidgets('words the data has that read like a failed value', (tester) async {
      expect(
          await _shown(tester, '''
state log="ERROR null check failed"
state runs=[{"name":"add_not_null_to_orders_status"}]
Page
  Section
    Text "{log}"
    each r in runs
      Text "{r.name}"
'''),
          isEmpty);
    });
  });

  group('still reported', () {
    testWidgets('a page with nothing showing', (tester) async {
      expect(await _shown(tester, 'Page\n  Section\n    Badge ""\n'), contains(startsWith('empty_view')));
    });

    testWidgets('a value that reads a field the data does not have', (tester) async {
      final found = await _shown(tester, 'state plan={"name":"Pro"}\nPage\n  Section\n    Text "Total: {plan.price} a month"\n');
      expect(found, [startsWith('value_not_computed')]);
    });

    testWidgets('a text with content squeezed to no width', (tester) async {
      final found = await _shown(tester, 'Page\n  Section\n    Row\n      Box w=0\n        Text "Squeezed"\n');
      expect(found.where((f) => f.startsWith('no_size')), isNotEmpty);
    });
  });
}
