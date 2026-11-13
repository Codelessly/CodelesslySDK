import 'dart:async';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart' as lists;

/// A source of [total] items `{'id': i}` that counts its calls and can be
/// held open or made to fail.
class FakeSource {
  FakeSource(this.total, {this.counts = true, this.cursor = false});

  final int total;
  final bool counts;
  final bool cursor;
  final List<PageRequest> requests = [];
  Completer<void>? gate;
  bool fail = false;

  /// Items inserted at the front after the first call, shifting offsets.
  int shift = 0;

  Future<PageResult> call(PageRequest request) async {
    requests.add(request);
    await gate?.future;
    if (fail) throw StateError('offline');
    final int start = cursor
        ? (request.cursor as int? ?? 0)
        : request.offset - shift;
    final int end = (start + request.pageSize).clamp(0, total);
    final List<Object?> items = [
      for (int i = start.clamp(0, total); i < end; i++) {'id': i},
    ];
    return PageResult(
      items,
      totalCount: counts ? total : null,
      nextCursor: cursor && end < total ? end : null,
    );
  }
}

PaginationController controller(
  FakeSource source, {
  PaginationMode mode = PaginationMode.pages,
  int pageSize = 10,
  PaginationStrategy strategy = PaginationStrategy.offset,
  String keyPath = 'id',
  bool cachePages = true,
  int initialPage = 1,
}) => PaginationController(
  model: Pagination(name: 'p', mode: mode)
      .set(PaginationFields.pageSize, pageSize)
      .set(PaginationFields.strategy, strategy)
      .set(PaginationFields.keyPath, keyPath)
      .set(PaginationFields.cachePages, cachePages)
      .set(PaginationFields.initialPage, initialPage)
      .set(PaginationFields.source, PaginationSource.api),
  fetcher: source.call,
);

List<Object?> ids(PaginationController c) => [
  for (final item in c.items) (item as Map)['id'],
];

// The pagination node: its controls show and move the controller it names.


Map<String, Json> nodes({int pageSize = 10, String controller = 'rowsPager'}) => {
      'col': {
        'type': 'column',
        'children': ['list', 'pager'],
        'layout': {'width': 1100, 'height': {'hug': 400}},
      },
      'list': {
        'type': 'listView',
        'children': ['row'],
        'layout': {'width': 400, 'height': 300},
        'bind': {'data': r'${rows}'},
        'props': {
          'pagination': {
            'name': 'rowsPager',
            'mode': 'pages',
            'pageSize': pageSize,
            'pageSizeOptions': [10, 25],
          },
        },
      },
      'row': {'type': 'box', 'layout': {'width': 400, 'height': 30}},
      'pager': {
        'type': 'pagination',
        // Test glyphs are wide: the controls fit on one run.
        'layout': {'width': 1100, 'height': 48},
        'props': {'controller': controller, 'showPageSize': true},
        'actions': [
          lists.reaction('changed', [
            {'type': 'setVariable', 'variable': 'chosen', 'value': r'${result}'},
          ]),
        ],
      },
    };

Variable rows(int count) => lists.v('rows', [for (var i = 0; i < count; i++) {'id': i}], VariableType.list);

void main() {
  group('loading pages', () {
    test('a loaded page is kept until a refresh', () async {
      final FakeSource source = FakeSource(50);
      final PaginationController c = controller(source);
      await c.start();
      await c.next();
      await c.previous();
      await c.next();
      expect(source.requests.map((r) => r.page), [1, 2]);
      await c.refresh();
      expect(source.requests.map((r) => r.page), [1, 2, 2]);
      expect(c.page, 2);
    });

    test('a page asked for again while it loads is loaded once', () async {
      final FakeSource source = FakeSource(100);
      final PaginationController c = controller(
        source,
        mode: PaginationMode.infinite,
      );
      await c.start();
      source.gate = Completer<void>();
      // A fast fling builds the last items many times before the page lands.
      final List<Future<void>> calls = [for (int i = 0; i < 20; i++) c.loadMore()];
      expect(c.isLoadingMore, isTrue);
      source.gate!.complete();
      await Future.wait(calls);
      expect(source.requests.map((r) => r.page), [1, 2]);
      expect(c.items.length, 20);
    });

    test('an item repeated across pages shows once', () async {
      final FakeSource source = FakeSource(40);
      final PaginationController c = controller(
        source,
        mode: PaginationMode.infinite,
      );
      await c.start();
      // Two items were added before the first page: page 2 repeats 8 and 9.
      source.shift = 2;
      await c.loadMore();
      expect(ids(c), List.generate(18, (i) => i));
    });

    test('a page that fails keeps what was shown and can be retried', () async {
      final FakeSource source = FakeSource(40);
      final PaginationController c = controller(
        source,
        mode: PaginationMode.infinite,
      );
      await c.start();
      source.fail = true;
      await c.loadMore();
      expect(c.error, isA<StateError>());
      expect(c.state['error'], contains('offline'));
      expect(c.items.length, 10);
      // No automatic loads while the error shows.
      await c.loadMore();
      expect(source.requests.length, 2);
      source.fail = false;
      await c.retry();
      expect(c.error, isNull);
      expect(c.items.length, 20);
    });

    test('a first page that fails reports an error', () async {
      final FakeSource source = FakeSource(40)..fail = true;
      final PaginationController c = controller(source);
      await c.start();
      expect(c.status, queryStatusError);
      source.fail = false;
      await c.retry();
      expect(c.status, queryStatusLoaded);
    });

    test('changing the page size keeps the first shown item on screen', () async {
      final FakeSource source = FakeSource(200);
      final PaginationController c = controller(source);
      await c.start();
      await c.goTo(5);
      expect(c.from, 41);
      await c.setPageSize(25);
      expect(c.page, 2);
      expect(c.from, 26);
      expect(c.pageCount, 8);
    });

    test('a refresh keeps showing the old items until the new page arrives', () async {
      final FakeSource source = FakeSource(30);
      final PaginationController c = controller(
        source,
        mode: PaginationMode.infinite,
      );
      await c.start();
      await c.loadMore();
      source.gate = Completer<void>();
      final Future<void> refreshing = c.refresh();
      expect(c.isRefreshing, isTrue);
      expect(c.items.length, 20);
      source.gate!.complete();
      await refreshing;
      expect(c.isRefreshing, isFalse);
      expect(c.items.length, 10);
    });
  });

  group('pagination controls', () {
    late lists.Screen s;
    Future<PaginationController> pump(WidgetTester tester, int count, {String controller = 'rowsPager'}) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      s = await lists.show(tester, nodes(controller: controller), variables: [rows(count), lists.v('chosen', '')]);
      await tester.pumpAndSettle();
      return PaginationRegistry.of(s.tree)['rowsPager']!;
    }

    testWidgets('show the current page and move it', (tester) async {
      final c = await pump(tester, 35);
      expect(find.text('Showing 1–10 of 35'), findsOneWidget);
      for (final page in ['1', '2', '3', '4']) {
        expect(find.text(page), findsOneWidget, reason: page);
      }
      await tester.tap(find.text('3'));
      await tester.pumpAndSettle();
      expect(c.page, 3);
      expect(s['chosen'], '3');
      expect(find.text('Showing 21–30 of 35'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Next page'));
      await tester.pumpAndSettle();
      expect(find.text('Showing 31–35 of 35'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('First page'));
      await tester.pumpAndSettle();
      expect(c.page, 1);
    });

    testWidgets('disable previous on the first page', (tester) async {
      await pump(tester, 35);
      final previous = tester.widget<Semantics>(find
          .ancestor(
            of: find.text('‹'),
            matching: find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Previous page'),
          )
          .first);
      expect(previous.properties.enabled, isFalse);
    });

    testWidgets('shorten long page ranges with ellipses', (tester) async {
      final c = await pump(tester, 200);
      await c.goTo(10);
      await tester.pumpAndSettle();
      // 1 … 9 10 11 … 20
      expect(find.text('…'), findsNWidgets(2));
      expect(find.text('20'), findsOneWidget);
      expect(find.text('9'), findsOneWidget);
      expect(find.text('5'), findsNothing);
    });

    testWidgets('change the page size from their size menu', (tester) async {
      final c = await pump(tester, 100);
      expect(find.text('Rows per page'), findsOneWidget);
      await tester.tap(find.byType(DropdownButton<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('25').last);
      await tester.pumpAndSettle();
      expect(c.pageSize, 25);
      expect(find.text('Showing 1–25 of 100'), findsOneWidget);
    });

    testWidgets('show a preview on the design canvas', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      s = await lists.show(tester, {'col': nodes(controller: 'missing')['pager']!}, variables: [lists.v('chosen', '')]);
      await tester.pumpAndSettle();
      expect(find.text('Showing 1–20 of 200'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
