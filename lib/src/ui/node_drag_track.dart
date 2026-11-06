import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../transformers/node_transformers/freeform_layout.dart';
import '../utils/svg_path.dart';
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

  /// Whether the track is in fine mode ([DragTrackModel.fineStep]).
  final bool fine;

  /// Whether the track has keyboard focus (see [DragTrackModel.keyboard]).
  final bool focused;

  /// Creates [TrackValues].
  const TrackValues({
    this.value = 0,
    this.progress = 0,
    this.dragging = false,
    this.fine = false,
    this.focused = false,
  });

  /// The values as the `track` variable reads them.
  Map<String, dynamic> toMap() => {
    'value': value.isNaN ? null : value,
    'progress': progress,
    'dragging': dragging,
    'fine': fine,
    'focused': focused,
  };

  @override
  bool operator ==(Object other) =>
      other is TrackValues &&
      (other.value == value || (other.value.isNaN && value.isNaN)) &&
      other.progress == progress &&
      other.dragging == dragging &&
      other.fine == fine &&
      other.focused == focused;

  @override
  int get hashCode => Object.hash(
    value.isNaN ? null : value,
    progress,
    dragging,
    fine,
    focused,
  );
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

/// [track] with its node's bindings ([bound], the resolved `track.<field>`
/// values, see [DragTrackModel.bindableFields]) applied and, for
/// [DragTrackUnits.parent], its line and pivot scaled from fractions of
/// [parentSize] to pixels. A path's coordinates are scaled by the
/// geometry ([DragTrackGeometry.scale], see [trackPathScale]).
DragTrackModel resolveDragTrack(
  DragTrackModel track, {
  Map<String, Object?> bound = const {},
  Size? parentSize,
}) {
  final DragTrackModel t = bound.isEmpty ? track : track.withBound(bound);
  if (t.units != DragTrackUnits.parent || parentSize == null) return t;
  final double w = parentSize.width.isFinite ? parentSize.width : 0;
  final double h = parentSize.height.isFinite ? parentSize.height : 0;
  return t.copyWith(
    x1: t.x1 * w,
    x2: t.x2 * w,
    pivotX: t.pivotX * w,
    y1: t.y1 * h,
    y2: t.y2 * h,
    pivotY: t.pivotY * h,
  );
}

/// How much a [DragTrackUnits.parent] track's path is scaled to pixels for
/// a parent of [parentSize]; (1, 1) otherwise.
Size trackPathScale(DragTrackModel track, Size? parentSize) {
  if (track.units != DragTrackUnits.parent || parentSize == null) {
    return const Size(1, 1);
  }
  return Size(
    parentSize.width.isFinite ? parentSize.width : 0,
    parentSize.height.isFinite ? parentSize.height : 0,
  );
}

/// Builds a drag track with the size of its node's parent, measured from
/// [parentBox] after layout: a playhead whose line spans its parent at any
/// width ([DragTrackUnits.parent], or a `track.x2` binding reading
/// `${parent.width}`). The first frame builds with null (the caller falls
/// back to the parent's design size); a changed size rebuilds.
///
/// A freeform parent gives its children their own box as constraints, so
/// the `parent` a node normally reads there is not its parent's size.
class TrackParentMeasure extends StatefulWidget {
  /// Creates a [TrackParentMeasure].
  const TrackParentMeasure({
    super.key,
    required this.parentBox,
    required this.builder,
  });

  /// The parent's render box, or null when there is none.
  final RenderBox? Function() parentBox;

  /// Builds the track with the parent's measured size.
  final Widget Function(BuildContext context, Size? parentSize) builder;

  @override
  State<TrackParentMeasure> createState() => _TrackParentMeasureState();
}

class _TrackParentMeasureState extends State<TrackParentMeasure> {
  Size? _size;

  void _measure(Duration _) {
    if (!mounted) return;
    final RenderBox? box = widget.parentBox();
    if (box == null || !box.attached || !box.hasSize) return;
    if (box.size != _size) setState(() => _size = box.size);
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback(_measure);
    return widget.builder(context, _size);
  }
}

/// Geometry of a [DragTrackModel], in the node's own coordinates with the
/// origin at the node's rest centre.
class DragTrackGeometry {
  /// Creates the geometry of [track]; a path's coordinates are multiplied by
  /// [scale] (see [trackPathScale]).
  DragTrackGeometry(this.track, {this.scale = const Size(1, 1)}) {
    _sample();
  }

  /// The track.
  final DragTrackModel track;

  /// What a path's coordinates are multiplied by ([DragTrackUnits.parent]);
  /// a viewBox path ([DragTrackModel.usesViewBox]) is scaled to its frame
  /// instead.
  final Size scale;
  final List<Offset> _samples = [];

  Offset _scaled(Offset o) => Offset(o.dx * scale.width, o.dy * scale.height);

  /// [angle] (radians) of a path direction once scaled.
  double _scaledAngle(double angle) => scale.width == scale.height
      ? angle
      : math.atan2(
          math.sin(angle) * scale.height,
          math.cos(angle) * scale.width,
        );

  /// For a track in a viewBox ([DragTrackModel.usesViewBox]): the scale
  /// from viewBox units to the frame's pixels, and the node's rest centre
  /// in the frame. Set by the track's render object after layout.
  Offset _scale = const Offset(1, 1);
  Offset _rest = Offset.zero;

  /// The node's size: a [DragTrackModel.relative] line is measured in it.
  Size size = Size.zero;

  /// The ends of a line track, in pixels relative to the rest centre.
  Offset get _lineStart => track.relative
      ? Offset(track.x1 * size.width, track.y1 * size.height)
      : Offset(track.x1, track.y1);
  Offset get _lineEnd => track.relative
      ? Offset(track.x2 * size.width, track.y2 * size.height)
      : Offset(track.x2, track.y2);

  /// Places a viewBox track in a frame of [frameSize] where the node's rest
  /// centre is at [rest]. Returns whether anything changed.
  bool setFrame(Size frameSize, Offset rest) {
    if (!track.usesViewBox) return false;
    final Offset scale = Offset(
      frameSize.width / track.viewBoxWidth,
      frameSize.height / track.viewBoxHeight,
    );
    if (scale == _scale && rest == _rest) return false;
    _scale = scale;
    _rest = rest;
    _sample();
    return true;
  }

  /// [point] of the path as an offset from the node's rest centre.
  Offset _place(Offset point) => track.usesViewBox
      ? Offset(
              (point.dx + _start.dx) * _scale.dx,
              (point.dy + _start.dy) * _scale.dy,
            ) -
            _rest
      : _scaled(point);

  /// Where a viewBox path starts, in viewBox units.
  Offset _start = Offset.zero;

  void _sample() {
    _samples.clear();
    final String? data = track.path;
    // Motion paths are measured from their start; a viewBox path is placed
    // where it is drawn, so its start goes back on.
    _start = Offset.zero;
    if (track.usesViewBox && data != null) {
      final Path? path = parseSvgPath(data);
      final Iterator<PathMetric>? it = path?.computeMetrics().iterator;
      if (it != null && it.moveNext()) {
        _start = it.current.getTangentForOffset(0)?.position ?? Offset.zero;
      }
    }
    if (track.shape == DragTrackShape.path && data != null) {
      // Samples for finding the nearest point to the pointer.
      const int n = 240;
      for (int i = 0; i <= n; i++) {
        final (Offset, double)? point = pointOnMotionPath(data, i / n);
        if (point == null) break;
        _samples.add(_place(point.$1));
      }
    }
  }

  /// Where the node's centre sits at [progress], relative to rest.
  /// A line or arc goes on past its ends for a progress outside 0 to 1
  /// (a drag stretched past an end, see [DragTrackModel.overscroll], or a
  /// parked node, see [DragTrackModel.parkedProgress]); a path stops at its
  /// ends.
  Offset offsetAt(double progress) {
    final double p = track.shape == DragTrackShape.path
        ? track.clampProgress(progress)
        : progress;
    switch (track.shape) {
      case DragTrackShape.line:
        return Offset.lerp(_lineStart, _lineEnd, p)!;
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
        if (track.usesViewBox && _samples.isNotEmpty) {
          // Along the stretched path: by its own (pixel) length.
          return _alongSamples(p);
        }
        return _place(pointOnMotionPath(data, p)?.$1 ?? Offset.zero);
    }
  }

  /// The point [p] of the way along the sampled (placed) path, by length.
  Offset _alongSamples(double p) {
    double total = 0;
    for (int i = 1; i < _samples.length; i++) {
      total += (_samples[i] - _samples[i - 1]).distance;
    }
    double d = p * total;
    for (int i = 1; i < _samples.length; i++) {
      final double seg = (_samples[i] - _samples[i - 1]).distance;
      if (d <= seg && seg > 0) {
        return Offset.lerp(_samples[i - 1], _samples[i], d / seg)!;
      }
      d -= seg;
    }
    return _samples.last;
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
        final double angle = track.usesViewBox
            ? point.$2
            : _scaledAngle(point.$2);
        // Kept from turning upside down ([DragTrackModel.orientUpright]).
        return (track.orientUpright ? uprightPathAngle(angle) : angle) *
            180 /
            math.pi;
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
  /// to the rest centre), or of the angle [p] makes around an arc's pivot.
  /// A line's point may lie past its ends ([unclamped]), for a drag that
  /// stretches past them.
  double nearest(Offset p, {bool unclamped = false}) {
    switch (track.shape) {
      case DragTrackShape.line:
        final Offset a = _lineStart;
        final Offset d = _lineEnd - a;
        final double len2 = d.distanceSquared;
        if (len2 == 0) return 0;
        final Offset ap = p - a;
        final double t = (ap.dx * d.dx + ap.dy * d.dy) / len2;
        return unclamped ? t : t.clamp(0.0, 1.0);
      case DragTrackShape.path:
        if (_samples.isEmpty) return 0;
        if (track.usesViewBox) return _nearestByLength(p);
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
        // The pointer's angle around the pivot, from where the node rests,
        // taken in whichever turn lands inside the sweep (or nearest an end
        // of it, for the gap).
        final double sweep = track.endAngle - track.startAngle;
        if (sweep == 0) return 0;
        final double raw = angleOf(p) - angleOf(Offset.zero);
        final double lo = math.min(track.startAngle, track.endAngle);
        final double hi = math.max(track.startAngle, track.endAngle);
        double a = raw;
        double best = double.infinity;
        for (int turn = -2; turn <= 2; turn++) {
          final double c = raw + turn * 360;
          final double off = c < lo ? lo - c : (c > hi ? c - hi : 0);
          if (off < best) {
            best = off;
            a = c;
          }
        }
        return ((a - track.startAngle) / sweep).clamp(0.0, 1.0);
    }
  }

  /// The progress (by length along the placed path) nearest [p].
  double _nearestByLength(Offset p) {
    double total = 0, at = 0, bestD = double.infinity, bestAt = 0;
    for (int i = 1; i < _samples.length; i++) {
      final Offset a = _samples[i - 1];
      final Offset d = _samples[i] - a;
      final double len = d.distance;
      final double t = len == 0
          ? 0
          : (((p - a).dx * d.dx + (p - a).dy * d.dy) / (len * len)).clamp(
              0.0,
              1.0,
            );
      final double dist = (a + d * t - p).distanceSquared;
      if (dist < bestD) {
        bestD = dist;
        bestAt = at + len * t;
      }
      at += len;
      total += len;
    }
    return total == 0 ? 0 : bestAt / total;
  }

  /// The progress along an arc whose angle is nearest [angle] (degrees
  /// clockwise from up): inside the sweep, where it is; in the gap past its
  /// ends, the nearer end. Null for a track that isn't an arc or has no
  /// sweep.
  double? progressAtAngle(double angle) {
    if (track.shape != DragTrackShape.arc) return null;
    final double start = track.startAngle, end = track.endAngle;
    final double sweep = end - start;
    if (sweep == 0) return null;
    // The angle as a turn past the start, in the sweep's direction.
    double from = (angle - start) * sweep.sign % 360;
    if (from < 0) from += 360;
    final double span = sweep.abs();
    if (from <= span) return from / span;
    // In the gap: snap to whichever end is closer.
    return (from - span) < (360 - from) ? 1 : 0;
  }

  /// The circle an arc's node sweeps round its pivot, as (centre, radius)
  /// relative to the rest centre, for a node of [size].
  (Offset, double) sweptCircle(Size size) {
    final Offset pivot = Offset(track.pivotX, track.pivotY);
    return (pivot, pivot.distance + size.longestSide / 2);
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

/// The spring a [DragTrackModel] settles with when its
/// [DragTrackModel.settleCurve] is [MotionCurve.spring].
SpringDescription trackSettleSpring(DragTrackModel track) => SpringDescription(
  mass: 1,
  stiffness: track.settleStiffness <= 0 ? 380 : track.settleStiffness,
  damping: track.settleDamping < 0 ? 20 : track.settleDamping,
);

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
/// [DragTrackModel.jumpOnTap], pressing along the track) reports new values
/// through [onChanged]. While dragged the node follows the pointer; once
/// let go it is drawn at [value] again (which the reactions may have
/// changed). Double tap moves through [DragTrackModel.doubleTapValues] (or
/// resets to [DragTrackModel.defaultValue]), the mouse wheel steps the
/// value by [DragTrackModel.effectiveWheelStep] (Shift + wheel by the fine
/// step), and with a [DragTrackModel.keyStep] the arrow keys step it while
/// focused.
///
/// With [DragTrackHitArea.parent] the pointer is taken anywhere in the box
/// [hitAreaBox] gives (the node's parent).
///
/// A vertical or horizontal track takes its drags with a drag recognizer of
/// that axis, and a follow track claims the pointer as soon as it lands on
/// it, so a control inside a scrolling page turns instead of scrolling the
/// page. With [DragTrackModel.fineStep] the track has a fine mode (Shift, or
/// press and hold still before dragging), reported through [onFine]. With
/// [DragTrackModel.snapMs] the node animates to each new value.
///
/// With [DragTrackModel.momentum] a flick keeps it going after the pointer
/// lifts, slowing by [DragTrackModel.friction]; with
/// [DragTrackModel.smooth] it is drawn between steps while it moves and
/// springs onto a step when it stops. [onSettled] reports the value it comes
/// to rest on. [step] turns a mounted track from an action.
///
/// The feel: with [DragTrackModel.detent] the node leans past its step
/// while dragged, with [DragTrackModel.overscroll] it stretches past the
/// ends, and with [DragTrackModel.settleMs] (or a spring
/// [DragTrackModel.settleCurve]) it glides to its value's place whenever it
/// isn't following the pointer: on release (at the release speed for a
/// spring), and when the value changes from elsewhere. A value out of range
/// or empty (NaN) is drawn at [DragTrackModel.parkedProgress] when the
/// track has one. With [DragTrackModel.keyboard] the track takes the focus
/// and the keys step it; screen readers see a slider.
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
    this.onChange,
    this.onSettled,
    this.onFine,
    this.enabled = true,
    this.gain,
    this.nodeId,
    this.pathScale = const Size(1, 1),
    this.hitAreaBox,
  });

  /// The track, its bindings resolved (see [resolveDragTrack]).
  final DragTrackModel track;

  /// What a path track's coordinates are multiplied by (see
  /// [trackPathScale]).
  final Size pathScale;

  /// The box whose area takes the pointer for [DragTrackHitArea.parent]: an
  /// ancestor's render box. Null takes it on the node only.
  final RenderBox? Function()? hitAreaBox;

  /// The variable's current value; NaN for an empty variable or one that
  /// isn't a number (drawn at [DragTrackModel.parkedProgress]).
  final double value;

  /// Called with each new (snapped) value while dragging.
  final ValueChanged<double> onChanged;

  /// Called with each change and what it crossed, after [onChanged].
  final ValueChanged<TrackChange>? onChange;

  /// Called when the pointer lifts, with the final value.
  final ValueChanged<double>? onEnd;

  /// Called with [onEnd], with the final value, the value the drag started
  /// at and the release velocity in the variable's units per second along
  /// the track (see [DragTrackModel.endValues]); 0 for a wheel, key or tap
  /// change.
  final void Function(double value, double startValue, double velocity)?
  onRelease;

  /// Called when the control comes to rest after a drag, a coast, a wheel
  /// notch or a [step], with the value it rests on.
  final ValueChanged<double>? onSettled;

  /// Called when fine mode turns on or off.
  final ValueChanged<bool>? onFine;

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

/// The pan a [NodeDragTrack] turns its value with. It claims the pointer
/// after half the movement any drag or scroll needs (half a pixel with a
/// mouse, half the touch slop on touch), so a control wins over what holds
/// it: a knob on a pedal that can itself be dragged (a draggable starts at
/// 1px with a mouse), a fader in a scrolling page (a scroll starts at the
/// touch slop, where a plain pan needs twice that). Holding still is not
/// claiming, so a double tap still resets the value.
class TrackPanGestureRecognizer extends PanGestureRecognizer {
  /// Creates a [TrackPanGestureRecognizer].
  TrackPanGestureRecognizer({super.debugOwner});

  @override
  bool hasSufficientGlobalDistanceToAccept(
    PointerDeviceKind pointerDeviceKind,
    double? deviceTouchSlop,
  ) =>
      globalDistanceMoved.abs() >
      computeHitSlop(pointerDeviceKind, gestureSettings) / 2;
}

/// The curve named by [DragTrackModel.snapCurve].
Curve trackSnapCurve(String name) => switch (name) {
  'linear' => Curves.linear,
  'easeIn' => Curves.easeIn,
  'easeOut' => Curves.easeOut,
  'easeInOut' => Curves.easeInOut,
  'easeOutCubic' => Curves.easeOutCubic,
  'elasticOut' => Curves.elasticOut,
  'bounceOut' => Curves.bounceOut,
  _ => Curves.easeOutBack,
};

class _NodeDragTrackState extends State<NodeDragTrack>
    with TickerProviderStateMixin {
  late DragTrackGeometry _geometry = DragTrackGeometry(
    widget.track,
    scale: widget.pathScale,
  );

  /// Takes the keys while the track has them ([DragTrackModel.keyboard]).
  final FocusNode _focus = FocusNode(debugLabel: 'drag track');
  bool _focused = false;

  /// The value the last wheel or key step wrote, until the widget is
  /// rebuilt with it: quick key repeats step on from there.
  double? _stepValue;

  /// The value a drag (or a step) started from, for `dragEnd`.
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

  /// The pointer's progress while dragging, coasting or snapping, unsnapped
  /// (and past the ends when the track allows
  /// [DragTrackModel.overscroll]).
  double _raw = 0;

  /// The value shown while dragging, ahead of the variable catching up.
  double? _dragValue;
  double? _lastAngle;
  Offset _grab = Offset.zero;
  Size _size = Size.zero;
  Offset? _lastLocal;

  /// Fine mode: from Shift or a press held still ([DragTrackModel.fineHoldMs]).
  bool _fine = false;
  bool _heldFine = false;
  Timer? _hold;

  /// The drawn progress while it animates to a new value
  /// ([DragTrackModel.snapMs]).
  late final AnimationController _snap = AnimationController(vsync: this);
  double _from = 0;
  double _to = 0;

  /// Where a smooth track is drawn while it moves (null: at its value).
  double? _drawProgress;

  /// Coasting speed in progress per second.
  double _velocity = 0;

  /// Progress a snap (or an animated external change) is heading for.
  double? _snapTo;

  /// Whether the motion that is ending should report [NodeDragTrack.onSettled].
  bool _settleWhenDone = false;

  /// Where a value set from elsewhere is being drawn gliding to.
  double? _glideTo;

  /// Whether a pointer is dragging the control now.
  bool _pointerActive = false;
  Duration _last = Duration.zero;
  late final Ticker _ticker = createTicker(_onTick);

  late DragGestureRecognizer _drag = _makeDrag();
  late final DoubleTapGestureRecognizer _doubleTap =
      DoubleTapGestureRecognizer()..onDoubleTap = _onDoubleTap;

  DragGestureRecognizer _makeDrag() {
    final DragGestureRecognizer r = switch (widget.track.input) {
      DragTrackInput.vertical => VerticalDragGestureRecognizer(),
      DragTrackInput.horizontal => HorizontalDragGestureRecognizer(),
      DragTrackInput.follow ||
      DragTrackInput.both => TrackPanGestureRecognizer(),
    };
    return r
      ..dragStartBehavior = DragStartBehavior.down
      ..onDown = _onDown
      ..onStart = _onStart
      ..onUpdate = _onUpdate
      ..onEnd = _onPanEnd
      ..onCancel = _onEnd;
  }

  @override
  void initState() {
    super.initState();
    _from = _to = _progress;
    _snap.value = 1;
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
    _stepValue = null;
    if (oldWidget.track != widget.track ||
        oldWidget.pathScale != widget.pathScale) {
      _geometry = DragTrackGeometry(widget.track, scale: widget.pathScale);
      if (oldWidget.track.input != widget.track.input) {
        _drag.dispose();
        _drag = _makeDrag();
      }
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
    } else if (!_track.smooth &&
        _dragValue == null &&
        !_same(oldWidget.value, widget.value)) {
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
    _animateTo(_progress);
  }

  @override
  void dispose() {
    _unregister(widget.nodeId);
    _hold?.cancel();
    _ticker.dispose();
    _snap.dispose();
    _settle.dispose();
    _drag.dispose();
    _doubleTap.dispose();
    _focus.dispose();
    super.dispose();
  }

  DragTrackModel get _track => widget.track;
  double get _gain => widget.gain ?? _track.gain;
  double get _shownValue => _dragValue ?? widget.value;
  bool get _moving => _ticker.isActive;

  /// Equal values, NaN (an empty variable) included.
  static bool _same(double a, double b) => a == b || (a.isNaN && b.isNaN);

  /// Whether the keys move the track (and it takes focus).
  bool get _keys => _track.effectiveKeyStep != null && widget.enabled;

  bool get _settling => _settle.isAnimating;
  double get _lerpSettle =>
      _settleFrom + (_settleTo - _settleFrom) * _settle.value;

  /// How fast the glide moves the drawn progress now, per second.
  double get _settleVelocity =>
      _settling ? _settle.velocity * (_settleTo - _settleFrom) : 0;

  /// Whether value changes glide instead of jumping.
  bool get _glides =>
      _track.settleMs > 0 || _track.settleCurve == MotionCurve.spring;

  /// Where the node is drawn along the track: where a smooth track draws
  /// it, following the pointer (held back by the step's detent, stretched
  /// past the ends), gliding to its value, or at its value (or parked).
  double get _progress {
    if (_drawProgress case final double drawn) return drawn;
    if (_dragValue != null) return _dragProgress;
    if (_settling) return _lerpSettle;
    return _track.restProgressOf(widget.value);
  }

  double get _dragProgress {
    // An endless arc is drawn at its value, in whichever turn it is.
    if (_track.unbounded) return _track.progressOf(_shownValue);
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
        !from.isFinite ||
        !to.isFinite ||
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

  /// Reports the end of a change at [v]: `dragEnd` with where it started
  /// ([start], else [_startValue]) and the release [velocity] (variable
  /// units per second).
  void _ended(double v, {double? start, double velocity = 0}) {
    widget.onEnd?.call(v);
    widget.onRelease?.call(v, start ?? _startValue, velocity);
  }

  /// The progress the node is drawn at: animating towards [_to] with
  /// [DragTrackModel.snapMs], else where the value is.
  double get _drawn {
    if (_track.snapMs <= 0) return _progress;
    if (!_snap.isAnimating) return _to;
    final double t = trackSnapCurve(_track.snapCurve).transform(_snap.value);
    return _from + (_to - _from) * t;
  }

  void _animateTo(double target) {
    if (_track.snapMs <= 0 || target == _to) {
      _to = target;
      return;
    }
    _from = _drawn;
    _to = target;
    _snap.duration = Duration(
      milliseconds: _fine ? (_track.snapMs / 2).round() : _track.snapMs,
    );
    _snap.forward(from: 0);
  }

  void _setFine(bool fine) {
    if (fine == _fine) return;
    setState(() => _fine = fine);
    widget.onFine?.call(fine);
  }

  bool get _wantFine =>
      _track.hasFine && (_heldFine || HardwareKeyboard.instance.isShiftPressed);

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
    _raw = _track.overscroll > 0 && !_track.unbounded
        ? raw
        : _track.clampProgress(raw);
    if (_track.smooth) _drawProgress = _raw;
    final double at = _track.clampProgress(_raw);
    final double v = _fine
        ? _track.snapFine(_track.min + (_track.max - _track.min) * at)
        : _track.valueAt(at);
    final double from = _shownValue;
    if (v != from) {
      setState(() => _dragValue = v);
      _animateTo(_track.progressOf(v));
      widget.onChanged(v);
      widget.onChange?.call(
        TrackChange(
          value: v,
          from: from,
          crossed: from.isNaN ? [v] : _crossed(from, v),
        ),
      );
    } else if (_track.smooth || _track.detent > 0 || _track.overscroll > 0) {
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
    if (_track.jumpOnTap && _track.input == DragTrackInput.follow) {
      if (_track.shape == DragTrackShape.arc) {
        // A dial turns to the angle tapped (on the knob or its ring, or
        // anywhere in the circle it sweeps), then drags from there, like a
        // real dial's pointer. Too near the pivot there is no steady angle.
        final Offset p = _rel(local);
        final double? jump = _nearPivot(p)
            ? null
            : _geometry.progressAtAngle(_geometry.angleOf(p));
        if (jump != null) {
          _settle.stop();
          _raw = _progress;
          _emit(jump);
        }
      } else if (!onNode ||
          // A relative line's node is usually a scrub area as wide as its
          // track (a transparent thumb over a chart): a tap on it jumps too.
          (_track.relative && _track.shape == DragTrackShape.line)) {
        // Tapped the track off the node: jump there, then drag from there.
        _settle.stop();
        _raw = _progress;
        _emit(_geometry.nearest(_rel(local)));
      }
    }
    _drag.addPointer(event);
    _doubleTap.addPointer(event);
  }

  void _onDown(DragDownDetails d) {
    _hold?.cancel();
    if (!_track.hasFine || _track.fineHoldMs <= 0) return;
    // Pressed and held still: fine mode for the drag that follows.
    _hold = Timer(Duration(milliseconds: _track.fineHoldMs), () {
      if (!mounted) return;
      _heldFine = true;
      _setFine(true);
    });
  }

  void _onStart(DragStartDetails d) {
    _hold?.cancel();
    final Offset p = _rel(d.localPosition);
    _pointerActive = true;
    if (_glideTo != null) {
      _glideTo = null;
      _drawProgress = null;
    }
    // Caught mid-glide, the drag goes on from where the node is drawn; a
    // parked node is dragged from the nearest end. After a tap jump it goes
    // on from where it jumped to (the variable may not have caught up).
    final bool jumped = _dragValue != null;
    final double from = _track.clampProgress(_progress);
    _settle.stop();
    setState(() {
      if (!jumped) {
        _raw = from;
        _dragValue = _shownValue;
      }
      if (_track.smooth) _drawProgress = _raw;
    });
    _setFine(_wantFine);
    _lastAngle = _geometry.angleOf(p);
    _lastLocal = d.localPosition;
    _grab = _geometry.offsetAt(_raw) - p;
  }

  void _onUpdate(DragUpdateDetails d) {
    final bool fine = _wantFine;
    if (fine != _fine) {
      // Switching mode mid-drag: carry on from where the node is.
      _raw = _progress;
      _setFine(fine);
    }
    final Offset p = _rel(d.localPosition);
    _lastLocal = d.localPosition;
    final double ppr = _fine
        ? _track.effectiveFinePixelsPerRange
        : _track.pixelsPerRange;
    switch (_track.input) {
      case DragTrackInput.vertical:
        _emit(_raw - d.delta.dy * _gain / ppr);
      case DragTrackInput.horizontal:
        _emit(_raw + d.delta.dx * _gain / ppr);
      case DragTrackInput.both:
        _emit(_raw + (d.delta.dx - d.delta.dy) * _gain / ppr);
      case DragTrackInput.follow:
        if (_track.shape == DragTrackShape.arc) {
          final Offset fromPivot = p - Offset(_track.pivotX, _track.pivotY);
          if (fromPivot.distance < _size.shortestSide * 0.12) {
            // Too close to the pivot for a steady angle: use vertical travel.
            _emit(_raw - d.delta.dy * _gain / ppr);
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
          _emit(_geometry.nearest(p + _grab, unclamped: _track.overscroll > 0));
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
      case DragTrackInput.both:
        return (v.dx - v.dy) * _gain / _track.pixelsPerRange;
      case DragTrackInput.follow:
        if (_track.shape == DragTrackShape.arc) {
          final Offset r = _rel(local) - Offset(_track.pivotX, _track.pivotY);
          final double r2 = r.distanceSquared;
          if (r2 < 1) return 0;
          final double degPerSec =
              (r.dx * v.dy - r.dy * v.dx) / r2 * 180 / math.pi;
          final double sweep = _track.endAngle - _track.startAngle;
          return sweep == 0 ? 0 : degPerSec * _gain / sweep;
        }
        // Along a line or path: the velocity's share of the track's
        // direction where the node is.
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

  /// A coast starts above this speed (in degrees per second on an arc,
  /// about 230°/s; 400 px/s along a line or drag input).
  double get _coastStart =>
      _speedOf(_track.shape == DragTrackShape.arc ? 230 : 400);

  /// And ends below this one.
  double get _coastStop =>
      _speedOf(_track.shape == DragTrackShape.arc ? 52 : 60);

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
    final double speed = _dragValue == null ? 0 : _releaseSpeed(d.velocity);
    if (_track.momentum && _dragValue != null && !_fine) {
      if (speed.abs() > _coastStart) {
        _hold?.cancel();
        _heldFine = false;
        _setFine(false);
        _velocity = speed.clamp(-_coastStart * 4, _coastStart * 4);
        _settleWhenDone = true;
        _ended(_shownValue, velocity: speed * (_track.max - _track.min));
        _startTicker();
        return;
      }
    }
    _onEnd(speed.isFinite ? speed : 0);
  }

  /// The pointer lifted (or the drag was cancelled) with [speed] along the
  /// track, in progress per second.
  void _onEnd([double speed = 0]) {
    _pointerActive = false;
    _hold?.cancel();
    _heldFine = false;
    _setFine(false);
    if (_dragValue == null) return;
    final double v = _shownValue;
    final double velocity = speed * (_track.max - _track.min);
    if (_track.smooth && _drawProgress != null) {
      _ended(v, velocity: velocity);
      _settleWhenDone = true;
      _beginSnap();
      return;
    }
    final double drawn = _dragProgress;
    // Hold the dragged value until the variable has caught up. A spring
    // settle starts at the release speed, so a fling carries on.
    setState(() => _dragValue = null);
    _glide(drawn, _track.progressOf(v), velocity: speed);
    _ended(v, velocity: velocity);
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

  /// Turns the control [steps] steps (of [by], else the track's step, or a
  /// hundredth of the track each for a continuous one), as a drag would:
  /// crossing each step and settling.
  Future<bool> stepBy(int steps, {double? by}) async {
    if (!mounted || steps == 0) return mounted;
    // Gliding to a value set from elsewhere: finish there, then step on
    // from that value (the glide only draws; the value is already set).
    if (_glideTo != null) {
      _raw = _track.progressOf(widget.value);
      _drawProgress = _raw;
      _glideTo = null;
      _dragValue = widget.value;
    }
    final double unit =
        by ?? (_track.step > 0 ? _track.step : _track.effectiveWheelStep);
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
    if (!widget.enabled) return;
    // Through [DragTrackModel.doubleTapValues], else back to the default.
    final double? v = _track.doubleTapTarget(widget.value);
    if (v == null) return;
    _set(v, always: true);
  }

  /// Reports [v] as a whole change: a wheel notch, a key, a double tap.
  /// Nothing when it is the value already, unless [always].
  void _set(double v, {bool always = false}) {
    final double from = _stepValue ?? widget.value;
    if (_same(v, from) && !always) return;
    _stepValue = v;
    widget.onChanged(v);
    widget.onChange?.call(
      TrackChange(
        value: v,
        from: from,
        crossed: from.isNaN ? [v] : _crossed(from, v),
      ),
    );
    _ended(v, start: from);
    widget.onSettled?.call(v);
  }

  /// Whether [v] is a value on the track (not empty, not out of range).
  bool _inRange(double v) {
    if (v.isNaN) return false;
    if (_track.unbounded) return true;
    final double lo = math.min(_track.min, _track.max);
    final double hi = math.max(_track.min, _track.max);
    return v >= lo && v <= hi;
  }

  /// The value [steps] steps of [size] toward [DragTrackModel.max]. From an
  /// empty or out-of-range value any step lands on the nearest end.
  double _stepped(double size, int steps) {
    final double v = _stepValue ?? widget.value;
    if (!_inRange(v)) {
      return _track.valueAt(_track.restProgressOf(v) <= 0.5 ? 0 : 1);
    }
    final double up = _track.max >= _track.min ? 1 : -1;
    return _track.snap(v + steps * up * size);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final double? step = _track.effectiveKeyStep;
    if (step == null || !widget.enabled || _dragValue != null) {
      return KeyEventResult.ignored;
    }
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final LogicalKeyboardKey key = event.logicalKey;
    final double? v = switch (key) {
      LogicalKeyboardKey.arrowUp ||
      LogicalKeyboardKey.arrowRight => _stepped(step, 1),
      LogicalKeyboardKey.arrowDown ||
      LogicalKeyboardKey.arrowLeft => _stepped(step, -1),
      LogicalKeyboardKey.pageUp => _stepped(step, 10),
      LogicalKeyboardKey.pageDown => _stepped(step, -10),
      LogicalKeyboardKey.home => _track.snap(_track.min),
      LogicalKeyboardKey.end => _track.snap(_track.max),
      _ => null,
    };
    if (v == null) return KeyEventResult.ignored;
    _set(v);
    return KeyEventResult.handled;
  }

  void _onWheel(PointerScrollEvent event) {
    if (!_track.wheel || !widget.enabled) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (e) {
      final PointerScrollEvent s = e as PointerScrollEvent;
      if (s.scrollDelta.dy == 0) return;
      final int dir = s.scrollDelta.dy < 0 ? 1 : -1;
      final int up = _track.max >= _track.min ? 1 : -1;
      final bool fine =
          _track.hasFine && HardwareKeyboard.instance.isShiftPressed;
      // A stepped or smooth track turns one step, through the same path as
      // a drag (crossing, settling).
      // A set [DragTrackModel.wheelStep] is the notch's size.
      if (!fine &&
          (_track.step > 0 || _track.smooth) &&
          _inRange(widget.value)) {
        final double from = widget.value;
        stepBy(dir * up, by: _track.wheelStep);
        _ended(
          _track.snap(widget.value + dir * up * _track.effectiveWheelStep),
          start: from,
        );
        return;
      }
      final double by = fine ? _track.fineStep : _track.effectiveWheelStep;
      final double from = _stepValue ?? widget.value;
      final double v = !_inRange(from)
          ? _stepped(by, dir)
          : fine
          ? _track.snapFine(from + dir * up * by)
          : _track.snap(from + dir * up * by);
      if (!_same(v, from)) {
        _stepValue = v;
        widget.onChanged(v);
        widget.onChange?.call(TrackChange(value: v, from: from, crossed: [v]));
        _ended(v, start: from);
        widget.onSettled?.call(v);
      }
    });
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
    final bool enabled = widget.enabled;
    final double shownValue = _shownValue;
    final double keyStep =
        _track.effectiveKeyStep ??
        (_track.step > 0 ? _track.step : _track.effectiveWheelStep);
    final double up = _stepped(keyStep, 1);
    final double down = _stepped(keyStep, -1);
    Widget node = MouseRegion(
      cursor: enabled
          ? (_dragValue != null
                ? SystemMouseCursors.grabbing
                : SystemMouseCursors.grab)
          : MouseCursor.defer,
      child: widget.child,
    );
    // Inside the track area, whose hit test reaches past the node's box.
    node = Focus(
      focusNode: _focus,
      canRequestFocus: _keys,
      skipTraversal: !_keys,
      onKeyEvent: _onKey,
      onFocusChange: (focused) => setState(() => _focused = focused),
      child: node,
    );
    // Inside the moved area, so the slider's bounds follow the node.
    node = Semantics(
      container: true,
      slider: true,
      enabled: enabled,
      // Empty while there is no value (parked), as the slider's next values
      // must be too.
      value: _valueText(shownValue),
      increasedValue: _inRange(shownValue) ? _valueText(up) : '',
      decreasedValue: _inRange(shownValue) ? _valueText(down) : '',
      onIncrease: enabled && !_same(up, widget.value) ? () => _set(up) : null,
      onDecrease: enabled && !_same(down, widget.value)
          ? () => _set(down)
          : null,
      child: node,
    );
    return AnimatedBuilder(
      animation: _snap,
      builder: (context, child) {
        final double progress = _drawn;
        final double shown = _progress;
        return TrackScope(
          values: TrackValues(
            value: _shownValue,
            // An endless track reports where it is within one turn.
            progress: _track.unbounded ? shown - shown.floorToDouble() : shown,
            dragging: _dragValue != null,
            fine: _fine,
            focused: _focused,
          ),
          child: _TrackArea(
            geometry: _geometry,
            progress: progress,
            jumpOnTap: _track.jumpOnTap,
            hitAreaBox: _track.hitArea == DragTrackHitArea.parent
                ? widget.hitAreaBox
                : null,
            onSize: (size) => _size = size,
            onPointerDown: _pointerDown,
            onWheel: _onWheel,
            child: child!,
          ),
        );
      },
      child: node,
    );
  }
}

/// Draws its child moved along the track and takes pointer events on the
/// moved child, anywhere along the track when [jumpOnTap], and anywhere in
/// the box [hitAreaBox] gives when set.
class _TrackArea extends SingleChildRenderObjectWidget {
  const _TrackArea({
    required this.geometry,
    required this.progress,
    required this.jumpOnTap,
    required this.hitAreaBox,
    required this.onSize,
    required this.onPointerDown,
    required this.onWheel,
    required super.child,
  });

  final DragTrackGeometry geometry;
  final double progress;
  final bool jumpOnTap;
  final RenderBox? Function()? hitAreaBox;
  final ValueChanged<Size> onSize;
  final void Function(PointerDownEvent event, Offset local, bool onNode)
  onPointerDown;
  final ValueChanged<PointerScrollEvent> onWheel;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderTrackArea()
    ..geometry = geometry
    ..progress = progress
    ..jumpOnTap = jumpOnTap
    ..hitAreaBox = hitAreaBox
    ..onSize = onSize
    ..onPointerDown = onPointerDown
    ..onWheel = onWheel;

  @override
  void updateRenderObject(BuildContext context, _RenderTrackArea r) => r
    ..geometry = geometry
    ..progress = progress
    ..jumpOnTap = jumpOnTap
    ..hitAreaBox = hitAreaBox
    ..onSize = onSize
    ..onPointerDown = onPointerDown
    ..onWheel = onWheel;
}

class _RenderTrackArea extends RenderProxyBox {
  late DragTrackGeometry _geometry;
  set geometry(DragTrackGeometry g) {
    if (hasSize) g.size = size;
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
  RenderBox? Function()? hitAreaBox;
  late ValueChanged<Size> onSize;
  late void Function(PointerDownEvent, Offset, bool) onPointerDown;
  late ValueChanged<PointerScrollEvent> onWheel;

  /// Whether the last hit landed on the moved child (else on the track).
  bool _hitNode = false;

  Matrix4 get _transform {
    _placeInFrame();
    return _geometry.transformAt(_progress, size);
  }

  /// For a track drawn in its frame's viewBox: tells the geometry how big
  /// the frame is and where the node rests in it.
  void _placeInFrame() {
    if (!_geometry.track.usesViewBox || !hasSize) return;
    RenderObject? up = parent;
    while (up != null && up is! RenderFreeformLayout) {
      up = up.parent;
    }
    final RenderObject? frame = up;
    if (frame is! RenderFreeformLayout || !frame.hasSize) return;
    final Offset rest = MatrixUtils.transformPoint(
      getTransformTo(frame),
      size.center(Offset.zero),
    );
    _geometry.setFrame(frame.size, rest);
  }

  @override
  void performLayout() {
    super.performLayout();
    _geometry.size = size;
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
    final bool onTrack = jumpOnTap && _onTrack(position);
    if (_hitNode || onTrack || _inHitArea(position)) {
      result.add(BoxHitTestEntry(this, position));
      return true;
    }
    return false;
  }

  /// Whether [position] (in this box) lies in the [hitAreaBox]'s box.
  bool _inHitArea(Offset position) {
    final RenderBox? area = hitAreaBox?.call();
    if (area == null || !area.attached || !area.hasSize || !attached) {
      return false;
    }
    try {
      final Offset inArea = MatrixUtils.transformPoint(
        getTransformTo(area),
        position,
      );
      return (Offset.zero & area.size).contains(inArea);
    } catch (_) {
      // Not an ancestor (the tree moved): the node only.
      return false;
    }
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

/// Draws [child] where its track puts it at [progress], without making it
/// draggable (the design canvas). The pose is worked out from the child's
/// laid-out size, so relative lines ([DragTrackModel.relative]) move by
/// their share of it.
class TrackPose extends SingleChildRenderObjectWidget {
  /// Creates a [TrackPose].
  const TrackPose({
    super.key,
    required this.track,
    required this.progress,
    this.pathScale = const Size(1, 1),
    required super.child,
  });

  /// The track.
  final DragTrackModel track;

  /// Where along the track to draw the child, 0 to 1.
  final double progress;

  /// What a path track's coordinates are multiplied by (see
  /// [trackPathScale]).
  final Size pathScale;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderTrackPose(DragTrackGeometry(track, scale: pathScale), progress);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    final _RenderTrackPose r = renderObject as _RenderTrackPose;
    if (r._geometry.track != track || r._geometry.scale != pathScale) {
      r.geometry = DragTrackGeometry(track, scale: pathScale);
    }
    r.progress = progress;
  }
}

class _RenderTrackPose extends RenderProxyBox {
  _RenderTrackPose(this._geometry, this._progress);

  DragTrackGeometry _geometry;
  set geometry(DragTrackGeometry g) {
    if (hasSize) g.size = size;
    _geometry = g;
    markNeedsPaint();
  }

  double _progress;
  set progress(double p) {
    if (p == _progress) return;
    _progress = p;
    markNeedsPaint();
  }

  Matrix4 get _transform => _geometry.transformAt(_progress, size);

  @override
  void performLayout() {
    super.performLayout();
    _geometry.size = size;
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      result.addWithPaintTransform(
        transform: _transform,
        position: position,
        hitTest: (result, position) =>
            super.hitTestChildren(result, position: position),
      );

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
