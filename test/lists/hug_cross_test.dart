// A list that scrolls sideways and hugs its height is as tall as its items
// (a row of filter chips), not its design size.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  testWidgets('a horizontal scrolling list hugging its height is as tall as its tallest item', (tester) async {
    final s = await show(tester, {
      'col': {'type': 'column', 'children': ['list'], 'layout': {'width': 360, 'height': 400}},
      'list': {
        'type': 'listView',
        'children': ['chip'],
        'layout': {'width': {'fill': 360}, 'height': {'hug': 10}},
        'props': {'scrollable': true, 'scrollDirection': 'horizontal', 'spacing': 8},
        'bind': {'data': r'${chips}'},
      },
      'chip': {'type': 'box', 'layout': {'width': 120, 'height': 38}},
    }, variables: [v('chips', ['a', 'b', 'c', 'd'], VariableType.list)]);
    final list = s.tree.boxOf('list')!;
    expect(list.size.height, 38);
    expect(list.size.width, 360);
    // Wider than the screen: it still scrolls.
    final state = tester.state<ScrollableState>(find.byType(Scrollable).first);
    expect(state.position.maxScrollExtent, greaterThan(0));
  });

  testWidgets('without data too: a counted sideways list hugs its items\' height', (tester) async {
    final s = await show(tester, {
      'col': {'type': 'column', 'children': ['list'], 'layout': {'width': 360, 'height': 400}},
      'list': {
        'type': 'listView',
        'children': ['chip'],
        'layout': {'width': {'fill': 360}, 'height': {'hug': 10}},
        'props': {'scrollable': true, 'scrollDirection': 'horizontal', 'itemCount': 6},
      },
      'chip': {'type': 'box', 'layout': {'width': 120, 'height': 38}},
    });
    expect(s.tree.boxOf('list')!.size.height, 38);
  });
}
