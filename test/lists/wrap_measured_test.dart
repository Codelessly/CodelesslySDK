// A list that wraps its items is measured by what is around it: a grid
// whose rows are as tall as their cells counts the lines the items take, and
// a row that makes room for a grown child keeps the list its longest item.
// It had no measure (0 by 0): a card's wrapping chips were left out of the
// height of its row in a grid and reached past the card's cell.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _sponsors = '''
state tiers=[{"name":"Gold","names":["Northwind","Contoso","Fabrikam","Globex"]},{"name":"Silver","names":["Initech","Umbrella"]},{"name":"Bronze","names":["Hooli"]}]
Column
  Grid#g cols=3 gap=20
    each t in tiers
      Box#card gap=14 pad=16 fill=#FFFFFFFF
        Text "{t.name}"
        Row#names gap=8 wrap
          each n in t.names
            Box#chip w=100 h=24 fill=#1A4B2FD6
''';

List<NodeBox> _boxes(WidgetTester tester, String id) {
  final found = <NodeBox>[];
  void visit(RenderObject o) {
    if (o is NodeBox && o.id == id && o.hasSize) found.add(o);
    o.visitChildren(visit);
  }

  tester.binding.renderViews.forEach(visit);
  return found;
}

void main() {
  testWidgets('a card of chips that wrap, in a grid: the row is as tall as its tallest card, and nothing reaches past its cell', (tester) async {
    final session = UiSession();
    addTearDown(session.dispose);
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Align(alignment: Alignment.topLeft, child: SizedBox(width: 800, height: 600, child: CodelesslyView(session: session))),
    ));
    final result = await session.applyNotation(Stream.value(_sponsors));
    expect(result.errors, isEmpty, reason: '${result.errors}');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // A cell is (800 - 40) / 3 wide, 221.3 inside its padding: two chips of 100 to a line.
    final names = _boxes(tester, 'names');
    expect([for (final n in names) n.size.height], [56, 24, 24]);
    final cards = _boxes(tester, 'card');
    final tallest = cards.map((c) => c.size.height).reduce((a, b) => a > b ? a : b);
    expect(tallest, greaterThan(16 + 14 + 56 + 16));
    expect(_boxes(tester, 'g').single.size.height, tallest);
    expect([for (final d in session.shownDiagnostics()) if (d.code == 'content_overflows') d.message], isEmpty);
  });
}
