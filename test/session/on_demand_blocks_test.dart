// A card that names a block it wanted shows at once from plain parts; the
// block is designed in the background, checked, added to the session, and
// the next answer calls it by name.
import 'dart:convert';
import 'dart:io';

import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

Future<api.DesignSystem> _cards() async {
  final problems = <String>[];
  final ds = await api.DesignSystem.load((ref) async {
    final f = File('design_systems/cards/$ref');
    return f.existsSync() ? f.readAsStringSync() : null;
  }, problems: problems);
  expect(problems, isEmpty);
  return ds;
}

Map<String, Object?> _poll() =>
    jsonDecode(File('examples/showcase/on-demand/poll/PollResults.json').readAsStringSync()) as Map<String, Object?>;

const _first = '''
ChatCard "Team lunch poll" "Where on Friday?"
  Wanted "PollResults" "each option with its share of the votes as a bar, the leader marked"
    Text "Ramen bar 9"
    Text "Taco truck 6"
''';

const _second = '''
ChatCard "Team lunch poll" "Where on Friday?"
  PollResults options:["Ramen bar","Taco truck"] votes:=[9,6] choice:="Taco truck"
''';

void main() {
  test('the prompt asks for a name only when told to', () async {
    final session = UiSession(designSystem: await _cards());
    addTearDown(session.dispose);
    expect(session.notationInstructions(), isNot(contains('Wanted "')));
    expect(session.notationInstructions(askForBlocks: true), contains('Wanted "Name"'));
  });

  test('a wanted block shows from plain parts, is designed once, checked and added', () async {
    final session = UiSession(designSystem: await _cards());
    addTearDown(session.dispose);
    final asked = <List<String>>[];
    final stored = <String>[];
    final blocks = OnDemandBlocks(
      session,
      design: (wanted, session, notes) async {
        asked.add(notes);
        // The first design is not a component; the second is the block.
        return asked.length == 1 ? {'schema': 3, 'roots': <String>[], 'nodes': <String, Object?>{}} : _poll();
      },
      onAdded: (wanted, definition) => stored.add(definition.componentType!),
    );

    final result = await session.applyNotation(Stream.value(_first));
    expect(result.errors, isEmpty, reason: '${result.errors}');
    expect(session.notationIssues, isEmpty, reason: '${session.notationIssues}');
    expect(session.wantedBlocks.single.name, 'PollResults');
    expect(session.wantedBlocks.single.purpose, contains('share of the votes'));
    // Its strings are the request, not text on the card.
    expect(jsonEncode(session.document.toJson()), isNot(contains('share of the votes')));
    expect(jsonEncode(session.document.toJson()), contains('Ramen bar 9'));

    final both = await Future.wait([blocks.designWanted(), blocks.designWanted()]);
    expect(asked, hasLength(2), reason: 'one request, joined, two tries');
    expect(asked[1].single, contains('Not a component'));
    expect(both.first.single.added, isTrue, reason: '${both.first}');
    expect(both.first.single.tries, 2);
    expect(stored, ['PollResults']);
    expect(blocks.designing, isEmpty);
    expect(session.notationInstructions(), contains('PollResults'));

    // The card written again takes the old one's place.
    final next = await session.applyNotation(Stream.value(_second), replace: true);
    expect(next.errors, isEmpty, reason: '${next.errors}');
    expect(session.notationIssues, isEmpty, reason: '${session.notationIssues}');
    expect(session.wantedBlocks, isEmpty);
    expect(jsonEncode(session.document.toJson()), isNot(contains('Ramen bar 9')));
    expect(session.document.nodes.values.where((n) => n.type == 'PollResults'), hasLength(1));
    // Nothing is asked for a block the session now has.
    expect(await blocks.designWanted(), isEmpty);
  });

  test('a design under another name, or one a host check refuses, is not added', () async {
    final session = UiSession(designSystem: await _cards());
    addTearDown(session.dispose);
    await session.applyNotation(Stream.value(_first.replaceAll('PollResults', 'VoteBars')));
    final wrongName = OnDemandBlocks(session, design: (w, s, n) async => _poll(), maxTries: 1);
    final a = (await wrongName.designWanted()).single;
    expect(a.added, isFalse);
    expect(a.problems.single, contains('asked for as "VoteBars"'));

    await session.applyNotation(Stream.value(_first), replace: true);
    final refused = OnDemandBlocks(session, design: (w, s, n) async => _poll(), check: (w, d) => ['Too wide at 320.'], maxTries: 1);
    final b = (await refused.designWanted()).single;
    expect(b.added, isFalse);
    expect(b.problems, ['Too wide at 320.']);
    expect(session.designSystem!.components['PollResults'], isNull);
  });

  test('a parameter named like a handler (change) is the parameter', () async {
    final session = UiSession(designSystem: await _cards());
    addTearDown(session.dispose);
    final block = jsonDecode(File('examples/showcase/on-demand/stock/StockQuote.json').readAsStringSync()) as Map<String, Object?>;
    session.addBlock(api.LayoutDocument.fromJson(block, catalog: api.standardCatalog));
    final result = await session.applyNotation(Stream.value(File('examples/showcase/on-demand/stock/designer-card.txt').readAsStringSync()));
    expect(session.notationIssues, isEmpty, reason: '${session.notationIssues}');
    expect(result.errors, isEmpty, reason: '${result.errors}');
    final quote = session.document.nodes.values.singleWhere((n) => n.type == 'StockQuote');
    expect(jsonEncode(quote.toJson()), contains('"change":1.84'));
  });


  test('a card of mostly plain parts is told from one made of blocks', () async {
    final session = UiSession(designSystem: await _cards());
    addTearDown(session.dispose);
    final blocks = OnDemandBlocks(session, design: (w, s, n) async => null);
    await session.applyNotation(Stream.value('ChatCard "Poll" "Friday"\n  Row\n    Text "Ramen"\n    Text "45%"\n  Row\n    Text "Taco"\n    Text "30%"\n'));
    expect(blocks.mostlyPlainParts, isTrue);
    await session.applyNotation(
      Stream.value('ChatCard "Plan" "Team"\n  Counter "Seats" =seats min:1 max:9\n  ActionButton "Upgrade"\n  Text "Billed monthly"\n'),
      replace: true,
    );
    expect(blocks.mostlyPlainParts, isFalse);
  });

}
