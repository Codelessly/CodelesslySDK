// A node that styles its pressed state (a button that shrinks while held)
// still runs its click reactions.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

import 'lists/support.dart';

void main() {
  for (final (name, states) in [
    ('scale', {'pressed': {'btn': {'scale': 0.97}}}),
    ('scale + hover fill', {
      'hovered': {'btn': {'decoration': {'fills': [{'color': '#FFDDDBD6'}]}}},
      'pressed': {'btn': {'scale': 0.97}},
    }),
    ('child restyle', {'pressed': {'label': {'props': {'style': {'color': '#FF0E0E10'}}}}}),
  ]) {
    testWidgets('a tap on a node with a pressed state ($name) runs its click', (tester) async {
      final s = await show(
        tester,
        {
          'col': {
            'type': 'column',
            'children': ['btn'],
            'layout': {'width': 300, 'height': 200},
          },
          'btn': {
            'type': 'row',
            'children': ['label'],
            'layout': {'width': 160, 'height': 56},
            'decoration': {'fills': [{'color': '#FFF7F5F0'}]},
            'states': states,
            'actions': [
              reaction('click', [
                {'type': 'setVariable', 'variable': 'taps', 'op': 'add', 'value': '1'},
              ]),
            ],
          },
          'label': {'type': 'text', 'layout': {'width': {'hug': 80}, 'height': {'hug': 20}}, 'props': {'text': 'GO'}},
        },
        variables: [v('taps', 0, VariableType.integer)],
      );
      await tester.pumpAndSettle();
      await tester.tapAt(s.center('btn'));
      await tester.pumpAndSettle();
      expect(s['taps'], 1);
    });
  }
}
