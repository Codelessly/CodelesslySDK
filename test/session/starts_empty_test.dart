// What the view's own check says of a list that shows no items while the
// list it reads has some (`list_empty`): nothing when it is meant to start
// that way (it follows a selection that is empty now, it chooses an empty
// list itself, the UI has an empty state for it), and still what it said
// when a filter over values that are all there matches nothing. And which
// timers of a view are to end by themselves (`TreeReactions.hasEndingTimer`:
// what takes a picture waits for a figure that counts up, not for a clock).
import 'dart:io';

import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const String _state = '''
state clips=[{"id":1,"name":"Intro","day":1},{"id":2,"name":"Outro","day":2}]
state sel=[]
state picked=""
state saved=[]
state hidden=[]
state q=""
state today=5
''';

Future<UiSession> _show(WidgetTester tester, String notation) async {
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
  await tester.pump(const Duration(milliseconds: 100));
  expect(result.errors, isEmpty);
  return session;
}

Future<List<String>> _empties(WidgetTester tester, String each, {String more = ''}) async {
  final session = await _show(tester, '${_state}Page\n  Section\n    Text "Clips"\n    each c in $each\n      Text "{c.name}"\n$more');
  await tester.pump(const Duration(milliseconds: 500));
  return [
    for (final d in session.shownDiagnostics())
      if (d.code == 'list_empty') d.message,
  ];
}

bool _counting(WidgetTester tester) {
  bool? found;
  void visit(RenderObject o) {
    if (found != null) return;
    if (o is NodeBox) {
      final Object? reactions = o.tree.interactions;
      found = reactions is TreeReactions && reactions.hasEndingTimer;
      return;
    }
    o.visitChildren(visit);
  }

  visit(tester.renderObject(find.byType(CodelesslyView)));
  return found ?? false;
}

void main() {
  group('a list that starts empty on purpose is not reported', () {
    testWidgets('nothing is chosen yet: the first of a selection, a name picked, what is saved', (tester) async {
      expect(await _empties(tester, 'filter(clips,c=>c.id==first(sel))'), isEmpty);
      expect(await _empties(tester, 'filter(clips,c=>c.name==picked)'), isEmpty);
      expect(await _empties(tester, 'filter(clips,c=>contains(saved,c.id))'), isEmpty);
    });

    testWidgets('through a worked-out value that reads the selection', (tester) async {
      final session = await _show(tester, '${_state}state shown={filter(clips,c=>c.name==picked)}\nPage\n  Section\n    each c in shown\n      Text "{c.name}"\n');
      expect(session.shownDiagnostics().where((d) => d.code == 'list_empty'), isEmpty);
    });

    testWidgets('a condition with a literal [] branch (an empty search shows nothing)', (tester) async {
      expect(await _empties(tester, '(q=="" ? [] : filter(clips,c=>contains(c.name,q)))'), isEmpty);
    });

    testWidgets('the UI has an empty state for it', (tester) async {
      expect(await _empties(tester, 'filter(clips,c=>c.day==today)', more: '    if length(filter(clips,c=>c.day==today))==0\n      Text "Nothing today"\n'), isEmpty);
    });
  });

  group('still reported', () {
    testWidgets('a filter over values that are all there, which matches nothing', (tester) async {
      final found = await _empties(tester, 'filter(clips,c=>c.day==today)');
      expect(found, [allOf(contains('is empty while clips has 2'), contains('through a lambda'))]);
    });

    testWidgets('what is left out being empty is no reason for a list to be', (tester) async {
      expect(await _empties(tester, 'filter(clips,c=>c.day==today && !contains(hidden,c.name))'), hasLength(1));
    });

    testWidgets('an empty search that is to show everything, and shows nothing', (tester) async {
      expect(await _empties(tester, 'filter(clips,c=>q=="" && c.day==today)'), hasLength(1));
    });
  });

  group('a timer that is to end by itself', () {
    testWidgets('is one whose condition holds, until it no longer does; a clock is not one', (tester) async {
      final session = await _show(tester, 'state tick=0\nevery 40 when tick<5 onTick={tick=tick+1}\nPage\n  Section\n    Text "{tick}"\n');
      expect(_counting(tester), isTrue);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(session.values['tick'], 5);
      expect(_counting(tester), isFalse);
    });

    testWidgets('a timer with no condition runs for as long as the screen shows', (tester) async {
      await _show(tester, 'state s=0\nevery 1s onTick={s=s+1}\nPage\n  Section\n    Text "{s}"\n');
      expect(_counting(tester), isFalse);
      // Beside one that ends, the clock decides: there is no end to wait for.
      await _show(tester, 'state s=0\nstate tick=0\nevery 1s onTick={s=s+1}\nevery 40 when tick<5 onTick={tick=tick+1}\nPage\n  Section\n    Text "{s} {tick}"\n');
      expect(_counting(tester), isFalse);
    });
  });
}
