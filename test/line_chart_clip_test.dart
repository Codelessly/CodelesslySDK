import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/widgets/indicators_paint.dart' show NodePainter;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a line chart with values below its yMin stays in its box', (tester) async {
    final doc = LayoutDocument.fromJson({
      'roots': ['root'],
      'nodes': {
        'root': {'type': 'column', 'children': ['line'], 'layout': {'width': 300, 'height': 400}},
        'line': {
          'type': 'lineChart',
          'layout': {'width': 300, 'height': 110},
          'props': {
            'xMin': 0, 'xMax': 3, 'yMin': 55, 'yMax': 75, 'animate': false,
            'data': [{'x': 1, 'y': 0}, {'x': 2, 'y': 0}, {'x': 3, 'y': 0}],
          },
        },
      },
    });
    final tree = NodeTree(DocumentSource(doc));
    await tester.pumpWidget(MaterialApp(home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'root'))));
    await tester.pump();
    RenderCustomPaint? paint;
    void visit(RenderObject o) {
      if (o is RenderCustomPaint && o.painter is NodePainter) paint = o;
      o.visitChildren(visit);
    }
    visit(tree.boxOf('line')!);
    expect(paint, paints..clipRect(rect: const Rect.fromLTWH(0, 0, 300, 110)));
    await tester.pumpWidget(const SizedBox());
    tree.dispose();
  });
}
