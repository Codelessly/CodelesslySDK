import 'dart:math' as math;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../codelessly_sdk.dart';
import '../functions/action_chain.dart';

/// [list] with the item at [from] moved so that it ends up at [to] (an index
/// in the new order, as `onReorderItem` gives it).
List<T> moveListItem<T>(List<T> list, int from, int to) {
  if (from < 0 || from >= list.length) return [...list];
  final List<T> result = [...list];
  final T item = result.removeAt(from);
  result.insert(to.clamp(0, result.length), item);
  return result;
}

/// The two lists after the item at [from] of [source] is moved to index [to]
/// of [target] (an index among the target's items before the move).
({List<T> source, List<T> target}) moveBetweenLists<T>(
  List<T> source,
  List<T> target,
  int from,
  int to,
) {
  if (from < 0 || from >= source.length) {
    return (source: [...source], target: [...target]);
  }
  final List<T> newSource = [...source];
  final T item = newSource.removeAt(from);
  final List<T> newTarget = [...target]..insert(to.clamp(0, target.length), item);
  return (source: newSource, target: newTarget);
}

/// An order value between [before] and [after] (the order values of the
/// moved item's new neighbours, null at an end), so only the moved document
/// is written: the midpoint, or one past the end.
double orderBetween(num? before, num? after) {
  if (before == null && after == null) return 0;
  if (before == null) return after!.toDouble() - 1;
  if (after == null) return before.toDouble() + 1;
  return (before + after) / 2;
}

/// The `${result}` of a reorder.
Map<String, Object?> reorderResult({
  required int from,
  required int to,
  required Object? item,
  required String fromList,
  required String toList,
}) => {
  'from': from,
  'to': to,
  'item': item,
  'fromList': fromList,
  'toList': toList,
};

/// Evaluates [condition] (a `${...}` binding or `${= ...}` formula) with
/// [item] and [index] as `${item}` and `${index}` and [result] as
/// `${result}`. Empty holds.
bool reorderConditionHolds(
  BuildContext context,
  String condition, {
  Object? item,
  int index = 0,
  Map<String, Object?>? result,
}) {
  final String text = condition.trim();
  if (text.isEmpty) return true;
  final ScopedValues base = ScopedValues.of(context);
  final ScopedValues scoped = ScopedValues.forItem(
    base,
    IndexedItem(index, item),
  );
  String evaluate() => PropertyValueDelegate.substituteVariables(
    text,
    scopedValues: scoped,
    nullSubstitutionMode: NullSubstitutionMode.emptyString,
  ).trim();
  final String value = result == null
      ? evaluate()
      : ActionChain.run(evaluate, result: result);
  return value == 'true' || value == '1';
}

/// Applies a reorder of [list]'s data on its own, as its [ReorderModel.apply]
/// says, then runs its `reorder` reactions (and [handleReactions]) with the
/// reorder's `${result}`. A drop [ReorderModel.canDropIf] refuses changes
/// nothing. Returns whether it was applied.
Future<bool> runListReorder(
  BuildContext context, {
  required BaseNode list,
  required ReorderModel? model,
  required List<Object?> items,
  required int from,
  required int to,
  String? listKey,
  List<Reaction> handleReactions = const [],
}) async {
  final Object? item = items.elementAtOrNull(from);
  final String key = listKey ?? list.id;
  final Map<String, Object?> result = reorderResult(
    from: from,
    to: to,
    item: item,
    fromList: key,
    toList: key,
  );
  if (model != null &&
      !reorderConditionHolds(
        context,
        model.canDropIf,
        item: item,
        index: from,
        result: result,
      )) {
    return false;
  }
  switch (model?.apply ?? ListApply.none) {
    case ListApply.none:
      break;
    case ListApply.variable:
      final Observable<VariableData>? variable = boundListVariable(
        context,
        list,
      );
      if (variable != null) {
        final List<Object?> current = [
          ...?variable.value.getValue().typedValue<List>(),
        ];
        variable.value = variable.value.copyWith(
          value: moveListItem(current, from, to),
        );
      }
    case ListApply.cloud:
      await _writeOrder(context, list, model!, items, from, to);
  }
  if (!context.mounted) return true;
  final List<Reaction> reactions = [
    if (list is ReactionMixin) ...(list as ReactionMixin).reactions,
    ...handleReactions,
  ];
  await FunctionsRepository.triggerAction(
    context,
    TriggerType.reorder,
    reactions: reactions,
    result: result,
  );
  return true;
}

/// Writes the moved document's order field between its new neighbours'.
Future<void> _writeOrder(
  BuildContext context,
  BaseNode list,
  ReorderModel model,
  List<Object?> items,
  int from,
  int to,
) async {
  final List<Object?> moved = moveListItem(items, from, to);
  final Object? item = moved.elementAtOrNull(to);
  final Object? id = item is Map ? item['id'] : null;
  if (id is! String) return;
  num? orderOf(Object? neighbour) => neighbour is Map
      ? (neighbour[model.orderField] as num?)
      : null;
  final double order = orderBetween(
    to > 0 ? orderOf(moved[to - 1]) : null,
    to < moved.length - 1 ? orderOf(moved[to + 1]) : null,
  );
  final String path = switch (list) {
    final ListViewNode node => node.collectionPath ?? '',
    final GridViewNode node => node.collectionPath ?? '',
    _ => '',
  };
  final CloudDatabase? database = context.read<Codelessly?>()?.cloudDatabase;
  await database?.updateDocument(
    path,
    documentId: id,
    value: {model.orderField: order},
  );
}

/// The proxy decoration of a dragged item, from [model].
Widget decorateReorderProxy(
  Widget child,
  Animation<double> animation,
  ReorderModel? model,
) {
  final double elevation = model?.proxyElevation ?? 6;
  final double scale = model?.proxyScale ?? 1;
  final double opacity = (model?.proxyOpacity ?? 1).clamp(0, 1);
  return AnimatedBuilder(
    animation: animation,
    child: child,
    builder: (context, child) {
      final double t = Curves.easeOut.transform(animation.value);
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

/// Marks the items of a reorderable list that may not be picked up, so a
/// reorder handle inside them stays still.
class ReorderLockScope extends InheritedWidget {
  /// Whether the item is locked.
  final bool locked;

  /// Creates a [ReorderLockScope].
  const ReorderLockScope({
    super.key,
    required this.locked,
    required super.child,
  });

  /// Whether the item around [context] is locked.
  static bool isLocked(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ReorderLockScope>()?.locked ??
      false;

  @override
  bool updateShouldNotify(ReorderLockScope oldWidget) =>
      oldWidget.locked != locked;
}

/// Lets a focused list item move with Alt (Option) and the arrow keys, and
/// gives screen readers "Move up" and "Move down" actions. Each move is
/// announced ("Moved to 3 of 12").
class KeyboardReorderItem extends StatelessWidget {
  /// The item's index.
  final int index;

  /// The number of items.
  final int count;

  /// Whether the item can move.
  final bool enabled;

  /// Whether the list is vertical (Up and Down) or horizontal (Left and
  /// Right).
  final bool vertical;

  /// Moves the item at `from` to `to`.
  final Future<bool> Function(int from, int to) onMove;

  /// The item.
  final Widget child;

  /// Creates a [KeyboardReorderItem].
  const KeyboardReorderItem({
    super.key,
    required this.index,
    required this.count,
    required this.enabled,
    required this.vertical,
    required this.onMove,
    required this.child,
  });

  Future<void> _move(BuildContext context, int delta) async {
    final int to = index + delta;
    if (!enabled || to < 0 || to >= count) return;
    final bool moved = await onMove(index, to);
    if (!moved || !context.mounted) return;
    SemanticsService.sendAnnouncement(
      View.of(context),
      'Moved to ${to + 1} of $count',
      Directionality.maybeOf(context) ?? TextDirection.ltr,
    );
  }

  @override
  Widget build(BuildContext context) {
    final LogicalKeyboardKey back = vertical
        ? LogicalKeyboardKey.arrowUp
        : LogicalKeyboardKey.arrowLeft;
    final LogicalKeyboardKey forward = vertical
        ? LogicalKeyboardKey.arrowDown
        : LogicalKeyboardKey.arrowRight;
    return Semantics(
      customSemanticsActions: enabled
          ? {
              if (index > 0)
                CustomSemanticsAction(
                  label: vertical ? 'Move up' : 'Move left',
                ): () => _move(context, -1),
              if (index < count - 1)
                CustomSemanticsAction(
                  label: vertical ? 'Move down' : 'Move right',
                ): () => _move(context, 1),
            }
          : null,
      child: Focus(
        canRequestFocus: enabled,
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
            return KeyEventResult.ignored;
          }
          if (!HardwareKeyboard.instance.isAltPressed) {
            return KeyEventResult.ignored;
          }
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

/// What is dragged from a list whose [ReorderModel.group] lets its items
/// move to other lists.
@immutable
class ReorderPayload {
  /// The group of the list it came from.
  final String group;

  /// The list node it came from.
  final BaseNode list;

  /// The [ReorderModel.listKey] of that list.
  final String listKey;

  /// Its index there.
  final int index;

  /// Its data.
  final Object? item;

  /// The items of the list it came from.
  final List<Object?> items;

  /// The context of the list it came from, to update that list's data.
  final BuildContext context;

  /// Creates a [ReorderPayload].
  const ReorderPayload({
    required this.group,
    required this.list,
    required this.listKey,
    required this.index,
    required this.item,
    required this.items,
    required this.context,
  });
}

/// Moves [payload]'s item into [target] at [to] (an index among the target's
/// [targetItems] before the move): updates both lists' data as the target's
/// [ReorderModel.apply] says, then runs the target's `reorder` reactions with
/// `${result.fromList}` and `${result.toList}`. A refused drop
/// ([ReorderModel.canDropIf]) changes nothing.
Future<bool> runCrossListMove(
  BuildContext context, {
  required ReorderPayload payload,
  required BaseNode target,
  required ReorderModel model,
  required String targetKey,
  required List<Object?> targetItems,
  required int to,
}) async {
  if (identical(payload.list, target) || payload.list.id == target.id) {
    // A move within the list: `to` counts the item itself.
    final int adjusted = to > payload.index ? to - 1 : to;
    return runListReorder(
      context,
      list: target,
      model: model,
      items: targetItems,
      from: payload.index,
      to: adjusted,
      listKey: targetKey,
    );
  }
  final Map<String, Object?> result = reorderResult(
    from: payload.index,
    to: to,
    item: payload.item,
    fromList: payload.listKey,
    toList: targetKey,
  );
  if (!reorderConditionHolds(
    context,
    model.canDropIf,
    item: payload.item,
    index: payload.index,
    result: result,
  )) {
    return false;
  }
  switch (model.apply) {
    case ListApply.none:
      break;
    case ListApply.variable:
      final Observable<VariableData>? source = payload.context.mounted
          ? boundListVariable(payload.context, payload.list)
          : null;
      final Observable<VariableData>? destination = boundListVariable(
        context,
        target,
      );
      if (source != null && destination != null) {
        final moved = moveBetweenLists(
          [...?source.value.getValue().typedValue<List>()],
          [...?destination.value.getValue().typedValue<List>()],
          payload.index,
          to,
        );
        if (identical(source, destination)) {
          // Two lists over one variable (filtered views of it): keep it.
        } else {
          source.value = source.value.copyWith(value: moved.source);
          destination.value = destination.value.copyWith(
            value: moved.target,
          );
        }
      }
    case ListApply.cloud:
      final Object? id = payload.item is Map
          ? (payload.item as Map)['id']
          : null;
      if (id is String) {
        num? orderOf(Object? item) =>
            item is Map ? item[model.orderField] as num? : null;
        final double order = orderBetween(
          to > 0 ? orderOf(targetItems.elementAtOrNull(to - 1)) : null,
          orderOf(targetItems.elementAtOrNull(to)),
        );
        final String path = switch (target) {
          final ListViewNode node => node.collectionPath ?? '',
          final GridViewNode node => node.collectionPath ?? '',
          _ => '',
        };
        await context.read<Codelessly?>()?.cloudDatabase?.updateDocument(
          path,
          documentId: id,
          value: {
            model.orderField: order,
            if (model.listField.trim().isNotEmpty) model.listField: targetKey,
          },
        );
      }
  }
  if (!context.mounted) return true;
  await FunctionsRepository.triggerAction(
    context,
    TriggerType.reorder,
    reactions: target is ReactionMixin
        ? (target as ReactionMixin).reactions
        : const [],
    result: result,
  );
  return true;
}

/// A list whose items can be dragged to a new place in it or into another
/// list of its [ReorderModel.group]: a column of a Kanban board.
///
/// Items are Flutter [Draggable]s (or long-press ones) carrying a
/// [ReorderPayload]; the list is a [DragTarget] that works out where the
/// drop lands from the pointer, opens a placeholder there, scrolls near its
/// edges, and moves the item with [runCrossListMove].
class GroupReorderList extends StatefulWidget {
  /// The list node.
  final ListViewNode node;

  /// The reorder settings.
  final ReorderModel model;

  /// The list's items.
  final List<Object?> items;

  /// The key of this list in results.
  final String listKey;

  /// Builds item [index].
  final IndexedWidgetBuilder itemBuilder;

  /// The extent each item takes along the scroll axis, when known; else
  /// items are measured.
  final double? itemExtent;

  /// Builds the placeholder node, for [ReorderPlaceholder.node].
  final WidgetBuilder? placeholderBuilder;

  /// The list's padding.
  final EdgeInsets? padding;

  /// Whether the list shrink-wraps.
  final bool shrinkWrap;

  /// Creates a [GroupReorderList].
  const GroupReorderList({
    super.key,
    required this.node,
    required this.model,
    required this.items,
    required this.listKey,
    required this.itemBuilder,
    this.itemExtent,
    this.placeholderBuilder,
    this.padding,
    this.shrinkWrap = false,
  });

  @override
  State<GroupReorderList> createState() => GroupReorderListState();
}

/// The state of a [GroupReorderList].
class GroupReorderListState extends State<GroupReorderList> {
  /// The list's scroll controller.
  final ScrollController scrollController = ScrollController();
  final Map<int, GlobalKey> _itemKeys = {};

  /// Where a drag over this list would land, if one is over it.
  int? dropIndex;

  /// The extent of the item being dragged over this list.
  double _draggedExtent = 0;

  /// The index of the item of this list being dragged, if any.
  int? _dragging;

  Axis get _axis => widget.node.scrollDirection.flutterAxis;

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  /// The index a drop at [global] lands at, among this list's items.
  int indexAt(Offset global) {
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null) return widget.items.length;
    final Offset local = box.globalToLocal(global);
    final double along = _axis == Axis.vertical ? local.dy : local.dx;
    final double offset =
        (scrollController.hasClients ? scrollController.offset : 0) +
        along -
        (_axis == Axis.vertical
            ? widget.padding?.top ?? 0
            : widget.padding?.left ?? 0);
    final double? extent = widget.itemExtent;
    if (extent != null && extent > 0) {
      return (offset / extent).round().clamp(0, widget.items.length);
    }
    // Measured items: the first whose middle is after the pointer.
    for (int i = 0; i < widget.items.length; i++) {
      final BuildContext? item = _itemKeys[i]?.currentContext;
      final RenderBox? itemBox = item?.findRenderObject() as RenderBox?;
      if (itemBox == null || !itemBox.attached) continue;
      final Offset topLeft = itemBox.localToGlobal(Offset.zero);
      final double middle = _axis == Axis.vertical
          ? topLeft.dy + itemBox.size.height / 2
          : topLeft.dx + itemBox.size.width / 2;
      if ((_axis == Axis.vertical ? global.dy : global.dx) < middle) return i;
    }
    return widget.items.length;
  }

  void _autoScroll(Offset global) {
    if (!widget.model.autoScroll || !scrollController.hasClients) return;
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final Offset local = box.globalToLocal(global);
    final double along = _axis == Axis.vertical ? local.dy : local.dx;
    final double length = _axis == Axis.vertical
        ? box.size.height
        : box.size.width;
    final double edge = widget.model.autoScrollEdge;
    final ScrollPosition position = scrollController.position;
    double delta = 0;
    if (along < edge) delta = -(edge - along) / 2;
    if (along > length - edge) delta = (along - (length - edge)) / 2;
    if (delta == 0) return;
    position.jumpTo(
      (position.pixels + delta).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      ),
    );
  }

  bool _accepts(ReorderPayload payload) =>
      widget.model.enabled && payload.group == widget.model.group;

  Widget _placeholder() {
    final double extent = _draggedExtent > 0
        ? _draggedExtent
        : (widget.itemExtent ?? 48);
    final Widget? node =
        widget.model.placeholder == ReorderPlaceholder.node
        ? widget.placeholderBuilder?.call(context)
        : null;
    return SizedBox(
      key: const ValueKey('reorder-placeholder'),
      width: _axis == Axis.horizontal ? extent : null,
      height: _axis == Axis.vertical ? extent : null,
      child: node,
    );
  }

  Widget _item(BuildContext context, int index) {
    final Object? value = widget.items[index];
    final GlobalKey key = _itemKeys.putIfAbsent(index, GlobalKey.new);
    final Widget item = KeyedSubtree(
      key: key,
      child: widget.itemBuilder(context, index),
    );
    final bool locked = !reorderConditionHolds(
      context,
      widget.model.canReorderIf,
      item: value,
      index: index,
    );
    if (locked || !widget.model.enabled) return item;
    final ReorderPayload payload = ReorderPayload(
      group: widget.model.group,
      list: widget.node,
      listKey: widget.listKey,
      index: index,
      item: value,
      items: widget.items,
      context: this.context,
    );
    Widget feedback() {
      final RenderBox? box =
          key.currentContext?.findRenderObject() as RenderBox?;
      final Size? size = box?.hasSize == true ? box!.size : null;
      return reprovideCodelessly(
        this.context,
        Material(
          type: MaterialType.transparency,
          child: SizedBox.fromSize(
            size: size,
            child: decorateReorderProxy(
              DraggedScope(child: widget.itemBuilder(this.context, index)),
              const AlwaysStoppedAnimation(1),
              widget.model,
            ),
          ),
        ),
      );
    }

    void started() {
      final RenderBox? box =
          key.currentContext?.findRenderObject() as RenderBox?;
      setState(() {
        _dragging = index;
        if (box != null && box.hasSize) {
          _draggedExtent = _axis == Axis.vertical
              ? box.size.height
              : box.size.width;
        }
      });
    }

    void ended() {
      if (mounted) setState(() => _dragging = null);
    }

    const Widget hidden = SizedBox.shrink();
    return switch (widget.model.start) {
      ReorderStart.press => Draggable<ReorderPayload>(
        data: payload,
        feedback: Builder(builder: (_) => feedback()),
        childWhenDragging: hidden,
        onDragStarted: started,
        onDragEnd: (_) => ended(),
        child: MouseRegion(cursor: SystemMouseCursors.grab, child: item),
      ),
      ReorderStart.longPress || ReorderStart.handle =>
        LongPressDraggable<ReorderPayload>(
          data: payload,
          feedback: Builder(builder: (_) => feedback()),
          childWhenDragging: hidden,
          onDragStarted: started,
          onDragEnd: (_) => ended(),
          child: item,
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return DragTarget<ReorderPayload>(
      onWillAcceptWithDetails: (details) => _accepts(details.data),
      onMove: (details) {
        if (!_accepts(details.data)) return;
        _autoScroll(details.offset);
        final int index = indexAt(details.offset);
        if (index != dropIndex) setState(() => dropIndex = index);
      },
      onLeave: (_) => setState(() => dropIndex = null),
      onAcceptWithDetails: (details) async {
        final int to = dropIndex ?? indexAt(details.offset);
        setState(() => dropIndex = null);
        await runCrossListMove(
          context,
          payload: details.data,
          target: widget.node,
          model: widget.model,
          targetKey: widget.listKey,
          targetItems: widget.items,
          to: to,
        );
      },
      builder: (context, candidates, rejected) {
        final int? slot = dropIndex;
        final int count = widget.items.length + (slot == null ? 0 : 1);
        return ListView.builder(
          controller: scrollController,
          scrollDirection: _axis,
          padding: widget.padding,
          shrinkWrap: widget.shrinkWrap,
          itemCount: count,
          itemBuilder: (context, i) {
            if (slot != null && i == slot) return _placeholder();
            final int index = slot != null && i > slot ? i - 1 : i;
            // The dragged item of this list collapses while away.
            if (index == _dragging && slot != null) {
              return const SizedBox.shrink();
            }
            return _item(context, index);
          },
        );
      },
    );
  }
}
