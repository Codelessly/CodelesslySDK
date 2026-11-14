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
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderAbstractViewport, ScrollCacheExtent;
import 'package:flutter/scheduler.dart';

import '../render/convert.dart';
import '../render/recipe.dart';
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

class DataListViewState extends State<DataListView> {
  final ScrollController scrollController = ScrollController();

  // --- items: the current index and snapping -------------------------------------

  /// The items built now, by index.
  final Map<int, BuildContext> _built = {};

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
    _m;
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
    _atEnd = p.pixels >= p.maxScrollExtent - 8;
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
    Widget child = _IndexedItem(index: index, list: this, child: _node$('row', widget.itemId, key, index, item));
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
        offered: (action) => _r.holds(action.when, item: item, index: index),
        onAction: (action) => _onSwipe(action, index, item),
        textDefault: _node.behaviors.defaultTextStyle,
        child: child,
      );
    }
    return child;
  }

  void _onSwipe(SwipeAction action, int index, Object? item) => _m.onSwipe(action, index, item);
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
    } else if (sticky && sections == null) {
      // Items put before the anchor grow up from it.
      var at = items.indexWhere((item) => _keyOf(item) == _anchor);
      if (at < 0) {
        at = 0;
        _anchor = items.isEmpty ? null : _keyOf(items.first);
      }
      center = _centerKey;
      slivers = [
        _sliverList(_delegate(items, count: at, reversed: true)),
        _sliverList(_delegate(items, start: at, onBuilt: (index) => _onItemBuilt(index, items.length)), key: _centerKey),
      ];
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
        return CustomScrollView(
          controller: scrollController,
          scrollDirection: axis,
          reverse: _node.prop(CollectionScrollProps.reverse),
          shrinkWrap: !bounded || widget.hugMain,
          center: center,
          physics: _withSnapping(refreshable ? const AlwaysScrollableScrollPhysics().applyTo(widget.physics) : widget.physics),
          scrollCacheExtent: cache == null ? null : ScrollCacheExtent.pixels(cache),
          clipBehavior: clip(_node.prop(CollectionScrollProps.clipBehavior)),
          slivers: [
            for (final sliver in all)
              if (padding == EdgeInsets.zero)
                sliver
              else
                SliverPadding(padding: _paddingFor(padding, sliver, all, axis), sliver: sliver),
          ],
        );
      },
    );

    if (model != null && model.thresholdPixels > 0) {
      list = NotificationListener<ScrollNotification>(onNotification: _onScroll, child: list);
    }
    list = NotificationListener<ScrollNotification>(onNotification: _onOwnScroll, child: list);

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
      list = Stack(
        children: [
          Positioned.fill(child: list),
          Positioned(
            left: 8,
            right: 8,
            bottom: 8,
            child: UndoBar(message: _m.undoMessage(pending), onUndo: () => _undo(pending)),
          ),
        ],
      );
    }
    return list;
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
                      style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w700, color: Colors.white)
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

/// An item of a [DataListView], known to the list by its index while built.
class _IndexedItem extends StatefulWidget {
  const _IndexedItem({required this.index, required this.list, required this.child});
  final int index;
  final DataListViewState list;
  final Widget child;

  @override
  State<_IndexedItem> createState() => _IndexedItemState();
}

class _IndexedItemState extends State<_IndexedItem> {
  @override
  void initState() {
    super.initState();
    widget.list._built[widget.index] = context;
  }

  @override
  void didUpdateWidget(covariant _IndexedItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index && identical(widget.list._built[oldWidget.index], context)) {
      widget.list._built.remove(oldWidget.index);
    }
    widget.list._built[widget.index] = context;
  }

  @override
  void dispose() {
    if (identical(widget.list._built[widget.index], context)) widget.list._built.remove(widget.index);
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
