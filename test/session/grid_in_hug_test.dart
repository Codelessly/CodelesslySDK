// A Grid of tiles that say only a height, inside a bubble as wide as its
// content: nothing in it has a width, so the grid has a width of its own to
// fall back on (its tiles squares of their height) and is not laid out 0
// wide.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _bubble = '''
state pics=[1,2,3]
Column
  Row gap=8
    Column gap=4
      Box pad=[12,8,12,8] radius=16 fill=#FFF1EEE8 gap=6
        Text "Hi"
        Grid#pics cols=3 gap=4
          each i in pics
            Box h=64 radius=8 fill=#FF7C3AED
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

void main() {
  testWidgets('its tiles are squares of their height, and nothing is laid out with no size', (tester) async {
    final session = UiSession();
    addTearDown(session.dispose);
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Align(alignment: Alignment.topLeft, child: SizedBox(width: 600, height: 600, child: CodelesslyView(session: session))),
    ));
    final result = await session.applyNotation(Stream.value(_bubble));
    expect(result.errors, isEmpty, reason: '${result.errors}');
    await tester.pumpAndSettle();
    // Three tiles of 64 and two gaps of 4.
    expect(_box(tester, 'pics').size, const Size(200, 64));
    expect([for (final d in session.layoutDiagnostics()) if (d.code == 'no_size') d.message], isEmpty);
  });
}
