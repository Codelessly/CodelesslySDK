// A drag handle (draggable on press) inside a list item whose own draggable
// is disabled (long press, phones only), inside a clickable card: dragging
// the handle starts the drag.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/runtime/gestures/drag_and_drop.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../actions/wiring_test.dart' show show, v;

void main() {
  for (final kind in [PointerDeviceKind.mouse, PointerDeviceKind.touch])
  for (final scrolls in [false, true])
  for (final outerEnabled in [false, null])
  testWidgets('a handle drags inside an item whose own draggable is ${outerEnabled == null ? 'absent' : 'disabled'} (scrolling page: $scrolls, ${kind.name})',
      (tester) async {
    final s = await show(
      tester,
      {
        // A scrolling page, as a form builder's canvas is.
        'col': {'type': 'column', 'children': ['list'], 'layout': {'width': 300, 'height': 400}, 'props': {'scrollable': scrolls}},
        'list': {
          'type': 'listView',
          'children': ['item'],
          'layout': {'width': 300, 'height': {'hug': 0}},
          'bind': {'data': r'${items}'},
          'props': {'scrollable': false},
          'dropTarget': {'accepts': ['card'], 'key': 'canvas', 'listNodeId': 'list'},
        },
        'item': {
          'type': 'column',
          'children': ['card', 'ghost'],
          'layout': {'width': {'fill': 0}, 'height': {'hug': 0}},
          if (outerEnabled != null)
            'draggable': {'group': 'card', 'data': r'${item}', 'start': 'longPress', 'enabled': outerEnabled,
                          'whileDragging': 'hidden', 'feedbackNodeId': 'ghost'},
        },
        'card': {
          'type': 'row',
          'children': ['handle', 'label'],
          'layout': {'width': {'fill': 0}, 'height': 50},
          'actions': [
            {'trigger': {'type': 'click'}, 'actions': [{'type': 'setVariable', 'variable': 'picked', 'value': r'${item}'}]},
          ],
        },
        // No fill of its own: only its icon takes the press.
        'handle': {
          'type': 'row',
          'children': ['grip'],
          'layout': {'width': 24, 'height': 24},
          'props': {'mainAxisAlignment': 'center'},
          'draggable': {'group': 'card', 'data': r'${item}', 'start': 'press', 'whileDragging': 'hidden',
                        'feedbackNodeId': 'ghost', 'feedbackElevation': 16},
        },
        'grip': {
          'type': 'icon',
          'layout': {'width': 18, 'height': 18},
          'props': {'icon': {'type': 'MATERIAL_ICON', 'name': 'drag_indicator', 'style': 'rounded', 'size': 18}},
        },
        // The lifted chip a drag shows (hidden at rest).
        'ghost': {'type': 'box', 'visible': false, 'layout': {'width': 120, 'height': 30}},
        'label': {'type': 'text', 'layout': {'width': 100, 'height': 20}, 'props': {'text': r'${item}'}},
      },
      variables: [v('items', ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j'], VariableType.list), v('picked', '')],
    );
    await tester.pumpAndSettle();
    final handle = s.tree.boxOf('handle', instance: ('item', null, 'list', 2)) ?? s.tree.boxOf('handle')!;
    final at = handle.localToGlobal(handle.size.center(Offset.zero));
    final g = await tester.startGesture(at, kind: kind);
    await tester.pump(const Duration(milliseconds: 450));
    for (var i = 1; i <= 8; i++) {
      await g.moveBy(const Offset(0, -12));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(DragAndDrop.of(s.tree).value['active'], isTrue);
    await g.cancel();
    await tester.pumpAndSettle();
  });
}
