// `semanticLabel` on a switch, a checkbox, a radio and a slider: the name a
// screen reader says, not shown (test 10: writers named controls whose
// visible label is the row's own text; a `label` drew it a second time).
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lists/support.dart' as lists;

void main() {
  testWidgets('a control\'s semanticLabel is what a screen reader says, and nothing shows it', (tester) async {
    final handle = tester.ensureSemantics();
    await lists.show(tester, {
      'col': {
        'type': 'column',
        'layout': {'width': 300, 'height': {'hug': 0}},
        'children': ['wifi', 'tick', 'light'],
      },
      'wifi': {'type': 'switch', 'layout': {'width': 59, 'height': 40}, 'props': {'semanticLabel': 'Wi-Fi'}},
      'tick': {'type': 'checkbox', 'layout': {'width': 40, 'height': 40}, 'props': {'semanticLabel': 'Milk'}},
      'light': {'type': 'slider', 'layout': {'width': 200, 'height': 40}, 'props': {'value': 0.5, 'semanticLabel': 'Light'}},
    });
    final semantics = tester.getSemantics(find.byType(NodeView)).toStringDeep();
    for (final name in ['Wi-Fi', 'Milk', 'Light']) {
      expect(semantics, contains('label: "$name"'), reason: semantics);
      expect(find.text(name), findsNothing, reason: '$name is not shown');
    }
    handle.dispose();
  });
}
