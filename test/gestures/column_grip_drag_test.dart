// A column's grip drags it sideways (axis horizontal) across a board that
// scrolls sideways itself: the grip wins the gesture and its feedback
// follows the pointer.
import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/runtime/gestures/drag_and_drop.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Rect textRect(WidgetTester tester, String text, {bool last = false}) {
  final out = <Rect>[];
  void visit(RenderObject o) {
    if (o is RenderParagraph && o.text.toPlainText() == text && o.attached && o.hasSize) {
      out.add(MatrixUtils.transformRect(o.getTransformTo(null), Offset.zero & o.size));
    }
    o.visitChildren(visit);
  }

  visit(tester.binding.rootElement!.renderObject!);
  return last ? out.last : out.first;
}

void main() {
  for (final kind in [PointerDeviceKind.mouse, PointerDeviceKind.touch]) {
    testWidgets('a column grip drags its feedback sideways over a sideways-scrolling board (${kind.name})', (tester) async {
      tester.view.physicalSize = const Size(600, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final doc = api.LayoutDocument.fromJson({
        'roots': ['board'],
        'nodes': {
          'board': {'type': 'column', 'children': ['lanes', 'pill'], 'layout': {'width': 600, 'height': 400}},
          'lanes': {
            'type': 'listView',
            'children': ['col'],
            'layout': {'width': 600, 'height': 360},
            'props': {'scrollDirection': 'horizontal', 'spacing': 12, 'separator': 'space'},
            'bind': {'data': r'${lanes}'},
            'dropTarget': {'accepts': ['lane'], 'key': 'board', 'listNodeId': 'lanes'},
          },
          'col': {
            'type': 'column',
            'children': ['head'],
            'layout': {'width': 250, 'height': 360},
            // Dimmed while its own grip drags it: a layer the drag's start
            // adds, not yet laid out when the drag looks for targets.
            'bind': {'opacity': r"${= drag.active && drag.group == 'lane' && drag.data == item ? 0.4 : 1}"},
            // A drop target for cards, as a board's column is.
            'dropTarget': {'accepts': ['card'], 'key': r'${item}'},
          },
          'head': {
            'type': 'row',
            'children': ['grip', 'name'],
            'layout': {'width': 250, 'height': 40},
          },
          'grip': {
            'type': 'row',
            'layout': {'width': 20, 'height': 20},
            'decoration': {'fills': [{'color': '#FF888888'}]},
            'draggable': {
              'group': 'lane',
              'data': r'${item}',
              'start': 'press',
              'axis': 'horizontal',
              'whileDragging': 'keep',
              'feedbackNodeId': 'pill',
            },
          },
          'name': {'type': 'text', 'layout': {'width': 100, 'height': 20}, 'props': {'text': r'Lane ${item}'}},
          'pill': {
            'type': 'text',
            'visible': false,
            'layout': {'width': 120, 'height': 30},
            'props': {'text': r'Pill ${item}'},
          },
        },
      });
      final values = ValuesScope({'drag': dragIdleValues});
      final scope = VariableScope([
        const Variable(name: 'lanes', type: VariableType.list, value: ['a', 'b', 'c', 'd']),
      ], parent: values);
      final source = NodeValues(DocumentSource(doc));
      final tree = NodeTree(source, binder: NodeBinder(scope: scope));
      final context = RuntimeActionContext(scope: scope, tree: tree, nodeValues: source, services: Services());
      final reactions = TreeReactions(runner: const CodelesslyActions(), context: context);
      tree.interactions = reactions;
      addTearDown(() {
        reactions.dispose();
        tree.dispose();
      });
      await tester.pumpWidget(MaterialApp(
        home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'board', interactive: true)),
      ));
      await tester.pump();
      // The third lane's grip (x ~ 524).
      final grip = textRect(tester, 'Lane c').centerLeft - const Offset(10, 0);
      final g = await tester.startGesture(grip, kind: kind);
      await tester.pump();
      for (var i = 1; i <= 12; i++) {
        await g.moveTo(grip + Offset(-20.0 * i, 8.0 * i));
        await tester.pump();
      }
      final drag = DragAndDrop.of(tree).value;
      expect(drag['active'], isTrue);
      final pill = textRect(tester, 'Pill c', last: true);
      // Grabbed at its left; moved 240 left, not down (horizontal).
      expect(pill.left, lessThan(grip.dx - 200));
      await g.up();
      await tester.pumpAndSettle();
    });
  }
}
