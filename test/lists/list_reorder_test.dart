// Ported from SDK 8.x's test/list_reorder_test.dart: reorderable lists
// (press, long press, a handle, conditions, keys) and moving cards between
// the lists of a reorder group.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

List<Object?> songs() => [for (var i = 0; i < 5; i++) {'id': 's$i', 'locked': i == 4}];

Map<String, Json> list(Json reorder, {Json rowExtra = const {}, Map<String, Json> extra = const {}}) => {
      'col': {
        'type': 'column',
        'children': ['list'],
        'layout': {'width': 300, 'height': {'hug': 500}},
      },
      'list': {
        'type': 'listView',
        'children': ['row'],
        'layout': {'width': 300, 'height': 500},
        'bind': {'data': r'${songs}'},
        'props': {'reorder': reorder},
        'actions': [
          reaction('reorder', [
            {'type': 'setVariable', 'variable': 'last', 'value': r'${result.from}>${result.to}'},
          ]),
        ],
      },
      'row': {
        'type': 'text',
        'layout': {'width': 300, 'height': 50},
        'props': {'text': r'${item.id}'},
        ...rowExtra,
      },
      ...extra,
    };

void main() {
  group('index math', () {
    test('moveListItem puts the item at its index in the new order', () {
      expect(moveListItem([0, 1, 2, 3, 4], 0, 2), [1, 2, 0, 3, 4]);
      expect(moveListItem([0, 1, 2, 3, 4], 4, 0), [4, 0, 1, 2, 3]);
      expect(moveListItem([0, 1, 2, 3, 4], 1, 4), [0, 2, 3, 4, 1]);
      expect(moveListItem([0, 1, 2], 1, 1), [0, 1, 2]);
      expect(moveListItem([0, 1, 2], 1, 99), [0, 2, 1]);
      expect(moveListItem([0, 1, 2], 9, 0), [0, 1, 2]);
    });

    test('moveBetweenLists inserts before the target index', () {
      final moved = moveBetweenLists(['a', 'b', 'c'], ['x', 'y'], 1, 1);
      expect(moved.source, ['a', 'c']);
      expect(moved.target, ['x', 'b', 'y']);
      final atEnd = moveBetweenLists(['a'], ['x', 'y'], 0, 2);
      expect(atEnd.source, isEmpty);
      expect(atEnd.target, ['x', 'y', 'a']);
      expect(moveBetweenLists(['a', 'b'], <String>[], 1, 5).target, ['b']);
    });

    test('orderBetween writes only the moved document', () {
      expect(orderBetween(1, 2), 1.5);
      expect(orderBetween(null, 3), 2);
      expect(orderBetween(7, null), 8);
      expect(orderBetween(null, null), 0);
    });

    test('the reorder result has from, to, item and both lists', () {
      expect(reorderResult(from: 1, to: 3, item: {'id': 's1'}, fromList: 'todo', toList: 'todo'), {
        'from': 1,
        'to': 3,
        'item': {'id': 's1'},
        'fromList': 'todo',
        'toList': 'todo',
      });
    });
  });

  group('reorderable list', () {
    late Screen s;
    List<String> order() => [for (final song in s['songs'] as List) (song as Map)['id'] as String];

    Future<void> pumpList(WidgetTester tester, Json reorder, {Json rowExtra = const {}, Map<String, Json> extra = const {}}) async {
      s = await show(tester, list(reorder, rowExtra: rowExtra, extra: extra),
          variables: [v('songs', songs(), VariableType.list), v('last', '')]);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    Offset row(int i) => s.center('row', instance: ProvidedItem('row', null, 'list', ('id', 's$i')));

    testWidgets('press anywhere drags an item and applies to the variable', (tester) async {
      await pumpList(tester, {'start': 'press', 'apply': 'variable'});
      expect(find.byType(ReorderableListView), findsOneWidget);
      final drag = await tester.startGesture(row(0));
      await tester.pump(kPressTimeout);
      await drag.moveBy(const Offset(0, 20));
      await tester.pump();
      await drag.moveBy(const Offset(0, 110));
      await tester.pump();
      await drag.up();
      await tester.pumpAndSettle();
      // s0 moved down; the others kept their order.
      expect(order().indexOf('s0'), greaterThan(1));
      expect(order().where((id) => id != 's0'), ['s1', 's2', 's3', 's4']);
      expect(s['last'], '0>${order().indexOf('s0')}');
    });

    testWidgets('long press starts the drag; a tap does nothing', (tester) async {
      await pumpList(tester, {'start': 'longPress', 'apply': 'variable'});
      expect(find.byType(ReorderableDelayedDragStartListener), findsWidgets);
      await tester.tapAt(row(3));
      await tester.pumpAndSettle();
      expect(order(), ['s0', 's1', 's2', 's3', 's4']);
      final drag = await tester.startGesture(row(3));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      for (var i = 0; i < 8; i++) {
        await drag.moveBy(const Offset(0, -25));
        await tester.pump();
      }
      await drag.up();
      await tester.pumpAndSettle();
      expect(order().indexOf('s3'), lessThan(2));
    });

    testWidgets('a handle node (its drag reorders) picks the row up', (tester) async {
      await pumpList(
        tester,
        {'apply': 'variable'},
        rowExtra: {
          'type': 'row',
          'children': ['label', 'grip'],
          'props': <String, Object?>{},
        },
        extra: {
          'label': {'type': 'text', 'layout': {'width': 250, 'height': 50}, 'props': {'text': r'${item.id}'}},
          'grip': {
            'type': 'box',
            'layout': {'width': 50, 'height': 50},
            'decoration': {'fills': [{'color': '#FF000000'}]},
            'drag': {'reorder': true},
          },
        },
      );
      Offset grip(int i) => s.center('grip', instance: ProvidedItem('row', null, 'list', ('id', 's$i')));
      Offset label(int i) => s.center('label', instance: ProvidedItem('row', null, 'list', ('id', 's$i')));
      // Off the handle, nothing moves.
      var drag = await tester.startGesture(label(0));
      await drag.moveBy(const Offset(0, 130));
      await tester.pump();
      await drag.up();
      await tester.pumpAndSettle();
      expect(order(), ['s0', 's1', 's2', 's3', 's4']);
      drag = await tester.startGesture(grip(0));
      await tester.pump(kPressTimeout);
      await drag.moveBy(const Offset(0, 20));
      await tester.pump();
      await drag.moveBy(const Offset(0, 110));
      await tester.pump();
      await drag.up();
      await tester.pumpAndSettle();
      expect(order().indexOf('s0'), greaterThan(1));
    });

    testWidgets('an item canReorderIf refuses stays put', (tester) async {
      await pumpList(tester, {'start': 'press', 'apply': 'variable', 'canReorderIf': r'${= !item.locked}'});
      final listeners =
          tester.widgetList<ReorderableDragStartListener>(find.byType(ReorderableDragStartListener)).toList();
      expect(listeners.where((l) => !l.enabled).length, 1);
      expect(listeners.firstWhere((l) => !l.enabled).index, 4);
    });

    testWidgets('a drop canDropIf refuses changes nothing', (tester) async {
      // Items may only move down.
      await pumpList(tester, {'start': 'press', 'apply': 'variable', 'canDropIf': r'${= result.to > result.from}'});
      final drag = await tester.startGesture(row(2));
      await tester.pump(kPressTimeout);
      await drag.moveBy(const Offset(0, -20));
      await tester.pump();
      await drag.moveBy(const Offset(0, -110));
      await tester.pump();
      await drag.up();
      await tester.pumpAndSettle();
      expect(order(), ['s0', 's1', 's2', 's3', 's4']);
      expect(s['last'], '');
    });

    testWidgets('Alt and the arrow keys move a focused item', (tester) async {
      await pumpList(tester, {'start': 'press', 'apply': 'variable'});
      final node = Focus.of(tester.element(find
          .descendant(of: find.byType(KeyboardReorderItem).at(1), matching: find.byType(ReorderableDragStartListener))
          .first));
      node.requestFocus();
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.pumpAndSettle();
      expect(order(), ['s0', 's2', 's1', 's3', 's4']);
      expect(s['last'], '1>2');
    });

    testWidgets('a design canvas keeps the list at rest', (tester) async {
      s = await show(tester, list({'start': 'press'}),
          variables: [v('songs', songs(), VariableType.list), v('last', '')], interactive: false);
      expect(find.byType(ReorderableListView), findsNothing);
    });
  });

  testWidgets('a card moves between two lists of a group (Kanban)', (tester) async {
    Json column(String id) => {
          'type': 'listView',
          'children': ['$id-card'],
          'layout': {'width': 200, 'height': 400},
          'bind': {'data': '\${$id}'},
          'props': {
            'reorder': {'start': 'press', 'group': 'board', 'listKey': id, 'apply': 'variable'},
          },
          'actions': [
            reaction('reorder', [
              {'type': 'setVariable', 'variable': 'moves', 'value': r'${result.fromList}>${result.toList}@${result.to}'},
            ]),
          ],
        };
    Json card() => {
          'type': 'text',
          'layout': {'width': 200, 'height': 50},
          'props': {'text': r'${item.id}'},
        };
    final s = await show(
      tester,
      {
        'board': {
          'type': 'row',
          'children': ['todo', 'done'],
          'layout': {'width': 400, 'height': 400},
          'crossAxisAlignment': 'start',
        },
        'todo': column('todo'),
        'todo-card': card(),
        'done': column('done'),
        'done-card': card(),
      },
      root: 'board',
      variables: [
        v('todo', [for (final id in ['t0', 't1', 't2']) {'id': id}], VariableType.list),
        v('done', [for (final id in ['d0', 'd1']) {'id': id}], VariableType.list),
        v('moves', ''),
      ],
    );
    await tester.pumpAndSettle();
    expect(find.byType(GroupReorderList), findsNWidgets(2));
    List<String> ids(String name) => [for (final item in s[name] as List) (item as Map)['id'] as String];

    // Drag t1 onto the done column, between d0 and d1.
    final start = s.center('todo-card', instance: const ProvidedItem('row', null, 'todo', ('id', 't1')));
    final d1 = s.center('done-card', instance: const ProvidedItem('row', null, 'done', ('id', 'd1')));
    final drag = await tester.startGesture(start);
    await tester.pump();
    for (var i = 1; i <= 10; i++) {
      await drag.moveTo(Offset.lerp(start, d1 - const Offset(0, 25), i / 10)!);
      await tester.pump();
    }
    expect(find.byKey(const ValueKey('reorder-placeholder')), findsOneWidget);
    await drag.up();
    await tester.pumpAndSettle();
    expect(ids('todo'), ['t0', 't2']);
    expect(ids('done'), ['d0', 't1', 'd1']);
    expect(s['moves'], 'todo>done@1');
  });
}
