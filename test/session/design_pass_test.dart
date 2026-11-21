// The design pass: a design agent restyles the session's UI in place with
// edit operations; what it says and does must stay, and an answer that
// breaks that (or is rejected) is undone and asked for again.
import 'dart:convert';
import 'dart:io';

import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

Future<api.DesignSystem> _cards() async {
  final ds = await api.DesignSystem.load((ref) async {
    final f = File('design_systems/cards/$ref');
    return f.existsSync() ? f.readAsStringSync() : null;
  });
  return ds;
}

const _card = '''
state count=1
Card
  Text#title "Seats"
  Row#row
    Button#less "-" onTap={count=count-1}
    Text#n "{count}"
    Button#more "+" onTap={count=count+1}
''';

const _good = [
  {
    'op': 'patch',
    'id': 'row',
    'patch': {
      'props': {'spacing': 12},
      'decoration': {
        'fills': [
          {'color': 'tile'},
        ],
      },
      'bind': {'decoration.radius': r'${theme.radii.tile}'},
    },
  },
  {
    'op': 'patch',
    'id': 'title',
    'patch': {
      'props': {
        'style': {'from': 'title'},
      },
    },
  },
];

void main() {
  test('the instructions hold the principles, the theme names, the operations and the UI', () async {
    final session = UiSession(designSystem: await _cards());
    addTearDown(session.dispose);
    await session.applyNotation(Stream.value(_card));
    final text = DesignPass(session, design: (_) async => null).instructions(request: 'pick seats');
    expect(text, contains('art director of the "${session.designSystem!.name}"'));
    expect(text, contains(session.designSystem!.design.trim().split('\n').first));
    expect(text, contains('accentTint'));
    expect(text, contains(r'"bind": {"decoration.radius": "${theme.radii.name}"}'));
    for (final spec in api.EditOp.specs) {
      expect(text, contains('${spec.op}: '));
    }
    expect(text, contains('"title"'));
    expect(text, contains('WHAT THE USER ASKED FOR\npick seats'));
  });

  test('an answer that changes what the UI says is undone; the corrected one is kept as one undo step', () async {
    final session = UiSession(designSystem: await _cards());
    addTearDown(session.dispose);
    await session.applyNotation(Stream.value(_card));
    final plain = jsonEncode(session.document.toJson());
    final rounds = <DesignRequest>[];
    final pass = DesignPass(session, design: (request) async {
      rounds.add(request);
      if (request.round == 1) {
        expect(jsonEncode(session.document.toJson()), plain);
        return '''Tightening the header.
```json
{"ops": [{"op": "patch", "id": "title", "patch": {"props": {"text": "Choose seats"}}}, {"op": "remove", "id": "more"}]}
```''';
      }
      // Asked again on the UI as it was, with what was wrong.
      expect(jsonEncode(session.document.toJson()), plain);
      return {'ops': _good};
    });
    final outcome = await pass.run();
    expect(outcome.kept, isTrue);
    expect(outcome.rounds, 2);
    expect(outcome.ops, 2);
    expect(rounds[1].problems.join('\n'), allOf(contains('"title" no longer says what it said'), contains('"more" (filledButton) is gone')));
    final after = session.document.toJson()['nodes'] as Map;
    expect(((after['row'] as Map)['decoration'] as Map)['fills'], isNotEmpty);
    expect(((after['title'] as Map)['props'] as Map)['text'], 'Seats');
    expect(DesignPass.changedMeaning(api.LayoutDocument.fromJson(jsonDecode(plain) as Map<String, Object?>, catalog: session.catalog), session.document),
        isEmpty);
    // One step puts the plain card back.
    expect(session.undo(author: DesignPass.author), isTrue);
    expect(jsonEncode(session.document.toJson()), plain);
  });

  test('a rejected operation, or a host check that fails every round, leaves the UI as it was', () async {
    final session = UiSession(designSystem: await _cards());
    addTearDown(session.dispose);
    await session.applyNotation(Stream.value(_card));
    final plain = jsonEncode(session.document.toJson());
    final rejected = await DesignPass(session, design: (_) async => [
          {'op': 'patch', 'id': 'nobody', 'patch': {'props': {'spacing': 4}}},
        ]).run();
    expect(rejected.kept, isFalse);
    expect(rejected.problems.single, contains('Operation 1 was rejected'));
    expect(jsonEncode(session.document.toJson()), plain);

    var checks = 0;
    final refused = await DesignPass(session, design: (_) async => _good, check: () {
      checks++;
      return ['content_overflows at /nodes/row'];
    }).run();
    expect(refused.kept, isFalse);
    expect(checks, 2);
    expect(refused.problems, ['content_overflows at /nodes/row']);
    expect(jsonEncode(session.document.toJson()), plain);
  });

  group('with blocks', () {
    const card = '''
state note="Ready at the desk"
Card
  Text#title "Lab kit ready"
  Text#where "{note}"
  Button#go "I'll pick it up" onTap={emit collect}
''';

    // The plain button and the title's text go; an ActionButton and a
    // SectionLabel carry what they said and did.
    List<Object?> swap(UiSession session, {String label = "I'll pick it up", bool actions = true, bool title = false}) {
      final nodes = session.document.toJson()['nodes'] as Map;
      final parent = nodes.entries.firstWhere((e) => ((e.value as Map)['children'] as List? ?? const []).contains('go')).key;
      final reactions = (nodes['go'] as Map)['actions'] as List;
      return [
        {
          'op': 'set',
          'id': 'goBlock',
          'parent': parent,
          'node': {
            'type': 'ActionButton',
            'props': {'label': label, 'tone': 'primary'},
            'layout': {'width': {'fill': 0}, 'height': 46},
            if (actions)
              'actions': [
                {
                  'trigger': {'type': 'event', 'event': 'onPressed'},
                  'actions': (reactions.first as Map)['actions'],
                },
              ],
          },
        },
        {'op': 'remove', 'id': 'go'},
        if (title) {'op': 'remove', 'id': 'where'},
      ];
    }

    test('the instructions list the blocks with their sizes and show the closest as written', () async {
      final session = UiSession(designSystem: await _cards());
      addTearDown(session.dispose);
      await session.applyNotation(Stream.value(card));
      final plain = DesignPass(session, design: (_) async => null).instructions();
      expect(plain, isNot(contains("THE SYSTEM'S BLOCKS")));
      final text = DesignPass(session, design: (_) async => null, blocks: const ['ActionButton', 'TotalBar', 'Receipt', 'NoSuchBlock'])
          .instructions(request: 'a button that confirms');
      expect(text, contains("THE SYSTEM'S BLOCKS"));
      expect(text, contains('ActionButton: '));
      expect(text, contains('layout: {"width":{"fill":0},"height":46}'));
      expect(text, contains('events: onPressed'));
      expect(text, contains('unless a block takes its place and carries what it said and did'));
      expect(text, contains('THE CLOSEST BLOCKS, AS WRITTEN'));
      expect(text, isNot(contains('NoSuchBlock')));
    });

    test('a block that carries a removed node\'s label and actions is kept', () async {
      final session = UiSession(designSystem: await _cards());
      addTearDown(session.dispose);
      await session.applyNotation(Stream.value(card));
      final plain = jsonEncode(session.document.toJson());
      final outcome = await DesignPass(session, design: (_) async => swap(session), blocks: const ['ActionButton']).run();
      expect(outcome.problems, isEmpty);
      expect(outcome.kept, isTrue);
      final nodes = session.document.toJson()['nodes'] as Map;
      expect(nodes.containsKey('go'), isFalse);
      expect((nodes['goBlock'] as Map)['type'], 'ActionButton');
      expect(session.undo(author: DesignPass.author), isTrue);
      expect(jsonEncode(session.document.toJson()), plain);
    });

    test('without blocks the same answer is refused: a node that takes input is gone', () async {
      final session = UiSession(designSystem: await _cards());
      addTearDown(session.dispose);
      await session.applyNotation(Stream.value(card));
      final outcome = await DesignPass(session, design: (_) async => swap(session), maxRounds: 1).run();
      expect(outcome.kept, isFalse);
      expect(outcome.problems.join('\n'), contains('"go" (filledButton) is gone'));
    });

    test('a block that drops the label, the actions or a bound text is refused, each named', () async {
      final session = UiSession(designSystem: await _cards());
      addTearDown(session.dispose);
      await session.applyNotation(Stream.value(card));
      final plain = jsonEncode(session.document.toJson());
      Future<DesignOutcome> run(List<Object?> ops) => DesignPass(session, design: (_) async => ops, blocks: const ['ActionButton'], maxRounds: 1).run();

      final relabeled = await run(swap(session, label: 'Collect'));
      expect(relabeled.kept, isFalse);
      expect(relabeled.problems.single, allOf(contains('"go" (filledButton) is gone and no block carries'), contains('its "label" ("I\'ll pick it up")')));
      expect(jsonEncode(session.document.toJson()), plain);

      final inert = await run(swap(session, actions: false));
      expect(inert.kept, isFalse);
      expect(inert.problems.single, contains('its actions'));

      // The text that reads {note} is removed and no block reads the same value.
      final unbound = await run(swap(session, title: true));
      expect(unbound.kept, isFalse);
      expect(unbound.problems.join('\n'), allOf(contains('"where" (text) is gone and no block carries'), contains(r'its "text" ("${note}")')));
      expect(jsonEncode(session.document.toJson()), plain);
    });

    test('a removed text whose value a block reads the same way is accepted', () async {
      final session = UiSession(designSystem: await _cards());
      addTearDown(session.dispose);
      await session.applyNotation(Stream.value(card));
      final before = session.document;
      final nodes = before.toJson()['nodes'] as Map;
      final parent = nodes.entries.firstWhere((e) => ((e.value as Map)['children'] as List? ?? const []).contains('where')).key;
      final result = session.apply([
        {
          'op': 'set',
          'id': 'whereBlock',
          'parent': parent,
          'node': {
            'type': 'Paragraph',
            'layout': {'width': {'fill': 0}, 'height': {'hug': 0}},
            'props': {'text': ((nodes['where'] as Map)['props'] as Map)['text']},
          },
        },
        {'op': 'remove', 'id': 'where'},
      ], author: DesignPass.author);
      expect(result.rejected, isEmpty, reason: '${result.diagnostics.map((d) => d.message)}');
      expect(DesignPass.changedMeaning(before, session.document, blocks: const {'Paragraph'}), isEmpty);
      expect(DesignPass.changedMeaning(before, session.document).single, contains('"where" (text) is gone'));
    });
  });

    test('a text a block shows in pieces is carried; a piece left out is named', () {
      api.LayoutDocument doc(Map<String, Object?> nodes) => api.LayoutDocument.fromJson({
            'schema': 3,
            'roots': ['c'],
            'nodes': {
              'c': {'type': 'canvas', 'children': nodes.keys.toList()},
              ...nodes,
            },
          });
      final before = doc({
        'times': {'type': 'text', 'props': {'text': '07:15 → 09:50'}},
        'air': {'type': 'text', 'props': {'text': r'${f.air} · Direct'}},
      });
      Map<String, Object?> option(Map<String, Object?> props) => {
            'opt': {'type': 'FlightOption', 'props': props},
          };
      final split = doc(option({'depart': '07:15', 'arrive': '09:50', 'name': r'${f.air}', 'stops': 'Direct'}));
      expect(DesignPass.changedMeaning(before, split, blocks: const {'FlightOption'}), isEmpty);
      final short = doc(option({'depart': '07:15', 'name': r'${f.air}', 'stops': 'Direct'}));
      expect(DesignPass.changedMeaning(before, short, blocks: const {'FlightOption'}).single,
          allOf(contains('"times" (text) is gone and no block carries'), contains('07:15 → 09:50')));
    });

  test('the operations are read from a list, a map, a fenced answer or a bare one', () {
    expect(DesignPass.opsOf(_good), hasLength(2));
    expect(DesignPass.opsOf({'ops': _good}), hasLength(2));
    expect(DesignPass.opsOf('Why.\n```json\n${jsonEncode({'ops': _good})}\n```\nDone.'), hasLength(2));
    expect(DesignPass.opsOf('Here: ${jsonEncode({'ops': _good})}'), hasLength(2));
    expect(DesignPass.opsOf('SHIP'), isNull);
  });

  group('reading an answer', () {
    final good = jsonEncode({'ops': _good});

    test('an answer cut off anywhere reads as cut off, and never throws', () {
      final whole = 'I tighten the row.\n```json\n$good\n```';
      for (var cut = 0; cut < whole.length; cut++) {
        final read = DesignPass.readAnswer(whole.substring(0, cut));
        expect(read.ops, isNull, reason: 'cut at $cut');
        expect(read.problem, isNotNull, reason: 'cut at $cut');
      }
      // Before any closing bracket (what threw a RangeError), and mid list.
      expect(DesignPass.readAnswer('Restyle.\n```json\n{"ops": [{"op": "patch", "id": "row", "pat').problem, contains('cut off at the output limit'));
      expect(DesignPass.opsOf('Restyle.\n```json\n{"ops": ['), isNull);
      // The host knows it stopped at the limit.
      expect(DesignPass.readAnswer(const DesignAnswer('I will tighten the', cutOff: true)).problem, contains('cut off at the output limit'));
      expect(DesignPass.readAnswer(DesignAnswer('Why.\n```json\n$good\n```')).ops, hasLength(2));
    });

    test('nothing to change: an empty list, {"ops": []}, null or NOTHING', () {
      for (final Object? answer in [null, const <Object?>[], {'ops': const <Object?>[]}, 'It sits at the bar already.\n```json\n{"ops": []}\n```', 'It is fine.\nNOTHING']) {
        final read = DesignPass.readAnswer(answer);
        expect(read.nothing, isTrue, reason: '$answer');
        expect(read.problem, isNull);
        expect(read.ops, isEmpty);
      }
    });

    test('the last fence that reads is the answer; an example before it is not', () {
      final read = DesignPass.readAnswer('An op looks like this:\n```json\n{"op": "patch", "id": "x", "patch": {}}\n```\nMine:\n```json\n$good\n```');
      expect(read.ops, hasLength(2));
      // The operations first, a note in a fence after: the fence that reads.
      expect(DesignPass.readAnswer('```json\n$good\n```\nIn short:\n```\nrow: tile\n```').ops, hasLength(2));
    });

    test('what does not parse says where; prose alone says what to write', () {
      final comma = DesignPass.readAnswer('Why.\n```json\n{"ops": [{"op": "patch", "id": "row", "patch": {}},]}\n```');
      expect(comma.ops, isNull);
      expect(comma.problem, allOf(contains('does not parse'), contains('at character'), contains('near `')));
      expect(DesignPass.readAnswer('I would make the title larger.').problem, contains('holds no operations'));
      expect(DesignPass.readAnswer('```json\n{"changes": []}\n```').problem, contains('no "ops" list'));
      expect(DesignPass.readAnswer(42).problem, isNotNull);
    });
  });

  group('how a pass ends', () {
    Future<(UiSession, String)> card() async {
      final session = UiSession(designSystem: await _cards());
      addTearDown(session.dispose);
      await session.applyNotation(Stream.value(_card));
      return (session, jsonEncode(session.document.toJson()));
    }

    test('nothing to change is an outcome of its own, after one answer', () async {
      final (session, plain) = await card();
      var asked = 0;
      final outcome = await DesignPass(session, maxRounds: 4, design: (_) async {
        asked++;
        return 'It already sits at the bar.\n```json\n{"ops": []}\n```';
      }).run();
      expect((outcome.kept, outcome.nothing, outcome.endedBy, asked), (false, true, 'nothing', 1));
      expect(outcome.problems, isEmpty);
      expect(outcome.answers.single.outcome, 'nothing');
      expect(jsonEncode(session.document.toJson()), plain);
    });

    test('an answer that cannot be read is asked for once more, told what was wrong; a second ends the pass', () async {
      final (session, plain) = await card();
      final requests = <DesignRequest>[];
      final outcome = await DesignPass(session, maxRounds: 4, design: (r) async {
        requests.add(r);
        return 'Why.\n```json\n{"ops": [{"op": "patch",]}\n```';
      }).run();
      expect(requests, hasLength(2));
      expect(requests[1].problems.single, contains('does not parse'));
      expect((outcome.kept, outcome.endedBy, outcome.rounds), (false, 'refused', 2));
      expect(outcome.problems.single, contains('does not parse'));
      expect(outcome.answers.map((a) => a.outcome), ['unreadable', 'unreadable']);
      expect(jsonEncode(session.document.toJson()), plain);

      // Read the second time: kept.
      var round = 0;
      final kept = await DesignPass(session, maxRounds: 4, design: (r) async => ++round == 1 ? 'Only words.' : _good).run();
      expect((kept.kept, kept.rounds), (true, 2));
      expect(kept.answers.map((a) => a.outcome), ['unreadable', 'kept']);
    });

    test('a call that throws is a pass that could not run: no answer was refused, and it is not asked again', () async {
      final (session, plain) = await card();
      var asked = 0;
      final outcome = await DesignPass(session, maxRounds: 4, design: (_) async {
        asked++;
        throw StateError('401: invalid x-api-key');
      }).run();
      expect(asked, 1);
      expect((outcome.kept, outcome.endedBy, outcome.rounds), (false, 'error', 0));
      expect(outcome.error, contains('401: invalid x-api-key'));
      expect(jsonEncode(session.document.toJson()), plain);
    });

    test('an error the host says passes is asked again once, after its wait', () async {
      final (session, _) = await card();
      var asked = 0;
      final waits = <Object>[];
      final outcome = await DesignPass(
        session,
        maxRounds: 2,
        retryAfter: (e) {
          waits.add(e);
          return const Duration(milliseconds: 5);
        },
        design: (_) async {
          if (++asked == 1) throw StateError('529 overloaded');
          return _good;
        },
      ).run();
      expect((outcome.kept, asked, waits.length), (true, 2, 1));
      expect(outcome.answers.map((a) => a.outcome), ['failed', 'kept']);

      // Twice in a row: it could not run.
      asked = 0;
      final failed = await DesignPass(session, retryAfter: (_) => Duration.zero, design: (_) async {
        asked++;
        throw StateError('529 overloaded');
      }).run();
      expect((failed.endedBy, asked), ('error', 2));
    });

    test('one rejected operation is left out and said; the rest of the answer is kept', () async {
      final (session, plain) = await card();
      final ops = [
        _good[0],
        {'op': 'patch', 'id': 'nobody', 'patch': {'props': {'spacing': 4}}},
        _good[1],
      ];
      final outcome = await DesignPass(session, design: (_) async => ops).run();
      expect((outcome.kept, outcome.ops, outcome.rounds), (true, 2, 1));
      expect(outcome.rejected.single, contains('Operation 2 was rejected'));
      expect(outcome.applied, [_good[0], _good[1]]);
      expect(outcome.answers.single.rejected, outcome.rejected);
      expect(session.document['row']!.toJson()['props'], containsPair('spacing', 12));
      // What was applied gives the same restyle again (a reload).
      final restyled = jsonEncode(session.document.toJson());
      expect(session.undo(author: DesignPass.author), isTrue);
      expect(jsonEncode(session.document.toJson()), plain);
      expect(session.apply(outcome.applied, author: DesignPass.author, atomic: true).ok, isTrue);
      expect(jsonEncode(session.document.toJson()), restyled);
    });

    test('a rejected operation beside one that changes what the UI says: refused, and the agent is told of both', () async {
      final (session, plain) = await card();
      final requests = <DesignRequest>[];
      final outcome = await DesignPass(session, maxRounds: 2, design: (r) async {
        requests.add(r);
        return [
          {'op': 'patch', 'id': 'nobody', 'patch': {'props': {'spacing': 4}}},
          {'op': 'patch', 'id': 'title', 'patch': {'props': {'text': 'Choose seats'}}},
        ];
      }).run();
      expect(outcome.kept, isFalse);
      expect(requests[1].problems.join('\n'), allOf(contains('Operation 1 was rejected'), contains('no longer says what it said')));
      expect(jsonEncode(session.document.toJson()), plain);
    });

    test('the agent or the check can cut the pass short: the UI is put back and the outcome says why', () async {
      final (session, plain) = await card();
      final byAgent = await DesignPass(session, design: (_) async => throw const DesignPassInterrupted('The page changed.')).run();
      expect((byAgent.kept, byAgent.endedBy, byAgent.interrupted), (false, 'interrupted', 'The page changed.'));
      final byCheck = await DesignPass(session, design: (_) async => _good, check: () => throw const DesignPassInterrupted('The page changed.')).run();
      expect((byCheck.kept, byCheck.endedBy, byCheck.rounds), (false, 'interrupted', 1));
      expect(jsonEncode(session.document.toJson()), plain);
    });
  });
}
