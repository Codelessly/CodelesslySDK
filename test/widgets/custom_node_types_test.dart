// An app's own node types: recipes given to a tree (NodeTree.recipes,
// CodelesslyConfig.recipes), using only the package's public library.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A rating row: its `stars` prop as icons, then its child nodes.
void _rating(NodeBuilder b, Node n, List<RenderBox> chain) {
  chain.add(b.fitBox('fit', n.layout.width.fit, n.layout.height.fit, Size(n.layout.width.value, n.layout.height.value)));
  chain.add(b.island('rating', (context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < (n.props.unknown['stars'] as num? ?? 0); i++) const Icon(Icons.star, size: 10),
          for (final c in n.children) NodeChild(tree: b.tree, id: c, instance: b.instance),
        ],
      )));
}

LayoutDocument _doc({int stars = 3}) => LayoutDocument.fromJson({
      'roots': ['s'],
      'nodes': {
        's': {'type': 'stack', 'children': ['r', 'd'], 'layout': {'width': 300, 'height': 200}},
        'r': {
          'type': 'acme.rating',
          'children': ['label'],
          'props': {'stars': stars},
          'layout': {'width': {'hug': 0}, 'height': {'hug': 0}, 'x': {'start': 10}, 'y': {'start': 20}},
        },
        'label': {'type': 'box', 'layout': {'width': 40, 'height': 10}},
        'd': {'type': 'divider', 'layout': {'width': 100, 'height': 16, 'x': {'start': 0}, 'y': {'start': 100}}},
      },
    });

Widget _app(NodeTree tree) => MaterialApp(home: Center(child: NodeView(tree: tree, rootId: 's')));

void main() {
  testWidgets('a node type the model does not know is built by the app\'s builder for it', (tester) async {
    final source = DocumentSource(_doc());
    final tree = NodeTree(source, recipes: {'acme.rating': _rating});
    await tester.pumpWidget(_app(tree));
    final view = tester.renderObject(find.byType(NodeView));
    expect(find.byIcon(Icons.star), findsNWidgets(3));
    expect(tree.boxOf('r')!.rectIn(view), const Rect.fromLTWH(10, 20, 70, 10));
    expect(tree.boxOf('label')!.rectIn(view), const Rect.fromLTWH(40, 20, 40, 10));

    // Its props are data like any node's: a new document, a new build.
    source.document = _doc(stars: 5);
    await tester.pump();
    expect(find.byIcon(Icons.star), findsNWidgets(5));
    expect(tree.boxOf('r')!.rectIn(view), const Rect.fromLTWH(10, 20, 90, 10));
  });

  testWidgets('without a builder an unknown node type is an empty box of its size', (tester) async {
    final tree = NodeTree(DocumentSource(_doc()));
    await tester.pumpWidget(_app(tree));
    expect(find.byIcon(Icons.star), findsNothing);
    expect(tree.boxOf('r'), isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an app\'s builder replaces a built-in type, for that app only', (tester) async {
    final tree = NodeTree(DocumentSource(_doc()), recipes: {
      'acme.rating': _rating,
      'divider': (b, n, chain) => chain.add(b.island('mine', (context) => const Text('divider'))),
    });
    await tester.pumpWidget(_app(tree));
    expect(find.text('divider'), findsOneWidget);

    await tester.pumpWidget(_app(NodeTree(DocumentSource(_doc()))));
    await tester.pump();
    expect(find.text('divider'), findsNothing);
  });

  testWidgets('an app-defined node\'s props bind like any other\'s', (tester) async {
    final doc = LayoutDocument.fromJson({
      ..._doc().toJson(),
      'nodes': {
        ..._doc().toJson()['nodes'] as Map,
        'r': {...(_doc().toJson()['nodes'] as Map)['r'] as Map, 'bind': {'props.stars': r'${count}'}},
      },
    });
    final scope = VariableScope([Variable(name: 'count', type: VariableType.integer, value: 2)]);
    final tree = NodeTree(DocumentSource(doc), binder: NodeBinder(scope: scope), recipes: {'acme.rating': _rating});
    await tester.pumpWidget(_app(tree));
    expect(find.byIcon(Icons.star), findsNWidgets(2));
    scope.set('count', 4);
    await tester.pump();
    expect(find.byIcon(Icons.star), findsNWidgets(4));
  });

}
