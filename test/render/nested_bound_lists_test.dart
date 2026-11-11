// A list of items each holding a grid bound to `${item.cells}` (Petri's
// pattern tiles with live previews): every inner cell reads its own item.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Variable v(String name, Object? value, VariableType type) => Variable(name: name, type: type, value: type.coerce(value));

Color? fillOf(NodeTree tree, String id, Object? instance) {
  Color? found;
  void visit(RenderObject o) {
    if (found == null && o is RenderDecoratedBox && o.decoration is BoxDecoration) {
      final c = (o.decoration as BoxDecoration).color;
      if (c != null) found = c;
    }
    o.visitChildren(visit);
  }

  visit(tree.boxOf(id, instance: instance)!);
  return found;
}

void main() {
  for (final interactive in [false, true]) {
    testWidgets('inner cells read their own items (interactive: $interactive)', (tester) async {
      final doc = LayoutDocument.fromJson({
        'roots': ['tiles'],
        'nodes': {
          'tiles': {
            'type': 'listView',
            'children': ['mini'],
            'layout': {'width': 200, 'height': {'hug': 100}},
            'props': {'scrollable': false},
            'bind': {'data': r'${ps}'},
          },
          'mini': {
            'type': 'gridView',
            'children': ['cell'],
            'layout': {'width': 30, 'height': 10},
            'props': {'crossAxisCount': 3, 'scrollable': false},
            'bind': {'data': r'${item.cells}'},
          },
          'cell': {
            'type': 'box',
            'layout': {'width': 10, 'height': 10},
            'decoration': {'fills': [{'color': '#FF000000'}]},
            'bind': {'decoration.fills[0]': r"${= item == 1 ? '#FFFF0000' : '#FF00FF00'}"},
          },
        },
      });
      final scope = VariableScope([
        v('ps', [
          {'cells': [1, 0, 1]},
          {'cells': [0, 1, 0]},
        ], VariableType.list),
      ]);
      final tree = NodeTree(NodeValues(DocumentSource(doc)), binder: NodeBinder(scope: scope));
      addTearDown(tree.dispose);
      await tester.pumpWidget(MaterialApp(
        home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'tiles', interactive: interactive)),
      ));
      await tester.pump();
      const red = Color(0xFFFF0000), green = Color(0xFF00FF00);
      final second = ('item', null, 'tiles', 1);
      expect(fillOf(tree, 'cell', null), red);
      expect(fillOf(tree, 'cell', ('item', null, 'mini', 1)), green);
      expect(fillOf(tree, 'cell', ('item', null, 'mini', 2)), red);
      expect(fillOf(tree, 'cell', second), green);
      expect(fillOf(tree, 'cell', ('item', second, 'mini', 1)), red);
    });
  }
}
