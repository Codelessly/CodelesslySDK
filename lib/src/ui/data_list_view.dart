import 'dart:math' as math;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../../codelessly_sdk.dart';
import 'swipe_actions_box.dart';

/// A section of a [DataListView]: consecutive items with the same key.
@immutable
class ListSection {
  /// The key the section's items share.
  final Object? key;

  /// The index of the section's first item.
  final int start;

  /// How many items it has.
  final int count;

  /// Creates a [ListSection].
  const ListSection(this.key, this.start, this.count);

  /// What a header node reads as `${item}`.
  Map<String, Object?> toItem(int index) => {
    'key': key,
    'count': count,
    'index': index,
    'start': start,
  };

  @override
  bool operator ==(Object other) =>
      other is ListSection &&
      other.key == key &&
      other.start == start &&
      other.count == count;

  @override
  int get hashCode => Object.hash(key, start, count);

  @override
  String toString() => 'ListSection($key, $start, $count)';
}

/// Groups [items] into sections of consecutive items with the same
/// [keyOf].
List<ListSection> groupIntoSections(
  List<Object?> items,
  Object? Function(int index, Object? item) keyOf,
) {
  final List<ListSection> sections = [];
  Object? current;
  int start = 0;
  for (int i = 0; i < items.length; i++) {
    final Object? key = keyOf(i, items[i]);
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
  if (items.isNotEmpty) {
    sections.add(ListSection(current, start, items.length - start));
  }
  return sections;
}

/// The scroll offset of the start of section [index] in a list whose items
/// are [itemExtent] long, with [separator] between items of a section and
/// headers [headerExtent] long; null when items aren't of one extent.
double? sectionOffset(
  List<ListSection> sections,
  int index, {
  required double? itemExtent,
  required double headerExtent,
  double separator = 0,
}) {
  if (itemExtent == null) return null;
  double offset = 0;
  for (int i = 0; i < index && i < sections.length; i++) {
    final int count = sections[i].count;
    offset +=
        headerExtent + count * itemExtent + math.max(0, count - 1) * separator;
  }
  return offset;
}

/// What a [DataListView] reads of its list or grid node.
@immutable
class DataListSpec {
  /// The node's pagination.
  final PaginationModel? pagination;

  /// The list's sections (lists only).
  final ListSectionsModel? sections;

  /// The list's swipe actions (lists only).
  final SwipeActionsModel? swipeActions;

  /// The scroll axis.
  final AxisC scrollDirection;

  /// Whether the scroll axis is reversed.
  final bool reverse;

  /// Whether the content is clipped to the node.
  final bool clipsContent;

  /// The node's reactions.
  final List<Reaction> reactions;

  /// The variable the node writes its status into.
  final VariableData? statusVariable;

  /// Pixels beyond the viewport to build items in.
  final double? cacheExtent;

  /// The cloud collection of the node's query.
  final String? collectionPath;

  /// The node's bindings.
  final Map<String, String> variables;

  const DataListSpec._({
    required this.pagination,
    required this.sections,
    required this.swipeActions,
    required this.scrollDirection,
    required this.reverse,
    required this.clipsContent,
    required this.reactions,
    required this.statusVariable,
    required this.cacheExtent,
    required this.collectionPath,
    required this.variables,
  });

  /// The spec of a list or grid [node].
  factory DataListSpec.of(BaseNode node) => switch (node) {
    final ListViewNode list => DataListSpec._(
      pagination: list.pagination,
      sections: list.sections,
      swipeActions: list.swipeActions,
      scrollDirection: list.scrollDirection,
      reverse: list.reverse,
      clipsContent: list.clipsContent,
      reactions: list.reactions,
      statusVariable: list.statusVariable,
      cacheExtent: list.properties.cacheExtent,
      collectionPath: list.collectionPath,
      variables: list.variables,
    ),
    final GridViewNode grid => DataListSpec._(
      pagination: grid.pagination,
      sections: null,
      swipeActions: null,
      scrollDirection: grid.scrollDirection,
      reverse: grid.reverse,
      clipsContent: grid.clipsContent,
      reactions: grid.reactions,
      statusVariable: grid.statusVariable,
      cacheExtent: grid.properties.cacheExtent,
      collectionPath: grid.collectionPath,
      variables: grid.variables,
    ),
    _ => throw ArgumentError('A data list is a list or a grid: $node'),
  };
}

/// Whether [node] needs a [DataListView]: it pages, groups into sections or
/// has swipe actions.
bool usesDataListView(ListViewNode node) =>
    node.pagination != null ||
    (node.sections?.isActive ?? false) ||
    (node.swipeActions?.hasActions ?? false);

/// Builds a list item template in a context that has its item.
typedef ListTemplateBuilder = Widget Function(BuildContext context);

/// A list of data items built lazily in slivers, for the list behaviors a
/// plain `ListView.builder` doesn't have:
///
/// * pages from a [PaginationController] (the list's [PaginationModel]):
///   a page at a time, or loading the next page when the list nears its
///   end, and in [PaginationMode.bidirectional] the page before when it
///   nears its start, put in front without moving what is on screen;
/// * loading, error-with-retry and end-of-list footers;
/// * pull to refresh;
/// * section headers that stay pinned, with an index bar to jump;
/// * swipe actions on the items, with undo.
class DataListView extends StatefulWidget {
  /// The list or grid node.
  final BaseNode node;

  /// Lays the items out in a grid instead of a list.
  final SliverGridDelegate? gridDelegate;

  /// The list's bound data, for a list without pagination or with a
  /// [PaginationSource.data] source.
  final List<Object?>? data;

  /// The source of a cloud or API pagination, made by the list.
  final PageFetcher? fetcher;

  /// Builds the item template.
  final ListTemplateBuilder buildTemplate;

  /// Builds another child of the list (a footer, a section header).
  final Widget Function(BuildContext context, String nodeId) buildNode;

  /// The extent every item takes along the scroll axis, when known.
  final double? itemExtent;

  /// The extent of a section header, along the scroll axis.
  final double headerExtent;

  /// Whether the list scrolls (it may only shrink-wrap in a scroll view).
  final bool shrinkWrap;

  /// The scroll physics.
  final ScrollPhysics? physics;

  /// The list's padding.
  final EdgeInsets? padding;

  /// Builds the separator between two items, if any.
  final IndexedWidgetBuilder? separatorBuilder;

  /// The extent of a separator.
  final double separatorExtent;

  /// Whether the list is shown in a preview with no data source.
  final bool preview;

  /// Creates a [DataListView].
  const DataListView({
    super.key,
    required this.node,
    required this.buildTemplate,
    required this.buildNode,
    this.data,
    this.fetcher,
    this.itemExtent,
    this.headerExtent = 32,
    this.shrinkWrap = false,
    this.physics,
    this.padding,
    this.separatorBuilder,
    this.separatorExtent = 0,
    this.preview = false,
    this.gridDelegate,
  });

  @override
  State<DataListView> createState() => DataListViewState();
}

/// The state of a [DataListView].
class DataListViewState extends State<DataListView> {
  /// The list's scroll controller.
  final ScrollController scrollController = ScrollController();

  /// The key of the sliver that anchors a list loading both ways.
  final Key _centerKey = UniqueKey();

  PaginationController? _controller;
  bool _loadScheduled = false;
  bool _previousScheduled = false;

  /// The keys of items swiped away, waiting for their Undo bar to go.
  final Set<Object?> _removed = {};

  /// The items whose swipe action waits for the Undo bar.
  final List<_PendingSwipe> _pending = [];

  List<ListSection>? _sections;
  List<Object?>? _sectionedItems;
  String? _sectionedBy;

  /// The controller of the list's pagination, if any.
  PaginationController? get controller => _controller;

  DataListSpec get _node => DataListSpec.of(widget.node);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _attach();
  }

  @override
  void didUpdateWidget(covariant DataListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _attach();
  }

  void _attach() {
    final PaginationModel? model = _node.pagination;
    if (model == null) {
      _controller = null;
      return;
    }
    final CodelesslyContext? codelessly = context.read<CodelesslyContext?>();
    final PaginationController controller =
        codelessly?.pagination.ensure(
          model,
          variables: codelessly.variables,
        ) ??
        (_controller ?? PaginationController(model: model));
    _controller = controller;
    switch (model.source) {
      case PaginationSource.data:
        controller.setLocalItems(widget.data ?? const [], notify: false);
        codelessly?.pagination.publish(model.name);
      case PaginationSource.cloud || PaginationSource.api:
        if (widget.fetcher != null) controller.fetcher = widget.fetcher;
    }
    if (!widget.preview || model.source == PaginationSource.data) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) controller.start();
      });
    }
  }

  @override
  void dispose() {
    for (final _PendingSwipe pending in _pending) {
      pending.commit();
    }
    scrollController.dispose();
    super.dispose();
  }

  /// The items to show, without the ones swiped away.
  List<Object?> get _items {
    final List<Object?> items =
        _controller?.items ?? widget.data ?? const <Object?>[];
    if (_removed.isEmpty) return items;
    return [
      for (final Object? item in items)
        if (!_removed.contains(_keyOf(item))) item,
    ];
  }

  Object? _keyOf(Object? item) {
    final String path = _node.pagination?.keyPath ?? 'id';
    return (path.isEmpty ? null : PaginationController.keyOf(item, path)) ??
        item;
  }

  /// Loads the next page after this frame, once.
  void _requestMore() {
    final PaginationController? controller = _controller;
    if (controller == null || _loadScheduled) return;
    if (!controller.model.autoPaginates) return;
    if (!controller.hasMore || controller.error != null) return;
    if (controller.isLoadingMore) return;
    _loadScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _loadScheduled = false;
      if (mounted) controller.loadMore();
    });
  }

  /// Loads the page before the first one shown after this frame, once.
  void _requestPrevious() {
    final PaginationController? controller = _controller;
    if (controller == null || _previousScheduled) return;
    if (controller.model.mode != PaginationMode.bidirectional) return;
    if (!controller.hasPrevious || controller.error != null) return;
    if (controller.isLoadingMore) return;
    _previousScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _previousScheduled = false;
      if (mounted) controller.loadPrevious();
    });
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    final double pixels = _node.pagination?.thresholdPixels ?? 0;
    if (pixels <= 0) return false;
    final ScrollMetrics metrics = notification.metrics;
    if (metrics.extentAfter <= pixels) _requestMore();
    if (metrics.extentBefore <= pixels) _requestPrevious();
    return false;
  }

  /// Called as item [index] of [count] is built: near the end, the next
  /// page loads.
  void _onItemBuilt(int index, int count) {
    final int threshold = math.max(0, _node.pagination?.thresholdItems ?? 0);
    if (index >= count - 1 - threshold) _requestMore();
  }

  Future<void> _refresh() async {
    await Future.wait([
      if (_controller != null) _controller!.refresh(),
      FunctionsRepository.triggerAction(
        context,
        TriggerType.refresh,
        reactions: _node.reactions,
      ),
    ]);
  }

  Widget _item(BuildContext context, int index, Object? item) {
    Widget child = IndexedItemProvider(
      key: ValueKey(('item', _keyOf(item))),
      item: IndexedItem(index, item),
      child: Builder(builder: widget.buildTemplate),
    );
    final SwipeActionsModel? swipe = _node.swipeActions;
    if (swipe != null && swipe.enabled && swipe.hasActions) {
      child = SwipeActionsBox(
        key: ValueKey(('swipe', _keyOf(item))),
        model: swipe,
        onAction: (action) => _onSwipe(action, index, item),
        child: child,
      );
    }
    return child;
  }

  void _onSwipe(SwipeActionModel action, int index, Object? item) {
    final SwipeActionsModel swipe = _node.swipeActions!;
    final Map<String, Object?> result = {
      'action': action.id,
      'label': action.label,
      'item': item,
      'index': index,
    };
    Future<void> run() async {
      if (!mounted) return;
      if (action.removes) await _applyRemoval(swipe.apply, item);
      if (!mounted) return;
      await FunctionsRepository.triggerAction(
        context,
        TriggerType.swipeAction,
        reactions: _node.reactions,
        result: result,
      );
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
        final Observable<VariableData>? variable = boundListVariable(
          context,
          widget.node,
        );
        if (variable == null) return;
        final List<Object?> list = [
          ...?(variable.value.getValue().typedValue<List>()),
        ];
        final Object? key = _keyOf(item);
        list.removeWhere((candidate) => _keyOf(candidate) == key);
        variable.value = variable.value.copyWith(value: list);
      case ListApply.cloud:
        final Object? id = item is Map ? item['id'] : null;
        if (id is! String) return;
        final CloudDatabase? database = context
            .read<Codelessly?>()
            ?.cloudDatabase;
        await database?.removeDocument(_node.collectionPath ?? '', id);
    }
  }

  List<ListSection>? _sectionsFor(List<Object?> items) {
    final ListSectionsModel? model = _node.sections;
    if (model == null || !model.isActive) return null;
    if (identical(items, _sectionedItems) && _sectionedBy == model.groupBy) {
      return _sections;
    }
    final String groupBy = model.groupBy.trim();
    final bool binding = groupBy.contains(r'${');
    final ScopedValues base = ScopedValues.of(context);
    _sections = groupIntoSections(items, (index, item) {
      if (!binding) return PaginationController.keyOf(item, groupBy);
      return PropertyValueDelegate.substituteVariables(
        groupBy,
        scopedValues: ScopedValues.forItem(base, IndexedItem(index, item)),
        nullSubstitutionMode: NullSubstitutionMode.emptyString,
      );
    });
    _sectionedItems = items;
    _sectionedBy = model.groupBy;
    return _sections;
  }

  /// Jumps to the start of section [index].
  void jumpToSection(int index) {
    final List<ListSection>? sections = _sections;
    if (sections == null || index < 0 || index >= sections.length) return;
    if (!scrollController.hasClients) return;
    final ScrollPosition position = scrollController.position;
    final double? exact = sectionOffset(
      sections,
      index,
      itemExtent: widget.itemExtent,
      headerExtent: widget.headerExtent,
      separator: widget.separatorBuilder == null ? 0 : widget.separatorExtent,
    );
    final int total = _items.length;
    final double offset =
        exact ??
        (total == 0
            ? 0
            : position.maxScrollExtent * sections[index].start / total);
    position.jumpTo(offset.clamp(0, position.maxScrollExtent));
  }

  SliverChildBuilderDelegate _delegate(
    List<Object?> items, {
    int start = 0,
    int? count,
    bool reversed = false,
    void Function(int index)? onBuilt,
  }) {
    final int length = count ?? items.length - start;
    final bool separated = widget.separatorBuilder != null;
    return SliverChildBuilderDelegate(
      (context, i) {
        if (separated && i.isOdd) {
          return widget.separatorBuilder!(context, i ~/ 2);
        }
        final int local = separated ? i ~/ 2 : i;
        final int position = reversed ? length - 1 - local : local;
        final int index = start + position;
        onBuilt?.call(index);
        return _item(context, index, items[index]);
      },
      childCount: separated ? math.max(0, length * 2 - 1) : length,
      findChildIndexCallback: null,
    );
  }

  Widget _sliverList(SliverChildBuilderDelegate delegate, {Key? key}) {
    final SliverGridDelegate? grid = widget.gridDelegate;
    if (grid != null) {
      return SliverGrid(key: key, delegate: delegate, gridDelegate: grid);
    }
    final double? extent = widget.itemExtent;
    if (extent != null && widget.separatorBuilder == null) {
      return SliverFixedExtentList(
        key: key,
        delegate: delegate,
        itemExtent: extent,
      );
    }
    if (extent != null) {
      final double gap = widget.separatorExtent;
      return SliverVariedExtentList(
        key: key,
        delegate: delegate,
        itemExtentBuilder: (index, _) => index.isEven ? extent : gap,
      );
    }
    return SliverList(key: key, delegate: delegate);
  }

  Widget? _footer(BuildContext context) {
    final PaginationController? controller = _controller;
    final PaginationModel? model = _node.pagination;
    if (controller == null || model == null) return null;
    if (controller.error != null) {
      final Widget content = model.errorNodeId.isNotEmpty
          ? widget.buildNode(context, model.errorNodeId)
          : _DefaultErrorFooter(error: controller.error);
      return GestureDetector(
        key: const ValueKey('pagination-error'),
        behavior: HitTestBehavior.opaque,
        onTap: controller.retry,
        child: content,
      );
    }
    if (controller.isLoading || controller.isLoadingMore) {
      if (!model.autoPaginates && !controller.isLoading) return null;
      return KeyedSubtree(
        key: const ValueKey('pagination-loading'),
        child: model.loadingNodeId.isNotEmpty
            ? widget.buildNode(context, model.loadingNodeId)
            : const _DefaultLoadingFooter(),
      );
    }
    if (model.autoPaginates &&
        !controller.hasMore &&
        model.endNodeId.isNotEmpty &&
        controller.items.isNotEmpty) {
      return KeyedSubtree(
        key: const ValueKey('pagination-end'),
        child: widget.buildNode(context, model.endNodeId),
      );
    }
    return null;
  }

  List<Widget> _sectionSlivers(
    BuildContext context,
    List<Object?> items,
    List<ListSection> sections,
  ) {
    final ListSectionsModel model = _node.sections!;
    final bool vertical = _node.scrollDirection == AxisC.vertical;
    return [
      for (int s = 0; s < sections.length; s++)
        SliverMainAxisGroup(
          key: ValueKey(('section', sections[s].key)),
          slivers: [
            if (vertical && model.sticky)
              SliverPersistentHeader(
                pinned: true,
                delegate: _HeaderDelegate(
                  extent: widget.headerExtent,
                  child: _header(sections[s], s),
                ),
              )
            else
              SliverToBoxAdapter(child: _header(sections[s], s)),
            _sliverList(
              _delegate(
                items,
                start: sections[s].start,
                count: sections[s].count,
                onBuilt: (index) => _onItemBuilt(index, items.length),
              ),
            ),
          ],
        ),
    ];
  }

  Widget _header(ListSection section, int index) => IndexedItemProvider(
    key: ValueKey(('header', section.key)),
    item: IndexedItem(index, section.toItem(index)),
    child: Builder(
      builder: (context) =>
          widget.buildNode(context, _node.sections!.headerNodeId),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final PaginationController? controller = _controller;
    if (controller == null) return _build(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        reportQueryStatus(context, _node.statusVariable, controller.status);
        return _build(context);
      },
    );
  }

  Widget _build(BuildContext context) {
    final List<Object?> items = _items;
    final PaginationModel? model = _node.pagination;
    final Axis axis = _node.scrollDirection.flutterAxis;
    final List<ListSection>? sections = _sectionsFor(items);
    final Widget? footer = _footer(context);
    final bool twoWay =
        model?.mode == PaginationMode.bidirectional && sections == null;

    final List<Widget> slivers;
    Key? center;
    if (twoWay) {
      // Items before the anchor page grow up (or left) from the anchor, so
      // putting a page in front moves nothing on screen.
      final anchored = _controller!.anchoredItems;
      final List<Object?> before = [
        for (final item in anchored.before)
          if (!_removed.contains(_keyOf(item))) item,
      ];
      final List<Object?> after = [
        for (final item in anchored.after)
          if (!_removed.contains(_keyOf(item))) item,
      ];
      center = _centerKey;
      slivers = [
        _sliverList(
          _delegate(
            [...before],
            reversed: true,
            onBuilt: (index) {
              if (index <= math.max(0, model!.thresholdItems)) {
                _requestPrevious();
              }
            },
          ),
        ),
        _sliverList(
          _delegate(
            after,
            onBuilt: (index) => _onItemBuilt(index, after.length),
          ),
          key: _centerKey,
        ),
      ];
    } else if (sections != null) {
      slivers = _sectionSlivers(context, items, sections);
    } else {
      slivers = [
        _sliverList(
          _delegate(
            items,
            onBuilt: (index) => _onItemBuilt(index, items.length),
          ),
        ),
      ];
    }

    final bool refreshable =
        model?.pullToRefresh == true ||
        _node.reactions.any((r) => r.trigger.type == TriggerType.refresh);

    Widget list = CustomScrollView(
      controller: scrollController,
      scrollDirection: axis,
      reverse: _node.reverse,
      shrinkWrap: widget.shrinkWrap,
      center: center,
      physics: refreshable
          ? const AlwaysScrollableScrollPhysics().applyTo(widget.physics)
          : widget.physics,
      scrollCacheExtent: _node.cacheExtent == null
          ? null
          : ScrollCacheExtent.pixels(_node.cacheExtent!),
      clipBehavior: _node.clipsContent ? Clip.hardEdge : Clip.none,
      slivers: [
        for (final Widget sliver in slivers)
          if (widget.padding == null)
            sliver
          else
            SliverPadding(
              padding: _paddingFor(sliver, slivers, axis),
              sliver: sliver,
            ),
        if (footer != null) SliverToBoxAdapter(child: footer),
      ],
    );

    if (model != null && model.thresholdPixels > 0) {
      list = NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: list,
      );
    }

    if (refreshable) {
      list = RefreshIndicator(
        onRefresh: _refresh,
        color: model?.refreshColor?.toFlutterColor(),
        backgroundColor: model?.refreshBackgroundColor?.toFlutterColor(),
        displacement: model?.refreshDisplacement ?? 40,
        child: list,
      );
    }

    if (sections != null && (_node.sections?.indexBar ?? false)) {
      list = Stack(
        children: [
          Positioned.fill(
            child: Scrollbar(
              controller: scrollController,
              interactive: true,
              child: list,
            ),
          ),
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            child: SectionIndexBar(
              keys: [for (final s in sections) s.key],
              onSelected: jumpToSection,
            ),
          ),
        ],
      );
    }

    if (_pending.isNotEmpty) {
      final _PendingSwipe pending = _pending.last;
      list = Stack(
        children: [
          Positioned.fill(child: list),
          Positioned(
            left: 8,
            right: 8,
            bottom: 8,
            child: UndoBar(
              message: _undoMessage(pending),
              onUndo: () => _undo(pending),
            ),
          ),
        ],
      );
    }
    return list;
  }

  String _undoMessage(_PendingSwipe pending) {
    final String template = _node.swipeActions?.undoMessage ?? '';
    return template.replaceAllMapped(
      RegExp(r'\$\{\s*result\.(\w+)\s*\}'),
      (match) => '${pending.result[match.group(1)] ?? ''}',
    );
  }

  /// The list's padding goes before the first sliver and after the last.
  EdgeInsets _paddingFor(Widget sliver, List<Widget> slivers, Axis axis) {
    final EdgeInsets padding = widget.padding!;
    final bool first = identical(sliver, slivers.first);
    final bool last = identical(sliver, slivers.last);
    if (axis == Axis.vertical) {
      return padding.copyWith(
        top: first ? padding.top : 0,
        bottom: last ? padding.bottom : 0,
      );
    }
    return padding.copyWith(
      left: first ? padding.left : 0,
      right: last ? padding.right : 0,
    );
  }
}

class _PendingSwipe {
  final Map<String, Object?> result;
  final VoidCallback commit;

  _PendingSwipe({required this.result, required this.commit});
}

/// The variable a list's data is bound to directly (`${name}`), if any.
Observable<VariableData>? boundListVariable(
  BuildContext context,
  BaseNode node,
) {
  final String path = node.variables['data']?.trim() ?? '';
  final RegExpMatch? match = RegExp(
    r'^\$\{\s*([A-Za-z_][A-Za-z0-9_]*)\s*\}$',
  ).firstMatch(path);
  if (match == null) return null;
  return context.read<CodelesslyContext?>()?.findVariableByName(
    match.group(1)!,
  );
}

class _HeaderDelegate extends SliverPersistentHeaderDelegate {
  final double extent;
  final Widget child;

  _HeaderDelegate({required this.extent, required this.child});

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => SizedBox.expand(child: child);

  @override
  bool shouldRebuild(covariant _HeaderDelegate oldDelegate) =>
      oldDelegate.extent != extent || oldDelegate.child != child;
}

/// The keys of a list's sections along its edge (A–Z): pressing or dragging
/// over one calls [onSelected] with its index.
class SectionIndexBar extends StatelessWidget {
  /// The keys, in order.
  final List<Object?> keys;

  /// Called with the index of the key under the pointer.
  final ValueChanged<int> onSelected;

  /// Creates a [SectionIndexBar].
  const SectionIndexBar({
    super.key,
    required this.keys,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (keys.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        void select(Offset local) {
          final double height = constraints.maxHeight;
          if (!height.isFinite || height <= 0) return;
          final int index = (local.dy / height * keys.length).floor().clamp(
            0,
            keys.length - 1,
          );
          onSelected(index);
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => select(details.localPosition),
          onVerticalDragStart: (details) => select(details.localPosition),
          onVerticalDragUpdate: (details) => select(details.localPosition),
          child: Semantics(
            label: 'Section index',
            child: SizedBox(
              width: 20,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final Object? key in keys)
                    Flexible(
                      child: FittedBox(
                        child: Text(
                          '${key ?? ''}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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
  /// What happened.
  final String message;

  /// Called when Undo is pressed.
  final VoidCallback onUndo;

  /// Creates an [UndoBar].
  const UndoBar({super.key, required this.message, required this.onUndo});

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFF323232),
    elevation: 6,
    borderRadius: BorderRadius.circular(8),
    child: Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
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
    child: Center(
      child: SizedBox.square(
        dimension: 24,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      ),
    ),
  );
}

class _DefaultErrorFooter extends StatelessWidget {
  final Object? error;

  const _DefaultErrorFooter({this.error});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text("Couldn't load more."),
        const SizedBox(height: 4),
        Text(
          'Tap to retry',
          style: TextStyle(color: Theme.of(context).colorScheme.primary),
        ),
      ],
    ),
  );
}
