// A drag track's interaction: the node is a value control (a fader cap, a
// knob, a handle on a path) that a running app lets the pointer, the wheel
// and the keys move. One render object of the
// node's chain (where the design canvas has its static pose): it reads and
// writes the track's variable, gives the nodes inside it `${track.*}`,
// and fires the node's `changed`, `dragEnd` and `changeEnd` reactions.
//
// The physics are coast, glide and snap loops with fixed thresholds; a settle spring is Flutter's SpringSimulation.
import 'dart:async';
import 'dart:math' as math;

import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/physics.dart';

import 'physics.dart' show describeSpring;
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show BuildContext, FocusAttachment, FocusNode, KeyEventResult;

import 'behavior_values.dart';
import 'behaviors.dart';
import 'contracts.dart';
import 'islands.dart';
import 'node_tree.dart';

/// One change of a track's value, as `changed` reactions read it in
/// `${result}`: the new [value], the value it moved [from], its
/// direction (1 toward `max`, -1 toward `min`) and every step it
/// [crossed] on the way, in order, ending with [value].
@immutable
class TrackChange {
  const TrackChange({required this.value, required this.from, required this.crossed});

  final double value, from;
  final List<double> crossed;

  int get direction => value > from ? 1 : (value < from ? -1 : 0);

  Map<String, Object?> toMap() => {'value': value, 'from': from, 'direction': direction, 'crossed': crossed};
}

/// The steps of [step] between [from] (exclusive) and [to] (inclusive), in
/// order; just [to] for a continuous track.
List<double> crossedSteps(double step, double from, double to) {
  if (step <= 0 || from == to) return [to];
  final out = <double>[];
  final dir = to > from ? 1 : -1;
  var v = from;
  for (var i = 0; i < 2000; i++) {
    v = double.parse((v + dir * step).toStringAsFixed(6));
    if (dir > 0 ? v > to + 1e-9 : v < to - 1e-9) break;
    out.add(v);
  }
  if (out.isEmpty || out.last != to) out.add(to);
  return out;
}

/// The pan a track turns its value with. It claims the pointer after half
/// the movement any drag or scroll needs, so a control wins over what
/// holds it (a knob on a draggable pedal, a fader in a scrolling page).
/// Holding still is not claiming, so a double tap still resets the value.
class TrackPanGestureRecognizer extends PanGestureRecognizer {
  TrackPanGestureRecognizer({super.debugOwner});

  @override
  bool hasSufficientGlobalDistanceToAccept(PointerDeviceKind pointerDeviceKind, double? deviceTouchSlop) =>
      globalDistanceMoved.abs() > computeHitSlop(pointerDeviceKind, gestureSettings) / 2;
}

/// What a track's geometry gives besides the pose: the nearest point to the
/// pointer, angles about an arc's pivot, the area it can be found in.
extension TrackGeometryHits on TrackGeometry {
  /// An arc's pivot, in pixels from the rest center.
  Offset get pivot => track.units == api.TrackUnits.parent && parent != null
      ? Offset(track.pivotX * parent!.width, track.pivotY * parent!.height)
      : Offset(track.pivotX, track.pivotY);

  /// The pointer's angle around the arc's pivot, degrees clockwise from up.
  double angleOf(Offset p) {
    final v = p - pivot;
    return math.atan2(v.dx, -v.dy) * 180 / math.pi;
  }

  /// The progress along an arc whose angle is nearest [angle]: inside the
  /// sweep where it is, in the gap the nearer end. Null for a track that
  /// isn't an arc or has no sweep.
  double? progressAtAngle(double angle) {
    if (track.shape != api.TrackShape.arc) return null;
    final start = track.startAngle, end = track.endAngle;
    final sweep = end - start;
    if (sweep == 0) return null;
    var from = (angle - start) * sweep.sign % 360;
    if (from < 0) from += 360;
    final span = sweep.abs();
    if (from <= span) return from / span;
    return (from - span) < (360 - from) ? 1 : 0;
  }

  /// The circle an arc's node sweeps round its pivot (center, radius), for
  /// a node of [size].
  (Offset, double) sweptCircle(Size size) => (pivot, pivot.distance + size.longestSide / 2);

  /// Where the node can be found anywhere along the track, inflated by its
  /// own box.
  Rect bounds(Size size) {
    var r = Rect.zero;
    for (var i = 0; i <= 24; i++) {
      final dot = Rect.fromCircle(center: offsetAt(i / 24), radius: 0);
      r = i == 0 ? dot : r.expandToInclude(dot);
    }
    return r.inflate(size.longestSide / 2);
  }

  /// The progress of the point on a line or path nearest [p] (from rest),
  /// or of the angle [p] makes round an arc's pivot. A line's may lie past
  /// its ends ([unclamped]). A path's [samples] are its points at even
  /// progress (see [pathSamples]).
  double nearest(Offset p, {bool unclamped = false, List<Offset> samples = const []}) {
    switch (track.shape) {
      case api.TrackShape.line:
        final a = offsetAt(0), d = offsetAt(1) - a;
        final len2 = d.distanceSquared;
        if (len2 == 0) return 0;
        final ap = p - a;
        final t = (ap.dx * d.dx + ap.dy * d.dy) / len2;
        return unclamped ? t : t.clamp(0.0, 1.0);
      case api.TrackShape.path:
        if (samples.length < 2) return 0;
        // By length along the placed path: the samples are even in it.
        var best = double.infinity, at = 0.0;
        final n = samples.length - 1;
        for (var i = 1; i <= n; i++) {
          final a = samples[i - 1], d = samples[i] - a;
          final len2 = d.distanceSquared;
          final t = len2 == 0 ? 0.0 : (((p - a).dx * d.dx + (p - a).dy * d.dy) / len2).clamp(0.0, 1.0);
          final dist = (a + d * t - p).distanceSquared;
          if (dist < best) {
            best = dist;
            at = (i - 1 + t) / n;
          }
        }
        return at;
      case api.TrackShape.arc:
        // The pointer's angle round the pivot, from where the node rests,
        // in whichever turn lands inside the sweep (or nearest an end).
        final sweep = track.endAngle - track.startAngle;
        if (sweep == 0) return 0;
        final raw = angleOf(p) - angleOf(Offset.zero);
        final lo = math.min(track.startAngle, track.endAngle), hi = math.max(track.startAngle, track.endAngle);
        var a = raw, best = double.infinity;
        for (var turn = -2; turn <= 2; turn++) {
          final c = raw + turn * 360;
          final off = c < lo ? lo - c : (c > hi ? c - hi : 0.0);
          if (off < best) {
            best = off;
            a = c;
          }
        }
        return ((a - track.startAngle) / sweep).clamp(0.0, 1.0);
    }
  }

  /// A path's points at progress 0, 1/240... 1.
  List<Offset> pathSamples() => [for (var i = 0; i <= 240; i++) offsetAt(i / 240)];
}

/// The tracks of a tree's nodes on screen, by node id: what a control
/// drag action steps.
abstract final class DragTracks {
  static final Expando<Map<String, Set<RenderDragTrack>>> _byTree = Expando('dragTracks');

  static void _add(RenderTree tree, String id, RenderDragTrack t) => ((_byTree[tree] ??= {})[id] ??= {}).add(t);

  static void _remove(RenderTree tree, String id, RenderDragTrack t) {
    final m = _byTree[tree];
    m?[id]?.remove(t);
    if (m?[id]?.isEmpty ?? false) m!.remove(id);
  }

  /// Turns the track of node [nodeId] of [tree] by [steps] steps, as if
  /// dragged there; false when no such
  /// track is on screen. [nodeId] may list several ids separated by commas
  /// (the copies of one control in a screen's layouts).
  static Future<bool> step(RenderTree tree, String nodeId, int steps) async {
    final all = [
      for (final id in nodeId.split(','))
        for (final t in _byTree[tree]?[id.trim()] ?? const <RenderDragTrack>{})
          if (t.attached) t,
    ];
    if (all.isEmpty) return false;
    final target = all.firstWhere((t) => t._enabled, orElse: () => all.first);
    return target.stepBy(steps);
  }
}

/// A node moved along its [api.Track] and, in a running app, dragged
/// along it ([configure]'s `interactive`); on the design canvas it's the
/// static pose at its variable's value, taking no input and never ticking.
class RenderDragTrack extends RenderTrackPose implements MouseTrackerAnnotation {
  NodeBox? _box;
  bool _interactive = false;
  bool _enabled = true;
  bool _configured = false;

  /// The variable's value (or the bound one); NaN while empty.
  double _value = 0;

  /// The scope the track reads in (its own node scope, over the variables).
  BoundValues? _scope;
  Listenable? _watched;

  api.Track get _track => track;

  /// Sets the track up from its node, as shown: [box] is the node's box
  /// (null outside a tree), [enabled] its `track.enabled`, [interactive]
  /// whether the tree runs (an app) or rests (a design canvas).
  void configure(NodeBox? box, api.Track track, {bool enabled = true, required bool interactive}) {
    final oldTrack = _track;
    final oldValue = _value;
    final oldInput = oldTrack.input;
    if (!identical(box, _box)) {
      if (_registered) _unregister();
      _box = box;
    }
    this.track = track;
    _stepValue = null;
    _enabled = enabled;
    if (interactive != _interactive) {
      _interactive = interactive;
      if (!interactive) _stopAll();
    }
    if (oldInput != track.input) {
      _drag?.dispose();
      _drag = null;
    }
    _scope = box?.tree.bindings?.valuesFor(box.tree.source, box.id, box.instance);
    _watch();
    final value = trackValueFrom(track, _scope?.read);
    if (!_configured) {
      _configured = true;
      _value = value;
      _from = _to = _progress;
      _snapT = 1;
    } else if (!_same(value, oldValue)) {
      _valueChanged(oldTrack, oldValue, value);
    }
    _animateTo(_progress);
    if (_interactive && (track.jumpOnTap || track.hitArea == api.TrackHitArea.parent)) _box?.outsideHitTest = _hitOutside;
    if (attached) _syncRegistration();
    _refresh(later: true);
  }

  // --- reading and writing the value ------------------------------------------------

  void _watch() {
    final name = _track.variable.trim();
    final w = _track.value == null && name.isNotEmpty ? _scope?.watch(name) : null;
    if (identical(w, _watched)) return;
    _watched?.removeListener(_onVariable);
    _watched = w;
    if (attached) _watched?.addListener(_onVariable);
  }

  /// The variable changed (from the drag, an action, a key...).
  void _onVariable() {
    final v = trackValueFrom(_track, _scope?.read);
    _stepValue = null;
    if (_same(v, _value)) return;
    _valueChanged(_track, _value, v);
    _animateTo(_progress);
    _refresh();
  }

  /// Moves to a new value [next] (was [old] on
  /// [oldTrack]): a smooth track glides there without reporting the values
  /// it passes; any other glides from where it's drawn now (a spring at the
  /// speed it moves). A change while the pointer holds it waits.
  void _valueChanged(api.Track oldTrack, double old, double next) {
    _value = next;
    if (!_interactive) return;
    if (_track.smooth && !_pointerActive && !_same(next, _dragValue ?? old)) {
      final from = _drawProgress ?? _track.progressOf(_dragValue ?? old);
      _velocity = 0;
      _snapTo = null;
      _settleWhenDone = false;
      _dragValue = null;
      _drawProgress = from;
      _glideTo = _track.progressOf(next);
      _startLoop();
    } else if (!_track.smooth && _dragValue == null) {
      final from = _settling ? _lerpSettle : oldTrack.restProgressOf(old);
      _glide(from, _track.restProgressOf(next), velocity: _settleVelocity);
    }
  }

  /// Writes [v] to the variable (unless [api.Track.write] is off, or
  /// it's computed): whole for an integer one. Scrubbing a variable an
  /// animation plays pauses it.
  void _onChanged(double v) {
    final name = _track.variable.trim();
    final scope = _scope;
    if (!_track.write || name.isEmpty || scope == null) return;
    final found = scope.variable(name);
    if (found == null || found.isComputed) return;
    found.pauseAnimation();
    scope.write(name, found.isInteger ? v.round() : v);
  }

  void _fire(String trigger, Map<String, Object?> result, {Object? value}) {
    final box = _box;
    if (box == null || !_interactive) return;
    fireTrigger(box, trigger, event: {'result': result, 'value': ?value});
  }

  /// `changed` reads the new value, the one before, the direction and
  /// every step crossed.
  void _onChange(TrackChange change) => _fire('changed', change.toMap(), value: change.value);

  /// `dragEnd`: the value let go at, the one the drag started at and the
  /// speed it was let go with (units per second along the track).
  void _onRelease(double v, double start, double velocity) =>
      _fire('dragEnd', {'value': v, 'startValue': start.isNaN ? null : start, 'velocity': velocity});

  /// `changeEnd` once it has come to rest.
  void _onSettled(double v) => _fire('changeEnd', {'value': v});

  void _onFine(bool fine) {
    final name = _track.fineVariable.trim();
    final scope = _scope;
    if (name.isNotEmpty && scope != null) scope.write(name, fine);
  }

  // --- what's shown --------------------------------------------------------------------

  /// Fine mode: from Shift or a press held still.
  bool _fine = false, _heldFine = false;
  Timer? _hold;
  bool _focused = false;
  double? _stepValue;
  double _startValue = 0;

  /// The pointer's progress while dragging, coasting or snapping, unsnapped
  /// (and past the ends with overscroll).
  double _raw = 0;

  /// The value shown while dragging, ahead of the variable catching up.
  double? _dragValue;
  double? _lastAngle;
  Offset _grab = Offset.zero;
  Offset? _lastLocal;

  /// Where a smooth track is drawn while it moves (null: at its value).
  double? _drawProgress;

  /// Coasting speed in progress per second.
  double _velocity = 0;

  /// Progress a snap is heading for.
  double? _snapTo;
  bool _settleWhenDone = false;

  /// Where a value set from elsewhere is drawn gliding to (smooth).
  double? _glideTo;
  bool _pointerActive = false;

  double get _gain => _track.gain;
  double get _shownValue => _dragValue ?? _value;

  static bool _same(double a, double b) => a == b || (a.isNaN && b.isNaN);

  /// Whether the keys move the track (and it takes focus).
  bool get _keys => _track.effectiveKeyStep != null && _enabled;

  bool get _glides => _track.settle > 0 || _track.settleCurve == api.AnimationCurve.spring;

  /// Where the node is along the track: where a smooth track draws it,
  /// following the pointer, gliding to its value, or at its value (parked).
  double get _progress {
    if (_drawProgress case final double drawn) return drawn;
    if (_dragValue != null) return _dragProgress;
    if (_settling) return _lerpSettle;
    return _track.restProgressOf(_value);
  }

  double get _dragProgress {
    // An endless arc is drawn at its value, in whichever turn it is.
    if (_track.unbounded) return _track.progressOf(_shownValue);
    final clamped = _raw.clamp(0.0, 1.0);
    var p = clamped;
    if (_track.step > 0 && !_shownValue.isNaN) {
      final snapped = _track.progressOf(_shownValue);
      p = snapped + (clamped - snapped) * _track.detent.clamp(0.0, 1.0);
    }
    return p + (_raw - clamped) * _track.overscroll.clamp(0.0, 1.0);
  }

  /// The progress drawn: animating towards [_to] with a snap, else
  /// [_progress].
  double get _drawn {
    if (_track.snap <= 0) return _progress;
    if (!_snapActive) return _to;
    return _from + (_to - _from) * _track.snapCurve.transform(_snapT);
  }

  Map<String, Object?>? _published;
  bool _publishScheduled = false;
  bool _draggedState = false;

  /// Shows the state: the pose, the slider's semantics and, now or after
  /// the current work ([later]: while a node applies), `${track}`.
  void _refresh({bool later = false}) {
    progress = _drawn;
    if (_interactive) markNeedsSemanticsUpdate();
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
    final dragging = _dragValue != null;
    final values = trackValues(_track, _shownValue,
        progress: _progress, dragging: dragging, fine: _fine, focused: _focused);
    if (!mapEquals(values, _published)) {
      _published = values;
      box.tree.bindings?.publish(box.tree.source, box.id, box.instance, 'track', values);
    }
    if (dragging != _draggedState) {
      _draggedState = dragging;
      _setDragged(box, dragging);
    }
  }

  /// The node and the nodes inside it are `dragged` while it's dragged
  /// (their `states.dragged` styles apply).
  static void _setDragged(NodeBox box, bool on) {
    final source = box.tree.source;
    void visit(String id) {
      final n = source.node(id);
      if (n == null) return;
      if (n.behaviors.states.patches.containsKey(api.WidgetState.dragged)) {
        box.tree.setState(id, api.WidgetState.dragged, on, instance: box.instance);
      }
      n.childIds.forEach(visit);
    }

    visit(box.id);
  }

  // --- animations ----------------------------------------------------------------------

  Ticker? _ticker;

  /// The settle glide: its value (a progress between [_settleFrom] and
  /// [_settleTo], overshooting for springy curves; a spring runs in
  /// progress itself, from 0 to 1, so it carries the speed it starts with).
  bool _settleActive = false;
  double _settleT = 1, _settleV = 0, _settleFrom = 0, _settleTo = 0;
  Simulation? _settleSim;
  Duration? _settleStart;

  bool get _settling => _settleActive;
  double get _lerpSettle => _settleFrom + (_settleTo - _settleFrom) * _settleT;
  double get _settleVelocity => _settling ? _settleV * (_settleTo - _settleFrom) : 0;

  /// The snap to a new value ([api.Track.snap] ms).
  bool _snapActive = false;
  double _snapT = 1, _from = 0, _to = 0;
  int _snapMs = 0;
  Duration? _snapStart;

  /// The coast, snap and glide loop.
  bool _loopActive = false;
  Duration? _last;

  bool get _ticking => _settleActive || _snapActive || _loopActive;

  void _syncTicker() {
    if (attached && _interactive && _ticking) {
      _ticker ??= Ticker(_tick, debugLabel: 'drag track');
      if (!_ticker!.isActive) _ticker!.start();
    } else if (_ticker?.isActive ?? false) {
      _ticker!.stop();
    }
  }

  void _tick(Duration elapsed) {
    if (_settleActive) _stepSettle(elapsed);
    if (_snapActive) _stepSnap(elapsed);
    if (_loopActive) _stepLoop(elapsed);
    _refresh();
    if (!_ticking) _ticker?.stop();
  }

  void _stopAll() {
    _settleActive = _snapActive = _loopActive = false;
    _settleT = _snapT = 1;
    _dragValue = _drawProgress = _glideTo = _snapTo = null;
    _velocity = 0;
    _pointerActive = false;
    _hold?.cancel();
    _ticker?.stop();
  }

  /// Glides the drawn progress from [from] to [to]; a spring starts at
  /// [velocity] (progress per second), eased curves from rest.
  void _glide(double from, double to, {double velocity = 0}) {
    final spring = _track.settleCurve == api.AnimationCurve.spring;
    if (!_glides ||
        !_interactive ||
        (from == to && (!spring || velocity == 0)) ||
        !velocity.isFinite ||
        !from.isFinite ||
        !to.isFinite) {
      _settleActive = false;
      _settleT = 1;
      _settleFrom = _settleTo = to;
      return;
    }
    _settleStart = null;
    _settleActive = true;
    if (spring) {
      _settleFrom = 0;
      _settleTo = 1;
      _settleSim = SpringSimulation(
        describeSpring(_track.settleSpring, dampingIfNegative: 20),
        from,
        to,
        velocity,
      );
      _settleT = from;
      _settleV = velocity;
    } else {
      _settleFrom = from;
      _settleTo = to;
      _settleSim = null;
      _settleT = 0;
      _settleV = 0;
    }
    _syncTicker();
  }

  void _stepSettle(Duration elapsed) {
    final start = _settleStart ??= elapsed;
    final t = (elapsed - start).inMicroseconds / 1e6;
    final sim = _settleSim;
    if (sim != null) {
      _settleT = sim.x(t);
      _settleV = sim.dx(t);
      if (sim.isDone(t)) _settleActive = false;
      return;
    }
    final ms = math.max(1, _track.settle);
    final f = (t * 1000 / ms).clamp(0.0, 1.0);
    final before = _settleT;
    _settleT = _track.settleCurve.transform(f);
    _settleV = t > 0 ? (_settleT - before) * 60 : 0;
    if (f >= 1) {
      _settleActive = false;
      _settleT = 1;
    }
  }

  void _animateTo(double target) {
    if (_track.snap <= 0 || target == _to || !_interactive) {
      _to = target;
      return;
    }
    _from = _drawn;
    _to = target;
    _snapMs = _fine ? (_track.snap / 2).round() : _track.snap;
    _snapT = 0;
    _snapStart = null;
    _snapActive = true;
    _syncTicker();
  }

  void _stepSnap(Duration elapsed) {
    final start = _snapStart ??= elapsed;
    _snapT = ((elapsed - start).inMicroseconds / 1000 / math.max(1, _snapMs)).clamp(0.0, 1.0);
    if (_snapT >= 1) _snapActive = false;
  }

  void _startLoop() {
    if (_loopActive) return;
    _loopActive = true;
    _last = null;
    _syncTicker();
  }

  void _stepLoop(Duration now) {
    final last = _last;
    final dt = last == null ? 1 / 60 : (now - last).inMicroseconds / 1e6;
    _last = now;
    final glide = _glideTo;
    if (glide != null) {
      final at = _drawProgress ?? glide;
      final diff = glide - at;
      if (diff.abs() < 0.0005) {
        _loopActive = false;
        _glideTo = null;
        _drawProgress = null;
      } else {
        _drawProgress = at + diff * (1 - math.exp(-14 * dt));
      }
      return;
    }
    if (_velocity != 0) {
      final before = _raw;
      _emit(_raw + _velocity * dt);
      _velocity *= math.exp(-_track.friction * dt);
      final stuck = !_track.unbounded && _raw == before;
      if (_velocity.abs() < _coastStop || stuck) {
        _velocity = 0;
        _track.smooth ? _beginSnap() : _finish();
      }
      return;
    }
    final to = _snapTo;
    if (to == null) return _finish();
    final diff = to - _raw;
    // About 1/1000 of a step, or of the whole track.
    final done = _track.step > 0 && _track.max != _track.min ? (_track.step / (_track.max - _track.min)).abs() / 1000 : 0.0005;
    if (diff.abs() <= done) {
      _emit(to);
      return _finish();
    }
    _emit(_raw + diff * (1 - math.exp(-22 * dt)));
  }

  void _beginSnap([double? toProgress]) {
    _velocity = 0;
    _snapTo = toProgress ?? _track.progressOf(_track.valueAt(_raw));
    _startLoop();
  }

  void _finish() {
    _loopActive = false;
    _snapTo = null;
    final v = _shownValue;
    _drawProgress = null;
    _dragValue = null;
    if (_settleWhenDone) {
      _settleWhenDone = false;
      _onSettled(v);
    }
    // Reset from elsewhere while it was settling: glide to the new value.
    if (_track.smooth && !_same(_value, v)) {
      _drawProgress = _track.progressOf(v);
      _glideTo = _track.progressOf(_value);
      _startLoop();
    }
  }

  // --- the pointer ---------------------------------------------------------------------

  DragGestureRecognizer? _drag;
  DoubleTapGestureRecognizer? _doubleTap;

  DragGestureRecognizer _makeDrag() {
    final DragGestureRecognizer r = switch (_track.input) {
      api.TrackInput.vertical => VerticalDragGestureRecognizer(debugOwner: this),
      api.TrackInput.horizontal => HorizontalDragGestureRecognizer(debugOwner: this),
      api.TrackInput.follow || api.TrackInput.both => TrackPanGestureRecognizer(debugOwner: this),
    };
    return r
      ..dragStartBehavior = DragStartBehavior.down
      ..onDown = _onDown
      ..onStart = _onStart
      ..onUpdate = _onUpdate
      ..onEnd = _onPanEnd
      ..onCancel = _onEnd;
  }

  /// [local] (in the node's untransformed box) relative to the rest center.
  Offset _rel(Offset local) => local - size.center(Offset.zero);

  TrackGeometry get _geometry => pose();

  List<Offset>? _samples;
  Object? _samplesKey;

  List<Offset> _pathSamples(TrackGeometry g) {
    if (_track.shape != api.TrackShape.path) return const [];
    final key = (g.track, g.size, g.parent, g.rest);
    if (key != _samplesKey) {
      _samplesKey = key;
      _samples = g.pathSamples();
    }
    return _samples!;
  }

  double _nearest(Offset p, {bool unclamped = false}) {
    final g = _geometry;
    return g.nearest(p, unclamped: unclamped, samples: _pathSamples(g));
  }

  void _emit(double raw) {
    _raw = _track.overscroll > 0 && !_track.unbounded ? raw : _track.clampProgress(raw);
    if (_track.smooth) _drawProgress = _raw;
    final at = _track.clampProgress(_raw);
    final v = _fine ? _track.snapTo(_track.min + (_track.max - _track.min) * at, _track.fineStep) : _track.valueAt(at);
    final from = _shownValue;
    if (v != from) {
      _dragValue = v;
      _animateTo(_track.progressOf(v));
      _onChanged(v);
      _onChange(TrackChange(value: v, from: from, crossed: from.isNaN ? [v] : crossedSteps(_track.step, from, v)));
    }
    _refresh();
  }

  bool _nearPivot(Offset p) => (p - _geometry.pivot).distance < size.shortestSide * 0.12;

  void _pointerDown(PointerDownEvent event, Offset local, bool onNode) {
    if (!_enabled) return;
    if (_keys) _focus?.requestFocus();
    _startValue = _value;
    // Catch a coasting or settling control.
    if (_loopActive) {
      _loopActive = false;
      _velocity = 0;
      _snapTo = null;
      if (_glideTo != null) {
        _glideTo = null;
        _drawProgress = null;
      }
    }
    if (_track.jumpOnTap && _track.input == api.TrackInput.follow) {
      if (_track.shape == api.TrackShape.arc) {
        // A dial turns to the angle tapped, then drags from there. Too near
        // the pivot there is no steady angle.
        final p = _rel(local);
        final g = _geometry;
        final jump = _nearPivot(p) ? null : g.progressAtAngle(g.angleOf(p));
        if (jump != null) {
          _settleActive = false;
          _raw = _progress;
          _emit(jump);
        }
      } else if (!onNode || (_track.relative && _track.shape == api.TrackShape.line)) {
        // Tapped the track off the node (or a relative scrub area): jump
        // there, then drag from there.
        _settleActive = false;
        _raw = _progress;
        _emit(_nearest(_rel(local)));
      }
    }
    (_drag ??= _makeDrag()).addPointer(event);
    if (_track.doubleTapValues.isNotEmpty || _track.defaultValue != null) {
      (_doubleTap ??= DoubleTapGestureRecognizer(debugOwner: this)..onDoubleTap = _onDoubleTap).addPointer(event);
    }
  }

  void _onDown(DragDownDetails d) {
    _hold?.cancel();
    if (!_track.hasFine || _track.fineHold <= 0) return;
    // Pressed and held still: fine mode for the drag that follows.
    _hold = Timer(Duration(milliseconds: _track.fineHold), () {
      if (!attached) return;
      _heldFine = true;
      _setFine(true);
      _refresh();
    });
  }

  void _setFine(bool fine) {
    if (fine == _fine) return;
    _fine = fine;
    _onFine(fine);
  }

  bool get _wantFine => _track.hasFine && (_heldFine || HardwareKeyboard.instance.isShiftPressed);

  void _onStart(DragStartDetails d) {
    _hold?.cancel();
    final p = _rel(d.localPosition);
    _pointerActive = true;
    if (_glideTo != null) {
      _glideTo = null;
      _drawProgress = null;
    }
    // Caught mid-glide, the drag goes on from where the node is drawn; a
    // parked node from the nearest end; after a tap jump from there.
    final jumped = _dragValue != null;
    final from = _track.clampProgress(_progress);
    _settleActive = false;
    if (!jumped) {
      _raw = from;
      _dragValue = _shownValue;
    }
    if (_track.smooth) _drawProgress = _raw;
    _setFine(_wantFine);
    final g = _geometry;
    _lastAngle = g.angleOf(p);
    _lastLocal = d.localPosition;
    _grab = g.offsetAt(_raw) - p;
    _refresh();
  }

  void _onUpdate(DragUpdateDetails d) {
    final fine = _wantFine;
    if (fine != _fine) {
      // Switching mode mid-drag: carry on from where the node is.
      _raw = _progress;
      _setFine(fine);
    }
    final p = _rel(d.localPosition);
    _lastLocal = d.localPosition;
    final ppr = _fine ? _track.effectiveFinePixelsPerRange : _track.pixelsPerRange;
    switch (_track.input) {
      case api.TrackInput.vertical:
        _emit(_raw - d.delta.dy * _gain / ppr);
      case api.TrackInput.horizontal:
        _emit(_raw + d.delta.dx * _gain / ppr);
      case api.TrackInput.both:
        _emit(_raw + (d.delta.dx - d.delta.dy) * _gain / ppr);
      case api.TrackInput.follow:
        if (_track.shape == api.TrackShape.arc) {
          final g = _geometry;
          if ((p - g.pivot).distance < size.shortestSide * 0.12) {
            // Too close to the pivot for a steady angle: vertical travel.
            _emit(_raw - d.delta.dy * _gain / ppr);
            _lastAngle = g.angleOf(p);
            return;
          }
          final angle = g.angleOf(p);
          var delta = angle - (_lastAngle ?? angle);
          if (delta > 180) delta -= 360;
          if (delta < -180) delta += 360;
          _lastAngle = angle;
          final sweep = _track.endAngle - _track.startAngle;
          if (sweep != 0) _emit(_raw + delta * _gain / sweep);
        } else {
          _emit(_nearest(p + _grab, unclamped: _track.overscroll > 0));
        }
    }
  }

  /// The pointer's speed along the track at release, progress per second.
  double _releaseSpeed(Velocity velocity) {
    final v = velocity.pixelsPerSecond;
    final local = _lastLocal;
    if (local == null) return 0;
    switch (_track.input) {
      case api.TrackInput.vertical:
        return -v.dy * _gain / _track.pixelsPerRange;
      case api.TrackInput.horizontal:
        return v.dx * _gain / _track.pixelsPerRange;
      case api.TrackInput.both:
        return (v.dx - v.dy) * _gain / _track.pixelsPerRange;
      case api.TrackInput.follow:
        final g = _geometry;
        if (_track.shape == api.TrackShape.arc) {
          final r = _rel(local) - g.pivot;
          final r2 = r.distanceSquared;
          if (r2 < 1) return 0;
          final degPerSec = (r.dx * v.dy - r.dy * v.dx) / r2 * 180 / math.pi;
          final sweep = _track.endAngle - _track.startAngle;
          return sweep == 0 ? 0 : degPerSec * _gain / sweep;
        }
        // Along a line or path: the velocity's share of the track's
        // direction where the node is.
        final p = _raw.clamp(0.0, 1.0);
        final a = (p - 0.01).clamp(0.0, 1.0), b = (p + 0.01).clamp(0.0, 1.0);
        if (a == b) return 0;
        final t = (g.offsetAt(b) - g.offsetAt(a)) / (b - a);
        final t2 = t.distanceSquared;
        return t2 == 0 ? 0 : (v.dx * t.dx + v.dy * t.dy) / t2;
    }
  }

  /// A coast starts above this speed (about 230°/s on an arc; 400 px/s
  /// along a line or drag input), and ends below the next.
  double get _coastStart => _speedOf(_track.shape == api.TrackShape.arc ? 230 : 400);
  double get _coastStop => _speedOf(_track.shape == api.TrackShape.arc ? 52 : 60);

  /// [units] (°/s on an arc, px/s otherwise) in progress per second.
  double _speedOf(double units) {
    if (_track.shape == api.TrackShape.arc && _track.input == api.TrackInput.follow) {
      final sweep = (_track.endAngle - _track.startAngle).abs();
      return sweep == 0 ? double.infinity : units / sweep;
    }
    if (_track.input != api.TrackInput.follow) return units / _track.pixelsPerRange;
    final g = _geometry;
    final len = (g.offsetAt(1) - g.offsetAt(0)).distance;
    return len == 0 ? double.infinity : units / len;
  }

  void _ended(double v, {double? start, double velocity = 0}) => _onRelease(v, start ?? _startValue, velocity);

  void _onPanEnd(DragEndDetails d) {
    _pointerActive = false;
    final speed = _dragValue == null ? 0.0 : _releaseSpeed(d.velocity);
    if (_track.momentum && _dragValue != null && !_fine && speed.abs() > _coastStart) {
      _hold?.cancel();
      _heldFine = false;
      _setFine(false);
      _velocity = speed.clamp(-_coastStart * 4, _coastStart * 4);
      _settleWhenDone = true;
      _ended(_shownValue, velocity: speed * (_track.max - _track.min));
      _startLoop();
      _refresh();
      return;
    }
    _onEnd(speed.isFinite ? speed : 0);
  }

  /// The pointer lifted (or the drag was canceled) at [speed] along the
  /// track (progress per second).
  void _onEnd([double speed = 0]) {
    _pointerActive = false;
    _hold?.cancel();
    _heldFine = false;
    _setFine(false);
    if (_dragValue == null) return _refresh();
    final v = _shownValue;
    final velocity = speed * (_track.max - _track.min);
    if (_track.smooth && _drawProgress != null) {
      _ended(v, velocity: velocity);
      _settleWhenDone = true;
      _beginSnap();
      return _refresh();
    }
    final drawn = _dragProgress;
    // A spring settle starts at the release speed, so a fling carries on.
    _dragValue = null;
    _glide(drawn, _track.progressOf(v), velocity: speed);
    _ended(v, velocity: velocity);
    _onSettled(v);
    _refresh();
  }

  /// Turns the control [steps] steps (of [by], else the track's step, or a
  /// wheel step for a continuous one), as a drag would: crossing each step
  /// and settling.
  Future<bool> stepBy(int steps, {double? by}) async {
    if (!attached || steps == 0) return attached;
    // Gliding to a value set from elsewhere: finish there, then step on.
    if (_glideTo != null) {
      _raw = _track.progressOf(_value);
      _drawProgress = _raw;
      _glideTo = null;
      _dragValue = _value;
    }
    final unit = by ?? (_track.step > 0 ? _track.step : _track.effectiveWheelStep);
    final base = _snapTo != null ? _track.valueAt(_snapTo!) : _shownValue;
    final target = _track.snapValue(base + steps * unit);
    if (_track.smooth) {
      if (!_loopActive) {
        _raw = _track.progressOf(_shownValue);
        _drawProgress = _raw;
        _dragValue = _shownValue;
      }
      _settleWhenDone = true;
      _beginSnap(_track.progressOf(target));
      _refresh();
      return true;
    }
    final from = _shownValue;
    if (target != from) {
      _onChanged(target);
      _onChange(TrackChange(value: target, from: from, crossed: crossedSteps(_track.step, from, target)));
    }
    _onSettled(target);
    _refresh();
    return true;
  }

  void _onDoubleTap() {
    if (!_enabled) return;
    final v = _track.doubleTapTarget(_value);
    if (v != null) _set(v, always: true);
  }

  /// Reports [v] as a whole change (a wheel notch, a key, a double tap);
  /// nothing when it's the value already, unless [always].
  void _set(double v, {bool always = false}) {
    final from = _stepValue ?? _value;
    if (_same(v, from) && !always) return;
    _onChanged(v);
    _stepValue = v;
    _onChange(TrackChange(value: v, from: from, crossed: from.isNaN ? [v] : crossedSteps(_track.step, from, v)));
    _ended(v, start: from);
    _onSettled(v);
    _refresh();
  }

  bool _inRange(double v) {
    if (v.isNaN) return false;
    if (_track.unbounded) return true;
    final lo = math.min(_track.min, _track.max), hi = math.max(_track.min, _track.max);
    return v >= lo && v <= hi;
  }

  /// The value [steps] steps of [by] toward max; from an empty or
  /// out-of-range value any step lands on the nearest end.
  double _stepped(double by, int steps) {
    final v = _stepValue ?? _value;
    if (!_inRange(v)) return _track.valueAt(_track.restProgressOf(v) <= 0.5 ? 0 : 1);
    final up = _track.max >= _track.min ? 1 : -1;
    return _track.snapValue(v + steps * up * by);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final step = _track.effectiveKeyStep;
    if (step == null || !_enabled || _dragValue != null) return KeyEventResult.ignored;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final v = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowUp || LogicalKeyboardKey.arrowRight => _stepped(step, 1),
      LogicalKeyboardKey.arrowDown || LogicalKeyboardKey.arrowLeft => _stepped(step, -1),
      LogicalKeyboardKey.pageUp => _stepped(step, 10),
      LogicalKeyboardKey.pageDown => _stepped(step, -10),
      LogicalKeyboardKey.home => _track.snapValue(_track.min),
      LogicalKeyboardKey.end => _track.snapValue(_track.max),
      _ => null,
    };
    if (v == null) return KeyEventResult.ignored;
    _set(v);
    return KeyEventResult.handled;
  }

  void _onWheel(PointerScrollEvent event) {
    if (!_track.wheel || !_enabled) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (e) {
      final s = e as PointerScrollEvent;
      if (s.scrollDelta.dy == 0 || !attached) return;
      final dir = s.scrollDelta.dy < 0 ? 1 : -1;
      final up = _track.max >= _track.min ? 1 : -1;
      final fine = _track.hasFine && HardwareKeyboard.instance.isShiftPressed;
      // A stepped or smooth track turns one step, as a drag would; a set
      // wheelStep is the notch's size.
      if (!fine && (_track.step > 0 || _track.smooth) && _inRange(_value)) {
        final from = _value;
        stepBy(dir * up, by: _track.wheelStep);
        _ended(_track.snapValue(from + dir * up * _track.effectiveWheelStep), start: from);
        return;
      }
      final by = fine ? _track.fineStep : _track.effectiveWheelStep;
      final from = _stepValue ?? _value;
      final v = !_inRange(from)
          ? _stepped(by, dir)
          : fine
          ? _track.snapTo(from + dir * up * by, _track.fineStep)
          : _track.snapValue(from + dir * up * by);
      if (!_same(v, from)) {
        _onChanged(v);
        _stepValue = v;
        _onChange(TrackChange(value: v, from: from, crossed: [v]));
        _ended(v, start: from);
        _onSettled(v);
        _refresh();
      }
    });
  }

  // --- hit testing ---------------------------------------------------------------------

  bool _hitNode = false;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!_interactive) return super.hitTest(result, position: position);
    _hitNode = _hitTestNode(result, position);
    if (_hitNode || (_track.jumpOnTap && _onTrack(position)) || _inHitArea(position)) {
      result.add(BoxHitTestEntry(this, position));
      return true;
    }
    return false;
  }

  /// The moved node: only its own box counts, not its overflow.
  bool _hitTestNode(BoxHitTestResult result, Offset position) {
    final child = this.child;
    if (child == null) return false;
    pose();
    return result.addWithPaintTransform(
      transform: effectiveTransform,
      position: position,
      hitTest: (result, p) {
        if (!child.size.contains(p)) return false;
        child.hitTest(result, position: p);
        return true;
      },
    );
  }

  /// Whether [position] lies on the track's area: the circle an arc's node
  /// sweeps, or the box round a line or path.
  bool _onTrack(Offset position) {
    final rel = _rel(position);
    final g = _geometry;
    if (_track.shape == api.TrackShape.arc) {
      final (center, radius) = g.sweptCircle(size);
      return (rel - center).distance <= radius;
    }
    return g.bounds(size).contains(rel);
  }

  /// The box that takes the pointer for [api.TrackHitArea.parent]: the
  /// node's parent's.
  RenderBox? get _hitAreaBox {
    final box = _box;
    if (box == null || _track.hitArea != api.TrackHitArea.parent) return null;
    final parentId = box.tree.source.parentOf(box.id);
    if (parentId == null) return null;
    final p = box.tree.boxOf(parentId, instance: box.instance) ?? box.tree.boxOf(parentId);
    return p?.contentBox ?? p;
  }

  bool _inHitArea(Offset position) {
    final area = _hitAreaBox;
    if (area == null || !area.attached || !area.hasSize || !attached) return false;
    try {
      return (Offset.zero & area.size).contains(MatrixUtils.transformPoint(getTransformTo(area), position));
    } catch (_) {
      return false;
    }
  }

  /// The node box was hit at [position] outside its size: the track's area
  /// or its hit area may still take it.
  bool _hitOutside(BoxHitTestResult result, Offset position) {
    final box = _box;
    if (box == null || !attached || !hasSize) return false;
    final Matrix4 toBox;
    try {
      toBox = getTransformTo(box);
    } catch (_) {
      return false;
    }
    return result.addWithPaintTransform(
      transform: toBox,
      position: position,
      hitTest: (result, p) => hitTest(result, position: p),
    );
  }

  @override
  void handleEvent(PointerEvent event, covariant BoxHitTestEntry entry) {
    if (!_interactive) return;
    if (event is PointerDownEvent) {
      _pointerDown(event, entry.localPosition, _hitNode);
    } else if (event is PointerScrollEvent) {
      _onWheel(event);
    }
  }

  // --- the mouse, focus and semantics --------------------------------------------------

  @override
  MouseCursor get cursor => _enabled
      ? (_dragValue != null ? SystemMouseCursors.grabbing : SystemMouseCursors.grab)
      : MouseCursor.defer;

  @override
  PointerEnterEventListener? get onEnter => null;

  @override
  PointerExitEventListener? get onExit => null;

  @override
  bool get validForMouseTracker => attached && _interactive;

  FocusNode? _focus;
  FocusAttachment? _focusAttachment;
  bool _focusScheduled = false;

  /// Takes the keys (arrows, page up/down, home, end) through a focus node
  /// in the app's focus tree, under the view the node is shown in.
  void _syncFocus() {
    final want = attached && _interactive && _keys;
    if (want && _focus == null) {
      final context = islandContextOf(this);
      if (context == null) return;
      final f = _focus = FocusNode(debugLabel: 'drag track', onKeyEvent: _onKey);
      f.addListener(_focusChanged);
      _focusAttachment = f.attach(context)..reparent();
    } else if (!want && _focus != null) {
      final f = _focus!;
      _focus = null;
      f.removeListener(_focusChanged);
      _focusAttachment?.detach();
      _focusAttachment = null;
      f.dispose();
      if (_focused) {
        _focused = false;
        _refresh(later: true);
      }
    }
  }

  void _focusSoon() {
    if (_focusScheduled) return;
    _focusScheduled = true;
    scheduleMicrotask(() {
      _focusScheduled = false;
      _syncFocus();
    });
  }

  void _focusChanged() {
    final f = _focus?.hasFocus ?? false;
    if (f == _focused) return;
    _focused = f;
    _refresh(later: true);
  }

  /// [v] as a screen reader reads it: empty while there's no value.
  String _valueText(double v) {
    if (!_inRange(v)) return '';
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(6).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    if (!_interactive) return;
    final keyStep = _track.effectiveKeyStep ?? (_track.step > 0 ? _track.step : _track.effectiveWheelStep);
    final up = _stepped(keyStep, 1), down = _stepped(keyStep, -1);
    final shown = _shownValue;
    config
      ..isSemanticBoundary = true
      ..textDirection = TextDirection.ltr
      ..isSlider = true
      ..isEnabled = _enabled
      ..value = _valueText(shown)
      ..increasedValue = _inRange(shown) ? _valueText(up) : ''
      ..decreasedValue = _inRange(shown) ? _valueText(down) : '';
    if (_enabled && !_same(up, _value)) config.onIncrease = () => _set(up);
    if (_enabled && !_same(down, _value)) config.onDecrease = () => _set(down);
  }

  // --- lifecycle -----------------------------------------------------------------------

  bool _registered = false;

  void _syncRegistration() {
    final box = _box;
    final want = attached && _interactive && box != null;
    if (want && !_registered) {
      _registered = true;
      DragTracks._add(box.tree, box.id, this);
    } else if (!want && _registered) {
      _unregister();
    }
    _focusSoon();
  }

  void _unregister() {
    final box = _box;
    if (box != null) DragTracks._remove(box.tree, box.id, this);
    _registered = false;
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _watched?.addListener(_onVariable);
    _syncRegistration();
    _syncTicker();
  }

  @override
  void detach() {
    _watched?.removeListener(_onVariable);
    _ticker?.stop();
    _hold?.cancel();
    _drag?.dispose();
    _drag = null;
    _doubleTap?.dispose();
    _doubleTap = null;
    if (_registered) _unregister();
    super.detach();
    _focusSoon();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _ticker = null;
    _hold?.cancel();
    _drag?.dispose();
    _doubleTap?.dispose();
    _watched?.removeListener(_onVariable);
    _watched = null;
    final f = _focus;
    _focus = null;
    _focusAttachment?.detach();
    f?.dispose();
    super.dispose();
  }
}

/// The element that shows [o]'s node boxes (its [NodeView] or island), for
/// what needs a place in the element tree (a focus node).
BuildContext? islandContextOf(RenderObject o) {
  for (RenderObject? p = o; p != null; p = p.parent) {
    if (p is IslandParent) return p.islandContext;
  }
  return null;
}
