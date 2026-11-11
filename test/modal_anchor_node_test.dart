// openModal anchored to a named node (`anchor: node`): a menu opened from a
// keyboard shortcut or a screen's load sits by a node, in a list by the copy
// built for an item (Tack: a column's menu opened by its link, by that column).
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'actions/wiring_test.dart' as wiring show show;

Map<String, Json> page(Json open, {String trigger = 'click'}) => {
      'col': {
        'type': 'column',
        'layout': {'width': 400, 'height': 400},
        'children': ['go', 'list'],
        if (trigger == 'load')
          'actions': [
            {
              'trigger': {'type': 'load'},
              'actions': [open],
            },
          ],
      },
      'go': {
        'type': 'box',
        'layout': {'width': 400, 'height': 40},
        if (trigger == 'click')
          'actions': [
            {
              'trigger': {'type': 'click'},
              'actions': [open],
            },
          ],
      },
      'list': {
        'type': 'listView',
        'props': {'scrollable': false, 'scrollDirection': 'horizontal'},
        'layout': {'width': 400, 'height': 300},
        'bind': {'data': r'${lanes}'},
        'children': ['lane'],
      },
      'lane': {
        'type': 'box',
        'layout': {'width': 100, 'height': 300},
      },
    };

const lanes = Variable(name: 'lanes', type: VariableType.list, value: [
  {'id': 'todo'},
  {'id': 'doing'},
  {'id': 'done'},
]);

void main() {
  NavigatorActionUi ui(WidgetTester tester) => NavigatorActionUi(
        context: () => tester.element(find.byType(NodeView)),
        modal: (to, params) => SizedBox(key: ValueKey(to), width: 120, height: 80),
      );
  // Tack's column menu by its link: the lane's right - 200, its top + 40.
  const open = {
    'type': 'openModal',
    'to': 'menu',
    'anchor': 'node',
    'anchorNode': 'lane',
    'anchorItem': r'${laneId}',
    'placement': 'rightStart',
    'anchorGap': -60,
    'anchorOffset': 40,
  };

  testWidgets('a popover anchored to a named node sits by the copy for its item', (tester) async {
    final s = await wiring.show(tester, page(open),
        variables: [lanes, const Variable(name: 'laneId', value: 'doing')], ui: ui(tester));
    await tester.tapAt(s.center('go'));
    await tester.pumpAndSettle();
    final lane = s.tree.boxesOf('lane').elementAt(1);
    final rect = lane.localToGlobal(Offset.zero) & lane.size;
    expect(rect.left, 100, reason: 'the second copy is the doing lane');
    expect(tester.getTopLeft(find.byKey(const ValueKey('menu'))), Offset(rect.right - 60, rect.top + 40));
  });

  testWidgets('from load, it waits for the node to lay out', (tester) async {
    late Offset at;
    final s = await wiring.show(tester, page(open, trigger: 'load'),
        variables: [lanes, const Variable(name: 'laneId', value: 'done')], ui: ui(tester));
    await tester.pumpAndSettle();
    final lane = s.tree.boxesOf('lane').elementAt(2);
    at = lane.localToGlobal(Offset.zero);
    expect(tester.getTopLeft(find.byKey(const ValueKey('menu'))), Offset(at.dx + 100 - 60, at.dy + 40));
  });

  testWidgets('a node that is not there: the modal opens as a dialog', (tester) async {
    await wiring.show(tester, page({...open, 'anchorNode': 'missing'}),
        variables: [lanes, const Variable(name: 'laneId', value: 'doing')], ui: ui(tester));
    await tester.tapAt(const Offset(200, 20));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('menu')), findsOneWidget);
  });
}
