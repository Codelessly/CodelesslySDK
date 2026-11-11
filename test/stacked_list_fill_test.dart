// A stacked list's item that fills fills the list's box (Strata v2: the
// canyon cross-section is a stacked list of layers, each item a stack of
// two walls in a 400x300 viewBox, drawn in a 350x262 box).
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

import 'actions/wiring_test.dart' as wiring show show;

Map<String, Json> nodes(Json itemLayout) => {
      'list': {
        'type': 'listView',
        'props': {'layout': 'stack', 'scrollable': false},
        'layout': {'width': 350, 'height': 262},
        'bind': {'data': r'${rows}'},
        'children': ['item'],
      },
      'item': {'type': 'stack', 'layout': itemLayout},
    };

const rows = Variable(name: 'rows', type: VariableType.list, value: [
  {'id': 'a'},
  {'id': 'b'},
]);

void main() {
  for (final interactive in [true, false]) {
    testWidgets('fill items take the list box (interactive: $interactive)', (tester) async {
      final s = await wiring.show(tester, nodes({'width': {'fill': 400}, 'height': {'fill': 300}}),
          root: 'list', variables: [rows], interactive: interactive);
      final boxes = s.tree.boxesOf('item').toList();
      expect(boxes, hasLength(2));
      for (final b in boxes) {
        expect(b.size.width, closeTo(350, .01));
        expect(b.size.height, closeTo(262, .01));
      }
    });
  }

  testWidgets('fixed items keep their size, even past the box', (tester) async {
    final s = await wiring.show(tester, nodes({'width': 500, 'height': 100}), root: 'list', variables: [rows]);
    for (final b in s.tree.boxesOf('item')) {
      expect(b.size.width, closeTo(500, .01));
      expect(b.size.height, closeTo(100, .01));
    }
  });
}
