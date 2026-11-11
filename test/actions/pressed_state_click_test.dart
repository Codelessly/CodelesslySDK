// A node with a pressed state (a cap that sinks while held) still runs its
// click: the state patch applied on pointer down must not drop the tap.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

import 'wiring_test.dart' show show, reaction, v, add;

void main() {
  testWidgets('a cap with a pressed state sinks while held and still clicks', (tester) async {
    final s = await show(tester, {
      'col': {'type': 'column', 'children': ['cap'], 'layout': {'width': 200, 'height': 100}},
      'cap': {
        'type': 'row', 'children': ['label'],
        'layout': {'width': 120, 'height': 40},
        'decoration': {'fills': [{'color': '#FF4A413A'}], 'radius': 6, 'effects': [{'type': 'dropShadow', 'color': '#88000000', 'offset': [0, 3], 'blurRadius': 3}]},
        'states': {'pressed': {'cap': {'motion': {'translateY': 1.5}, 'decoration': {'effects': [{'type': 'dropShadow', 'color': '#66000000', 'offset': [0, 1], 'blurRadius': 1}]}}}},
        'actions': [reaction('click', [add('clicks')])],
      },
      'label': {'type': 'text', 'layout': {'width': {'hug': 40}, 'height': {'hug': 14}}, 'props': {'text': 'LATCH'}},
    }, variables: [v('clicks', 0, VariableType.integer)]);
    final view = tester.renderObject(find.byType(NodeView));
    final at = tester.getTopLeft(find.byType(NodeView)) + s.tree.boxOf('cap')!.rectIn(view)!.center;
    final g = await tester.startGesture(at);
    await tester.pump(const Duration(milliseconds: 50));
    await g.up();
    await tester.pump();
    expect(s['clicks'], 1);
    await tester.tapAt(at);
    await tester.pump();
    expect(s['clicks'], 2);
  });
}
