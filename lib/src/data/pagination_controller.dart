import 'dart:async';
import 'dart:math' as math;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/foundation.dart';

/// A page a [PaginationController] asks its source for.
@immutable
class PageRequest {
  /// The page's number, from 1.
  final int page;

  /// How many items the page holds.
  final int pageSize;

  /// The cursor the page before it returned, for a cursor source; null for
  /// the first page.
  final Object? cursor;

  /// Creates a [PageRequest].
  const PageRequest({required this.page, required this.pageSize, this.cursor});

  /// The index of the page's first item.
  int get offset => (page - 1) * pageSize;

  /// The values an API's parameters read as `${page.*}`.
  Map<String, Object?> toMap() => {
    'page': page,
    'pageSize': pageSize,
    'offset': offset,
    'limit': pageSize,
    'cursor': cursor,
  };

  @override
  bool operator ==(Object other) =>
      other is PageRequest &&
      other.page == page &&
      other.pageSize == pageSize &&
      other.cursor == cursor;

  @override
  int get hashCode => Object.hash(page, pageSize, cursor);

  @override
  String toString() => 'PageRequest($page, size $pageSize, cursor $cursor)';
}

/// What a source returns for a [PageRequest].
@immutable
class PageResult {
  /// The page's items.
  final List<Object?> items;

  /// The number of items of all pages, when the source counts them.
  final int? totalCount;

  /// The cursor of the next page, for a cursor source.
  final Object? nextCursor;

  /// Whether pages follow, when the source says so. Otherwise a page that
  /// is shorter than the page size, or a cursor source without a next
  /// cursor, is the last.
  final bool? hasMore;

  /// Creates a [PageResult].
  const PageResult(
    this.items, {
    this.totalCount,
    this.nextCursor,
    this.hasMore,
  });
}

/// Loads one page.
typedef PageFetcher = Future<PageResult> Function(PageRequest request);

/// Loads the pages of a list ([PaginationModel]) from a [PageFetcher], keeps
/// the pages it loaded, and exposes the list's state ([state]).
///
/// It never asks for a page twice at once: a request for a page that is
/// loading waits for that load. A list scrolled fast to its end therefore
/// loads the next page once, however many items it builds meanwhile.
class PaginationController extends ChangeNotifier {
  /// Creates a [PaginationController].
  PaginationController({required PaginationModel model, PageFetcher? fetcher})
    : _model = model,
      _fetcher = fetcher,
      _pageSize = math.max(1, model.pageSize),
      _page = math.max(1, model.initialPage);

  PaginationModel _model;
  PageFetcher? _fetcher;

  /// The model this controller follows.
  PaginationModel get model => _model;

  int _pageSize;
  int _page;
  int? _totalCount;

  /// The highest page number known to exist, when the end was reached.
  int? _lastPage;

  /// The loaded pages, by number.
  final Map<int, List<Object?>> _pages = {};

  /// The cursor that loads each page; page 1's is null.
  final Map<int, Object?> _cursors = {1: null};

  /// The pages being fetched from the source.
  final Map<int, Future<void>> _inFlight = {};

  /// The pages being loaded to show (a fetch, after the pages a cursor
  /// needs first), registered at once so a second request joins the first.
  final Map<int, Future<void>> _loads = {};

  bool get _busy => _inFlight.isNotEmpty || _loads.isNotEmpty;

  /// The range of loaded pages a scrolling list shows.
  int? _firstShown;
  int? _lastShown;

  Object? _error;
  int? _failedPage;
  bool _refreshing = false;
  bool _disposed = false;

  /// Bumped by every refresh, so loads started before it are dropped.
  int _generation = 0;

  /// How many times the source was asked for a page; for tests and
  /// diagnostics.
  int get fetchCount => _fetchCount;
  int _fetchCount = 0;

  /// The current page (pages mode), or the last page shown (scrolling).
  int get page => _page;

  /// How many items a page holds.
  int get pageSize => _pageSize;

  /// The number of items of all pages, when known.
  int? get totalCount => _totalCount;

  /// The number of pages, when known: from the total, or once the last page
  /// has loaded.
  int? get pageCount {
    if (_totalCount != null) {
      return math.max(1, (_totalCount! / _pageSize).ceil());
    }
    return _lastPage;
  }

  /// The error of the last load that failed, until a load works.
  Object? get error => _error;

  /// Whether the first page is loading.
  bool get isLoading => _busy && _pages.isEmpty;

  /// Whether a page loads while others show.
  bool get isLoadingMore => _busy && _pages.isNotEmpty;

  /// Whether a refresh is under way.
  bool get isRefreshing => _refreshing;

  /// Whether a page follows the last one shown.
  bool get hasMore {
    final int last = _model.autoPaginates ? (_lastShown ?? 0) : _page;
    final int? count = pageCount;
    if (count != null) return last < count;
    return true;
  }

  /// Whether a page comes before the first one shown.
  bool get hasPrevious {
    final int first = _model.autoPaginates ? (_firstShown ?? _page) : _page;
    return first > 1;
  }

  /// The source of the pages; replacing it forgets what was loaded.
  set fetcher(PageFetcher? fetcher) {
    if (identical(fetcher, _fetcher)) return;
    _fetcher = fetcher;
  }

  /// Follows a changed [model]. A change of source or page size forgets
  /// the loaded pages.
  void updateModel(PaginationModel model) {
    if (model == _model) return;
    final bool resets =
        model.source != _model.source ||
        model.pageSize != _model.pageSize ||
        model.strategy != _model.strategy ||
        model.apiId != _model.apiId ||
        !mapEquals(model.parameters, _model.parameters) ||
        model.mode != _model.mode;
    _model = model;
    if (resets) {
      _pageSize = math.max(1, model.pageSize);
      _clear();
      _page = math.max(1, model.initialPage);
      _notify();
    }
  }

  /// The items to show: the current page's, or every page shown by a
  /// scrolling list, without repeats by [PaginationModel.keyPath].
  List<Object?> get items {
    if (!_model.autoPaginates) return _dedupe(_pages[_page] ?? const []);
    final int? first = _firstShown;
    final int? last = _lastShown;
    if (first == null || last == null) return const [];
    return _dedupe([
      for (int page = first; page <= last; page++) ...?_pages[page],
    ]);
  }

  /// In a list that loads both ways, the items of the pages before
  /// [PaginationModel.initialPage] (shown above the anchor, nearest last)
  /// and of the pages from it on.
  ({List<Object?> before, List<Object?> after}) get anchoredItems {
    final int anchor = math.max(1, _model.initialPage);
    final int? first = _firstShown;
    final int? last = _lastShown;
    if (first == null || last == null) return (before: const [], after: const []);
    final List<Object?> all = items;
    int beforeCount = 0;
    for (int page = first; page < anchor && page <= last; page++) {
      beforeCount += _pages[page]?.length ?? 0;
    }
    beforeCount = math.min(beforeCount, all.length);
    return (
      before: all.sublist(0, beforeCount),
      after: all.sublist(beforeCount),
    );
  }

  /// The 1-based index of the first item shown on the current page.
  int get from {
    final int count = items.length;
    if (count == 0) return 0;
    if (_model.autoPaginates) return ((_firstShown ?? 1) - 1) * _pageSize + 1;
    return (_page - 1) * _pageSize + 1;
  }

  /// The 1-based index of the last item shown.
  int get to {
    final int count = items.length;
    if (count == 0) return 0;
    return from + count - 1;
  }

  /// The status for a list's status variable: loading, empty, error or
  /// loaded.
  String get status {
    if (_error != null && _pages.isEmpty) return kQueryStatusError;
    if (isLoading) return kQueryStatusLoading;
    if (_pages.isEmpty) return kQueryStatusLoading;
    if (items.isEmpty) return kQueryStatusEmpty;
    return kQueryStatusLoaded;
  }

  /// The state, as the map variable named by [PaginationModel.name] holds it.
  Map<String, Object?> get state => {
    'items': items,
    'page': _page,
    'pageSize': _pageSize,
    'pageCount': pageCount,
    'totalCount': _totalCount,
    'from': from,
    'to': to,
    'hasMore': hasMore,
    'hasPrevious': hasPrevious,
    'isLoading': isLoading,
    'isLoadingMore': isLoadingMore,
    'isRefreshing': _refreshing,
    'error': _error?.toString(),
    'status': status,
    'pageSizeOptions': _model.pageSizeOptions,
  };

  List<Object?> _dedupe(List<Object?> items) {
    final String path = _model.keyPath.trim();
    if (path.isEmpty) return items;
    final Set<Object?> seen = {};
    final List<Object?> result = [];
    for (final Object? item in items) {
      final Object? key = keyOf(item, path);
      if (key == null || seen.add(key)) result.add(item);
    }
    return result.length == items.length ? items : result;
  }

  /// The value at [path] (dot separated) in [item], or null.
  static Object? keyOf(Object? item, String path) {
    Object? value = item;
    for (final String part in path.split('.')) {
      if (value is Map) {
        value = value[part];
      } else if (value is List) {
        final int? index = int.tryParse(part);
        value = index == null ? null : value.elementAtOrNull(index);
      } else {
        return null;
      }
    }
    return value;
  }

  /// Loads the first page to show, unless one is shown or loading.
  Future<void> start() {
    if (_pages.isNotEmpty || _busy) {
      return _loads.values.firstOrNull ??
          _inFlight.values.firstOrNull ??
          Future.value();
    }
    return _show(_page);
  }

  /// Shows [page] (pages mode) after loading it, if needed. In a scrolling
  /// list it jumps: the shown pages become just [page].
  Future<void> goTo(int page) async {
    final int target = math.max(1, page);
    final int? count = pageCount;
    await _show(count == null ? target : math.min(target, count));
  }

  /// Shows (or, in a scrolling list, appends) the next page.
  Future<void> next() {
    if (_model.autoPaginates) return loadMore();
    if (!hasMore) return Future.value();
    return _show(_page + 1);
  }

  /// Shows the page before the current one; in a list that loads both
  /// ways, puts the page before the first shown in front.
  Future<void> previous() {
    if (_model.autoPaginates) return loadPrevious();
    if (_page <= 1) return Future.value();
    return _show(_page - 1);
  }

  /// Shows the first page.
  Future<void> first() => _show(1);

  /// Shows the last page, once the number of pages is known.
  Future<void> last() async {
    final int? count = pageCount;
    if (count != null) await _show(count);
  }

  /// Appends the page after the last one shown, unless the end is reached,
  /// it is already loading, or the last load failed (retry first).
  Future<void> loadMore() {
    final int next = (_lastShown ?? 0) + 1;
    if (_lastShown == null) return start();
    if (!hasMore || _error != null) return Future.value();
    final Future<void>? loading = _loads[next];
    if (loading != null) return loading;
    return _load(next, onLoaded: () => _lastShown = next);
  }

  /// Puts the page before the first one shown in front, in a list that
  /// loads both ways.
  Future<void> loadPrevious() {
    final int? first = _firstShown;
    if (first == null) return start();
    if (first <= 1 || _error != null) return Future.value();
    final int previous = first - 1;
    final Future<void>? loading = _loads[previous];
    if (loading != null) return loading;
    return _load(previous, onLoaded: () => _firstShown = previous);
  }

  /// Loads again the page that failed.
  Future<void> retry() {
    final int? failed = _failedPage;
    _error = null;
    _failedPage = null;
    _notify();
    if (failed == null) return start();
    if (!_model.autoPaginates || _lastShown == null) return _show(failed);
    if (failed > (_lastShown ?? 0)) return loadMore();
    return loadPrevious();
  }

  /// Forgets every loaded page and loads the first one again. The items
  /// shown stay until it loads.
  Future<void> refresh() async {
    _refreshing = true;
    _notify();
    final int target = _model.autoPaginates
        ? math.max(1, _model.initialPage)
        : _page;
    final Map<int, List<Object?>> previous = Map.of(_pages);
    final (int?, int?) shown = (_firstShown, _lastShown);
    _clear(keepShown: true);
    // Keep showing the old items while the page reloads.
    _pages.addAll(previous);
    final int generation = _generation;
    try {
      await _fetchInto(target, generation, replace: true);
      if (generation == _generation) {
        _pages.removeWhere((page, _) => page != target);
        _page = target;
        if (_model.autoPaginates) {
          _firstShown = target;
          _lastShown = target;
        }
      }
    } catch (_) {
      if (generation == _generation) {
        _firstShown = shown.$1;
        _lastShown = shown.$2;
      }
    } finally {
      _refreshing = false;
      _notify();
    }
  }

  /// Changes the page size, keeping the first item shown on screen.
  Future<void> setPageSize(int size) {
    final int newSize = math.max(1, size);
    if (newSize == _pageSize) return Future.value();
    final int firstIndex = math.max(0, from - 1);
    _pageSize = newSize;
    _clear();
    _page = firstIndex ~/ newSize + 1;
    _notify();
    return _show(_page);
  }

  /// Gives a [PaginationSource.data] source its items: every item of the
  /// list's bound data. Pages are cut from them; a change forgets the
  /// pages cut from the old items.
  ///
  /// A list calls it while it builds with [notify] false: it already shows
  /// the new items, and the registry publishes the state after the frame.
  void setLocalItems(List<Object?> items, {bool notify = true}) {
    if (identical(items, _localItems) ||
        (_localItems != null && listEquals(items, _localItems))) {
      return;
    }
    final bool hadItems = _localItems != null;
    _localItems = items;
    _fetcher = _localFetcher;
    if (!hadItems) return;
    // Re-cut the pages already shown, synchronously, so the list doesn't
    // flash while it re-pages.
    final List<int> shown = _pages.keys.toList();
    _pages.clear();
    _lastPage = null;
    _totalCount = items.length;
    for (final int page in shown) {
      final PageRequest request = PageRequest(page: page, pageSize: _pageSize);
      _pages[page] = _slice(items, request);
    }
    if (notify) _notify();
  }

  List<Object?>? _localItems;

  Future<PageResult> _localFetcher(PageRequest request) =>
      SynchronousFuture(_localPage(request));

  PageResult _localPage(PageRequest request) {
    final List<Object?> items = _localItems ?? const [];
    return PageResult(_slice(items, request), totalCount: items.length);
  }

  static List<Object?> _slice(List<Object?> items, PageRequest request) {
    final int start = math.min(request.offset, items.length);
    final int end = math.min(start + request.pageSize, items.length);
    return items.sublist(start, end);
  }

  Future<void> _show(int page) async {
    if (_model.autoPaginates) {
      // A jump in a scrolling list starts its shown range again.
      if (_pages.containsKey(page)) {
        _firstShown = page;
        _lastShown = page;
        _page = page;
        _notify();
        return;
      }
      return _load(
        page,
        onLoaded: () {
          _firstShown = page;
          _lastShown = page;
        },
      );
    }
    if (_pages.containsKey(page) && _model.cachePages) {
      _page = page;
      _error = null;
      _notify();
      return;
    }
    return _load(page, onLoaded: () => _page = page);
  }

  Future<void> _load(int page, {required VoidCallback onLoaded}) {
    final Future<void>? loading = _loads[page];
    if (loading != null) return loading;
    final int generation = _generation;
    late final Future<void> future;
    future = () async {
      try {
        await _ensureCursor(page, generation);
        await _fetchInto(page, generation);
        if (generation != _generation) return;
        if (page > (_lastShown ?? 0) || !_model.autoPaginates) {
          _page = page;
        }
        onLoaded();
      } catch (error) {
        // Recorded by _fetchInto.
      } finally {
        if (identical(_loads[page], future)) _loads.remove(page);
        if (generation == _generation) _notify();
      }
    }();
    _loads[page] = future;
    return future;
  }

  /// For a cursor source, loads the pages before [page] in order so that
  /// its cursor is known (cached, so they aren't loaded again).
  Future<void> _ensureCursor(int page, int generation) async {
    if (_model.effectiveStrategy != PaginationStrategy.cursor) return;
    for (int before = 1; before < page; before++) {
      if (_cursors.containsKey(before + 1)) continue;
      if (_lastPage != null && before >= _lastPage!) return;
      await (_inFlight[before] ?? _fetchInto(before, generation));
      if (generation != _generation) return;
    }
  }

  Future<void> _fetchInto(
    int page,
    int generation, {
    bool replace = false,
  }) {
    final Future<void>? loading = _inFlight[page];
    if (loading != null && !replace) return loading;
    final PageFetcher? fetcher = _fetcher;
    if (fetcher == null) return Future.value();
    final PageRequest request = PageRequest(
      page: page,
      pageSize: _pageSize,
      cursor: _cursors[page],
    );
    _fetchCount++;
    final Completer<void> done = Completer<void>();
    _inFlight[page] = done.future;
    // Listeners hear about the load once it is under way.
    scheduleMicrotask(_notify);
    () async {
      try {
        final PageResult result = await fetcher(request);
        if (generation != _generation && !replace) return;
        _store(page, result);
        _error = null;
        _failedPage = null;
        done.complete();
      } catch (error, stackTrace) {
        if (generation == _generation || replace) {
          _error = error;
          _failedPage = page;
        }
        done.completeError(error, stackTrace);
      } finally {
        if (identical(_inFlight[page], done.future)) _inFlight.remove(page);
      }
    }();
    // Callers that don't await shouldn't see unhandled errors.
    done.future.ignore();
    return done.future;
  }

  void _store(int page, PageResult result) {
    _pages[page] = List<Object?>.unmodifiable(result.items);
    if (result.totalCount != null) _totalCount = result.totalCount;
    final bool cursor =
        _model.effectiveStrategy == PaginationStrategy.cursor;
    if (cursor && result.nextCursor != null) {
      _cursors[page + 1] = result.nextCursor;
    }
    final bool last =
        result.hasMore == false ||
        (result.hasMore == null &&
            (result.items.length < _pageSize ||
                (cursor && result.nextCursor == null) ||
                (_totalCount != null && page * _pageSize >= _totalCount!)));
    if (last) {
      _lastPage = page;
      _totalCount ??= (page - 1) * _pageSize + result.items.length;
    }
    if (!_model.cachePages && !_model.autoPaginates) {
      _pages.removeWhere((key, _) => key != page);
    }
  }

  void _clear({bool keepShown = false}) {
    _generation++;
    _pages.clear();
    _cursors
      ..clear()
      ..[1] = null;
    _inFlight.clear();
    _loads.clear();
    _totalCount = null;
    _lastPage = null;
    _error = null;
    _failedPage = null;
    if (!keepShown) {
      _firstShown = null;
      _lastShown = null;
    }
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
