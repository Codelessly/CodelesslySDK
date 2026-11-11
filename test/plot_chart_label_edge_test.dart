import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a plot chart keeps its last x label inside the chart', (tester) async {
    final doc = LayoutDocument.fromJson({
      'roots': ['root'],
      'nodes': {
        'root': {'type': 'column', 'children': ['plot'], 'layout': {'width': 400, 'height': 300}},
        'plot': {
          'type': 'plotChart',
          'layout': {'width': 300, 'height': 160},
          'props': {
            'xMin': 0, 'xMax': 420, 'points': [0, 1, 2], 'animate': false, 'labelHeight': 18,
            'xLabels': [{'x': 0, 'label': '22:00'}, {'x': 420, 'label': '05:00'}],
          },
        },
      },
    });
    final tree = NodeTree(DocumentSource(doc));
    addTearDown(tree.dispose);
    await tester.pumpWidget(MaterialApp(home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'root'))));
    await tester.pump();
    final paint = tree.boxOf('plot');
    final starts = <double>[];
    expect(
      paint,
      paints
        ..everything((Symbol method, List<dynamic> args) {
          if (method == #drawParagraph) {
            starts.add((args[1] as Offset).dx);
          }
          return true;
        }),
    );
    // "05:00" at x = 420 (the right edge) starts a label's width before it,
    // not half a width (it would be cut off by the chart's clip).
    expect(starts, isNotEmpty);
    expect(starts.reduce((a, b) => a > b ? a : b), lessThan(280));
    expect(starts.reduce((a, b) => a < b ? a : b), greaterThanOrEqualTo(0));
  });

  testWidgets('a marker label at the left edge stays clear of the y-axis gutter', (tester) async {
    final doc = LayoutDocument.fromJson({
      'roots': ['root'],
      'nodes': {
        'root': {'type': 'column', 'children': ['plot'], 'layout': {'width': 400, 'height': 300}},
        'plot': {
          'type': 'plotChart',
          'layout': {'width': 300, 'height': 160},
          'props': {
            'xMin': 0, 'xMax': 420, 'points': [10, 20, 30], 'animate': false, 'yMin': 0, 'yMax': 40,
            'yAxisWidth': 30, 'labelHeight': 0,
            'markers': [{'x': 0, 'y': 33, 'label': 'EXIT POLL 33'}],
          },
        },
      },
    });
    final tree = NodeTree(DocumentSource(doc));
    addTearDown(tree.dispose);
    await tester.pumpWidget(MaterialApp(home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'root'))));
    await tester.pump();
    final starts = <double>[];
    expect(
      tree.boxOf('plot'),
      paints
        ..everything((Symbol method, List<dynamic> args) {
          if (method == #drawParagraph) starts.add((args[1] as Offset).dx);
          return true;
        }),
    );
    expect(starts, isNotEmpty);
    expect(starts.reduce((a, b) => a < b ? a : b), greaterThanOrEqualTo(30));
  });
}
