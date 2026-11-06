import 'dart:math' as math;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'node_motion.dart';

/// The live state of a drag track, as the `track` variable shows it.
@immutable
class TrackValues {
  /// The variable's value where the node is now; NaN while the variable is
  /// empty or not a number.
  final double value;

  /// Where the node is along its track, 0 to 1 (outside that while it is
  /// stretched past an end or parked, see
  /// [DragTrackModel.parkedProgress]).
  final double progress;

  /// Whether a pointer is dragging the node now.
  final bool dragging;

  /// Whether the track has keyboard focus (see [DragTrackModel.keyboard]).
  final bool focused;

  /// Creates [TrackValues].
  const TrackValues({
    this.value = 0,
    this.progress = 0,
    this.dragging = false,
    this.focused = false,
  });

  /// The values as the `track` variable reads them.
  Map<String, dynamic> toMap() => {
    'value': value.isNaN ? null : value,
    'progress': progress,
    'dragging': dragging,
    'focused': focused,
  };

  @override
  bool operator ==(Object other) =>
      other is TrackValues &&
      (other.value == value || (other.value.isNaN && value.isNaN)) &&
      other.progress == progress &&
      other.dragging == dragging &&
      other.focused == focused;

  @override
  int get hashCode =>
      Object.hash(value.isNaN ? null : value, progress, dragging, focused);
}

/// Shares the nearest [NodeDragTrack]'s state with the nodes inside it,
/// which read it as the `track` variable.
class TrackScope extends InheritedWidget {
  /// The track's live values.
  final TrackValues values;

  /// Creates a [TrackScope].
  const TrackScope({super.key, required this.values, required super.child});

  /// The values of the nearest track above [context], or null outside one.
  static TrackValues? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TrackScope>()?.values;

  @override
  bool updateShouldNotify(TrackScope oldWidget) => values != oldWidget.values;
}

/// Geometry of a [DragTrackModel], in the node's own coordinates with the
/// origin at the node's rest centre.
class DragTrackGeometry {
  /// Creates the geometry of [track].
  DragTrackGeometry(this.track) {
    final String? data = track.path;
    if (track.shape == DragTrackShape.path && data != null) {
      // Samples for finding the nearest point to the pointer.
      const int n = 240;
      for (int i = 0; i <= n; i++) {
        final (Offset, double)? point = pointOnMotionPath(data, i / n);
        if (point == null) break;
        _samples.add(point.$1);
      }
    }
  }

  /// The track.
  final DragTrackModel track;
  final List<Offset> _samples = [];

  /// Where the node's centre sits at [progress], relative to rest.
  /// A line or arc goes on past its ends for a progress outside 0 to 1
  /// (a drag stretched past an end, see [DragTrackModel.overscroll]); a
  /// path stops at its ends.
  Offset offsetAt(double progress) {
    final double p = track.shape == DragTrackShape.path
        ? progress.clamp(0.0, 1.0)
        : progress;
    switch (track.shape) {
      case DragTrackShape.line:
        return Offset.lerp(
          Offset(track.x1, track.y1),
          Offset(track.x2, track.y2),
          p,
        )!;
      case DragTrackShape.arc:
        // The node turns around the pivot: its centre moves on a circle
        // through rest, from where it stands at angle 0.
        final Offset pivot = Offset(track.pivotX, track.pivotY);
        if (pivot == Offset.zero) return Offset.zero;
        final double a = _angle(p) * math.pi / 180;
        final Offset r = -pivot;
        return pivot +
            Offset(
              r.dx * math.cos(a) - r.dy * math.sin(a),
              r.dx * math.sin(a) + r.dy * math.cos(a),
            );
      case DragTrackShape.path:
        final String? data = track.path;
        if (data == null) return Offset.zero;
        return pointOnMotionPath(data, p)?.$1 ?? Offset.zero;
    }
  }

  /// The arc's angle at [progress], going on past its ends.
  double _angle(double progress) =>
      track.startAngle + (track.endAngle - track.startAngle) * progress;

  /// How much the node turns at [progress], in degrees.
  double rotationAt(double progress) {
    switch (track.shape) {
      case DragTrackShape.line:
        return 0;
      case DragTrackShape.arc:
        return track.rotate ? _angle(progress) : 0;
      case DragTrackShape.path:
        final String? data = track.path;
        if (!track.orientToPath || data == null) return 0;
        final (Offset, double)? point = pointOnMotionPath(data, progress);
        if (point == null) return 0;
        final double angle = track.orientUpright
            ? uprightPathAngle(point.$2)
            : point.$2;
        return angle * 180 / math.pi;
    }
  }

  /// The transform that draws the node at [progress] around its centre (for
  /// a [Transform] aligned to [Alignment.center]).
  Matrix4 poseAt(double progress) {
    final Offset o = offsetAt(progress);
    return Matrix4.identity()
      ..translateByDouble(o.dx, o.dy, 0, 1)
      ..rotateZ(rotationAt(progress) * math.pi / 180);
  }

  /// The transform that draws the node at [progress], for a box of [size].
  Matrix4 transformAt(double progress, Size size) {
    final Offset o = offsetAt(progress);
    final double r = rotationAt(progress) * math.pi / 180;
    final Offset c = size.center(Offset.zero);
    return Matrix4.identity()
      ..translateByDouble(o.dx + c.dx, o.dy + c.dy, 0, 1)
      ..rotateZ(r)
      ..translateByDouble(-c.dx, -c.dy, 0, 1);
  }

  /// The progress of the point on a line or path nearest to [p] (relative
  /// to the rest centre).
  /// A line's point may lie past its ends ([unclamped]), for a drag that
  /// stretches past them.
  double nearest(Offset p, {bool unclamped = false}) {
    switch (track.shape) {
      case DragTrackShape.line:
        final Offset a = Offset(track.x1, track.y1);
        final Offset d = Offset(track.x2, track.y2) - a;
        final double len2 = d.distanceSquared;
        if (len2 == 0) return 0;
        final Offset ap = p - a;
        final double t = (ap.dx * d.dx + ap.dy * d.dy) / len2;
        return unclamped ? t : t.clamp(0.0, 1.0);
      case DragTrackShape.path:
        if (_samples.isEmpty) return 0;
        int best = 0;
        double bestD = double.infinity;
        for (int i = 0; i < _samples.length; i++) {
          final double dd = (_samples[i] - p).distanceSquared;
          if (dd < bestD) {
            bestD = dd;
            best = i;
          }
        }
        return best / (_samples.length - 1);
      case DragTrackShape.arc:
        return 0;
    }
  }

  /// The pointer's angle around the arc's pivot, degrees clockwise from up.
  double angleOf(Offset p) {
    final Offset v = p - Offset(track.pivotX, track.pivotY);
    return math.atan2(v.dx, -v.dy) * 180 / math.pi;
  }

  /// The progress along an arc that points nearest to [angle] (degrees,
  /// clockwise from up, any turn): an angle in the gap the arc leaves
  /// goes to the nearer end.
  double progressAtAngle(double angle) {
    final double s = track.startAngle;
    final double sweep = track.endAngle - s;
    if (sweep == 0) return 0;
    final double lo = math.min(s, track.endAngle);
    final double hi = math.max(s, track.endAngle);
    double a = lo + (angle - lo) % 360;
    if (a > hi) a = (a - hi) <= (lo + 360 - a) ? hi : lo;
    return ((a - s) / sweep).clamp(0.0, 1.0);
  }

  /// The circle an arc's node sweeps round its pivot, as (centre, radius)
  /// relative to the rest centre, for a node of [size].
  (Offset, double) sweptCircle(Size size) {
    final Offset pivot = Offset(track.pivotX, track.pivotY);
    return (pivot, pivot.distance + size.longestSide / 2);
  }

  /// The area the node can be found in anywhere along the track, inflated
  /// by the node's own box, in coordinates relative to the rest centre.
  Rect bounds(Size size) {
    Rect r = Rect.zero;
    for (int i = 0; i <= 24; i++) {
      final Offset o = offsetAt(i / 24);
      final Rect dot = Rect.fromCircle(center: o, radius: 0);
      r = i == 0 ? dot : r.expandToInclude(dot);
    }
    final double half = size.longestSide / 2;
    return r.inflate(half);
  }
}

/// The spring a [DragTrackModel] settles with when its
/// [DragTrackModel.settleCurve] is [MotionCurve.spring].
SpringDescription trackSettleSpring(DragTrackModel track) => SpringDescription(
  mass: 1,
  stiffness: track.settleStiffness <= 0 ? 380 : track.settleStiffness,
  damping: track.settleDamping < 0 ? 20 : track.settleDamping,
);

/// Makes [child] a value control that moves along [track]: it is drawn at
/// [value]'s place on the track (or parked, see
/// [DragTrackModel.parkedProgress]), and dragging it (or, with
/// [DragTrackModel.jumpOnTap], tapping along the track) reports new values
/// through [onChanged]. Double tap resets to [DragTrackModel.defaultValue];
/// the mouse wheel and, while focused, the keys step the value (see
/// [DragTrackModel.keyboard]). Screen readers see a slider.
class NodeDragTrack extends StatefulWidget {
  /// Creates a [NodeDragTrack].
  const NodeDragTrack({
    super.key,
    required this.track,
    required this.value,
    required this.onChanged,
    required this.child,
    this.onEnd,
    this.onRelease,
    this.enabled = true,
  });

  /// The track.
  final DragTrackModel track;

  /// The variable's current value; NaN for an empty variable or one that
  /// isn't a number (drawn at [DragTrackModel.parkedProgress]).
  final double value;

  /// Called with each new (snapped) value while dragging.
  final ValueChanged<double> onChanged;

  /// Called when the pointer lifts, with the final value.
  final ValueChanged<double>? onEnd;

  /// Called when the pointer lifts after a drag, with the final value, the
  /// value the drag started at and the release velocity in the variable's
  /// units per second along the track (see [DragTrackModel.endValues]);
  /// also after each wheel or key step, with no velocity.
  final void Function(double value, double startValue, double velocity)?
  onRelease;

  /// Whether the control responds to the pointer.
  final bool enabled;

  /// The node.
  final Widget child;

  @override
  State<NodeDragTrack> createState() => _NodeDragTrackState();
}

class _NodeDragTrackState extends State<NodeDragTrack>
    with SingleTickerProviderStateMixin {
  late DragTrackGeometry _geometry = DragTrackGeometry(widget.track);

  /// The pointer's progress while dragging, unsnapped (and past the ends
  /// when the track allows [DragTrackModel.overscroll]).
  double _raw = 0;

  /// The value shown while dragging, ahead of the variable catching up.
  double? _dragValue;
  double? _lastAngle;
  Offset _grab = Offset.zero;
  Size _size = Size.zero;
  double _startValue = 0;

  /// Glides the drawn progress from [_settleFrom] to [_settleTo] (0 to 1,
  /// overshooting for springy curves); see [DragTrackModel.settleMs]. A
  /// spring settle runs in progress itself (from 0 to 1), so it can carry
  /// the speed it starts with.
  late final AnimationController _settle = AnimationController.unbounded(
    vsync: this,
    value: 1,
  )..addListener(() => setState(() {}));
  double _settleFrom = 0;
  double _settleTo = 0;

  late final PanGestureRecognizer _pan = PanGestureRecognizer()
    ..dragStartBehavior = DragStartBehavior.down
    ..onStart = _onStart
    ..onUpdate = _onUpdate
    ..onEnd = _onEnd
    ..onCancel = (() => _onEnd(null));
  late final DoubleTapGestureRecognizer _doubleTap =
      DoubleTapGestureRecognizer()..onDoubleTap = _onDoubleTap;

  final FocusNode _focus = FocusNode(debugLabel: 'NodeDragTrack');
  bool _focused = false;

  /// The value the last wheel or key step wrote, until the widget is
  /// rebuilt with it: quick key repeats step on from there.
  double? _stepValue;

  @override
  void didUpdateWidget(NodeDragTrack oldWidget) {
    super.didUpdateWidget(oldWidget);
    _stepValue = null;
    if (oldWidget.track != widget.track) {
      _geometry = DragTrackGeometry(widget.track);
    }
    if (_dragValue == null && !_same(oldWidget.value, widget.value)) {
      // Changed by an action, a tap, a key or a reset: glide from where it
      // is drawn now (to or from its parked place too), at the speed it is
      // moving: a deck flung on to its next card carries on smoothly.
      final double from = _settling
          ? _lerpSettle
          : oldWidget.track.restProgressOf(oldWidget.value);
      _glide(
        from,
        _track.restProgressOf(widget.value),
        velocity: _settleVelocity,
      );
    }
  }

  @override
  void dispose() {
    _pan.dispose();
    _doubleTap.dispose();
    _settle.dispose();
    _focus.dispose();
    super.dispose();
  }

  DragTrackModel get _track => widget.track;
  double get _shownValue => _dragValue ?? widget.value;

  /// Equal values, NaN (an empty variable) included.
  static bool _same(double a, double b) => a == b || (a.isNaN && b.isNaN);

  /// Whether the keys move the track (and it takes focus).
  bool get _keys => _track.keyboard && widget.enabled;

  bool get _settling => _settle.isAnimating;
  double get _lerpSettle =>
      _settleFrom + (_settleTo - _settleFrom) * _settle.value;

  /// How fast the glide moves the drawn progress now, per second.
  double get _settleVelocity =>
      _settling ? _settle.velocity * (_settleTo - _settleFrom) : 0;

  /// Whether value changes glide instead of jumping.
  bool get _glides =>
      _track.settleMs > 0 || _track.settleCurve == MotionCurve.spring;

  /// Where the node is drawn along the track: following the pointer (held
  /// back by the step's detent, stretched past the ends), gliding to its
  /// value, or at its value.
  double get _progress {
    if (_dragValue != null) return _dragProgress;
    if (_settling) return _lerpSettle;
    return _track.restProgressOf(widget.value);
  }

  double get _dragProgress {
    final double clamped = _raw.clamp(0.0, 1.0);
    double p = clamped;
    if (_track.step > 0 && !_shownValue.isNaN) {
      final double snapped = _track.progressOf(_shownValue);
      p = snapped + (clamped - snapped) * _track.detent.clamp(0.0, 1.0);
    }
    return p + (_raw - clamped) * _track.overscroll.clamp(0.0, 1.0);
  }

  /// Glides the drawn progress from [from] to [to]. A spring starts at
  /// [velocity] (progress per second), so a release or a glide already
  /// under way carries on; eased curves start from rest.
  void _glide(double from, double to, {double velocity = 0}) {
    final bool spring = _track.settleCurve == MotionCurve.spring;
    if (!_glides ||
        (from == to && (!spring || velocity == 0)) ||
        !velocity.isFinite ||
        !mounted) {
      _settle.value = 1;
      _settleFrom = _settleTo = to;
      return;
    }
    if (spring) {
      _settleFrom = 0;
      _settleTo = 1;
      _settle.animateWith(
        SpringSimulation(trackSettleSpring(_track), from, to, velocity),
      );
    } else {
      _settleFrom = from;
      _settleTo = to;
      _settle
        ..value = 0
        ..animateTo(
          1,
          duration: Duration(milliseconds: _track.settleMs),
          curve: flutterCurveOf(_track.settleCurve),
        );
    }
  }

  /// [local] (in the node's untransformed box) relative to the rest centre.
  Offset _rel(Offset local) => local - _size.center(Offset.zero);

  void _emit(double raw) {
    _raw = _track.overscroll > 0 ? raw : raw.clamp(0.0, 1.0);
    final double v = _track.valueAt(_raw.clamp(0.0, 1.0));
    if (v != _shownValue) {
      setState(() => _dragValue = v);
      widget.onChanged(v);
    } else {
      // The drawn place moves with the pointer between steps.
      setState(() {});
    }
  }

  /// Whether a pointer at [p] (relative to the rest centre) is too near an
  /// arc's pivot for a steady angle.
  bool _nearPivot(Offset p) =>
      (p - Offset(_track.pivotX, _track.pivotY)).distance <
      _size.shortestSide * 0.12;

  void _pointerDown(PointerDownEvent event, Offset local, bool onNode) {
    if (!widget.enabled) return;
    if (_keys) _focus.requestFocus();
    _startValue = widget.value;
    if (_track.jumpOnTap && _track.input == DragTrackInput.follow) {
      final Offset p = _rel(local);
      if (_track.shape == DragTrackShape.arc) {
        // Tapped round the dial: point at the angle tapped, then drag from
        // there.
        if (!_nearPivot(p)) {
          _raw = _progress;
          _emit(_geometry.progressAtAngle(_geometry.angleOf(p)));
        }
      } else if (!onNode) {
        // Tapped the track off the node: jump there, then drag from there.
        _raw = _progress;
        _emit(_geometry.nearest(p));
      }
    }
    _pan.addPointer(event);
    _doubleTap.addPointer(event);
  }

  void _onStart(DragStartDetails d) {
    final Offset p = _rel(d.localPosition);
    _settle.stop();
    // After a tap jump the drag goes on from where it jumped to (the
    // variable may not have caught up yet).
    if (_dragValue == null) {
      setState(() {
        _dragValue = widget.value;
        // A parked node is dragged from the nearest end.
        _raw = _track.restProgressOf(widget.value).clamp(0.0, 1.0);
      });
    }
    _lastAngle = _geometry.angleOf(p);
    _grab = _geometry.offsetAt(_raw) - p;
  }

  void _onUpdate(DragUpdateDetails d) {
    final Offset p = _rel(d.localPosition);
    switch (_track.input) {
      case DragTrackInput.vertical:
        _emit(_raw - d.delta.dy / _track.pixelsPerRange);
      case DragTrackInput.horizontal:
        _emit(_raw + d.delta.dx / _track.pixelsPerRange);
      case DragTrackInput.follow:
        if (_track.shape == DragTrackShape.arc) {
          if (_nearPivot(p)) {
            // Too close to the pivot for a steady angle: use vertical travel.
            _emit(_raw - d.delta.dy / _track.pixelsPerRange);
            _lastAngle = _geometry.angleOf(p);
            return;
          }
          final double angle = _geometry.angleOf(p);
          double delta = angle - (_lastAngle ?? angle);
          if (delta > 180) delta -= 360;
          if (delta < -180) delta += 360;
          _lastAngle = angle;
          final double sweep = _track.endAngle - _track.startAngle;
          if (sweep != 0) _emit(_raw + delta / sweep);
        } else {
          _emit(_geometry.nearest(p + _grab, unclamped: _track.overscroll > 0));
        }
    }
  }

  /// [velocity] (pixels per second) as progress along the track per second.
  double _progressVelocity(Velocity? velocity) {
    if (velocity == null) return 0;
    final Offset v = velocity.pixelsPerSecond;
    switch (_track.input) {
      case DragTrackInput.vertical:
        return -v.dy / _track.pixelsPerRange;
      case DragTrackInput.horizontal:
        return v.dx / _track.pixelsPerRange;
      case DragTrackInput.follow:
        if (_track.shape == DragTrackShape.arc) {
          final double sweep = _track.endAngle - _track.startAngle;
          final Offset r =
              _geometry.offsetAt(_raw.clamp(0.0, 1.0)) -
              Offset(_track.pivotX, _track.pivotY) -
              _grab;
          final double r2 = r.distanceSquared;
          if (sweep == 0 || r2 == 0) return 0;
          final double degPerSec =
              (r.dx * v.dy - r.dy * v.dx) / r2 * 180 / math.pi;
          return degPerSec / sweep;
        }
        final double p = _raw.clamp(0.0, 1.0);
        final double a = (p - 0.01).clamp(0.0, 1.0);
        final double b = (p + 0.01).clamp(0.0, 1.0);
        if (a == b) return 0;
        final Offset t =
            (_geometry.offsetAt(b) - _geometry.offsetAt(a)) / (b - a);
        final double t2 = t.distanceSquared;
        return t2 == 0 ? 0 : (v.dx * t.dx + v.dy * t.dy) / t2;
    }
  }

  void _onEnd(DragEndDetails? details) {
    if (_dragValue == null) return;
    final double v = _shownValue;
    final double drawn = _dragProgress;
    final double progressVelocity = _progressVelocity(details?.velocity);
    final double velocity = progressVelocity * (_track.max - _track.min);
    // Hold the dragged value until the variable has caught up. A spring
    // settle starts at the release speed, so a fling carries on.
    setState(() => _dragValue = null);
    _glide(drawn, _track.progressOf(v), velocity: progressVelocity);
    widget.onEnd?.call(v);
    widget.onRelease?.call(v, _startValue, velocity);
  }

  void _onDoubleTap() {
    final double? reset = _track.defaultValue;
    if (reset == null || !widget.enabled) return;
    final double v = _track.snap(reset);
    widget.onChanged(v);
    widget.onEnd?.call(v);
  }

  /// Whether [v] is a value on the track (not empty, not out of range).
  bool _inRange(double v) {
    if (v.isNaN) return false;
    final double lo = math.min(_track.min, _track.max);
    final double hi = math.max(_track.min, _track.max);
    return v >= lo && v <= hi;
  }

  /// The value [steps] wheel steps (or key steps) from the current one,
  /// toward [DragTrackModel.max] when positive. From an empty or
  /// out-of-range value any step lands on the nearest end.
  double _stepped(int steps) {
    final double v = _stepValue ?? widget.value;
    if (!_inRange(v)) {
      return _track.valueAt(_track.restProgressOf(v) <= 0.5 ? 0 : 1);
    }
    final double up = _track.max >= _track.min ? 1 : -1;
    return _track.snap(v + steps * up * _track.wheelStep);
  }

  /// Writes [v] from a wheel or key step: `changed`, then the end
  /// callbacks as a drag that let go there with no velocity.
  void _commitStep(double v) {
    final double start = _stepValue ?? widget.value;
    if (_same(v, start)) return;
    _stepValue = v;
    widget.onChanged(v);
    widget.onEnd?.call(v);
    widget.onRelease?.call(v, start, 0);
  }

  void _onWheel(PointerScrollEvent event) {
    if (!_track.wheel || !widget.enabled) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (e) {
      final PointerScrollEvent s = e as PointerScrollEvent;
      _commitStep(_stepped(s.scrollDelta.dy < 0 ? 1 : -1));
    });
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!_keys || _dragValue != null) return KeyEventResult.ignored;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final LogicalKeyboardKey key = event.logicalKey;
    final double? v = switch (key) {
      _ when key == LogicalKeyboardKey.arrowRight => _stepped(1),
      _ when key == LogicalKeyboardKey.arrowUp => _stepped(1),
      _ when key == LogicalKeyboardKey.arrowLeft => _stepped(-1),
      _ when key == LogicalKeyboardKey.arrowDown => _stepped(-1),
      _ when key == LogicalKeyboardKey.pageUp => _stepped(10),
      _ when key == LogicalKeyboardKey.pageDown => _stepped(-10),
      _ when key == LogicalKeyboardKey.home => _track.snap(_track.min),
      _ when key == LogicalKeyboardKey.end => _track.snap(_track.max),
      _ => null,
    };
    if (v == null) return KeyEventResult.ignored;
    _commitStep(v);
    return KeyEventResult.handled;
  }

  /// [v] as a screen reader reads it: empty while there is no value.
  String _valueText(double v) {
    if (!_inRange(v)) return '';
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v
        .toStringAsFixed(6)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  @override
  Widget build(BuildContext context) {
    final double progress = _progress;
    final double shown = _shownValue;
    final bool enabled = widget.enabled;
    final double up = _stepped(1);
    final double down = _stepped(-1);
    return _TrackArea(
      geometry: _geometry,
      progress: progress,
      jumpOnTap: _track.jumpOnTap,
      onSize: (size) => _size = size,
      onPointerDown: _pointerDown,
      onWheel: _onWheel,
      // Inside the moved area, so the slider's bounds follow the node.
      child: Semantics(
        container: true,
        slider: true,
        enabled: enabled,
        // Empty while there is no value (parked), as the slider's next
        // values must be too.
        value: _valueText(shown),
        increasedValue: _inRange(shown) ? _valueText(up) : '',
        decreasedValue: _inRange(shown) ? _valueText(down) : '',
        onIncrease: enabled && !_same(up, widget.value)
            ? () => _commitStep(up)
            : null,
        onDecrease: enabled && !_same(down, widget.value)
            ? () => _commitStep(down)
            : null,
        child: Focus(
          focusNode: _focus,
          canRequestFocus: _keys,
          skipTraversal: !_keys,
          onKeyEvent: _onKey,
          onFocusChange: (focused) => setState(() => _focused = focused),
          child: TrackScope(
            values: TrackValues(
              value: shown,
              progress: progress,
              dragging: _dragValue != null,
              focused: _focused,
            ),
            child: MouseRegion(
              cursor: enabled
                  ? (_dragValue != null
                        ? SystemMouseCursors.grabbing
                        : SystemMouseCursors.grab)
                  : MouseCursor.defer,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Draws its child moved along the track and takes pointer events on the
/// moved child, or anywhere along the track when [jumpOnTap].
class _TrackArea extends SingleChildRenderObjectWidget {
  const _TrackArea({
    required this.geometry,
    required this.progress,
    required this.jumpOnTap,
    required this.onSize,
    required this.onPointerDown,
    required this.onWheel,
    required super.child,
  });

  final DragTrackGeometry geometry;
  final double progress;
  final bool jumpOnTap;
  final ValueChanged<Size> onSize;
  final void Function(PointerDownEvent event, Offset local, bool onNode)
  onPointerDown;
  final ValueChanged<PointerScrollEvent> onWheel;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderTrackArea()
    ..geometry = geometry
    ..progress = progress
    ..jumpOnTap = jumpOnTap
    ..onSize = onSize
    ..onPointerDown = onPointerDown
    ..onWheel = onWheel;

  @override
  void updateRenderObject(BuildContext context, _RenderTrackArea r) => r
    ..geometry = geometry
    ..progress = progress
    ..jumpOnTap = jumpOnTap
    ..onSize = onSize
    ..onPointerDown = onPointerDown
    ..onWheel = onWheel;
}

class _RenderTrackArea extends RenderProxyBox {
  late DragTrackGeometry _geometry;
  set geometry(DragTrackGeometry g) {
    _geometry = g;
    markNeedsPaint();
  }

  double _progress = 0;
  set progress(double p) {
    if (p == _progress) return;
    _progress = p;
    markNeedsPaint();
  }

  bool jumpOnTap = false;
  late ValueChanged<Size> onSize;
  late void Function(PointerDownEvent, Offset, bool) onPointerDown;
  late ValueChanged<PointerScrollEvent> onWheel;

  /// Whether the last hit landed on the moved child (else on the track).
  bool _hitNode = false;

  Matrix4 get _transform => _geometry.transformAt(_progress, size);

  @override
  void performLayout() {
    super.performLayout();
    onSize(size);
  }

  /// Whether [position] (in this box) lies on the track's area: the circle
  /// an arc's node sweeps, or the box around a line or path.
  bool _onTrack(Offset position) {
    final Offset rel = position - size.center(Offset.zero);
    if (_geometry.track.shape == DragTrackShape.arc) {
      final (Offset centre, double radius) = _geometry.sweptCircle(size);
      return (rel - centre).distance <= radius;
    }
    return _geometry.bounds(size).contains(rel);
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    _hitNode = hitTestChildren(result, position: position);
    final bool onTrack =
        jumpOnTap &&
        _geometry.track.input == DragTrackInput.follow &&
        _onTrack(position);
    if (_hitNode || onTrack) {
      result.add(BoxHitTestEntry(this, position));
      return true;
    }
    return false;
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    if (child == null) return false;
    return result.addWithPaintTransform(
      transform: _transform,
      position: position,
      hitTest: (result, position) {
        // Only the child's own box counts, not its overflow.
        if (!child!.size.contains(position)) return false;
        child!.hitTest(result, position: position);
        return true;
      },
    );
  }

  @override
  void handleEvent(PointerEvent event, HitTestEntry entry) {
    if (event is PointerDownEvent) {
      onPointerDown(event, (entry as BoxHitTestEntry).localPosition, _hitNode);
    } else if (event is PointerScrollEvent) {
      onWheel(event);
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) return;
    layer = context.pushTransform(
      needsCompositing,
      offset,
      _transform,
      super.paint,
      oldLayer: layer is TransformLayer ? layer as TransformLayer : null,
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.multiply(_transform);
  }
}
