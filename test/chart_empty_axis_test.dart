import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/widgets/indicators_paint.dart' show NodePainter;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Future<RenderCustomPaint> _paintOf(WidgetTester tester, List<Map<String, Object?>> data) async {
  final doc = LayoutDocument.fromJson({
    'roots': ['root'],
    'nodes': {
      'root': {'type': 'column', 'children': ['c'], 'layout': {'width': 400, 'height': 300}},
      'c': {
        'type': 'chart',
        'layout': {'width': 400, 'height': 200},
        'props': {
          'chartType': 'line', 'xField': 'm', 'domainMin': 0, 'domainMax': 120, 'animate': false,
          'gridLines': 0, 'showYAxis': false,
          'xLabels': [{'x': 0, 'label': '22:00'}, {'x': 60, 'label': '23:00'}, {'x': 120, 'label': '00:00'}],
          'series': [{'field': 'v', 'kind': 'line'}],
          'data': data,
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
  visit(tree.boxOf('c')!);
  return paint!;
}

void main() {
  testWidgets('a line chart with value-placed labels keeps its time axis without rows', (tester) async {
    expect(await _paintOf(tester, const []), paintsExactlyCountTimes(#drawParagraph, 3));
  });
}
