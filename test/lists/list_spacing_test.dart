// A bound list that doesn't scroll spaces its items by `spacing`, as a
// column does (the leaderboard's rows, 12 apart).
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/widgets.dart' show Offset;
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  for (final (scrollable, motion) in [(false, false), (true, false), (false, true)]) {
    testWidgets('a bound list (scrollable: $scrollable, entering: $motion) spaces its items by spacing', (tester) async {
      final s = await show(tester, {
        'col': {'type': 'column', 'children': ['rows'], 'layout': {'width': 300, 'height': 600}},
        'rows': {
          'type': 'listView',
          'children': ['row'],
          'layout': {'width': {'fill': 300}, 'height': scrollable ? 400 : {'hug': 10}},
          'props': {'scrollable': scrollable, 'spacing': 12},
          'bind': {'data': r'${items}'},
        },
        'row': {
          'type': 'column',
          'children': ['card'],
          'layout': {'width': {'fill': 300}, 'height': {'hug': 10}},
          if (motion) 'motion': {'enter': true, 'enterFrom': {'translateX': 60, 'opacity': 0}, 'duration': 300},
        },
        'card': {'type': 'box', 'layout': {'width': {'fill': 300}, 'height': 40}},
      }, variables: [v('items', [1, 2, 3], VariableType.list)]);
      await tester.pumpAndSettle();
      // 40 px rows, 12 apart: tops 52 apart.
      final tops = [
        for (final b in s.tree.boxesOf('row').where((b) => b.attached && b.hasSize)) b.localToGlobal(Offset.zero).dy,
      ]..sort();
      expect(tops.length, greaterThanOrEqualTo(2));
      expect(tops[1] - tops[0], closeTo(52, 0.5));
    });
  }
}
