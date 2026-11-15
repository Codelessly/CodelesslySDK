// A block that takes children (a card frame) gains them line by line as a
// notation answer streams in: each one shows when its line completes, with
// the view left as it is (no rebuild of it by the host).
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

  for (final v in tester.binding.renderViews) {
    visit(v);
  }
  return out.toString();
}

const _card = '''
ChatCard "Delete 214 old files?" "Shared drive cleanup" icon:"delete_rounded" status:"Awaiting you"
  Paragraph "Nothing is removed until you approve."
  Details rows:[["Folder","Archive / 2019"],["Files","214"]]
  ActionButton "Approve deletion" tone:"danger" -> emit decision "approve"
''';

void main() {
  testWidgets('children of a block show as their lines arrive, in a view that is not rebuilt', (tester) async {
    final ds = await tester.runAsync(_cards);
    final session = UiSession(designSystem: ds);
    addTearDown(session.dispose);
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Align(alignment: Alignment.topLeft, child: SizedBox(width: 420, height: 700, child: CodelesslyView(session: session))),
    ));
    final seen = <String>[];
    Stream<String> lines() async* {
      for (final line in _card.trimLeft().split('\n')) {
        yield '$line\n';
        await tester.pump(const Duration(milliseconds: 50));
        seen.add(_texts(tester));
      }
    }

    final result = await session.applyNotation(lines());
    await tester.pumpAndSettle();
    expect(session.notationIssues, isEmpty);
    expect(result.errors, isEmpty, reason: '${result.errors}');
    final end = _texts(tester);
    expect(end, contains('Delete 214 old files?'));
    expect(end, contains('Nothing is removed until you approve.'), reason: 'the card\'s children are drawn');
    expect(end, contains('Approve deletion'));
    // The paragraph was on screen before the button's line arrived.
    expect(seen.any((s) => s.contains('Nothing is removed') && !s.contains('Approve deletion')), isTrue, reason: seen.join('\n---\n'));
  });
}
