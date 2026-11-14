// A carousel's controls: the scroll reaction reports the item at the start
// of the view (`${result.index}`, `${result.count}`) beside its offset and
// fraction, arrows move it an item with scrollTo, and itemSnapping makes a
// drag come to rest with an item at the start (CSS scroll-snap-align).
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/layout/design_scroll.dart' show RenderDesignScroll;
import 'package:codelessly_sdk/src/widgets/collections_data_list.dart' show DataListView, DataListViewState;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support.dart';

/// A 300 px window on a horizontal row of five 200 px cards, 20 apart; a
/// "next" box that scrolls to the card after the current one, and the
/// scroll reaction storing the current card and the progress.
Map<String, Json> _rail(String type, {bool snapping = false}) => {
      'col': {'type': 'column', 'children': ['rail', 'next'], 'layout': {'width': 300, 'height': {'hug': 300}}},
      'rail': {
        'type': type,
        'children': type == 'listView' ? ['card'] : ['card0', 'card1', 'card2', 'card3', 'card4'],
        'layout': {'width': 300, 'height': 120},
        'props': {
          'scrollable': true,
          'scrollDirection': 'horizontal',
          'spacing': 20,
          if (snapping) 'itemSnapping': true,
        },
        if (type == 'listView') 'bind': {'data': r'${= [0, 1, 2, 3, 4]}'},
        'actions': [
          reaction('scroll', [
            {'type': 'setVariable', 'variable': 'current', 'value': r'${result.index}'},
            {'type': 'setVariable', 'variable': 'count', 'value': r'${result.count}'},
            {'type': 'setVariable', 'variable': 'progress', 'value': r'${result.fraction}'},
          ]),
        ],
      },
      if (type == 'listView')
        'card': {'type': 'box', 'layout': {'width': 200, 'height': {'fill': 120}}, 'decoration': {'fills': [{'color': '#FF334155'}]}}
      else
        for (var i = 0; i < 5; i++)
          'card$i': {'type': 'box', 'layout': {'width': 200, 'height': 120}, 'decoration': {'fills': [{'color': '#FF334155'}]}},
      'next': {
        'type': 'box',
        'layout': {'width': 100, 'height': 40},
        'decoration': {'fills': [{'color': '#FF000000'}]},
        'actions': [
          reaction('click', [
            if (type == 'listView')
              {'type': 'scrollTo', 'node': 'card', 'item': r'${= current + 1}', 'axis': 'horizontal', 'durationMs': 0}
            else
              {'type': 'scrollTo', 'node': r'card${= current + 1}', 'axis': 'horizontal', 'durationMs': 0},
          ]),
        ],
      },
    };

List<Variable> get _vars => [
      v('current', 0, VariableType.integer),
      v('count', 0, VariableType.integer),
      v('progress', 0.0, VariableType.decimal),
    ];

/// How far the rail is scrolled.
double _offset(WidgetTester tester, Screen s) {
  final list = find.byType(DataListView);
  if (list.evaluate().isNotEmpty) return tester.state<DataListViewState>(list).scrollController.offset;
  RenderDesignScroll? found;
  void visit(RenderObject o) {
    if (o is RenderDesignScroll) found ??= o;
    o.visitChildren(visit);
  }

  visit(s.tree.boxOf('rail')!);
  return found!.offset;
}

void main() {
  for (final type in ['row', 'listView']) {
    testWidgets('a $type\'s scroll reaction reports the card at the start, and an arrow moves it one card', (tester) async {
      final s = await show(tester, _rail(type), variables: _vars);
      await tester.tapAt(s.center('next'));
      await tester.pumpAndSettle();
      expect(s['current'], 1);
      expect(s['count'], 5);
      await tester.tapAt(s.center('next'));
      await tester.pumpAndSettle();
      expect(s['current'], 2);
      expect(s['progress'] as num, closeTo(440 / (5 * 200 + 4 * 20 - 300), 0.01));
    });
  }

  testWidgets('a hand scroll updates the current card too, and the last one shows at the end', (tester) async {
    final s = await show(tester, _rail('row'), variables: _vars);
    // Slowly, so it does not coast on.
    await tester.timedDrag(find.byType(NodeView), const Offset(-230, 0), const Duration(seconds: 8));
    await tester.pumpAndSettle();
    expect(s['current'], 1);
    await tester.timedDrag(find.byType(NodeView), const Offset(-2000, 0), const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(s['current'], 4, reason: 'at the end, where the last card cannot reach the start');
    expect(s['progress'], 1.0);
  });

  for (final type in ['row', 'listView']) {
    testWidgets('a $type with item snapping comes to rest with a card at the start after a drag', (tester) async {
      final s = await show(tester, _rail(type, snapping: true), variables: _vars);
      // A slow drag of 150 px: past half a card, it settles on the second (at 220).
      await tester.timedDrag(find.byType(NodeView), const Offset(-150, 0), const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(_offset(tester, s), closeTo(220, 0.5));
      expect(s['current'], 1);
      // A short one back: it settles on the second again.
      await tester.timedDrag(find.byType(NodeView), const Offset(60, 0), const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(_offset(tester, s), closeTo(220, 0.5));
      // A fling forward goes at least one card on.
      await tester.fling(find.byType(NodeView), const Offset(-120, 0), 1500);
      await tester.pumpAndSettle();
      expect([440.0, 660.0, 780.0], contains(_offset(tester, s).roundToDouble()));
    });
  }
}
