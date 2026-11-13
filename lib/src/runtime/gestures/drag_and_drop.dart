// Drag and drop (`DragSource` and `DropTarget`, node keys
// `draggable` and `dropTarget`): render object layers of a running app's
// nodes, between the rotation and the node's reactions.
//
// * [RenderDragSource] picks the node up (on press, or a long press on
//   touch), draws a copy of it (or its feedback node) under the pointer in
//   the app's overlay, shows the node as a ghost, hidden or kept while it's
//   dragged, and on a drop no target takes springs it back on its physics.
// * [RenderDropTarget] takes drags of the groups it accepts: where the
//   dragged node's center is over it (`x`, `y`, `fx`, `fy`), whether it's
//   full (`fullIf`) and takes the drop (`acceptIf`), and for a target with
//   a list (`listNodeId`) where among the list's items the drop lands
//   (`index`, `before`, `beforeId`); [dropSlotOf] gives a list the slot to
//   open there (`slot`, `slotSize`, `slotWhenRefused`).
// * The session is the layout's `${drag}` ([DragAndDrop]): active, group,
//   data, ids, count, source, over, index, beforeId, before, accepted, x,
//   y, fx, fy, full, width, height; the last drop's values stay readable.
// * Triggers with the session as `${result}`: on the source `dragStart`,
//   `dragCancel`, `dragCompleted`; on the target `dragEnter`, `dragHover`
//   (after its `hoverDelay`), `dragExit`, `drop` (with `key`),
//   `dropRejected` (its `acceptIf` refused) and `dropFull`.
//
// Scroll views under the pointer scroll near their edges while dragging,
// including nested horizontal/vertical views. Targets are hit-tested again
// after scrolling, so a stationary pointer can reach off-screen slots.
// Not supported yet: the drop position a flight key records for the hero.
import 'dart:async';
import 'dart:math' as math;

import 'package:codelessly_api/core.dart' as api;
import 'package:codelessly_api/core.dart' show CollectionScrollProps, Json, ListViewProps, Node, jsonEquality;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart' show SpringSimulation;
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../render/islands.dart';
import '../../render/node_tree.dart';
import '../../render/play.dart' show FlightRegistry;
import '../../render/source.dart';
import '../contracts.dart';
import '../expressions/bindings.dart' show RenderTreeBinder;
import '../expressions/formula.dart' show FormulaEvaluator;
import '../expressions/scopes.dart';
import 'drag_motion.dart' show DragValues;
import 'physics.dart';

/// The id of a list item or payload value: a map's `id`, else the value
/// itself as text.
String dragItemId(Object? value) => switch (value) {
  final Map map when map['id'] != null => FormulaEvaluator.stringify(map['id']),
  _ => FormulaEvaluator.stringify(value),
};

/// The ids a payload carries: each element of a list, or the value.
List<String> dragPayloadIds(Object? data) => switch (data) {
  final Iterable list => [for (final v in list) dragItemId(v)],
  null => const [],
  _ => [dragItemId(data)],
};

/// The size a drag carries (`drag.width`/`drag.height`, a list's slot): what
/// follows the pointer, the feedback node at its designed [feedbackSize]
/// or else the dragged node at its [size], times [feedbackScale].
Size draggedSize(Size size, {Size? feedbackSize, double feedbackScale = 1}) {
  final base = feedbackSize ?? size;
  final scale = feedbackScale > 0 ? feedbackScale : 1;
  return Size(base.width * scale, base.height * scale);
}

/// Whether a drop at [position] lands before the list item at [rect].
///
/// Along a single line (a plain list) it lands before an item when it is
/// above the item's center ([Axis.vertical]) or left of it
/// ([Axis.horizontal]). A wrapping list ([wraps]) reads like text: a
/// horizontal one lays its items in rows, left to right, so a drop lands
/// before an item in an earlier row, or in the item's row left of its
/// center; a vertical one lays them in columns, top to bottom.
bool dropLandsBefore(Offset position, Rect rect, {required Axis axis, bool wraps = false}) {
  if (!wraps) return axis == Axis.vertical ? position.dy < rect.center.dy : position.dx < rect.center.dx;
  if (axis == Axis.horizontal) {
    if (position.dy < rect.top) return true;
    return position.dy <= rect.bottom && position.dx < rect.center.dx;
  }
  if (position.dx < rect.left) return true;
  return position.dx <= rect.right && position.dy < rect.center.dy;
}

/// Logical pixels per second for a drag held inside a scroll viewport.
/// A 48px edge band (at most a third of a small view) ramps smoothly to
/// 720px/s; the centre and positions outside the viewport do not scroll.
@visibleForTesting
double dragEdgeScrollVelocity(double position, double extent) {
  if (extent <= 0 || position < 0 || position > extent) return 0;
  final band = math.min(48.0, extent / 3);
  if (position < band) return -720 * math.pow(1 - position / band, 2).toDouble();
  if (position > extent - band) return 720 * math.pow(1 - (extent - position) / band, 2).toDouble();
  return 0;
}

/// A drag in progress.
class DragSession {
  DragSession({required this.group, required this.data, required this.source, required this.size})
    : ids = dragPayloadIds(data);

  /// The draggable's group.
  final String group;

  /// The payload, as evaluated when the drag started.
  final Object? data;

  /// The ids the payload carries (see [dragPayloadIds]).
  final List<String> ids;

  /// The key of the drop target the drag started in, or ''.
  final String source;

  /// The size of what's dragged ([draggedSize]).
  final Size size;

  /// Where the pointer holds the dragged node, from its top left: where it
  /// was grabbed, or its center ([api.DragAnchor.center]).
  Offset grab = Offset.zero;

  /// Where the feedback is held from its top left: [grab], or zero for a
  /// copy centered on the pointer, which is shifted by half its own size
  /// instead.
  Offset feedbackAnchor = Offset.zero;

  /// The global top left of the dragged node's box for a drag whose
  /// feedback is at [feedbackOffset]: so its center, where `drag.x` and
  /// `drag.y` are measured, is the pointer for a centered copy.
  Offset nodeTopLeft(Offset feedbackOffset) => feedbackOffset + feedbackAnchor - grab;

  /// The drop target under the pointer, or null.
  RenderDropTarget? overTarget;

  /// The key of [overTarget], or ''.
  String over = '';

  /// Where in [overTarget]'s list the drop would land: the index among the
  /// items that aren't being dragged, the raw index of the item it lands
  /// before (the list's length at the end), that item and its id.
  int index = 0;
  int? rawBefore;
  Object? before;
  String beforeId = '';

  /// Whether [overTarget] accepts the drop (its `acceptIf`).
  bool accepted = false;

  /// Where the center of the dragged node is over [overTarget], in logical
  /// pixels from the target's top left ([x], [y]) and as a share of its
  /// size, 0 to 1 ([fx], [fy]). 0 while over no target.
  double x = 0, y = 0, fx = 0, fy = 0;

  /// Whether [overTarget] is full (`fullIf`): it takes no drop, but still
  /// reports itself in [over] so a binding can say why.
  bool full = false;

  /// Number of things dragged.
  int get count => data is Iterable ? ids.length : 1;

  /// What `${drag}` reads.
  Map<String, Object?> toMap({bool active = true}) => {
    'active': active,
    'group': group,
    'data': data,
    'ids': ids,
    'count': count,
    'source': source,
    'over': over,
    // The node of the target the drag is over (several targets may share a
    // key: a column and its tab).
    'target': overTarget?._box?.id ?? '',
    'index': index,
    'beforeId': beforeId,
    'before': before,
    'accepted': accepted,
    'x': x,
    'y': y,
    'fx': fx,
    'fy': fy,
    'full': full,
    'width': size.width,
    'height': size.height,
  };
}

/// What `${drag}` reads when nothing is being dragged (a drag's live values
/// at rest and an idle session): what an app shell declares `drag` as.
final Map<String, Object?> dragIdleValues = Map.unmodifiable({...DragValues.rest.toMap(), ...DragAndDrop.idle});

/// The drag and drop state of one layout (a node tree): the drag in
/// progress, the targets that can take it, and what `${drag}` reads.
class DragAndDrop extends ChangeNotifier {
  DragAndDrop._(this.tree);

  final RenderTree tree;

  static final Expando<DragAndDrop> _of = Expando('DragAndDrop');

  /// [tree]'s drag and drop.
  static DragAndDrop of(RenderTree tree) => _of[tree] ??= DragAndDrop._(tree);

  /// The value of `${drag}`'s session keys when nothing is being dragged.
  static const Map<String, Object?> idle = {
    'active': false,
    'group': '',
    'data': null,
    'ids': <String>[],
    'count': 0,
    'source': '',
    'over': '',
    'target': '',
    'index': 0,
    'beforeId': '',
    'before': null,
    'accepted': false,
    'x': 0.0,
    'y': 0.0,
    'fx': 0.0,
    'fy': 0.0,
    'full': false,
    'width': 0.0,
    'height': 0.0,
  };

  DragSession? _session;
  Map<String, Object?>? _last;

  /// The drag in progress, or null.
  DragSession? get session => _session;

  /// What `${drag}` reads: the drag in progress, else the last drop (with
  /// `active` false, so a drop's actions can still read it), else [idle].
  Map<String, Object?> get value => _session?.toMap() ?? _last ?? idle;

  void start(DragSession session) {
    _session = session;
    _last = null;
    changed();
  }

  /// Tells listeners (and `${drag}`) the session changed.
  void changed() {
    publish();
    notifyListeners();
  }

  /// Ends the drag in progress; [dropped] keeps its values for `${drag}`.
  void end({bool dropped = false}) {
    final session = _session;
    if (session == null) return;
    _session = null;
    _last = dropped ? session.toMap(active: false) : null;
    changed();
  }

  /// Whether a node whose payload is [ids] is part of the drag.
  bool isDragging(List<String> ids) {
    final s = _session;
    return s != null && ids.any(s.ids.contains);
  }

  // --- `${drag}` --------------------------------------------------------------

  Map<String, Object?>? _published;

  /// Writes [value] to the scope that declares `drag` (an app shell's
  /// values, [dragIdleValues] at first), or the outermost values scope.
  void publish() {
    final v = {...DragValues.rest.toMap(), ...value};
    if (_published != null && jsonEquality.equals(_published, v)) return;
    final scope = _dragScope();
    if (scope == null) return;
    _published = v;
    scope.set('drag', v);
  }

  ValuesScope? _dragScope() {
    ValuesScope? outermost;
    for (ValueScope? s = tree.binder?.scope; s != null; s = s.parent) {
      if (s is ValuesScope) {
        if (s.declares('drag')) return s;
        outermost = s;
      }
    }
    return outermost;
  }

  // --- targets ---------------------------------------------------------------

  final Set<RenderDropTarget> _targets = {};
}

/// Adds [n]'s drag and drop layers (a drag source, a drop target) to
/// [chain]: between the rotation and the reactions, in a running app that
/// reacts.
void dragAndDropLayers(NodeBox box, Node n, List<RenderBox> chain) {
  if (!box.tree.animates || box.tree.interactions == null || n.type == 'canvas') return;
  final be = n.behaviors;
  if (be.draggable case final api.DragSource source) {
    chain.add(box.obtain<RenderDragSource>('dragSource', RenderDragSource.new)..configure(box, n, source));
  }
  if (be.dropTarget case final api.DropTarget target) {
    chain.add(box.obtain<RenderDropTarget>('dropTarget', RenderDropTarget.new)..configure(box, n, target));
  }
}

/// The slot a list opens where a drag over its drop target would land.
@immutable
class DropSlotSpec {
  const DropSlotSpec({required this.before, required this.size, this.slotNodeId = '', this.ownSize = false, this.inGap = false});

  /// The raw index of the item the slot goes before (the item count at the
  /// end).
  final int before;

  /// The dragged node's size: the slot's length along the list (and both
  /// ways in a wrapping list). Zero for a refused drop when the target
  /// opens no slot for one ([api.DropTarget.slotWhenRefused]).
  final Size size;

  /// The node drawn in the slot ('' for an empty gap).
  final String slotNodeId;

  /// Whether the slot is [slotNodeId] at its own size (an insertion line)
  /// rather than the dragged node's ([api.DropSlotSize.node]).
  final bool ownSize;

  /// Whether [slotNodeId] is drawn in the gap before the item, at its own
  /// size, taking no room ([api.DropSlotSize.inGap]).
  final bool inGap;

  @override
  bool operator ==(Object other) =>
      other is DropSlotSpec &&
      other.before == before &&
      other.size == size &&
      other.slotNodeId == slotNodeId &&
      other.ownSize == ownSize &&
      other.inGap == inGap;

  @override
  int get hashCode => Object.hash(before, size, slotNodeId, ownSize, inGap);
}

/// The slot list [listNodeId] of [tree] opens now, while a drag is over its
/// drop target ([api.DropTarget.listNodeId]); null for none. A list listens
/// to [DragAndDrop.of] to follow it.
///
/// A list repeated in several copies (each column of a board has its card
/// list) gives its [instance]: only the copy the target names opens it.
DropSlotSpec? dropSlotOf(RenderTree tree, String listNodeId, {Object? instance}) {
  final session = DragAndDrop.of(tree).session;
  final target = session?.overTarget;
  if (session == null || target == null) return null;
  final m = target._model;
  if (m.listNodeId != listNodeId || m.slot == api.DropSlot.none) return null;
  if (!identical(target._listBox, tree.boxOf(listNodeId, instance: instance))) return null;
  final before = session.rawBefore;
  if (before == null) return null;
  // A refused drop opens no slot when the target says so.
  if (!m.slotWhenRefused && !session.accepted) return DropSlotSpec(before: before, size: Size.zero);
  final hasNode = m.slot == api.DropSlot.node && m.slotNodeId.isNotEmpty;
  return DropSlotSpec(
    before: before,
    size: session.size,
    slotNodeId: hasNode ? m.slotNodeId : '',
    ownSize: hasNode && m.slotSize != api.DropSlotSize.dragged,
    inGap: hasNode && m.slotSize == api.DropSlotSize.inGap,
  );
}

/// The node a drop target draws in the slot its list opens
/// ([api.DropTarget.slotNodeId]): a tree of its own over the same nodes and
/// bindings (it reads the drag as it would in its own place), with the node
/// shown even though it's designed hidden where it sits. A list holds one
/// while it shows the slot and [dispose]s it when done.
class DropSlotNode {
  DropSlotNode(RenderTree tree, this.id)
    : _tree = RenderTree(
        _FeedbackSource(tree.source, rootId: id, reveal: true),
        binder: tree.bindings,
        recipes: tree.recipes,
        catalog: tree.catalog,
        gestures: tree.gestures,
        imageLoader: tree.imageLoader,
      );

  final String id;
  final RenderTree _tree;

  /// The slot node's box.
  late final NodeBox box = _tree.obtain(id, const Slot.root());

  void dispose() => _tree.dispose();
}

/// The scope node [box] reads, and its expressions.
ValueScope? _scopeOf(NodeBox box) => box.tree.binder?.scopeFor(box.tree.source, box.id, box.instance);

/// Evaluates [text] (a `${...}` path, a `${= ...}` formula or text with
/// paths) to a value where [box] reads.
Object? _evaluate(NodeBox box, String text) {
  final t = text.trim();
  if (t.isEmpty) return null;
  final binder = box.tree.binder;
  final scope = _scopeOf(box);
  if (binder == null || scope == null) return t;
  return binder.engine.evaluate(t, scope);
}

bool _holds(Object? v) => v == true || v == 'true';

// --- the source ---------------------------------------------------------------

/// A drag of a [RenderDragSource], from pick up to let go: the feedback in
/// the overlay, the targets it's over (as Flutter's `_DragAvatar` tracks
/// them) and the end.
class _SourceDrag implements Drag {
  _SourceDrag(this.source, this.session, Offset pointer) : _position = pointer;

  final RenderDragSource source;
  final DragSession session;
  Offset _position;

  /// The feedback's global top left.
  Offset get offset => _position - session.feedbackAnchor;

  /// Whether a target took the drop (its group, `fullIf` and `acceptIf`
  /// allowed it), as opposed to the drag merely ending over one.
  bool dropped = false;

  final List<RenderDropTarget> _entered = [];
  RenderDropTarget? _active;
  OverlayEntry? _entry;
  final ValueNotifier<Offset> _overlayAt = ValueNotifier(Offset.zero);

  Offset _restrict(Offset delta) => switch (source._model.axis) {
    api.DragAxis.free => delta,
    api.DragAxis.horizontal => Offset(delta.dx, 0),
    api.DragAxis.vertical => Offset(0, delta.dy),
  };

  @override
  void update(DragUpdateDetails details) {
    _position += _restrict(details.delta);
    _moved();
  }

  void _moved() {
    _placeFeedback();
    _updateTargets(_position);
    _edgeTicker ??= Ticker(_scrollTick, debugLabel: 'drag edge scroll')..start();
  }

  Ticker? _edgeTicker;
  Duration _lastScrollTick = Duration.zero;

  /// Scroll the innermost view that can still move on each axis. Retest the
  /// pointer every frame: scrolling can recycle list items and change both
  /// the viewport and the drop target under a stationary pointer.
  void _scrollTick(Duration elapsed) {
    if (_finished) return;
    final dt = math.min((elapsed - _lastScrollTick).inMicroseconds / 1e6, .05);
    _lastScrollTick = elapsed;
    final axes = <Axis>{};
    final visited = <RenderObject>{};
    final offsets = <ViewportOffset>{};
    var moved = false;
    void consider(RenderBox box, ViewportOffset offset, AxisDirection direction) {
      final axis = axisDirectionToAxis(direction);
      if (!offsets.add(offset) ||
          axes.contains(axis) ||
          !box.attached ||
          !box.hasSize ||
          offset is! ScrollPosition ||
          !offset.hasContentDimensions ||
          !offset.physics.shouldAcceptUserOffset(offset)) {
        return;
      }
      final local = box.globalToLocal(_position);
      if (!(Offset.zero & box.size).contains(local)) return;
      final coordinate = axis == Axis.vertical ? local.dy : local.dx;
      final extent = axis == Axis.vertical ? box.size.height : box.size.width;
      final velocity = dragEdgeScrollVelocity(coordinate, extent) * (axisDirectionIsReversed(direction) ? -1 : 1);
      final next = (offset.pixels + velocity * dt).clamp(offset.minScrollExtent, offset.maxScrollExtent);
      if ((next - offset.pixels).abs() < .01) return;
      offset.jumpTo(next);
      axes.add(axis);
      moved = true;
    }

    for (final entry in _hitTestAt(_position).path) {
      if (entry.target case final RenderObject target) {
        for (RenderObject? object = target; object != null; object = object.parent) {
          if (!visited.add(object)) continue;
          if (object is RenderViewport) consider(object, object.offset, object.axisDirection);
          if (object is RenderShrinkWrappingViewport) consider(object, object.offset, object.axisDirection);
          if (object is RenderTwoDimensionalViewport) {
            consider(object, object.horizontalOffset, object.horizontalAxisDirection);
            consider(object, object.verticalOffset, object.verticalAxisDirection);
          }
        }
        // SingleChildScrollView has a private render viewport. The islands'
        // element ancestry also exposes its public ScrollableState; use the
        // scrollable's own render box as the viewport, never the dragged node.
        islandContextOf(target)?.visitAncestorElements((element) {
          if (element is StatefulElement && element.state is ScrollableState) {
            final state = element.state as ScrollableState;
            final box = state.context.findRenderObject();
            if (box is RenderBox) consider(box, state.position, state.axisDirection);
          }
          return true;
        });
      }
    }
    if (moved) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!_finished) _updateTargets(_position);
      });
    }
  }

  void _updateTargets(Offset globalPosition) {
    final targets = _targetsAt(globalPosition);
    var same = false;
    if (targets.length >= _entered.length && _entered.isNotEmpty) {
      same = true;
      for (var i = 0; i < _entered.length; i++) {
        if (!identical(targets[i], _entered[i])) {
          same = false;
          break;
        }
      }
    }
    if (same) {
      for (final t in _entered) {
        t._onMove(this);
      }
      return;
    }
    _leaveAll();
    RenderDropTarget? taker;
    for (final t in targets) {
      _entered.add(t);
      if (t._takes(session.group)) {
        taker = t;
        break;
      }
    }
    for (final t in _entered) {
      t._onMove(this);
    }
    _active = taker;
  }

  /// The drop targets of this layout under [globalPosition], innermost
  /// first.
  List<RenderDropTarget> _targetsAt(Offset globalPosition) {
    final dnd = DragAndDrop.of(source._box!.tree);
    if (dnd._targets.isEmpty) return const [];
    return [
      for (final e in _hitTestAt(globalPosition).path)
        if (e.target case final RenderDropTarget t when dnd._targets.contains(t)) t,
    ];
  }

  HitTestResult _hitTestAt(Offset globalPosition) {
    final result = HitTestResult();
    final context = islandContextOf(source);
    final viewId =
        (context == null ? null : View.maybeOf(context))?.viewId ??
        WidgetsBinding.instance.platformDispatcher.implicitView?.viewId;
    if (viewId != null) WidgetsBinding.instance.hitTestInView(result, globalPosition, viewId);
    return result;
  }

  void _leaveAll() {
    for (final t in _entered) {
      t._onLeave(this);
    }
    _entered.clear();
  }

  @override
  void end(DragEndDetails details) => _finish(dropped: true);

  @override
  void cancel() => _finish(dropped: false);

  bool _finished = false;

  void _finish({required bool dropped}) {
    if (_finished) return;
    _finished = true;
    _edgeTicker?.dispose();
    _edgeTicker = null;
    var wasAccepted = false;
    final active = _active;
    if (dropped && active != null) {
      active._onDrop(this);
      wasAccepted = true;
      _entered.remove(active);
    }
    _leaveAll();
    _active = null;
    _entry?.remove();
    _entry?.dispose();
    _entry = null;
    _feedbackTree?.dispose();
    _feedbackTree = null;
    _overlayAt.dispose();
    source._ended(this, wasAccepted);
  }

  // --- feedback ------------------------------------------------------------

  RenderTree? _feedbackTree;
  RenderBox? _overlayBox;

  void _placeFeedback() {
    final box = _overlayBox;
    if (box == null || !box.attached) return;
    _overlayAt.value = box.globalToLocal(offset);
  }

  /// Shows the feedback in the app's overlay.
  void showFeedback() {
    final context = islandContextOf(source);
    final overlay = context == null ? null : Overlay.maybeOf(context);
    final box = source._box;
    if (overlay == null || box == null) return;
    _overlayBox = overlay.context.findRenderObject() as RenderBox?;
    final model = source._model;
    final feedbackId = model.feedback.isNotEmpty && box.tree.source.node(model.feedback) != null
        ? model.feedback
        : '';
    final rootId = feedbackId.isEmpty ? box.id : feedbackId;
    // A tree of its own over the same nodes and bindings: what the node
    // reads where it is (its list item) it reads in the overlay too.
    final tree = _feedbackTree = RenderTree(
      _FeedbackSource(box.tree.source, rootId: rootId, under: feedbackId.isEmpty ? null : box.id),
      binder: box.tree.bindings,
      environment: const IslandEnvironment(interactive: true),
      recipes: box.tree.recipes,
      catalog: box.tree.catalog,
      gestures: box.tree.gestures,
      imageLoader: box.tree.imageLoader,
    );
    final size = feedbackId.isEmpty ? source.size : (source._feedbackSize ?? source.size);
    // A feedback node of its own that hugs its content on an axis (a chip
    // with a tag whose text changes while dragging) takes its content's
    // size there; a fixed axis keeps its designed size.
    final hug = feedbackId.isEmpty ? (false, false) : source._feedbackHugs;
    final overlaySize = _overlayBox?.hasSize == true ? _overlayBox!.size : Size.infinite;
    Widget content = hug.$1 || hug.$2
        ? ConstrainedBox(
            constraints: BoxConstraints(maxWidth: overlaySize.width, maxHeight: overlaySize.height),
            child: SizedBox(
              width: hug.$1 ? null : size.width,
              height: hug.$2 ? null : size.height,
              child: _NodeInstanceView(tree: tree, id: rootId, instance: box.instance),
            ),
          )
        : SizedBox.fromSize(
            size: size,
            child: _NodeInstanceView(tree: tree, id: rootId, instance: box.instance),
          );
    final radius = box.node?.decoration.radius.topLeft ?? 0;
    Widget feedback = Opacity(
      opacity: model.feedbackOpacity.clamp(0, 1).toDouble(),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: model.feedbackElevation <= 0
              ? null
              : [
                  BoxShadow(
                    color: const Color(0x2E14171C),
                    blurRadius: model.feedbackElevation,
                    offset: Offset(0, model.feedbackElevation / 2),
                  ),
                ],
        ),
        child: content,
      ),
    );
    if (model.feedbackScale != 1 || model.feedbackRotation != 0) {
      feedback = Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..rotateZ(model.feedbackRotation * math.pi / 180)
          ..scaleByDouble(model.feedbackScale, model.feedbackScale, 1, 1),
        child: feedback,
      );
    }
    feedback = Material(type: MaterialType.transparency, child: feedback);
    if (model.dragAnchor == api.DragAnchor.center) {
      feedback = FractionalTranslation(translation: const Offset(-0.5, -0.5), child: feedback);
    }
    feedback = IgnorePointer(child: feedback);
    content = feedback;
    final themes = InheritedTheme.capture(from: context!, to: overlay.context);
    _placeFeedback();
    _entry = OverlayEntry(
      builder: (_) => ValueListenableBuilder<Offset>(
        valueListenable: _overlayAt,
        builder: (_, at, child) => Positioned(left: at.dx, top: at.dy, child: child!),
        child: themes.wrap(content),
      ),
    );
    overlay.insert(_entry!);
  }
}

/// The feedback tree's nodes: the source's, with the feedback node shown
/// even where it's designed hidden (only it: the nodes inside keep their
/// own visibility) and, for a feedback node of its own, read as if inside
/// the dragged node (its list item, its drag).
class _FeedbackSource implements NodeSource {
  _FeedbackSource(this.base, {required this.rootId, this.under, this.reveal = false});

  final NodeSource base;
  final String rootId;
  final String? under;

  /// Shows the root even where it's designed hidden when it's read where it
  /// is (a drop slot's node, kept hidden in its own place).
  final bool reveal;
  final Map<String, ValueNotifier<Node?>> _watched = {};

  bool get _reshows => under != null || reveal;

  Node? _shown(Node? n) {
    if (n == null || n.id != rootId || !_reshows) return n;
    return n.copyWith(visible: true, bind: {...n.bind}..remove('visible'));
  }

  @override
  Node? node(String id) => _shown(base.node(id));

  @override
  String? parentOf(String id) => id == rootId && under != null ? under : base.parentOf(id);

  @override
  ValueListenable<Node?> watch(String id) {
    if (id != rootId || !_reshows) return base.watch(id);
    return _watched[id] ??= () {
      final from = base.watch(id);
      final out = ValueNotifier<Node?>(_shown(from.value));
      from.addListener(() => out.value = _shown(from.value));
      return out;
    }();
  }
}

/// Shows node [id] of [tree] in [instance] (a list item's copy), like a
/// NodeView.
class _NodeInstanceView extends RenderObjectWidget {
  const _NodeInstanceView({required this.tree, required this.id, required this.instance});

  final RenderTree tree;
  final String id;
  final Object? instance;

  @override
  IslandOwnerElement createElement() => IslandOwnerElement(this);

  @override
  _RenderInstanceView createRenderObject(BuildContext context) =>
      _RenderInstanceView(tree.obtain(id, const Slot.root(), instance: instance));

  @override
  void updateRenderObject(BuildContext context, _RenderInstanceView renderObject) {}
}

class _RenderInstanceView extends RenderProxyBox with RenderObjectWithLayoutCallbackMixin, IslandParent {
  _RenderInstanceView(NodeBox box) {
    if (box.parent != null) box.detachFromParent();
    child = box;
  }

  @override
  void dispose() {
    child = null;
    super.dispose();
  }
}

/// The drag source layer of a node with a [api.DragSource] (see the top of
/// this file). [configure]d by its node box on every apply.
class RenderDragSource extends RenderProxyBox implements MouseTrackerAnnotation {
  RenderDragSource();

  NodeBox? _box;
  api.DragSource _model = const api.DragSource();

  /// The payload's expression: the model's data, or the first form's
  /// `draggable.data` binding (the value's own text).
  String _data = '';

  /// The designed size of the feedback node, when it has one.
  Size? _feedbackSize;

  /// Whether the feedback node hugs its content across and down.
  (bool, bool) _feedbackHugs = (false, false);

  void configure(NodeBox box, Node n, api.DragSource model) {
    final restart = model.start != _model.start || model.axis != _model.axis;
    _box = box;
    _model = model;
    _data = n.bind['draggable.data'] ?? model.data;
    final f = model.feedback.isEmpty ? null : box.tree.source.node(model.feedback);
    _feedbackSize = f == null ? null : Size(f.layout.width.value, f.layout.height.value);
    _feedbackHugs = f == null ? (false, false) : (f.layout.width.isHug, f.layout.height.isHug);
    if (restart) {
      _recognizer?.dispose();
      _recognizer = null;
    }
    _listen();
    _restyle();
  }

  DragAndDrop? _dnd;

  void _listen() {
    final next = attached && _box != null ? DragAndDrop.of(_box!.tree) : null;
    if (identical(next, _dnd)) return;
    _dnd?.removeListener(_restyle);
    _dnd = next;
    _dnd?.addListener(_restyle);
  }

  /// The ids this node's payload carries now.
  List<String> get _ownIds {
    final box = _box;
    return box == null ? const [] : dragPayloadIds(_evaluate(box, _data));
  }

  // --- how it shows while dragged ---------------------------------------------

  /// Collapsed: hidden while over a target that would take it.
  bool _collapsed = false;

  /// The ghost's opacity while dragged, or null.
  double? _ghost;

  void _restyle() {
    final box = _box;
    if (box == null) return;
    final dnd = DragAndDrop.of(box.tree);
    final session = dnd.session;
    final dragged = session != null && dnd.isDragging(_ownIds);
    var collapsed = false;
    double? ghost;
    if (dragged) {
      switch (_model.childWhenDragging) {
        // Collapses while over a target that would take it, so the slot
        // there is the only place it shows; ghosts elsewhere (and over a
        // full target) so it can be found again.
        case api.DragSourceStyle.hidden when session.overTarget != null && !session.full:
          collapsed = true;
        case api.DragSourceStyle.hidden || api.DragSourceStyle.ghost:
          ghost = _model.ghostOpacity.clamp(0, 1).toDouble();
        case api.DragSourceStyle.keep:
      }
    }
    if (collapsed != _collapsed) {
      _collapsed = collapsed;
      markNeedsLayout();
    }
    if (ghost != _ghost) {
      _ghost = ghost;
      markNeedsPaint();
    }
  }

  @override
  void performLayout() {
    if (_collapsed) {
      child?.layout(constraints, parentUsesSize: false);
      size = constraints.smallest;
      return;
    }
    super.performLayout();
  }

  // --- the spring back --------------------------------------------------------

  /// Where the node was let go, from its place; and how far home it is (0
  /// where it was let go, 1 home).
  Offset _returnFrom = Offset.zero;
  double _return = 1;
  SpringSimulation? _spring;
  Ticker? _ticker;
  Duration? _springStart;

  void _springBack(Offset feedbackTopLeft) {
    final physics = _model.effectivePhysics;
    if (physics == null || !attached) return;
    _returnFrom = feedbackTopLeft - localToGlobal(Offset.zero);
    _return = 0;
    _spring = SpringSimulation(springOf(physics), 0, 1, 0);
    _springStart = null;
    _ticker ??= Ticker(_tick, debugLabel: 'drag source return');
    if (!_ticker!.isActive) _ticker!.start();
    markNeedsPaint();
  }

  void _stopReturn() {
    _spring = null;
    _ticker?.stop();
    if (_return != 1) {
      _return = 1;
      markNeedsPaint();
    }
  }

  void _tick(Duration elapsed) {
    final s = _spring;
    if (s == null) return _ticker?.stop();
    final start = _springStart ??= elapsed;
    final t = (elapsed - start).inMicroseconds / Duration.microsecondsPerSecond;
    if (s.isDone(t)) {
      _return = 1;
      _spring = null;
      _ticker?.stop();
    } else {
      _return = s.x(t);
    }
    markNeedsPaint();
  }

  Offset get _shift => _return == 1 ? Offset.zero : _returnFrom * (1 - _return);

  /// How far from its place it's drawn, flying home (tests).
  @visibleForTesting
  Offset get debugReturnShift => _shift;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_collapsed || child == null) return;
    final shift = _shift;
    final ghost = _ghost;
    void inner(PaintingContext c, Offset o) {
      if (ghost == null) return super.paint(c, o);
      c.pushOpacity(o, (ghost * 255).round(), super.paint);
    }

    inner(context, offset + shift);
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final s = _shift;
    if (s != Offset.zero) transform.translateByDouble(s.dx, s.dy, 0, 1);
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    // A ghost doesn't take the pointer.
    if (_collapsed || _ghost != null) return false;
    return super.hitTest(result, position: position);
  }

  // --- the drag -------------------------------------------------------------------

  MultiDragGestureRecognizer? _recognizer;
  _SourceDrag? _drag;
  bool _disposed = false;

  bool get _longPress => switch (_model.start) {
    api.DragStart.press => false,
    api.DragStart.longPress => true,
    api.DragStart.auto => const {
      TargetPlatform.android,
      TargetPlatform.iOS,
      TargetPlatform.fuchsia,
    }.contains(defaultTargetPlatform),
  };

  MultiDragGestureRecognizer _ensureRecognizer() => _recognizer ??=
      (_longPress
            ? DelayedMultiDragGestureRecognizer(delay: const Duration(milliseconds: 300), debugOwner: this)
            : switch (_model.axis) {
                api.DragAxis.free => ImmediateMultiDragGestureRecognizer(debugOwner: this),
                api.DragAxis.horizontal => HorizontalMultiDragGestureRecognizer(debugOwner: this),
                api.DragAxis.vertical => VerticalMultiDragGestureRecognizer(debugOwner: this),
              })
        ..onStart = _onStart;

  @override
  void handleEvent(PointerEvent event, HitTestEntry entry) {
    if (event is PointerDownEvent && _model.enabled && _drag == null) _ensureRecognizer().addPointer(event);
  }

  Drag? _onStart(Offset position) {
    final box = _box;
    if (box == null || _drag != null || !attached || !hasSize || !_model.enabled) return null;
    final dnd = DragAndDrop.of(box.tree);
    final session = DragSession(
      group: _model.group,
      data: _evaluate(box, _data),
      source: _sourceKey(box),
      size: draggedSize(size, feedbackSize: _feedbackSize, feedbackScale: _model.feedbackScale),
    )..grab = globalToLocal(position);
    // A centered copy is held by the center of what is dragged (the feedback
    // node at its own size): `drag.x` and `drag.y` are then the pointer.
    final centered = _model.dragAnchor == api.DragAnchor.center;
    if (centered) session.grab = session.size.center(Offset.zero);
    session.feedbackAnchor = centered ? Offset.zero : session.grab;
    final drag = _drag = _SourceDrag(this, session, position);
    _stopReturn();
    HapticFeedback.selectionClick();
    dnd.start(session);
    _fire(api.TriggerType.dragStart.name, session.toMap());
    drag.showFeedback();
    // Starting re-applies what reads the drag (a column dimmed while its
    // grip drags it adds a layer): look for targets once that is laid out,
    // not in the stale tree, whose hit test would throw and drop the
    // gesture.
    drag._placeFeedback();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!drag._finished) drag._moved();
    }, debugLabel: 'drag start targets');
    SchedulerBinding.instance.ensureVisualUpdate();
    return drag;
  }

  /// The key of the drop target the node is in, or ''.
  String _sourceKey(NodeBox box) {
    for (RenderObject? p = parent; p != null; p = p.parent) {
      if (p is RenderDropTarget) return p.key;
    }
    return '';
  }

  void _fire(String trigger, Json result) {
    final box = _box;
    if (box != null && box.attached) fireTrigger(box, trigger, event: {'result': result});
  }

  /// The drag let go ([wasAccepted]: over a target of its group, which
  /// either took it ([_SourceDrag.dropped]) or refused it).
  void _ended(_SourceDrag drag, bool wasAccepted) {
    if (identical(_drag, drag)) _drag = null;
    if (_disposed) {
      final recognizer = _recognizer;
      _recognizer = null;
      scheduleMicrotask(() => recognizer?.dispose());
    }
    final box = _box;
    if (box == null) return;
    final dnd = DragAndDrop.of(box.tree);
    if (wasAccepted && drag.dropped) {
      // Where the copy was let go, for the node with the same flight key
      // that shows the drop next (render/play.dart's FlightRegistry).
      final key = box.node?.behaviors.flightKey ?? '';
      if (key.isNotEmpty && box.hasSize) {
        final dropped = drag.session.size;
        FlightRegistry.recordDrop(
          key,
          Rect.fromCenter(
            center: drag.offset + box.size.center(Offset.zero),
            width: dropped.width,
            height: dropped.height,
          ),
        );
      }
      _fire(api.TriggerType.dragCompleted.name, drag.session.toMap(active: false));
    } else {
      _springBack(drag.offset);
    }
    // A drop on a target ends the session there.
    if (wasAccepted && !identical(dnd.session, drag.session)) return;
    dnd.end();
    _canceled(drag.session);
  }

  /// Fires the `dragCancel` reactions.
  void _canceled(DragSession session) => _fire(api.TriggerType.dragCancel.name, session.toMap(active: false));

  // --- mouse ------------------------------------------------------------------------

  @override
  MouseCursor get cursor => _model.enabled && !_longPress ? SystemMouseCursors.grab : MouseCursor.defer;

  @override
  PointerEnterEventListener? get onEnter => null;

  @override
  PointerExitEventListener? get onExit => null;

  @override
  bool get validForMouseTracker => attached;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _listen();
  }

  @override
  void detach() {
    _dnd?.removeListener(_restyle);
    _dnd = null;
    _ticker?.stop();
    super.detach();
  }

  @override
  void dispose() {
    _disposed = true;
    if (_box?.tree.isDisposed ?? false) _drag?.cancel();
    // A virtualized source may disappear during an active drag. Its gesture
    // client owns edge scrolling until pointer up/cancel; dropping its router
    // here would strand the session and its ticker.
    if (_drag == null) {
      _recognizer?.dispose();
      _recognizer = null;
    }
    _ticker?.dispose();
    _ticker = null;
    super.dispose();
  }
}

// --- the target ---------------------------------------------------------------

/// The drop target layer of a node with a [api.DropTarget] (see the top of
/// this file). [configure]d by its node box on every apply.
class RenderDropTarget extends RenderProxyBox {
  RenderDropTarget();

  NodeBox? _box;
  api.DropTarget _model = const api.DropTarget();

  void configure(NodeBox box, Node n, api.DropTarget model) {
    _box = box;
    _model = model;
    _register();
  }

  DragAndDrop? _registered;

  void _register() {
    final box = _box;
    final next = attached && box != null ? DragAndDrop.of(box.tree) : null;
    if (identical(next, _registered)) return;
    _registered?._targets.remove(this);
    _registered = next;
    next?._targets.add(this);
  }

  /// This target's key, as `drag.over` reads it.
  String get key {
    final box = _box;
    final text = _model.key.trim();
    if (box == null) return '';
    if (text.isEmpty) return box.id;
    return FormulaEvaluator.stringify(_evaluate(box, text));
  }

  /// Whether a drag of [group] may come onto this target at all: a group it
  /// accepts, while it is enabled. A full target still takes the drag onto
  /// it (so `drag.over` and `drag.full` can say why) and refuses the drop.
  bool _takes(String group) => _model.enabled && (_model.accepts.isEmpty || _model.accepts.contains(group));

  /// Whether it takes no drops now (`fullIf`), reading the session as it is.
  bool _isFull(DragAndDrop dnd) {
    final condition = _model.fullIf.trim();
    if (condition.isEmpty) return false;
    dnd.publish();
    return _holds(_evaluate(_box!, condition));
  }

  bool _evaluateAccept(DragAndDrop dnd) {
    final condition = _model.acceptIf.trim();
    if (condition.isEmpty) return true;
    dnd.publish();
    return _holds(_evaluate(_box!, condition));
  }

  Timer? _hoverTimer;
  bool _entered = false;

  /// Sets where the dragged node's center is over this target, from the
  /// global position of its top left.
  bool _locate(DragSession session, Offset topLeft) {
    if (!attached || !hasSize) return false;
    final local = globalToLocal(topLeft + session.size.center(Offset.zero));
    final x = local.dx, y = local.dy;
    final fx = size.width > 0 ? (x / size.width).clamp(0.0, 1.0) : 0.0;
    final fy = size.height > 0 ? (y / size.height).clamp(0.0, 1.0) : 0.0;
    final changed = x != session.x || y != session.y || fx != session.fx || fy != session.fy;
    session
      ..x = x
      ..y = y
      ..fx = fx
      ..fy = fy;
    return changed;
  }

  void _onMove(_SourceDrag drag) {
    final session = drag.session;
    if (!_takes(session.group)) return;
    final dnd = DragAndDrop.of(_box!.tree);
    final position = drag.offset + session.feedbackAnchor;
    final moved = _locate(session, session.nodeTopLeft(drag.offset));
    final oldOver = session.over;
    final oldBefore = session.rawBefore;
    final oldAccepted = session.accepted;
    final entering = !identical(session.overTarget, this);
    final oldFull = session.full;
    session.overTarget = this;
    session.over = key;
    session.full = _isFull(dnd);
    if (_model.listNodeId.isNotEmpty && !session.full) {
      _place(session, position);
    } else {
      session
        ..index = 0
        ..rawBefore = null
        ..before = null
        ..beforeId = '';
    }
    session.accepted = !session.full && _evaluateAccept(dnd);
    if (entering ||
        moved ||
        oldOver != session.over ||
        oldBefore != session.rawBefore ||
        oldAccepted != session.accepted ||
        oldFull != session.full) {
      dnd.changed();
    }
    // A full target reports itself (drag.over, drag.full) but isn't
    // entered: enter, hover and exit are for targets that would take it.
    if (entering && !_entered && !session.full) {
      _entered = true;
      _fire(api.TriggerType.dragEnter.name, session.toMap());
      if (_model.hoverDelay > 0) {
        _hoverTimer?.cancel();
        _hoverTimer = Timer(Duration(milliseconds: _model.hoverDelay), () {
          if (attached && identical(dnd.session?.overTarget, this)) {
            _fire(api.TriggerType.dragHover.name, session.toMap());
          }
        });
      }
    }
  }

  void _onLeave(_SourceDrag drag) {
    _hoverTimer?.cancel();
    final wasEntered = _entered;
    _entered = false;
    final session = drag.session;
    if (!identical(session.overTarget, this)) return;
    session
      ..overTarget = null
      ..over = ''
      ..accepted = false
      ..x = 0
      ..y = 0
      ..fx = 0
      ..fy = 0
      ..full = false
      ..rawBefore = null;
    DragAndDrop.of(_box!.tree).changed();
    if (wasEntered) _fire(api.TriggerType.dragExit.name, session.toMap());
  }

  void _onDrop(_SourceDrag drag) {
    _hoverTimer?.cancel();
    _entered = false;
    final session = drag.session;
    final dnd = DragAndDrop.of(_box!.tree);
    _locate(session, session.nodeTopLeft(drag.offset));
    // Let go before a move reached this target: judge the drop now.
    if (!identical(session.overTarget, this)) {
      session
        ..overTarget = this
        ..over = key;
      session.full = _isFull(dnd);
      session.accepted = !session.full && _evaluateAccept(dnd);
    }
    final full = session.full;
    final accepted = session.accepted;
    final result = session.toMap(active: false)..['key'] = session.over;
    drag.dropped = accepted;
    dnd.end(dropped: accepted);
    if (accepted) {
      _fire(api.TriggerType.drop.name, result);
    } else if (full) {
      // Let go on a full target: not a wrong answer, but say so.
      _fire(api.TriggerType.dropFull.name, result);
      drag.source._canceled(session);
    } else {
      // Of a group it takes, but its acceptIf refused it: a wrong answer.
      _fire(api.TriggerType.dropRejected.name, result);
      drag.source._canceled(session);
    }
  }

  void _fire(String trigger, Json result) {
    final box = _box;
    if (box != null && box.attached) fireTrigger(box, trigger, event: {'result': result});
  }

  // --- the list it drops into ---------------------------------------------------

  /// Places the pointer at [position] among the items of the target's list.
  void _place(DragSession session, Offset position) {
    final items = _listItems();
    // Over a target beside the list (a column's tab): at the end.
    if (_ownList == null && _remoteList != null) {
      session
        ..index = items.where((i) => !session.ids.contains(dragItemId(i.value))).length
        ..before = null
        ..beforeId = ''
        ..rawBefore = items.isEmpty ? 0 : items.map((e) => e.index).reduce(math.max) + 1;
      return;
    }
    final list = _box!.tree.source.node(_model.listNodeId);
    final axis = list == null
        ? Axis.vertical
        : switch (list.type) {
            'row' => Axis.horizontal,
            'column' => Axis.vertical,
            _ =>
              list.prop(CollectionScrollProps.scrollDirection) == api.Axis.horizontal ? Axis.horizontal : Axis.vertical,
          };
    final wraps = list != null && list.type == 'listView' && list.prop(ListViewProps.wrap);
    var index = 0;
    _ListItem? before;
    for (final item in items) {
      if (session.ids.contains(dragItemId(item.value))) continue;
      if (dropLandsBefore(position, item.rect, axis: axis, wraps: wraps)) {
        before = item;
        break;
      }
      index++;
    }
    session.index = index;
    session.before = before?.value;
    session.beforeId = before == null ? '' : dragItemId(before.value);
    session.rawBefore = before?.index ?? (items.isEmpty ? 0 : items.map((e) => e.index).reduce(math.max) + 1);
  }

  /// The box of the list this target drops into: the copy in its own list
  /// item; else, for a target outside the list's repeat (a column's tab),
  /// the copy whose own target has this one's key ([_remoteList]); else the
  /// list's only one.
  NodeBox? get _listBox => _ownList ?? _remoteList ?? _box?.tree.boxOf(_model.listNodeId);

  NodeBox? get _ownList {
    final box = _box;
    if (box == null || _model.listNodeId.isEmpty || !_holdsList) return null;
    return box.tree.boxOf(_model.listNodeId, instance: box.instance);
  }

  /// Whether the list is inside this target (or is it) in the design, so
  /// a copy of it is in this target's own list item.
  bool get _holdsList {
    final box = _box!;
    final source = box.tree.source;
    for (String? id = _model.listNodeId; id != null; id = source.parentOf(id)) {
      if (id == box.id) return true;
    }
    return false;
  }

  /// The copy of the list another target with the same key drops into, for
  /// a target that names a list outside its own repeat.
  NodeBox? get _remoteList {
    final box = _box;
    final dnd = _registered;
    if (box == null || dnd == null || _model.listNodeId.isEmpty || _ownList != null) return null;
    final key = this.key;
    for (final t in dnd._targets) {
      if (identical(t, this) || t._model.listNodeId != _model.listNodeId) continue;
      final own = t._ownList;
      if (own != null && own.attached && t.key == key) return own;
    }
    return null;
  }

  /// The items of the target's list as laid out: their index, value and
  /// global rect, in index order.
  List<_ListItem> _listItems() {
    final box = _box!;
    final tree = box.tree;
    final list = _listBox;
    if (list == null || !list.attached) return const [];
    final out = <_ListItem>[];
    void visit(RenderObject o) {
      // Not an item: the slot's node, drawn from a tree of its own.
      if (o is NodeBox && !identical(o.tree, tree)) return;
      if (o is NodeBox && !identical(o, list)) {
        if (!o.attached || !o.hasSize) return;
        final scope = tree.binder?.scopeFor(tree.source, o.id, o.instance);
        ItemScope? item;
        for (ValueScope? s = scope; s != null; s = s.parent) {
          if (s is ItemScope) {
            item = s;
            break;
          }
        }
        final index =
            item?.index ??
            switch (o.instance) {
              (_, _, _, final int k) => k,
              _ => 0,
            };
        final rect = MatrixUtils.transformRect(o.getTransformTo(null), Offset.zero & o.size);
        out.add(_ListItem(index, item?.item, rect));
        return;
      }
      o.visitChildren(visit);
    }

    list.visitChildren(visit);
    out.sort((a, b) => a.index.compareTo(b.index));
    return out;
  }

  /// Hit within its box whether or not what's in it is (Flutter's
  /// `DragTarget` is translucent), so a drag over its empty parts is over
  /// it.
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!size.contains(position)) return false;
    final hit = hitTestChildren(result, position: position);
    result.add(BoxHitTestEntry(this, position));
    return hit;
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _register();
  }

  @override
  void detach() {
    _registered?._targets.remove(this);
    _registered = null;
    _hoverTimer?.cancel();
    super.detach();
  }
}

class _ListItem {
  _ListItem(this.index, this.value, this.rect);
  final int index;
  final Object? value;
  final Rect rect;
}
