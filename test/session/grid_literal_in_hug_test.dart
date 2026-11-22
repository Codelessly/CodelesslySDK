// A Grid of cells written out (no `each`) where nothing gives it a width
// (beside a text in a row, in a bubble as wide as its content): its rows are
// rows of equal cells that fill, so it is as wide as its columns of its
// widest cell. It was laid out 0 wide.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _days = '''
Column
  Row#bar gap=8
    Text "Days"
    Grid#g cols=3 gap=4
      Box#a w=24 h=24 fill=#FF112233
      Box#b w=24 h=24 fill=#FF112233
      Box#c w=24 h=24 fill=#FF112233
      Text#d "Mo"
      Text#e "Tu"
      Text#f "We"
''';

const _bubble = '''
Column
  Row gap=8
    Column gap=4
      Box pad=[12,8,12,8] radius=16 fill=#FFF1EEE8 gap=6
        Text "Hi"
        Grid#g cols=2 gap=4
          Box#a h=40 fill=#FF7C3AED
            Text "One"
          Box#b h=40 fill=#FF7C3AED
            Text "Twenty-two"
''';

NodeBox _box(WidgetTester tester, String id) {
  NodeBox? found;
  void visit(RenderObject o) {
    if (o is NodeBox && o.id == id) found ??= o;
    o.visitChildren(visit);
  }

  tester.binding.renderViews.forEach(visit);
  return found!;
}

Future<UiSession> _show(WidgetTester tester, String notation) async {
  final session = UiSession();
  addTearDown(session.dispose);
  await tester.pumpWidget(Directionality(
    textDirection: TextDirection.ltr,
    child: Align(alignment: Alignment.topLeft, child: SizedBox(width: 600, height: 600, child: CodelesslyView(session: session))),
  ));
  final result = await session.applyNotation(Stream.value(notation));
  expect(result.errors, isEmpty, reason: '${result.errors}');
  await tester.pumpAndSettle();
  return session;
}

void main() {
  testWidgets('beside a text in a row: three columns of its widest cell, nothing with no size', (tester) async {
    final session = await _show(tester, _days);
    expect([for (final d in session.layoutDiagnostics()) if (d.code == 'no_size') d.message], isEmpty);
    final g = _box(tester, 'g').size, a = _box(tester, 'a').size, d = _box(tester, 'd').size;
    expect(a.width, greaterThanOrEqualTo(24));
    // Every cell is as wide as the others, and the grid is its three columns and two gaps.
    expect(d.width, closeTo(a.width, 0.01));
    expect(g.width, closeTo(a.width * 3 + 8, 0.01));
  });

  testWidgets('where its parent gives it a width (a centered column of a page), its cells share that, as before', (tester) async {
    await _show(tester, '''
Column center w=fill
  Text "Figures"
  Grid#g cols=3 gap=24
    Text#a "One"
    Text#b "Two"
    Text#c "Three"
''');
    expect(_box(tester, 'g').size.width, 600);
    expect(_box(tester, 'a').size.width, closeTo((600 - 48) / 3, 0.01));
  });

  testWidgets('in a bubble as wide as its content: two columns of its widest text', (tester) async {
    final session = await _show(tester, _bubble);
    expect([for (final d in session.layoutDiagnostics()) if (d.code == 'no_size') d.message], isEmpty);
    final g = _box(tester, 'g').size, a = _box(tester, 'a').size, b = _box(tester, 'b').size;
    expect(a.width, closeTo(b.width, 0.01));
    expect(a.width, greaterThan(40), reason: 'room for "Twenty-two"');
    expect(g.width, closeTo(a.width * 2 + 4, 0.01));
  });
}
