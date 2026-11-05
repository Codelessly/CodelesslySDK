// Elliptical corners: a node's decoration, clip and painted fills and
// strokes take each corner's x and y.
import 'package:codelessly_sdk_v2/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

List<T> _under<T>(RenderObject root) {
  final out = <T>[];
  void visit(RenderObject o) {
    if (o is T) out.add(o as T);
    o.visitChildren(visit);
  }

  visit(root);
  return out;
}

void main() {
  testWidgets('a box with elliptical corners decorates, clips and paints them', (tester) async {
    final tree = NodeTree(DocumentSource(LayoutDocument.fromJson({
      'roots': ['s'],
      'nodes': {
        's': {'type': 'stack', 'children': ['solid', 'gradient'], 'layout': {'width': 400, 'height': 200}},
        'solid': {
          'type': 'stack',
          'layout': {'width': 80, 'height': 40, 'x': {'start': 0}, 'y': {'start': 0}},
          'decoration': {'fills': [{'color': '#FFFF0000'}], 'radius': [40, 10], 'clip': 'antiAlias'},
        },
        'gradient': {
          'type': 'box',
          'layout': {'width': 80, 'height': 40, 'x': {'start': 100}, 'y': {'start': 0}},
          'decoration': {
            'fills': [
              {'type': 'linear', 'stops': [{'color': '#FF000000', 'position': 0}, {'color': '#FFFFFFFF', 'position': 1}]},
            ],
            'strokes': [{'color': '#FF0000FF'}],
            'strokeWidth': 2,
            'radius': [[30, 12], 4, 0, 0],
          },
        },
      },
    })));
    addTearDown(tree.dispose);
    await tester.pumpWidget(MaterialApp(home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 's'))));

    const oval = BorderRadius.all(Radius.elliptical(40, 10));
    final solid = tree.boxOf('solid')!;
    final decorated = _under<RenderDecoratedBox>(solid).map((d) => d.decoration).whereType<BoxDecoration>();
    expect(decorated.map((d) => d.borderRadius), contains(oval));
    expect(_under<RenderClipRRect>(solid).single.borderRadius, oval);

    final gradient = tree.boxOf('gradient')!;
    final painter = _under<RenderBox>(gradient).firstWhere((o) => o.runtimeType.toString() == 'RenderNodePaint');
    const corners = BorderRadius.only(topLeft: Radius.elliptical(30, 12), topRight: Radius.circular(4));
    final rect = Offset.zero & painter.size;
    expect(painter, paints..rrect(rrect: corners.toRRect(rect))..path());
    expect(tester.takeException(), isNull);
  });
}
