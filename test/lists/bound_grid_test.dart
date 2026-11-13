import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

// A grid of bound cells (Petri's board: 2,304 boxes whose fill is
// `${pal[item]}`) costs what its changed cells cost: a changed item
// repaints its box without re-applying or laying out anything, an
// unchanged one does nothing, and a transparent fill draws nothing.

Variable v(String name, Object? value, VariableType type) => Variable(name: name, type: type, value: type.coerce(value));

Map<String, Json> grid({Json cellExtra = const {}}) => {
      'grid': {
        'type': 'gridView',
        'children': ['cell'],
        'layout': {'width': 40, 'height': 40},
        'props': {'crossAxisCount': 4, 'scrollable': false},
        'bind': {'data': r'${cells}'},
      },
      'cell': {
        'type': 'box',
        'layout': {'width': 10, 'height': 10},
        'decoration': {'fills': [{'color': '#FF000000'}]},
        'bind': {'decoration.fills[0]': r'${pal[item]}', ...cellExtra},
      },
    };

Future<(NodeTree, VariableScope)> show(WidgetTester tester, {Json cellExtra = const {}}) async {
  final doc = LayoutDocument.fromJson({'roots': ['grid'], 'nodes': grid(cellExtra: cellExtra)});
  final scope = VariableScope([
    v('cells', [0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1], VariableType.list),
    v('pal', ['#00000000', '#FF55358A', '#FF3B7CA3'], VariableType.list),
    v('w', 10, VariableType.integer),
  ]);
  final tree = NodeTree(NodeValues(DocumentSource(doc)), binder: NodeBinder(scope: scope));
  addTearDown(tree.dispose);
  await tester.pumpWidget(MaterialApp(
    home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'grid', interactive: true)),
  ));
  return (tree, scope);
}

Object? cellInstance(int i) => i == 0 ? null : ('item', null, 'grid', i);

Color? fillOf(NodeTree tree, int i) {
  Color? found;
  void visit(RenderObject o) {
    if (found == null && o is RenderDecoratedBox && o.decoration is BoxDecoration) {
      final c = (o.decoration as BoxDecoration).color;
      if (c != null) found = c;
    }
    o.visitChildren(visit);
  }

  visit(tree.boxOf('cell', instance: cellInstance(i))!);
  return found;
}

// A list of items each holding a grid bound to `${item.cells}` (Petri's
// pattern tiles with live previews): every inner cell reads its own item.

Color? cellFillOf(NodeTree tree, String id, Object? instance) {
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
  group('a grid bound to data', () {
    tearDown(() {
      NodeBox.debugCountApplies = false;
      NodeBox.debugApplyCounts.clear();
    });

    testWidgets('a cell whose bound fill turns transparent stops drawing, and draws again when it returns', (tester) async {
      final (tree, scope) = await show(tester);
      scope.set('cells', [...(scope.read('cells') as List)]..[3] = 0);
      await tester.pump();
      expect(fillOf(tree, 3), isNull);
      scope.set('cells', [...(scope.read('cells') as List)]..[3] = 1);
      await tester.pump();
      expect(fillOf(tree, 3), const Color(0xFF55358A));
    });

    testWidgets('the grid follows a change in the number of items', (tester) async {
      final (tree, scope) = await show(tester);
      scope.set('cells', [for (var i = 0; i < 8; i++) 2]);
      await tester.pump();
      expect(tree.boxOf('cell', instance: cellInstance(7)), isNotNull);
      expect(fillOf(tree, 7), const Color(0xFF3B7CA3));
    });
  });

  group('lists inside lists', () {
    for (final interactive in [false, true]) {
      testWidgets('the items of an inner list read their own data (interactive: $interactive)', (tester) async {
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
        expect(cellFillOf(tree, 'cell', null), red);
        expect(cellFillOf(tree, 'cell', ('item', null, 'mini', 1)), green);
        expect(cellFillOf(tree, 'cell', ('item', null, 'mini', 2)), red);
        expect(cellFillOf(tree, 'cell', second), green);
        expect(cellFillOf(tree, 'cell', ('item', second, 'mini', 1)), red);
      });
    }
  });
}
