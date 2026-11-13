// A node that follows the pointer: `dismissible` (Flutter's `Dismissible`)
// or `pan` (the legacy `drag` reads as one of them). A render object, the
// outermost layer of the node's chain (around its margin). It follows the
// pointer within its bounds and limits, locked to its axis and held back by
// resistance; and on release springs back, stays, or flies off past a
// threshold (a swiped card), with `physics` a fling, a spring settle and
// snap points. Only a running app adds it (RenderTree.animates): the design
// canvas draws the node where its layout puts it.
//
// What it gives the layout:
// * `${dismiss}` / `${pan}` (and the legacy `${drag}`) inside the node
//   (itself and the nodes in it): its live values ([DragValues.toMap]) over
//   the layout's drag and drop session, through the node's [LocalScope]
//   (NodeBinder.localNames).
// * `shareAs` (the same map), `xVariable` and `yVariable` (its offset,
//   rounded to hundredths) written after each frame it changed in.
// * Triggers: `drag` on every move (`dx`, `dy` from rest, `deltaX`,
//   `deltaY`, `pointerCount`), `dragEnd` when let go (`dx`, `dy`,
//   `velocityX`, `velocityY`, `dismissed`, `direction`, `blocked`,
//   `pointerCount`; with physics `targetX`, `targetY`, `snapIndex`), and
//   the swipe of the direction it flew off in (`direction`).
// * The `dragged` interaction state of it and the nodes in it, while held.
// * [DragMotionControl.control]: the controlDismissible action's dismiss,
//   returnFrom, reset and shake.
import 'dart:async';
import 'dart:math' as math;

import 'package:codelessly_api/core.dart' as api;
import 'package:codelessly_api/core.dart' show Json, Node;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/physics.dart' show Simulation;
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import '../../render/contracts.dart' show HitTestedWhereDrawn;
import '../../render/node_tree.dart';
import '../actions/context.dart' show setVariableIn;
import '../expressions/bindings.dart' show RenderTreeBinder;
import '../contracts.dart';
import 'physics.dart';

/// The live state of a drag, as the `drag` name shows it.
@immutable
class DragValues {
  const DragValues({
    this.offset = Offset.zero,
    this.left = 0,
    this.right = 0,
    this.up = 0,
    this.down = 0,
    this.dragging = false,
    this.dismissed = false,
    this.settling = false,
    this.snapIndex = -1,
  });

  /// How far the node has moved from where its layout puts it, in logical
  /// pixels.
  final Offset offset;

  /// Progress toward dismissing each way, 0 to 1 (1 is at the threshold).
  final double left, right, up, down;

  /// Whether a pointer is dragging the node now.
  final bool dragging;

  /// Whether the node has flown off.
  final bool dismissed;

  /// Whether the node is flinging or springing on its own after release
  /// ([api.Pan.physics]).
  final bool settling;

  /// The [api.GestureSnap.points] index the last release settles on; −1
  /// for none.
  final int snapIndex;

  /// At rest.
  static const DragValues rest = DragValues();

  /// The largest progress in any direction.
  double get progress => math.max(math.max(left, right), math.max(up, down));

  /// The direction with the most progress, or '' at rest.
  String get direction {
    final p = progress;
    if (p <= 0) return '';
    if (p == left) return 'left';
    if (p == right) return 'right';
    if (p == up) return 'up';
    return 'down';
  }

  /// The values as `${drag}` reads them.
  Map<String, Object?> toMap() => {
        'dx': offset.dx,
        'dy': offset.dy,
        'left': left,
        'right': right,
        'up': up,
        'down': down,
        'progress': progress,
        'direction': direction,
        'dragging': dragging,
        'dismissed': dismissed,
        'settling': settling,
        'snapIndex': snapIndex,
      };

  @override
  bool operator ==(Object other) =>
      other is DragValues &&
      other.offset == offset &&
      other.left == left &&
      other.right == right &&
      other.up == up &&
      other.down == down &&
      other.dragging == dragging &&
      other.dismissed == dismissed &&
      other.settling == settling &&
      other.snapIndex == snapIndex;

  @override
  int get hashCode => Object.hash(offset, left, right, up, down, dragging, dismissed, settling, snapIndex);
}

/// Whether node [n] follows the pointer as a [RenderDragMotion]: it is
/// dismissible or pans. The screen itself doesn't.
bool followsPointer(Node n) => (n.behaviors.dismissible != null || n.behaviors.pan != null) && n.type != 'canvas';

/// The release a [RenderDragMotion] runs: [api.PanRelease]'s two, or
/// flying off.
enum FollowRelease { snapBack, stay, dismiss }

/// What a node that follows the pointer does, from its
/// [api.DismissibleBehavior] or [api.Pan]: one engine for both.
@immutable
class FollowSpec {
  const FollowSpec({
    this.enabled = true,
    this.axis = api.DragAxis.free,
    this.release = FollowRelease.snapBack,
    this.directions = const [],
    this.thresholds = const {},
    this.velocityThreshold = 800,
    this.resistance = 0,
    this.snapBack = 450,
    this.snapCurve = api.AnimationCurve.spring,
    this.flyOut = 320,
    this.flyOutCurve = api.AnimationCurve.easeIn,
    this.flyOutRotate = 0,
    this.restX = 0,
    this.restY = 0,
    this.xVariable = '',
    this.yVariable = '',
    this.physics,
    this.bounds = api.GestureBounds.none,
    this.minX,
    this.maxX,
    this.minY,
    this.maxY,
    this.rotateFactor = 0,
    this.originX = 0,
    this.originY = 0,
    this.shakeWhenDisabled = false,
    this.disabledFollow = 0,
    this.shareAs = '',
    this.follow = true,
    this.defaultThreshold = 0.35,
  });

  static const FollowSpec none = FollowSpec();

  final bool enabled;
  final api.DragAxis axis;
  final FollowRelease release;
  final List<api.DragDirection> directions;
  final Map<api.DragDirection, double> thresholds;
  final double defaultThreshold, velocityThreshold, resistance;
  final int snapBack, flyOut;
  final api.AnimationCurve snapCurve, flyOutCurve;
  final double flyOutRotate, restX, restY;
  final String xVariable, yVariable;
  final api.GesturePhysics? physics;
  final api.GestureBounds bounds;
  final double? minX, maxX, minY, maxY;
  final double rotateFactor, originX, originY, disabledFollow;
  final bool shakeWhenDisabled, follow;
  final String shareAs;

  bool get hasBounds => bounds != api.GestureBounds.none || minX != null || maxX != null || minY != null || maxY != null;

  /// The scope name its values are given under besides `drag`.
  String get scopeName => release == FollowRelease.dismiss ? 'dismiss' : 'pan';

  /// [n]'s, or null when it doesn't follow the pointer.
  static FollowSpec? of(Node n) {
    if (n.behaviors.dismissible case final d?) {
      return FollowSpec(
        enabled: d.enabled,
        axis: d.axis,
        release: FollowRelease.dismiss,
        directions: d.directions,
        thresholds: d.dismissThresholds,
        defaultThreshold: api.DismissibleBehavior.defaultThreshold,
        velocityThreshold: d.flingVelocity,
        resistance: d.resistance,
        snapBack: d.effectiveReturnDuration,
        snapCurve: d.effectiveReturnCurve,
        flyOut: d.movementDuration,
        flyOutCurve: d.curve,
        flyOutRotate: d.flyOutRotate,
        restX: d.restX,
        restY: d.restY,
        xVariable: d.xVariable,
        yVariable: d.yVariable,
        physics: d.returnSpring == null ? null : api.GesturePhysics(spring: d.returnSpring!),
        rotateFactor: d.rotateFactor,
        originX: d.originX,
        originY: d.originY,
        shakeWhenDisabled: d.shakeWhenDisabled,
        disabledFollow: d.disabledFollow,
        shareAs: d.shareAs,
        follow: d.follow,
      );
    }
    if (n.behaviors.pan case final p?) {
      return FollowSpec(
        enabled: p.enabled,
        axis: p.axis,
        release: p.release == api.PanRelease.stay ? FollowRelease.stay : FollowRelease.snapBack,
        snapBack: p.returnDuration,
        snapCurve: p.returnCurve,
        restX: p.x,
        restY: p.y,
        xVariable: p.xVariable,
        yVariable: p.yVariable,
        physics: p.physics,
        bounds: p.bounds,
        minX: p.minX,
        maxX: p.maxX,
        minY: p.minY,
        maxY: p.maxY,
        rotateFactor: p.rotateFactor,
        originX: p.originX,
        originY: p.originY,
        shakeWhenDisabled: p.shakeWhenDisabled,
        disabledFollow: p.disabledFollow,
        shareAs: p.shareAs,
        follow: p.follow,
      );
    }
    return null;
  }
}

/// Adds [n]'s drag layer to [chain] (outermost) when it follows the
/// pointer; a running app's tree only.
void dragMotionLayers(NodeBox box, Node n, List<RenderBox> chain) {
  if (!box.tree.animates || !followsPointer(n)) return;
  chain.add(box.obtain<RenderDragMotion>('dragMotion', RenderDragMotion.new)..configure(box, n));
}

extension on api.DragDirection {
  (double, double) get unit => switch (this) {
        api.DragDirection.left => (-1, 0),
        api.DragDirection.right => (1, 0),
        api.DragDirection.up => (0, -1),
        api.DragDirection.down => (0, 1),
      };

  String get swipeTrigger => switch (this) {
        api.DragDirection.left => api.TriggerType.swipeLeft.name,
        api.DragDirection.right => api.TriggerType.swipeRight.name,
        api.DragDirection.up => api.TriggerType.swipeUp.name,
        api.DragDirection.down => api.TriggerType.swipeDown.name,
      };

  bool get horizontal => this == api.DragDirection.left || this == api.DragDirection.right;
}

extension on FollowSpec {
  /// The fraction of the node's size a drag toward [direction] must travel
  /// to dismiss.
  double thresholdFor(api.DragDirection direction) => thresholds[direction] ?? defaultThreshold;

  bool onAxis(api.DragDirection d) => switch (axis) {
        api.DragAxis.free => true,
        api.DragAxis.horizontal => d.horizontal,
        api.DragAxis.vertical => !d.horizontal,
      };

  /// Whether a release can fly off toward [direction].
  bool canDismiss(api.DragDirection direction) =>
      release == FollowRelease.dismiss && directions.contains(direction) && onAxis(direction);
}

/// The drags of nodes in the running app, for the controlDismissible action.
abstract final class DragMotionControl {
  static final Map<String, List<RenderDragMotion>> _instances = {};
  static final Map<String, api.DragDirection> _pendingReturns = {};

  /// Runs [command] on the enabled instance of node [nodeId] that comes
  /// first (in [tree], when given). For [api.DismissCommand.returnFrom] an
  /// instance built in the next frame (the card an undo puts back) starts
  /// off-screen instead of flashing at rest. False when no such node took it.
  static Future<bool> control(String nodeId, api.DismissCommand command, api.DragDirection direction,
      {RenderTree? tree}) async {
    if (command == api.DismissCommand.returnFrom) {
      _pendingReturns[nodeId] = direction;
      await SchedulerBinding.instance.endOfFrame;
      // Consumed by an instance built in that frame.
      if (_pendingReturns.remove(nodeId) == null) return true;
    }
    final target = instanceOf(nodeId, tree: tree);
    if (target == null) return false;
    switch (command) {
      case api.DismissCommand.dismiss:
        await target.fling(direction);
      case api.DismissCommand.returnFrom:
        await target.returnFrom(direction);
      case api.DismissCommand.reset:
        await target.reset();
      case api.DismissCommand.shake:
        target.shake();
    }
    return true;
  }

  /// The instance of [nodeId] an action moves: the first enabled one by
  /// its item index, or the first one when none is enabled.
  static RenderDragMotion? instanceOf(String nodeId, {RenderTree? tree}) {
    final all = [
      for (final r in _instances[nodeId] ?? const <RenderDragMotion>[])
        if (r.attached && !r._dismissed && (tree == null || identical(r._box?.tree, tree))) r,
    ]..sort((a, b) => a.order.compareTo(b.order));
    if (all.isEmpty) return null;
    return all.firstWhere((s) => s._model.enabled, orElse: () => all.first);
  }
}

/// The drag layer of a node that follows the pointer (see the top of this
/// file). [configure]d by its node box on every apply.
class RenderDragMotion extends RenderProxyBox implements HitTestedWhereDrawn {
  RenderDragMotion();

  NodeBox? _box;
  Node? _node;
  FollowSpec _model = FollowSpec.none;
  bool _configured = false;
  String? _registeredAs;

  /// Where the node rests, from where its layout puts it ([api.Pan.x],
  /// [api.Pan.y], bindable as `pan.x`/`pan.y`): it springs back here, and a
  /// new value moves it there.
  Offset _rest = Offset.zero;

  /// Its place among the node's instances: its list item's index.
  int get order => switch (_box?.instance) {
        (_, _, _, final int k) => k,
        _ => 0,
      };

  /// Takes node [n] (as shown) of [box].
  void configure(NodeBox box, Node n) {
    final model = FollowSpec.of(n)!;
    _box = box;
    _node = n;
    final axisChanged = model.axis != _model.axis;
    _model = model;
    final rest = Offset(model.restX, model.restY);
    if (axisChanged) {
      _recognizer?.dispose();
      _recognizer = null;
    }
    if (!_configured) {
      _configured = true;
      _rest = rest;
      _offset = rest;
      _register();
      final back = DragMotionControl._pendingReturns.remove(box.id);
      if (back != null) {
        _offset = _offscreen(back, const Size(300, 400));
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (attached) returnFrom(back);
        });
      }
      _changed(publishNow: false);
      return;
    }
    if (rest != _rest) {
      _rest = rest;
      if (!_dragging && !_dismissed) {
        // Not now: the node is being applied.
        scheduleMicrotask(() {
          if (attached && !_dragging && !_dismissed) _animateTo(_rest, _model.snapBack, _model.snapCurve);
        });
      }
    }
  }

  void _register() {
    final id = _box?.id;
    if (id == null || _registeredAs == id) return;
    _unregister();
    (DragMotionControl._instances[id] ??= []).add(this);
    _registeredAs = id;
  }

  void _unregister() {
    final id = _registeredAs;
    if (id == null) return;
    DragMotionControl._instances[id]?.remove(this);
    if (DragMotionControl._instances[id]?.isEmpty ?? false) DragMotionControl._instances.remove(id);
    _registeredAs = null;
  }

  // --- state -----------------------------------------------------------------

  Offset _offset = Offset.zero;
  bool _dragging = false;
  bool _dismissed = false;
  bool _active = false;
  int _snapIndex = -1;
  int _pointers = 0;
  int _maxPointers = 0;

  /// Extra turn while flying off, in degrees, eased in with the flight.
  double _spin = 0;
  double _spinTo = 0;
  double _spinFrom = 0;
  double _shake = 0;

  bool get _enabled => _model.enabled;

  Size get _size => hasSize ? size : const Size(300, 400);

  /// The live values (tests, the `drag` name).
  DragValues get values {
    final size = _size;
    double p(double distance, api.DragDirection d) => (distance / _thresholdFor(d, size)).clamp(0, 1).toDouble();
    return DragValues(
      offset: _offset,
      left: p(-_offset.dx, api.DragDirection.left),
      right: p(_offset.dx, api.DragDirection.right),
      up: p(-_offset.dy, api.DragDirection.up),
      down: p(_offset.dy, api.DragDirection.down),
      dragging: _dragging,
      dismissed: _dismissed,
      settling: _physicsOn,
      snapIndex: _snapIndex,
    );
  }

  double _thresholdFor(api.DragDirection direction, Size size) =>
      math.max(1, (direction.horizontal ? size.width : size.height) * _model.thresholdFor(direction));

  DragValues? _published;
  DragValues? _shared;
  bool _shareScheduled = false;

  /// Something moved: repaints, tells the nodes inside (`${drag}`) and, after
  /// the frame, the variables it shares.
  void _changed({bool publishNow = true}) {
    markNeedsPaint();
    if (publishNow) {
      _publish();
    } else {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (attached) _publish();
      });
      SchedulerBinding.instance.ensureVisualUpdate();
    }
  }

  void _publish() {
    final box = _box;
    if (box == null) return;
    final current = values;
    if (current != _published) {
      _published = current;
      final local = box.tree.binder?.localScopeOf(box.source, box.id, box.instance);
      final map = current.toMap();
      local?.set('drag', map);
      if (local?.names.contains(_model.scopeName) ?? false) local!.set(_model.scopeName, map);
    }
    final m = _model;
    if (m.shareAs.trim().isEmpty && m.xVariable.trim().isEmpty && m.yVariable.trim().isEmpty) return;
    // Only the instance an action would move (the top card of a stack), or
    // one moving now, shares: the cards resting behind it would otherwise
    // overwrite the live drag with their rest values.
    final sharing = _dragging || _active || identical(DragMotionControl.instanceOf(box.id, tree: box.tree), this);
    if (!sharing || current == _shared || _shareScheduled) return;
    _shareScheduled = true;
    // Shared after the frame: writing a variable re-applies other nodes.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _shareScheduled = false;
      if (!attached) return;
      final now = values;
      if (now == _shared) return;
      _shared = now;
      _share(now);
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  ValueScope? get _scope {
    final box = _box;
    return box?.tree.binder?.scopeFor(box.source, box.id, box.instance);
  }

  void _share(DragValues values) {
    final scope = _scope;
    if (scope == null) return;
    final m = _model;
    if (m.shareAs.trim().isNotEmpty) setVariableIn(scope, m.shareAs.trim(), values.toMap());
    _writeOffset(scope, m.xVariable, values.offset.dx);
    _writeOffset(scope, m.yVariable, values.offset.dy);
  }

  /// Writes [offset], rounded to hundredths, into the number variable
  /// [name] (a computed variable is left as it is).
  static void _writeOffset(ValueScope scope, String name, double offset) {
    if (name.trim().isEmpty) return;
    final rounded = (offset * 100).round() / 100;
    final num value = rounded == rounded.roundToDouble() ? rounded.round() : rounded;
    setVariableIn(scope, name.trim(), value);
  }

  /// Turns the `dragged` state of the node and the nodes in it on or off
  /// (those that style it).
  void _setDragged(bool on) {
    final box = _box;
    if (box == null) return;
    final tree = box.tree;
    final ids = <String>[];
    void visit(String id) {
      final n = tree.source.node(id);
      if (n == null) return;
      if (n.behaviors.states.patches.containsKey(api.WidgetState.dragged)) ids.add(id);
      n.children.forEach(visit);
    }

    visit(box.id);
    for (final id in ids) {
      tree.setState(id, api.WidgetState.dragged, on, instance: box.instance);
    }
  }

  // --- ticking -----------------------------------------------------------------

  Ticker? _ticker;
  Duration _clock = Duration.zero;

  // The curve-timed animation (spring back, fly off, return, shake).
  bool _animOn = false;
  Duration? _animStart;
  int _animMs = 1;
  Offset _from = Offset.zero;
  Offset _to = Offset.zero;
  api.AnimationCurve _curve = api.AnimationCurve.linear;
  Completer<void>? _animDone;

  // The physics settle.
  bool _physicsOn = false;
  Duration? _physicsStart;
  final SimulationGroup _sims = SimulationGroup();

  void _syncTicker() {
    final run = (_animOn || _physicsOn) && (attached || (_ticker?.isActive ?? false));
    if (run) {
      _ticker ??= Ticker(_tick, debugLabel: 'drag');
      if (!_ticker!.isActive) {
        _clock = Duration.zero;
        _ticker!.start();
      }
    } else if (_ticker?.isActive ?? false) {
      _ticker!.stop();
    }
  }

  void _tick(Duration elapsed) {
    _clock = elapsed;
    if (_animOn) _animTick();
    if (_physicsOn) _physicsTick();
    _syncTicker();
  }

  /// Stops the curve-timed animation; its future completes.
  void _stopAnim() {
    if (!_animOn) return;
    _animOn = false;
    _active = false;
    final done = _animDone;
    _animDone = null;
    done?.complete();
    _syncTicker();
  }

  Future<void> _runAnim(int ms) {
    _stopAnim();
    _animMs = math.max(1, ms);
    _animStart = null;
    _animOn = true;
    final done = _animDone = Completer<void>();
    _syncTicker();
    return done.future;
  }

  void _animTick() {
    final start = _animStart ??= _clock;
    final value = ((_clock - start).inMicroseconds / 1000 / _animMs).clamp(0.0, 1.0);
    final t = _curve.transform(value);
    if (_shake > 0) {
      // A damped sideways wiggle.
      _offset = _rest + Offset(math.sin(value * math.pi * 6) * _shake * (1 - value), 0);
    } else {
      _offset = Offset.lerp(_from, _to, t)!;
      if (_spinTo != 0) {
        _spin = _spinTo * t;
      } else if (_spinFrom != 0) {
        _spin = _spinFrom * (1 - t);
      }
    }
    if (value >= 1) {
      _animOn = false;
      _active = false;
      final done = _animDone;
      _animDone = null;
      if (_shake > 0) {
        _shake = 0;
        _offset = _rest;
      }
      _changed();
      done?.complete();
      return;
    }
    _changed();
  }

  Future<void> _animateTo(Offset to, int ms, api.AnimationCurve curve) async {
    _stopPhysics();
    final physics = _model.physics;
    if (physics != null && !_dismissed && to == _rest && _spin == 0) {
      // A spring back with physics springs, at any speed it already has.
      _settle(_springSims(physics, to, Offset.zero));
      return;
    }
    _shake = 0;
    // Unwind any turn left over (a returning card).
    _spinFrom = _spinTo == 0 && _spin != 0 ? _spin : 0;
    _from = _offset;
    _to = to;
    _curve = curve;
    _active = true;
    final done = _runAnim(ms);
    _active = true;
    await done;
  }

  void _stopPhysics() {
    if (!_physicsOn && _sims.isEmpty) return;
    _physicsOn = false;
    _sims.clear();
    _syncTicker();
  }

  void _settle(Map<String, Simulation> sims) {
    _stopPhysics();
    sims.forEach(_sims.set);
    if (_sims.isDone(0)) {
      _sims.clear();
      return;
    }
    _active = true;
    _physicsStart = null;
    _physicsOn = true;
    _syncTicker();
  }

  void _physicsTick() {
    final start = _physicsStart ??= _clock;
    final t = (_clock - start).inMicroseconds / Duration.microsecondsPerSecond;
    _offset = Offset(_sims.x('x', t) ?? _offset.dx, _sims.x('y', t) ?? _offset.dy);
    if (_sims.isDone(t)) {
      _offset = Offset(_sims.finalOf('x'), _sims.finalOf('y'));
      _physicsOn = false;
      _sims.clear();
      _active = false;
    }
    _changed();
  }

  // --- physics -------------------------------------------------------------------

  /// The offsets the node may take, from its bounds and limits.
  Rect get _range {
    final m = _model;
    var left = double.negativeInfinity, right = double.infinity;
    var top = double.negativeInfinity, bottom = double.infinity;
    if (m.bounds != api.GestureBounds.none) {
      final view = _viewport();
      final size = _size;
      if (view != null) {
        (left, right) = boundsRange(
            bounds: m.bounds, center: size.width / 2, half: size.width / 2, viewLo: view.left, viewHi: view.right);
        (top, bottom) = boundsRange(
            bounds: m.bounds, center: size.height / 2, half: size.height / 2, viewLo: view.top, viewHi: view.bottom);
      }
    }
    if (m.minX != null) left = math.max(left, _rest.dx + m.minX!);
    if (m.maxX != null) right = math.min(right, _rest.dx + m.maxX!);
    if (m.minY != null) top = math.max(top, _rest.dy + m.minY!);
    if (m.maxY != null) bottom = math.min(bottom, _rest.dy + m.maxY!);
    if (left > right) left = right = (left + right) / 2;
    if (top > bottom) top = bottom = (top + bottom) / 2;
    return Rect.fromLTRB(left, top, right, bottom);
  }

  /// The parent's layout box, in the node's layout coordinates.
  Rect? _viewport() {
    if (!attached || !hasSize) return null;
    RenderObject? ancestor = parent;
    while (ancestor != null && ancestor is! ContainerRenderObjectMixin) {
      ancestor = ancestor.parent;
    }
    if (ancestor is! RenderBox || !ancestor.hasSize) return null;
    final back = Matrix4.tryInvert(getTransformTo(ancestor));
    if (back == null) return null;
    return MatrixUtils.transformRect(back, Offset.zero & ancestor.size);
  }

  /// The offsets that put the node flush with each of its parent's edges,
  /// for [api.SnapKind.edges].
  Rect? get _edges {
    final view = _viewport();
    if (view == null) return null;
    final size = _size;
    return Rect.fromLTRB(view.left, view.top, view.right - size.width, view.bottom - size.height);
  }

  /// [offset] held back past the range like a rubber band.
  Offset _band(Offset offset) {
    final physics = _model.physics;
    if (physics == null || !_model.hasBounds) return offset;
    final r = _range;
    return Offset(
      rubberBand(offset.dx, r.left, r.right, physics.overscroll),
      rubberBand(offset.dy, r.top, r.bottom, physics.overscroll),
    );
  }

  Map<String, Simulation> _springSims(api.GesturePhysics physics, Offset to, Offset velocity) => {
        'x': AxisSettleSimulation.spring(physics: physics, position: _offset.dx, velocity: velocity.dx, target: to.dx),
        'y': AxisSettleSimulation.spring(physics: physics, position: _offset.dy, velocity: velocity.dy, target: to.dy),
      };

  /// What a release at [velocity] settles on, as simulations of x and y,
  /// and where they end and the snap index.
  ({Map<String, Simulation> sims, Offset target, int snap}) _releaseSims(api.GesturePhysics physics, Offset velocity) {
    final v = switch (_model.axis) {
      api.DragAxis.free => velocity,
      api.DragAxis.horizontal => Offset(velocity.dx, 0),
      api.DragAxis.vertical => Offset(0, velocity.dy),
    };
    if (_model.release != FollowRelease.stay) {
      return (sims: _springSims(physics, _rest, v), target: _rest, snap: -1);
    }
    final range = _range;
    final snap = snapTargetOf(
      physics: physics,
      position: _offset - _rest,
      velocity: v,
      range: range.shift(-_rest),
      edges: _edges?.shift(-_rest),
      axis: _model.axis,
    );
    if (snap != null) {
      final target = _rest + snap.offset;
      return (sims: _springSims(physics, target, v), target: target, snap: snap.index);
    }
    final x = AxisSettleSimulation.release(
        physics: physics, position: _offset.dx, velocity: v.dx, lo: range.left, hi: range.right);
    final y = AxisSettleSimulation.release(
        physics: physics, position: _offset.dy, velocity: v.dy, lo: range.top, hi: range.bottom);
    return (sims: {'x': x, 'y': y}, target: Offset(x.finalX, y.finalX), snap: -1);
  }

  /// Whether the pointer may pull toward [direction] freely.
  bool _free(api.DragDirection direction) {
    if (!_model.onAxis(direction)) return false;
    if (_model.release != FollowRelease.dismiss) return true;
    return _model.directions.contains(direction);
  }

  /// [raw] pointer travel turned into node travel: locked off its axis,
  /// held back by resistance toward directions that can't dismiss.
  Offset _resist(Offset raw) {
    double along(double v, api.DragDirection neg, api.DragDirection pos) {
      final d = v < 0 ? neg : pos;
      if (_free(d)) return v;
      if (!_model.onAxis(d)) return 0;
      final r = _model.resistance.clamp(0, 1).toDouble();
      if (r >= 1) return 0;
      // Rubber band: moves less and less the further it is pulled.
      const reach = 120.0;
      final k = 1 - r;
      return v.sign * reach * k * (1 - math.exp(-v.abs() / reach));
    }

    return Offset(
      along(raw.dx, api.DragDirection.left, api.DragDirection.right),
      along(raw.dy, api.DragDirection.up, api.DragDirection.down),
    );
  }

  // --- gestures ----------------------------------------------------------------

  DragGestureRecognizer? _recognizer;
  Offset _raw = Offset.zero;
  Offset? _lastGlobal;

  /// Whether the current drag is of a disabled node, which only follows by
  /// [FollowSpec.disabledFollow] and always springs back.
  bool _blocked = false;

  DragGestureRecognizer _ensureRecognizer() => _recognizer ??= (switch (_model.axis) {
        // A drag locked to one axis only claims moves along it, so a scroll
        // across it still scrolls.
        api.DragAxis.horizontal => HorizontalDragGestureRecognizer(debugOwner: this),
        api.DragAxis.vertical => VerticalDragGestureRecognizer(debugOwner: this),
        api.DragAxis.free => PanGestureRecognizer(debugOwner: this),
      })
        // Moves from where the finger went down: the node keeps up with it
        // instead of lagging by the touch slop.
        ..dragStartBehavior = DragStartBehavior.down
        ..onStart = _onStart
        ..onUpdate = _onUpdate
        ..onEnd = _onEnd
        ..onCancel = () {
          if (_dragging) _onEnd(DragEndDetails());
        };

  Node? get _liveNode => _box?.node ?? _node;

  bool _reactsTo(String trigger) => _liveNode?.actions.any((r) => r.trigger.type.name == trigger) ?? false;

  void _fire(String trigger, Json result) {
    final box = _box;
    if (box != null && _reactsTo(trigger)) fireTrigger(box, trigger, event: {'result': result});
  }

  void _onStart(DragStartDetails details) {
    if (_dismissed) return;
    _blocked = !_enabled;
    if (_blocked && _model.disabledFollow <= 0) {
      if (_model.shakeWhenDisabled && !_animOn) _shakeOnce();
      _fire('dragEnd', {'blocked': true, 'dismissed': false, 'direction': ''});
      return;
    }
    _stopAnim();
    _stopPhysics();
    _active = false;
    _shake = 0;
    _raw = _offset;
    _lastGlobal = details.globalPosition;
    _maxPointers = math.max(1, _pointers);
    _dragging = true;
    _setDragged(true);
    _changed();
  }

  void _onUpdate(DragUpdateDetails details) {
    if (!_dragging) return;
    // Moves in screen space: the node's own tilt doesn't turn them.
    final delta = details.globalPosition - (_lastGlobal ?? details.globalPosition - details.delta);
    _lastGlobal = details.globalPosition;
    _raw += delta;
    final before = _offset;
    _offset = _blocked ? _raw * _model.disabledFollow.clamp(0, 1).toDouble() : _band(_resist(_raw));
    _maxPointers = math.max(_maxPointers, _pointers);
    _changed();
    _fire('drag', {
      'dx': _offset.dx - _rest.dx,
      'dy': _offset.dy - _rest.dy,
      'deltaX': _offset.dx - before.dx,
      'deltaY': _offset.dy - before.dy,
      'pointerCount': _maxPointers,
    });
  }

  void _onEnd(DragEndDetails details) {
    if (!_dragging) return;
    _dragging = false;
    _setDragged(false);
    _changed();
    final velocity = details.velocity.pixelsPerSecond;
    if (_blocked) {
      _fire('dragEnd', {
        'dx': _offset.dx,
        'dy': _offset.dy,
        'velocityX': velocity.dx,
        'velocityY': velocity.dy,
        'dismissed': false,
        'direction': '',
        'blocked': true,
      });
      _animateTo(_rest, _model.snapBack, _model.snapCurve).then((_) {
        if (attached && _model.shakeWhenDisabled) _shakeOnce();
      });
      return;
    }
    final direction = _dismissDirection(velocity);
    final physics = _model.physics;
    final settle = direction == null && physics != null ? _releaseSims(physics, velocity) : null;
    _snapIndex = settle?.snap ?? -1;
    _fire('dragEnd', {
      'dx': _offset.dx,
      'dy': _offset.dy,
      'velocityX': velocity.dx,
      'velocityY': velocity.dy,
      'dismissed': direction != null,
      'direction': direction?.name ?? '',
      'blocked': false,
      'pointerCount': _maxPointers,
      if (settle != null) ...{
        'targetX': settle.target.dx - _rest.dx,
        'targetY': settle.target.dy - _rest.dy,
        'snapIndex': settle.snap,
      },
    });
    if (direction != null) {
      _flyOff(direction, velocity);
    } else if (settle != null) {
      _settle(settle.sims);
    } else if (_model.release != FollowRelease.stay) {
      _animateTo(_rest, _model.snapBack, _model.snapCurve);
    }
  }

  static api.DragDirection _directionOf(Offset v) => v.dx.abs() >= v.dy.abs()
      ? (v.dx < 0 ? api.DragDirection.left : api.DragDirection.right)
      : (v.dy < 0 ? api.DragDirection.up : api.DragDirection.down);

  /// The direction a release at [velocity] dismisses toward, if any.
  api.DragDirection? _dismissDirection(Offset velocity) {
    if (_model.release != FollowRelease.dismiss) return null;
    final size = _size;
    if (_offset != Offset.zero) {
      final d = _directionOf(_offset);
      final travel = switch (d) {
        api.DragDirection.left => -_offset.dx,
        api.DragDirection.right => _offset.dx,
        api.DragDirection.up => -_offset.dy,
        api.DragDirection.down => _offset.dy,
      };
      if (_model.canDismiss(d) && travel >= _thresholdFor(d, size)) return d;
    }
    if (velocity.distance >= _model.velocityThreshold) {
      final d = _directionOf(velocity);
      final (ux, uy) = d.unit;
      final along = velocity.dx * ux + velocity.dy * uy;
      if (_model.canDismiss(d) && along >= _model.velocityThreshold) return d;
    }
    return null;
  }

  static Size get _screenSize {
    final view = SchedulerBinding.instance.platformDispatcher.views.firstOrNull;
    if (view == null) return const Size(1200, 900);
    return view.physicalSize / view.devicePixelRatio;
  }

  Offset _offscreen(api.DragDirection direction, Size size, [Offset? along]) {
    final screen = _screenSize;
    final far = math.max(screen.width, screen.height) + size.longestSide * 1.2;
    final (ux, uy) = direction.unit;
    // Keep going the way it was thrown, mostly along the direction.
    var heading = Offset(ux, uy);
    if (along != null && along.distance > 0) {
      final a = along / along.distance;
      heading = Offset(ux + a.dx * 0.5, uy + a.dy * 0.5);
      heading = heading / heading.distance;
    }
    return _offset + heading * far;
  }

  Future<void> _flyOff(api.DragDirection direction, [Offset? velocity]) async {
    _spinTo = switch (direction) {
      api.DragDirection.left || api.DragDirection.up => -_model.flyOutRotate,
      api.DragDirection.right || api.DragDirection.down => _model.flyOutRotate,
    };
    final target = _offscreen(direction, _size, velocity == null || velocity == Offset.zero ? _offset : velocity);
    await _animateTo(target, _model.flyOut, _model.flyOutCurve);
    if (!attached) return;
    _dismissed = true;
    _changed();
    final box = _box;
    if (box != null && _reactsTo(direction.swipeTrigger)) {
      await runTrigger(box, direction.swipeTrigger, event: {
        'result': {'direction': direction.name},
      });
    }
    if (!attached) return;
    SchedulerBinding.instance.ensureVisualUpdate();
    await SchedulerBinding.instance.endOfFrame;
    if (!attached || !_dismissed) return;
    // Still here: the node shows its next content, back at rest.
    _dismissed = false;
    _offset = _rest;
    _spin = _spinTo = 0;
    _changed();
  }

  void _shakeOnce() {
    _shake = 12;
    _curve = api.AnimationCurve.linear;
    _runAnim(420);
  }

  // --- commands ------------------------------------------------------------------

  /// Wiggles sideways once, as a hint that the node can't go yet.
  void shake() {
    if (_dismissed || _dragging || _animOn) return;
    _shakeOnce();
  }

  /// Flies off toward [direction] as if swiped, then reports it.
  Future<void> fling(api.DragDirection direction) async {
    if (_dismissed || _active && _to != _rest) return;
    _stopAnim();
    await _flyOff(direction);
  }

  /// Flies in from off-screen toward [direction] to rest.
  Future<void> returnFrom(api.DragDirection direction) async {
    _stopAnim();
    // Comes back unwinding the turn it left with.
    final turn = switch (direction) {
      api.DragDirection.left || api.DragDirection.up => -_model.flyOutRotate,
      api.DragDirection.right || api.DragDirection.down => _model.flyOutRotate,
    };
    _dismissed = false;
    _offset = _offscreen(direction, _size) - _offset;
    _spin = turn;
    _spinTo = 0;
    _changed();
    await _animateTo(_rest, math.max(_model.flyOut, 380), api.AnimationCurve.easeOutCubic);
  }

  /// Springs back to rest.
  Future<void> reset() async {
    _stopAnim();
    _dismissed = false;
    _changed();
    await _animateTo(_rest, _model.snapBack, _model.snapCurve);
  }

  // --- render ---------------------------------------------------------------------

  /// The tilt, in degrees.
  double get _angle => _offset.dx / math.max(1, _size.width) * _model.rotateFactor + _spin;

  /// The transform over the node's layout: none while at rest or when the
  /// drag only reports ([FollowSpec.follow] off).
  Matrix4? get _transform {
    final angle = _angle;
    if (!_model.follow || (_offset == Offset.zero && angle == 0)) return null;
    final origin = Alignment(_model.originX, _model.originY).alongSize(_size);
    return Matrix4.translationValues(origin.dx, origin.dy, 0)
      ..translateByDouble(_offset.dx, _offset.dy, 0, 1)
      ..rotateZ(angle * math.pi / 180)
      ..translateByDouble(-origin.dx, -origin.dy, 0, 1);
  }

  /// The translation and turn it draws the node with now, about its
  /// origin (tests).
  @visibleForTesting
  Matrix4 get debugTransform => Matrix4.translationValues(_offset.dx, _offset.dy, 0)..rotateZ(_angle * math.pi / 180);

  final LayerHandle<TransformLayer> _layer = LayerHandle();

  @override
  bool get alwaysNeedsCompositing => child != null;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_dismissed || child == null) {
      _layer.layer = null;
      return;
    }
    // Always a transform layer (identity at rest): the node isn't
    // re-composited when a drag starts.
    _layer.layer = context.pushTransform(
      needsCompositing,
      offset,
      _transform ?? Matrix4.identity(),
      super.paint,
      oldLayer: _layer.layer,
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final m = _transform;
    if (m != null) transform.multiply(m);
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (_dismissed) return false;
    // Grabbed where it is drawn: an open sheet by its visible top.
    return result.addWithPaintTransform(
      transform: _transform,
      position: position,
      hitTest: (result, p) {
        if (!size.contains(p)) return false;
        final hit = child?.hitTest(result, position: p) ?? false;
        // Translucent: it takes the drag and lets what's under it be hit.
        result.add(BoxHitTestEntry(this, p));
        return hit;
      },
    );
  }

  @override
  void handleEvent(PointerEvent event, HitTestEntry entry) {
    if (event is PointerDownEvent) {
      _pointers++;
      _ensureRecognizer().addPointer(event);
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      _pointers = math.max(0, _pointers - 1);
    }
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _register();
    _syncTicker();
  }

  @override
  void detach() {
    super.detach();
    // Re-applying the node moves its layers (a detach and an attach): only
    // a layer still out after the frame stops.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (attached) return;
      _ticker?.stop();
      _unregister();
      if (_dragging) {
        _dragging = false;
        _setDragged(false);
      }
    });
  }

  @override
  void dispose() {
    _layer.layer = null;
    _ticker?.dispose();
    _ticker = null;
    _recognizer?.dispose();
    _recognizer = null;
    final done = _animDone;
    _animDone = null;
    done?.complete();
    super.dispose();
  }
}
