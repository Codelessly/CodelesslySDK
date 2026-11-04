// A row/column that hugs its cross axis and stretches its children
// (RenderHugCross) relays out when a stretched child's content changes:
// incremental relayout gives what a fresh render gives.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Map<String, Object?>> _nodes({required bool tall, double b = 30}) => {
      'r': {
        'type': 'row',
        'children': ['c', 'side'],
        'layout': {'width': 300, 'height': {'hug': 0}},
        'props': {'crossAxisAlignment': 'stretch'},
      },
      // Fills the row's main axis and is stretched across it: tight both
      // ways in the stretch pass.
      'c': {
        'type': 'column',
        'children': [if (tall) 'a', 'b'],
        'layout': {'width': {'fill': 100}, 'height': {'hug': 0}},
      },
      'a': {'type': 'box', 'layout': {'width': 40, 'height': 100}},
      'b': {'type': 'box', 'layout': {'width': 40, 'height': b}},
      'side': {'type': 'box', 'layout': {'width': 50, 'height': {'fill': 10}}},
    };

LayoutDocument _doc({required bool tall, double b = 30}) =>
    LayoutDocument.fromJson({'roots': ['r'], 'nodes': _nodes(tall: tall, b: b)});

Future<Map<String, Rect>> _rects(WidgetTester tester, NodeTree tree) async {
  final view = tester.renderObject(find.byType(NodeView));
  return {for (final id in ['r', 'c', 'b', 'side']) id: tree.boxOf(id)!.rectIn(view)!};
}

Future<NodeTree> _show(WidgetTester tester, DocumentSource source) async {
  final tree = NodeTree(source);
  addTearDown(tree.dispose);
  await tester.pumpWidget(MaterialApp(
    home: Align(alignment: Alignment.topLeft, child: NodeView(key: UniqueKey(), tree: tree, rootId: 'r')),
  ));
  return tree;
}

void main() {
  for (final (from, to) in [(true, false), (false, true)]) {
    testWidgets('a hugging stretch row follows a stretched child that ${from ? 'shrinks' : 'grows'}', (tester) async {
      final fresh = await _rects(tester, await _show(tester, DocumentSource(_doc(tall: to))));

      final source = DocumentSource(_doc(tall: from));
      final tree = await _show(tester, source);
      source.document = _doc(tall: to);
      await tester.pump();
      expect(await _rects(tester, tree), fresh);
      expect(fresh['r']!.height, to ? 130 : 30);
    });
  }

  testWidgets('a hugging stretch row follows a grandchild that shrinks', (tester) async {
    final fresh = await _rects(tester, await _show(tester, DocumentSource(_doc(tall: false, b: 12))));
    final source = DocumentSource(_doc(tall: false));
    final tree = await _show(tester, source);
    source.document = _doc(tall: false, b: 12);
    await tester.pump();
    expect(await _rects(tester, tree), fresh);
    expect(fresh['r']!.height, 12);
  });
}
