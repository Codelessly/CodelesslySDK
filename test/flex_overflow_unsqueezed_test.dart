// A row with squeezeChildren false lets its children run past its end, as a
// Flutter Row does. It paints them without the debug overflow stripe (and
// its "A RenderFlex overflowed" error): a release build never shows one, so
// the design canvas and the debug editor show what the published app shows.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('an unsqueezed overflowing row keeps its children and reports no overflow', (tester) async {
    final nodes = <String, Map<String, Object?>>{
      'r': {
        'type': 'column',
        'children': ['row'],
        'layout': {'width': 300, 'height': 200, 'padding': [10, 0, 10, 0]},
        'props': {'crossAxisAlignment': 'start'},
      },
      'row': {
        'type': 'row',
        'children': ['a', 'gap', 'b'],
        'layout': {'width': {'hug': 0}, 'height': {'hug': 0}},
        'props': {'crossAxisAlignment': 'start', 'squeezeChildren': false},
      },
      'a': {'type': 'box', 'layout': {'width': 200, 'height': 50}, 'decoration': {'fills': [{'color': '#FF000000'}]}},
      'gap': {'type': 'box', 'layout': {'width': 20, 'height': 1}},
      'b': {'type': 'box', 'layout': {'width': 120, 'height': 50}, 'decoration': {'fills': [{'color': '#FF000000'}]}},
    };
    final tree = NodeTree(DocumentSource(LayoutDocument.fromJson({'roots': ['r'], 'nodes': nodes})));
    addTearDown(tree.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'r')),
    ));
    expect(tester.takeException(), isNull, reason: 'no overflow error');
    final view = tester.renderObject(find.byType(NodeView));
    expect(tree.boxOf('a')!.rectIn(view)!.left, 10);
    expect(tree.boxOf('b')!.rectIn(view)!.left, 230);
    expect(tree.boxOf('b')!.rectIn(view)!.width, 120);
  });
}
