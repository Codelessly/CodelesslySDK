// Pagination controllers: a list's `pagination` loads its items page
// by page from its bound data, an API or its cloud query, and publishes its
// state as a map variable named after it (`${contacts.page}`...). Paginate
// actions move a controller by name.
import 'dart:async';
import 'dart:math' as math;

import 'package:codelessly_api/codelessly_api.dart'
    show Json, ListViewProps, Node, Pagination, PaginationMode, PaginationSource, PaginationStrategy, Variable, VariableType;
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../../render/node_tree.dart';
import '../contracts.dart';
import '../expressions/scopes.dart';

/// A list's status values (`statusVariable`, `${name.status}`).
const String queryStatusLoading = 'loading';
const String queryStatusEmpty = 'empty';
const String queryStatusError = 'error';
const String queryStatusLoaded = 'loaded';

/// A page a [PaginationController] asks its source for.
@immutable
class PageRequest {
  const PageRequest({required this.page, required this.pageSize, this.cursor});

  /// The page's number, from 1.
  final int page;

  /// How many items the page holds.
  final int pageSize;

  /// The cursor the page before it returned, for a cursor source; null for
  /// the first page.
  final Object? cursor;

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
      other is PageRequest && other.page == page && other.pageSize == pageSize && other.cursor == cursor;

  @override
  int get hashCode => Object.hash(page, pageSize, cursor);

  @override
  String toString() => 'PageRequest($page, size $pageSize, cursor $cursor)';
}

/// What a source returns for a [PageRequest].
@immutable
class PageResult {
  const PageResult(this.items, {this.totalCount, this.nextCursor, this.hasMore});

  final List<Object?> items;

  /// The number of items of all pages, when the source counts them.
  final int? totalCount;

  /// The cursor of the next page, for a cursor source.
  final Object? nextCursor;

  /// Whether pages follow, when the source says so. Otherwise a page
  /// shorter than the page size, or a cursor source without a next cursor,
  /// is the last.
  final bool? hasMore;
}

/// Loads one page.
typedef PageFetcher = Future<PageResult> Function(PageRequest request);

/// Loads the pages of a list ([Pagination]) from a [PageFetcher], keeps the
/// pages it loaded, and exposes the list's [state].
///
/// It never asks for a page twice at once: a request for a page that is
/// loading waits for that load.
class PaginationController extends ChangeNotifier {
  PaginationController({required Pagination model, this._fetcher})
      : _model = model,
        _pageSize = math.max(1, model.pageSize),
        _page = math.max(1, model.initialPage);

  Pagination _model;
  PageFetcher? _fetcher;

  Pagination get model => _model;

  bool get _autoPaginates => _model.mode != PaginationMode.pages;

  int _pageSize;
  int _page;
  int? _totalCount;

  /// The highest page number known to exist, when the end was reached.
  int? _lastPage;

  final Map<int, List<Object?>> _pages = {};

  /// The cursor that loads each page; page 1's is null.
  final Map<int, Object?> _cursors = {1: null};

  /// The pages being fetched from the source.
  final Map<int, Future<void>> _inFlight = {};

  /// The pages being loaded to show, registered at once so a second
  /// request joins the first.
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

  /// How many times the source was asked for a page.
  int get fetchCount => _fetchCount;
  int _fetchCount = 0;

  /// The current page (pages mode), or the last page shown (scrolling).
  int get page => _page;
  int get pageSize => _pageSize;
  int? get totalCount => _totalCount;

  /// The number of pages, when known: from the total, or once the last page
  /// has loaded.
  int? get pageCount {
    if (_totalCount != null) return math.max(1, (_totalCount! / _pageSize).ceil());
    return _lastPage;
  }

  Object? get error => _error;

  /// Whether the first page is loading.
  bool get isLoading => _busy && _pages.isEmpty;

  /// Whether a page loads while others show.
  bool get isLoadingMore => _busy && _pages.isNotEmpty;
  bool get isRefreshing => _refreshing;

  /// Whether a page follows the last one shown.
  bool get hasMore {
    final last = _autoPaginates ? (_lastShown ?? 0) : _page;
    final count = pageCount;
    if (count != null) return last < count;
    return true;
  }

  /// Whether a page comes before the first one shown.
  bool get hasPrevious => (_autoPaginates ? (_firstShown ?? _page) : _page) > 1;

  /// The source of the pages.
  set fetcher(PageFetcher? fetcher) {
    if (identical(fetcher, _fetcher)) return;
    _fetcher = fetcher;
  }

  /// Follows a changed [model]. A change of source, page size, strategy,
  /// API, parameters or mode forgets the loaded pages.
  void updateModel(Pagination model) {
    if (model == _model) return;
    final resets = model.source != _model.source ||
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
  /// scrolling list, without repeats by [Pagination.keyPath].
  List<Object?> get items {
    if (!_autoPaginates) return _dedupe(_pages[_page] ?? const []);
    final first = _firstShown, last = _lastShown;
    if (first == null || last == null) return const [];
    return _dedupe([for (var p = first; p <= last; p++) ...?_pages[p]]);
  }

  /// In a list that loads both ways, the items of the pages before
  /// [Pagination.initialPage] (shown above the anchor) and from it on.
  ({List<Object?> before, List<Object?> after}) get anchoredItems {
    final anchor = math.max(1, _model.initialPage);
    final first = _firstShown, last = _lastShown;
    if (first == null || last == null) return (before: const [], after: const []);
    final all = items;
    var beforeCount = 0;
    for (var p = first; p < anchor && p <= last; p++) {
      beforeCount += _pages[p]?.length ?? 0;
    }
    beforeCount = math.min(beforeCount, all.length);
    return (before: all.sublist(0, beforeCount), after: all.sublist(beforeCount));
  }

  /// The 1-based index of the first item shown.
  int get from {
    if (items.isEmpty) return 0;
    if (_autoPaginates) return ((_firstShown ?? 1) - 1) * _pageSize + 1;
    return (_page - 1) * _pageSize + 1;
  }

  /// The 1-based index of the last item shown.
  int get to {
    final count = items.length;
    if (count == 0) return 0;
    return from + count - 1;
  }

  /// Loading, empty, error or loaded.
  String get status {
    if (_error != null && _pages.isEmpty) return queryStatusError;
    if (isLoading) return queryStatusLoading;
    if (_pages.isEmpty) return queryStatusLoading;
    if (items.isEmpty) return queryStatusEmpty;
    return queryStatusLoaded;
  }

  /// The state as the map variable named by [Pagination.name] holds it: a
  /// scrolling list publishes `itemCount` but not its `items` (thousands of
  /// them would be copied with every page); they're read from the list.
  Map<String, Object?> get publishedState => {
        ...state,
        if (_autoPaginates) 'items': null,
      }..removeWhere((key, value) => key == 'items' && value == null);

  /// The full state, items included.
  Map<String, Object?> get state => {
        'items': items,
        'itemCount': items.length,
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
    final path = _model.keyPath.trim();
    if (path.isEmpty) return items;
    final seen = <Object?>{};
    final result = <Object?>[];
    for (final item in items) {
      final key = keyOf(item, path);
      if (key == null || seen.add(key)) result.add(item);
    }
    return result.length == items.length ? items : result;
  }

  /// The value at [path] (dot separated, list indexes allowed) in [item].
  static Object? keyOf(Object? item, String path) {
    Object? value = item;
    for (final part in path.split('.')) {
      if (value is Map) {
        value = value[part];
      } else if (value is List) {
        final index = int.tryParse(part);
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
      return _loads.values.firstOrNull ?? _inFlight.values.firstOrNull ?? Future.value();
    }
    return _show(_page);
  }

  /// Shows [page] after loading it, if needed. In a scrolling list it
  /// jumps: the shown pages become just [page].
  Future<void> goTo(int page) async {
    final target = math.max(1, page);
    final count = pageCount;
    await _show(count == null ? target : math.min(target, count));
  }

  /// Shows (or, in a scrolling list, appends) the next page.
  Future<void> next() {
    if (_autoPaginates) return loadMore();
    if (!hasMore) return Future.value();
    return _show(_page + 1);
  }

  /// Shows the page before the current one; in a list that loads both
  /// ways, puts the page before the first shown in front.
  Future<void> previous() {
    if (_autoPaginates) return loadPrevious();
    if (_page <= 1) return Future.value();
    return _show(_page - 1);
  }

  Future<void> first() => _show(1);

  /// Shows the last page, once the number of pages is known.
  Future<void> last() async {
    final count = pageCount;
    if (count != null) await _show(count);
  }

  /// Appends the page after the last one shown, unless the end is reached,
  /// it is already loading, or the last load failed (retry first).
  Future<void> loadMore() {
    final next = (_lastShown ?? 0) + 1;
    if (_lastShown == null) return start();
    if (!hasMore || _error != null) return Future.value();
    final loading = _loads[next];
    if (loading != null) return loading;
    return _load(next, onLoaded: () => _lastShown = next);
  }

  /// Puts the page before the first one shown in front.
  Future<void> loadPrevious() {
    final first = _firstShown;
    if (first == null) return start();
    if (first <= 1 || _error != null) return Future.value();
    final previous = first - 1;
    final loading = _loads[previous];
    if (loading != null) return loading;
    return _load(previous, onLoaded: () => _firstShown = previous);
  }

  /// Loads again the page that failed.
  Future<void> retry() {
    final failed = _failedPage;
    _error = null;
    _failedPage = null;
    _notify();
    if (failed == null) return start();
    if (!_autoPaginates || _lastShown == null) return _show(failed);
    if (failed > (_lastShown ?? 0)) return loadMore();
    return loadPrevious();
  }

  /// Forgets every loaded page and loads the first one again. The items
  /// shown stay until it loads.
  Future<void> refresh() async {
    _refreshing = true;
    _notify();
    final target = _autoPaginates ? math.max(1, _model.initialPage) : _page;
    final previous = Map.of(_pages);
    final shown = (_firstShown, _lastShown);
    _clear(keepShown: true);
    _pages.addAll(previous);
    final generation = _generation;
    try {
      await _fetchInto(target, generation, replace: true);
      if (generation == _generation) {
        _pages.removeWhere((page, _) => page != target);
        _page = target;
        if (_autoPaginates) {
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
    final newSize = math.max(1, size);
    if (newSize == _pageSize) return Future.value();
    final firstIndex = math.max(0, from - 1);
    _pageSize = newSize;
    _clear();
    _page = firstIndex ~/ newSize + 1;
    _notify();
    return _show(_page);
  }

  /// Gives a [PaginationSource.data] source its items (the list's bound
  /// data); pages are cut from them, and a change re-cuts the pages shown.
  void setLocalItems(List<Object?> items, {bool notify = true}) {
    if (identical(items, _localItems) || (_localItems != null && listEquals(items, _localItems))) return;
    final hadItems = _localItems != null;
    _localItems = items;
    _fetcher = _localFetcher;
    if (!hadItems) return;
    final shown = _pages.keys.toList();
    _pages.clear();
    _lastPage = null;
    _totalCount = items.length;
    for (final page in shown) {
      _pages[page] = _slice(items, PageRequest(page: page, pageSize: _pageSize));
    }
    if (notify) _notify();
  }

  List<Object?>? _localItems;

  Future<PageResult> _localFetcher(PageRequest request) => SynchronousFuture(_localPage(request));

  PageResult _localPage(PageRequest request) {
    final items = _localItems ?? const [];
    return PageResult(_slice(items, request), totalCount: items.length);
  }

  static List<Object?> _slice(List<Object?> items, PageRequest request) {
    final start = math.min(request.offset, items.length);
    final end = math.min(start + request.pageSize, items.length);
    return items.sublist(start, end);
  }

  Future<void> _show(int page) async {
    if (_autoPaginates) {
      if (_pages.containsKey(page)) {
        _firstShown = page;
        _lastShown = page;
        _page = page;
        _notify();
        return;
      }
      return _load(page, onLoaded: () {
        _firstShown = page;
        _lastShown = page;
      });
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
    final loading = _loads[page];
    if (loading != null) return loading;
    final generation = _generation;
    late final Future<void> future;
    future = () async {
      try {
        await _ensureCursor(page, generation);
        await _fetchInto(page, generation);
        if (generation != _generation) return;
        if (page > (_lastShown ?? 0) || !_autoPaginates) _page = page;
        onLoaded();
      } catch (_) {
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
    if (_model.strategy != PaginationStrategy.cursor) return;
    for (var before = 1; before < page; before++) {
      if (_cursors.containsKey(before + 1)) continue;
      if (_lastPage != null && before >= _lastPage!) return;
      await (_inFlight[before] ?? _fetchInto(before, generation));
      if (generation != _generation) return;
    }
  }

  Future<void> _fetchInto(int page, int generation, {bool replace = false}) {
    final loading = _inFlight[page];
    if (loading != null && !replace) return loading;
    final fetcher = _fetcher;
    if (fetcher == null) return Future.value();
    final request = PageRequest(page: page, pageSize: _pageSize, cursor: _cursors[page]);
    _fetchCount++;
    final done = Completer<void>();
    _inFlight[page] = done.future;
    // Listeners hear about the load once it is under way.
    scheduleMicrotask(_notify);
    () async {
      try {
        final result = await fetcher(request);
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
        if (!done.isCompleted) done.complete();
      }
    }();
    // Callers that don't await shouldn't see unhandled errors.
    done.future.ignore();
    return done.future;
  }

  void _store(int page, PageResult result) {
    _pages[page] = List<Object?>.unmodifiable(result.items);
    if (result.totalCount != null) _totalCount = result.totalCount;
    final cursor = _model.strategy == PaginationStrategy.cursor;
    if (cursor && result.nextCursor != null) _cursors[page + 1] = result.nextCursor;
    final last = result.hasMore == false ||
        (result.hasMore == null &&
            (result.items.length < _pageSize ||
                (cursor && result.nextCursor == null) ||
                (_totalCount != null && page * _pageSize >= _totalCount!)));
    if (last) {
      _lastPage = page;
      _totalCount ??= (page - 1) * _pageSize + result.items.length;
    }
    if (!_model.cachePages && !_autoPaginates) _pages.removeWhere((key, _) => key != page);
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

/// The pagination controllers of one screen (a [NodeTree]), by name. Each
/// writes its [PaginationController.publishedState] into the screen's map
/// variable of its name.
class PaginationRegistry extends ChangeNotifier {
  PaginationRegistry._();

  static final Expando<PaginationRegistry> _ofTree = Expando('PaginationRegistry');

  /// [tree]'s registry (made on first use).
  static PaginationRegistry of(NodeTree tree) => _ofTree[tree] ??= PaginationRegistry._();

  /// [tree]'s registry, if a list made one.
  static PaginationRegistry? maybeOf(NodeTree? tree) => tree == null ? null : _ofTree[tree];

  final Map<String, PaginationController> _controllers = {};
  final Map<String, VoidCallback> _publishers = {};

  /// Where the controllers' variables are written.
  ValueScope? _scope;

  PaginationController? operator [](String name) => _controllers[name];
  Iterable<String> get names => _controllers.keys;

  /// The controller for [model], made (and published into [scope]) the first
  /// time, and following [model] after.
  PaginationController ensure(Pagination model, {ValueScope? scope}) {
    if (scope != null) _scope = scope;
    final existing = _controllers[model.name];
    if (existing != null) {
      existing.updateModel(model);
      return existing;
    }
    final controller = PaginationController(model: model);
    _controllers[model.name] = controller;
    void publisher() => publish(model.name);
    _publishers[model.name] = publisher;
    controller.addListener(publisher);
    publish(model.name);
    // Nodes that find controllers by name (a pagination node shown before
    // its list) look again.
    _later(notifyListeners);
    return controller;
  }

  /// Writes [name]'s state into its variable, now or, during a frame's
  /// build or layout, after it.
  void publish(String name) => _later(() => _write(name));

  static bool get _inFrame {
    try {
      final phase = SchedulerBinding.instance.schedulerPhase;
      return phase == SchedulerPhase.persistentCallbacks || phase == SchedulerPhase.midFrameMicrotasks;
    } catch (_) {
      return false;
    }
  }

  void _later(VoidCallback f) {
    if (_inFrame) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!_disposed) f();
      });
    } else {
      f();
    }
  }

  void _write(String name) {
    final controller = _controllers[name];
    final scope = _scope;
    if (controller == null || scope == null) return;
    writePaginationState(scope, name, controller.publishedState);
  }

  bool _disposed = false;

  /// Forgets every controller.
  void clear() {
    for (final e in _controllers.entries) {
      final p = _publishers[e.key];
      if (p != null) e.value.removeListener(p);
      e.value.dispose();
    }
    _controllers.clear();
    _publishers.clear();
  }

  @override
  void dispose() {
    _disposed = true;
    clear();
    super.dispose();
  }
}

/// The variable scope of [scope]'s chain: the screen's variables.
VariableScope? variablesOf(ValueScope? scope) {
  for (var s = scope; s != null; s = s.parent) {
    if (s is VariableScope) return s;
  }
  return null;
}

/// Writes a pagination's [state] into the map variable [name] (declared
/// when missing).
void writePaginationState(ValueScope scope, String name, Json state) {
  final variables = variablesOf(scope);
  if (variables == null || name.isEmpty) return;
  if (variables.variable(name) case final Variable v when v.type == VariableType.map && !v.isComputed) {
    variables.set(name, state);
  } else if (!variables.declares(name)) {
    variables.define(Variable(name: name, type: VariableType.map, value: state));
  }
}

/// Declares the map variables of the paginations of [nodes] (a screen's)
/// in [scope], before anything reads them: a text bound to
/// `${contacts.page}` built before its list then follows it.
void declarePaginationVariables(VariableScope scope, Iterable<Node> nodes) {
  for (final n in nodes) {
    if (n.type != 'listView' && n.type != 'gridView') continue;
    final model = n.props.get(ListViewProps.pagination);
    final name = model?.name.trim() ?? '';
    if (model == null || name.isEmpty || scope.declares(name)) continue;
    scope.define(Variable(
      name: name,
      type: VariableType.map,
      value: PaginationController(model: model).publishedState,
    ));
  }
}
