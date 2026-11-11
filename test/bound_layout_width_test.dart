// A layout width bound to an axis size object ({"hug": 0} / {"fill": 1}):
// the first item of a horizontal list hugs, the others fill.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'actions/wiring_test.dart' show show, v;

void main() {
  testWidgets('a bound layout.width of {hug} or {fill} sizes each item', (tester) async {
    final s = await show(
      tester,
      {
        'col': {'type': 'column', 'children': ['path'], 'layout': {'width': 300, 'height': 100}},
        'path': {
          'type': 'listView',
          'children': ['step'],
          'layout': {'width': 300, 'height': {'hug': 0}},
          'props': {'scrollDirection': 'horizontal', 'scrollable': false},
          'bind': {'data': r'${steps}'},
        },
        'step': {
          'type': 'row',
          'children': ['dot'],
          'layout': {'width': {'fill': 0}, 'height': {'hug': 0}},
          'props': {'mainAxisAlignment': 'end'},
          'bind': {'layout.width': r"${= index == 0 ? {'hug': 0} : {'fill': 1}}"},
        },
        'dot': {'type': 'box', 'layout': {'width': 22, 'height': 22}, 'decoration': {'fills': [{'color': '#FF0000FF'}]}},
      },
      variables: [v('steps', [1, 2, 3], VariableType.list)],
    );
    await tester.pumpAndSettle();
    final rects = [
      for (var i = 0; i < 3; i++)
        (s.tree.boxOf('step', instance: ('item', null, 'path', i)) ?? (i == 0 ? s.tree.boxOf('step') : null))?.paintBounds,
    ];
    expect(rects[0]?.width, 22);
    expect(rects[1]?.width, closeTo((300 - 22) / 2, 0.5));
    expect(rects[2]?.width, closeTo((300 - 22) / 2, 0.5));
  });
}
