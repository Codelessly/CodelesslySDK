import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

// A column that stretches its children leaves a child with a width of its
// own at that width (CSS align-items: stretch over an item's width): a 64 ×
// 64 tile in a stretching scroll column drew as wide as the column. A child
// that fills, or writes no width, is still stretched.

Future<(NodeTree, RenderObject)> _show(WidgetTester tester, Map<String, Map<String, Object?>> nodes) async {
  final tree = NodeTree(DocumentSource(LayoutDocument.fromJson({'schema': 3, 'roots': ['col'], 'nodes': nodes})));
  addTearDown(tree.dispose);
  await tester.pumpWidget(MaterialApp(home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'col'))));
  return (tree, tester.renderObject(find.byType(NodeView)));
}

void main() {
  testWidgets('a fixed width in a stretching column holds, at the start; a fill is stretched', (tester) async {
    final (tree, view) = await _show(tester, {
      'col': {
        'type': 'column',
        'layout': {'width': 350, 'height': 300},
        'props': {'crossAxisAlignment': 'stretch'},
        'children': ['tile', 'bar'],
      },
      'tile': {
        'type': 'row',
        'layout': {'width': 64, 'height': 64},
        'decoration': {
          'fills': [
            {'color': '#FFEEEEEE'},
          ],
        },
      },
      'bar': {
        'type': 'box',
        'layout': {'width': {'fill': 0}, 'height': 20},
      },
    });
    final tile = tree.boxOf('tile')!;
    // The node's own box: its paint, 64 wide, at the column's start.
    RenderBox inner = tile;
    while (inner.size.width != 64 && inner is RenderObjectWithChildMixin<RenderBox> && (inner as RenderObjectWithChildMixin<RenderBox>).child != null) {
      inner = (inner as RenderObjectWithChildMixin<RenderBox>).child!;
    }
    expect(inner.size, const Size(64, 64));
    expect(inner.localToGlobal(Offset.zero, ancestor: view).dx, 0);
    expect(tree.boxOf('bar')!.rectIn(view)!.width, 350);
  });
}
