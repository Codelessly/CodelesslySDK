// Pinch, pan and rotate, as one render
// object of a node's chain in a running app: pinch and ctrl+wheel zoom
// about the focal point, one finger pans, two rotate, a double tap zooms
// to a point, and a release flings and settles by the gesture's physics
// within its bounds and scale limits. With handles the node is an
// editable object (corners scale it, edges stretch it, a knob turns it).
// The pose binds two-way to variables, the node and the nodes inside it
// read it as `${transform.*}`, and changes run the node's `changed`,
// `changeEnd` and `doubleTap` reactions.
//
// The design canvas has no layer: the node rests where its layout puts it.
import 'dart:async';
import 'dart:math' as math;

import 'package:codelessly_api/core.dart' as api;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'behaviors.dart' show RenderPose;
import 'contracts.dart';
import 'convert.dart';
import 'node_tree.dart';
import 'physics.dart';

/// Where a transform gesture draws its node: offset, scale, rotation and
/// stretch, about the node's center.
@immutable
class TransformPose {
  const TransformPose({this.x = 0, this.y = 0, this.scale = 1, this.rotation = 0, this.scaleX = 1, this.scaleY = 1});

  final double x, y, scale, rotation, scaleX, scaleY;

  static const TransformPose identity = TransformPose();
  static const List<String> keys = ['x', 'y', 'scale', 'rotation', 'scaleX', 'scaleY'];

  TransformPose copyWith({double? x, double? y, double? scale, double? rotation, double? scaleX, double? scaleY}) =>
      TransformPose(
        x: x ?? this.x,
        y: y ?? this.y,
        scale: scale ?? this.scale,
        rotation: rotation ?? this.rotation,
        scaleX: scaleX ?? this.scaleX,
        scaleY: scaleY ?? this.scaleY,
      );

  double operator [](String key) => switch (key) {
    'x' => x,
    'y' => y,
    'scale' => scale,
    'rotation' => rotation,
    'scaleX' => scaleX,
    'scaleY' => scaleY,
    _ => 0,
  };

  TransformPose withValue(String key, double value) => switch (key) {
    'x' => copyWith(x: value),
    'y' => copyWith(y: value),
    'scale' => copyWith(scale: value),
    'rotation' => copyWith(rotation: value),
    'scaleX' => copyWith(scaleX: value),
    'scaleY' => copyWith(scaleY: value),
    _ => this,
  };

  /// [value] rounded as a pose is written to variables: pixels and degrees
  /// to hundredths, scales to thousandths (six significant digits below .01).
  static num rounded(String key, double value) {
    // Rounding a tiny zoom to thousandths could write zero, which then
    // reset a two-way pose instead of retaining its valid minimum scale.
    if (key.startsWith('scale') && value != 0 && value.abs() < .01) {
      return double.parse(value.toStringAsPrecision(6));
    }
    final places = key.startsWith('scale') ? 1000 : 100;
    final num r = (value * places).round() / places;
    return r == r.roundToDouble() ? r.round() : r;
  }

  bool sameAs(TransformPose other) => keys.every((k) => rounded(k, this[k]) == rounded(k, other[k]));

  Map<String, num> toMap() => {for (final k in keys) k: rounded(k, this[k])};

  /// The pose about the center of a [size] box, in its coordinates.
  Matrix4 matrixFor(Size size) {
    final c = size.center(Offset.zero);
    return Matrix4.translationValues(c.dx + x, c.dy + y, 0)
      ..rotateZ(rotation * math.pi / 180)
      ..scaleByDouble(scale * scaleX, scale * scaleY, 1, 1)
      ..translateByDouble(-c.dx, -c.dy, 0, 1);
  }

  @override
  bool operator ==(Object other) =>
      other is TransformPose &&
      other.x == x &&
      other.y == y &&
      other.scale == scale &&
      other.rotation == rotation &&
      other.scaleX == scaleX &&
      other.scaleY == scaleY;

  @override
  int get hashCode => Object.hash(x, y, scale, rotation, scaleX, scaleY);

  @override
  String toString() => 'TransformPose($x, $y, ×$scale, $rotation°, $scaleX, $scaleY)';
}

/// A scale recognizer that, while [canAccept] says no, never claims the
/// arena itself: a one-finger drag on a photo at rest goes to the page view
/// around it, while a second finger still makes it a pinch.
class TransformScaleGestureRecognizer extends ScaleGestureRecognizer {
  TransformScaleGestureRecognizer({super.debugOwner});

  bool Function(int pointers) canAccept = _always;
  static bool _always(int pointers) => true;

  @override
  // ignore: must_call_super
  void resolve(GestureDisposition disposition) {
    if (disposition == GestureDisposition.accepted && !canAccept(pointerCount)) return;
    super.resolve(disposition);
  }
}

/// The transform gestures of a tree's nodes on screen, by node id: what a
/// control drag action's reset springs back.
abstract final class TransformGestures {
  static final Expando<Map<String, Set<RenderTransformGesture>>> _byTree = Expando('transformGestures');

  /// Whether node [nodeId] of [tree] has a transform gesture on screen.
  static bool has(RenderTree tree, String nodeId) => _byTree[tree]?[nodeId]?.isNotEmpty ?? false;

  /// [has], for a tree that may be missing.
  static bool hasIn(RenderTree? tree, String nodeId) => tree != null && has(tree, nodeId);

  /// Springs every instance of [nodeId] back to its rest pose (no offset,
  /// scale 1, no rotation or stretch), writing its variables.
  static Future<void> reset(RenderTree tree, String nodeId) async {
    for (final t in [...?_byTree[tree]?[nodeId]]) {
      if (t.attached) t.reset();
    }
  }

  /// Zooms every instance of [nodeId] by [factor] about the middle of what
  /// its viewport shows, springing there (zoom buttons).
  static Future<void> zoom(RenderTree tree, String nodeId, double factor) async {
    for (final t in [...?_byTree[tree]?[nodeId]]) {
      if (t.attached) t.zoomBy(factor);
    }
  }

  /// Springs every instance of [nodeId] to [pose] (`x`, `y`, `scale`,
  /// `rotation`, `scaleX`, `scaleY`; keys left out are kept), within its
  /// scale limits and bounds, even when that's where a bound pose already
  /// says (a "fit" button after the user panned away).
  static Future<void> moveTo(RenderTree tree, String nodeId, Map<String, double> pose) async {
    for (final t in [...?_byTree[tree]?[nodeId]]) {
      if (t.attached) t.moveTo(pose);
    }
  }
}

/// A node's [api.TransformGesture] in a running app.
class RenderTransformGesture extends RenderPose implements MouseTrackerAnnotation {
  RenderTransformGesture() {
    _scale = TransformScaleGestureRecognizer(debugOwner: this)
      // Scales and turns count from where the fingers went down.
      ..dragStartBehavior = DragStartBehavior.down
      // A pan claims at 16px, ahead of a scroll's 18px touch slop.
      ..gestureSettings = const DeviceGestureSettings(touchSlop: 8)
      ..canAccept = _canAccept
      ..onStart = _onScaleStart
      ..onUpdate = _onScaleUpdate
      ..onEnd = _onScaleEnd;
    _doubleTap = DoubleTapGestureRecognizer(debugOwner: this)
      ..onDoubleTapDown = ((d) => _doubleTapAt = d.globalPosition)
      ..onDoubleTap = _onDoubleTap;
    _tap = TapGestureRecognizer(debugOwner: this)..onTap = _select;
  }

  NodeBox? _box;
  api.TransformGesture _model = const api.TransformGesture();
  BoundValues? _scope;

  /// The pose's variables (two-way), by pose key, and their watchers.
  final Map<String, String> _variables = {};
  final List<Listenable> _watched = [];

  bool _enabled = true;
  bool _selected = true;

  /// Sets the gesture up from its node, as shown ([model] with its
  /// bindings applied).
  void configure(NodeBox? box, api.TransformGesture model) {
    final oldBox = _box;
    if (!identical(oldBox, box) && _registered) _unregister();
    _box = box;
    final modelChanged = model != _model;
    _model = model;
    _enabled = model.enabled;
    _scope = box?.tree.bindings?.valuesFor(box.source, box.id, box.instance);
    _variables
      ..clear()
      ..addAll({
        for (final (k, name) in [
          ('x', model.xVariable),
          ('y', model.yVariable),
          ('scale', model.scaleVariable),
          ('rotation', model.rotationVariable),
          ('scaleX', model.scaleXVariable),
          ('scaleY', model.scaleYVariable),
        ])
          if (name.trim().isNotEmpty) k: name.trim(),
      });
    _rewatch();
    _selected = _isSelected();
    if (model.target == api.TransformTarget.node || model.handles != null) box?.outsideHitTest = _hitOutside;
    if (!_configured) {
      _configured = true;
      _pose = _with(TransformPose.identity, _given());
      _written = _pose;
    } else {
      _onGiven();
    }
    if (attached) _syncRegistration();
    if (modelChanged) markNeedsPaint();
    _show(later: true);
  }

  bool _configured = false;

  // --- the pose given from outside ------------------------------------------------------

  static double? _number(Object? v) => switch (v) {
    final num n => n.toDouble(),
    final String s => double.tryParse(s.trim()),
    _ => null,
  };

  /// The pose's values given from variables (else bindings), by key.
  Map<String, double> _given() {
    final out = <String, double>{};
    for (final k in TransformPose.keys) {
      final name = _variables[k];
      var v = name == null ? null : _number(_scope?.read(name));
      v ??= switch (k) {
        'x' => _model.x,
        'y' => _model.y,
        'scale' => _model.scale,
        'rotation' => _model.rotation,
        'scaleX' => _model.scaleX,
        _ => _model.scaleY,
      };
      if (v != null) out[k] = v;
    }
    return out;
  }

  void _rewatch() {
    for (final w in _watched) {
      w.removeListener(_onVariable);
    }
    _watched.clear();
    final scope = _scope;
    if (scope == null) return;
    // One watcher per name (paths into one variable share theirs).
    final names = {..._variables.values, if (_selectionName.isNotEmpty) _selectionName};
    for (final n in names) {
      final w = scope.watch(n);
      if (w != null && !_watched.contains(w)) _watched.add(w);
    }
    if (attached) {
      for (final w in _watched) {
        w.addListener(_onVariable);
      }
    }
  }

  void _onVariable() {
    if (_writing) return;
    final selected = _isSelected();
    if (selected != _selected) {
      _selected = selected;
      markNeedsPaint();
      _show();
    }
    _onGiven();
  }

  TransformPose _with(TransformPose base, Map<String, double> values) {
    var out = base;
    values.forEach((k, v) => out = out.withValue(k, v));
    return out;
  }

  static bool _matches(TransformPose pose, Map<String, double> values) =>
      values.entries.every((e) => TransformPose.rounded(e.key, e.value) == TransformPose.rounded(e.key, pose[e.key]));

  /// A changed given pose springs the node there, after the frame (it
  /// writes variables back and runs reactions).
  void _onGiven() {
    final given = _given();
    if (_writing || given.isEmpty || _gestureActive) return;
    if (_written != null && _matches(_written!, given)) return;
    if (_matches(_pose, given)) return;
    final changed = {
      for (final e in given.entries)
        if (TransformPose.rounded(e.key, e.value) != TransformPose.rounded(e.key, _pose[e.key])) e.key,
    };
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!attached || _gestureActive) return;
      _fromOutside(_with(_pose, given), onlyScale: changed.length == 1 && changed.first == 'scale');
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  // --- selection --------------------------------------------------------------------------

  String get _selectionName => _model.handles?.selectionVariable.trim() ?? '';

  String get _selectionKey {
    final key = _model.handles?.selectionKey ?? '';
    if (key.trim().isEmpty || _scope == null) return key.trim().isEmpty ? (_box?.id ?? '') : key;
    final box = _box;
    return box == null ? key : _scope!.interpolate(key);
  }

  bool _isSelected() {
    final name = _selectionName;
    if (name.isEmpty || _scope == null) return true;
    return '${_scope!.read(name)}' == _selectionKey;
  }

  void _select() {
    final name = _selectionName;
    final scope = _scope;
    if (name.isEmpty || scope == null) return;
    final key = _selectionKey;
    if ('${scope.read(name)}' == key) return;
    scope.write(name, key);
  }

  // --- reporting --------------------------------------------------------------------------

  TransformPose _pose = TransformPose.identity;
  TransformPose? _written;
  String _gesture = 'pan';
  bool _gestureActive = false;
  int _pointerCount = 0;
  Offset _lastVelocity = Offset.zero;
  Timer? _wheelEnd;

  /// The pose now.
  TransformPose get pose => _pose;

  bool get _active => _gestureActive || (_ticker?.isActive ?? false);

  Map<String, Object?> _result([Offset velocity = Offset.zero]) => {
    ..._pose.toMap(),
    'pointerCount': _pointerCount,
    'gesture': _gesture,
    'velocityX': velocity.dx,
    'velocityY': velocity.dy,
  };

  void _fire(String trigger, Map<String, Object?> result) {
    final box = _box;
    if (box == null) return;
    if (!box.node!.actions.any((r) => r.trigger.type.name == trigger)) return;
    fireTrigger(box, trigger, event: {'result': result});
  }

  /// Writes [pose] to the bound variables (rounded; computed ones and
  /// unchanged values skipped).
  void _writePose(TransformPose pose) {
    final scope = _scope;
    if (scope == null) return;
    // Its own writes come back through the variables: read them once, after.
    _writing = true;
    try {
      _writeEach(scope, pose);
    } finally {
      _writing = false;
    }
  }

  bool _writing = false;

  void _writeEach(BoundValues scope, TransformPose pose) {
    // A write can synchronously reconfigure this node through its bindings.
    for (final e in _variables.entries.toList()) {
      final found = scope.variable(e.value);
      if (found == null || found.isComputed) continue;
      final value = TransformPose.rounded(e.key, pose[e.key]);
      if ('${scope.read(e.value)}' == '$value') continue;
      scope.write(e.value, value);
    }
  }

  void _set(TransformPose next, {bool report = true}) {
    if (next == _pose) return;
    _pose = next;
    _show();
    if (!report) return;
    if (_variables.isNotEmpty && (_written == null || !next.sameAs(_written!))) {
      _written = next;
      _writePose(next);
    }
    _fire('changed', _result());
  }

  void _finish() {
    if (_down > 0 && _gestureActive) {
      // A finger is still on the node: end when it lifts.
      _endPending = true;
      return;
    }
    _endPending = false;
    _fire('changeEnd', _result(_lastVelocity));
    _show();
  }

  Map<String, Object?>? _published;
  bool _publishScheduled = false;

  /// Draws the pose and gives `${transform}` (now, or after the current
  /// work when [later]).
  void _show({bool later = false}) {
    transform = _pose.matrixFor(hasSize ? size : Size.zero);
    origin = Alignment.topLeft;
    if (!later) return _publish();
    if (_publishScheduled) return;
    _publishScheduled = true;
    scheduleMicrotask(() {
      _publishScheduled = false;
      _publish();
    });
  }

  void _publish() {
    final box = _box;
    if (box == null) return;
    final values = {..._pose.toMap(), 'active': _active, 'selected': _selected};
    if (mapEquals(values, _published)) return;
    _published = values;
    box.tree.bindings?.publish(box.source, box.id, box.instance, 'transform', values);
  }

  // --- geometry ---------------------------------------------------------------------------

  Offset get _center => (hasSize ? size : Size.zero).center(Offset.zero);

  /// The box the node is kept inside, in its layout coordinates: its own
  /// box for content, its parent's layout box for the node.
  Rect? _viewport() {
    if (!hasSize) return null;
    if (_model.target == api.TransformTarget.content) return Offset.zero & size;
    RenderObject? a = parent;
    while (a != null && a is! ContainerRenderObjectMixin) {
      a = a.parent;
    }
    if (a is! RenderBox || !a.hasSize) return null;
    try {
      final from = Matrix4.tryInvert(getTransformTo(a));
      if (from == null) return null;
      return MatrixUtils.transformRect(from, Offset.zero & a.size);
    } catch (_) {
      return null;
    }
  }

  Offset _local(Offset global) => attached ? globalToLocal(global) : global;

  (double, double) _halfExtents(TransformPose pose) {
    final s = hasSize ? size : Size.zero;
    final w = s.width * pose.scale * pose.scaleX, h = s.height * pose.scale * pose.scaleY;
    final a = pose.rotation * math.pi / 180;
    final c = math.cos(a).abs(), sn = math.sin(a).abs();
    return ((c * w + sn * h) / 2, (sn * w + c * h) / 2);
  }

  ((double, double), (double, double)) _ranges(TransformPose pose) {
    const none = (double.negativeInfinity, double.infinity);
    final view = _model.bounds == api.GestureBounds.none ? null : _viewport();
    if (view == null) return (none, none);
    final (hw, hh) = _halfExtents(pose);
    final c = _center;
    final (xlo, xhi) = boundsRange(bounds: _model.bounds, center: c.dx + pose.x, half: hw, viewLo: view.left, viewHi: view.right);
    final (ylo, yhi) = boundsRange(bounds: _model.bounds, center: c.dy + pose.y, half: hh, viewLo: view.top, viewHi: view.bottom);
    return ((pose.x + xlo, pose.x + xhi), (pose.y + ylo, pose.y + yhi));
  }

  TransformPose _clamped(TransformPose pose) {
    final ((xlo, xhi), (ylo, yhi)) = _ranges(pose);
    return pose.copyWith(x: pose.x.clamp(xlo, xhi), y: pose.y.clamp(ylo, yhi));
  }

  api.GesturePhysics get _physics => _model.effectivePhysics;
  double get _minScale => _model.minScale.isFinite && _model.minScale > 0 ? _model.minScale : 0.01;
  double get _maxScale => math.max(_minScale, _model.maxScale);

  /// [scale] held back past the scale limits, on a log scale.
  double _rubberScale(double scale) {
    final k = _physics.overscroll.clamp(0.0, 1.0);
    final v = math.log(math.max(_minScale * 1e-6, scale));
    final lo = math.log(_minScale), hi = math.log(_maxScale);
    if (v >= lo && v <= hi) return scale;
    if (k <= 0) return scale.clamp(_minScale, _maxScale);
    const reach = 0.6;
    double band(double excess) => (1 - 1 / (excess * k / reach + 1)) * reach;
    return math.exp(v < lo ? lo - band(lo - v) : hi + band(v - hi));
  }

  /// [from] zoomed by [factor] and turned by [turn]° about [focal] and
  /// moved by [pan], keeping the point under the focal under it.
  TransformPose _around(TransformPose from, Offset focal, {double factor = 1, double turn = 0, Offset pan = Offset.zero}) {
    final c0 = _center;
    final center = c0 + Offset(from.x, from.y);
    final a = turn * math.pi / 180;
    final d = (focal - center) * factor;
    final rotated = Offset(d.dx * math.cos(a) - d.dy * math.sin(a), d.dx * math.sin(a) + d.dy * math.cos(a));
    final next = focal + pan - rotated;
    return from.copyWith(x: next.dx - c0.dx, y: next.dy - c0.dy, scale: from.scale * factor, rotation: from.rotation + turn);
  }

  /// A pose given from outside kept inside the bounds once laid out.
  void _keepInBounds() {
    if (_model.bounds == api.GestureBounds.none || _active || !hasSize) return;
    final clamped = _clamped(_pose);
    if (clamped.sameAs(_pose)) return;
    _gesture = 'settle';
    _set(clamped);
  }

  Size? _laidOut;

  @override
  void performLayout() {
    super.performLayout();
    if (size == _laidOut) return;
    _laidOut = size;
    transform = _pose.matrixFor(size);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (attached) _keepInBounds();
    });
  }

  // --- settling ---------------------------------------------------------------------------

  Ticker? _ticker;
  final Map<String, Simulation> _sims = {};

  void _stop() {
    if (_ticker?.isActive ?? false) _ticker!.stop();
    _sims.clear();
  }

  void _run() {
    if (_sims.isEmpty) return _finish();
    _ticker ??= Ticker(_tick, debugLabel: 'transform gesture');
    _ticker!.stop();
    if (attached) _ticker!.start();
    _show();
  }

  void _tick(Duration elapsed) {
    final t = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    var next = _pose;
    for (final e in _sims.entries) {
      next = next.withValue(e.key, e.value.x(t));
    }
    _set(next);
    if (_sims.values.every((s) => s.isDone(t))) {
      var end = _pose;
      for (final e in _sims.entries) {
        final s = e.value;
        end = end.withValue(e.key, s is AxisSettleSimulation ? s.finalX : s.x(1e6));
      }
      _set(end);
      _ticker?.stop();
      _sims.clear();
      _finish();
    }
  }

  void _springTo(TransformPose target, {Offset velocity = Offset.zero}) {
    _stop();
    for (final key in TransformPose.keys) {
      if ((target[key] - _pose[key]).abs() < 1e-6 && !(key == 'x' && velocity.dx != 0) && !(key == 'y' && velocity.dy != 0)) {
        continue;
      }
      _sims[key] = AxisSettleSimulation.spring(
        physics: _physics,
        position: _pose[key],
        velocity: key == 'x' ? velocity.dx : (key == 'y' ? velocity.dy : 0),
        target: target[key],
      );
    }
    _run();
  }

  /// The release of a gesture at [velocity] (pixels per second).
  void _release(Offset velocity) {
    _stop();
    _lastVelocity = velocity;
    final scale = _pose.scale;
    final target = scale.clamp(_minScale, _maxScale);
    var settled = _pose;
    if (target != scale) settled = _around(_pose, _lastFocal, factor: target / scale);
    if (settled != _pose) {
      _gesture = 'settle';
      _springTo(_clamped(settled), velocity: velocity);
      return;
    }
    // In range: fling, and spring back at the bounds.
    final pans = _model.pansAt(scale) || _pointerCount > 1;
    final ((xlo, xhi), (ylo, yhi)) = _ranges(_pose);
    final v = pans ? velocity : Offset.zero;
    final sx = AxisSettleSimulation.release(physics: _physics, position: _pose.x, velocity: v.dx, lo: xlo, hi: xhi);
    final sy = AxisSettleSimulation.release(physics: _physics, position: _pose.y, velocity: v.dy, lo: ylo, hi: yhi);
    if (!sx.isDone(0)) _sims['x'] = sx;
    if (!sy.isDone(0)) _sims['y'] = sy;
    _gesture = 'fling';
    _run();
  }

  void _fromOutside(TransformPose given, {bool onlyScale = false}) {
    _gesture = 'variable';
    var target = given;
    if (onlyScale && hasSize) {
      // A zoom slider: zoom into what the viewport shows.
      final focal = _viewport()?.center ?? _center;
      target = _clamped(_around(_pose, focal, factor: given.scale / _pose.scale).copyWith(rotation: given.rotation));
    }
    _written = target;
    if (target != given) _writePose(target);
    if (!hasSize) {
      _pose = target;
      return _show();
    }
    _springTo(target);
  }

  /// Zooms by [factor] about the middle of the viewport, springing there.
  void zoomBy(double factor) {
    if (!factor.isFinite || factor <= 0) return;
    _gesture = 'settle';
    _lastVelocity = Offset.zero;
    final focal = (hasSize ? _viewport()?.center : null) ?? _center;
    final next = _clamped(_around(_pose, focal, factor: (_pose.scale * factor).clamp(_minScale, _maxScale) / _pose.scale));
    _written = next;
    _writePose(next);
    hasSize ? _springTo(next) : (_pose = next);
  }

  /// Springs to [pose] (keys left out kept).
  void moveTo(Map<String, double> pose) {
    _gesture = 'settle';
    _lastVelocity = Offset.zero;
    final next = _clamped(_with(_pose, pose));
    _written = next;
    _writePose(next);
    if (!hasSize) {
      _pose = next;
      return _show();
    }
    _springTo(next);
  }

  /// Springs back to the rest pose: no offset, scale 1 (or the minimum),
  /// no rotation or stretch.
  void reset() {
    _gesture = 'settle';
    _lastVelocity = Offset.zero;
    final rest = TransformPose(scale: 1.clamp(_minScale, _maxScale).toDouble());
    _written = rest;
    _writePose(rest);
    _springTo(_clamped(rest));
  }

  // --- gestures ---------------------------------------------------------------------------

  late final TransformScaleGestureRecognizer _scale;
  late final DoubleTapGestureRecognizer _doubleTap;
  late final TapGestureRecognizer _tap;
  Offset? _doubleTapAt;

  bool get _hasTransformGestures => _model.zoom || _model.rotate || _model.pan != api.TransformPan.never;

  bool _canAccept(int pointers) =>
      pointers > 1 ? (_model.zoom || _model.rotate || _model.pan != api.TransformPan.never) : _model.pansAt(_pose.scale);

  TransformPose _startPose = TransformPose.identity;
  Offset _startFocal = Offset.zero, _lastFocal = Offset.zero;
  double _scaleBase = 1, _turn = 0, _lastRawRotation = 0;
  int _gesturePointers = 0;

  void _onScaleStart(ScaleStartDetails d) {
    _stop();
    if (!_gestureActive) {
      _gesturePointers = 0;
      _select();
    }
    final fresh = !_gestureActive;
    _gestureActive = true;
    _gesturePointers = math.max(_gesturePointers, d.pointerCount);
    _turn = 0;
    _lastRawRotation = 0;
    _pointerCount = d.pointerCount;
    _startPose = _pose;
    // A new gesture pans from where its fingers went down, so the touch
    // slop isn't lost; a restart (a finger landed or lifted) from here.
    _startFocal = fresh && _downAt.isNotEmpty
        ? _local(_downAt.values.reduce((a, b) => a + b) / _downAt.length.toDouble())
        : _local(d.focalPoint);
    _lastFocal = _startFocal;
    _scaleBase = 1;
    _gesture = d.pointerCount > 1 ? 'pinch' : 'pan';
    _show();
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    if (d.pointerCount != _pointerCount) {
      _pointerCount = d.pointerCount;
      _startPose = _pose;
      _startFocal = _local(d.focalPoint);
      _scaleBase = d.scale;
      _turn = 0;
      _lastRawRotation = d.rotation;
    }
    _gesturePointers = math.max(_gesturePointers, d.pointerCount);
    // The recognizer's rotation jumps a turn as the fingers cross ±180°:
    // add up small steps instead.
    var step = d.rotation - _lastRawRotation;
    while (step > math.pi) {
      step -= 2 * math.pi;
    }
    while (step < -math.pi) {
      step += 2 * math.pi;
    }
    _lastRawRotation = d.rotation;
    _turn += step;
    final focal = _local(d.focalPoint);
    _lastFocal = focal;
    final many = d.pointerCount > 1;
    if (!many && !_model.pansAt(_startPose.scale)) return;
    _gesture = many ? 'pinch' : 'pan';
    var factor = _model.zoom && many ? d.scale / _scaleBase : 1.0;
    final turn = _model.rotate && many ? _turn * 180 / math.pi : 0.0;
    factor = _rubberScale(_startPose.scale * factor) / _startPose.scale;
    var pan = focal - _startFocal;
    if (_model.pan == api.TransformPan.never) pan = Offset.zero;
    var next = _around(_startPose, _startFocal, factor: factor, turn: turn, pan: pan);
    // Stretch past the bounds like a rubber band.
    final ((xlo, xhi), (ylo, yhi)) = _ranges(next);
    final k = _physics.overscroll;
    next = next.copyWith(x: rubberBand(next.x, xlo, xhi, k), y: rubberBand(next.y, ylo, yhi, k));
    _set(next);
  }

  void _onScaleEnd(ScaleEndDetails d) {
    _gestureActive = _down > 0;
    _scaleBase = 1;
    // A pinch doesn't throw.
    _release(_gesturePointers > 1 ? Offset.zero : d.velocity.pixelsPerSecond);
  }

  void _onDoubleTap() {
    final at = _local(_doubleTapAt ?? Offset.zero);
    final zoomedIn = _pose.scale > _minScale + 0.01;
    final target = zoomedIn ? _minScale : _model.doubleTapScale.clamp(_minScale, _maxScale);
    _fire('doubleTap', {'x': at.dx, 'y': at.dy, 'scale': target});
    _gesture = 'doubleTap';
    _pointerCount = 1;
    var next = _around(_pose, at, factor: target / _pose.scale);
    if (zoomedIn && _model.target == api.TransformTarget.content) next = next.copyWith(x: 0, y: 0);
    _springTo(_clamped(next));
  }

  int _down = 0;
  bool _endPending = false;
  final Map<int, Offset> _downAt = {};

  void _onPointerUp(PointerEvent event) {
    _downAt.remove(event.pointer);
    _down = math.max(0, _down - 1);
    if (_down > 0) return;
    _gestureActive = false;
    if (_endPending && !(_ticker?.isActive ?? false)) _finish();
  }

  void _onPointerDown(PointerDownEvent event) {
    _down++;
    _downAt[event.pointer] = event.position;
    if (!_enabled) return;
    final handle = _handleAt(event.localPosition);
    if (handle != null) return _startHandle(handle, event);
    if (_hasTransformGestures) {
      _scale.addPointer(event);
    }
    if (_model.zoom && _model.doubleTapScale > 0) _doubleTap.addPointer(event);
    if (_selectionName.isNotEmpty) _tap.addPointer(event);
  }

  void _onSignal(PointerSignalEvent event) {
    if (!_enabled) return;
    final keys = HardwareKeyboard.instance;
    final ctrl = keys.isControlPressed || keys.isMetaPressed;
    final wheel = _model.wheel;
    if (event is PointerScaleEvent) {
      if (!_model.zoom) return;
      GestureBinding.instance.pointerSignalResolver.register(
        event,
        (e) => _wheelZoom(_local(e.position), (e as PointerScaleEvent).scale),
      );
      return;
    }
    if (event is! PointerScrollEvent || wheel == api.WheelZoom.none) return;
    final zooms =
        _model.zoom && (wheel == api.WheelZoom.zoom || (ctrl && (wheel == api.WheelZoom.ctrlZoom || wheel == api.WheelZoom.pan)));
    final pans = !zooms && wheel == api.WheelZoom.pan && !ctrl;
    if (!zooms && !pans) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (e) {
      final s = e as PointerScrollEvent;
      if (zooms) {
        _wheelZoom(_local(s.position), math.exp(-s.scrollDelta.dy / 300));
      } else {
        _gesture = 'wheel';
        _stop();
        _set(_clamped(_pose.copyWith(x: _pose.x - s.scrollDelta.dx, y: _pose.y - s.scrollDelta.dy)));
        _scheduleWheelEnd();
      }
    });
  }

  void _wheelZoom(Offset focal, double factor) {
    _stop();
    _gesture = 'wheel';
    _pointerCount = 0;
    final target = (_pose.scale * factor).clamp(_minScale, _maxScale);
    _set(_clamped(_around(_pose, focal, factor: target / _pose.scale)));
    _scheduleWheelEnd();
  }

  void _scheduleWheelEnd() {
    _wheelEnd?.cancel();
    _wheelEnd = Timer(const Duration(milliseconds: 220), () {
      if (attached && !_active) _finish();
    });
  }

  // --- handles ----------------------------------------------------------------------------

  /// The handles shown now, by name: where each is (layout coordinates)
  /// and what it does.
  List<_Handle> _handles() {
    final h = _model.handles;
    if (h == null || !_selected || !_enabled || !hasSize || size.isEmpty) return const [];
    final w = size.width, ht = size.height;
    Offset at(double qx, double qy) => _toLayout(Offset((qx + 1) / 2 * w, (qy + 1) / 2 * ht));
    return [
      if (h.corners)
        for (final (name, qx, qy) in const [('tl', -1.0, -1.0), ('tr', 1.0, -1.0), ('br', 1.0, 1.0), ('bl', -1.0, 1.0)])
          _Handle(name, at(qx, qy), qx, qy,
              qx == qy ? SystemMouseCursors.resizeUpLeftDownRight : SystemMouseCursors.resizeUpRightDownLeft),
      if (h.edges && !h.aspectLock)
        for (final (name, qx, qy) in const [('t', 0.0, -1.0), ('r', 1.0, 0.0), ('b', 0.0, 1.0), ('l', -1.0, 0.0)])
          _Handle(name, at(qx, qy), qx, qy, qx == 0 ? SystemMouseCursors.resizeUpDown : SystemMouseCursors.resizeLeftRight),
      if (h.rotateKnob) _Handle('rotate', _knobAt(), 0, 0, SystemMouseCursors.grab, round: true),
    ];
  }

  Offset _toLayout(Offset q) => MatrixUtils.transformPoint(_pose.matrixFor(size), q);

  /// 28px above the top edge's middle, turned with the node.
  Offset _knobAt() {
    final top = _toLayout(Offset(size.width / 2, 0));
    final a = _pose.rotation * math.pi / 180;
    return top + Offset(math.sin(a), -math.cos(a)) * 28;
  }

  double get _handleHit => math.max(32, _model.handles?.handleSize ?? 12);

  _Handle? _handleAt(Offset local) {
    final hit = _handleHit;
    for (final h in _handles().reversed) {
      if (Rect.fromCenter(center: h.at, width: hit, height: hit).contains(local)) return h;
    }
    return null;
  }

  PanGestureRecognizer? _handleDrag;
  _Handle? _dragging;
  TransformPose? _handleStart;

  void _startHandle(_Handle handle, PointerDownEvent event) {
    _handleDrag ??= PanGestureRecognizer(debugOwner: this)
      ..onStart = ((_) => _onHandleStart())
      ..onUpdate = ((d) => _onHandleMove(d.globalPosition))
      ..onEnd = ((_) => _onHandleEnd())
      ..onCancel = _onHandleEnd;
    _dragging = handle;
    _handleDrag!.addPointer(event);
  }

  void _onHandleStart() {
    _stop();
    _select();
    _gestureActive = true;
    _handleStart = _pose;
    _gesture = 'handle';
    _pointerCount = 1;
  }

  void _onHandleMove(Offset global) {
    final h = _dragging;
    if (h == null) return;
    if (h.name == 'rotate') return _onRotateHandle(global);
    _onResize(global, h.qx, h.qy);
  }

  void _onHandleEnd() {
    _gestureActive = false;
    _handleStart = null;
    _dragging = null;
    _lastVelocity = Offset.zero;
    final clamped = _clamped(_pose);
    clamped != _pose ? _springTo(clamped) : _finish();
  }

  /// A corner (hx, hy in ±1) or edge (one of them 0) dragged to [global].
  void _onResize(Offset global, double hx, double hy) {
    final handles = _model.handles!;
    final from = _handleStart ?? _pose;
    final c = _center + Offset(from.x, from.y);
    final a = -from.rotation * math.pi / 180;
    final p = _local(global) - c;
    final d = Offset(p.dx * math.cos(a) - p.dy * math.sin(a), p.dx * math.sin(a) + p.dy * math.cos(a));
    if (size.isEmpty) return;
    double clampW(double w) => w.clamp(handles.minWidth, handles.maxWidth > 0 ? handles.maxWidth : double.infinity);
    double clampH(double h) => h.clamp(handles.minHeight, handles.maxHeight > 0 ? handles.maxHeight : double.infinity);
    TransformPose next;
    if (hx != 0 && hy != 0 && handles.aspectLock) {
      final base = Offset(size.width / 2, size.height / 2).distance;
      var scale = d.distance / base / (from.scaleX + from.scaleY) * 2;
      scale = clampW(size.width * scale * from.scaleX) / (size.width * from.scaleX);
      scale = clampH(size.height * scale * from.scaleY) / (size.height * from.scaleY);
      next = from.copyWith(scale: scale);
    } else {
      var scaleX = from.scaleX, scaleY = from.scaleY;
      if (hx != 0) scaleX = clampW(d.dx.abs() * 2) / (size.width * from.scale);
      if (hy != 0) scaleY = clampH(d.dy.abs() * 2) / (size.height * from.scale);
      next = from.copyWith(scaleX: scaleX, scaleY: scaleY);
    }
    _set(next);
  }

  void _onRotateHandle(Offset global) {
    final handles = _model.handles!;
    final p = _local(global) - (_center + Offset(_pose.x, _pose.y));
    var angle = math.atan2(p.dy, p.dx) * 180 / math.pi + 90;
    var snap = handles.snapAngle;
    if (snap <= 0 && HardwareKeyboard.instance.isShiftPressed) snap = 15;
    if (snap > 0) angle = (angle / snap).round() * snap;
    // Keep turning the short way from where it was.
    final from = _pose.rotation;
    while (angle - from > 180) {
      angle -= 360;
    }
    while (angle - from < -180) {
      angle += 360;
    }
    _set(_pose.copyWith(rotation: angle));
  }

  // --- painting and hit testing -----------------------------------------------------------

  bool get _content => _model.target == api.TransformTarget.content;

  final LayerHandle<ClipRectLayer> _clip = LayerHandle();

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_content) {
      // The node stays; its content zooms inside its own box.
      _clip.layer = context.pushClipRect(needsCompositing, offset, Offset.zero & size, super.paint, oldLayer: _clip.layer);
    } else {
      _clip.layer = null;
      super.paint(context, offset);
    }
    final handles = _handles();
    if (handles.isEmpty) return;
    final h = _model.handles!;
    final color = h.color.flutter;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final canvas = context.canvas;
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    if (h.outline) {
      final w = size.width, ht = size.height;
      canvas.drawPath(
        Path()..addPolygon([_toLayout(Offset.zero), _toLayout(Offset(w, 0)), _toLayout(Offset(w, ht)), _toLayout(Offset(0, ht))], true),
        stroke,
      );
      if (h.rotateKnob) canvas.drawLine(_toLayout(Offset(w / 2, 0)), _knobAt(), stroke);
    }
    final fill = Paint()..color = const Color(0xFFFFFFFF);
    final s = h.handleSize;
    for (final handle in handles) {
      final r = Rect.fromCenter(center: handle.at, width: s, height: s);
      if (handle.round) {
        canvas.drawOval(r, fill);
        canvas.drawOval(r, stroke);
      } else {
        final rr = RRect.fromRectAndRadius(r, const Radius.circular(2));
        canvas.drawRRect(rr, fill);
        canvas.drawRRect(rr, stroke);
      }
    }
    canvas.restore();
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (_handleAt(position) != null) {
      result.add(BoxHitTestEntry(this, position));
      return true;
    }
    if (_content) {
      if (!size.contains(position)) return false;
      hitTestChildren(result, position: position);
      result.add(BoxHitTestEntry(this, position));
      return true;
    }
    // Where the node is drawn, not where it was laid out.
    if (hitTestChildren(result, position: position)) {
      result.add(BoxHitTestEntry(this, position));
      return true;
    }
    return false;
  }

  bool _hitOutside(BoxHitTestResult result, Offset position) {
    final box = _box;
    if (box == null || !attached || !hasSize) return false;
    final Matrix4 toBox;
    try {
      toBox = getTransformTo(box);
    } catch (_) {
      return false;
    }
    return result.addWithPaintTransform(transform: toBox, position: position, hitTest: (r, p) => hitTest(r, position: p));
  }

  Offset? _hover;

  @override
  void handleEvent(PointerEvent event, covariant BoxHitTestEntry entry) {
    if (event is PointerDownEvent) {
      _onPointerDown(event);
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      _onPointerUp(event);
    } else if (event is PointerPanZoomStartEvent) {
      if (_enabled && _hasTransformGestures) _scale.addPointerPanZoom(event);
    } else if (event is PointerSignalEvent) {
      _onSignal(event);
    } else if (event is PointerHoverEvent) {
      _hover = entry.localPosition;
    }
  }

  @override
  MouseCursor get cursor {
    final at = _hover;
    return (at == null ? null : _handleAt(at)?.cursor) ?? MouseCursor.defer;
  }

  @override
  PointerEnterEventListener? get onEnter => null;

  @override
  PointerExitEventListener? get onExit => (_) => _hover = null;

  @override
  bool get validForMouseTracker => attached && _model.handles != null;

  // --- lifecycle --------------------------------------------------------------------------

  bool _registered = false;

  void _syncRegistration() {
    final box = _box;
    if (attached && box != null && !_registered) {
      _registered = true;
      ((TransformGestures._byTree[box.tree] ??= {})[box.id] ??= {}).add(this);
    } else if ((!attached || box == null) && _registered) {
      _unregister();
    }
  }

  void _unregister() {
    final box = _box;
    if (box != null) {
      final m = TransformGestures._byTree[box.tree];
      m?[box.id]?.remove(this);
      if (m?[box.id]?.isEmpty ?? false) m!.remove(box.id);
    }
    _registered = false;
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    for (final w in _watched) {
      w.addListener(_onVariable);
    }
    _syncRegistration();
    if (_sims.isNotEmpty) _ticker?.start();
  }

  @override
  void detach() {
    for (final w in _watched) {
      w.removeListener(_onVariable);
    }
    _ticker?.stop();
    _wheelEnd?.cancel();
    if (_registered) _unregister();
    super.detach();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _scale.dispose();
    _doubleTap.dispose();
    _tap.dispose();
    _handleDrag?.dispose();
    _wheelEnd?.cancel();
    _clip.layer = null;
    super.dispose();
  }
}

class _Handle {
  const _Handle(this.name, this.at, this.qx, this.qy, this.cursor, {this.round = false});
  final String name;
  final Offset at;
  final double qx, qy;
  final MouseCursor cursor;
  final bool round;
}
