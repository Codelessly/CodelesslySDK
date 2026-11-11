// motion.replayKey: a change of the key replays the entrance (after its
// delay, through its keyframes), as Rota's auto-fill drops shifts into
// their cells one after another and a refused drop shakes its chip.
import 'package:codelessly_api/codelessly_api.dart' show Json, LayoutDocument, Variable, VariableType;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Future<(VariableScope, NodeTree, RenderObject)> _show(WidgetTester tester, Map<String, Json> nodes) async {
  final scope = VariableScope(const [
    Variable(name: 'stamp', type: VariableType.integer, value: 0),
    Variable(name: 'shake', type: VariableType.text, value: ''),
  ]);
  final tree = NodeTree(
    DocumentSource(LayoutDocument.fromJson({
      'roots': ['s'],
      'nodes': {
        's': {'type': 'stack', 'children': nodes.keys.toList(), 'layout': {'width': 400, 'height': 300}},
        ...nodes,
      },
    })),
    binder: NodeBinder(scope: scope),
  );
  addTearDown(tree.dispose);
  await tester.pumpWidget(MaterialApp(
    home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 's', interactive: true)),
  ));
  return (scope, tree, tester.renderObject(find.byType(NodeView)));
}

void main() {
  testWidgets('a new replay key replays the entrance after its delay', (tester) async {
    final (scope, tree, view) = await _show(tester, {
      'chip': {
        'type': 'box',
        'layout': {'width': 40, 'height': 20, 'x': {'start': 0}, 'y': {'start': 100}},
        'motion': {'enter': true, 'enterFrom': {'translateY': -100}, 'duration': 400, 'delay': 200, 'curve': 'linear'},
        'bind': {'motion.replayKey': r"${= 'fill' + stamp}"},
      },
    });
    double top() => tree.boxOf('chip')!.rectIn(view)!.top;
    // The first entrance plays when it appears.
    await tester.pump();
    expect(top(), 0);
    await tester.pumpAndSettle();
    expect(top(), 100);
    // A new key: back to the start, held through the delay, then in.
    scope.set('stamp', 1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(top(), 0);
    await tester.pump(const Duration(milliseconds: 300)); // 200 into the 400 ms run
    expect(top(), closeTo(50, 2));
    await tester.pumpAndSettle();
    expect(top(), 100);
    // The same key again does nothing.
    scope.set('stamp', 1);
    await tester.pump(const Duration(milliseconds: 50));
    expect(top(), 100);
  });

  testWidgets('a list item that appears with its replay key set plays its entrance', (tester) async {
    final scope = VariableScope(const [
      Variable(name: 'items', type: VariableType.list, value: []),
      Variable(name: 'stamp', type: VariableType.integer, value: 0),
    ]);
    final tree = NodeTree(
      DocumentSource(LayoutDocument.fromJson({
        'roots': ['list'],
        'nodes': {
          'list': {
            'type': 'listView',
            'children': ['item'],
            'layout': {'width': 200, 'height': 300},
            'bind': {'data': r'${items}'},
          },
          'item': {
            'type': 'text',
            'props': {'text': r'${item}'},
            'layout': {'width': 200, 'height': 40},
            'motion': {'enter': true, 'enterFrom': {'translateY': -100}, 'duration': 400, 'curve': 'linear'},
            'bind': {'motion.replayKey': r"${= 'fill' + stamp}"},
          },
        },
      })),
      binder: NodeBinder(scope: scope),
    );
    addTearDown(tree.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'list', interactive: true)),
    ));
    await tester.pumpAndSettle();
    scope.set('items', ['a', 'b']);
    scope.set('stamp', 1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    // The new item is still coming in from above.
    double? top;
    void visit(RenderObject o) {
      if (o is RenderParagraph && o.text.toPlainText() == 'a') top = o.localToGlobal(Offset.zero).dy;
      o.visitChildren(visit);
    }
    visit(tester.renderObject(find.byType(NodeView)));
    expect(top, lessThan(-50));
    await tester.pumpAndSettle();
  });

  testWidgets('an item that appears in a table cell\'s list plays its entrance', (tester) async {
    final scope = VariableScope(const [
      Variable(name: 'rows', type: VariableType.list, value: [
        {'id': 'r0'},
      ]),
      Variable(name: 'cells', type: VariableType.map, value: {
        'r0': ['z'],
      }),
      Variable(name: 'stamp', type: VariableType.integer, value: 0),
      Variable(name: 'order', type: VariableType.map, value: {}),
    ]);
    final tree = NodeTree(
      DocumentSource(LayoutDocument.fromJson({
        'roots': ['table'],
        'nodes': {
          'table': {
            'type': 'tableView',
            'layout': {'width': 400, 'height': 300},
            'bind': {'data': r'${rows}'},
            'slots': {'cell': 'cell'},
            'props': {
              'columns': [
                {'key': 'c', 'label': 'C'},
              ],
              'columnWidth': 300,
              'rowHeight': 200,
            },
          },
          'cell': {
            'type': 'listView',
            'children': ['item'],
            'layout': {'width': {'fill': 300}, 'height': {'fill': 200}},
            'bind': {'data': r'${= cells[item.row.id]}'},
          },
          'item': {
            'type': 'text',
            'props': {'text': r'${item}'},
            'layout': {'width': 200, 'height': 40},
            'motion': {'enter': true, 'enterFrom': {'translateY': -100, 'opacity': 0, 'scale': 0.7}, 'duration': 400, 'curve': 'linear'},
            'bind': {
              'motion.enter': r"${= order[item] != null}",
              'motion.delay': r"${= 60 + coalesce(order[item], 0) * 45}",
              'motion.replayKey': r"${= order[item] != null ? 'fill' + stamp : ''}",
              'draggable.enabled': r'${= true}',
            },
            'draggable': {'group': 'shift', 'data': r'${item}', 'start': 'auto'},
          },
        },
      })),
      binder: NodeBinder(scope: scope),
    );
    addTearDown(tree.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'table', interactive: true)),
    ));
    await tester.pumpAndSettle();
    double? top(String text) {
      double? at;
      void visit(RenderObject o) {
        if (o is RenderParagraph && o.text.toPlainText() == text) at = o.localToGlobal(Offset.zero).dy;
        o.visitChildren(visit);
      }

      visit(tester.binding.rootElement!.renderObject!);
      return at;
    }

    scope.set('cells', {
      'r0': ['z', 'a'],
    });
    scope.set('order', {'a': 0});
    scope.set('stamp', 1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final coming = top('a');
    await tester.pumpAndSettle();
    expect(coming, isNotNull);
    expect(coming, lessThan(top('a')! - 50));
  });

  testWidgets('keyframes run on a new key: a shake there and back', (tester) async {
    final (scope, tree, view) = await _show(tester, {
      'chip': {
        'type': 'box',
        'layout': {'width': 40, 'height': 20, 'x': {'start': 100}, 'y': {'start': 0}},
        'motion': {
          'duration': 400,
          'curve': 'linear',
          'keyframes': [
            {'t': 0.25, 'translateX': -8},
            {'t': 0.75, 'translateX': 8},
          ],
        },
        'bind': {'motion.replayKey': r'${shake}'},
      },
    });
    double left() => tree.boxOf('chip')!.rectIn(view)!.left;
    await tester.pumpAndSettle();
    expect(left(), 100); // no key, no shake
    scope.set('shake', 'a');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(left(), lessThan(95));
    await tester.pump(const Duration(milliseconds: 200));
    expect(left(), greaterThan(105));
    await tester.pumpAndSettle();
    expect(left(), 100);
  });
}
