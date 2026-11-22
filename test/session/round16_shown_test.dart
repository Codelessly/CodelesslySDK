// Round 16 (30 briefs through the Playground's assistant):
//
// * a list written under another list's row (a month's days, each with its
//   events) was said empty once per check although most days have events:
//   `list_empty` is said once for the list, and only when every copy of it
//   is empty;
// * Cards' SiteNav showed a "Sign in" nobody wrote.
import 'dart:convert';
import 'dart:io';

import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

/// Every text the view draws.
List<String> _texts(WidgetTester tester) {
  final out = <String>[];
  void visit(RenderObject o) {
    if (o is RenderParagraph) out.add(o.text.toPlainText());
    o.visitChildren(visit);
  }

  visit(tester.renderObject(find.byType(CodelesslyView)));
  return out;
}

void main() {
  group('list_empty for a list under another list\'s row', () {
    testWidgets('some rows have items: nothing is said', (tester) async {
      final found = await _shown(tester, '''
state days=[1,2,3,4]
state events=[{"day":2,"title":"Standup"},{"day":2,"title":"Lunch"},{"day":4,"title":"Review"}]
Page
  Section
    each d in days
      Column gap=4
        Text "Day {d}"
        each e in filter(events,x=>x.day==d)
          Text "{e.title}"
''');
      expect(found.where((f) => f.startsWith('list_empty')), isEmpty);
    });

    testWidgets('every row is empty: said once, for the list', (tester) async {
      final found = await _shown(tester, '''
state days=[1,2,3,4]
state events=[{"day":7,"title":"Standup"},{"day":8,"title":"Review"}]
Page
  Section
    each d in days
      Column gap=4
        Text "Day {d}"
        each e in filter(events,x=>x.day==d)
          Text "{e.title}"
''');
      final said = found.where((f) => f.startsWith('list_empty')).toList();
      expect(said, hasLength(1));
      expect(said.single, contains('is empty while events has 2'));
    });

    testWidgets('one list that is empty is still said', (tester) async {
      final found = await _shown(tester, '''
state events=[{"day":7,"title":"Standup"}]
Page
  Section
    Text "Today"
    each e in filter(events,x=>x.day==1)
      Text "{e.title}"
''');
      expect(found.where((f) => f.startsWith('list_empty')), hasLength(1));
    });
  });

  group('SiteNav', () {
    test('has no quiet action unless one is written', () {
      final json = jsonDecode(File('design_systems/cards/components/SiteNav.json').readAsStringSync()) as Map;
      final props = ((json['widget'] as Map)['props'] as List).cast<Map>();
      expect(props.firstWhere((p) => p['key'] == 'secondary')['default'], '');
    });

    testWidgets('written without secondary shows no "Sign in"; written with one shows it', (tester) async {
      expect(await _shown(tester, 'Page\n  SiteNav brand="Olive" links=["Menu","Visit"]\n  Section\n    Text "Dinner"\n'), isEmpty);
      expect(_texts(tester), isNot(contains('Sign in')));
      expect(_texts(tester), containsAll(['Olive', 'Menu', 'Visit']));
      await _shown(tester, 'Page\n  SiteNav brand="Olive" links=["Menu","Visit"] secondary="Sign in"\n  Section\n    Text "Dinner"\n');
      expect(_texts(tester), contains('Sign in'));
    });
  });
}
