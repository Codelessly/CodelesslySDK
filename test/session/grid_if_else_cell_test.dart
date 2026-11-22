// A Grid's cell written as an `if` and its `else` is one cell: the branch
// that shows is in the place of the other. Each branch was a cell of its
// own: with two columns the `else` began a second row, laid out with no
// height while the `if` showed (a no_size note the writer could not act on),
// and under the first column once it showed.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _contact = '''
state sent=false
Column
  Grid#g cols=2 gap=48
    Column#words
      Text "Say hello."
    if !sent
      Box#form h=200 fill=#FF112233
    else
      Box#thanks h=120 fill=#FF445566
  Button#send "Send" onTap={sent=true}
''';

const _atWidths = '''
state sent=false
Column
  Grid#g cols=3 phone.cols=1 gap=10
    Box#a h=40 fill=#FF112233
    if !sent
      Box#form h=40 fill=#FF112233
    else
      Box#thanks h=40 fill=#FF445566
    Box#c h=40 fill=#FF112233
''';

NodeBox? _box(WidgetTester tester, String id) {
  NodeBox? found;
  void visit(RenderObject o) {
    // (Of a cell's copies, the one that shows.)
    if (o is NodeBox && o.id == id && o.hasSize && !o.size.isEmpty) found ??= o;
    o.visitChildren(visit);
  }

  tester.binding.renderViews.forEach(visit);
  return found;
}

Rect _rect(WidgetTester tester, String id) {
  final box = _box(tester, id)!;
  return box.localToGlobal(Offset.zero) & box.size;
}

Future<UiSession> _show(WidgetTester tester, String notation, {double width = 600}) async {
  final session = UiSession();
  addTearDown(session.dispose);
  await tester.pumpWidget(Directionality(
    textDirection: TextDirection.ltr,
    child: Align(alignment: Alignment.topLeft, child: SizedBox(width: width, height: 600, child: CodelesslyView(session: session))),
  ));
  final result = await session.applyNotation(Stream.value(notation));
  expect(result.errors, isEmpty, reason: '${result.errors}');
  await tester.pumpAndSettle();
  return session;
}

void main() {
  testWidgets('the else takes the cell of its if: one row, no row of no height, and the same place once it shows', (tester) async {
    final session = await _show(tester, _contact);
    expect([for (final d in session.layoutDiagnostics()) if (d.code == 'no_size') d.message], isEmpty);
    final form = _rect(tester, 'form');
    // The second of two columns of (600 - 48) / 2.
    expect(form.left, 324);
    expect(form.width, 276);
    expect(_rect(tester, 'g').height, 200);

    await tester.tapAt(_rect(tester, 'send').center);
    await tester.pumpAndSettle();
    final thanks = _rect(tester, 'thanks');
    expect(thanks.left, 324);
    expect(thanks.width, 276);
    expect(thanks.top, form.top);
    expect(_rect(tester, 'words').width, 276);
    expect([for (final d in session.layoutDiagnostics()) if (d.code == 'no_size') d.message], isEmpty);
  });

  testWidgets('with columns at other widths too: three cells, the third after the one that shows', (tester) async {
    await _show(tester, _atWidths, width: 800);
    final a = _rect(tester, 'a'), form = _rect(tester, 'form'), c = _rect(tester, 'c');
    expect(a.top, form.top);
    expect(c.top, a.top);
    expect(form.left, greaterThan(a.right));
    expect(c.left, greaterThan(form.right));
    expect(c.right, 800);
  });
}
