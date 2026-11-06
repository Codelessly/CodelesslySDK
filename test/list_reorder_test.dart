import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

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
      final toEmpty = moveBetweenLists(['a', 'b'], <String>[], 1, 5);
      expect(toEmpty.target, ['b']);
    });

    test('orderBetween writes only the moved document', () {
      expect(orderBetween(1, 2), 1.5);
      expect(orderBetween(null, 3), 2);
      expect(orderBetween(7, null), 8);
      expect(orderBetween(null, null), 0);
    });
  });

  group('reorderable list', () {
    late VariableData songs;
    late CodelesslyContext codelessly;

    setUp(() {
      songs = VariableData(
        id: 'songs',
        name: 'songs',
        type: VariableType.list,
        value: [
          for (int i = 0; i < 5; i++) {'id': 's$i', 'locked': i == 4},
        ],
      );
      codelessly = CodelesslyContext.empty().copyWith(
        variables: {songs.id: Observable(songs)},
      );
    });

    List<String> order() => [
      for (final song in codelessly
          .findVariableByName('songs')!
          .value
          .getValue()
          .typedValue<List>()!)
        (song as Map)['id'] as String,
    ];

    Future<void> pumpList(WidgetTester tester, ReorderModel reorder) async {
      final List<BaseNode> nodes = [
        ListViewNode(
          id: 'list',
          name: 'list',
          basicBoxLocal: NodeBox(0, 0, 300, 500),
          properties: ListViewProperties(),
          variables: {'data': r'${songs}'},
          children: const ['row'],
          reorder: reorder,
          reactions: [
            Reaction(
              id: 'r',
              name: 'reorder',
              trigger: TriggerModel(type: TriggerType.reorder),
              action: SetVariableAction(
                variable: VariableData(
                  id: 'last',
                  name: 'last',
                  type: VariableType.text,
                ),
                newValue: r'${result.from}',
              ),
            ),
          ],
        )..parentID = kRootNode,
        TextNode(
          id: 'row',
          name: 'row',
          basicBoxLocal: NodeBox(0, 0, 300, 50),
          data: r'${item.id}',
          textMixedProps: [StartEndProp(start: 0, end: 10, fontSize: 14)],
        )..parentID = 'list',
      ];
      final registry = NodeRegistry()
        ..setNodes({for (final node in nodes) node.id: node});
      final manager = PassiveNodeTransformerManager(
        registry.getNodeByID,
        (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
      );
      await tester.pumpWidget(
        ChangeNotifierProvider<CodelesslyContext>.value(
          value: codelessly,
          child: MaterialApp(
            home: Material(
              child: Align(
                alignment: Alignment.topLeft,
                child: Builder(
                  builder: (context) => NotificationListener<Notification>(
                    child: manager.buildWidgetFromNode(
                      nodes.first,
                      context,
                      settings: const WidgetBuildSettings(debugLabel: 'test'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    Finder row(String id) => find.text(id, findRichText: true);

    testWidgets('press anywhere drags an item and applies to the variable', (
      tester,
    ) async {
      await pumpList(
        tester,
        const ReorderModel(start: ReorderStart.press, apply: ListApply.variable),
      );
      expect(find.byType(ReorderableListView), findsOneWidget);
      final TestGesture drag = await tester.startGesture(
        tester.getCenter(row('s0')),
      );
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
    });

    testWidgets('long press starts the drag; a tap does nothing', (
      tester,
    ) async {
      await pumpList(
        tester,
        const ReorderModel(
          start: ReorderStart.longPress,
          apply: ListApply.variable,
        ),
      );
      expect(find.byType(ReorderableDelayedDragStartListener), findsWidgets);
      final TestGesture drag = await tester.startGesture(
        tester.getCenter(row('s3')),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      for (int i = 0; i < 8; i++) {
        await drag.moveBy(const Offset(0, -25));
        await tester.pump();
      }
      await drag.up();
      await tester.pumpAndSettle();
      expect(order().indexOf('s3'), lessThan(2));
    });

    testWidgets('an item canReorderIf refuses stays put', (tester) async {
      await pumpList(
        tester,
        const ReorderModel(
          start: ReorderStart.press,
          apply: ListApply.variable,
          canReorderIf: r'${= !item.locked}',
        ),
      );
      final List<ReorderableDragStartListener> listeners = tester
          .widgetList<ReorderableDragStartListener>(
            find.byType(ReorderableDragStartListener),
          )
          .toList();
      expect(listeners.where((l) => !l.enabled).length, 1);
      expect(listeners.firstWhere((l) => !l.enabled).index, 4);
    });

    testWidgets('a drop canDropIf refuses changes nothing', (tester) async {
      await pumpList(
        tester,
        const ReorderModel(
          start: ReorderStart.press,
          apply: ListApply.variable,
          // Items may only move down.
          canDropIf: r'${= result.to > result.from}',
        ),
      );
      final TestGesture drag = await tester.startGesture(
        tester.getCenter(row('s2')),
      );
      await tester.pump(kPressTimeout);
      await drag.moveBy(const Offset(0, -20));
      await tester.pump();
      await drag.moveBy(const Offset(0, -110));
      await tester.pump();
      await drag.up();
      await tester.pumpAndSettle();
      expect(order(), ['s0', 's1', 's2', 's3', 's4']);
    });

    testWidgets('Alt and the arrow keys move a focused item', (tester) async {
      await pumpList(
        tester,
        const ReorderModel(start: ReorderStart.press, apply: ListApply.variable),
      );
      // The item's own focus node is the nearest one above its content.
      final FocusNode node = Focus.of(
        tester.element(
          find
              .descendant(
                of: find.byType(KeyboardReorderItem).at(1),
                matching: find.byType(ReorderableDragStartListener),
              )
              .first,
        ),
      );
      node.requestFocus();
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.pumpAndSettle();
      expect(order(), ['s0', 's2', 's1', 's3', 's4']);
    });

    testWidgets('the reorder result has from, to, item and both lists', (
      tester,
    ) async {
      late BuildContext captured;
      await tester.pumpWidget(
        ChangeNotifierProvider<CodelesslyContext>.value(
          value: codelessly,
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                captured = context;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      final ListViewNode list = ListViewNode(
        id: 'board',
        name: 'board',
        basicBoxLocal: NodeBox(0, 0, 10, 10),
        properties: ListViewProperties(),
        children: const [],
        variables: {'data': r'${songs}'},
      );
      final Map<String, Object?> result = reorderResult(
        from: 1,
        to: 3,
        item: {'id': 's1'},
        fromList: 'todo',
        toList: 'todo',
      );
      expect(result, {
        'from': 1,
        'to': 3,
        'item': {'id': 's1'},
        'fromList': 'todo',
        'toList': 'todo',
      });
      final bool applied = await runListReorder(
        captured,
        list: list,
        model: const ReorderModel(apply: ListApply.variable),
        items: songs.getValue().typedValue<List>()!.cast<Object?>(),
        from: 1,
        to: 3,
        listKey: 'todo',
      );
      expect(applied, isTrue);
      expect(order(), ['s0', 's2', 's3', 's1', 's4']);
    });
  });

  testWidgets('a card moves between two lists of a group (Kanban)', (
    tester,
  ) async {
    VariableData column(String name, List<String> ids) => VariableData(
      id: name,
      name: name,
      type: VariableType.list,
      value: [
        for (final id in ids) {'id': id},
      ],
    );
    final VariableData moves = VariableData(
      id: 'moves',
      name: 'moves',
      type: VariableType.text,
      value: '',
    );
    final CodelesslyContext codelessly = CodelesslyContext.empty().copyWith(
      variables: {
        for (final v in [
          column('todo', ['t0', 't1', 't2']),
          column('done', ['d0', 'd1']),
          moves,
        ])
          v.id: Observable(v),
      },
    );
    ListViewNode list(String id) => ListViewNode(
      id: id,
      name: id,
      basicBoxLocal: NodeBox(0, 0, 200, 400),
      properties: ListViewProperties(),
      variables: {'data': '\${$id}'},
      children: ['$id-card'],
      reorder: ReorderModel(
        start: ReorderStart.press,
        group: 'board',
        listKey: id,
        apply: ListApply.variable,
      ),
      reactions: [
        Reaction(
          id: '$id-r',
          name: 'moved',
          trigger: TriggerModel(type: TriggerType.reorder),
          action: SetVariableAction(
            variable: moves,
            newValue: r'${result.fromList}>${result.toList}@${result.to}',
          ),
        ),
      ],
    )..parentID = kRootNode;
    TextNode card(String id) => TextNode(
      id: '$id-card',
      name: '$id-card',
      basicBoxLocal: NodeBox(0, 0, 200, 50),
      data: r'${item.id}',
      textMixedProps: [StartEndProp(start: 0, end: 10, fontSize: 14)],
    )..parentID = id;
    final List<BaseNode> nodes = [
      list('todo'),
      card('todo'),
      list('done'),
      card('done'),
    ];
    final registry = NodeRegistry()
      ..setNodes({for (final node in nodes) node.id: node});
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: codelessly,
        child: MaterialApp(
          home: Material(
            child: Builder(
              builder: (context) => Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final String id in ['todo', 'done'])
                    SizedBox(
                      width: 200,
                      height: 400,
                      child: manager.buildWidgetFromNode(
                        registry.getNodeByID(id),
                        context,
                        settings: const WidgetBuildSettings(debugLabel: 't'),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(GroupReorderList), findsNWidgets(2));
    List<String> ids(String name) => [
      for (final item in codelessly
          .findVariableByName(name)!
          .value
          .getValue()
          .typedValue<List>()!)
        (item as Map)['id'] as String,
    ];

    // Drag t1 onto the done column, between d0 and d1.
    final Offset start = tester.getCenter(find.text('t1', findRichText: true));
    final Offset d1 = tester.getCenter(find.text('d1', findRichText: true));
    final TestGesture drag = await tester.startGesture(start);
    await tester.pump();
    for (int i = 1; i <= 10; i++) {
      await drag.moveTo(Offset.lerp(start, d1 - const Offset(0, 25), i / 10)!);
      await tester.pump();
    }
    expect(find.byKey(const ValueKey('reorder-placeholder')), findsOneWidget);
    await drag.up();
    await tester.pumpAndSettle();
    expect(ids('todo'), ['t0', 't2']);
    expect(ids('done'), ['d0', 't1', 'd1']);
    expect(
      codelessly.findVariableByName('moves')!.value.value,
      'todo>done@1',
    );
  });
}
