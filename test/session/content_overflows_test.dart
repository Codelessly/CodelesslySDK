// A child that reaches past its row's edge is reported by the view's own
// check; one that fits, and one under a sideways scroller, is not.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Future<List<String>> _shown(WidgetTester tester, String notation, {double width = 320}) async {
  final session = UiSession();
  addTearDown(session.dispose);
  await tester.pumpWidget(Directionality(
    textDirection: TextDirection.ltr,
    child: Align(alignment: Alignment.topLeft, child: SizedBox(width: width, height: 600, child: CodelesslyView(session: session))),
  ));
  final result = await session.applyNotation(Stream.value(notation));
  expect(result.errors, isEmpty, reason: '${result.errors}');
  await tester.pumpAndSettle();
  tester.takeException(); // the debug-mode overflow report of the same thing
  return [for (final d in session.shownDiagnostics()) if (d.code == 'content_overflows') d.message];
}

void main() {
  testWidgets('what to write is said for what reaches past: the copies of an each, and a text taller than its column', (tester) async {
    // Copies side by side do not shrink: wrap, scroll or fewer.
    final copies = await _shown(
        tester, 'state teams=["Platform","Design","Support"]\nColumn\n  Row#cell w=150 gap=4\n    each t in teams\n      Box w=70 h=20 fill=#FFEEEEEE\n');
    expect(copies.single, allOf(contains('past the right edge of "cell"'), contains('copies an each repeats'), contains('wrap on the row'), isNot(contains('maxLines'))));
    // A stage's label in a box scaled to half: one line, taller than the box.
    final label = await _shown(tester, 'state zoom=0.5\nColumn\n  Box#stage w=230 h={20*zoom} fill=#FFD9B15F\n    Text#label "S T A G E" size=14\n');
    expect(label.single, allOf(contains('"label" reaches'), contains('The text is 14 high'), contains('the column is written 10 high'), isNot(contains('maxLines'))));
  });

  testWidgets('a Stack of a height that its column cuts short is reported: its text was written beside it, not in it', (tester) async {
    // A sheet's cell: the row is 24 high, the Stack is 24 high, and the text
    // after it (at the Stack's depth) is a second line of the cell's column.
    // The Stack gave way to 12 with nothing past the column's edge to report.
    final found = await _shown(
        tester, 'Column\n  Row h=24\n    Column#cell w=90\n      Stack#ground w=90 h=24 fill=#FFFFFFFF border=#FFE3E6EA\n      Text#value "12" size=12 maxLines=1 grow\n');
    expect(found, hasLength(1));
    expect(found.single, allOf(contains('"ground" is written 24 high and is given 12'), contains('"cell" (a column 24 high)'), contains('"value"'), contains('indented')));
  });

  testWidgets('one drawn at the height written, and one in a column that scrolls, is not', (tester) async {
    expect(await _shown(tester, 'Column\n  Row h=24\n    Column#cell w=90\n      Stack#ground w=90 h=24 fill=#FFFFFFFF\n        Text#value "12" size=12 maxLines=1\n'), isEmpty);
    expect(
        await _shown(tester, 'Column\n  Row h=24\n    Column#cell w=90 scroll\n      Stack#ground w=90 h=24 fill=#FFFFFFFF\n      Text#value "12" size=12 maxLines=1\n'), isEmpty);
  });

  testWidgets('fixed cells wider than the row are reported, with by how much', (tester) async {
    final found = await _shown(tester, 'Column\n  Row gap=8\n    Box w=140 h=40 fill=#FF111827\n    Box w=140 h=40 fill=#FF111827\n    Box w=140 h=40 fill=#FF111827\n');
    expect(found, isNotEmpty);
    expect(found.join('\n'), contains('past the right edge'));
  });

  testWidgets('a row that fits, and a row that scrolls sideways, are not', (tester) async {
    expect(await _shown(tester, 'Column\n  Row gap=8\n    Box w=80 h=40 fill=#FF111827\n    Box w=80 h=40 fill=#FF111827\n'), isEmpty);
    expect(await _shown(tester, 'Column\n  Row scroll gap=8\n    Box w=140 h=40 fill=#FF111827\n    Box w=140 h=40 fill=#FF111827\n    Box w=140 h=40 fill=#FF111827\n'), isEmpty);
  });
}
