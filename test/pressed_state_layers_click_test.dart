// A node whose `pressed` state style changes its own layers (a scale, an
// opacity) still gets its click: the press re-parents its reactions box,
// which used to drop the tap recognizer mid-gesture (Ninefold v2's number
// pad keys never placed a digit).
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

import 'actions/wiring_test.dart' show show, v;

void main() {
  for (final patch in [
    {'scale': 0.97, 'opacity': 0.8},
    {'opacity': 0.5},
    {'scale': 0.9},
  ]) {
    testWidgets('a pressed style $patch keeps the click', (tester) async {
      final screen = await show(tester, {
        'col': {'type': 'column', 'layout': {'width': 200, 'height': 200}, 'children': ['btn']},
        'btn': {
          'type': 'stack',
          'layout': {'width': 100, 'height': 40},
          'decoration': {'fills': [{'color': '#FFFFFFFF'}]},
          'states': {'pressed': {'btn': patch}},
          'actions': [
            {'trigger': {'type': 'click'}, 'actions': [{'type': 'setVariable', 'variable': 'count', 'op': 'add', 'value': '1'}]},
          ],
        },
      }, variables: [v('count', 0, VariableType.integer)]);
      await tester.tapAt(screen.center('btn'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(screen['count'], 1);
      await tester.tapAt(screen.center('btn'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(screen['count'], 2);
    });
  }
}
