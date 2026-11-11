// A negative margin or padding in a document (or from a binding) reads as 0:
// Flutter asserts insets are never negative, and one bad side used to fail
// the layout of the whole screen.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('negative margins and paddings lay out as zero, the rest of the screen intact', (tester) async {
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
    expect(tree.boxOf('a')!.rectIn(view)!.left, 0);
    expect(tree.boxOf('b')!.rectIn(view)!.left, 50);
    expect(tree.boxOf('r')!.rectIn(view)!.width, 200);
  });
}
