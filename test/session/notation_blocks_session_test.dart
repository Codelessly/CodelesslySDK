// The fast path with a design system's blocks: a session takes a screen
// written in the notation as a few block calls, with the host's own lines
// (the data contract's state) put before the answer, and its instructions
// list only the blocks asked for.
import 'dart:io';

import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

Future<api.DesignSystem> _skip() async {
  const dir = 'design_systems/skip';
  final problems = <String>[];
  final ds = await api.DesignSystem.load((ref) async {
    final f = File('$dir/$ref');
    return f.existsSync() ? f.readAsStringSync() : null;
  }, problems: problems);
  expect(problems, isEmpty);
  return ds;
}

const _contract = '''
state streak=4
state weeklyGoal=5
state sessionsThisWeek=3
state today={"name":"Intervals","rounds":8,"work":40,"rest":20,"minutes":8}
''';

const _answer = '''
Screen
  HeroSession "{today.name}" "{today.rounds} rounds" minutes:{today.minutes} cta:"Start" -> emit start_session
  Row gap:12
    StreakFlame "sessions in a row" "Keep going." count:{streak}
    ProgressGoal "This week" "Almost there." done:{sessionsThisWeek} goal:{weeklyGoal}
''';

void main() {
  test('blocks called by name arrive line by line, with the host\'s state before them', () async {
    final ds = await _skip();
    final session = UiSession(designSystem: ds);
    addTearDown(session.dispose);
    final perChunk = <int>[];
    // Nine characters at a time, as a model's answer arrives.
    Stream<String> chunks() async* {
      for (var i = 0; i < _answer.length; i += 9) {
        yield _answer.substring(i, i + 9 > _answer.length ? _answer.length : i + 9);
      }
    }

    final result = await session.applyNotation(chunks(), prelude: _contract, onOp: (p) => perChunk.add(1));
    expect(session.notationIssues, isEmpty);
    expect(result.errors, isEmpty, reason: '${result.errors}');
    final types = [for (final n in session.document.nodes.values) n.type];
    expect(types, containsAll(['Screen', 'HeroSession', 'StreakFlame', 'ProgressGoal']));
    expect(perChunk.length, greaterThan(3), reason: 'the blocks are applied as their lines complete, not at the end');
    // The host's state is the screen's: the model wrote none of it.
    final canvas = session.document.roots.first;
    final declared = {for (final v in api.LayoutLogic.fromJson(session.document.extra).variablesOf(canvas)) v.name: v.value};
    expect(declared['streak'], 4);
    expect((declared['today']! as Map)['minutes'], 8);
  });

  test('the instructions list only the blocks asked for, and are a fraction of the whole design system\'s', () async {
    final ds = await _skip();
    final session = UiSession(designSystem: ds);
    addTearDown(session.dispose);
    final all = session.notationInstructions();
    final some = session.notationInstructions(blocks: {'Screen', 'HeroSession', 'StreakFlame', 'ProgressGoal'});
    expect(some, contains('HeroSession'));
    expect(some, isNot(contains('RunHistoryList')));
    expect(some.length, lessThan(all.length ~/ 2));
  });
}
