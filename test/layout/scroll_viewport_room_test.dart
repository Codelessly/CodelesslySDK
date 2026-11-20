import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// A row that scrolls is a viewport: along its axis it can be any length, so
// in a row with less room than its content it takes the room there is and
// scrolls (a strip of four 110 wide tabs ran 74 px past a 390 wide screen).

Future<(NodeTree, RenderObject)> _show(WidgetTester tester, Map<String, Map<String, Object?>> nodes, String root) async {
  final tree = NodeTree(DocumentSource(LayoutDocument.fromJson({'schema': 3, 'roots': [root], 'nodes': nodes})));
  addTearDown(tree.dispose);
  await tester.pumpWidget(MaterialApp(home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: root))));
  return (tree, tester.renderObject(find.byType(NodeView)));
}

Map<String, Map<String, Object?>> _strip({required double rowWidth}) => {
      'bar': {
        'type': 'row',
        'layout': {'width': rowWidth, 'height': 51},
        'props': {'crossAxisAlignment': 'center'},
        'children': ['tabs'],
      },
      'tabs': {
        'type': 'row',
        'layout': {'width': {'hug': 0}, 'height': 35},
        'props': {'scrollable': true, 'scrollDirection': 'horizontal', 'spacing': 8},
        'children': ['a', 'b', 'c', 'd'],
      },
      for (final id in ['a', 'b', 'c', 'd']) id: {'type': 'box', 'layout': {'width': 110, 'height': 35}},
    };

void main() {
  testWidgets('a hugging row that scrolls, in a row narrower than its content, takes the row\'s room', (tester) async {
    final (tree, view) = await _show(tester, _strip(rowWidth: 390), 'bar');
    expect(tree.boxOf('tabs')!.rectIn(view)!.width, 390);
    expect(tester.takeException(), isNull);
  });

  testWidgets('with room to spare it still hugs its content', (tester) async {
    final (tree, view) = await _show(tester, _strip(rowWidth: 600), 'bar');
    expect(tree.boxOf('tabs')!.rectIn(view)!.width, 4 * 110 + 3 * 8);
  });
}
