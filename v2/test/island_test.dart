import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/recipe.dart';
import 'package:codelessly_sdk/src/widgets/registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a recipe can host a widget island with a node inside', (tester) async {
    widgetRecipes['testButton'] = (b, n, chain) {
      chain.add(b.island('button', (context) => Padding(
            padding: const EdgeInsets.all(5),
            child: NodeChild(tree: b.tree, id: n.children.first),
          )));
    };
    addTearDown(() => widgetRecipes.remove('testButton'));
    final doc = LayoutDocument.fromJson({
      'roots': ['s'],
      'nodes': {
        's': {'type': 'stack', 'children': ['btn'], 'layout': {'width': 300, 'height': 200}},
        'btn': {'type': 'testButton', 'children': ['label'], 'layout': {'width': {'hug': 0}, 'height': {'hug': 0}, 'x': {'start': 10}, 'y': {'start': 20}}},
        'label': {'type': 'box', 'layout': {'width': 40, 'height': 16}},
      },
    });
    final source = DocumentSource(doc);
    final tree = NodeTree(source);
    await tester.pumpWidget(MaterialApp(home: Center(child: NodeView(tree: tree, rootId: 's'))));
    final view = tester.renderObject(find.byType(NodeView));
    expect(tree.boxOf('btn')!.rectIn(view), const Rect.fromLTWH(10, 20, 50, 26));
    expect(tree.boxOf('label')!.rectIn(view), const Rect.fromLTWH(15, 25, 40, 16));

    // An edit to the node inside re-lays out through the island.
    source.document = doc.copyWith(nodes: {
      ...doc.nodes,
      'label': doc['label']!.copyWith(layout: doc['label']!.layout.copyWith(width: const AxisSize.fixed(60))),
    });
    await tester.pump();
    expect(tree.boxOf('btn')!.rectIn(view)!.width, 70);
    await tester.pumpWidget(const SizedBox());
    tree.dispose();
  });
}
