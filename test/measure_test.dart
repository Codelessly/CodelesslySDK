// A node's laid-out box written to a variable (Strata v2: the timeline's
// "you are here" marker travels to the chip of the reader's layer; chips
// are laid out by data, so the marker reads where they ended up).
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

import 'actions/wiring_test.dart' as wiring show show;

Map<String, Json> page() => {
      'col': {
        'type': 'column',
        'layout': {'width': 300, 'height': {'hug': 10}, 'padding': [10, 20, 10, 20]},
        'children': ['top', 'list'],
      },
      'top': {'type': 'box', 'layout': {'width': 100, 'height': 40}},
      'list': {
        'type': 'listView',
        'props': {'scrollable': false},
        'layout': {'width': {'fill': 280}, 'height': {'hug': 100}},
        'bind': {'data': r'${rows}'},
        'children': ['chip'],
      },
      'chip': {
        'type': 'box',
        'layout': {'width': 120, 'height': 30},
        'measure': {'variable': 'boxes', 'relativeTo': 'col'},
        'bind': {'measure.key': r'${item.id}'},
      },
    };

const rows = Variable(name: 'rows', type: VariableType.list, value: [
  {'id': 'a'},
  {'id': 'b'},
]);

void main() {
  for (final interactive in [true, false]) {
    testWidgets('each copy writes its box under its key (interactive: $interactive)', (tester) async {
      final s = await wiring.show(tester, page(), interactive: interactive, variables: [
        rows,
        const Variable(name: 'boxes', type: VariableType.map, value: <String, Object?>{}),
      ]);
      await tester.pump();
      final boxes = s['boxes'] as Map;
      expect(boxes['a'], {'x': 90.0, 'y': 60.0, 'width': 120.0, 'height': 30.0, 'centerX': 150.0, 'centerY': 75.0});
      expect((boxes['b'] as Map)['y'], 90.0);
    });
  }
}
