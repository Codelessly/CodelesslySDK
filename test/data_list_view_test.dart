import 'dart:async';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// A source of [total] items `{'id': i}` that counts its calls.
class CountingSource {
  CountingSource(this.total, {this.delay = Duration.zero});

  final int total;
  final Duration delay;
  final List<int> pages = [];

  Future<PageResult> call(PageRequest request) async {
    pages.add(request.page);
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    final int start = request.offset.clamp(0, total);
    final int end = (start + request.pageSize).clamp(0, total);
    return PageResult(
      [for (int i = start; i < end; i++) {'id': i}],
      totalCount: total,
    );
  }
}

ListViewNode listNode({
  PaginationModel? pagination,
  ListSectionsModel? sections,
  SwipeActionsModel? swipeActions,
  List<Reaction> reactions = const [],
}) => ListViewNode(
  id: 'list',
  name: 'list',
  basicBoxLocal: NodeBox(0, 0, 300, 400),
  properties: ListViewProperties(),
  children: const ['row'],
  pagination: pagination,
  sections: sections,
  swipeActions: swipeActions,
  reactions: reactions,
);

Widget rowOf(BuildContext context) {
  final Object? item = IndexedItemProvider.maybeOf(context)?.item;
  final Object? id = item is Map ? item['id'] ?? item['name'] : item;
  return SizedBox(height: 50, child: Text('row $id'));
}

Future<DataListViewState> pumpList(
  WidgetTester tester,
  ListViewNode node, {
  PageFetcher? fetcher,
  List<Object?>? data,
  CodelesslyContext? codelessly,
  double headerExtent = 30,
}) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: codelessly ?? CodelesslyContext.empty(),
      child: MaterialApp(
        home: Material(
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 300,
              height: 400,
              child: DataListView(
                node: node,
                fetcher: fetcher,
                data: data,
                itemExtent: 50,
                headerExtent: headerExtent,
                buildTemplate: rowOf,
                buildNode: (context, id) {
                  final Object? item = IndexedItemProvider.maybeOf(
                    context,
                  )?.item;
                  return SizedBox(
                    height: headerExtent,
                    child: Text(
                      'node $id ${item is Map ? item['key'] : ''}'.trim(),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return tester.state<DataListViewState>(find.byType(DataListView));
}

void main() {
  group('auto-paginate', () {
    testWidgets('loads the next page once per threshold', (tester) async {
      final CountingSource source = CountingSource(100);
      final DataListViewState state = await pumpList(
        tester,
        listNode(
          pagination: const PaginationModel(
            name: 'feed',
            source: PaginationSource.api,
            pageSize: 20,
            thresholdItems: 3,
          ),
        ),
        fetcher: source.call,
      );
      // 400px shows 8 rows: the first page doesn't reach its threshold.
      expect(source.pages, [1]);

      // Scroll in small steps to just past the threshold of page 1.
      for (int i = 0; i < 12; i++) {
        state.scrollController.jumpTo(state.scrollController.offset + 50);
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(source.pages, [1, 2]);

      // Moving around inside the loaded pages loads nothing more.
      state.scrollController.jumpTo(0);
      await tester.pumpAndSettle();
      state.scrollController.jumpTo(500);
      await tester.pumpAndSettle();
      expect(source.pages, [1, 2]);
      expect(state.controller!.items.length, 40);
    });

    testWidgets('a fast fling loads each page once', (tester) async {
      final CountingSource source = CountingSource(
        200,
        delay: const Duration(milliseconds: 300),
      );
      final DataListViewState state = await pumpList(
        tester,
        listNode(
          pagination: const PaginationModel(
            name: 'feed',
            source: PaginationSource.api,
            pageSize: 20,
          ),
        ),
        fetcher: source.call,
      );
      expect(source.pages, [1]);
      // Fling repeatedly while the next page is still loading.
      for (int i = 0; i < 6; i++) {
        await tester.fling(
          find.byType(CustomScrollView),
          const Offset(0, -3000),
          8000,
        );
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pumpAndSettle();
      // Every page was asked for once, in order, never twice.
      expect(source.pages.toSet().length, source.pages.length);
      expect(source.pages, List.generate(source.pages.length, (i) => i + 1));
      expect(state.controller!.items.length, source.pages.length * 20);
    });

    testWidgets('shows the loading footer while a page loads', (tester) async {
      final Completer<void> gate = Completer<void>();
      int calls = 0;
      await pumpList(
        tester,
        listNode(
          pagination: const PaginationModel(
            name: 'feed',
            source: PaginationSource.api,
            pageSize: 4,
            loadingNodeId: 'spinner',
            endNodeId: 'done',
          ),
        ),
        fetcher: (request) async {
          calls++;
          if (calls > 1) await gate.future;
          return PageResult([
            for (int i = 0; i < 4; i++) {'id': request.offset + i},
          ], totalCount: 8);
        },
      );
      // Four rows don't fill the list: the next page loads at once.
      await tester.pump();
      expect(find.text('node spinner'), findsOneWidget);
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('node spinner'), findsNothing);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(find.text('node done'), findsOneWidget);
    });

    testWidgets('an error footer retries on tap', (tester) async {
      bool fail = true;
      final DataListViewState state = await pumpList(
        tester,
        listNode(
          pagination: const PaginationModel(
            name: 'feed',
            source: PaginationSource.api,
            pageSize: 4,
          ),
        ),
        fetcher: (request) async {
          if (request.page == 2 && fail) throw StateError('offline');
          return PageResult([
            for (int i = 0; i < 4; i++) {'id': request.offset + i},
          ], totalCount: 12);
        },
      );
      await tester.pumpAndSettle();
      expect(find.text('Tap to retry'), findsOneWidget);
      expect(state.controller!.items.length, 4);
      fail = false;
      await tester.tap(find.text('Tap to retry'));
      await tester.pumpAndSettle();
      expect(state.controller!.error, isNull);
      expect(state.controller!.items.length, 12);
    });
  });

  testWidgets('two-way loading keeps the rows on screen in place', (
    tester,
  ) async {
    final CountingSource source = CountingSource(200);
    final DataListViewState state = await pumpList(
      tester,
      listNode(
        pagination: const PaginationModel(
          name: 'chat',
          source: PaginationSource.api,
          mode: PaginationMode.bidirectional,
          pageSize: 20,
          initialPage: 5,
          thresholdItems: 0,
        ),
      ),
      fetcher: source.call,
    );
    // The anchor page (items 80–99) shows first, at the top.
    expect(find.text('row 80'), findsOneWidget);
    final double before = tester.getTopLeft(find.text('row 82')).dy;

    // Load the page before it: it goes above, and row 82 doesn't move.
    await state.controller!.loadPrevious();
    await tester.pumpAndSettle();
    expect(state.controller!.items.length, greaterThanOrEqualTo(40));
    expect(tester.getTopLeft(find.text('row 82')).dy, before);

    // Scrolling up shows the earlier rows.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 200));
    await tester.pumpAndSettle();
    expect(find.text('row 78'), findsOneWidget);
  });

  testWidgets('pull to refresh reloads the first page', (tester) async {
    final CountingSource source = CountingSource(60);
    await pumpList(
      tester,
      listNode(
        pagination: const PaginationModel(
          name: 'inbox',
          source: PaginationSource.api,
          pageSize: 20,
          pullToRefresh: true,
        ),
      ),
      fetcher: source.call,
    );
    expect(find.byType(RefreshIndicator), findsOneWidget);
    expect(source.pages, [1]);
    await tester.fling(
      find.byType(CustomScrollView),
      const Offset(0, 300),
      1000,
    );
    await tester.pumpAndSettle();
    expect(source.pages, [1, 1]);
  });

  testWidgets('pages mode publishes its state as a variable', (tester) async {
    final CodelesslyContext codelessly = CodelesslyContext.empty();
    final DataListViewState state = await pumpList(
      tester,
      listNode(
        pagination: const PaginationModel(
          name: 'contacts',
          mode: PaginationMode.pages,
          pageSize: 10,
        ),
      ),
      data: [for (int i = 0; i < 35; i++) {'id': i}],
      codelessly: codelessly,
    );
    expect(find.text('row 0'), findsOneWidget);
    expect(find.text('row 10'), findsNothing);
    Map variable() => codelessly
        .findVariableByName('contacts')!
        .value
        .getValue()
        .typedValue<Map>()!;
    expect(variable()['pageCount'], 4);
    expect(variable()['page'], 1);
    await state.controller!.goTo(4);
    await tester.pumpAndSettle();
    expect(find.text('row 30'), findsOneWidget);
    expect(variable()['page'], 4);
    expect(variable()['from'], 31);
    expect(variable()['to'], 35);
    expect((variable()['items'] as List).length, 5);
  });

  group('sections', () {
    final List<Object?> contacts = [
      for (final String letter in ['A', 'B', 'C', 'D'])
        for (int i = 0; i < 10; i++) {'name': '$letter$i', 'letter': letter},
    ];

    testWidgets('groups items under pinned headers', (tester) async {
      final DataListViewState state = await pumpList(
        tester,
        listNode(
          sections: const ListSectionsModel(
            groupBy: 'letter',
            headerNodeId: 'header',
          ),
        ),
        data: contacts,
      );
      expect(find.text('node header A'), findsOneWidget);
      // Scroll into section B: B's header pins at the top.
      state.scrollController.jumpTo(30 + 500 + 30 + 100);
      await tester.pumpAndSettle();
      expect(find.text('node header B'), findsOneWidget);
      expect(tester.getTopLeft(find.text('node header B')).dy, 0);
      expect(find.text('node header A'), findsNothing);
    });

    testWidgets('the index bar jumps to a section', (tester) async {
      final DataListViewState state = await pumpList(
        tester,
        listNode(
          sections: const ListSectionsModel(
            groupBy: 'letter',
            headerNodeId: 'header',
            indexBar: true,
          ),
        ),
        data: contacts,
      );
      expect(find.byType(SectionIndexBar), findsOneWidget);
      state.jumpToSection(2);
      await tester.pumpAndSettle();
      expect(state.scrollController.offset, 2 * (30 + 500));
      expect(find.text('row C0'), findsOneWidget);
      // Tapping D on the bar.
      final Rect bar = tester.getRect(find.byType(SectionIndexBar));
      await tester.tapAt(Offset(bar.center.dx, bar.bottom - 5));
      await tester.pumpAndSettle();
      expect(find.text('node header D'), findsOneWidget);
    });

    test('groupIntoSections and sectionOffset', () {
      final sections = groupIntoSections(
        ['a1', 'a2', 'b1', 'c1', 'c2', 'c3'],
        (i, item) => (item as String)[0],
      );
      expect(sections, const [
        ListSection('a', 0, 2),
        ListSection('b', 2, 1),
        ListSection('c', 3, 3),
      ]);
      expect(
        sectionOffset(sections, 2, itemExtent: 10, headerExtent: 5),
        5 + 20 + 5 + 10,
      );
      expect(
        sectionOffset(sections, 1, itemExtent: null, headerExtent: 5),
        isNull,
      );
    });
  });

  group('swipe actions', () {
    late VariableData mail;
    late CodelesslyContext codelessly;

    setUp(() {
      mail = VariableData(
        id: 'mail',
        name: 'mail',
        type: VariableType.list,
        value: [
          for (int i = 0; i < 5; i++) {'id': i},
        ],
      );
      codelessly = CodelesslyContext.empty().copyWith(
        variables: {mail.id: Observable(mail)},
      );
    });

    ListViewNode swipeList() =>
        listNode(
            swipeActions: const SwipeActionsModel(
              endActions: [SwipeActionModel(id: 'delete', label: 'Delete')],
              undoMs: 1000,
              apply: ListApply.variable,
            ),
          )
          ..variables['data'] = r'${mail}';

    List<Object?> mailValue() =>
        codelessly.findVariableByName('mail')!.value.getValue().typedValue<List>()!;

    testWidgets('a full swipe removes the item after the undo bar', (
      tester,
    ) async {
      await pumpList(
        tester,
        swipeList(),
        data: mailValue(),
        codelessly: codelessly,
      );
      await tester.drag(find.text('row 1'), const Offset(-250, 0));
      await tester.pumpAndSettle();
      expect(find.text('row 1'), findsNothing);
      expect(find.byType(UndoBar), findsOneWidget);
      // Not applied yet.
      expect(mailValue().length, 5);
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pumpAndSettle();
      expect(find.byType(UndoBar), findsNothing);
      expect(mailValue().map((m) => (m as Map)['id']), [0, 2, 3, 4]);
    });

    testWidgets('undo puts the item back', (tester) async {
      await pumpList(
        tester,
        swipeList(),
        data: mailValue(),
        codelessly: codelessly,
      );
      await tester.drag(find.text('row 2'), const Offset(-250, 0));
      await tester.pumpAndSettle();
      expect(find.text('row 2'), findsNothing);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(find.text('row 2'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1100));
      expect(mailValue().length, 5);
    });

    testWidgets('a short swipe reveals the action to tap', (tester) async {
      await pumpList(
        tester,
        swipeList(),
        data: mailValue(),
        codelessly: codelessly,
      );
      await tester.drag(find.text('row 3'), const Offset(-60, 0));
      await tester.pumpAndSettle();
      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('row 3'), findsOneWidget);
    });
  });

  testWidgets('a list node with pagination builds a DataListView and the '
      'Paginate action moves it', (tester) async {
    final VariableData rows = VariableData(
      id: 'rows',
      name: 'rows',
      type: VariableType.list,
      value: [
        for (int i = 0; i < 10000; i++) {'id': i},
      ],
    );
    final List<BaseNode> nodes = [
      ListViewNode(
        id: 'list',
        name: 'list',
        basicBoxLocal: NodeBox(0, 0, 300, 400),
        properties: ListViewProperties(),
        variables: {'data': r'${rows}'},
        children: const ['row'],
        pagination: const PaginationModel(
          name: 'rowsPager',
          mode: PaginationMode.pages,
          pageSize: 50,
        ),
      )..parentID = kRootNode,
      RectangleNode(
        id: 'row',
        name: 'row',
        basicBoxLocal: NodeBox(0, 0, 300, 40),
      )..parentID = 'list',
    ];
    final registry = NodeRegistry()
      ..setNodes({for (final node in nodes) node.id: node});
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    final CodelesslyContext codelessly = CodelesslyContext.empty().copyWith(
      variables: {rows.id: Observable(rows)},
    );
    late BuildContext listContext;
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: codelessly,
        child: MaterialApp(
          home: Material(
            child: Align(
              alignment: Alignment.topLeft,
              child: Builder(
                builder: (context) {
                  listContext = context;
                  return manager.buildWidgetFromNode(
                    nodes.first,
                    context,
                    settings: const WidgetBuildSettings(debugLabel: 'test'),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(DataListView), findsOneWidget);
    // The template has a fixed height: rows have a fixed extent, lazily.
    expect(find.byType(SliverFixedExtentList), findsOneWidget);
    expect(find.byType(IndexedItemProvider).evaluate().length, lessThan(25));

    final PaginationController pager = codelessly.pagination['rowsPager']!;
    expect(pager.pageCount, 200);
    await FunctionsRepository.paginate(
      listContext,
      PaginateAction(
        controller: 'rowsPager',
        command: PaginateCommand.goTo,
        page: '120',
      ),
    );
    await tester.pumpAndSettle();
    expect(pager.page, 120);
    final IndexedItemProvider first = tester.widget<IndexedItemProvider>(
      find.byType(IndexedItemProvider).first,
    );
    expect((first.item.item as Map)['id'], 119 * 50);

    await FunctionsRepository.paginate(
      listContext,
      PaginateAction(
        controller: 'rowsPager',
        command: PaginateCommand.setPageSize,
        pageSize: '100',
      ),
    );
    await tester.pumpAndSettle();
    expect(pager.pageSize, 100);
    expect(pager.page, 60);
  });

  testWidgets('a grid with pagination pages lazily and loads near its end', (
    tester,
  ) async {
    final VariableData photos = VariableData(
      id: 'photos',
      name: 'photos',
      type: VariableType.list,
      value: [
        for (int i = 0; i < 1000; i++) {'id': i},
      ],
    );
    final List<BaseNode> nodes = [
      GridViewNode(
        id: 'grid',
        name: 'grid',
        basicBoxLocal: NodeBox(0, 0, 300, 400),
        properties: GridViewProperties(
          gridDelegate: FixedCrossAxisCountGridDelegateProperties(
            crossAxisCount: 3,
            mainAxisExtent: 100,
          ),
        ),
        variables: {'data': r'${photos}'},
        children: const ['tile'],
        pagination: const PaginationModel(name: 'photoPages', pageSize: 30),
      )..parentID = kRootNode,
      RectangleNode(
        id: 'tile',
        name: 'tile',
        basicBoxLocal: NodeBox(0, 0, 100, 100),
      )..parentID = 'grid',
    ];
    final registry = NodeRegistry()
      ..setNodes({for (final node in nodes) node.id: node});
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    final CodelesslyContext codelessly = CodelesslyContext.empty().copyWith(
      variables: {photos.id: Observable(photos)},
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: codelessly,
        child: MaterialApp(
          home: Material(
            child: Align(
              alignment: Alignment.topLeft,
              child: Builder(
                builder: (context) => manager.buildWidgetFromNode(
                  nodes.first,
                  context,
                  settings: const WidgetBuildSettings(debugLabel: 'test'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(SliverGrid), findsOneWidget);
    final PaginationController pager = codelessly.pagination['photoPages']!;
    expect(pager.items.length, 30);
    expect(find.byType(IndexedItemProvider).evaluate().length, lessThan(40));
    // Scroll to the end of the first page's 10 rows.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(pager.items.length, 60);
  });
}
