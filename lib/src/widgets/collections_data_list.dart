// A running list (or grid) that pages, groups its items into sections or
// has swipe actions, as an island: a
// CustomScrollView of slivers whose items are the template's node boxes
// (NodeChild), each in the scope of its item (NodeBinder.provideItem).
//
// On a design canvas (not animating) the list keeps its render objects at
// rest (collections.dart): this is the running app's.
import 'dart:math' as math;

import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_api/codelessly_api.dart'
    show CollectionScrollProps, CollectionSlots, ListApply, ListSections, ListViewProps, Node, Pagination,
        PaginationMode, PaginationSource, SwipeAction, SwipeActions, TriggerType;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/scheduler.dart';

import '../render/convert.dart';
import '../render/recipe.dart';
import '../runtime/expressions/bindings.dart';
import '../runtime/lists/page_fetchers.dart';
import '../runtime/lists/pagination.dart';
import '../services/cloud/resolve.dart';
import 'collections_list_runtime.dart';
import 'collections_swipe.dart';

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
/// headers [headerExtent] long; null when items aren't of one extent.
double? sectionOffset(List<ListSection> sections, int index,
    {required double? itemExtent, required double headerExtent, double separator = 0}) {
  if (itemExtent == null) return null;
  var offset = 0.0;
  for (var i = 0; i < index && i < sections.length; i++) {
    final count = sections[i].count;
    offset += headerExtent + count * itemExtent + math.max(0, count - 1) * separator;
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
}

/// Whether a running list [n] is a [DataListView]: it pages, groups into
/// sections, has swipe actions or pulls to refresh, and lays its items in a
/// line.
bool usesDataList(Node n) =>
    (n.pagination != null || n.sectioned || n.swipes || n.pullsToRefresh) &&
    !n.prop(ListViewProps.wrap) &&
    n.prop(ListViewProps.layout) == api.ListLayout.list;

/// A running list [n] built as a [DataListView] island in [chain] (after
/// its viewport box). [itemMain] sizes its items along it; [separator]
/// builds what goes between two items; [gridDelegate] lays a grid.
void dataListRecipe(
  NodeBuilder b,
  Node n,
  List<RenderBox> chain, {
  required String itemId,
  double? itemExtent,
  double? itemMain,
  bool stretch = false,
  double separatorExtent = 0,
  Widget Function()? separator,
  SliverGridDelegate? gridDelegate,
  bool scrollable = true,
  bool hugMain = false,
}) {
  final runtime = ListRuntime(b, n);
  final vertical = n.prop(CollectionScrollProps.scrollDirection) == api.Axis.vertical;
  final header = b.nodeOf(n.slots[CollectionSlots.sectionHeader] ?? '');
  final headerExtent = header == null
      ? 32.0
      : vertical
          ? header.layout.height.value + header.layout.margin.vertical
          : header.layout.width.value + header.layout.margin.horizontal;
  final data = runtime.data;
  chain.add(b.island(
    'dataList',
    (context) => DataListView(
      runtime: runtime,
      itemId: itemId,
      data: data,
      itemExtent: itemExtent,
      itemMain: itemMain,
      stretch: stretch,
      headerExtent: headerExtent,
      separatorExtent: separatorExtent,
      separator: separator,
      gridDelegate: gridDelegate,
      physics: scrollPhysicsOf(n, scrollable: scrollable),
      hugMain: hugMain,
    ),
  ));
}

/// A list of data items built lazily in slivers, for what a plain list
/// doesn't do:
///
/// * pages from its [PaginationController]: a page at a time, or the next
///   page loading as the list nears its end (and, both ways, the page
///   before near its start, put in front without moving what is on screen);
/// * loading, error-with-retry and end-of-list footers (the list's
///   `loading`, `error` and `end` slots);
/// * pull to refresh (the list's `refresh` reactions);
/// * section headers (the `sectionHeader` slot) that stay pinned, with an
///   index bar to jump;
/// * swipe actions on the items (the `swipeAction` reactions), with undo.
class DataListView extends StatefulWidget {
  const DataListView({
    super.key,
    required this.runtime,
    required this.itemId,
    this.data,
    this.itemExtent,
    this.itemMain,
    this.stretch = false,
    this.headerExtent = 32,
    this.separatorExtent = 0,
    this.separator,
    this.gridDelegate,
    this.physics,
    this.hugMain = false,
  });

  final ListRuntime runtime;

  /// The item template.
  final String itemId;

  /// The list's bound data, for a list without pagination or with a data
  /// source.
  final List<Object?>? data;

  /// The extent every item takes along the list, when known.
  final double? itemExtent;

  /// The extent an item is placed at along the list ([ListItemBox]).
  final double? itemMain;
  final bool stretch;
  final double headerExtent;
  final double separatorExtent;
  final Widget Function()? separator;
  final SliverGridDelegate? gridDelegate;
  final ScrollPhysics? physics;

  /// Hugs its items along its scroll axis within the room it's given (a
  /// flexible list): as long as they are, scrolling once they outgrow it.
  final bool hugMain;

  @override
  State<DataListView> createState() => DataListViewState();
}

class DataListViewState extends State<DataListView> {
  final ScrollController scrollController = ScrollController();

  /// The key of the sliver that anchors a list loading both ways.
  final Key _centerKey = UniqueKey();

  PaginationController? _controller;
  bool _loadScheduled = false;
  bool _previousScheduled = false;
  bool _started = false;

  /// The keys of items swiped away, waiting for their Undo bar to go.
  final Set<Object?> _removed = {};
  final List<_PendingSwipe> _pending = [];

  List<ListSection>? _sections;
  List<Object?>? _sectionedItems;
  String? _sectionedBy;

  /// The repeats given an item scope.
  final Set<ProvidedItem> _provided = {};

  /// The cloud or API page source, and what it was made for.
  (Object?, PageFetcher)? _fetcher;

  PaginationController? get controller => _controller;

  ListRuntime get _r => widget.runtime;
  Node get _node => _r.node;
  Pagination? get _model => _node.pagination;
  Axis get _axis => _node.prop(CollectionScrollProps.scrollDirection) == api.Axis.vertical ? Axis.vertical : Axis.horizontal;

  @override
  void initState() {
    super.initState();
    _attach();
  }

  @override
  void didUpdateWidget(covariant DataListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _attach();
  }

  void _attach() {
    final model = _model;
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
        final changed = controller.setLocalItems(widget.data ?? const [], notify: false);
        if (changed) registry.localItemsChanged(model.name);
        registry.publish(model.name);
      case PaginationSource.cloud || PaginationSource.api:
        final f = _sourceFetcher(model);
        if (f != null) controller.fetcher = f;
    }
    if (!_started) {
      _started = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) controller.start();
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
    final query = resolveCloudQuery(def, _r.engine, scope);
    final key = ('cloud', path, query.filters.toString(), query.orderBy.toString());
    if (_fetcher?.$1 == key) return _fetcher!.$2;
    final f = cloudPageFetcher(database, path, query);
    _fetcher = (key, f);
    return f;
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.removeListener(_changed);
    for (final pending in [..._pending]) {
      pending.commit();
    }
    final binder = _r.binder;
    for (final p in _provided) {
      binder?.forgetItem(p);
    }
    scrollController.dispose();
    super.dispose();
  }

  /// The items to show, without the ones swiped away.
  List<Object?> get _items {
    final items = _controller?.items ?? widget.data ?? const <Object?>[];
    if (_removed.isEmpty) return items;
    return [
      for (final item in items)
        if (!_removed.contains(_keyOf(item))) item,
    ];
  }

  Object? _keyOf(Object? item) {
    final path = _model?.keyPath ?? 'id';
    return (path.isEmpty ? null : PaginationController.keyOf(item, path)) ?? item;
  }

  /// Loads the next page after this frame, once.
  void _requestMore() {
    final c = _controller;
    if (c == null || _loadScheduled) return;
    if (c.model.mode == PaginationMode.pages) return;
    if (!c.hasMore || c.error != null || c.isLoadingMore) return;
    _loadScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _loadScheduled = false;
      if (mounted) c.loadMore();
    });
  }

  /// Loads the page before the first one shown after this frame, once.
  void _requestPrevious() {
    final c = _controller;
    if (c == null || _previousScheduled) return;
    if (c.model.mode != PaginationMode.bidirectional) return;
    if (!c.hasPrevious || c.error != null || c.isLoadingMore) return;
    _previousScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _previousScheduled = false;
      if (mounted) c.loadPrevious();
    });
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    final pixels = _model?.thresholdPixels ?? 0;
    if (pixels <= 0) return false;
    final metrics = notification.metrics;
    if (metrics.extentAfter <= pixels) _requestMore();
    if (metrics.extentBefore <= pixels) _requestPrevious();
    return false;
  }

  /// Item [index] of [count] was built: near the end, the next page loads.
  void _onItemBuilt(int index, int count) {
    final threshold = math.max(0, _model?.thresholdItems ?? 0);
    if (index >= count - 1 - threshold) _requestMore();
  }

  Future<void> _refresh() async {
    await Future.wait([
      if (_controller != null) _controller!.refresh(),
      _r.fire(TriggerType.refresh.name),
    ]);
  }

  /// The node box of repeat [key] of node [id], in the scope of [item] at
  /// [index].
  Widget _node$(String tag, String id, Object? key, int index, Object? item) {
    final instance = ProvidedItem(tag, _r.b.instance, _node.id, key);
    _provided.add(instance);
    _r.binder?.provideItem(_r.tree.source, instance, index: index, item: item);
    return NodeChild(tree: _r.tree, id: id, instance: instance);
  }

  /// A slot node of the list (a footer), in the list's scope.
  Widget _slot(String id) => NodeChild(tree: _r.tree, id: id, instance: _r.b.instance);

  Widget _item(BuildContext context, int index, Object? item) {
    final key = _keyOf(item);
    Widget child = _node$('row', widget.itemId, key, index, item);
    if (widget.gridDelegate == null) {
      child = ListItemBox(axis: _axis, main: widget.itemMain, stretch: widget.stretch, child: child);
    }
    // Node boxes aren't hit themselves: the row is, so the gestures around
    // it (a swipe) see pointers on its blank parts too.
    child = MetaData(key: ValueKey(('item', key)), behavior: HitTestBehavior.opaque, child: child);
    final swipe = _node.swipeActions;
    if (swipe != null && swipe.enabled && _node.swipes) {
      child = SwipeActionsBox(
        key: ValueKey(('swipe', key)),
        model: swipe,
        onAction: (action) => _onSwipe(action, index, item),
        child: child,
      );
    }
    return child;
  }

  void _onSwipe(SwipeAction action, int index, Object? item) {
    final swipe = _node.swipeActions!;
    final result = <String, Object?>{'action': action.id, 'label': action.label, 'item': item, 'index': index};
    Future<void> run() async {
      if (!mounted) return;
      if (action.removes) await _applyRemoval(swipe.apply, item);
      if (!mounted) return;
      await _r.fire(TriggerType.swipeAction.name, event: result);
    }

    if (!action.removes || !swipe.undo) {
      if (action.removes) setState(() => _removed.add(_keyOf(item)));
      run();
      return;
    }
    late final _PendingSwipe pending;
    pending = _PendingSwipe(
      result: result,
      commit: () {
        _pending.remove(pending);
        run();
      },
    );
    setState(() {
      _removed.add(_keyOf(item));
      _pending.add(pending);
    });
    Future<void>.delayed(Duration(milliseconds: swipe.undoMs), () {
      if (_pending.contains(pending)) {
        if (mounted) setState(() {});
        pending.commit();
      }
    });
  }

  void _undo(_PendingSwipe pending) {
    setState(() {
      _pending.remove(pending);
      _removed.remove(_keyOf(pending.result['item']));
    });
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
        final key = _keyOf(item);
        list.removeWhere((candidate) => _keyOf(candidate) == key);
        _r.setVariable(name, list);
      case ListApply.cloud:
        final id = item is Map ? item['id'] : null;
        if (id is! String) return;
        await _r.database?.removeDocument(_r.collectionPath, id);
    }
  }

  List<ListSection>? _sectionsFor(List<Object?> items) {
    final model = _node.sections;
    if (model == null || !_node.sectioned) return null;
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

  /// Jumps to the start of section [index].
  void jumpToSection(int index) {
    final sections = _sections;
    if (sections == null || index < 0 || index >= sections.length) return;
    if (!scrollController.hasClients) return;
    final position = scrollController.position;
    final exact = sectionOffset(
      sections,
      index,
      itemExtent: widget.itemExtent,
      headerExtent: widget.headerExtent,
      separator: widget.separator == null ? 0 : widget.separatorExtent,
    );
    final total = _items.length;
    final offset = exact ?? (total == 0 ? 0 : position.maxScrollExtent * sections[index].start / total);
    position.jumpTo(offset.clamp(0, position.maxScrollExtent));
  }

  SliverChildBuilderDelegate _delegate(List<Object?> items,
      {int start = 0, int? count, bool reversed = false, void Function(int index)? onBuilt}) {
    final length = count ?? items.length - start;
    final separated = widget.separator != null && widget.gridDelegate == null;
    return SliverChildBuilderDelegate(
      (context, i) {
        if (separated && i.isOdd) return widget.separator!();
        final local = separated ? i ~/ 2 : i;
        final position = reversed ? length - 1 - local : local;
        final index = start + position;
        onBuilt?.call(index);
        return _item(context, index, items[index]);
      },
      childCount: separated ? math.max(0, length * 2 - 1) : length,
    );
  }

  Widget _sliverList(SliverChildBuilderDelegate delegate, {Key? key}) {
    final grid = widget.gridDelegate;
    if (grid != null) return SliverGrid(key: key, delegate: delegate, gridDelegate: grid);
    final extent = widget.itemExtent;
    if (extent != null && widget.separator == null) {
      return SliverFixedExtentList(key: key, delegate: delegate, itemExtent: extent);
    }
    if (extent != null) {
      final gap = widget.separatorExtent;
      return SliverVariedExtentList(
        key: key,
        delegate: delegate,
        itemExtentBuilder: (index, _) => index.isEven ? extent : gap,
      );
    }
    return SliverList(key: key, delegate: delegate);
  }

  Widget? _footer(BuildContext context) {
    final c = _controller, model = _model;
    if (c == null || model == null) return null;
    final slots = _node.slots;
    String? slot(String name) => slots[name]?.let((id) => _r.b.nodeOf(id) == null ? null : id);
    if (c.error != null) {
      final error = slot(CollectionSlots.error);
      return GestureDetector(
        key: const ValueKey('pagination-error'),
        behavior: HitTestBehavior.opaque,
        onTap: c.retry,
        child: error != null ? _slot(error) : _DefaultErrorFooter(error: c.error),
      );
    }
    if (c.isLoading || c.isLoadingMore) {
      if (model.mode == PaginationMode.pages && !c.isLoading) return null;
      final loading = slot(CollectionSlots.loading);
      return KeyedSubtree(
        key: const ValueKey('pagination-loading'),
        child: loading != null ? _slot(loading) : const _DefaultLoadingFooter(),
      );
    }
    final end = slot(CollectionSlots.end);
    if (model.mode != PaginationMode.pages && !c.hasMore && end != null && c.items.isNotEmpty) {
      return KeyedSubtree(key: const ValueKey('pagination-end'), child: _slot(end));
    }
    return null;
  }

  List<Widget> _sectionSlivers(BuildContext context, List<Object?> items, List<ListSection> sections) {
    final model = _node.sections!;
    final vertical = _axis == Axis.vertical;
    return [
      for (var s = 0; s < sections.length; s++)
        SliverMainAxisGroup(
          key: ValueKey(('section', sections[s].key)),
          slivers: [
            if (vertical && model.sticky)
              SliverPersistentHeader(
                pinned: true,
                delegate: _HeaderDelegate(extent: widget.headerExtent, child: _header(sections[s], s)),
              )
            else
              SliverToBoxAdapter(child: _header(sections[s], s)),
            _sliverList(_delegate(items,
                start: sections[s].start,
                count: sections[s].count,
                onBuilt: (index) => _onItemBuilt(index, items.length))),
          ],
        ),
    ];
  }

  Widget _header(ListSection section, int index) => KeyedSubtree(
        key: ValueKey(('header', section.key)),
        child: _node$('section', _node.slots[CollectionSlots.sectionHeader]!, section.key, index, section.toItem(index)),
      );

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (c != null) _r.reportStatus(c.status);
    final out = _build(context);
    // Repeats no longer in the list let go of their scopes.
    final keep = {
      for (final item in _items) ('row', _keyOf(item)),
      for (final s in _sections ?? const <ListSection>[]) ('section', s.key),
    };
    final gone = [
      for (final p in _provided)
        if (!keep.contains((p.tag, p.key))) p,
    ];
    final binder = _r.binder;
    if (gone.isNotEmpty) {
      _provided.removeAll(gone);
      if (binder != null) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          for (final p in gone) {
            if (!_provided.contains(p)) binder.forgetItem(p);
          }
        });
      }
    }
    return out;
  }

  Widget _build(BuildContext context) {
    final items = _items;
    final model = _model;
    final axis = _axis;
    final sections = _sectionsFor(items);
    final footer = _footer(context);
    final twoWay = model?.mode == PaginationMode.bidirectional && sections == null;

    final List<Widget> slivers;
    Key? center;
    if (twoWay) {
      // Items before the anchor page grow up (or left) from the anchor, so
      // putting a page in front moves nothing on screen.
      final anchored = _controller!.anchoredItems;
      final before = [
        for (final item in anchored.before)
          if (!_removed.contains(_keyOf(item))) item,
      ];
      final after = [
        for (final item in anchored.after)
          if (!_removed.contains(_keyOf(item))) item,
      ];
      center = _centerKey;
      slivers = [
        _sliverList(_delegate(before, reversed: true, onBuilt: (index) {
          if (index <= math.max(0, model!.thresholdItems)) _requestPrevious();
        })),
        _sliverList(_delegate(after, onBuilt: (index) => _onItemBuilt(index, after.length)), key: _centerKey),
      ];
    } else if (sections != null) {
      slivers = _sectionSlivers(context, items, sections);
    } else {
      slivers = [_sliverList(_delegate(items, onBuilt: (index) => _onItemBuilt(index, items.length)))];
    }

    final refreshable = model?.pullToRefresh == true ||
        _node.pullsToRefresh ||
        _node.actions.any((r) => r.trigger.type == TriggerType.refresh);
    final padding = _node.layout.padding.flutter;
    final cache = _node.prop(CollectionScrollProps.cacheExtent);

    Widget list = LayoutBuilder(
      builder: (context, constraints) {
        final bounded = axis == Axis.vertical ? constraints.hasBoundedHeight : constraints.hasBoundedWidth;
        return CustomScrollView(
          controller: scrollController,
          scrollDirection: axis,
          reverse: _node.prop(CollectionScrollProps.reverse),
          shrinkWrap: !bounded || widget.hugMain,
          center: center,
          physics: refreshable ? const AlwaysScrollableScrollPhysics().applyTo(widget.physics) : widget.physics,
          scrollCacheExtent: cache == null ? null : ScrollCacheExtent.pixels(cache),
          clipBehavior: clip(_node.prop(CollectionScrollProps.clipBehavior)),
          slivers: [
            for (final sliver in slivers)
              if (padding == EdgeInsets.zero)
                sliver
              else
                SliverPadding(padding: _paddingFor(padding, sliver, slivers, axis), sliver: sliver),
            if (footer != null) SliverToBoxAdapter(child: footer),
          ],
        );
      },
    );

    if (model != null && model.thresholdPixels > 0) {
      list = NotificationListener<ScrollNotification>(onNotification: _onScroll, child: list);
    }

    if (refreshable) {
      list = RefreshIndicator(
        onRefresh: _refresh,
        color: model?.refreshColor?.flutter,
        backgroundColor: model?.refreshBackgroundColor?.flutter,
        displacement: model?.refreshDisplacement ?? 40,
        child: list,
      );
    }

    if (sections != null && (_node.sections?.indexBar ?? false)) {
      list = Stack(
        children: [
          Positioned.fill(child: Scrollbar(controller: scrollController, interactive: true, child: list)),
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            child: SectionIndexBar(keys: [for (final s in sections) s.key], onSelected: jumpToSection),
          ),
        ],
      );
    }

    if (_pending.isNotEmpty) {
      final pending = _pending.last;
      list = Stack(
        children: [
          Positioned.fill(child: list),
          Positioned(
            left: 8,
            right: 8,
            bottom: 8,
            child: UndoBar(message: _undoMessage(pending), onUndo: () => _undo(pending)),
          ),
        ],
      );
    }
    return list;
  }

  String _undoMessage(_PendingSwipe pending) {
    final template = _node.swipeActions?.undoMessage ?? '';
    return template.replaceAllMapped(
      RegExp(r'\$\{\s*result\.(\w+)\s*\}'),
      (m) => '${pending.result[m.group(1)] ?? ''}',
    );
  }

  /// The list's padding goes before the first sliver and after the last.
  EdgeInsets _paddingFor(EdgeInsets padding, Widget sliver, List<Widget> slivers, Axis axis) {
    final first = identical(sliver, slivers.first), last = identical(sliver, slivers.last);
    if (axis == Axis.vertical) {
      return padding.copyWith(top: first ? padding.top : 0, bottom: last ? padding.bottom : 0);
    }
    return padding.copyWith(left: first ? padding.left : 0, right: last ? padding.right : 0);
  }
}

class _PendingSwipe {
  _PendingSwipe({required this.result, required this.commit});
  final Map<String, Object?> result;
  final VoidCallback commit;
}

class _HeaderDelegate extends SliverPersistentHeaderDelegate {
  _HeaderDelegate({required this.extent, required this.child});
  final double extent;
  final Widget child;

  @override
  double get minExtent => extent;
  @override
  double get maxExtent => extent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => SizedBox.expand(child: child);

  @override
  bool shouldRebuild(covariant _HeaderDelegate oldDelegate) => oldDelegate.extent != extent || oldDelegate.child != child;
}

/// The keys of a list's sections along its edge (A–Z): pressing or
/// dragging over one calls [onSelected] with its index.
class SectionIndexBar extends StatelessWidget {
  const SectionIndexBar({super.key, required this.keys, required this.onSelected});

  final List<Object?> keys;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    if (keys.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        void select(Offset local) {
          final height = constraints.maxHeight;
          if (!height.isFinite || height <= 0) return;
          onSelected((local.dy / height * keys.length).floor().clamp(0, keys.length - 1));
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => select(d.localPosition),
          onVerticalDragStart: (d) => select(d.localPosition),
          onVerticalDragUpdate: (d) => select(d.localPosition),
          child: Semantics(
            label: 'Section index',
            child: SizedBox(
              width: 20,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final key in keys)
                    Flexible(
                      child: FittedBox(
                        child: Text('${key ?? ''}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A bar that says what a swipe did, with an Undo button.
class UndoBar extends StatelessWidget {
  const UndoBar({super.key, required this.message, required this.onUndo});

  final String message;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xFF323232),
        elevation: 6,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Row(
            children: [
              Expanded(child: Text(message, style: const TextStyle(color: Colors.white, fontSize: 14))),
              TextButton(onPressed: onUndo, child: const Text('Undo')),
            ],
          ),
        ),
      );
}

class _DefaultLoadingFooter extends StatelessWidget {
  const _DefaultLoadingFooter();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2.5))),
      );
}

class _DefaultErrorFooter extends StatelessWidget {
  const _DefaultErrorFooter({this.error});
  final Object? error;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Couldn't load more."),
            const SizedBox(height: 4),
            Text('Tap to retry', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
          ],
        ),
      );
}
