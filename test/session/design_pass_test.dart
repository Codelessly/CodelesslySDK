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
    Button#less "-" -> count=count-1
    Text#n "{count}"
    Button#more "+" -> count=count+1
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

  test('the operations are read from a list, a map, a fenced answer or a bare one', () {
    expect(DesignPass.opsOf(_good), hasLength(2));
    expect(DesignPass.opsOf({'ops': _good}), hasLength(2));
    expect(DesignPass.opsOf('Why.\n```json\n${jsonEncode({'ops': _good})}\n```\nDone.'), hasLength(2));
    expect(DesignPass.opsOf('Here: ${jsonEncode({'ops': _good})}'), hasLength(2));
    expect(DesignPass.opsOf('SHIP'), isNull);
  });
}
