// A block designed after a session began (because none fitted a request) is
// added to it while it runs: the next answer calls it by name, and the view
// already on screen draws it.
import 'dart:convert';
import 'dart:io';

import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
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

String _texts(WidgetTester tester) {
  final out = StringBuffer();
  void visit(RenderObject o) {
    if (o is RenderParagraph) out.writeln(o.text.toPlainText());
    o.visitChildren(visit);
  }

  tester.binding.renderViews.forEach(visit);
  return out.toString();
}

const _card = '''
ChatCard "Team lunch poll" "Where on Friday?" icon:"poll" status:"Closed"
  PollResults options:["Ramen bar","Taco truck","Pizza place"] votes:{[9,6,5]} choice:{"Taco truck"} note:"Votes are anonymous"
''';

void main() {
  testWidgets('a block added to a running session is called by the next answer and drawn by the view on screen', (tester) async {
    final ds = await tester.runAsync(_cards);
    final session = UiSession(designSystem: ds);
    addTearDown(session.dispose);
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Align(alignment: Alignment.topLeft, child: SizedBox(width: 420, height: 700, child: CodelesslyView(session: session))),
    ));
    expect(session.notationInstructions(), isNot(contains('PollResults')));

    final block = jsonDecode(File('examples/showcase/on-demand/poll/PollResults.json').readAsStringSync()) as Map<String, Object?>;
    session.addBlock(api.LayoutDocument.fromJson(block, catalog: api.standardCatalog));
    expect(session.notationInstructions(), contains('PollResults'));

    final result = await session.applyNotation(Stream.value(_card));
    await tester.pumpAndSettle();
    expect(session.notationIssues, isEmpty, reason: '${session.notationIssues}');
    expect(result.errors, isEmpty, reason: '${result.errors}');
    final shown = _texts(tester);
    expect(shown, contains('Team lunch poll'));
    expect(shown, contains('Taco truck'));
    expect(shown, contains('45%'), reason: 'the new block draws its shares: $shown');
  });
}
