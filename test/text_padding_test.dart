// A text node's layout.padding (Strata v2: a specimen's paragraphs, each a
// list item with 14 px below it).
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

import 'actions/wiring_test.dart' as wiring show show;

Json _text(Json layout) => {'type': 'text', 'layout': layout, 'props': {'text': 'Hi', 'style': {'fontSize': 10, 'height': 1.6}}};

void main() {
  testWidgets('padding adds to a hugging text and sits inside a fixed one', (tester) async {
    final s = await wiring.show(tester, {
      'col': {'type': 'column', 'layout': {'width': 200, 'height': {'hug': 10}}, 'children': ['a', 'b', 'c']},
      'a': _text({'width': {'fill': 200}, 'height': {'hug': 10}, 'padding': [0, 0, 0, 14]}),
      'b': _text({'width': {'hug': 10}, 'height': {'hug': 10}, 'padding': [8, 4, 8, 4]}),
      'c': _text({'width': 120, 'height': 40, 'padding': [10, 10, 10, 10]}),
    });
    expect(s.tree.boxOf('a')!.size.height, closeTo(16 + 14, .01));
    expect(s.tree.boxOf('b')!.size.height, closeTo(16 + 8, .01));
    expect(s.tree.boxOf('c')!.size.width, closeTo(120, .01));
    expect(s.tree.boxOf('c')!.size.height, closeTo(40, .01));
  });

  testWidgets('without padding, unchanged', (tester) async {
    final s = await wiring.show(tester, {
      'col': {'type': 'column', 'layout': {'width': 200, 'height': {'hug': 10}}, 'children': ['a']},
      'a': _text({'width': {'fill': 200}, 'height': {'hug': 10}}),
    });
    expect(s.tree.boxOf('a')!.size.height, closeTo(16, .01));
  });
}
