import 'dart:async';
import 'dart:math' as math;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'gesture_physics.dart';

/// Where a [NodeTransformGesture] draws its node: offset, scale, rotation
/// and stretch, around the node's centre.
@immutable
class TransformPose {
  /// Horizontal offset from where the layout puts the node, in pixels.
  final double x;

  /// Vertical offset from where the layout puts the node.
  final double y;

  /// Uniform scale.
  final double scale;

  /// Rotation in degrees, clockwise.
  final double rotation;

  /// Horizontal stretch on top of [scale] (edge handles).
  final double scaleX;

  /// Vertical stretch on top of [scale].
  final double scaleY;

  /// Creates a [TransformPose].
  const TransformPose({
    this.x = 0,
    this.y = 0,
    this.scale = 1,
    this.rotation = 0,
    this.scaleX = 1,
    this.scaleY = 1,
  });

  /// No transform.
  static const TransformPose identity = TransformPose();

  /// The pose with the given values replaced.
  TransformPose copyWith({
    double? x,
    double? y,
    double? scale,
    double? rotation,
    double? scaleX,
    double? scaleY,
  }) => TransformPose(
    x: x ?? this.x,
    y: y ?? this.y,
    scale: scale ?? this.scale,
    rotation: rotation ?? this.rotation,
    scaleX: scaleX ?? this.scaleX,
    scaleY: scaleY ?? this.scaleY,
  );

  /// The value named [key] (`x`, `y`, `scale`, `rotation`, `scaleX`,
  /// `scaleY`).
  double operator [](String key) => switch (key) {
    'x' => x,
    'y' => y,
    'scale' => scale,
    'rotation' => rotation,
    'scaleX' => scaleX,
    'scaleY' => scaleY,
    _ => 0,
  };

  /// A copy with the value named [key] set to [value].
  TransformPose withValue(String key, double value) => switch (key) {
    'x' => copyWith(x: value),
    'y' => copyWith(y: value),
    'scale' => copyWith(scale: value),
    'rotation' => copyWith(rotation: value),
    'scaleX' => copyWith(scaleX: value),
    'scaleY' => copyWith(scaleY: value),
    _ => this,
  };

  /// The names of the values.
  static const List<String> keys = [
    'x',
    'y',
    'scale',
    'rotation',
    'scaleX',
    'scaleY',
  ];

  /// [value] rounded the way a pose is written to variables: pixels and
  /// degrees to hundredths, scales to thousandths.
  static num rounded(String key, double value) {
    final int places = key.startsWith('scale') ? 1000 : 100;
    final num r = (value * places).round() / places;
    return r == r.roundToDouble() ? r.round() : r;
  }

  /// Whether this and [other] round to the same written values.
  bool sameAs(TransformPose other) =>
      keys.every((key) => rounded(key, this[key]) == rounded(key, other[key]));

  /// The values, rounded as written.
  Map<String, num> toMap() => {
    for (final key in keys) key: rounded(key, this[key]),
  };

  /// The matrix that draws a box at this pose around its centre, for a
  /// `Transform` aligned at the centre.
  Matrix4 get centeredMatrix => Matrix4.translationValues(x, y, 0)
    ..rotateZ(rotation * math.pi / 180)
    ..scaleByDouble(scale * scaleX, scale * scaleY, 1, 1);

  /// The matrix that draws a [size] box at this pose, in the box's own
  /// coordinates.
  Matrix4 matrixFor(Size size) {
    final Offset c = size.center(Offset.zero);
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
  String toString() =>
      'TransformPose(x: $x, y: $y, scale: $scale, rotation: $rotation, '
      'scaleX: $scaleX, scaleY: $scaleY)';
}

/// The live state of the nearest [NodeTransformGesture], as the
/// `transform` variable shows it inside the node.
@immutable
class TransformValues {
  /// The pose.
  final TransformPose pose;

  /// Whether a gesture or its settle is running.
  final bool active;

  /// Whether the node's handles are showing.
  final bool selected;

  /// Creates [TransformValues].
  const TransformValues({
    this.pose = TransformPose.identity,
    this.active = false,
    this.selected = false,
  });

  /// The values as `${transform.*}` reads them.
  Map<String, dynamic> toMap() => {
    ...pose.toMap(),
    'active': active,
    'selected': selected,
  };

  @override
  bool operator ==(Object other) =>
      other is TransformValues &&
      other.pose == pose &&
      other.active == active &&
      other.selected == selected;

  @override
  int get hashCode => Object.hash(pose, active, selected);
}

/// Shares the nearest [NodeTransformGesture]'s values with the nodes
/// inside it.
class TransformScope extends InheritedWidget {
  /// The live values.
  final TransformValues values;

  /// Creates a [TransformScope].
  const TransformScope({super.key, required this.values, required super.child});

  /// The values of the nearest transform gesture above [context], if any.
  static TransformValues? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TransformScope>()?.values;

  @override
  bool updateShouldNotify(TransformScope oldWidget) =>
      values != oldWidget.values;
}

/// A scale recognizer that, while [canAccept] says no, never claims the
/// arena itself: a one-finger drag on a photo at rest goes to the page
/// view or dismiss drag around it, while a second finger still makes it a
/// pinch.
class TransformScaleGestureRecognizer extends ScaleGestureRecognizer {
  /// Creates a [TransformScaleGestureRecognizer].
  TransformScaleGestureRecognizer({super.debugOwner});

  /// Whether the recognizer may claim a gesture of [pointers] pointers.
  bool Function(int pointers) canAccept = _always;

  static bool _always(int pointers) => true;

  @override
  // ignore: must_call_super
  void resolve(GestureDisposition disposition) {
    if (disposition == GestureDisposition.accepted &&
        !canAccept(pointerCount)) {
      // Stays in the arena undecided: another recognizer can win, or a
      // second pointer turns this into a pinch it may claim.
      return;
    }
    super.resolve(disposition);
  }
}

/// Makes [child] pannable, zoomable and rotatable as [model] says: pinch
/// and ctrl+wheel zoom around the focal point, a pan, two-finger rotate,
/// double-tap zoom, and a release that flings and settles within bounds by
/// the model's physics. With [TransformGestureModel.handles] it shows
/// corner, edge and rotate handles around the node.
///
/// [given] holds the values of the pose given from outside (bound
/// variables or data); a change springs the node there. Every change made by the user is reported
/// to [onPose] (to write the variables), [onChanged] and, once the gesture
/// and its settle end, [onEnd].
class NodeTransformGesture extends StatefulWidget {
  /// Creates a [NodeTransformGesture].
  const NodeTransformGesture({
    super.key,
    required this.model,
    required this.child,
    this.given = const {},
    this.enabled = true,
    this.selected = true,
    this.onSelect,
    this.onPose,
    this.onChanged,
    this.onEnd,
    this.onDoubleTap,
  });

  /// What the gestures do.
  final TransformGestureModel model;

  /// The values of the pose given from outside (bound variables or data),
  /// by [TransformPose.keys] name; the others are the node's own. A change
  /// springs the node there.
  final Map<String, double> given;

  /// Whether the gestures work.
  final bool enabled;

  /// Whether the handles show (see [TransformHandlesModel.selectionVariable]).
  final bool selected;

  /// Called when the node is tapped or grabbed, to select it.
  final VoidCallback? onSelect;

  /// Called with each pose the user moves the node to.
  final ValueChanged<TransformPose>? onPose;

  /// Called with each change, as `changed` reactions read it.
  final ValueChanged<Map<String, dynamic>>? onChanged;

  /// Called when a gesture and its settle end, as `changeEnd` reads it.
  final ValueChanged<Map<String, dynamic>>? onEnd;

  /// Called on a double tap, as `doubleTap` reads it.
  final ValueChanged<Map<String, dynamic>>? onDoubleTap;

  /// The node.
  final Widget child;

  @override
  State<NodeTransformGesture> createState() => NodeTransformGestureState();
}

/// The state of a [NodeTransformGesture].
class NodeTransformGestureState extends State<NodeTransformGesture>
    with SingleTickerProviderStateMixin {
  TransformPose _pose = TransformPose.identity;
  TransformPose? _written;

  TransformPose _with(TransformPose base, Map<String, double> values) {
    TransformPose out = base;
    values.forEach((key, value) => out = out.withValue(key, value));
    return out;
  }

  /// Whether [values] round to what [pose] has.
  static bool _matches(TransformPose pose, Map<String, double> values) =>
      values.entries.every(
        (e) =>
            TransformPose.rounded(e.key, e.value) ==
            TransformPose.rounded(e.key, pose[e.key]),
      );
  late final Ticker _ticker = createTicker(_tick);
  final SimulationGroup _sims = SimulationGroup();
  String _gesture = 'pan';
  bool _gestureActive = false;
  int _pointerCount = 0;
  Offset _lastVelocity = Offset.zero;
  Timer? _wheelEnd;

  late final TransformScaleGestureRecognizer _scale =
      TransformScaleGestureRecognizer(debugOwner: this)
        // Scales and turns count from where the fingers went down, not
        // from where they passed the slop.
        ..dragStartBehavior = DragStartBehavior.down
        // A pan claims at 16px, ahead of a scroll's 18px touch slop: a
        // zoomed photo in a page view, or a map in a list, takes one-finger
        // drags whenever it may pan ([_canAccept] says when).
        ..gestureSettings = const DeviceGestureSettings(touchSlop: 8)
        ..canAccept = _canAccept
        ..onStart = _onScaleStart
        ..onUpdate = _onScaleUpdate
        ..onEnd = _onScaleEnd;
  late final DoubleTapGestureRecognizer _doubleTap =
      DoubleTapGestureRecognizer(debugOwner: this)
        ..onDoubleTapDown = ((d) => _doubleTapAt = d.globalPosition)
        ..onDoubleTap = _onDoubleTap;
  late final TapGestureRecognizer _tap = TapGestureRecognizer(debugOwner: this)
    ..onTap = (() => widget.onSelect?.call());
  Offset? _doubleTapAt;
  Size? _builtSize;

  TransformGestureModel get _model => widget.model;
  PhysicsModel get _physics => _model.effectivePhysics;

  /// The current pose.
  TransformPose get pose => _pose;

  /// Whether a gesture or settle is running.
  bool get active => _gestureActive || _ticker.isActive;

  @override
  void initState() {
    super.initState();
    _pose = _with(TransformPose.identity, widget.given);
    _written = _pose;
  }

  @override
  void didUpdateWidget(NodeTransformGesture oldWidget) {
    super.didUpdateWidget(oldWidget);
    final Map<String, double> given = widget.given;
    if (given.isEmpty || _gestureActive) return;
    // Ours coming back through the variables: nothing to do.
    if (_written != null && _matches(_written!, given)) return;
    if (_matches(_pose, given)) return;
    final Set<String> changed = {
      for (final e in given.entries)
        if (TransformPose.rounded(e.key, e.value) !=
            TransformPose.rounded(e.key, _pose[e.key]))
          e.key,
    };
    // After the frame: it writes variables back and runs reactions, which
    // rebuild other nodes.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _gestureActive) return;
      _fromOutside(
        _with(_pose, given),
        onlyScale: changed.length == 1 && changed.first == 'scale',
      );
    });
  }

  @override
  void dispose() {
    _wheelEnd?.cancel();
    _ticker.dispose();
    _scale.dispose();
    _doubleTap.dispose();
    _tap.dispose();
    super.dispose();
  }

  // ---- Geometry -----------------------------------------------------------

  RenderBox? get _root {
    final RenderObject? box = context.findRenderObject();
    return box is RenderBox && box.hasSize ? box : null;
  }

  Size get _size => _root?.size ?? Size.zero;

  Offset get _center => _size.center(Offset.zero);

  /// The box the node is kept inside of, in the node's layout coordinates:
  /// its own box for content, its parent's layout box for the node.
  Rect? _viewport() {
    final RenderBox? root = _root;
    if (root == null) return null;
    if (_model.target == TransformTarget.content) {
      return Offset.zero & root.size;
    }
    RenderObject? ancestor = root.parent;
    while (ancestor != null && ancestor is! ContainerRenderObjectMixin) {
      ancestor = ancestor.parent;
    }
    if (ancestor is! RenderBox || !ancestor.hasSize) return null;
    final Matrix4 toAncestor = root.getTransformTo(ancestor);
    final Matrix4? fromAncestor = Matrix4.tryInvert(toAncestor);
    if (fromAncestor == null) return null;
    return MatrixUtils.transformRect(fromAncestor, Offset.zero & ancestor.size);
  }

  Offset _local(Offset global) => _root?.globalToLocal(global) ?? global;

  /// Half the width and height of the node's bounding box at [pose].
  (double, double) _halfExtents(TransformPose pose) {
    final Size size = _size;
    final double w = size.width * pose.scale * pose.scaleX;
    final double h = size.height * pose.scale * pose.scaleY;
    final double a = pose.rotation * math.pi / 180;
    final double c = math.cos(a).abs(), s = math.sin(a).abs();
    return ((c * w + s * h) / 2, (s * w + c * h) / 2);
  }

  /// The ranges [pose]'s x and y may take to keep within the bounds.
  ((double, double), (double, double)) _ranges(TransformPose pose) {
    const none = (double.negativeInfinity, double.infinity);
    final Rect? view = _model.bounds == GestureBounds.none ? null : _viewport();
    if (view == null) return (none, none);
    final (double hw, double hh) = _halfExtents(pose);
    final Offset c = _center;
    final (double xlo, double xhi) = boundsRange(
      bounds: _model.bounds,
      center: c.dx + pose.x,
      half: hw,
      viewLo: view.left,
      viewHi: view.right,
    );
    final (double ylo, double yhi) = boundsRange(
      bounds: _model.bounds,
      center: c.dy + pose.y,
      half: hh,
      viewLo: view.top,
      viewHi: view.bottom,
    );
    return ((pose.x + xlo, pose.x + xhi), (pose.y + ylo, pose.y + yhi));
  }

  /// [pose] moved inside the bounds.
  TransformPose _clamped(TransformPose pose) {
    final ((double xlo, double xhi), (double ylo, double yhi)) = _ranges(pose);
    return pose.copyWith(x: pose.x.clamp(xlo, xhi), y: pose.y.clamp(ylo, yhi));
  }

  double get _minScale => math.max(0.01, _model.minScale);
  double get _maxScale => math.max(_minScale, _model.maxScale);

  /// [scale] held back past the scale limits, on a log scale.
  double _rubberScale(double scale) {
    final double k = _physics.overscroll.clamp(0.0, 1.0);
    final double v = math.log(math.max(1e-4, scale));
    final double lo = math.log(_minScale), hi = math.log(_maxScale);
    if (v >= lo && v <= hi) return scale;
    if (k <= 0) return scale.clamp(_minScale, _maxScale);
    const double reach = 0.6;
    double band(double excess) => (1 - 1 / (excess * k / reach + 1)) * reach;
    return math.exp(v < lo ? lo - band(lo - v) : hi + band(v - hi));
  }

  /// [from] zoomed by [factor] and turned by [turn] degrees around [focal]
  /// (layout coordinates) and moved by [pan], keeping the point under the
  /// focal under it.
  TransformPose _around(
    TransformPose from,
    Offset focal, {
    double factor = 1,
    double turn = 0,
    Offset pan = Offset.zero,
  }) {
    final Offset c0 = _center;
    final Offset center = c0 + Offset(from.x, from.y);
    final double a = turn * math.pi / 180;
    final Offset d = (focal - center) * factor;
    final Offset rotated = Offset(
      d.dx * math.cos(a) - d.dy * math.sin(a),
      d.dx * math.sin(a) + d.dy * math.cos(a),
    );
    final Offset next = focal + pan - rotated;
    return from.copyWith(
      x: next.dx - c0.dx,
      y: next.dy - c0.dy,
      scale: from.scale * factor,
      rotation: from.rotation + turn,
    );
  }

  // ---- Reporting ----------------------------------------------------------

  Map<String, dynamic> _result([Offset velocity = Offset.zero]) => {
    ..._pose.toMap(),
    'pointerCount': _pointerCount,
    'gesture': _gesture,
    'velocityX': velocity.dx,
    'velocityY': velocity.dy,
  };

  void _set(TransformPose next, {bool report = true}) {
    if (next == _pose) return;
    setState(() => _pose = next);
    if (!report) return;
    if (widget.onPose != null &&
        (_written == null || !next.sameAs(_written!))) {
      _written = next;
      widget.onPose!(next);
    }
    widget.onChanged?.call(_result());
  }

  void _finish() {
    if (_down > 0 && _gestureActive) {
      // A finger is still on the node: end when it lifts.
      _endPending = true;
      return;
    }
    _endPending = false;
    widget.onEnd?.call(_result(_lastVelocity));
    if (mounted) setState(() {});
  }

  // ---- Settling -----------------------------------------------------------

  void _stop() {
    if (_ticker.isActive) _ticker.stop();
    _sims.clear();
  }

  void _run() {
    if (_sims.isEmpty) {
      _finish();
      return;
    }
    _ticker.stop();
    _ticker.start();
    setState(() {});
  }

  void _tick(Duration elapsed) {
    final double t = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    TransformPose next = _pose;
    for (final String key in _sims.keys) {
      next = next.withValue(key, _sims.x(key, t)!);
    }
    _set(next);
    if (_sims.isDone(t)) {
      // Land exactly where the simulations end.
      TransformPose end = _pose;
      for (final String key in _sims.keys) {
        end = end.withValue(key, _sims.finalOf(key));
      }
      _set(end);
      _ticker.stop();
      _sims.clear();
      _finish();
    }
  }

  /// Springs every value of the pose to [target], starting at [velocity]
  /// for x and y.
  void _springTo(TransformPose target, {Offset velocity = Offset.zero}) {
    _stop();
    for (final String key in TransformPose.keys) {
      if ((target[key] - _pose[key]).abs() < 1e-6 &&
          !(key == 'x' && velocity.dx != 0) &&
          !(key == 'y' && velocity.dy != 0)) {
        continue;
      }
      _sims.set(
        key,
        AxisSettleSimulation.spring(
          physics: _physics,
          position: _pose[key],
          velocity: key == 'x'
              ? velocity.dx
              : key == 'y'
              ? velocity.dy
              : 0,
          target: target[key],
        ),
      );
    }
    _run();
  }

  /// The release of a gesture at [velocity] (pixels per second).
  void _release(Offset velocity) {
    _stop();
    _lastVelocity = velocity;
    final double scale = _pose.scale;
    double target = scale.clamp(_minScale, _maxScale);
    TransformPose settled = _pose;
    if (target != scale) {
      // Back inside the scale limits, around the last focal point.
      settled = _around(_pose, _lastFocal, factor: target / scale);
    }
    double turn = settled.rotation;
    final double snap = _model.rotationSnap;
    if (snap > 0) turn = (turn / snap).round() * snap;
    settled = settled.copyWith(rotation: turn);

    if (settled != _pose) {
      _gesture = 'settle';
      _springTo(_clamped(settled), velocity: velocity);
      return;
    }
    // In range: fling, and spring back at the bounds.
    final bool pans = _model.pansAt(scale) || _pointerCount > 1;
    final ((double xlo, double xhi), (double ylo, double yhi)) = _ranges(_pose);
    final Offset v = pans ? velocity : Offset.zero;
    final AxisSettleSimulation sx = AxisSettleSimulation.release(
      physics: _physics,
      position: _pose.x,
      velocity: v.dx,
      lo: xlo,
      hi: xhi,
    );
    final AxisSettleSimulation sy = AxisSettleSimulation.release(
      physics: _physics,
      position: _pose.y,
      velocity: v.dy,
      lo: ylo,
      hi: yhi,
    );
    if (!sx.isDone(0)) _sims.set('x', sx);
    if (!sy.isDone(0)) _sims.set('y', sy);
    _gesture = 'fling';
    _run();
  }

  void _fromOutside(TransformPose given, {bool onlyScale = false}) {
    _gesture = 'variable';
    TransformPose target = given;
    if (onlyScale && _root != null) {
      // A zoom slider: zoom into what the viewport shows.
      final Rect? view = _viewport();
      final Offset focal = view?.center ?? _center;
      target = _around(
        _pose,
        focal,
        factor: given.scale / _pose.scale,
      ).copyWith(rotation: given.rotation);
      target = _clamped(target);
    }
    _written = target;
    if (target != given) widget.onPose?.call(target);
    if (_root == null) {
      setState(() => _pose = target);
      return;
    }
    _springTo(target);
  }

  // ---- Gestures -----------------------------------------------------------

  bool _canAccept(int pointers) => pointers > 1
      ? (_model.zoom || _model.rotate || _model.pan != TransformPan.never)
      : _model.pansAt(_pose.scale);

  TransformPose _startPose = TransformPose.identity;
  Offset _startFocal = Offset.zero;
  Offset _lastFocal = Offset.zero;

  void _onScaleStart(ScaleStartDetails d) {
    _stop();
    // A restart for a finger landing or lifting keeps what the gesture was.
    if (!_gestureActive) {
      _gesturePointers = 0;
      widget.onSelect?.call();
    }
    final bool fresh = !_gestureActive;
    _gestureActive = true;
    _gesturePointers = math.max(_gesturePointers, d.pointerCount);
    _turn = 0;
    _lastRawRotation = 0;
    _pointerCount = d.pointerCount;
    _startPose = _pose;
    // A new gesture pans from where its fingers went down, so the touch
    // slop isn't lost; a restart (a finger landed or lifted) from here.
    _startFocal = fresh && _downAt.isNotEmpty
        ? _local(
            _downAt.values.reduce((a, b) => a + b) / _downAt.length.toDouble(),
          )
        : _local(d.focalPoint);
    _lastFocal = _startFocal;
    _scaleBase = 1;
    _gesture = d.pointerCount > 1 ? 'pinch' : 'pan';
    setState(() {});
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    if (d.pointerCount != _pointerCount) {
      // A finger landed or lifted: carry on from here.
      _pointerCount = d.pointerCount;
      _startPose = _pose;
      _startFocal = _local(d.focalPoint);
      _scaleBase = d.scale;
      _turn = 0;
      _lastRawRotation = d.rotation;
    }
    _gesturePointers = math.max(_gesturePointers, d.pointerCount);
    // The recognizer's rotation jumps by a turn as the fingers cross the
    // ±180° line: add up small steps instead.
    double step = d.rotation - _lastRawRotation;
    while (step > math.pi) {
      step -= 2 * math.pi;
    }
    while (step < -math.pi) {
      step += 2 * math.pi;
    }
    _lastRawRotation = d.rotation;
    _turn += step;
    final Offset focal = _local(d.focalPoint);
    _lastFocal = focal;
    final bool many = d.pointerCount > 1;
    if (!many && !_model.pansAt(_startPose.scale)) return;
    _gesture = many ? 'pinch' : 'pan';
    double factor = _model.zoom && many ? d.scale / _scaleBase : 1;
    final double turn = _model.rotate && many ? _turn * 180 / math.pi : 0;
    final double rubbered = _rubberScale(_startPose.scale * factor);
    factor = rubbered / _startPose.scale;
    Offset pan = focal - _startFocal;
    if (_model.pan == TransformPan.never) pan = Offset.zero;
    TransformPose next = _around(
      _startPose,
      _startFocal,
      factor: factor,
      turn: turn,
      pan: pan,
    );
    // Stretch past the bounds like a rubber band.
    final ((double xlo, double xhi), (double ylo, double yhi)) = _ranges(next);
    final double k = _physics.overscroll;
    next = next.copyWith(
      x: rubberBand(next.x, xlo, xhi, k),
      y: rubberBand(next.y, ylo, yhi, k),
    );
    _set(next);
  }

  double _scaleBase = 1;
  double _turn = 0;
  double _lastRawRotation = 0;
  int _gesturePointers = 0;

  void _onScaleEnd(ScaleEndDetails d) {
    // Fingers lift one at a time: the recognizer ends when the first one
    // does, and starts again only if the other moves on. Settle now; the
    // gesture counts as over once every finger is up (see [_onPointerUp]).
    _gestureActive = _down > 0;
    _scaleBase = 1;
    // A pinch doesn't throw: the last finger up still moves.
    _release(_gesturePointers > 1 ? Offset.zero : d.velocity.pixelsPerSecond);
  }

  void _onDoubleTap() {
    final Offset at = _local(_doubleTapAt ?? Offset.zero);
    final bool zoomedIn = _pose.scale > _minScale + 0.01;
    final double target = zoomedIn
        ? _minScale
        : _model.doubleTapScale.clamp(_minScale, _maxScale);
    widget.onDoubleTap?.call({'x': at.dx, 'y': at.dy, 'scale': target});
    _gesture = 'doubleTap';
    _pointerCount = 1;
    TransformPose next = _around(_pose, at, factor: target / _pose.scale);
    if (zoomedIn && _model.target == TransformTarget.content) {
      next = next.copyWith(x: 0, y: 0);
    }
    _springTo(_clamped(next));
  }

  /// Fingers (or buttons) down on the node now.
  int _down = 0;
  bool _endPending = false;

  /// Where each finger on the node went down, in global coordinates.
  final Map<int, Offset> _downAt = {};

  void _onPointerUp(PointerEvent event) {
    _downAt.remove(event.pointer);
    _down = math.max(0, _down - 1);
    if (_down > 0) return;
    _gestureActive = false;
    if (_endPending && !_ticker.isActive) _finish();
  }

  void _onPointerDown(PointerDownEvent event) {
    _down++;
    _downAt[event.pointer] = event.position;
    if (!widget.enabled) return;
    _scale.addPointer(event);
    if (_model.zoom && _model.doubleTapScale > 0) _doubleTap.addPointer(event);
    if (widget.onSelect != null) _tap.addPointer(event);
  }

  void _onPanZoomStart(PointerPanZoomStartEvent event) {
    if (!widget.enabled) return;
    _scale.addPointerPanZoom(event);
  }

  void _onSignal(PointerSignalEvent event) {
    if (!widget.enabled) return;
    final bool ctrl =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    final WheelZoom wheel = _model.wheel;
    if (event is PointerScaleEvent) {
      if (!_model.zoom) return;
      GestureBinding.instance.pointerSignalResolver.register(
        event,
        (e) => _wheelZoom(_local(e.position), (e as PointerScaleEvent).scale),
      );
      return;
    }
    if (event is! PointerScrollEvent || wheel == WheelZoom.none) return;
    final bool zooms =
        _model.zoom &&
        (wheel == WheelZoom.zoom ||
            (ctrl && (wheel == WheelZoom.ctrlZoom || wheel == WheelZoom.pan)));
    final bool pans = !zooms && wheel == WheelZoom.pan && !ctrl;
    if (!zooms && !pans) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (e) {
      final PointerScrollEvent s = e as PointerScrollEvent;
      if (zooms) {
        _wheelZoom(_local(s.position), math.exp(-s.scrollDelta.dy / 300));
      } else {
        _gesture = 'wheel';
        _stop();
        _set(
          _clamped(
            _pose.copyWith(
              x: _pose.x - s.scrollDelta.dx,
              y: _pose.y - s.scrollDelta.dy,
            ),
          ),
        );
        _scheduleWheelEnd();
      }
    });
  }

  void _wheelZoom(Offset focal, double factor) {
    _stop();
    _gesture = 'wheel';
    _pointerCount = 0;
    final double target = (_pose.scale * factor).clamp(_minScale, _maxScale);
    _set(_clamped(_around(_pose, focal, factor: target / _pose.scale)));
    _scheduleWheelEnd();
  }

  void _scheduleWheelEnd() {
    _wheelEnd?.cancel();
    _wheelEnd = Timer(const Duration(milliseconds: 220), () {
      if (mounted && !active) _finish();
    });
  }

  // ---- Handles ------------------------------------------------------------

  /// The node-local point [q] at the current pose, in layout coordinates.
  Offset _toLayout(Offset q) =>
      MatrixUtils.transformPoint(_pose.matrixFor(_size), q);

  TransformPose? _handleStart;

  void _onHandleStart() {
    _stop();
    widget.onSelect?.call();
    _gestureActive = true;
    _handleStart = _pose;
    _gesture = 'handle';
    _pointerCount = 1;
  }

  void _onHandleEnd() {
    _gestureActive = false;
    _handleStart = null;
    _lastVelocity = Offset.zero;
    final TransformPose clamped = _clamped(_pose);
    if (clamped != _pose) {
      _springTo(clamped);
    } else {
      _finish();
    }
  }

  /// A corner (sx, sy in ±1) or edge (one of them 0) handle dragged to
  /// [global].
  void _onResize(Offset global, double hx, double hy) {
    final TransformHandlesModel handles = _model.handles!;
    final TransformPose from = _handleStart ?? _pose;
    final Offset c = _center + Offset(from.x, from.y);
    final double a = -from.rotation * math.pi / 180;
    final Offset p = _local(global) - c;
    // The pointer in the node's own (unrotated) frame.
    final Offset d = Offset(
      p.dx * math.cos(a) - p.dy * math.sin(a),
      p.dx * math.sin(a) + p.dy * math.cos(a),
    );
    final Size size = _size;
    if (size.isEmpty) return;
    double clampW(double w) => w.clamp(
      handles.minWidth,
      handles.maxWidth > 0 ? handles.maxWidth : double.infinity,
    );
    double clampH(double h) => h.clamp(
      handles.minHeight,
      handles.maxHeight > 0 ? handles.maxHeight : double.infinity,
    );
    TransformPose next = from;
    if (hx != 0 && hy != 0 && handles.aspectLock) {
      final double base = Offset(size.width / 2, size.height / 2).distance;
      double scale = d.distance / base / (from.scaleX + from.scaleY) * 2;
      // Keep the drawn size inside the limits, aspect kept.
      final double w = clampW(size.width * scale * from.scaleX);
      scale = w / (size.width * from.scaleX);
      final double h = clampH(size.height * scale * from.scaleY);
      scale = h / (size.height * from.scaleY);
      next = from.copyWith(scale: scale);
    } else {
      double scaleX = from.scaleX, scaleY = from.scaleY;
      if (hx != 0) {
        scaleX = clampW(d.dx.abs() * 2) / (size.width * from.scale);
      }
      if (hy != 0) {
        scaleY = clampH(d.dy.abs() * 2) / (size.height * from.scale);
      }
      next = from.copyWith(scaleX: scaleX, scaleY: scaleY);
    }
    _set(next);
  }

  void _onRotateHandle(Offset global) {
    final TransformHandlesModel handles = _model.handles!;
    final Offset c = _center + Offset(_pose.x, _pose.y);
    final Offset p = _local(global) - c;
    double angle = math.atan2(p.dy, p.dx) * 180 / math.pi + 90;
    double snap = handles.snapAngle;
    if (snap <= 0 && HardwareKeyboard.instance.isShiftPressed) snap = 15;
    if (snap > 0) angle = (angle / snap).round() * snap;
    // Keep turning the short way from where it was.
    final double from = _pose.rotation;
    while (angle - from > 180) {
      angle -= 360;
    }
    while (angle - from < -180) {
      angle += 360;
    }
    _set(_pose.copyWith(rotation: angle));
  }

  Color _color() {
    final String hex = (_model.handles?.color ?? '').replaceFirst('#', '');
    final int? value = int.tryParse(
      hex.length == 6 ? 'FF$hex' : hex,
      radix: 16,
    );
    return Color(value ?? 0xFF2F80ED);
  }

  List<Widget> _handles() {
    final TransformHandlesModel? handles = _model.handles;
    if (handles == null || !widget.selected || !widget.enabled) return const [];
    final Size size = _size;
    if (size.isEmpty) return const [];
    final Color color = _color();
    final double s = handles.handleSize;
    final double hit = math.max(32, s);
    Widget handle({
      required Offset at,
      required String name,
      required MouseCursor cursor,
      required void Function(Offset global) onMove,
      bool round = false,
    }) => Positioned(
      left: at.dx - hit / 2,
      top: at.dy - hit / 2,
      width: hit,
      height: hit,
      child: MouseRegion(
        cursor: cursor,
        child: GestureDetector(
          key: ValueKey('transform-handle-$name'),
          behavior: HitTestBehavior.opaque,
          onPanStart: (_) => _onHandleStart(),
          onPanUpdate: (d) => onMove(d.globalPosition),
          onPanEnd: (_) => _onHandleEnd(),
          onPanCancel: _onHandleEnd,
          child: Center(
            child: Container(
              width: s,
              height: s,
              decoration: BoxDecoration(
                color: const Color(0xFFFFFFFF),
                border: Border.all(color: color, width: 1.5),
                shape: round ? BoxShape.circle : BoxShape.rectangle,
                borderRadius: round ? null : BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );

    final double w = size.width, h = size.height;
    final List<Widget> out = [
      if (handles.outline)
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _OutlinePainter(
                corners: [
                  _toLayout(Offset.zero),
                  _toLayout(Offset(w, 0)),
                  _toLayout(Offset(w, h)),
                  _toLayout(Offset(0, h)),
                ],
                knob: handles.rotateKnob ? _knobAt() : null,
                top: _toLayout(Offset(w / 2, 0)),
                color: color,
              ),
            ),
          ),
        ),
    ];
    if (handles.corners) {
      for (final (String name, double qx, double qy) in [
        ('tl', -1.0, -1.0),
        ('tr', 1.0, -1.0),
        ('br', 1.0, 1.0),
        ('bl', -1.0, 1.0),
      ]) {
        out.add(
          handle(
            at: _toLayout(Offset((qx + 1) / 2 * w, (qy + 1) / 2 * h)),
            name: name,
            cursor: qx == qy
                ? SystemMouseCursors.resizeUpLeftDownRight
                : SystemMouseCursors.resizeUpRightDownLeft,
            onMove: (g) => _onResize(g, qx, qy),
          ),
        );
      }
    }
    if (handles.edges && !handles.aspectLock) {
      for (final (String name, double qx, double qy) in [
        ('t', 0.0, -1.0),
        ('r', 1.0, 0.0),
        ('b', 0.0, 1.0),
        ('l', -1.0, 0.0),
      ]) {
        out.add(
          handle(
            at: _toLayout(Offset((qx + 1) / 2 * w, (qy + 1) / 2 * h)),
            name: name,
            cursor: qx == 0
                ? SystemMouseCursors.resizeUpDown
                : SystemMouseCursors.resizeLeftRight,
            onMove: (g) => _onResize(g, qx, qy),
          ),
        );
      }
    }
    if (handles.rotateKnob) {
      out.add(
        handle(
          at: _knobAt(),
          name: 'rotate',
          cursor: SystemMouseCursors.grab,
          round: true,
          onMove: _onRotateHandle,
        ),
      );
    }
    return out;
  }

  /// Where the rotate knob sits: 28px above the top edge's middle, turned
  /// with the node.
  Offset _knobAt() {
    final Offset top = _toLayout(Offset(_size.width / 2, 0));
    final double a = _pose.rotation * math.pi / 180;
    return top + Offset(math.sin(a), -math.cos(a)) * 28;
  }

  // ---- Build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final TransformValues values = TransformValues(
      pose: _pose,
      active: active,
      selected: widget.selected,
    );
    Widget child = TransformScope(values: values, child: widget.child);
    final Matrix4 matrix = _pose.centeredMatrix;
    final Size size = _size;
    if (size != _builtSize) {
      // Handles are placed by the node's size, known after layout.
      final bool first = _builtSize == null || size.isEmpty;
      _builtSize = size;
      if (_model.handles != null && (first || size != Size.zero)) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() {});
        });
      }
    }
    Widget listen(Widget child) => Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerUp,
      onPointerPanZoomStart: _onPanZoomStart,
      onPointerSignal: _onSignal,
      child: child,
    );

    if (_model.target == TransformTarget.content) {
      // The node stays; its content zooms inside its own box.
      return listen(
        ClipRect(
          child: Transform(
            alignment: Alignment.center,
            transform: matrix,
            child: child,
          ),
        ),
      );
    }
    final List<Widget> handles = _handles();
    // Listening inside the transform takes pointers where the node is
    // drawn, not where it was laid out.
    final Widget body = Transform(
      alignment: Alignment.center,
      transform: matrix,
      child: listen(child),
    );
    return _OverflowStack(children: [body, ...handles]);
  }
}

class _OutlinePainter extends CustomPainter {
  _OutlinePainter({
    required this.corners,
    required this.top,
    required this.knob,
    required this.color,
  });

  final List<Offset> corners;
  final Offset top;
  final Offset? knob;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(Path()..addPolygon(corners, true), paint);
    if (knob != null) canvas.drawLine(top, knob!, paint);
  }

  @override
  bool shouldRepaint(_OutlinePainter old) =>
      old.color != color ||
      old.knob != knob ||
      old.top != top ||
      !_listEquals(old.corners, corners);

  static bool _listEquals(List<Offset> a, List<Offset> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// A stack sized by its first child that takes pointers on any child,
/// even where the children reach past its own box: a moved, scaled node
/// and its handles.
class _OverflowStack extends Stack {
  const _OverflowStack({super.children})
    : super(fit: StackFit.passthrough, clipBehavior: Clip.none);

  @override
  RenderStack createRenderObject(BuildContext context) => _RenderOverflowStack(
    alignment: alignment,
    textDirection: textDirection ?? Directionality.maybeOf(context),
    fit: fit,
    clipBehavior: clipBehavior,
  );
}

class _RenderOverflowStack extends RenderStack {
  _RenderOverflowStack({
    super.alignment,
    super.textDirection,
    super.fit,
    super.clipBehavior,
  });

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (hitTestChildren(result, position: position)) {
      result.add(BoxHitTestEntry(this, position));
      return true;
    }
    return false;
  }
}
