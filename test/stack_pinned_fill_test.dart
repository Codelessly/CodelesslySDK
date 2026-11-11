import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a fill child pinned top and bottom takes the stack height less its insets', (tester) async {
    final doc = LayoutDocument.fromJson({
      'roots': ['root'],
      'nodes': {
        'root': {'type': 'column', 'children': ['line'], 'layout': {'width': 300, 'height': {'hug': 0}}, 'props': {'crossAxisAlignment': 'stretch'}},
        'line': {'type': 'row', 'children': ['s'], 'layout': {'width': {'fill': 0}, 'height': {'hug': 0}}},
        's': {
          'type': 'stack',
          'children': ['halves'],
          'layout': {'width': {'fill': 1}, 'height': 14, 'flex': 1},
        },
        'halves': {
          'type': 'row',
          'children': ['a'],
          'layout': {
            'width': {'fill': 0},
            'height': {'fill': 0},
            'x': {'start': 0, 'end': 0},
            'y': {'start': 3, 'end': 3},
          },
        },
        'a': {'type': 'box', 'layout': {'width': {'fill': 1}, 'height': {'fill': 0}, 'flex': 1}},
      },
    });
    final tree = NodeTree(DocumentSource(doc));
    await tester.pumpWidget(MaterialApp(home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'root'))));
    await tester.pump();
    expect(tree.boxOf('s')!.size.height, 14);
    expect(tree.boxOf('halves')!.size.height, 8);
    expect(tree.boxOf('a')!.size.height, 8);
    expect(tree.boxOf('root')!.size.height, 14);
    await tester.pumpWidget(const SizedBox());
    tree.dispose();
  });
}
