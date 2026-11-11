// A negative padding in a document (or from a binding) reads as 0: Flutter
// asserts insets are never negative, and one bad side used to fail the
// layout of the whole screen. A negative margin overlaps (RenderMargin): the
// node reaches that far past its place, and its neighbour moves up to it.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('negative paddings lay out as zero, negative margins overlap, the rest of the screen intact', (tester) async {
    final tree = NodeTree(DocumentSource(LayoutDocument.fromJson({
      'roots': ['r'],
      'nodes': {
        'r': {'type': 'row', 'children': ['a', 'b'], 'layout': {'width': 200, 'height': 40, 'padding': [-6, 4, 0, 4]}},
        'a': {'type': 'box', 'layout': {'width': 50, 'height': 20, 'margin': [-4, 0, 0, -2]}},
        'b': {'type': 'box', 'layout': {'width': 60, 'height': 20}},
      },
    })));
    addTearDown(tree.dispose);
    await tester.pumpWidget(MaterialApp(home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'r'))));
    expect(tester.takeException(), isNull);
    final view = tester.renderObject(find.byType(NodeView));
    // `a` takes 50 - 4 in the row and is drawn 4 px left of it; `b` follows.
    expect(tree.boxOf('a')!.rectIn(view)!.left, -4);
    expect(tree.boxOf('a')!.rectIn(view)!.width, 50);
    expect(tree.boxOf('b')!.rectIn(view)!.left, 46);
    expect(tree.boxOf('r')!.rectIn(view)!.width, 200);
  });
}
