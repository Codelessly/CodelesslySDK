import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/widgets/indicators_paint.dart' show NodePainter;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Future<RenderCustomPaint> _paintOf(WidgetTester tester, Map<String, Object?> line) async {
  final doc = LayoutDocument.fromJson({
    'roots': ['root'],
    'nodes': {
      'root': {'type': 'column', 'children': ['line'], 'layout': {'width': 300, 'height': 200}},
      'line': {
        'type': 'lineChart',
        'layout': {'width': 300, 'height': 110},
        'props': {
          'xMin': 0, 'xMax': 3, 'yMin': 55, 'yMax': 75, 'animate': false,
          'data': [{'x': 1, 'y': 60}, {'x': 2, 'y': 66}],
          'referenceLines': [line],
        },
      },
    },
  });
  final tree = NodeTree(DocumentSource(doc));
  addTearDown(tree.dispose);
  await tester.pumpWidget(MaterialApp(home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'root'))));
  await tester.pump();
  RenderCustomPaint? paint;
  void visit(RenderObject o) {
    if (o is RenderCustomPaint && o.painter is NodePainter) paint = o;
    o.visitChildren(visit);
  }
  visit(tree.boxOf('line')!);
  return paint!;
}

void main() {
  testWidgets('a reference line can be labelled', (tester) async {
    final plain = await _paintOf(tester, {'y': 63.4, 'color': '#FFC0392B'});
    expect(plain, paintsExactlyCountTimes(#drawParagraph, 0));
    final labelled = await _paintOf(tester, {'y': 63.4, 'color': '#FFC0392B', 'label': '2022 63.4%'});
    expect(labelled, paintsExactlyCountTimes(#drawParagraph, 1));
  });
}
