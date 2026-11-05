import 'dart:math' as math;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'node_motion.dart';

/// The live state of a drag track, as the `track` variable shows it.
@immutable
class TrackValues {
  /// The variable's value where the node is now.
  final double value;

  /// Where the node is along its track, 0 to 1.
  final double progress;

  /// Whether a pointer is dragging the node now.
  final bool dragging;

  /// Creates [TrackValues].
  const TrackValues({this.value = 0, this.progress = 0, this.dragging = false});

  /// The values as the `track` variable reads them.
  Map<String, dynamic> toMap() => {
    'value': value,
    'progress': progress,
    'dragging': dragging,
  };

  @override
  bool operator ==(Object other) =>
      other is TrackValues &&
      other.value == value &&
      other.progress == progress &&
      other.dragging == dragging;

  @override
  int get hashCode => Object.hash(value, progress, dragging);
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
  Offset offsetAt(double progress) {
    final double p = track.clampProgress(progress);
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
        final double a = track.angleAt(p) * math.pi / 180;
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

  /// How much the node turns at [progress], in degrees.
  double rotationAt(double progress) {
    switch (track.shape) {
      case DragTrackShape.line:
        return 0;
      case DragTrackShape.arc:
        return track.rotate ? track.angleAt(progress) : 0;
      case DragTrackShape.path:
        final String? data = track.path;
        if (!track.orientToPath || data == null) return 0;
        final (Offset, double)? point = pointOnMotionPath(data, progress);
        return point == null ? 0 : point.$2 * 180 / math.pi;
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
  double nearest(Offset p) {
    switch (track.shape) {
      case DragTrackShape.line:
        final Offset a = Offset(track.x1, track.y1);
        final Offset d = Offset(track.x2, track.y2) - a;
        final double len2 = d.distanceSquared;
        if (len2 == 0) return 0;
        final Offset ap = p - a;
        return ((ap.dx * d.dx + ap.dy * d.dy) / len2).clamp(0.0, 1.0);
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

/// One change of a track's value, as `changed` reactions read it in
/// `${result}`: the new [value], the value it moved [from], its
/// [direction] (1 toward `max`, -1 toward `min`) and every step it
/// [crossed] on the way, in order, ending with [value] (a dial spun past
/// several numbers in one frame crosses each of them).
@immutable
class TrackChange {
  /// Creates a [TrackChange].
  const TrackChange({
    required this.value,
    required this.from,
    required this.crossed,
  });

  /// The new value.
  final double value;

  /// The value before.
  final double from;

  /// The steps passed, from just after [from] up to [value].
  final List<double> crossed;

  /// 1 when the value grew, -1 when it shrank, 0 when it didn't change.
  int get direction => value > from ? 1 : (value < from ? -1 : 0);

  /// The change as reactions read it.
  Map<String, dynamic> toMap() => {
    'value': value,
    'from': from,
    'direction': direction,
    'crossed': crossed,
  };
}

/// Makes [child] a value control that moves along [track]: it is drawn at
/// [value]'s place on the track, and dragging it (or, with
/// [DragTrackModel.jumpOnTap], tapping along the track) reports new values
/// through [onChanged]. Double tap resets to [DragTrackModel.defaultValue];
/// the mouse wheel steps the value.
///
/// With [DragTrackModel.momentum] a flick keeps it going after the pointer
/// lifts, slowing by [DragTrackModel.friction]; with
/// [DragTrackModel.smooth] it is drawn between steps while it moves and
/// springs onto a step when it stops. [onSettled] reports the value it comes
/// to rest on. [step] turns a mounted track from an action.
class NodeDragTrack extends StatefulWidget {
  /// Creates a [NodeDragTrack].
  const NodeDragTrack({
    super.key,
    required this.track,
    required this.value,
    required this.onChanged,
    required this.child,
    this.onEnd,
    this.onChange,
    this.onSettled,
    this.enabled = true,
    this.gain,
    this.nodeId,
  });

  /// The track.
  final DragTrackModel track;

  /// The variable's current value.
  final double value;

  /// Called with each new (snapped) value while dragging.
  final ValueChanged<double> onChanged;

  /// Called with each change and what it crossed, after [onChanged].
  final ValueChanged<TrackChange>? onChange;

  /// Called when the pointer lifts, with the final value.
  final ValueChanged<double>? onEnd;

  /// Called when the control comes to rest after a drag, a coast, a wheel
  /// notch or a [step], with the value it rests on.
  final ValueChanged<double>? onSettled;

  /// Whether the control responds to the pointer.
  final bool enabled;

  /// Pointer gain, overriding [DragTrackModel.gain] (a bound setting).
  final double? gain;

  /// The node's id, so actions can [step] it.
  final String? nodeId;

  /// The node.
  final Widget child;

  static final Map<String, List<_NodeDragTrackState>> _instances = {};

  /// Turns the track of node [nodeId] by [steps] steps, as if dragged
  /// there. Returns false when no such track is on screen.
  ///
  /// [nodeId] may list several ids separated by commas: the copies of one
  /// control in a responsive screen's layouts, of which only the one for
  /// the screen's width is built.
  static Future<bool> step(String nodeId, int steps) async {
    final List<_NodeDragTrackState> all = [
      for (final String id in nodeId.split(','))
        for (final s in _instances[id.trim()] ?? const <_NodeDragTrackState>[])
          if (s.mounted) s,
    ];
    if (all.isEmpty) return false;
    final _NodeDragTrackState target = all.firstWhere(
      (s) => s.widget.enabled,
      orElse: () => all.first,
    );
    return target.stepBy(steps);
  }

  @override
  State<NodeDragTrack> createState() => _NodeDragTrackState();
}

class _NodeDragTrackState extends State<NodeDragTrack>
    with SingleTickerProviderStateMixin {
  late DragTrackGeometry _geometry = DragTrackGeometry(widget.track);

  /// The unsnapped progress while dragging, coasting or snapping.
  double _raw = 0;

  /// The value shown while dragging, ahead of the variable catching up.
  double? _dragValue;
  double? _lastAngle;
  Offset _grab = Offset.zero;
  Size _size = Size.zero;
  Offset? _lastLocal;

  /// Where a smooth track is drawn while it moves (null: at its value).
  double? _drawProgress;

  /// Coasting speed in progress per second.
  double _velocity = 0;

  /// Progress a snap (or an animated external change) is heading for.
  double? _snapTo;

  /// Whether the motion that is ending should report [onSettled].
  bool _settleWhenDone = false;

  /// Where a value set from elsewhere is being drawn gliding to.
  double? _glideTo;

  /// Whether a pointer is dragging the control now.
  bool _pointerActive = false;
  Duration _last = Duration.zero;
  late final Ticker _ticker = createTicker(_onTick);

  late final PanGestureRecognizer _pan = PanGestureRecognizer()
    ..dragStartBehavior = DragStartBehavior.down
    ..onStart = _onStart
    ..onUpdate = _onUpdate
    ..onEnd = _onPanEnd
    ..onCancel = _onEnd;
  late final DoubleTapGestureRecognizer _doubleTap =
      DoubleTapGestureRecognizer()..onDoubleTap = _onDoubleTap;

  @override
  void initState() {
    super.initState();
    _register();
  }

  void _register() {
    final String? id = widget.nodeId;
    if (id != null) (NodeDragTrack._instances[id] ??= []).add(this);
  }

  void _unregister(String? id) {
    if (id == null) return;
    NodeDragTrack._instances[id]?.remove(this);
    if (NodeDragTrack._instances[id]?.isEmpty ?? false) {
      NodeDragTrack._instances.remove(id);
    }
  }

  @override
  void didUpdateWidget(NodeDragTrack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.track != widget.track) {
      _geometry = DragTrackGeometry(widget.track);
    }
    if (oldWidget.nodeId != widget.nodeId) {
      _unregister(oldWidget.nodeId);
      _register();
    }
    // The variable changed from elsewhere (an action reset it): a smooth
    // track glides there instead of jumping, without reporting the values
    // it passes. A change while the pointer holds it waits for the release.
    if (_track.smooth &&
        oldWidget.value != widget.value &&
        !_pointerActive &&
        widget.value != (_dragValue ?? oldWidget.value)) {
      final double from =
          _drawProgress ?? _track.progressOf(_dragValue ?? oldWidget.value);
      _velocity = 0;
      _snapTo = null;
      _settleWhenDone = false;
      _dragValue = null;
      _drawProgress = from;
      _glideTo = _track.progressOf(widget.value);
      _startTicker();
    }
  }

  @override
  void dispose() {
    _unregister(widget.nodeId);
    _ticker.dispose();
    _pan.dispose();
    _doubleTap.dispose();
    super.dispose();
  }

  DragTrackModel get _track => widget.track;
  double get _gain => widget.gain ?? _track.gain;
  double get _shownValue => _dragValue ?? widget.value;
  double get _progress => _drawProgress ?? _track.progressOf(_shownValue);
  bool get _moving => _ticker.isActive;

  /// [local] (in the node's untransformed box) relative to the rest centre.
  Offset _rel(Offset local) => local - _size.center(Offset.zero);

  /// The steps between [from] (exclusive) and [to] (inclusive), in order.
  List<double> _crossed(double from, double to) {
    final double step = _track.step;
    if (step <= 0 || from == to) return [to];
    final List<double> out = [];
    final double dir = to > from ? 1 : -1;
    double v = from;
    for (int i = 0; i < 2000; i++) {
      v = double.parse((v + dir * step).toStringAsFixed(6));
      if (dir > 0 ? v > to + 1e-9 : v < to - 1e-9) break;
      out.add(v);
    }
    if (out.isEmpty || out.last != to) out.add(to);
    return out;
  }

  void _emit(double raw) {
    _raw = _track.clampProgress(raw);
    if (_track.smooth) _drawProgress = _raw;
    final double v = _track.valueAt(_raw);
    final double from = _shownValue;
    if (v != from) {
      setState(() => _dragValue = v);
      widget.onChanged(v);
      widget.onChange?.call(
        TrackChange(value: v, from: from, crossed: _crossed(from, v)),
      );
    } else if (_track.smooth) {
      setState(() {});
    }
  }

  void _pointerDown(PointerDownEvent event, Offset local, bool onNode) {
    if (!widget.enabled) return;
    // Catch a coasting or settling control.
    if (_moving) {
      _ticker.stop();
      _velocity = 0;
      _snapTo = null;
      if (_glideTo != null) {
        _glideTo = null;
        _drawProgress = null;
      }
    }
    if (!onNode &&
        _track.jumpOnTap &&
        _track.input == DragTrackInput.follow &&
        _track.shape != DragTrackShape.arc) {
      // Tapped the track off the node: jump there, then drag from there.
      _raw = _progress;
      _emit(_geometry.nearest(_rel(local)));
    }
    _pan.addPointer(event);
    _doubleTap.addPointer(event);
  }

  void _onStart(DragStartDetails d) {
    final Offset p = _rel(d.localPosition);
    _pointerActive = true;
    if (_glideTo != null) {
      _glideTo = null;
      _drawProgress = null;
    }
    setState(() {
      _raw = _progress;
      _dragValue = _shownValue;
      if (_track.smooth) _drawProgress = _raw;
    });
    _lastAngle = _geometry.angleOf(p);
    _lastLocal = d.localPosition;
    _grab = _geometry.offsetAt(_raw) - p;
  }

  void _onUpdate(DragUpdateDetails d) {
    final Offset p = _rel(d.localPosition);
    _lastLocal = d.localPosition;
    switch (_track.input) {
      case DragTrackInput.vertical:
        _emit(_raw - d.delta.dy * _gain / _track.pixelsPerRange);
      case DragTrackInput.horizontal:
        _emit(_raw + d.delta.dx * _gain / _track.pixelsPerRange);
      case DragTrackInput.follow:
        if (_track.shape == DragTrackShape.arc) {
          final Offset fromPivot = p - Offset(_track.pivotX, _track.pivotY);
          if (fromPivot.distance < _size.shortestSide * 0.12) {
            // Too close to the pivot for a steady angle: use vertical travel.
            _emit(_raw - d.delta.dy * _gain / _track.pixelsPerRange);
            _lastAngle = _geometry.angleOf(p);
            return;
          }
          final double angle = _geometry.angleOf(p);
          double delta = angle - (_lastAngle ?? angle);
          if (delta > 180) delta -= 360;
          if (delta < -180) delta += 360;
          _lastAngle = angle;
          final double sweep = _track.endAngle - _track.startAngle;
          if (sweep != 0) _emit(_raw + delta * _gain / sweep);
        } else {
          _emit(_geometry.nearest(p + _grab));
        }
    }
  }

  /// The pointer's speed along the track at release, in progress per
  /// second.
  double _releaseSpeed(Velocity velocity) {
    final Offset v = velocity.pixelsPerSecond;
    final Offset? local = _lastLocal;
    if (local == null) return 0;
    switch (_track.input) {
      case DragTrackInput.vertical:
        return -v.dy * _gain / _track.pixelsPerRange;
      case DragTrackInput.horizontal:
        return v.dx * _gain / _track.pixelsPerRange;
      case DragTrackInput.follow:
        if (_track.shape == DragTrackShape.arc) {
          final Offset r =
              _rel(local) - Offset(_track.pivotX, _track.pivotY);
          final double r2 = r.distanceSquared;
          if (r2 < 1) return 0;
          final double degPerSec =
              (r.dx * v.dy - r.dy * v.dx) / r2 * 180 / math.pi;
          final double sweep = _track.endAngle - _track.startAngle;
          return sweep == 0 ? 0 : degPerSec * _gain / sweep;
        }
        if (_track.shape == DragTrackShape.line) {
          final Offset d =
              Offset(_track.x2 - _track.x1, _track.y2 - _track.y1);
          final double len2 = d.distanceSquared;
          return len2 == 0 ? 0 : (v.dx * d.dx + v.dy * d.dy) / len2;
        }
        return 0;
    }
  }

  /// A coast starts above this speed (in degrees per second on an arc,
  /// about 230°/s; 400 px/s along a line or drag input).
  double get _coastStart => _speedOf(_track.shape == DragTrackShape.arc ? 230 : 400);

  /// And ends below this one.
  double get _coastStop => _speedOf(_track.shape == DragTrackShape.arc ? 52 : 60);

  /// [units] (°/s on an arc, px/s otherwise) in progress per second.
  double _speedOf(double units) {
    if (_track.shape == DragTrackShape.arc &&
        _track.input == DragTrackInput.follow) {
      final double sweep = (_track.endAngle - _track.startAngle).abs();
      return sweep == 0 ? double.infinity : units / sweep;
    }
    if (_track.input != DragTrackInput.follow) {
      return units / _track.pixelsPerRange;
    }
    final double len = Offset(
      _track.x2 - _track.x1,
      _track.y2 - _track.y1,
    ).distance;
    return len == 0 ? double.infinity : units / len;
  }

  void _onPanEnd(DragEndDetails d) {
    _pointerActive = false;
    if (_track.momentum && _dragValue != null) {
      final double speed = _releaseSpeed(d.velocity);
      if (speed.abs() > _coastStart) {
        _velocity = speed.clamp(-_coastStart * 4, _coastStart * 4);
        _settleWhenDone = true;
        widget.onEnd?.call(_shownValue);
        _startTicker();
        return;
      }
    }
    _onEnd();
  }

  void _onEnd() {
    _pointerActive = false;
    final double v = _shownValue;
    widget.onEnd?.call(v);
    if (_track.smooth && _drawProgress != null) {
      _settleWhenDone = true;
      _beginSnap();
      return;
    }
    // Hold the dragged value until the variable has caught up.
    setState(() => _dragValue = null);
    widget.onSettled?.call(v);
  }

  void _beginSnap([double? toProgress]) {
    _velocity = 0;
    _snapTo = toProgress ?? _track.progressOf(_track.valueAt(_raw));
    _startTicker();
  }

  void _startTicker() {
    if (!_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  void _onTick(Duration now) {
    final double dt = _last == Duration.zero
        ? 1 / 60
        : (now - _last).inMicroseconds / 1e6;
    _last = now;
    final double? glide = _glideTo;
    if (glide != null) {
      final double at = _drawProgress ?? glide;
      final double diff = glide - at;
      if (diff.abs() < 0.0005) {
        _ticker.stop();
        setState(() {
          _glideTo = null;
          _drawProgress = null;
        });
      } else {
        setState(() => _drawProgress = at + diff * (1 - math.exp(-14 * dt)));
      }
      return;
    }
    if (_velocity != 0) {
      final double before = _raw;
      _emit(_raw + _velocity * dt);
      _velocity *= math.exp(-_track.friction * dt);
      final bool stuck = !_track.unbounded && _raw == before;
      if (_velocity.abs() < _coastStop || stuck) {
        _velocity = 0;
        if (_track.smooth) {
          _beginSnap();
        } else {
          _finish();
        }
      }
      return;
    }
    final double? to = _snapTo;
    if (to == null) {
      _finish();
      return;
    }
    final double diff = to - _raw;
    // About 1/1000 of a step, or of the whole track.
    final double done = _track.step > 0 && _track.max != _track.min
        ? (_track.step / (_track.max - _track.min)).abs() / 1000
        : 0.0005;
    if (diff.abs() <= done) {
      _emit(to);
      _finish();
      return;
    }
    _emit(_raw + diff * (1 - math.exp(-22 * dt)));
  }

  void _finish() {
    _ticker.stop();
    _snapTo = null;
    final double v = _shownValue;
    setState(() {
      _drawProgress = null;
      _dragValue = null;
    });
    if (_settleWhenDone) {
      _settleWhenDone = false;
      widget.onSettled?.call(v);
    }
    // Reset from elsewhere while it was settling: glide to the new value.
    if (_track.smooth && widget.value != v) {
      _drawProgress = _track.progressOf(v);
      _glideTo = _track.progressOf(widget.value);
      _startTicker();
    }
  }

  /// Turns the control [steps] steps (or a hundredth of the track each for
  /// a continuous one), as a drag would: crossing each step and settling.
  Future<bool> stepBy(int steps) async {
    if (!mounted || steps == 0) return mounted;
    final double unit = _track.step > 0 ? _track.step : _track.wheelStep;
    final double base = _snapTo != null
        ? _track.valueAt(_snapTo!)
        : _shownValue;
    final double target = _track.snap(base + steps * unit);
    if (_track.smooth) {
      if (!_moving) {
        _raw = _track.progressOf(_shownValue);
        _drawProgress = _raw;
        _dragValue = _shownValue;
      }
      _settleWhenDone = true;
      _beginSnap(_track.progressOf(target));
      return true;
    }
    final double from = _shownValue;
    if (target != from) {
      widget.onChanged(target);
      widget.onChange?.call(
        TrackChange(value: target, from: from, crossed: _crossed(from, target)),
      );
    }
    widget.onSettled?.call(target);
    return true;
  }

  void _onDoubleTap() {
    final double? reset = _track.defaultValue;
    if (reset == null || !widget.enabled) return;
    final double v = _track.snap(reset);
    final double from = widget.value;
    widget.onChanged(v);
    widget.onChange?.call(TrackChange(value: v, from: from, crossed: [v]));
    widget.onEnd?.call(v);
    widget.onSettled?.call(v);
  }

  void _onWheel(PointerScrollEvent event) {
    if (!_track.wheel || !widget.enabled) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (e) {
      final PointerScrollEvent s = e as PointerScrollEvent;
      final int dir = s.scrollDelta.dy < 0 ? 1 : -1;
      final int up = _track.max >= _track.min ? 1 : -1;
      if (_track.step > 0 || _track.smooth) {
        stepBy(dir * up);
        widget.onEnd?.call(_track.snap(widget.value + dir * up * _track.wheelStep));
        return;
      }
      final double v = _track.snap(widget.value + dir * up * _track.wheelStep);
      if (v != widget.value) {
        final double from = widget.value;
        widget.onChanged(v);
        widget.onChange?.call(TrackChange(value: v, from: from, crossed: [v]));
        widget.onEnd?.call(v);
        widget.onSettled?.call(v);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final double progress = _progress;
    return TrackScope(
      values: TrackValues(
        value: _shownValue,
        progress: _track.unbounded
            ? progress - progress.floorToDouble()
            : progress,
        dragging: _dragValue != null,
      ),
      child: _TrackArea(
        geometry: _geometry,
        progress: progress,
        jumpOnTap: _track.jumpOnTap,
        onSize: (size) => _size = size,
        onPointerDown: _pointerDown,
        onWheel: _onWheel,
        child: MouseRegion(
          cursor: widget.enabled
              ? (_dragValue != null
                    ? SystemMouseCursors.grabbing
                    : SystemMouseCursors.grab)
              : MouseCursor.defer,
          child: widget.child,
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

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    _hitNode = hitTestChildren(result, position: position);
    final bool onTrack =
        jumpOnTap &&
        _geometry
            .bounds(size)
            .shift(size.center(Offset.zero))
            .contains(position);
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
