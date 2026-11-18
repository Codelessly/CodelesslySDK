// Reorderable lists
// (press, long press, a handle, conditions, keys) and moving cards between
// the lists of a reorder group.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';
import '../support/keyboard.dart';

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

  group('a reorderable list', () {
    late Screen s;
    List<String> order() => [for (final song in s['songs'] as List) (song as Map)['id'] as String];

    Future<void> pumpList(WidgetTester tester, Json reorder, {Json rowExtra = const {}, Map<String, Json> extra = const {}}) async {
      s = await show(tester, list(reorder, rowExtra: rowExtra, extra: extra),
          variables: [v('songs', songs(), VariableType.list), v('last', '')]);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    Offset row(int i) => s.center('row', instance: ProvidedItem('row', null, 'list', ('id', 's$i')));

    testWidgets('dragging an item moves it and updates the variable', (tester) async {
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

    testWidgets('runs its drag-start reaction when an item lifts and drag-completed when it lands', (tester) async {
      await pumpList(tester, {'start': 'press'}, extra: {
        'list': {
          ...list({'start': 'press'})['list']!,
          'actions': [
            reaction('dragStart', [
              {'type': 'setVariable', 'variable': 'last', 'value': r'lifted ${result.index} ${result.item.id}'},
            ]),
            reaction('dragCompleted', [
              {'type': 'setVariable', 'variable': 'last', 'value': r'${last}, dropped'},
            ]),
          ],
        },
      });
      final drag = await tester.startGesture(row(2));
      await tester.pump(kPressTimeout);
      await drag.moveBy(const Offset(0, 30));
      await tester.pump();
      await tester.pump();
      expect(s['last'], 'lifted 2 s2');
      await drag.up();
      await tester.pumpAndSettle();
      expect(s['last'], 'lifted 2 s2, dropped');
    });

    testWidgets('set to long press starts the drag on a long press, and a tap does nothing', (tester) async {
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

    testWidgets('with a handle picks the row up by its handle', (tester) async {
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

    testWidgets('a kit handle takes Tab, shows a keyboard ring and moves its list by key', (tester) async {
      await pumpList(tester, {'apply': 'variable', 'keyboard': true},
        rowExtra: {'type': 'row', 'children': ['label', 'grip'], 'props': <String, Object?>{}},
        extra: {
          'label': {'type': 'text', 'layout': {'width': 250, 'height': 50}, 'props': {'text': r'${item.id}'}},
          'grip': {'type': 'iconButton', 'layout': {'width': 44, 'height': 44},
            'props': {'icon': 'drag_indicator'}, 'tooltip': 'Reorder', 'reorderHandle': true},
        });
      final keys = Keyboard(tester);
      await keys.tab();
      expect(keys.focusedId, 'grip');
      expect(keys.ringShown, isTrue);
      expect(keys.semantics!.isButton, isTrue);
      expect(keys.semantics!.label, 'Reorder s0');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.pumpAndSettle();
      expect(order(), ['s1', 's0', 's2', 's3', 's4']);
    });

    testWidgets('a tap on a kit handle focuses it with no ring, and Alt and an arrow then move its row', (tester) async {
      await pumpList(tester, {'apply': 'variable', 'keyboard': true},
        rowExtra: {'type': 'row', 'children': ['label', 'grip'], 'props': <String, Object?>{}},
        extra: {
          'label': {'type': 'text', 'layout': {'width': 250, 'height': 50}, 'props': {'text': r'${item.id}'}},
          'grip': {'type': 'iconButton', 'layout': {'width': 44, 'height': 44},
            'props': {'icon': 'drag_indicator'}, 'tooltip': 'Reorder', 'reorderHandle': true},
        });
      final keys = Keyboard(tester);
      await tester.tapAt(s.center('grip', instance: ProvidedItem('row', null, 'list', ('id', 's1'))));
      await tester.pumpAndSettle();
      expect(keys.focusedId, 'grip');
      expect(keys.ringShown, isFalse);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.pumpAndSettle();
      expect(order(), ['s0', 's2', 's1', 's3', 's4']);
    });

    // Test 9, kanban 6: cards that open on a tap, reordered with no Handle;
    // Tab reached a card and Alt and an arrow moved nothing.
    testWidgets('with no handle, a row that is a Tab stop moves by Alt and an arrow, and keeps its own Enter', (tester) async {
      await pumpList(tester, {'start': 'press', 'apply': 'variable', 'keyboard': true}, rowExtra: {
        'actions': [
          reaction('click', [
            {'type': 'setVariable', 'variable': 'last', 'value': r'opened ${item.id}'},
          ]),
        ],
      });
      final keys = Keyboard(tester);
      await keys.tab();
      expect(keys.focusedId, 'row');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.pumpAndSettle();
      expect(order(), ['s1', 's0', 's2', 's3', 's4']);
      expect(keys.focusedId, 'row');
      await keys.enter();
      expect(s['last'], 'opened s0', reason: 'the focus followed the moved row, and Enter still opens it');
    });

    testWidgets('leaves an item in place when its condition refuses the move', (tester) async {
      await pumpList(tester, {'start': 'press', 'apply': 'variable', 'canReorderIf': r'${= !item.locked}'});
      final listeners =
          tester.widgetList<ReorderableDragStartListener>(find.byType(ReorderableDragStartListener)).toList();
      expect(listeners.where((l) => !l.enabled).length, 1);
      expect(listeners.firstWhere((l) => !l.enabled).index, 4);
    });

    testWidgets('changes nothing when the drop is refused', (tester) async {
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

    testWidgets('moves a focused item with Alt and the arrow keys', (tester) async {
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

    testWidgets('stays at rest on the design canvas', (tester) async {
      s = await show(tester, list({'start': 'press'}),
          variables: [v('songs', songs(), VariableType.list), v('last', '')], interactive: false);
      expect(find.byType(ReorderableListView), findsNothing);
    });
  });

  testWidgets('moves a card between two lists of the same group', (tester) async {
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

  testWidgets('moves a focused card between grouped lists by keyboard and exposes transfer actions', (tester) async {
    Json column(String id) => {
      'type': 'listView', 'children': ['$id-card'],
      'layout': {'width': 200, 'height': 300}, 'bind': {'data': '\${$id}'},
      'props': {'reorder': {'start': 'press', 'group': 'board', 'listKey': id, 'apply': 'variable', 'keyboard': true}},
    };
    final s = await show(tester, {
      'board': {'type': 'row', 'children': ['todo', 'done'], 'layout': {'width': 400, 'height': 350}},
      'todo': column('todo'), 'done': column('done'),
      'todo-card': {'type': 'text', 'layout': {'width': 200, 'height': 50}, 'props': {'text': r'${item.id}'}},
      'done-card': {'type': 'text', 'layout': {'width': 200, 'height': 50}, 'props': {'text': r'${item.id}'}},
    }, root: 'board', variables: [
      v('todo', [{'id': 't0'}, {'id': 't1'}], VariableType.list),
      v('done', [{'id': 'd0'}], VariableType.list),
    ]);
    await tester.pumpAndSettle();
    final first = find.byType(KeyboardReorderItem).first;
    final semantics = tester.widget<Semantics>(find.descendant(of: first, matching: find.byType(Semantics)).first);
    expect(semantics.properties.customSemanticsActions!.keys.map((a) => a.label), contains('Move to next list'));
    tester.widget<KeyboardReorderItem>(first).focusNode!.requestFocus();
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.pumpAndSettle();
    expect((s['todo'] as List).map((x) => (x as Map)['id']), ['t1']);
    expect((s['done'] as List).map((x) => (x as Map)['id']), ['d0', 't0']);
  });

  testWidgets('a Handle starts a grouped touch transfer at phone width', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    Json column(String id) => {
      'type': 'listView', 'children': ['$id-card'],
      'layout': {'width': 300, 'height': 130}, 'bind': {'data': '\${$id}'},
      'props': {'reorder': {'start': 'handle', 'group': 'trip', 'listKey': id, 'apply': 'variable'}},
    };
    Json card(String id) => {
      'type': 'row', 'children': ['$id-grip', '$id-name'],
      'layout': {'width': 300, 'height': 50},
    };
    final s = await show(tester, {
      'board': {'type': 'column', 'children': ['todo', 'done'], 'layout': {'width': 320, 'height': 350}},
      'todo': column('todo'), 'done': column('done'),
      'todo-card': card('todo'), 'done-card': card('done'),
      'todo-grip': {'type': 'iconButton', 'layout': {'width': 44, 'height': 44},
        'props': {'icon': 'drag_indicator'}, 'tooltip': 'Reorder', 'reorderHandle': true},
      'done-grip': {'type': 'iconButton', 'layout': {'width': 44, 'height': 44},
        'props': {'icon': 'drag_indicator'}, 'tooltip': 'Reorder', 'reorderHandle': true},
      'todo-name': {'type': 'text', 'layout': {'width': 250, 'height': 50}, 'props': {'text': r'${item.id}'}},
      'done-name': {'type': 'text', 'layout': {'width': 250, 'height': 50}, 'props': {'text': r'${item.id}'}},
    }, root: 'board', variables: [
      v('todo', [{'id': 't0'}], VariableType.list),
      v('done', [{'id': 'd0'}], VariableType.list),
    ]);
    await tester.pumpAndSettle();
    final from = s.center('todo-grip', instance: const ProvidedItem('row', null, 'todo', ('id', 't0')));
    final to = s.center('done-name', instance: const ProvidedItem('row', null, 'done', ('id', 'd0')));
    final drag = await tester.startGesture(from);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    for (var i = 1; i <= 10; i++) {
      await drag.moveTo(Offset.lerp(from, to, i / 10)!);
      await tester.pump();
    }
    await drag.up();
    await tester.pumpAndSettle();
    expect(s['todo'], isEmpty);
    expect((s['done'] as List).map((x) => (x as Map)['id']), containsAll(['t0', 'd0']));
  });
}
