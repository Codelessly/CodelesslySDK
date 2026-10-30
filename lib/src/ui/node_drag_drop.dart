import 'dart:ui' as ui;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'node_play.dart';

/// What a draggable node carries while dragged.
class NodeDragPayload {
  /// Creates a [NodeDragPayload].
  NodeDragPayload({
    required this.data,
    required this.group,
    required this.nodeId,
    required this.flightKey,
  });

  /// The value drop targets see as `${drop.data}`.
  final Object? data;

  /// The draggable's [DraggableModel.group].
  final String group;

  /// The id of the dragged node.
  final String nodeId;

  /// The dragged node's flight key, so a drop can fly into place.
  final String flightKey;

  /// Set by a drop target whose accept condition failed: the drag counts as
  /// canceled and the node springs back.
  bool rejected = false;
}

/// Makes [child] (a node's widget) draggable as [DraggableModel] describes.
///
/// The copy that follows the pointer is a snapshot of [child], so it looks
/// exactly like the node without rebuilding it outside its screen. Calls
/// [onEvent] with `dragStart`, `dragCompleted` or `dragCanceled` and the
/// dragged [data].
class NodeDraggable extends StatefulWidget {
  /// Creates a [NodeDraggable].
  const NodeDraggable({
    super.key,
    required this.nodeId,
    required this.model,
    required this.data,
    required this.enabled,
    required this.flightKey,
    required this.onEvent,
    required this.child,
  });

  /// The node's id.
  final String nodeId;

  /// The node's drag settings.
  final DraggableModel model;

  /// What it carries, resolved from `draggable.data` or [model].
  final Object? data;

  /// Whether it can be dragged now.
  final bool enabled;

  /// The node's flight key.
  final String flightKey;

  /// Runs the node's reactions for a drag event.
  final void Function(TriggerType type, Object? data) onEvent;

  /// The node's widget.
  final Widget child;

  @override
  State<NodeDraggable> createState() => _NodeDraggableState();
}

class _NodeDraggableState extends State<NodeDraggable>
    with SingleTickerProviderStateMixin {
  final GlobalKey _boundary = GlobalKey();
  final ValueNotifier<ui.Image?> _snapshot = ValueNotifier(null);
  late final AnimationController _return = AnimationController.unbounded(
    vsync: this,
    value: 1,
  )..addListener(() => setState(() {}));
  Offset _returnFrom = Offset.zero;
  Size _size = Size.zero;
  NodeDragPayload? _payload;

  /// Whether a drag is under way: the payload the drag carries must stay
  /// the one [_ended] reads, whatever rebuilds meanwhile.
  bool _dragging = false;

  void _capture() {
    final RenderObject? box = _boundary.currentContext?.findRenderObject();
    if (box is! RenderRepaintBoundary || !box.hasSize) return;
    _size = box.size;
    try {
      final double ratio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
      _snapshot.value?.dispose();
      _snapshot.value = box.toImageSync(pixelRatio: ratio);
    } catch (_) {
      // No snapshot (a renderer without toImageSync): the feedback shows
      // an outline of the node instead.
      _snapshot.value = null;
    }
  }

  void _started() {
    _dragging = true;
    _return
      ..stop()
      ..value = 1;
    _capture();
    widget.onEvent(TriggerType.dragStart, widget.data);
  }

  void _ended(DraggableDetails details) {
    _dragging = false;
    final NodeDragPayload? payload = _payload;
    final bool accepted = details.wasAccepted && !(payload?.rejected ?? false);
    if (accepted) {
      // Where the lifted copy was let go, so the node that shows the drop
      // flies in from there.
      final DraggableModel m = widget.model;
      final Rect rect = Rect.fromCenter(
        center: details.offset + _size.center(Offset.zero),
        width: _size.width * m.feedbackScale,
        height: _size.height * m.feedbackScale,
      );
      FlightRegistry.recordDrop(widget.flightKey, rect);
      widget.onEvent(TriggerType.dragCompleted, widget.data);
    } else {
      // The node's own box isn't mounted while the drag ghost shows; this
      // widget's box is where it comes back to.
      final RenderObject? box = context.findRenderObject();
      if (widget.model.returnSpring && box is RenderBox && box.attached) {
        _returnFrom = details.offset - box.localToGlobal(Offset.zero);
        _return
          ..value = 0
          ..animateWith(
            SpringSimulation(
              SpringDescription(
                mass: 1,
                stiffness: widget.model.springStiffness,
                damping: widget.model.springDamping,
              ),
              0,
              1,
              0,
            ),
          );
      }
      widget.onEvent(TriggerType.dragCanceled, widget.data);
    }
  }

  @override
  void dispose() {
    _return.dispose();
    _snapshot.value?.dispose();
    _snapshot.dispose();
    super.dispose();
  }

  Widget _feedback() {
    final DraggableModel m = widget.model;
    return ValueListenableBuilder<ui.Image?>(
      valueListenable: _snapshot,
      builder: (context, image, _) {
        Widget face = SizedBox.fromSize(
          size: _size,
          child: image == null
              ? const DecoratedBox(
                  decoration: BoxDecoration(color: Color(0x332D2A5A)),
                )
              : RawImage(image: image, fit: BoxFit.fill),
        );
        if (m.feedbackShadow) {
          face = DecoratedBox(
            decoration: const BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Color(0x40000000),
                  blurRadius: 22,
                  offset: Offset(0, 14),
                ),
              ],
            ),
            child: face,
          );
        }
        return IgnorePointer(
          child: Opacity(
            opacity: m.feedbackOpacity.clamp(0, 1),
            child: Transform.rotate(
              angle: m.feedbackRotation * 3.141592653589793 / 180,
              child: Transform.scale(scale: m.feedbackScale, child: face),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget child = RepaintBoundary(key: _boundary, child: widget.child);
    if (_return.value != 1) {
      child = Transform.translate(
        offset: _returnFrom * (1 - _return.value),
        child: child,
      );
    }
    if (!widget.enabled || Overlay.maybeOf(context) == null) return child;

    final DraggableModel m = widget.model;
    final Widget whileDragging = FlightSuppress(
      child: switch (m.whileDragging) {
        DragLeaveBehavior.keep => widget.child,
        DragLeaveBehavior.ghost => Opacity(
          opacity: m.ghostOpacity.clamp(0, 1),
          child: widget.child,
        ),
        DragLeaveBehavior.hidden => Opacity(opacity: 0, child: widget.child),
      },
    );
    if (!_dragging || _payload == null) {
      _payload = NodeDragPayload(
        data: widget.data,
        group: m.group,
        nodeId: widget.nodeId,
        flightKey: widget.flightKey,
      );
    }
    final NodeDragPayload payload = _payload!;
    final Axis? axis = switch (m.axis) {
      DragAxisLock.free => null,
      DragAxisLock.horizontal => Axis.horizontal,
      DragAxisLock.vertical => Axis.vertical,
    };
    if (m.longPressMs > 0) {
      return LongPressDraggable<NodeDragPayload>(
        data: payload,
        axis: axis,
        delay: Duration(milliseconds: m.longPressMs),
        maxSimultaneousDrags: 1,
        feedback: _feedback(),
        childWhenDragging: whileDragging,
        onDragStarted: _started,
        onDragEnd: _ended,
        child: child,
      );
    }
    return Draggable<NodeDragPayload>(
      data: payload,
      axis: axis,
      maxSimultaneousDrags: 1,
      feedback: _feedback(),
      childWhenDragging: whileDragging,
      onDragStarted: _started,
      onDragEnd: _ended,
      child: MouseRegion(cursor: SystemMouseCursors.grab, child: child),
    );
  }
}

/// Holds what a drop target knows about the drag over it, for [DropScope].
class DropScopeData {
  /// The current state: `hovering`, `data`, `accepts`, and after a drop
  /// `dx`, `dy`.
  Map<String, dynamic> value = DropScope.idle;
}

/// Gives the nodes inside a drop target `${drop}` (see [DropTargetModel]).
class DropScope extends InheritedWidget {
  /// Creates a [DropScope].
  const DropScope({
    super.key,
    required this.data,
    required this.version,
    required super.child,
  });

  /// `${drop}` when nothing is dragged over.
  static const Map<String, dynamic> idle = {
    'hovering': false,
    'accepts': false,
    'data': null,
  };

  /// The holder of the current state; read when a scope is captured.
  final DropScopeData data;

  /// Changes whenever [data] does, to rebuild the nodes that read it.
  final int version;

  /// A copy of the state of the nearest drop target above [context], or
  /// null outside one. Rebuilds [context] when it changes.
  static Map<String, dynamic>? stateOf(BuildContext context) {
    final DropScope? scope = context
        .dependOnInheritedWidgetOfExactType<DropScope>();
    return scope == null ? null : {...scope.data.value};
  }

  @override
  bool updateShouldNotify(DropScope oldWidget) => version != oldWidget.version;
}

/// Makes [builder]'s widget (a node) a drop target as [DropTargetModel]
/// describes.
///
/// [accepts] decides whether a drop of some data would be accepted (the
/// group already matched); [isFull] whether the target takes nothing now.
/// [onEvent] runs the node's reactions for `dragEnter`, `dragExit`, `drop`
/// and `dropRejected`, with a context inside the [DropScope] so the
/// actions read `${drop}`.
class NodeDropTarget extends StatefulWidget {
  /// Creates a [NodeDropTarget].
  const NodeDropTarget({
    super.key,
    required this.groups,
    required this.enabled,
    required this.accepts,
    required this.isFull,
    required this.onEvent,
    required this.child,
  });

  /// The groups it takes; empty takes any.
  final List<String> groups;

  /// Whether it takes drops now.
  final bool enabled;

  /// Whether a drop of [data] would be accepted, evaluated with `${drop}`
  /// set (in [context]).
  final bool Function(BuildContext context, Object? data) accepts;

  /// Whether it holds something already and takes nothing now.
  final bool Function() isFull;

  /// Runs the node's reactions for [type] with [context] (inside the
  /// scope) and [result].
  final void Function(BuildContext context, TriggerType type, Object? result)
  onEvent;

  /// The node's widget.
  final Widget child;

  @override
  State<NodeDropTarget> createState() => _NodeDropTargetState();
}

class _NodeDropTargetState extends State<NodeDropTarget> {
  final DropScopeData _data = DropScopeData();
  int _version = 0;
  BuildContext? _inner;
  bool _hovering = false;

  void _set(Map<String, dynamic> value) {
    _data.value = value;
    if (mounted) setState(() => _version++);
  }

  bool _groupMatches(NodeDragPayload payload) =>
      widget.groups.isEmpty || widget.groups.contains(payload.group);

  bool _wouldAccept(Object? data) {
    // The condition reads `${drop.data}`: set it before evaluating.
    _data.value = {..._data.value, 'data': data};
    final BuildContext? context = _inner;
    if (context == null || !context.mounted) return true;
    return widget.accepts(context, data);
  }

  bool _willAccept(DragTargetDetails<NodeDragPayload> details) {
    final NodeDragPayload payload = details.data;
    if (!widget.enabled || !_groupMatches(payload) || widget.isFull()) {
      return false;
    }
    final bool accepts = _wouldAccept(payload.data);
    _set({'hovering': true, 'data': payload.data, 'accepts': accepts});
    if (!_hovering) {
      _hovering = true;
      _run(TriggerType.dragEnter, {'data': payload.data});
    }
    return true;
  }

  void _left(NodeDragPayload? payload) {
    if (!_hovering) return;
    _hovering = false;
    _set(DropScope.idle);
    _run(TriggerType.dragExit, {'data': payload?.data});
  }

  void _dropped(DragTargetDetails<NodeDragPayload> details) {
    _hovering = false;
    final NodeDragPayload payload = details.data;
    final RenderObject? box = context.findRenderObject();
    final Offset origin = box is RenderBox && box.attached
        ? box.localToGlobal(Offset.zero)
        : Offset.zero;
    final Offset d = details.offset - origin;
    final bool accepts = _wouldAccept(payload.data);
    final Map<String, dynamic> drop = {
      'hovering': false,
      'data': payload.data,
      'accepts': accepts,
      'dx': d.dx,
      'dy': d.dy,
    };
    // The chain captures the scope now, so it sees this drop.
    _data.value = drop;
    if (accepts) {
      _run(TriggerType.drop, drop);
    } else {
      payload.rejected = true;
      _run(TriggerType.dropRejected, drop);
    }
    _set(DropScope.idle);
  }

  void _run(TriggerType type, Object? result) {
    final BuildContext? context = _inner;
    if (context == null || !context.mounted) return;
    widget.onEvent(context, type, result);
  }

  @override
  Widget build(BuildContext context) {
    return DragTarget<NodeDragPayload>(
      onWillAcceptWithDetails: _willAccept,
      onLeave: _left,
      onAcceptWithDetails: _dropped,
      builder: (context, candidates, rejected) => DropScope(
        data: _data,
        version: _version,
        child: Builder(
          builder: (context) {
            _inner = context;
            return widget.child;
          },
        ),
      ),
    );
  }
}
