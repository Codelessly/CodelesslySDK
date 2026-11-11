// A state style may replace a node's binding (`bind` in the patch): a card
// whose border is bound to its selection keeps that rule while hovered,
// with the hover colour as the fallback, as Flutter code writes
// `selected ? accent : (hover ? strong : line)`.
import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'actions/wiring_test.dart' show show, v;

Map<String, Json> nodes({bool dragged = false}) => {
      'col': {
        'type': 'listView',
        'children': ['card'],
        'layout': {'width': 200, 'height': 300},
        'bind': {'data': r'${items}'},
      },
      'card': {
        'type': 'box',
        'layout': {'width': 200, 'height': 100},
        'decoration': {
          'fills': [{'color': '#FFFFFFFF'}],
          'strokes': [{'color': '#FFDCE0E6'}],
        },
        'bind': {'decoration.strokes[0]': r"${= selected == item ? '#4B4DED' : '#DCE0E6'}"},
        if (dragged) 'draggable': {'group': 'card', 'data': r'${item}', 'start': 'longPress'},
        if (dragged)
          'actions': [
            {
              'trigger': {'type': 'click'},
              'actions': [
                {'type': 'setVariable', 'variable': 'selected', 'value': r'${item}'},
              ],
            },
          ],
        'states': {
          'hovered': {
            'card': {
              'bind': {'decoration.strokes[0]': r"${= selected == item ? '#4B4DED' : '#C5CBD5'}"},
            },
          },
        },
      },
    };

Color stroke(NodeTree tree, Object? instance) => Color(tree.resolve('card', instance: instance)!.decoration.strokes.first.color!.value);

void main() {
  for (final dragged in [false, true]) {
  testWidgets('a hovered state can rebind a bound style, keeping the binding\'s other cases${dragged ? ' (a draggable card with a click)' : ''}', (tester) async {
    final s = await show(tester, nodes(dragged: dragged), variables: [
      v('items', const ['a', 'b'], VariableType.list),
      v('selected', ''),
    ]);
    await tester.pumpAndSettle();
    final boxes = s.tree.boxesOf('card').toList()
      ..sort((x, y) => x.localToGlobal(Offset.zero).dy.compareTo(y.localToGlobal(Offset.zero).dy));
    final first = boxes.first;
    expect(stroke(s.tree, first.instance), const Color(0xFFDCE0E6));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(500, 500));
    addTearDown(mouse.removePointer);
    await mouse.moveTo(first.localToGlobal(const Offset(100, 50)));
    await tester.pump();
    expect(s.tree.statesOf('card', instance: first.instance), {api.WidgetState.hovered});
    // Hovered: the state's binding.
    expect(stroke(s.tree, first.instance), const Color(0xFFC5CBD5));
    // Selected wins while hovered, as the rebinding says.
    s.scope.set('selected', 'a');
    await tester.pump();
    expect(stroke(s.tree, first.instance), const Color(0xFF4B4DED));
    await mouse.moveTo(const Offset(500, 500));
    await tester.pump();
    s.scope.set('selected', '');
    await tester.pump();
    expect(stroke(s.tree, first.instance), const Color(0xFFDCE0E6));
  });
  }

  testWidgets('a card in a running page view (the phone board) takes its hover state', (tester) async {
    final n = nodes(dragged: true);
    final list = n.remove('col')!;
    n['col'] = {
      'type': 'pageView',
      'children': ['page'],
      'layout': {'width': 300, 'height': 400},
      'props': {'viewportFraction': 0.92, 'scrollDirection': 'horizontal'},
      'bind': {'data': r'${lanes}'},
    };
    n['page'] = {
      'type': 'column',
      'children': ['body'],
      'layout': {'width': {'fill': 300}, 'height': {'fill': 400}},
    };
    // The lane's scrolling body around its card list.
    n['body'] = {
      'type': 'column',
      'children': ['list'],
      'layout': {'width': {'fill': 300}, 'height': {'fill': 400}},
      'props': {'scrollable': true, 'crossAxisAlignment': 'stretch'},
    };
    n['list'] = {...list, 'bind': {'data': r'${items}'}, 'props': {'scrollable': false}, 'layout': {'width': {'fill': 276}, 'height': {'hug': 300}}};
    final s = await show(tester, n, variables: [
      v('lanes', const ['x', 'y'], VariableType.list),
      v('items', const ['a', 'b'], VariableType.list),
      v('selected', ''),
    ]);
    await tester.pumpAndSettle();
    final boxes = s.tree.boxesOf('card').where((b) => b.attached).toList()
      ..sort((x, y) => x.localToGlobal(Offset.zero).dy.compareTo(y.localToGlobal(Offset.zero).dy));
    final first = boxes.first;
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(700, 500));
    addTearDown(mouse.removePointer);
    await mouse.moveTo(first.localToGlobal(const Offset(100, 50)));
    await tester.pump();
    expect(s.tree.statesOf('card', instance: first.instance), {api.WidgetState.hovered});
    expect(stroke(s.tree, first.instance), const Color(0xFFC5CBD5));
  });
}
