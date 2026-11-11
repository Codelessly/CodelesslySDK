// A running list whose items are dragged to a new place, as
// islands: a ReorderableListView over the template's node
// boxes, or, for a list of a reorder group, a list whose items are
// Draggables into any list of the group (a Kanban board).
//
// A drop applies the move on its own as the list's `reorder.apply` says
// (the bound list variable, or the cloud documents' order field), then runs
// the list's `reorder` reactions (and its handle's) with `${result.from}`,
// `${result.to}`, `${result.item}`, `${result.fromList}`, `${result.toList}`.
import 'dart:math' as math;

import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_api/codelessly_api.dart'
    show CollectionScrollProps, CollectionSlots, ListApply, ListReorder, ListViewProps, Node, ReorderPlaceholder, ReorderStart, TriggerType;
import 'package:flutter/gestures.dart' show ImmediateMultiDragGestureRecognizer;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show CustomSemanticsAction, SemanticsService;
import 'package:flutter/services.dart';

import '../render/convert.dart';
import '../render/node_tree.dart';
import '../render/recipe.dart';
import '../runtime/actions/wiring.dart';
import '../runtime/expressions/bindings.dart';
import '../runtime/lists/reorder.dart';
import 'collections_list_runtime.dart';

/// The first node in [id]'s subtree whose drag reorders its row (a reorder
/// handle), or null.
String? reorderHandleOf(NodeBuilder b, String id) {
  final n = b.nodeOf(id);
  if (n == null) return null;
  if (n.behaviors.drag?.reorder ?? false) return id;
  for (final c in [...n.children, ...n.slots.values]) {
    final found = reorderHandleOf(b, c);
    if (found != null) return found;
  }
  return null;
}

/// Whether a running list [n] reorders its items: it has
/// data and lays it in a line, and its reorder is on (with a handle when it
/// starts from one), or, with no reorder setting, its item has a handle.
bool reordersItems(Node n, {required bool hasData, required String? handle}) {
  if (!hasData || n.prop(ListViewProps.wrap) || n.prop(ListViewProps.layout) != api.ListLayout.list) return false;
  final reorder = n.prop(ListViewProps.reorder);
  if (reorder == null) return handle != null;
  return reorder.enabled && (reorder.start != ReorderStart.handle || handle != null);
}

/// A running list that reorders, built as an island in [chain] (after its
/// viewport box).
void reorderRecipe(
  NodeBuilder b,
  Node n,
  List<RenderBox> chain, {
  required String itemId,
  required String? handle,
  double? itemMain,
  double? itemExtent,
  bool stretch = false,
  double gap = 0,
}) {
  final runtime = ListRuntime(b, n);
  final items = runtime.data ?? const [];
  final model = n.prop(ListViewProps.reorder);
  final listKey = model == null || model.listKey.trim().isEmpty ? n.id : runtime.text(model.listKey);
  if (model != null && model.group.trim().isNotEmpty) {
    chain.add(b.island(
      'reorder',
      (context) => GroupReorderList(
        runtime: runtime,
        model: model,
        items: [...items],
        listKey: listKey,
        itemId: itemId,
        itemMain: itemMain,
        itemExtent: itemExtent,
        stretch: stretch,
      ),
    ));
    return;
  }
  chain.add(b.island(
    'reorder',
    (context) => ReorderListView(
      runtime: runtime,
      model: model,
      items: [...items],
      listKey: model == null || model.listKey.trim().isEmpty ? null : listKey,
      itemId: itemId,
      handle: handle,
      itemMain: itemMain,
      stretch: stretch,
      gap: gap,
    ),
  ));
}

/// The item key of [item] at [index]: its `id` when no other item shares
/// it, else its index.
Object _rowKey(List<Object?> items, int index) {
  final item = items.elementAtOrNull(index);
  final id = item is Map ? item['id'] : null;
  if (id != null && items.where((o) => o is Map && o['id'] == id).length == 1) return ('id', id);
  return ('index', index);
}

/// The node box of row [index] of a reordering list, in its item's scope.
ProvidedItem _rowInstance(ListRuntime r, Object key) => ProvidedItem('row', r.b.instance, r.node.id, key);

Widget _rowNode(ListRuntime r, String itemId, List<Object?> items, int index) {
  final instance = _rowInstance(r, _rowKey(items, index));
  r.binder?.provideItem(r.tree.source, instance, index: index, item: items.elementAtOrNull(index));
  return NodeChild(tree: r.tree, id: itemId, instance: instance);
}

/// Marks the nodes of [itemId]'s subtree in row [instance] dragged (their
/// `dragged` state styles apply) or not.
void _setDragged(ListRuntime r, String itemId, Object instance, bool on) {
  void mark(String id) {
    r.tree.setState(id, api.WidgetState.dragged, on, instance: instance);
    final n = r.b.nodeOf(id);
    for (final c in [...?n?.children, ...?n?.slots.values]) {
      mark(c);
    }
  }

  mark(itemId);
}

/// Applies a reorder of [r]'s list on its own, as its [model]'s apply says,
/// then runs its `reorder` reactions (and its [handle]'s, in row [from])
/// with the reorder's `${result}`. A drop [ListReorder.canDropIf] refuses
/// changes nothing. Returns whether it was applied.
Future<bool> runListReorder(
  ListRuntime r, {
  required ListReorder? model,
  required List<Object?> items,
  required int from,
  required int to,
  String? listKey,
  String? handle,
  Object? handleInstance,
}) async {
  final item = items.elementAtOrNull(from);
  final key = listKey ?? r.node.id;
  final result = reorderResult(from: from, to: to, item: item, fromList: key, toList: key);
  if (model != null && !r.holds(model.canDropIf, item: item, index: from, result: result)) return false;
  switch (model?.apply ?? ListApply.none) {
    case ListApply.none:
      break;
    case ListApply.variable:
      final name = r.boundVariable;
      if (name != null) r.setVariable(name, moveListItem(r.listVariable(name), from, to));
    case ListApply.cloud:
      await _writeOrder(r, model!, items, from, to);
  }
  await r.fire(TriggerType.reorder.name, event: result);
  // Before the list's own reorder setting, only the handle had them.
  final handleBox = handle == null ? null : r.tree.boxOf(handle, instance: handleInstance);
  final reactions = r.tree.interactions;
  if (handleBox != null && reactions is TreeReactions) {
    await reactions.fireAndWait(handleBox, TriggerType.reorder.name, event: result);
  }
  return true;
}

/// Writes the moved document's order field between its new neighbors'.
Future<void> _writeOrder(ListRuntime r, ListReorder model, List<Object?> items, int from, int to) async {
  final moved = moveListItem(items, from, to);
  final item = moved.elementAtOrNull(to);
  final id = item is Map ? item['id'] : null;
  if (id is! String) return;
  num? orderOf(Object? neighbor) => neighbor is Map ? neighbor[model.orderField] as num? : null;
  final order = orderBetween(
    to > 0 ? orderOf(moved[to - 1]) : null,
    to < moved.length - 1 ? orderOf(moved[to + 1]) : null,
  );
  await r.database?.updateDocument(r.collectionPath, id, {model.orderField: order});
}

/// The proxy decoration of a dragged item, from [model].
Widget decorateReorderProxy(Widget child, Animation<double> animation, ListReorder? model) {
  final elevation = model?.proxyElevation ?? 6;
  final scale = model?.proxyScale ?? 1;
  final opacity = (model?.proxyOpacity ?? 1).clamp(0.0, 1.0);
  return AnimatedBuilder(
    animation: animation,
    child: child,
    builder: (context, child) {
      final t = Curves.easeOut.transform(animation.value);
      return Opacity(
        opacity: 1 - (1 - opacity) * t,
        child: Transform.scale(
          scale: 1 + (scale - 1) * t,
          child: PhysicalModel(
            color: const Color(0x00000000),
            shadowColor: const Color(0xFF000000),
            elevation: math.max(0, elevation) * t,
            child: child,
          ),
        ),
      );
    },
  );
}

/// A reorderable list (Flutter's `ReorderableListView`) of a list's items:
/// picked up by its handle, a long press or any press, as its reorder's
/// start says; with the keyboard (Alt and the arrows) when it allows.
class ReorderListView extends StatefulWidget {
  const ReorderListView({
    super.key,
    required this.runtime,
    required this.model,
    required this.items,
    required this.itemId,
    this.listKey,
    this.handle,
    this.itemMain,
    this.stretch = false,
    this.gap = 0,
  });

  final ListRuntime runtime;
  final ListReorder? model;
  final List<Object?> items;
  final String itemId;
  final String? listKey;

  /// The reorder handle node in the item template.
  final String? handle;
  final double? itemMain;
  final bool stretch;

  /// The space between items (a separator's).
  final double gap;

  @override
  State<ReorderListView> createState() => _ReorderListViewState();
}

class _ReorderListViewState extends State<ReorderListView> {
  ListRuntime get _r => widget.runtime;
  Node get _node => _r.node;
  Axis get _axis => _node.prop(CollectionScrollProps.scrollDirection) == api.Axis.vertical ? Axis.vertical : Axis.horizontal;

  Future<bool> _move(int from, int to) => runListReorder(
        _r,
        model: widget.model,
        items: widget.items,
        from: from,
        to: to,
        listKey: widget.listKey,
        handle: widget.handle,
        handleInstance: _rowInstance(_r, _rowKey(widget.items, from)),
      );

  ProvidedItem _proxyInstance(int index) =>
      ProvidedItem('dragged', _r.b.instance, _node.id, _rowKey(widget.items, index));

  Widget _proxy(int index) {
    final instance = _proxyInstance(index);
    _r.binder?.provideItem(_r.tree.source, instance, index: index, item: widget.items.elementAtOrNull(index));
    return MetaData(
      behavior: HitTestBehavior.opaque,
      child: ListItemBox(
        axis: _axis,
        main: widget.itemMain,
        stretch: widget.stretch,
        child: NodeChild(tree: _r.tree, id: widget.itemId, instance: instance),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final model = widget.model;
    final count = widget.items.length;
    final vertical = _axis == Axis.vertical;
    final scrollable = _node.prop(ListViewProps.scrollable);
    return LayoutBuilder(builder: (context, constraints) {
      final bounded = vertical ? constraints.hasBoundedHeight : constraints.hasBoundedWidth;
      return ReorderableListView.builder(
        shrinkWrap: !bounded || !scrollable,
        physics: scrollable ? null : const NeverScrollableScrollPhysics(),
        padding: _node.layout.padding.flutter,
        scrollDirection: _axis,
        buildDefaultDragHandles: false,
        itemCount: count,
        // Without auto-scroll the list barely moves near its edges.
        autoScrollerVelocityScalar: model?.autoScroll == false ? 0.001 : null,
        // The dragged row is drawn with boxes of its own (the row's stay
        // in the list), in its nodes' `dragged` state.
        proxyDecorator: (child, index, animation) => decorateReorderProxy(
            Material(type: MaterialType.transparency, child: _proxy(index)), animation, model),
        onReorderStart: (index) => _setDragged(_r, widget.itemId, _proxyInstance(index), true),
        onReorderEnd: (index) {
          for (var i = 0; i < count; i++) {
            _setDragged(_r, widget.itemId, _proxyInstance(i), false);
          }
        },
        onReorderItem: (from, to) => _move(from, to),
        itemBuilder: (context, index) {
          final value = widget.items.elementAtOrNull(index);
          final locked = model != null && !_r.holds(model.canReorderIf, item: value, index: index);
          Widget child = MetaData(
            behavior: HitTestBehavior.opaque,
            child: ListItemBox(
              axis: _axis,
              main: widget.itemMain,
              stretch: widget.stretch,
              child: _rowNode(_r, widget.itemId, widget.items, index),
            ),
          );
          switch (model?.start) {
            case ReorderStart.longPress:
              child = ReorderableDelayedDragStartListener(index: index, enabled: !locked, child: child);
            case ReorderStart.press:
              child = ReorderableDragStartListener(
                index: index,
                enabled: !locked,
                child: MouseRegion(cursor: locked ? MouseCursor.defer : SystemMouseCursors.grab, child: child),
              );
            case ReorderStart.handle || null:
              final handle = widget.handle;
              if (handle != null && !locked) {
                child = _HandleDragStart(
                  index: index,
                  handleBox: () => _r.tree.boxOf(handle, instance: _rowInstance(_r, _rowKey(widget.items, index))),
                  child: child,
                );
              }
          }
          if (model?.keyboard ?? false) {
            child = KeyboardReorderItem(
              index: index,
              count: count,
              enabled: !locked,
              vertical: vertical,
              onMove: _move,
              child: child,
            );
          }
          return Padding(
            key: ValueKey(('reorder', _rowKey(widget.items, index))),
            padding: index == count - 1
                ? EdgeInsets.zero
                : vertical
                    ? EdgeInsets.only(bottom: widget.gap)
                    : EdgeInsets.only(right: widget.gap),
            child: child,
          );
        },
      );
    });
  }
}

/// Starts dragging row [index] of the reorderable list around when a
/// pointer goes down on its handle node's box.
class _HandleDragStart extends StatelessWidget {
  const _HandleDragStart({required this.index, required this.handleBox, required this.child});

  final int index;
  final NodeBox? Function() handleBox;
  final Widget child;

  bool _onHandle(PointerDownEvent event) {
    final box = handleBox();
    final content = box?.contentBox ?? box;
    if (content == null || !content.attached || !content.hasSize) return false;
    final local = content.globalToLocal(event.position);
    return (Offset.zero & content.size).contains(local);
  }

  @override
  Widget build(BuildContext context) => Listener(
        onPointerDown: (event) {
          if (!_onHandle(event)) return;
          SliverReorderableList.maybeOf(context)?.startItemDragReorder(
            index: index,
            event: event,
            recognizer: ImmediateMultiDragGestureRecognizer(debugOwner: this)
              ..gestureSettings = MediaQuery.maybeGestureSettingsOf(context),
          );
        },
        child: MouseRegion(cursor: SystemMouseCursors.grab, child: child),
      );
}

/// Lets a focused list item move with Alt (Option) and the arrow keys, and
/// gives screen readers "Move up" and "Move down" actions. Each move is
/// announced ("Moved to 3 of 12").
class KeyboardReorderItem extends StatelessWidget {
  const KeyboardReorderItem({
    super.key,
    required this.index,
    required this.count,
    required this.enabled,
    required this.vertical,
    required this.onMove,
    required this.child,
  });

  final int index, count;
  final bool enabled, vertical;
  final Future<bool> Function(int from, int to) onMove;
  final Widget child;

  Future<void> _move(BuildContext context, int delta) async {
    final to = index + delta;
    if (!enabled || to < 0 || to >= count) return;
    final moved = await onMove(index, to);
    if (!moved || !context.mounted) return;
    SemanticsService.sendAnnouncement(
      View.of(context),
      'Moved to ${to + 1} of $count',
      Directionality.maybeOf(context) ?? TextDirection.ltr,
    );
  }

  @override
  Widget build(BuildContext context) {
    final back = vertical ? LogicalKeyboardKey.arrowUp : LogicalKeyboardKey.arrowLeft;
    final forward = vertical ? LogicalKeyboardKey.arrowDown : LogicalKeyboardKey.arrowRight;
    return Semantics(
      customSemanticsActions: enabled
          ? {
              if (index > 0) CustomSemanticsAction(label: vertical ? 'Move up' : 'Move left'): () => _move(context, -1),
              if (index < count - 1)
                CustomSemanticsAction(label: vertical ? 'Move down' : 'Move right'): () => _move(context, 1),
            }
          : null,
      child: Focus(
        canRequestFocus: enabled,
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
          if (!HardwareKeyboard.instance.isAltPressed) return KeyEventResult.ignored;
          if (event.logicalKey == back) {
            _move(context, -1);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == forward) {
            _move(context, 1);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: child,
      ),
    );
  }
}

/// What is dragged from a list of a reorder group.
@immutable
class ReorderPayload {
  const ReorderPayload({
    required this.group,
    required this.list,
    required this.listKey,
    required this.index,
    required this.item,
    required this.items,
  });

  final String group;

  /// The list it came from.
  final ListRuntime list;
  final String listKey;
  final int index;
  final Object? item;
  final List<Object?> items;
}

/// Moves [payload]'s item into [target] at [to] (an index among the
/// target's [targetItems] before the move): updates both lists' data as the
/// target's apply says, then runs the target's `reorder` reactions. A
/// refused drop ([ListReorder.canDropIf]) changes nothing.
Future<bool> runCrossListMove(
  ListRuntime target, {
  required ReorderPayload payload,
  required ListReorder model,
  required String targetKey,
  required List<Object?> targetItems,
  required int to,
}) async {
  if (payload.list.node.id == target.node.id && payload.list.b.instance == target.b.instance) {
    // A move within the list: `to` counts the item itself.
    final adjusted = to > payload.index ? to - 1 : to;
    return runListReorder(target,
        model: model, items: targetItems, from: payload.index, to: adjusted, listKey: targetKey);
  }
  final result =
      reorderResult(from: payload.index, to: to, item: payload.item, fromList: payload.listKey, toList: targetKey);
  if (!target.holds(model.canDropIf, item: payload.item, index: payload.index, result: result)) return false;
  switch (model.apply) {
    case ListApply.none:
      break;
    case ListApply.variable:
      final source = payload.list.boundVariable, destination = target.boundVariable;
      if (source != null && destination != null && source != destination) {
        final moved = moveBetweenLists(
            payload.list.listVariable(source), target.listVariable(destination), payload.index, to);
        payload.list.setVariable(source, moved.source);
        target.setVariable(destination, moved.target);
      }
    // Two lists over one variable (filtered views of it): keep it.
    case ListApply.cloud:
      final id = payload.item is Map ? (payload.item as Map)['id'] : null;
      if (id is String) {
        num? orderOf(Object? item) => item is Map ? item[model.orderField] as num? : null;
        final order = orderBetween(
          to > 0 ? orderOf(targetItems.elementAtOrNull(to - 1)) : null,
          orderOf(targetItems.elementAtOrNull(to)),
        );
        await target.database?.updateDocument(target.collectionPath, id, {
          model.orderField: order,
          if (model.listField.trim().isNotEmpty) model.listField: targetKey,
        });
      }
  }
  await target.fire(TriggerType.reorder.name, event: result);
  return true;
}

/// A list whose items can be dragged to a new place in it or into another
/// list of its reorder group: a column of a Kanban board. Items are
/// Draggables carrying a [ReorderPayload]; the list is a DragTarget that
/// works out where the drop lands, opens a placeholder there, scrolls near
/// its edges, and moves the item with [runCrossListMove].
class GroupReorderList extends StatefulWidget {
  const GroupReorderList({
    super.key,
    required this.runtime,
    required this.model,
    required this.items,
    required this.listKey,
    required this.itemId,
    this.itemMain,
    this.itemExtent,
    this.stretch = false,
  });

  final ListRuntime runtime;
  final ListReorder model;
  final List<Object?> items;
  final String listKey;
  final String itemId;
  final double? itemMain;

  /// The extent each item takes along the list, when known; else items
  /// are measured.
  final double? itemExtent;
  final bool stretch;

  @override
  State<GroupReorderList> createState() => GroupReorderListState();
}

class GroupReorderListState extends State<GroupReorderList> {
  final ScrollController scrollController = ScrollController();
  final Map<int, GlobalKey> _itemKeys = {};

  /// Where a drag over this list would land, if one is over it.
  int? dropIndex;

  /// The extent of the item being dragged over this list.
  double _draggedExtent = 0;

  /// The index of the item of this list being dragged, if any.
  int? _dragging;

  ListRuntime get _r => widget.runtime;
  Axis get _axis =>
      _r.node.prop(CollectionScrollProps.scrollDirection) == api.Axis.vertical ? Axis.vertical : Axis.horizontal;
  EdgeInsets get _padding => _r.node.layout.padding.flutter;

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  /// The index a drop at [global] lands at, among this list's items.
  int indexAt(Offset global) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return widget.items.length;
    final local = box.globalToLocal(global);
    final along = _axis == Axis.vertical ? local.dy : local.dx;
    final offset = (scrollController.hasClients ? scrollController.offset : 0) +
        along -
        (_axis == Axis.vertical ? _padding.top : _padding.left);
    final extent = widget.itemExtent;
    if (extent != null && extent > 0) return (offset / extent).round().clamp(0, widget.items.length);
    // Measured items: the first whose middle is after the pointer.
    for (var i = 0; i < widget.items.length; i++) {
      final itemBox = _itemKeys[i]?.currentContext?.findRenderObject() as RenderBox?;
      if (itemBox == null || !itemBox.attached) continue;
      final topLeft = itemBox.localToGlobal(Offset.zero);
      final middle =
          _axis == Axis.vertical ? topLeft.dy + itemBox.size.height / 2 : topLeft.dx + itemBox.size.width / 2;
      if ((_axis == Axis.vertical ? global.dy : global.dx) < middle) return i;
    }
    return widget.items.length;
  }

  void _autoScroll(Offset global) {
    if (!widget.model.autoScroll || !scrollController.hasClients) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(global);
    final along = _axis == Axis.vertical ? local.dy : local.dx;
    final length = _axis == Axis.vertical ? box.size.height : box.size.width;
    final edge = widget.model.autoScrollEdge;
    final position = scrollController.position;
    var delta = 0.0;
    if (along < edge) delta = -(edge - along) / 2;
    if (along > length - edge) delta = (along - (length - edge)) / 2;
    if (delta == 0) return;
    position.jumpTo((position.pixels + delta).clamp(position.minScrollExtent, position.maxScrollExtent));
  }

  bool _accepts(ReorderPayload payload) => widget.model.enabled && payload.group == widget.model.group;

  Widget _placeholder() {
    final extent = _draggedExtent > 0 ? _draggedExtent : (widget.itemExtent ?? 48);
    final slot = _r.node.slots[CollectionSlots.reorderPlaceholder];
    final node = widget.model.placeholder == ReorderPlaceholder.node && slot != null && _r.b.nodeOf(slot) != null
        ? NodeChild(tree: _r.tree, id: slot, instance: _r.b.instance)
        : null;
    return SizedBox(
      key: const ValueKey('reorder-placeholder'),
      width: _axis == Axis.horizontal ? extent : null,
      height: _axis == Axis.vertical ? extent : null,
      child: node,
    );
  }

  Widget _row(int index, {String tag = 'row'}) {
    Widget node = _rowNode(_r, widget.itemId, widget.items, index);
    if (tag != 'row') {
      // The feedback has boxes of its own: the row's stay in the list.
      final instance = ProvidedItem(tag, _r.b.instance, _r.node.id, _rowKey(widget.items, index));
      _r.binder?.provideItem(_r.tree.source, instance, index: index, item: widget.items.elementAtOrNull(index));
      node = NodeChild(tree: _r.tree, id: widget.itemId, instance: instance);
    }
    return MetaData(
      behavior: HitTestBehavior.opaque,
      child: ListItemBox(axis: _axis, main: widget.itemMain, stretch: widget.stretch, child: node),
    );
  }

  Widget _item(BuildContext context, int index) {
    final value = widget.items[index];
    final key = _itemKeys.putIfAbsent(index, GlobalKey.new);
    final item = KeyedSubtree(key: key, child: _row(index));
    final locked = !_r.holds(widget.model.canReorderIf, item: value, index: index);
    if (locked || !widget.model.enabled) return item;
    final payload = ReorderPayload(
      group: widget.model.group,
      list: _r,
      listKey: widget.listKey,
      index: index,
      item: value,
      items: widget.items,
    );
    final instance = ProvidedItem('dragged', _r.b.instance, _r.node.id, _rowKey(widget.items, index));
    Size? size;
    Widget feedback() => Material(
          type: MaterialType.transparency,
          child: SizedBox.fromSize(
            size: size,
            child: decorateReorderProxy(_row(index, tag: 'dragged'), const AlwaysStoppedAnimation(1), widget.model),
          ),
        );

    void started() {
      _setDragged(_r, widget.itemId, instance, true);
      setState(() {
        _dragging = index;
        if (size != null) _draggedExtent = _axis == Axis.vertical ? size!.height : size!.width;
      });
    }

    void ended() {
      _setDragged(_r, widget.itemId, instance, false);
      if (mounted) setState(() => _dragging = null);
    }

    void measure() {
      final box = key.currentContext?.findRenderObject() as RenderBox?;
      size = box != null && box.hasSize ? box.size : null;
    }

    const hidden = SizedBox.shrink();
    return Listener(
      onPointerDown: (_) => measure(),
      child: switch (widget.model.start) {
        ReorderStart.press => Draggable<ReorderPayload>(
            data: payload,
            feedback: Builder(builder: (_) => feedback()),
            childWhenDragging: hidden,
            onDragStarted: started,
            onDragEnd: (_) => ended(),
            child: MouseRegion(cursor: SystemMouseCursors.grab, child: item),
          ),
        ReorderStart.longPress || ReorderStart.handle => LongPressDraggable<ReorderPayload>(
            data: payload,
            feedback: Builder(builder: (_) => feedback()),
            childWhenDragging: hidden,
            onDragStarted: started,
            onDragEnd: (_) => ended(),
            child: item,
          ),
      },
    );
  }

  @override
  Widget build(BuildContext context) => DragTarget<ReorderPayload>(
        onWillAcceptWithDetails: (details) => _accepts(details.data),
        onMove: (details) {
          if (!_accepts(details.data)) return;
          _autoScroll(details.offset);
          final index = indexAt(details.offset);
          if (index != dropIndex) setState(() => dropIndex = index);
        },
        onLeave: (_) => setState(() => dropIndex = null),
        onAcceptWithDetails: (details) async {
          final to = dropIndex ?? indexAt(details.offset);
          setState(() => dropIndex = null);
          await runCrossListMove(
            _r,
            payload: details.data,
            model: widget.model,
            targetKey: widget.listKey,
            targetItems: widget.items,
            to: to,
          );
        },
        builder: (context, candidates, rejected) {
          final slot = dropIndex;
          final count = widget.items.length + (slot == null ? 0 : 1);
          return LayoutBuilder(builder: (context, constraints) {
            final bounded = _axis == Axis.vertical ? constraints.hasBoundedHeight : constraints.hasBoundedWidth;
            return ListView.builder(
              controller: scrollController,
              scrollDirection: _axis,
              padding: _padding,
              shrinkWrap: !bounded,
              itemCount: count,
              itemBuilder: (context, i) {
                if (slot != null && i == slot) return _placeholder();
                final index = slot != null && i > slot ? i - 1 : i;
                // The dragged item of this list collapses while away.
                if (index == _dragging && slot != null) return const SizedBox.shrink();
                return _item(context, index);
              },
            );
          });
        },
      );
}
