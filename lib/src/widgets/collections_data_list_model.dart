// What a list that pages, groups into sections or swipes knows and decides,
// apart from how it is drawn: its pagination controller and page source,
// the items to show, the ones swiped away and waiting on Undo, its sections
// and index keys, and which footer it shows. No widgets: the widget list
// and the render-object list read the same model.
import 'dart:async';
import 'dart:math' as math;

import 'package:codelessly_api/core.dart' as api;
import 'package:codelessly_api/core.dart'
    show CollectionSlots, ListApply, ListSections, ListViewProps, Node, Pagination, PaginationMode, PaginationSource,
        SwipeAction, SwipeActions, TriggerType;
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../runtime/expressions/bindings.dart';
import '../runtime/lists/page_fetchers.dart';
import '../runtime/lists/pagination.dart';
import 'collections_list_runtime.dart';

/// A section of a data list: consecutive items with the same key.
@immutable
class ListSection {
  const ListSection(this.key, this.start, this.count);

  final Object? key;

  /// The index of the section's first item.
  final int start;
  final int count;

  /// What its header reads as `${item}`.
  Map<String, Object?> toItem(int index) => {'key': key, 'count': count, 'index': index, 'start': start};

  @override
  bool operator ==(Object other) => other is ListSection && other.key == key && other.start == start && other.count == count;

  @override
  int get hashCode => Object.hash(key, start, count);

  @override
  String toString() => 'ListSection($key, $start, $count)';
}

/// [items] grouped into sections of consecutive items with the same
/// [keyOf].
List<ListSection> groupIntoSections(List<Object?> items, Object? Function(int index, Object? item) keyOf) {
  final sections = <ListSection>[];
  Object? current;
  var start = 0;
  for (var i = 0; i < items.length; i++) {
    final key = keyOf(i, items[i]);
    if (i == 0) {
      current = key;
      continue;
    }
    if (key != current) {
      sections.add(ListSection(current, start, i - start));
      current = key;
      start = i;
    }
  }
  if (items.isNotEmpty) sections.add(ListSection(current, start, items.length - start));
  return sections;
}

/// The scroll offset of the start of section [index] in a list whose items
/// are [itemExtent] long, with [separator] between items of a section and
/// between sections, and headers [headerExtent] long; null when items
/// aren't of one extent.
double? sectionOffset(List<ListSection> sections, int index,
    {required double? itemExtent, required double headerExtent, double separator = 0}) {
  if (itemExtent == null) return null;
  var offset = 0.0;
  for (var i = 0; i < index && i < sections.length; i++) {
    final count = sections[i].count;
    offset += headerExtent + count * itemExtent + math.max(0, count - 1) * separator + separator;
  }
  return offset;
}

extension ListFeatures on Node {
  Pagination? get pagination => type == 'listView' || type == 'gridView' ? prop(ListViewProps.pagination) : null;
  ListSections? get sections => type == 'listView' ? prop(ListViewProps.sections) : null;
  SwipeActions? get swipeActions => type == 'listView' ? prop(ListViewProps.swipeActions) : null;

  /// A sections setting that groups (a key and a header).
  bool get sectioned => (sections?.groupBy.trim().isNotEmpty ?? false) && slots[CollectionSlots.sectionHeader] != null;
  bool get swipes => swipeActions != null && (swipeActions!.startActions.isNotEmpty || swipeActions!.endActions.isNotEmpty);

  /// A list pulled to refresh without pagination: its `pullToRefresh`, or
  /// a `refresh` reaction.
  bool get pullsToRefresh =>
      type == 'listView' &&
      (prop(ListViewProps.pullToRefresh) || actions.any((r) => r.trigger.type == TriggerType.refresh));

  /// A list that opens at its end and keeps its place ([ListViewProps.stickToEnd]).
  bool get sticksToEnd => type == 'listView' && prop(ListViewProps.stickToEnd);
}

/// Whether a running list [n] is a [DataListView]: it pages, groups into
/// sections, has swipe actions or pulls to refresh, and lays its items in a
/// line.
bool usesDataList(Node n) =>
    (n.pagination != null || n.sectioned || n.swipes || n.pullsToRefresh || n.sticksToEnd) &&
    !n.prop(ListViewProps.wrap) &&
    n.prop(ListViewProps.layout) == api.ListLayout.list;

/// An item swiped away with Undo offered: [commit] runs its removal and
/// reaction when the Undo bar goes.
class PendingSwipe {
  PendingSwipe({required this.result, required this.commit});
  final Map<String, Object?> result;
  final VoidCallback commit;
}

/// Which footer a paged list shows after its items.
enum DataListFooter { error, loading, end }

/// The state of a list that pages, groups or swipes. [update] gives it the
/// list's runtime and bound data each time the list is built; it notifies
/// when what the list shows changes.
class DataListModel extends ChangeNotifier {
  DataListModel(this._r, this._data) {
    _attach();
  }

  ListRuntime _r;
  List<Object?>? _data;
  bool _disposed = false;

  ListRuntime get runtime => _r;
  Node get node => _r.node;
  Pagination? get pagination => node.pagination;

  /// The list's bound data, for a list without pagination or with a data
  /// source.
  List<Object?>? get data => _data;

  /// The list was built again: its runtime and data as of now.
  void update(ListRuntime runtime, List<Object?>? data) {
    _r = runtime;
    _data = data;
    _attach();
  }

  PaginationController? _controller;
  PaginationController? get controller => _controller;
  bool _loadScheduled = false, _previousScheduled = false, _started = false;

  /// The cloud or API page source, and what it was made for.
  (Object?, PageFetcher)? _fetcher;

  void _attach() {
    final model = pagination;
    if (model == null) {
      _controller?.removeListener(_changed);
      _controller = null;
      return;
    }
    final registry = PaginationRegistry.of(_r.tree);
    final controller = registry.ensure(model, scope: _r.scope);
    if (!identical(controller, _controller)) {
      _controller?.removeListener(_changed);
      controller.addListener(_changed);
      _controller = controller;
      _started = false;
    }
    switch (model.source) {
      case PaginationSource.data:
        final changed = controller.setLocalItems(_data ?? const [], notify: false);
        if (changed) registry.localItemsChanged(model.name);
        registry.publish(model.name);
      case PaginationSource.cloud || PaginationSource.api:
        final f = _sourceFetcher(model);
        if (f != null) controller.fetcher = f;
    }
    if (!_started) {
      _started = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!_disposed) controller.start();
      });
    }
  }

  /// The page source of a cloud or API pagination, made again when what it
  /// reads changes.
  PageFetcher? _sourceFetcher(Pagination model) {
    final scope = _r.scope;
    if (model.source == PaginationSource.api) {
      final services = _r.services;
      if (services == null || scope == null) return null;
      final key = ('api', model);
      if (_fetcher?.$1 == key) return _fetcher!.$2;
      final f = apiPageFetcher(model, (id, params) => services.callApi(id, params: params),
          resolve: resolverIn(_r.engine, scope));
      _fetcher = (key, f);
      return f;
    }
    final database = _r.database, def = _r.cloudQuery;
    if (database == null || def == null || scope == null) return null;
    final path = _r.collectionPath;
    final pages = database.pages(path, def, _r.engine, scope);
    final key = pages.key;
    if (_fetcher?.$1 == key) return _fetcher!.$2;
    final f = pages.fetcher();
    _fetcher = (key, f);
    return f;
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  // --- items ---

  /// The keys of items swiped away, waiting for their Undo bar to go.
  final Set<Object?> _removed = {};

  /// The swipes whose Undo is still offered, oldest first.
  final List<PendingSwipe> pending = [];

  /// Whether the item with [key] was swiped away.
  bool isRemoved(Object? key) => _removed.contains(key);

  /// The items to show, without the ones swiped away.
  List<Object?> get items {
    final items = _controller?.items ?? _data ?? const <Object?>[];
    if (_removed.isEmpty) return items;
    return [
      for (final item in items)
        if (!_removed.contains(keyOf(item))) item,
    ];
  }

  Object? keyOf(Object? item) {
    final path = pagination?.keyPath ?? 'id';
    return (path.isEmpty ? null : PaginationController.keyOf(item, path)) ?? item;
  }

  /// Loads the next page after this frame, once.
  void requestMore() {
    final c = _controller;
    if (c == null || _loadScheduled) return;
    if (c.model.mode == PaginationMode.pages) return;
    if (!c.hasMore || c.error != null || c.isLoadingMore) return;
    _loadScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _loadScheduled = false;
      if (!_disposed) c.loadMore();
    });
  }

  /// Loads the page before the first one shown after this frame, once.
  void requestPrevious() {
    final c = _controller;
    if (c == null || _previousScheduled) return;
    if (c.model.mode != PaginationMode.bidirectional) return;
    if (!c.hasPrevious || c.error != null || c.isLoadingMore) return;
    _previousScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _previousScheduled = false;
      if (!_disposed) c.loadPrevious();
    });
  }

  /// The list scrolled: [extentBefore] and [extentAfter] are what is out
  /// of view at each end. Within the pagination's pixel threshold, the
  /// page at that end loads.
  void onScrollExtents(double extentBefore, double extentAfter) {
    final pixels = pagination?.thresholdPixels ?? 0;
    if (pixels <= 0) return;
    if (extentAfter <= pixels) requestMore();
    if (extentBefore <= pixels) requestPrevious();
  }

  /// Item [index] of [count] was built: near the end, the next page loads.
  void onItemBuilt(int index, int count) {
    final threshold = math.max(0, pagination?.thresholdItems ?? 0);
    if (index >= count - 1 - threshold) requestMore();
  }

  /// Pulled to refresh: the controller's first page again, and the list's
  /// `refresh` reactions.
  Future<void> refresh() async {
    await Future.wait([
      if (_controller != null) _controller!.refresh(),
      _r.fire(TriggerType.refresh.name),
    ]);
  }

  /// Whether the list can be pulled to refresh.
  bool get refreshable =>
      pagination?.pullToRefresh == true || node.pullsToRefresh || node.actions.any((r) => r.trigger.type == TriggerType.refresh);

  // --- item scopes ---

  /// The repeats given an item scope.
  final Set<ProvidedItem> _provided = {};

  /// The scope of repeat [key] ([tag]: a row, a section header) holding
  /// [item] at [index].
  ProvidedItem provide(String tag, Object? key, int index, Object? item) {
    final instance = ProvidedItem(tag, _r.b.instance, node.id, key);
    _provided.add(instance);
    _r.binder?.provideItem(_r.b.source, instance, index: index, item: item);
    return instance;
  }

  /// Repeats no longer in the list let go of their scopes (after the
  /// frame: their boxes are still there until then).
  void forgetGone() {
    final keep = {
      for (final item in items) ('row', keyOf(item)),
      for (final s in _sections ?? const <ListSection>[]) ('section', s.key),
    };
    final gone = [
      for (final p in _provided)
        if (!keep.contains((p.tag, p.key))) p,
    ];
    if (gone.isEmpty) return;
    _provided.removeAll(gone);
    final binder = _r.binder;
    if (binder == null) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      for (final p in gone) {
        if (!_provided.contains(p)) binder.forgetItem(p);
      }
    });
  }

  // --- swipe actions ---

  /// [action] was chosen on [item]: its removal (kept back while Undo is
  /// offered) and the list's `swipeAction` reactions.
  void onSwipe(SwipeAction action, int index, Object? item) {
    final swipe = node.swipeActions!;
    final result = <String, Object?>{'action': action.id, 'label': action.label, 'item': item, 'index': index};
    Future<void> run() async {
      if (_disposed) return;
      if (action.removes) await _applyRemoval(swipe.apply, item);
      if (_disposed) return;
      await _r.fire(TriggerType.swipeAction.name, event: result);
    }

    if (!action.removes || !swipe.undo) {
      if (action.removes) {
        _removed.add(keyOf(item));
        notifyListeners();
      }
      run();
      return;
    }
    late final PendingSwipe entry;
    entry = PendingSwipe(
      result: result,
      commit: () {
        pending.remove(entry);
        run();
      },
    );
    _removed.add(keyOf(item));
    pending.add(entry);
    notifyListeners();
    Future<void>.delayed(Duration(milliseconds: swipe.undoMs), () {
      if (pending.contains(entry)) {
        entry.commit();
        if (!_disposed) notifyListeners();
      }
    });
  }

  /// Undo was pressed: the item is back.
  void undo(PendingSwipe entry) {
    pending.remove(entry);
    _removed.remove(keyOf(entry.result['item']));
    notifyListeners();
  }

  /// What the Undo bar of [entry] says.
  String undoMessage(PendingSwipe entry) {
    final template = node.swipeActions?.undoMessage ?? '';
    return template.replaceAllMapped(
      RegExp(r'\$\{\s*result\.(\w+)\s*\}'),
      (m) => '${entry.result[m.group(1)] ?? ''}',
    );
  }

  /// Removes [item] from the list's data on its own, as [apply] says.
  Future<void> _applyRemoval(ListApply apply, Object? item) async {
    switch (apply) {
      case ListApply.none:
        return;
      case ListApply.variable:
        final name = _r.boundVariable;
        if (name == null) return;
        final list = _r.listVariable(name);
        final key = keyOf(item);
        list.removeWhere((candidate) => keyOf(candidate) == key);
        _r.setVariable(name, list);
      case ListApply.cloud:
        final id = item is Map ? item['id'] : null;
        if (id is! String) return;
        await _r.database?.removeDocument(_r.collectionPath, id);
    }
  }

  // --- sections ---

  List<ListSection>? _sections;
  List<Object?>? _sectionedItems;
  String? _sectionedBy;

  /// The sections as of the last [sectionsFor].
  List<ListSection>? get sections => _sections;

  /// [items] grouped by the list's `sections.groupBy`; null for a list
  /// that does not group.
  List<ListSection>? sectionsFor(List<Object?> items) {
    final model = node.sections;
    if (model == null || !node.sectioned) return null;
    if (identical(items, _sectionedItems) && _sectionedBy == model.groupBy) return _sections;
    final groupBy = model.groupBy.trim();
    final binding = groupBy.contains(r'${');
    _sections = groupIntoSections(items, (index, item) {
      if (!binding) return PaginationController.keyOf(item, groupBy);
      return _r.text(groupBy, index: index, item: item);
    });
    _sectionedItems = items;
    _sectionedBy = model.groupBy;
    return _sections;
  }

  List<Object?>? _keyedData;
  String? _keyedBy;
  Map<String, int> _firstIndexOfKey = const {};

  /// The section key of every item of the list's data, by its first index:
  /// with a data-paged list all of its data counts, not only the loaded
  /// pages, so the index bar offers sections still to load.
  Map<String, int> dataKeys() {
    final model = node.sections;
    final data = _data;
    if (model == null || data == null || pagination?.source != PaginationSource.data) return const {};
    if (identical(data, _keyedData) && _keyedBy == model.groupBy) return _firstIndexOfKey;
    final groupBy = model.groupBy.trim();
    final binding = groupBy.contains(r'${');
    final out = <String, int>{};
    for (var i = 0; i < data.length; i++) {
      final key = binding ? _r.text(groupBy, index: i, item: data[i]) : PaginationController.keyOf(data[i], groupBy);
      out.putIfAbsent('$key', () => i);
    }
    _keyedData = data;
    _keyedBy = model.groupBy;
    return _firstIndexOfKey = out;
  }

  /// The keys the index bar shows: its own, else the sections'.
  List<Object?> indexKeys(List<ListSection> sections) {
    final own = node.sections?.indexKeys ?? const [];
    if (own.isNotEmpty) return own;
    final keys = <Object?>[for (final s in sections) s.key];
    for (final k in dataKeys().keys) {
      if (!keys.any((x) => '$x' == k)) keys.add(k);
    }
    return keys;
  }

  /// Keys some item has (the rest show muted and do nothing).
  Set<String> presentKeys(List<ListSection> sections) => {for (final s in sections) '${s.key}', ...dataKeys().keys};

  /// The index of the section with [key] among the sections now, or -1.
  int sectionIndexOf(Object? key) => (_sections ?? const <ListSection>[]).indexWhere((s) => '${s.key}' == '$key');

  /// Loads pages until the section with [key] is among the items (a
  /// data-paged list whose pages don't reach it yet). True when it loaded
  /// any.
  Future<bool> loadUntilKey(Object? key) async {
    final c = _controller;
    final target = dataKeys()['$key'];
    if (c == null || target == null) return false;
    var loaded = false;
    while (!_disposed && c.items.length <= target && c.hasMore) {
      await c.loadMore();
      loaded = true;
    }
    return loaded;
  }

  // --- the footer ---

  /// The footer to show after the items, and the list's own slot node for
  /// it when it has one (else the default one is drawn).
  (DataListFooter, String?)? get footer {
    final c = _controller, model = pagination;
    if (c == null || model == null) return null;
    final slots = node.slots;
    String? slot(String name) {
      final id = slots[name];
      return id == null || _r.b.nodeOf(id) == null ? null : id;
    }

    if (c.error != null) return (DataListFooter.error, slot(CollectionSlots.error));
    if (c.isLoading || c.isLoadingMore) {
      if (model.mode == PaginationMode.pages && !c.isLoading) return null;
      return (DataListFooter.loading, slot(CollectionSlots.loading));
    }
    final end = slot(CollectionSlots.end);
    if (model.mode != PaginationMode.pages && !c.hasMore && end != null && c.items.isNotEmpty) return (DataListFooter.end, end);
    return null;
  }

  @override
  void dispose() {
    _disposed = true;
    _controller?.removeListener(_changed);
    for (final entry in [...pending]) {
      entry.commit();
    }
    final binder = _r.binder;
    for (final p in _provided) {
      binder?.forgetItem(p);
    }
    super.dispose();
  }
}
