import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart' hide Node;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

// A rounded box with a uniform border, painted in the SDK's layer, paints the border as Flutter's
// BoxDecoration(border: Border.all(...), borderRadius: ...) does: the band
// between the outer and inner rounded rects, filled (drawDRRect). A stroked
// centre line covers the same band but anti-aliases the inner corners
// differently (a corner pixel 9 levels off on the web).

RenderBox _painter(NodeTree tree, String id) {
  RenderBox? out;
  void visit(RenderObject o) {
    if (out == null && o.runtimeType.toString() == 'RenderNodePaint') out = o as RenderBox;
    o.visitChildren(visit);
  }

  visit(tree.boxOf(id)!);
  return out!;
}

void main() {
  for (final (align, outset, inset) in [('inside', 0.0, 1.5), ('center', 0.75, 0.75), ('outside', 1.5, 0.0)]) {
    testWidgets('a rounded border ($align) paints as BoxBorder: one drawDRRect', (tester) async {
      final tree = NodeTree(DocumentSource(LayoutDocument.fromJson({
        'roots': ['b'],
        'nodes': {
          'b': {
            'type': 'box',
            'layout': {'width': 78, 'height': 38, 'x': {'start': 10}, 'y': {'start': 10}},
            'decoration': {
              // A gradient fill: the box paints in the SDK's own layer (a
              // plain one is Flutter's BoxDecoration, which already does this).
              'fills': [
                {'type': 'linear', 'stops': [{'color': '#FF3A2A1C', 'position': 0}, {'color': '#FF2A1C10', 'position': 1}]},
              ],
              'strokes': [{'color': '#FFC9A97B'}],
              'strokeWidth': 1.5,
              'strokeAlign': align,
              'radius': 3,
            },
          },
        },
      })));
      addTearDown(tree.dispose);
      await tester.pumpWidget(MaterialApp(home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'b'))));
      final painter = _painter(tree, 'b');
      // What Flutter's BoxBorder draws for the same box.
      final box = BorderRadius.circular(3).toRRect(Offset.zero & painter.size);
      final side = BorderSide(color: const Color(0xFFC9A97B), width: 1.5, strokeAlign: switch (align) {
        'inside' => BorderSide.strokeAlignInside,
        'center' => BorderSide.strokeAlignCenter,
        _ => BorderSide.strokeAlignOutside,
      });
      expect(side.strokeOutset, outset);
      expect(side.strokeInset, inset);
      expect(
        painter,
        paints..drrect(outer: box.inflate(side.strokeOutset), inner: box.deflate(side.strokeInset), color: const Color(0xFFC9A97B)),
      );
      expect(painter, isNot(paints..path()));
    });
  }

  testWidgets('a square border and a dashed rounded one still stroke a path', (tester) async {
    final tree = NodeTree(DocumentSource(LayoutDocument.fromJson({
      'roots': ['s'],
      'nodes': {
        's': {
          'type': 'stack',
          'layout': {'width': 200, 'height': 100},
          'children': ['dashed'],
        },
        'dashed': {
          'type': 'box',
          'layout': {'width': 60, 'height': 30, 'x': {'start': 0}, 'y': {'start': 0}},
          'decoration': {'strokes': [{'color': '#FF000000'}], 'strokeWidth': 1, 'radius': 4, 'dashPattern': [3, 2],
            'fills': [{'type': 'linear', 'stops': [{'color': '#FF000000', 'position': 0}, {'color': '#FFFFFFFF', 'position': 1}]}]},
        },
      },
    })));
    addTearDown(tree.dispose);
    await tester.pumpWidget(MaterialApp(home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 's'))));
    expect(_painter(tree, 'dashed'), paints..path());
  });
}
