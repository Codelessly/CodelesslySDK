import 'dart:async';

// Ported from SDK 8.x's test/pagination_controller_test.dart.
import 'package:codelessly_sdk_v2/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

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

void main() {
  test('pages mode shows one page at a time', () async {
    final FakeSource source = FakeSource(95);
    final PaginationController c = controller(source);
    await c.start();
    expect(ids(c), List.generate(10, (i) => i));
    expect(c.pageCount, 10);
    expect(c.totalCount, 95);
    expect((c.from, c.to), (1, 10));
    await c.goTo(10);
    expect(ids(c), List.generate(5, (i) => 90 + i));
    expect((c.from, c.to), (91, 95));
    expect(c.hasMore, isFalse);
    await c.previous();
    expect(c.page, 9);
    expect(c.state['hasPrevious'], isTrue);
  });

  test('loaded pages are cached until a refresh', () async {
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

  test('without caching a page loads every time it shows', () async {
    final FakeSource source = FakeSource(50);
    final PaginationController c = controller(source, cachePages: false);
    await c.start();
    await c.next();
    await c.previous();
    expect(source.requests.map((r) => r.page), [1, 2, 1]);
  });

  test('infinite mode appends pages and stops at the end', () async {
    final FakeSource source = FakeSource(25);
    final PaginationController c = controller(
      source,
      mode: PaginationMode.infinite,
    );
    await c.start();
    await c.loadMore();
    await c.loadMore();
    expect(ids(c), List.generate(25, (i) => i));
    expect(c.hasMore, isFalse);
    await c.loadMore();
    expect(source.requests.length, 3);
    expect((c.from, c.to), (1, 25));
  });

  test('a page asked for while it loads is loaded once', () async {
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

  test('items repeated by shifted offsets show once', () async {
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

  test('an empty key path keeps repeats', () async {
    final FakeSource source = FakeSource(40);
    final PaginationController c = controller(
      source,
      mode: PaginationMode.infinite,
      keyPath: '',
    );
    await c.start();
    source.shift = 2;
    await c.loadMore();
    expect(c.items.length, 20);
  });

  test('a failed page is retried and keeps what was shown', () async {
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

  test('a first page that fails reports the error status', () async {
    final FakeSource source = FakeSource(40)..fail = true;
    final PaginationController c = controller(source);
    await c.start();
    expect(c.status, queryStatusError);
    source.fail = false;
    await c.retry();
    expect(c.status, queryStatusLoaded);
  });

  test('a cursor source loads the pages before a page it jumps to', () async {
    final FakeSource source = FakeSource(55, counts: false, cursor: true);
    final PaginationController c = controller(
      source,
      strategy: PaginationStrategy.cursor,
    );
    await c.start();
    await c.goTo(4);
    expect(ids(c).first, 30);
    expect(source.requests.map((r) => r.cursor), [null, 10, 20, 30]);
    // The pages on the way are cached: going back loads nothing.
    await c.goTo(2);
    expect(source.requests.length, 4);
    // The end is found when there is no next cursor.
    await c.goTo(6);
    expect(c.pageCount, 6);
    expect(c.totalCount, 55);
    expect(c.hasMore, isFalse);
  });

  test('setPageSize keeps the first item shown', () async {
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

  test('two-way loading puts earlier pages in front of the anchor', () async {
    final FakeSource source = FakeSource(100);
    final PaginationController c = controller(
      source,
      mode: PaginationMode.bidirectional,
      initialPage: 5,
    );
    await c.start();
    expect(ids(c).first, 40);
    await c.loadPrevious();
    await c.loadMore();
    expect(ids(c).first, 30);
    expect(ids(c).last, 59);
    final anchored = c.anchoredItems;
    expect(anchored.before.length, 10);
    expect((anchored.after.first as Map)['id'], 40);
    expect(c.hasPrevious, isTrue);
  });

  test('a data source cuts pages from the bound list', () async {
    final PaginationController c = PaginationController(
      model: Pagination(name: 'p', mode: PaginationMode.pages),
    );
    c.setLocalItems([for (int i = 0; i < 45; i++) i]);
    await c.start();
    expect(c.items, List.generate(20, (i) => i));
    expect(c.pageCount, 3);
    await c.last();
    expect(c.items, [40, 41, 42, 43, 44]);
    // The bound list changes: the page shown is cut again at once.
    c.setLocalItems([for (int i = 0; i < 42; i++) i * 10]);
    expect(c.items, [400, 410]);
  });

  test('refresh keeps showing the old items until the new page loads', () async {
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

  test('the state map holds every documented key', () async {
    final PaginationController c = controller(FakeSource(5));
    await c.start();
    expect(c.state.keys, containsAll(<String>[
      'items',
      'page',
      'pageCount',
      'totalCount',
      'hasMore',
      'isLoading',
      'error',
      'from',
      'to',
      'status',
    ]));
  });
}
