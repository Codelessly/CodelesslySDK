import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a plot padding places the y domain, lines and ranges inside it', (tester) async {
    final doc = LayoutDocument.fromJson({
      'roots': ['root'],
      'nodes': {
        'root': {'type': 'column', 'children': ['plot'], 'layout': {'width': 400, 'height': 300}},
        'plot': {
          'type': 'plotChart',
          'layout': {'width': 300, 'height': 200},
          'props': {
            'xMin': 0, 'xMax': 420, 'yMin': 0, 'yMax': 40, 'points': [], 'animate': false, 'labelHeight': 22,
            'yAxisWidth': 30, 'plotPadding': [0, 14, 12, 0],
            'yLines': [{'y': 40, 'color': '#FF000000'}],
            'ranges': [{'from': 210, 'to': 420, 'color': '#FFE0E0E0'}],
          },
        },
      },
    });
    final tree = NodeTree(DocumentSource(doc));
    addTearDown(tree.dispose);
    await tester.pumpWidget(MaterialApp(home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'root'))));
    await tester.pump();
    final lines = <(Offset, Offset)>[];
    final rects = <Rect>[];
    expect(
      tree.boxOf('plot'),
      paints
        ..everything((Symbol m, List<dynamic> a) {
          if (m == #drawLine) lines.add((a[0] as Offset, a[1] as Offset));
          if (m == #drawRect) rects.add(a[0] as Rect);
          return true;
        }),
    );
    // y = 40 (yMax) at the padding's top, from the gutter to 12 px short of the edge.
    expect(lines.any((l) => l.$1 == const Offset(30, 14) && l.$2 == const Offset(288, 14)), isTrue, reason: '$lines');
    // The range spans the plot: from x(210) to x(420) = 288, top 14 to the axis (200 - 22).
    expect(rects.any((r) => r.top == 14 && r.bottom == 178 && r.right == 288 && r.left == 30 + 258 / 2), isTrue,
        reason: '$rects');
  });
}
