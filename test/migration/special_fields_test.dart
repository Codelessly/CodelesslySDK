// The last special-case fields left the model for general mechanisms
// (codelessly_api's steps_special.dart): a slider's ruler, marker, track fade
// and grip are its custom paint, a text field's highlight is its runs, a
// table's row edge is its cell template's selected style, a date/time
// input's displayFormat is its format, a text's countUp is a transition and
// an animation of its text. Each case draws what the migration makes of a
// node that used them and matches what 30.1.0's renderer drew: the goldens
// (goldens/special-*.png) and the recorded texts were taken with it, from
// the same nodes (special_fields_cases.dart). The slider cases' goldens
// (ruler-defaults, marker, grip, fade) were taken again when the slider
// became a render object with SSUI's look (Milestone 3): their custom paint
// is still drawn between its parts (test/controls/slider_test.dart), over
// SSUI's track and thumb instead of Material's.

import 'package:codelessly_api/codelessly_api.dart' show Json, LayoutDocument, migrate2to3, readMap;
import 'package:codelessly_api/src/core/migrate/steps_spellings.dart' show spellingMigrationSteps;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'special_fields_cases.dart';

/// [nodes] (30.1.0's spellings) as the one-way steps rewrite them.
Map<String, Json> _migrated(Map<String, Json> nodes) {
  final doc = migrate2to3({
    'schema': 2,
    'nodes': nodes,
  }, steps: spellingMigrationSteps);
  return {for (final id in nodes.keys) id: readMap(readMap(doc['nodes'])![id])!};
}

Iterable<RenderObject> _all(RenderObject o) sync* {
  yield o;
  final kids = <RenderObject>[];
  o.visitChildren(kids.add);
  for (final k in kids) {
    yield* _all(k);
  }
}

/// What a count showed with 30.1.0's countUp, frame by frame: its first
/// frame, ten frames 50 ms apart, the frame a new value arrives, ten more.
const _counted = {
  'linear': [
    r'$0.00', r'$150.56', r'$301.13', r'$451.69', r'$602.25', r'$752.81', r'$903.38', r'$1,053.94', r'$1,204.50', //
    r'$1,204.50', r'$1,204.50', r'$1,204.50', r'$1,303.94', r'$1,403.38', r'$1,502.81', r'$1,602.25', r'$1,701.69',
    r'$1,801.13', r'$1,900.56', r'$2,000.00', r'$2,000.00', r'$2,000.00',
  ],
  'eased': [
    '0%', '29%', '52%', '67%', '76%', '82%', '85%', '87%', '87%', '87%', '87%', //
    '87%', '62%', '42%', '29%', '21%', '17%', '14%', '12%', '12%', '12%', '12%',
  ],
  'no-show': [
    '1,204', '1,204', '1,204', '1,204', '1,204', '1,204', '1,204', '1,204', '1,204', '1,204', '1,204', //
    '1,204', '1,470', '1,736', '2,002', '2,269', '2,535', '2,801', '3,067', '3,333', '3,333', '3,333',
  ],
};

void main() {
  group('a migrated node draws what the special-case field drew', () {
    for (final e in specialCases.entries) {
      testWidgets('${e.key}: the same pixels', (tester) async {
        final migrated = _migrated(e.value.$1);
        expect(migrated, isNot(e.value.$1), reason: 'the migration rewrote it');
        await drawCase(tester, migrated, e.value.$2, golden: 'special-${e.key}');
      });
    }
  });

  group('a text that counted up counts the same frames as a transition and an animation', () {
    for (final (name, text, onShow, curve) in [
      ('linear', r'$1,204.50', true, 'linear'),
      ('eased', '87%', true, 'easeOutCubic'),
      ('no-show', '1,204', false, 'linear'),
    ]) {
      testWidgets('$name: the same text in every frame', (tester) async {
        final node = _migrated({'t': countUpText(text, onShow: onShow, curve: curve)})['t']!;
        expect(node['transitions'], isNotEmpty);
        final vars = VariableScope([textVariable(text)]);
        final tree = NodeTree(
          DocumentSource(LayoutDocument.fromJson({
            'roots': ['t'],
            'nodes': {'t': node},
          })),
          binder: NodeBinder(scope: vars),
          environment: const IslandEnvironment(interactive: true),
        );
        addTearDown(vars.dispose);
        addTearDown(tree.dispose);
        await tester.pumpWidget(
            MaterialApp(home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 't', interactive: true))));
        String shown() => _all(tree.boxOf('t')!).whereType<RenderParagraph>().map((p) => p.text.toPlainText()).join('|');
        final seen = <String>[shown()];
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 50));
          seen.add(shown());
        }
        vars.set('n', text.replaceAll('1,204.50', '2,000.00').replaceAll('87%', '12%').replaceAll('1,204', '3,333'));
        await tester.pump();
        seen.add(shown());
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 50));
          seen.add(shown());
        }
        expect(seen, _counted[name]);
        await tester.pumpWidget(const SizedBox());
      });
    }

    testWidgets('a design canvas shows the final text', (tester) async {
      final node = _migrated({'t': countUpText('1,204')})['t']!;
      final vars = VariableScope([textVariable('1,204')]);
      final tree = NodeTree(DocumentSource(LayoutDocument.fromJson({
        'roots': ['t'],
        'nodes': {'t': node},
      })), binder: NodeBinder(scope: vars));
      addTearDown(vars.dispose);
      addTearDown(tree.dispose);
      await tester.pumpWidget(MaterialApp(home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 't'))));
      String shown() => _all(tree.boxOf('t')!).whereType<RenderParagraph>().single.text.toPlainText();
      expect(shown(), '1,204');
      vars.set('n', '9');
      await tester.pump();
      expect(shown(), '9');
    });
  });

  group('a date/time input\'s displayFormat reads the same as its format', () {
    // As 30.1.0 showed each (its formatDate), recorded.
    for (final (mode, value, format, shown) in [
      ('date', '2026-03-05', 'EEE, MMM d', 'Thu, Mar 5'),
      ('time', '13:05', 'h:mm a', '1:05 PM'),
      ('dateTime', '2026-03-05T13:05', 'EEE, MMM d · h:mm a', 'Thu, Mar 5 · 1:05 PM'),
      ('date', '2026-03-05', 'd MMMM yyyy', '5 March 2026'),
    ]) {
      testWidgets('$mode "$format": $shown', (tester) async {
        final node = _migrated({
          'd': {'type': 'dateTimeInput', 'layout': {'width': 280, 'height': 56}, 'props': {'mode': mode, 'value': value, 'displayFormat': format}},
        })['d']!;
        expect(node['props'], {'mode': mode, 'value': value, 'format': format});
        final tree = NodeTree(
          DocumentSource(LayoutDocument.fromJson({
            'roots': ['d'],
            'nodes': {'d': node},
          })),
          environment: const IslandEnvironment(interactive: true),
        );
        addTearDown(tree.dispose);
        await tester.pumpWidget(
            MaterialApp(home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'd', interactive: true))));
        await tester.pumpAndSettle();
        final texts = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? t.textSpan?.toPlainText()).toList();
        expect(texts.first, shown);
        await tester.pumpWidget(const SizedBox());
      });
    }
  });
}
