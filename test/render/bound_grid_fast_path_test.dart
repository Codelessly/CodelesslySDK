// A grid of bound cells (Petri's board: 2,304 boxes whose fill is
// `${pal[item]}`) costs what its changed cells cost: a changed item
// repaints its box without re-applying or laying out anything, an
// unchanged one does nothing, and a transparent fill draws nothing.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Variable v(String name, Object? value, VariableType type) => Variable(name: name, type: type, value: type.coerce(value));

class _Counts implements NodeTreeObserver {
  int laidOut = 0;
  @override
  void nodeLaidOut(NodeBox box) => laidOut++;
  @override
  void nodePainted(NodeBox box) {}
}

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

void main() {
  tearDown(() {
    NodeBox.debugCountApplies = false;
    NodeBox.debugApplyCounts.clear();
  });

  testWidgets('a changed cell repaints its box only: no re-apply, no layout', (tester) async {
    final (tree, scope) = await show(tester);
    expect(fillOf(tree, 5), const Color(0xFF55358A));
    final counts = _Counts();
    tree.observer = counts;
    NodeBox.debugCountApplies = true;
    final next = [...(scope.read('cells') as List)]..[5] = 2;
    scope.set('cells', next);
    await tester.pump();
    expect(fillOf(tree, 5), const Color(0xFF3B7CA3));
    expect(NodeBox.debugApplyCounts, isEmpty, reason: 'the grid and the cells were not re-applied');
    expect(counts.laidOut, 0, reason: 'a fill change lays nothing out');
  });

  testWidgets('a transparent fill draws nothing', (tester) async {
    final (tree, _) = await show(tester);
    expect(fillOf(tree, 4), isNull);
    expect(fillOf(tree, 3), const Color(0xFF55358A));
  });

  testWidgets('a cell going transparent stops drawing, and back', (tester) async {
    final (tree, scope) = await show(tester);
    scope.set('cells', [...(scope.read('cells') as List)]..[3] = 0);
    await tester.pump();
    expect(fillOf(tree, 3), isNull);
    scope.set('cells', [...(scope.read('cells') as List)]..[3] = 1);
    await tester.pump();
    expect(fillOf(tree, 3), const Color(0xFF55358A));
  });

  testWidgets('a new item count re-syncs the grid', (tester) async {
    final (tree, scope) = await show(tester);
    scope.set('cells', [for (var i = 0; i < 8; i++) 2]);
    await tester.pump();
    expect(tree.boxOf('cell', instance: cellInstance(7)), isNotNull);
    expect(fillOf(tree, 7), const Color(0xFF3B7CA3));
  });

  testWidgets('a change beyond a fill still re-applies the cell', (tester) async {
    final (tree, scope) = await show(tester, cellExtra: {'opacity': r'${= w / 10}'});
    NodeBox.debugCountApplies = true;
    scope.set('w', 5);
    await tester.pump();
    expect(NodeBox.debugApplyCounts['cell'], 16);
    RenderOpacity? found;
    void visit(RenderObject o) {
      if (o is RenderOpacity) found ??= o;
      o.visitChildren(visit);
    }

    visit(tree.boxOf('cell', instance: cellInstance(2))!);
    expect(found?.opacity, 0.5);
  });
}
