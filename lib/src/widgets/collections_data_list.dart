// A running list (or grid) that pages, groups its items into sections or
// has swipe actions, as an island: a
// CustomScrollView of slivers whose items are the template's node boxes
// (NodeChild), each in the scope of its item (NodeBinder.provideItem).
//
// On a design canvas (not animating) the list keeps its render objects at
// rest (collections.dart): this is the running app's.
import 'dart:async';
import 'dart:math' as math;

import 'package:codelessly_api/core.dart' as api;
import 'package:codelessly_api/core.dart'
    show CollectionScrollProps, CollectionSlots, Node, Pagination, PaginationMode, SwipeAction;
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/rendering.dart'
    show GrowthDirection, RenderAbstractViewport, RenderSliverMultiBoxAdaptor, ScrollCacheExtent, SliverMultiBoxAdaptorParentData;
import 'package:flutter/scheduler.dart';

import '../render/convert.dart';
import '../render/controls/focus.dart';
import '../render/control_theme.dart' show chromeButton, chromeGlyph, chromeTokensOf, rolesOf;
import '../render/controls/buttons.dart' show ButtonKind;
import '../render/controls/root.dart';
import '../render/node_tree.dart' show RenderTree;
import '../render/controls/spinner.dart' show SpinnerStyle;
import '../render/node_view.dart' show CodelesslyLabelsScope, ControlButton, SpinnerView;
import '../render/paint/shell_constants.dart';
import '../render/recipe.dart';
import '../runtime/lists/built_items.dart';
import '../runtime/lists/pagination.dart';
import 'collections_data_list_model.dart';
import 'collections_list_runtime.dart';
import 'collections_swipe.dart';

export 'collections_data_list_model.dart';

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

class DataListViewState extends State<DataListView> implements LazyItems {
  final ScrollController scrollController = ScrollController();
  final GlobalKey _latestKey = GlobalKey();
  ControlFocusNode? _latestFocus;

  void _redrawLatestFocus() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  void _syncLatestFocus() {
    if (!mounted) return;
    final owner = _latestKey.currentContext?.findRenderObject();
    final root = owner is RenderBox ? RenderControlRoot.of(owner) : null;
    if (owner is! RenderBox || root == null) {
      _latestFocus?.leave();
      _latestFocus = null;
      return;
    }
    if (identical(_latestFocus?.owner, owner) && identical(_latestFocus?.scope, root.focus)) return;
    _latestFocus?.leave();
    _latestFocus = ControlFocusNode(owner, onActivate: _jumpToLatest, onFocusChange: (_) => _redrawLatestFocus())
      ..label = (() => mounted ? CodelesslyLabelsScope.of(context).jumpToLatest : 'Jump to latest')
      ..onHighlightChange = _redrawLatestFocus
      ..join(root.focus);
  }

  void _jumpToLatest() {
    if (_latestFocus?.hasFocus ?? false) _latestFocus?.scope?.next();
    setState(() => _atEnd = true);
    _scrollToEnd(animate: true, frames: 3);
  }

  // --- items: the current index and snapping -------------------------------------

  /// The items built now, by index.
  final Map<int, BuildContext> _built = {};

  /// The items built now, by key.
  final Map<Object?, BuildContext> _builtByKey = {};

  /// The scroll offset that puts each built item at the start of the view,
  /// by index.
  Map<int, double> _itemStarts() {
    final out = <int, double>{};
    for (final e in _built.entries) {
      if (!e.value.mounted) continue;
      final ro = e.value.findRenderObject();
      if (ro is! RenderBox || !ro.attached || !ro.hasSize) continue;
      final viewport = RenderAbstractViewport.maybeOf(ro);
      if (viewport == null) continue;
      out[e.key] = viewport.getOffsetToReveal(ro, 0).offset;
    }
    return out;
  }

  /// The scroll reaction's values: offset, max, fraction, and the item at
  /// the start of the view (the last at the end) and how many there are.
  Map<String, Object?> _scrollEvent(ScrollMetrics m) {
    final count = _items.length;
    var index = 0;
    if (m.maxScrollExtent > 0 && m.pixels >= m.maxScrollExtent - 0.5) {
      index = math.max(0, count - 1);
    } else {
      double? best;
      for (final e in _itemStarts().entries) {
        final d = (e.value - m.pixels).abs();
        if (best == null || d < best) {
          best = d;
          index = e.key;
        }
      }
    }
    final max = m.maxScrollExtent;
    return {
      'offset': m.pixels,
      'pixels': m.pixels,
      'min': m.minScrollExtent,
      'max': max,
      'viewport': m.viewportDimension,
      'fraction': max > 0 ? (m.pixels / max).clamp(0.0, 1.0) : 0.0,
      'progress': max > 0 ? (m.pixels / max).clamp(0.0, 1.0) : 0.0,
      'axis': m.axis.name,
      'index': index,
      'count': count,
    };
  }

  /// The item starts as of the last frame: what the snapping physics read
  /// (they can be asked during layout, where the items can't be measured).
  List<double> _snapStarts = const [];
  bool _snapStartsPending = false;

  void _refreshSnapStartsSoon() {
    if (_snapStartsPending || !_node.prop(CollectionScrollProps.itemSnapping)) return;
    _snapStartsPending = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _snapStartsPending = false;
      if (mounted) _snapStarts = _itemStarts().values.toList();
    });
  }

  bool _scrollEventPending = false;

  /// Reports the list's own scrolling to its `scroll` and `scrollEnd`
  /// reactions, as a scrolling row does.
  bool _onOwnScroll(ScrollNotification n) {
    if (n.depth != 0) return false;
    _refreshSnapStartsSoon();
    if (n is ScrollUpdateNotification && !_scrollEventPending) {
      _scrollEventPending = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _scrollEventPending = false;
        if (mounted && scrollController.hasClients) _r.fire('scroll', event: _scrollEvent(scrollController.position));
      });
    } else if (n is ScrollEndNotification) {
      _r.fire('scrollEnd', event: _scrollEvent(n.metrics));
    }
    return false;
  }

  /// The key of the sliver that anchors a list loading both ways.
  final Key _centerKey = UniqueKey();

  /// What the list knows and decides apart from how it is drawn.
  late final DataListModel _m = DataListModel(widget.runtime, widget.data)..addListener(_changed);

  PaginationController? get controller => _m.controller;
  PaginationController? get _controller => _m.controller;
  List<PendingSwipe> get _pending => _m.pending;
  List<ListSection>? get _sections => _m.sections;

  // A list that sticks to its end: the item the list is anchored at (items
  // before it grow up from it, so putting some there moves nothing), the
  // last item and count seen, and whether it was at its end.
  Object? _anchor;
  Object? _lastKey;
  int _lastCount = 0;
  bool _atEnd = true, _scrollListening = false;
  int _endFrames = 0;

  ListRuntime get _r => widget.runtime;
  Node get _node => _r.node;
  Pagination? get _model => _node.pagination;
  Axis get _axis => _node.prop(CollectionScrollProps.scrollDirection) == api.Axis.vertical ? Axis.vertical : Axis.horizontal;

  @override
  void initState() {
    super.initState();
    LazyItemLists.add(this);
    _m;
  }

  // --- a scrollTo of an item: copies not built yet (LazyItems) -------------------

  @override
  RenderTree get tree => _r.tree;

  @override
  String get itemId => widget.itemId;

  @override
  bool repeats(String id) {
    final source = _r.tree.source;
    var guard = 0;
    for (String? n = id; n != null && guard++ < 64; n = source.parentOf(n)) {
      if (n == widget.itemId) return true;
      if (n == _node.id) return false;
    }
    return false;
  }

  /// The index of the item [item] names: the item whose key (its `id`, or
  /// the list's key path) reads [item], else [item] as an index; -1: none.
  @override
  int indexOfItem(String item) {
    final items = _items;
    for (var i = 0; i < items.length; i++) {
      final v = items[i];
      final key = v is Map ? (v['id'] ?? v['key'] ?? _keyOf(v)) : _keyOf(v);
      if (key != null && '$key' == item) return i;
    }
    final index = int.tryParse(item);
    return index != null && index >= 0 && index < items.length ? index : -1;
  }

  @override
  String? keyAt(int index) {
    final items = _items;
    if (index < 0 || index >= items.length) return null;
    final v = items[index];
    final key = v is Map ? (v['id'] ?? v['key'] ?? _keyOf(v)) : _keyOf(v);
    return key == null || identical(key, v) && v is Map ? null : '$key';
  }

  /// Builds item [index] when the list has not (a list builds only the
  /// items near its view): scrolls toward it, from the items built where it
  /// is and their extents, a frame at a time, until it is laid out. Whether
  /// it is.
  @override
  Future<bool> buildItem(int index) async {
    bool built() {
      final ro = _built[index]?.findRenderObject();
      return ro is RenderBox && ro.attached && ro.hasSize;
    }

    for (var step = 0; step < 16 && !built(); step++) {
      if (!mounted || !scrollController.hasClients) return false;
      final p = scrollController.position;
      final starts = _itemStarts();
      double to;
      if (starts.isEmpty) {
        final count = _items.length;
        to = count <= 1 ? p.minScrollExtent : p.minScrollExtent + (p.maxScrollExtent - p.minScrollExtent) * index / (count - 1);
      } else {
        final indexes = starts.keys.toList()..sort();
        final lo = indexes.first, hi = indexes.last;
        final each = hi > lo ? (starts[hi]! - starts[lo]!) / (hi - lo) : p.viewportDimension;
        final from = index < lo ? lo : hi;
        to = starts[from]! + (index - from) * each;
      }
      p.jumpTo(to.clamp(p.minScrollExtent, p.maxScrollExtent).toDouble());
      SchedulerBinding.instance.scheduleFrame();
      await SchedulerBinding.instance.endOfFrame;
    }
    return mounted && built();
  }

  @override
  void didUpdateWidget(covariant DataListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _m.update(widget.runtime, widget.data);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  /// A list that sticks to its end: it opens there, and an item added at
  /// the end scrolls it there only while it was there.
  void _followEnd(List<Object?> items) {
    if (!_scrollListening) {
      _scrollListening = true;
      scrollController.addListener(_scrolled);
    }
    final last = items.isEmpty ? null : _keyOf(items.last);
    final grew = items.length != _lastCount || last != _lastKey;
    final first = _lastCount == 0 && items.isNotEmpty;
    _lastCount = items.length;
    _lastKey = last;
    if (grew && _atEnd) _scrollToEnd(animate: !first, frames: 3);
  }

  void _scrolled() {
    if (_endFrames > 0 || !scrollController.hasClients) return;
    final p = scrollController.position;
    final atEnd = p.pixels >= p.maxScrollExtent - 8;
    if (atEnd != _atEnd) setState(() => _atEnd = atEnd);
  }

  /// Scrolls to the end after the frame, again on the next ones (lazily
  /// built items only know their extent once laid out).
  void _scrollToEnd({required bool animate, int frames = 1}) {
    _endFrames = frames;
    SchedulerBinding.instance.ensureVisualUpdate();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !scrollController.hasClients) {
        _endFrames = 0;
        return;
      }
      final p = scrollController.position;
      if (animate && (p.maxScrollExtent - p.pixels) > 0) {
        unawaited(scrollController
            .animateTo(p.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut)
            .whenComplete(() {
          _endFrames = 0;
          if (mounted && scrollController.hasClients) _scrollToEnd(animate: false);
        }));
        return;
      }
      if (p.pixels != p.maxScrollExtent) p.jumpTo(p.maxScrollExtent);
      _endFrames = frames - 1;
      if (_endFrames > 0) {
        _scrollToEnd(animate: false, frames: _endFrames);
      } else {
        _atEnd = true;
      }
    });
  }

  /// [physics] that, with the list's `itemSnapping`, come to rest with an
  /// item at the start of the view.
  ScrollPhysics? _withSnapping(ScrollPhysics? physics) {
    if (!_node.prop(CollectionScrollProps.itemSnapping)) return physics;
    _refreshSnapStartsSoon();
    return ItemSnapPhysics(starts: () => _snapStarts, parent: physics);
  }

  @override
  void dispose() {
    LazyItemLists.remove(this);
    _latestFocus?.leave();
    _m
      ..removeListener(_changed)
      ..dispose();
    scrollController.dispose();
    super.dispose();
  }

  List<Object?> get _items => _m.items;
  Object? _keyOf(Object? item) => _m.keyOf(item);
  void _requestPrevious() => _m.requestPrevious();
  void _onItemBuilt(int index, int count) => _m.onItemBuilt(index, count);
  Future<void> _refresh() => _m.refresh();

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    _m.onScrollExtents(notification.metrics.extentBefore, notification.metrics.extentAfter);
    return false;
  }

  /// The node box of repeat [key] of node [id], in the scope of [item] at
  /// [index].
  Widget _node$(String tag, String id, Object? key, int index, Object? item) {
    return NodeChild(tree: _r.tree, id: id, instance: _m.provide(tag, key, index, item));
  }

  /// A slot node of the list (a footer), in the list's scope.
  Widget _slot(String id) => NodeChild(tree: _r.tree, id: id, instance: _r.b.instance);

  Widget _item(BuildContext context, int index, Object? item) {
    final key = _keyOf(item);
    Widget child = _IndexedItem(index: index, itemKey: key, list: this, child: _node$('row', widget.itemId, key, index, item));
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
        semanticLabel: 'Swipe actions for ${_swipeRowLabel(item, index)}',
        offered: (action) => _r.holds(action.when, item: item, index: index),
        onAction: (action) => _onSwipe(action, index, item),
        textDefault: _node.behaviors.defaultTextStyle,
        child: child,
      );
    }
    return child;
  }

  void _onSwipe(SwipeAction action, int index, Object? item) => _m.onSwipe(action, index, item);

  String _swipeRowLabel(Object? item, int index) {
    if (item is Map) {
      for (final field in const ['label', 'name', 'title', 'id']) {
        final value = item[field];
        if (value != null && '$value'.trim().isNotEmpty) return '$value';
      }
    }
    if (item is String && item.trim().isNotEmpty) return item;
    return 'row ${index + 1}';
  }
  void _undo(PendingSwipe pending) => _m.undo(pending);
  List<ListSection>? _sectionsFor(List<Object?> items) => _m.sectionsFor(items);
  List<Object?> _indexKeys(List<ListSection> sections) => _m.indexKeys(sections);
  Set<String> _presentKeys(List<ListSection> sections) => _m.presentKeys(sections);

  /// Jumps to the section with [key]. With a data-paged list whose pages
  /// don't reach it yet, loads them first.
  Future<void> jumpToKey(Object? key) async {
    var i = _m.sectionIndexOf(key);
    if (i < 0 && await _m.loadUntilKey(key)) {
      if (!mounted) return;
      setState(() {});
      await SchedulerBinding.instance.endOfFrame;
      if (!mounted) return;
      _sectionsFor(_items);
      i = _m.sectionIndexOf(key);
    }
    if (i >= 0) jumpToSection(i);
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
    final footer = _m.footer;
    if (footer == null) return null;
    final (kind, slot) = footer;
    return switch (kind) {
      DataListFooter.error => GestureDetector(
          key: const ValueKey('pagination-error'),
          behavior: HitTestBehavior.opaque,
          onTap: _controller!.retry,
          child: slot != null ? _slot(slot) : _DefaultErrorFooter(error: _controller!.error),
        ),
      DataListFooter.loading => KeyedSubtree(
          key: const ValueKey('pagination-loading'),
          child: slot != null ? _slot(slot) : const _DefaultLoadingFooter(),
        ),
      DataListFooter.end => KeyedSubtree(key: const ValueKey('pagination-end'), child: _slot(slot!)),
    };
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
            // The list's spacing also parts a section's last item from the
            // next section's header, as between any two entries of a list.
            if (s < sections.length - 1 && widget.separator != null && widget.separatorExtent > 0)
              SliverToBoxAdapter(
                child: SizedBox(
                  width: vertical ? null : widget.separatorExtent,
                  height: vertical ? widget.separatorExtent : null,
                ),
              ),
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
    _m.forgetGone();
    return out;
  }

  Widget _build(BuildContext context) {
    final items = _items;
    final model = _model;
    final axis = _axis;
    final sections = _sectionsFor(items);
    final footer = _footer(context);
    final twoWay = model?.mode == PaginationMode.bidirectional && sections == null;
    final sticky = _node.sticksToEnd && !twoWay;
    if (sticky) _followEnd(items);
    // (A list paged a page at a time shows each page from its start.)
    final anchored = !twoWay && sections == null && widget.gridDelegate == null && model?.mode != PaginationMode.pages;

    final List<Widget> slivers;
    Key? center;
    if (twoWay) {
      // Items before the anchor page grow up (or left) from the anchor, so
      // putting a page in front moves nothing on screen.
      final anchored = _controller!.anchoredItems;
      final before = [
        for (final item in anchored.before)
          if (!_m.isRemoved(_keyOf(item))) item,
      ];
      final after = [
        for (final item in anchored.after)
          if (!_m.isRemoved(_keyOf(item))) item,
      ];
      center = _centerKey;
      slivers = [
        _sliverList(_delegate(before, reversed: true, onBuilt: (index) {
          if (index <= math.max(0, model!.thresholdItems)) _requestPrevious();
        })),
        _sliverList(_delegate(after, onBuilt: (index) => _onItemBuilt(index, after.length)), key: _centerKey),
      ];
    } else if (anchored) {
      // Built with the view's size known (below).
      center = _centerKey;
      slivers = const [];
    } else if (sections != null) {
      slivers = _sectionSlivers(context, items, sections);
    } else {
      slivers = [_sliverList(_delegate(items, onBuilt: (index) => _onItemBuilt(index, items.length)))];
    }

    final refreshable = _m.refreshable;
    final padding = _node.layout.padding.flutter;
    final cache = _node.prop(CollectionScrollProps.cacheExtent);

    // The footer is the list's last item: inside its padding, as in a
    // padded list (the end-of-list line sits above the bottom padding).
    final all = [...slivers, if (footer != null) SliverToBoxAdapter(child: footer)];
    Widget list = LayoutBuilder(
      builder: (context, constraints) {
        final bounded = axis == Axis.vertical ? constraints.hasBoundedHeight : constraints.hasBoundedWidth;
        final shrink = !bounded || widget.hugMain;
        // A list as long as its items (no height: stickToEnd with nothing to
        // stick in) has no end to keep in view: its items in order, with no
        // anchor (a shrink-wrapped viewport cannot have one: it threw).
        final List<Widget> parts;
        if (shrink && center != null) {
          parts = [_sliverList(_delegate(items, onBuilt: (index) => _onItemBuilt(index, items.length))), if (footer != null) SliverToBoxAdapter(child: footer)];
        } else if (anchored) {
          // Items put before the anchor grow up (or left) from it, so the
          // offset of everything from the anchor on stays; what else moves
          // what is in view is undone as the list lays out (_HoldPhysics).
          final at = _anchorIndex(items, sticky: sticky);
          parts = [
            if (at > 0)
              _sliverList(_delegate(items, count: at, reversed: true, onBuilt: (index) => _onItemBuilt(index, items.length)),
                  // A fresh sliver as its count changes: one keeping the rows
                  // it laid out underestimates how far it reaches.
                  key: ValueKey(('before', at))),
            _sliverList(_delegate(items, start: at, onBuilt: (index) => _onItemBuilt(index, items.length)), key: _centerKey),
            if (footer != null) SliverToBoxAdapter(child: footer),
          ];
        } else {
          parts = all;
        }
        final direction = getAxisDirectionFromAxisReverseAndDirectionality(context, axis, _node.prop(CollectionScrollProps.reverse));
        final physics = _withSnapping(refreshable ? const AlwaysScrollableScrollPhysics().applyTo(widget.physics) : widget.physics);
        return CustomScrollView(
          controller: scrollController,
          scrollDirection: axis,
          reverse: _node.prop(CollectionScrollProps.reverse),
          shrinkWrap: shrink,
          center: shrink ? null : center,
          physics: anchored && !shrink ? _HoldPhysics(adjust: _held, parent: physics) : physics,
          scrollCacheExtent: cache == null ? null : ScrollCacheExtent.pixels(cache),
          clipBehavior: clip(_node.prop(CollectionScrollProps.clipBehavior)),
          slivers: [
            for (final sliver in parts)
              if (padding == EdgeInsets.zero)
                sliver
              else
                // (With the sliver's key: the viewport's center is found by it.
                // A padded list that keeps its end in view, stickToEnd with
                // pad=, asserted and drew nothing: round 11b, team-chat.)
                SliverPadding(key: sliver.key, padding: _paddingFor(padding, sliver, parts, direction), sliver: sliver),
          ],
        );
      },
    );

    if (model != null && model.thresholdPixels > 0) {
      list = NotificationListener<ScrollNotification>(onNotification: _onScroll, child: list);
    }
    list = NotificationListener<ScrollNotification>(onNotification: _onOwnScroll, child: list);

    if (refreshable) {
      list = PullToRefresh(
        onRefresh: _refresh,
        color: model?.refreshColor?.flutter,
        backgroundColor: model?.refreshBackgroundColor?.flutter,
        displacement: model?.refreshDisplacement ?? 40,
        style: _node.prop(api.ListViewProps.refreshStyle),
        child: list,
      );
    }

    if (sections != null && (_node.sections?.indexBar ?? false)) {
      list = Stack(
        children: [
          // The index is the list's scroll control: no scrollbar under it.
          Positioned.fill(child: list),
          Positioned(
            top: _node.sections!.indexInsets.elementAtOrNull(1) ?? 0,
            bottom: _node.sections!.indexInsets.elementAtOrNull(3) ?? 0,
            right: _node.sections!.indexInsets.elementAtOrNull(2) ?? 0,
            child: () {
              final model = _node.sections!;
              final keys = _indexKeys(sections);
              final style = model.indexStyle;
              return SectionIndexBar(
                keys: keys,
                present: _presentKeys(sections),
                style: style == api.TextStyle.empty ? null : textStyle(style, _node.behaviors.defaultTextStyle),
                activeColor: model.indexActiveColor?.flutter,
                mutedColor: model.indexMutedColor?.flutter,
                width: model.indexWidth,
                bubble: model.indexBubble,
                bubbleColor: model.indexBubbleColor?.flutter,
                bubbleStyle: model.indexBubbleStyle == api.TextStyle.empty ? null : textStyle(model.indexBubbleStyle, _node.behaviors.defaultTextStyle),
                onSelected: (i) => jumpToKey(keys[i]),
              );
            }(),
          ),
        ],
      );
    }

    if (_pending.isNotEmpty) {
      final pending = _pending.last;
      final bar = UndoBar(message: _m.undoMessage(pending), onUndo: () => _undo(pending));
      final inner = list;
      // Over the foot of a list as tall as its box; under a list that hugs
      // its rows (it has no height of its own to lay the bar over, and the
      // bar would hide its last row).
      list = LayoutBuilder(
        builder: (context, constraints) {
          if (!constraints.hasBoundedHeight) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: constraints.hasBoundedWidth ? CrossAxisAlignment.stretch : CrossAxisAlignment.start,
              children: [inner, Padding(padding: const EdgeInsets.fromLTRB(8, 8, 8, 0), child: bar)],
            );
          }
          return Stack(
            fit: StackFit.passthrough,
            children: [inner, Positioned(left: 8, right: 8, bottom: 8, child: bar)],
          );
        },
      );
    }
    if (sticky) {
      SchedulerBinding.instance.addPostFrameCallback((_) => _syncLatestFocus());
      final tokens = chromeTokensOf(context);
      final inner = list;
      // A list as tall as its items (no height of its own, in a column
      // that scrolls) has no end to stick to nor to jump to: it is its
      // items (a Stack over it had no bound: the list threw).
      list = LayoutBuilder(builder: (context, constraints) => !(axis == Axis.vertical ? constraints.hasBoundedHeight : constraints.hasBoundedWidth)
          ? inner
          : Stack(children: [
        Positioned.fill(child: inner),
        if (!_atEnd && _node.prop(api.ListViewProps.jumpToLatest)) PositionedDirectional(
          end: 12,
          bottom: 12,
          child: Semantics(
            key: _latestKey,
            label: CodelesslyLabelsScope.of(context).jumpToLatest,
            button: true,
            focused: _latestFocus?.hasFocus ?? false,
            onTap: _jumpToLatest,
            child: ExcludeSemantics(child: Focus(
              descendantsAreFocusable: false,
              // The stop is the list's own (the semantics above): not the
              // button's.
              child: SizedBox.square(
                key: const ValueKey('followListLatest'),
                dimension: 44,
                child: ControlButton(
                  focusable: false,
                  onPressed: _jumpToLatest,
                  semanticsLabel: CodelesslyLabelsScope.of(context).jumpToLatest,
                  spec: chromeButton(
                    tokens: tokens,
                    kind: ButtonKind.fab,
                    fabType: api.FloatingActionButtonType.small,
                    icon: axis == Axis.vertical
                        ? chromeGlyph('arrow_downward', const IconData(ShellGlyphs.arrowDownward, fontFamily: ShellGlyphs.font))
                        : chromeGlyph(
                            'arrow_forward',
                            const IconData(ShellGlyphs.arrowForward, fontFamily: ShellGlyphs.font, matchTextDirection: true),
                          ),
                    side: _latestFocus?.showsHighlight == true ? BorderSide(color: tokens.focusBorder, width: 2) : null,
                  ),
                ),
              ),
            )),
          ),
        ),
      ]));
    }
    return list;
  }

  /// The list's padding goes before the first sliver and after the last:
  /// on the side the list scrolls from (the bottom of a reversed list) and
  /// the side it scrolls to.
  EdgeInsets _paddingFor(EdgeInsets padding, Widget sliver, List<Widget> slivers, AxisDirection direction) {
    final first = identical(sliver, slivers.first), last = identical(sliver, slivers.last);
    return switch (direction) {
      AxisDirection.down => padding.copyWith(top: first ? padding.top : 0, bottom: last ? padding.bottom : 0),
      AxisDirection.up => padding.copyWith(bottom: first ? padding.bottom : 0, top: last ? padding.top : 0),
      AxisDirection.right => padding.copyWith(left: first ? padding.left : 0, right: last ? padding.right : 0),
      AxisDirection.left => padding.copyWith(right: first ? padding.right : 0, left: last ? padding.left : 0),
    };
  }

  // --- holding what is in view as the items change ----------------------------
  //
  // A list over data keeps what is in view where it is when items are put
  // before it or taken out before it (CSS scroll anchoring). Items put
  // before the anchor (the first item the list showed, while it is there)
  // go in a sliver before it that grows away from it, so they move nothing.
  // Any other move of what is in view (items put or taken out between the
  // anchor and the view, the anchor taken out) is undone as the list lays
  // out: the first item in view before the change is put back where it was
  // ([_HoldPhysics]). At the list's very start, what is put there shows
  // instead (as a browser does at the top of a page) unless `stickToStart`
  // is false and the items fill the list, or the list sticks to its end.

  /// The keys of the items as last built.
  List<Object?> _lastKeys = const [];

  /// What the next layout holds, set when the items change: an item's key
  /// and where it started, or the list's start ([_Hold.start]).
  _Hold? _hold;

  /// Where the list is anchored in [items]: the index of the first item of
  /// the anchor sliver. Sets [_hold] when the items changed.
  int _anchorIndex(List<Object?> items, {required bool sticky}) {
    final keys = [for (final item in items) _keyOf(item)];
    final lastKeys = _lastKeys;
    _lastKeys = keys;
    if (keys.isEmpty) {
      _anchor = null;
      return 0;
    }
    var at = _anchor == null ? -1 : keys.indexOf(_anchor);
    final p = scrollController.hasClients && scrollController.positions.length == 1 ? scrollController.position : null;
    if (p != null && p.hasContentDimensions && p.hasPixels && !listEquals(keys, lastKeys)) {
      _hold = _holdFor(p, keys, lastKeys, sticky: sticky);
      if (_hold != null) {
        SchedulerBinding.instance.addPostFrameCallback((_) => _hold = null);
      }
    }
    if (at < 0 && _anchor != null) {
      // The anchor went: the next item after it still there.
      final was = lastKeys.indexOf(_anchor);
      for (var i = was + 1; was >= 0 && i < lastKeys.length && at < 0; i++) {
        at = keys.indexOf(lastKeys[i]);
      }
    }
    if (at < 0) at = 0;
    _anchor = keys[at];
    return at;
  }

  /// What to hold as the items change from [lastKeys] to [keys]: the list's
  /// start, or the first item in view (its end past the view's start) that
  /// is still there; null: nothing.
  _Hold? _holdFor(ScrollPosition p, List<Object?> keys, List<Object?> lastKeys, {required bool sticky}) {
    if (p.pixels <= p.minScrollExtent + 0.5 &&
        (p.maxScrollExtent <= 0 || (!sticky && _node.prop(api.ListViewProps.stickToStart)))) {
      return const _Hold.start();
    }
    for (final i in _built.keys.toList()..sort()) {
      if (i >= lastKeys.length || !keys.contains(lastKeys[i])) continue;
      final ro = _built[i]!.mounted ? _built[i]!.findRenderObject() : null;
      if (ro is! RenderBox || !ro.attached || !ro.hasSize) continue;
      final viewport = RenderAbstractViewport.maybeOf(ro);
      final at = _placeOf(ro);
      if (viewport == null || at == null) continue;
      final extent = _axis == Axis.vertical ? ro.size.height : ro.size.width;
      if (viewport.getOffsetToReveal(ro, 0).offset + extent <= p.pixels + 0.5) continue;
      final hold = _Hold(lastKeys[i], at, p.pixels);
      // Items taken out between the anchor and the held one bring it that
      // much nearer the anchor: go there first, so it is laid out where
      // the list looks (the layout then puts it back exactly).
      final anchorAt = _anchor == null ? -1 : lastKeys.indexOf(_anchor);
      if (anchorAt >= 0) {
        final present = keys.toSet();
        final from = math.min(anchorAt, i + 1), to = math.max(anchorAt, i);
        var gone = 0.0, seen = 0.0, measured = 0;
        for (final c in _built.entries) {
          final box = c.value.mounted ? c.value.findRenderObject() : null;
          if (box is RenderBox && box.hasSize) {
            seen += _axis == Axis.vertical ? box.size.height : box.size.width;
            measured++;
          }
        }
        final average = measured == 0 ? 0.0 : seen / measured;
        for (var k = from; k < to; k++) {
          if (present.contains(lastKeys[k])) continue;
          final box = _built[k]?.mounted ?? false ? _built[k]!.findRenderObject() : null;
          gone += box is RenderBox && box.hasSize ? (_axis == Axis.vertical ? box.size.height : box.size.width) : average;
        }
        if (gone > 0) p.correctPixels(p.pixels + (i >= anchorAt ? -gone : gone));
      }
      return hold;
    }
    return null;
  }

  /// Where [box] (an item's) is laid out in the list's scroll offsets, from
  /// its sliver's place and its own in it (its edge toward the anchor: the
  /// start in the anchor's sliver, the end in the one before it); null
  /// when it is in no sliver. Reads no size, so it can be asked while the
  /// list lays out.
  static double? _placeOf(RenderBox box) {
    RenderObject child = box;
    while (child.parent != null && child.parent is! RenderSliverMultiBoxAdaptor) {
      child = child.parent!;
    }
    final sliver = child.parent;
    final data = child.parentData;
    if (sliver is! RenderSliverMultiBoxAdaptor || data is! SliverMultiBoxAdaptorParentData) return null;
    final at = sliver.constraints.precedingScrollExtent + (data.layoutOffset ?? 0);
    return sliver.constraints.growthDirection == GrowthDirection.reverse ? -at : at;
  }

  /// The offset the list takes as it lays out after its items changed:
  /// its start, or the held item back where it was; null: as it is.
  double? _held(ScrollMetrics oldPosition, ScrollMetrics newPosition) {
    final hold = _hold;
    if (hold == null) return null;
    _hold = null;
    if (hold.atStart) return newPosition.minScrollExtent;
    final context = _builtByKey[hold.key];
    final ro = context == null || !context.mounted ? null : context.findRenderObject();
    final now = ro is RenderBox && ro.attached ? _placeOf(ro) : null;
    if (now == null) return null;
    return hold.pixels + now - hold.offset;
  }
}

/// What a list holds in view as its items change: where item [key] started
/// (its offset at the start of the view), or the list's start.
class _Hold {
  const _Hold(this.key, this.offset, this.pixels) : atStart = false;
  const _Hold.start()
      : key = null,
        offset = 0,
        pixels = 0,
        atStart = true;
  final Object? key;
  final double offset;

  /// The list's offset when [offset] was read.
  final double pixels;
  final bool atStart;
}

/// Scroll physics that put a list's offset where [adjust] says as the list
/// lays out with new extents (items put in or taken out): what keeps what
/// is in view in place, in the same frame.
class _HoldPhysics extends ScrollPhysics {
  const _HoldPhysics({required this.adjust, super.parent});

  final double? Function(ScrollMetrics oldPosition, ScrollMetrics newPosition) adjust;

  @override
  _HoldPhysics applyTo(ScrollPhysics? ancestor) => _HoldPhysics(adjust: adjust, parent: buildParent(ancestor));

  @override
  double adjustPositionForNewDimensions({
    required ScrollMetrics oldPosition,
    required ScrollMetrics newPosition,
    required bool isScrolling,
    required double velocity,
  }) =>
      adjust(oldPosition, newPosition) ??
      super.adjustPositionForNewDimensions(
          oldPosition: oldPosition, newPosition: newPosition, isScrolling: isScrolling, velocity: velocity);
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
/// dragging over one calls [onSelected] with its index. Keys not in
/// [present] (when given) show in [mutedColor] and do nothing; the touched
/// key shows in [activeColor], and with [bubble] pops up large beside the
/// bar.
class SectionIndexBar extends StatefulWidget {
  const SectionIndexBar({
    super.key,
    required this.keys,
    required this.onSelected,
    this.present,
    this.style,
    this.activeColor,
    this.mutedColor,
    this.width = 20,
    this.bubble = false,
    this.bubbleColor,
    this.bubbleStyle,
  });

  final List<Object?> keys;
  final ValueChanged<int> onSelected;
  final Set<String>? present;
  final TextStyle? style;
  final Color? activeColor, mutedColor;
  final double width;
  final bool bubble;
  final Color? bubbleColor;
  final TextStyle? bubbleStyle;

  @override
  State<SectionIndexBar> createState() => _SectionIndexBarState();
}

class _SectionIndexBarState extends State<SectionIndexBar> {
  int? _touching;

  bool _offers(int i) => widget.present == null || widget.present!.contains('${widget.keys[i]}');

  void _select(Offset local, double height) {
    if (!height.isFinite || height <= 0) return;
    final i = (local.dy / height * widget.keys.length).floor().clamp(0, widget.keys.length - 1);
    if (i == _touching) return;
    setState(() => _touching = i);
    if (_offers(i)) widget.onSelected(i);
  }

  void _release() {
    if (_touching != null) setState(() => _touching = null);
  }

  @override
  Widget build(BuildContext context) {
    final keys = widget.keys;
    if (keys.isEmpty) return const SizedBox.shrink();
    final base = const TextStyle(fontSize: 11, fontWeight: FontWeight.w600).merge(widget.style);
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final touching = _touching;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => _select(d.localPosition, height),
              onTapUp: (_) => _release(),
              onTapCancel: _release,
              onVerticalDragStart: (d) => _select(d.localPosition, height),
              onVerticalDragUpdate: (d) => _select(d.localPosition, height),
              onVerticalDragEnd: (_) => _release(),
              child: Semantics(
                label: 'Section index',
                child: SizedBox(
                  width: widget.width,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (var i = 0; i < keys.length; i++)
                        Flexible(
                          child: FittedBox(
                            child: Text(
                              '${keys[i] ?? ''}',
                              style: base.copyWith(
                                color: i == touching && widget.activeColor != null
                                    ? widget.activeColor
                                    : !_offers(i) && widget.mutedColor != null
                                        ? widget.mutedColor
                                        : null,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (widget.bubble && touching != null && height.isFinite)
              Positioned(
                right: widget.width + 12,
                top: (touching + 0.5) / keys.length * height - 36,
                child: IgnorePointer(
                  child: Container(
                    width: 72,
                    height: 72,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: widget.bubbleColor ?? const Color(0xFF323232),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${keys[touching] ?? ''}',
                      style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w700, color: ShellColors.white)
                          .merge(widget.bubbleStyle),
                    ),
                  ),
                ),
              ),
          ],
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
  Widget build(BuildContext context) {
    // The bar is the theme's inverse surface (a tooltip's): the button's
    // states are the tokens' on it.
    final theme = chromeTokensOf(context);
    final tokens = chromeTokensOf(context, on: theme.tooltipBackground);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.tooltipBackground,
        borderRadius: BorderRadius.circular(theme.radius('panel', 8)),
        boxShadow: theme.shadows('level3'),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 6, 6, 6),
        child: Row(
          children: [
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: theme.tooltipText,
                  fontSize: 13,
                  fontFamily: theme.fontFamily,
                  decoration: TextDecoration.none,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            ControlButton(
              onPressed: onUndo,
              spec: chromeButton(tokens: tokens, label: 'Undo', foreground: theme.tooltipText),
            ),
          ],
        ),
      ),
    );
  }
}

class _DefaultLoadingFooter extends StatelessWidget {
  const _DefaultLoadingFooter();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: SizedBox.square(
            dimension: 24,
            child: SpinnerView(color: rolesOf(context).primary),
          ),
        ),
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
            Text('Tap to retry', style: TextStyle(color: rolesOf(context).primary)),
          ],
        ),
      );
}

/// An item of a [DataListView], known to the list by its index while built.
class _IndexedItem extends StatefulWidget {
  const _IndexedItem({required this.index, required this.itemKey, required this.list, required this.child});
  final int index;

  /// The item's key (its `id`).
  final Object? itemKey;
  final DataListViewState list;
  final Widget child;

  @override
  State<_IndexedItem> createState() => _IndexedItemState();
}

class _IndexedItemState extends State<_IndexedItem> {
  void _enter() {
    widget.list._built[widget.index] = context;
    widget.list._builtByKey[widget.itemKey] = context;
  }

  void _leave(_IndexedItem w) {
    if (identical(widget.list._built[w.index], context)) widget.list._built.remove(w.index);
    if (identical(widget.list._builtByKey[w.itemKey], context)) widget.list._builtByKey.remove(w.itemKey);
  }

  @override
  void initState() {
    super.initState();
    _enter();
  }

  @override
  void didUpdateWidget(covariant _IndexedItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    _leave(oldWidget);
    _enter();
  }

  // Out of the tree (a row the list let go, kept to be reused or
  // dropped), it is not the built item at its index.
  @override
  void deactivate() {
    _leave(widget);
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    _enter();
  }

  @override
  void dispose() {
    _leave(widget);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Scroll physics that come to rest with an item at the start of the view
/// (CSS `scroll-snap-align: start`), as `PageScrollPhysics` comes to rest on
/// a page: the item start nearest where the [parent]'s fling would end, at
/// least one item on in the direction of a fling.
class ItemSnapPhysics extends ScrollPhysics {
  const ItemSnapPhysics({required this.starts, super.parent});

  /// The offsets that put each built item at the start of the view.
  final Iterable<double> Function() starts;

  @override
  ItemSnapPhysics applyTo(ScrollPhysics? ancestor) => ItemSnapPhysics(starts: starts, parent: buildParent(ancestor));

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    if ((velocity <= 0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }
    final all = [for (final s in starts()) s.clamp(position.minScrollExtent, position.maxScrollExtent)]..sort();
    if (all.isEmpty) return super.createBallisticSimulation(position, velocity);
    final coast = super.createBallisticSimulation(position, velocity)?.x(double.infinity) ?? position.pixels;
    var target = all.reduce((a, b) => (a - coast).abs() <= (b - coast).abs() ? a : b);
    final tolerance = toleranceFor(position);
    if (velocity > tolerance.velocity && target <= position.pixels + tolerance.distance) {
      target = all.firstWhere((s) => s > position.pixels + tolerance.distance, orElse: () => target);
    } else if (velocity < -tolerance.velocity && target >= position.pixels - tolerance.distance) {
      target = all.lastWhere((s) => s < position.pixels - tolerance.distance, orElse: () => target);
    }
    if ((target - position.pixels).abs() < tolerance.distance) return null;
    return ScrollSpringSimulation(spring, position.pixels, target, velocity, tolerance: tolerance);
  }

  @override
  bool get allowImplicitScrolling => false;
}

/// Pull to refresh for a vertical list: dragging [child]'s scroll view past
/// its start brings a round indicator down from the top (the SDK's spinner
/// on a disc, its arc filling as the drag goes); let go far enough (a quarter of the list's height) and
/// it stays at [displacement], turning, while [onRefresh] runs, then shrinks
/// away. Let go sooner and it goes back up.
class PullToRefresh extends StatefulWidget {
  const PullToRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
    this.color,
    this.backgroundColor,
    this.displacement = 40,
    this.style = api.RefreshStyle.disc,
  });

  /// A disc over the list, or iOS's ticked spinner with no disc.
  final api.RefreshStyle style;

  final Future<void> Function() onRefresh;
  final Widget child;

  /// The arc (null: the theme's primary).
  final Color? color;

  /// The disc (null: the theme's raised surface).
  final Color? backgroundColor;

  /// How far under the list's top the indicator rests while refreshing.
  final double displacement;

  @override
  State<PullToRefresh> createState() => _PullToRefreshState();
}

enum _Pull { drag, armed, snap, refresh, done, canceled }

class _PullToRefreshState extends State<PullToRefresh> with TickerProviderStateMixin<PullToRefresh> {
  // The part of the list's height a drag covers to arm it; how far past
  // its resting place the drag can take the indicator.
  static const _dragExtent = 0.25;
  static const _overshoot = 1.5;
  static const _snap = Duration(milliseconds: 150);
  static const _leave = Duration(milliseconds: 200);

  late final AnimationController _position = AnimationController(vsync: this);
  late final AnimationController _scale = AnimationController(vsync: this);
  late final Animation<double> _positionFactor = _position.drive(Tween<double>(begin: 0, end: _overshoot));
  late final Animation<double> _scaleFactor = _scale.drive(Tween<double>(begin: 1, end: 0));

  _Pull? _status;
  double? _dragOffset;

  @override
  void dispose() {
    _position.dispose();
    _scale.dispose();
    super.dispose();
  }

  // The arc fades in over the drag up to its resting place: fully there, it
  // is armed.
  double get _ink => (_position.value * _overshoot).clamp(0.0, 1.0);

  bool _atStart(ScrollMetrics m) =>
      (m.axisDirection == AxisDirection.up && m.extentAfter == 0) || (m.axisDirection == AxisDirection.down && m.extentBefore == 0);

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0) return false;
    final vertical = n.metrics.axisDirection == AxisDirection.down || n.metrics.axisDirection == AxisDirection.up;
    if (n is ScrollStartNotification && n.dragDetails != null && _atStart(n.metrics) && _status == null && vertical) {
      _dragOffset = 0;
      _scale.value = 0;
      _position.value = 0;
      setState(() => _status = _Pull.drag);
      return false;
    }
    final dragging = _status == _Pull.drag || _status == _Pull.armed;
    if (!vertical) {
      if (dragging) _dismiss(_Pull.canceled);
    } else if (n is ScrollUpdateNotification) {
      if (dragging) {
        final delta = n.scrollDelta ?? 0;
        _dragOffset = _dragOffset! + (n.metrics.axisDirection == AxisDirection.down ? -delta : delta);
        _checkDrag(n.metrics.viewportDimension);
      }
      if (_status == _Pull.armed && n.dragDetails == null) _show();
    } else if (n is OverscrollNotification) {
      if (dragging) {
        _dragOffset = _dragOffset! + (n.metrics.axisDirection == AxisDirection.down ? -n.overscroll : n.overscroll);
        _checkDrag(n.metrics.viewportDimension);
      }
    } else if (n is ScrollEndNotification) {
      if (_status == _Pull.armed) {
        if (_position.value < 1) {
          _dismiss(_Pull.canceled);
        } else {
          _show();
        }
      } else if (_status == _Pull.drag) {
        _dismiss(_Pull.canceled);
      }
    }
    return false;
  }

  // While it is dragged the list's own overscroll glow stays away.
  bool _onGlow(OverscrollIndicatorNotification n) {
    if (n.depth != 0 || !n.leading || _status != _Pull.drag) return false;
    n.disallowIndicator();
    return true;
  }

  void _checkDrag(double extent) {
    var value = extent <= 0 ? 0.0 : _dragOffset! / (extent * _dragExtent);
    if (_status == _Pull.armed) value = math.max(value, 1 / _overshoot);
    _position.value = value.clamp(0.0, 1.0);
    if (_status == _Pull.drag && _ink >= 1) _status = _Pull.armed;
  }

  Future<void> _dismiss(_Pull to) async {
    await Future<void>.value();
    if (!mounted) return;
    setState(() => _status = to);
    if (to == _Pull.done) {
      await _scale.animateTo(1, duration: _leave);
    } else {
      await _position.animateTo(0, duration: _leave);
    }
    if (mounted && _status == to) {
      _dragOffset = null;
      setState(() => _status = null);
    }
  }

  void _show() {
    _status = _Pull.snap;
    _position.animateTo(1 / _overshoot, duration: _snap).then<void>((_) {
      if (!mounted || _status != _Pull.snap) return;
      setState(() => _status = _Pull.refresh);
      widget.onRefresh().whenComplete(() {
        if (mounted && _status == _Pull.refresh) _dismiss(_Pull.done);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final child = NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: NotificationListener<OverscrollIndicatorNotification>(onNotification: _onGlow, child: widget.child),
    );
    final tokens = chromeTokensOf(context);
    final color = widget.color ?? tokens.primary;
    final turning = _status == _Pull.refresh || _status == _Pull.done;
    return Stack(
      children: [
        child,
        if (_status != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SizeTransition(
              alignment: const AlignmentDirectional(-1, 1),
              sizeFactor: _positionFactor,
              child: Padding(
                padding: EdgeInsets.only(top: widget.displacement),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ScaleTransition(
                    scale: _scaleFactor,
                    child: AnimatedBuilder(
                      animation: _position,
                      builder: (context, _) => Semantics(
                        label: CodelesslyLabelsScope.of(context).refresh,
                        child: widget.style == api.RefreshStyle.spinner
                            // iOS's control: the ticks alone (system gray),
                            // fading in as the pull opens room for them, then
                            // stepping round while it refreshes.
                            ? SizedBox.square(
                                key: const ValueKey('Codelessly pull to refresh'),
                                dimension: 44,
                                child: Center(
                                  child: Opacity(
                                    opacity: turning ? 1 : _ink,
                                    child: SpinnerView(
                                      diameter: 20,
                                      style: SpinnerStyle.ticks,
                                      turning: turning,
                                      color: widget.color ?? const Color(0xFF8E8E93),
                                    ),
                                  ),
                                ),
                              )
                            : Padding(
                          key: const ValueKey('Codelessly pull to refresh'),
                          padding: const EdgeInsets.all(4),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: widget.backgroundColor ?? tokens.raisedBackground,
                              border: Border.all(color: tokens.primaryBorder),
                              boxShadow: tokens.shadows('level2'),
                            ),
                            child: SizedBox.square(
                              dimension: 36,
                              child: Center(
                                child: SpinnerView(
                                  diameter: 16,
                                  color: turning ? color : color.withValues(alpha: color.a * _ink),
                                  value: turning ? null : _position.value * .75,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

