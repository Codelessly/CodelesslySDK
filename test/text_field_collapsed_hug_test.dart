// A collapsed text field that hugs its height is one line tall (Strata v2:
// the glossary's search field sits in a 52 px outlined row). Under
// IntrinsicHeight Flutter's TextField reported the 48 px interactive
// minimum, so the field was 48 tall with its text at the top.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

import 'actions/wiring_test.dart' as wiring show show;

Map<String, Json> field(bool collapsed) => {
      'col': {'type': 'column', 'layout': {'width': 300, 'height': {'hug': 10}}, 'children': ['tf']},
      'tf': {
        'type': 'textField',
        'layout': {'width': {'fill': 300}, 'height': {'hug': 20}},
        'props': {
          'style': {'fontSize': 17, 'height': 1.2},
          'decoration': {'isCollapsed': collapsed, 'hintText': 'Search'},
        },
      },
    };

void main() {
  for (final interactive in [true, false]) {
    testWidgets('collapsed: one line tall (interactive: $interactive)', (tester) async {
      final s = await wiring.show(tester, field(true), interactive: interactive);
      await tester.pump();
      expect(s.tree.boxOf('tf')!.size.height, closeTo(17 * 1.2, 1));
    });
  }

  testWidgets('a decorated field keeps its height', (tester) async {
    final s = await wiring.show(tester, field(false));
    await tester.pump();
    expect(s.tree.boxOf('tf')!.size.height, greaterThanOrEqualTo(48));
  });
}
