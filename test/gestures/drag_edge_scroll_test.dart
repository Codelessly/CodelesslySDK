import 'drag_and_drop_test.dart' show textRect;
import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/runtime/gestures/drag_and_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('edge velocity is bounded, smooth and idle outside or in the centre', () {
    expect(dragEdgeScrollVelocity(0, 400), -720);
    expect(dragEdgeScrollVelocity(400, 400), 720);
    expect(dragEdgeScrollVelocity(200, 400), 0);
    expect(dragEdgeScrollVelocity(-1, 400), 0);
    expect(dragEdgeScrollVelocity(401, 400), 0);
    expect(dragEdgeScrollVelocity(1, 0), 0);
    expect(dragEdgeScrollVelocity(24, 400), -180);
    expect(dragEdgeScrollVelocity(376, 400), 180);
    expect(dragEdgeScrollVelocity(15, 30), 0);
  });

  Future<(NodeTree, ScrollController, ScrollController)> board(WidgetTester tester, {bool enabled = true}) async {
    tester.view.physicalSize = const Size(600, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final scope = VariableScope(const []);
    final doc = api.LayoutDocument.fromJson({
      'roots': ['board'],
      'nodes': {
        'board': {
          'type': 'column',
          'children': ['card', 'target'],
          'layout': {'width': 1200, 'height': 1600},
        },
        'card': {
          'type': 'text',
          'layout': {'width': 1200, 'height': 40},
          'props': {'text': 'Drag me'},
          'draggable': {'group': 'shift', 'data': 'shift1', 'start': 'press'},
        },
        'target': {
          'type': 'container',
          'layout': {'width': 1200, 'height': 1560},
          'dropTarget': {
            'accepts': ['shift'],
            'key': 'schedule',
          },
        },
      },
    });
    final tree = NodeTree(DocumentSource(doc), binder: NodeBinder(scope: scope));
    final reactions = TreeReactions(
      runner: const CodelesslyActions(),
      context: RuntimeActionContext(scope: scope, tree: tree, services: Services()),
    );
    tree.interactions = reactions;
    addTearDown(reactions.dispose);
    final h = ScrollController(), v = ScrollController();
    addTearDown(() {
      tree.dispose();
      h.dispose();
      v.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 600,
            height: 400,
            child: SingleChildScrollView(
              controller: h,
              scrollDirection: Axis.horizontal,
              physics: enabled ? null : const NeverScrollableScrollPhysics(),
              child: SizedBox(
                width: 1200,
                height: 400,
                child: SingleChildScrollView(
                  controller: v,
                  physics: enabled ? null : const NeverScrollableScrollPhysics(),
                  child: NodeView(tree: tree, rootId: 'board', interactive: true),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return (tree, h, v);
  }

  testWidgets('a stationary drag scrolls both nested axes and stops when released', (tester) async {
    final (tree, h, v) = await board(tester);
    final gesture = await tester.startGesture(textRect(tester, 'Drag me').center);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();
    await gesture.moveTo(const Offset(60, 20));
    await tester.pump();
    await gesture.moveTo(const Offset(570, 370));
    await tester.pump();
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(h.offset, greaterThan(10));
    expect(v.offset, greaterThan(10));
    expect(DragAndDrop.of(tree).value['over'], 'schedule');
    await gesture.up();
    await tester.pumpAndSettle();
    final after = (h.offset, v.offset);
    await tester.pump(const Duration(seconds: 1));
    expect((h.offset, v.offset), after);
  });

  testWidgets('disabled scroll physics stay still during a drag', (tester) async {
    final (_, h, v) = await board(tester, enabled: false);
    final gesture = await tester.startGesture(textRect(tester, 'Drag me').center);
    await tester.pump(const Duration(milliseconds: 700));
    await gesture.moveTo(const Offset(590, 390));
    await tester.pump();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(h.offset, 0);
    expect(v.offset, 0);
    await gesture.cancel();
    await tester.pumpAndSettle();
  });
  testWidgets('table edge scrolling keeps a virtualised drag alive and reaches later rows', (tester) async {
    tester.view.physicalSize = const Size(600, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final scope = VariableScope(const []);
    final doc = api.LayoutDocument.fromJson({'roots': ['table'], 'nodes': {
      'table': {'type': 'tableView', 'layout': {'width': 600, 'height': 400},
        'props': {'rowCount': 40, 'rowHeight': 80, 'columns': [for (var i=0;i<10;i++) {'key':'c$i', 'label':'Day $i', 'width':150}]},
        'slots': {'cell':'tile'}, 'dropTarget': {'accepts':['shift'], 'key':'table'}},
      'tile': {'type':'text', 'layout':{'width':150,'height':80},
        'props': {'text': r'${item.rowIndex}-${item.columnIndex}'},
        'draggable': {'group':'shift','data':r'${item.rowIndex}','start':'press'}},
    }});
    final tree = NodeTree(DocumentSource(doc), binder: NodeBinder(scope: scope));
    final reactions = TreeReactions(runner: const CodelesslyActions(), context: RuntimeActionContext(scope: scope, tree: tree, services: Services()));
    tree.interactions = reactions;
    addTearDown(() {reactions.dispose();tree.dispose();});
    await tester.pumpWidget(MaterialApp(home:Align(alignment:Alignment.topLeft,child:NodeView(tree:tree,rootId:'table',interactive:true))));
    await tester.pump();
    final gesture = await tester.startGesture(textRect(tester, '0-0').center);
    await tester.pump();
    await gesture.moveBy(const Offset(25,0));await tester.pump();
    await gesture.moveTo(const Offset(590,390));await tester.pump();
    for(var i=0;i<150;i++){await tester.pump(const Duration(milliseconds:16));}
    final state = tester.state<TwoDimensionalScrollableState>(find.byType(TwoDimensionalScrollable));
    expect(state.verticalScrollable.position.pixels,greaterThan(500));
    expect(state.horizontalScrollable.position.pixels,greaterThan(500));
    expect(DragAndDrop.of(tree).value['active'],true);
    expect(DragAndDrop.of(tree).value['over'],'table');
    await gesture.up();await tester.pumpAndSettle();
  });

}
