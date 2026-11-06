import 'dart:math' as math;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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
    final String? data = track.path;
    if (track.shape == DragTrackShape.path && data != null) {
      // Samples for finding the nearest point to the pointer.
      const int n = 240;
      for (int i = 0; i <= n; i++) {
        final (Offset, double)? point = pointOnMotionPath(data, i / n);
        if (point == null) break;
        _samples.add(_scaled(point.$1));
      }
    }
  }

  /// The track.
  final DragTrackModel track;

  /// What a path's coordinates are multiplied by.
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

  /// Where the node's centre sits at [progress], relative to rest.
  Offset offsetAt(double progress) {
    final double p = progress.clamp(0.0, 1.0);
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
        return _scaled(pointOnMotionPath(data, p)?.$1 ?? Offset.zero);
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
        return point == null ? 0 : _scaledAngle(point.$2) * 180 / math.pi;
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

  /// The progress along an arc at the pointer's angle round its pivot: the
  /// angle is taken within half a turn of the arc's middle, so a point in
  /// the gap of an open arc goes to the nearer end.
  double arcProgressAt(Offset p) {
    final double sweep = track.endAngle - track.startAngle;
    if (sweep == 0) return 0;
    final double mid = (track.startAngle + track.endAngle) / 2;
    double a = angleOf(p);
    while (a - mid > 180) {
      a -= 360;
    }
    while (a - mid < -180) {
      a += 360;
    }
    return ((a - track.startAngle) / sweep).clamp(0.0, 1.0);
  }

  /// The progress at pointer [p] for a jump: its angle on an arc, its
  /// nearest point on a line or path.
  double jumpProgressAt(Offset p) => track.shape == DragTrackShape.arc
      ? arcProgressAt(p)
      : nearest(p);

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

/// Makes [child] a value control that moves along [track]: it is drawn at
/// [value]'s place on the track, and dragging it (or, with
/// [DragTrackModel.jumpOnTap], pressing along the track) reports new values
/// through [onChanged]. While dragged the node follows the pointer; once
/// let go it is drawn at [value] again (which the reactions may have
/// changed). Double tap moves through [DragTrackModel.doubleTapValues] (or
/// resets to [DragTrackModel.defaultValue]), the mouse wheel steps the
/// value by [DragTrackModel.effectiveWheelStep], and with a
/// [DragTrackModel.keyStep] the arrow keys step it while focused.
///
/// With [DragTrackHitArea.parent] the pointer is taken anywhere in the box
/// [hitAreaBox] gives (the node's parent).
class NodeDragTrack extends StatefulWidget {
  /// Creates a [NodeDragTrack].
  const NodeDragTrack({
    super.key,
    required this.track,
    required this.value,
    required this.onChanged,
    required this.child,
    this.onEnd,
    this.enabled = true,
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

  /// The variable's current value.
  final double value;

  /// Called with each new (snapped) value while dragging.
  final ValueChanged<double> onChanged;

  /// Called when the pointer lifts, with the final value.
  final ValueChanged<double>? onEnd;

  /// Whether the control responds to the pointer.
  final bool enabled;

  /// The node.
  final Widget child;

  @override
  State<NodeDragTrack> createState() => _NodeDragTrackState();
}

class _NodeDragTrackState extends State<NodeDragTrack> {
  late DragTrackGeometry _geometry = DragTrackGeometry(
    widget.track,
    scale: widget.pathScale,
  );

  /// Takes the arrow keys when the track has a [DragTrackModel.keyStep].
  final FocusNode _focus = FocusNode(debugLabel: 'drag track');

  /// Whether this drag maps the pointer straight to the track (an arc with
  /// [DragTrackModel.jumpOnTap]) rather than by how far it moved.
  bool _absolute = false;

  /// The unsnapped progress while dragging.
  double _raw = 0;

  /// The value shown while dragging, ahead of the variable catching up.
  double? _dragValue;
  double? _lastAngle;
  Offset _grab = Offset.zero;
  Size _size = Size.zero;

  late final PanGestureRecognizer _pan = PanGestureRecognizer()
    ..dragStartBehavior = DragStartBehavior.down
    ..onStart = _onStart
    ..onUpdate = _onUpdate
    ..onEnd = ((_) => _onEnd())
    ..onCancel = _onEnd;
  late final DoubleTapGestureRecognizer _doubleTap =
      DoubleTapGestureRecognizer()..onDoubleTap = _onDoubleTap;

  @override
  void didUpdateWidget(NodeDragTrack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.track != widget.track ||
        oldWidget.pathScale != widget.pathScale) {
      _geometry = DragTrackGeometry(widget.track, scale: widget.pathScale);
    }
  }

  @override
  void dispose() {
    _pan.dispose();
    _doubleTap.dispose();
    _focus.dispose();
    super.dispose();
  }

  DragTrackModel get _track => widget.track;
  double get _shownValue => _dragValue ?? widget.value;
  double get _progress => _track.progressOf(_shownValue);

  /// [local] (in the node's untransformed box) relative to the rest centre.
  Offset _rel(Offset local) => local - _size.center(Offset.zero);

  void _emit(double raw) {
    _raw = raw.clamp(0.0, 1.0);
    final double v = _track.valueAt(_raw);
    if (v != _shownValue) {
      setState(() => _dragValue = v);
      widget.onChanged(v);
    }
  }

  void _pointerDown(PointerDownEvent event, Offset local, bool onNode) {
    if (!widget.enabled) return;
    if (_track.effectiveKeyStep != null) _focus.requestFocus();
    final bool jumps =
        _track.jumpOnTap && _track.input == DragTrackInput.follow;
    _absolute = jumps && _track.shape == DragTrackShape.arc;
    if (jumps && (!onNode || _absolute)) {
      // Pressed the track off the node (or anywhere round an arc): jump
      // there, then drag from there.
      _raw = _progress;
      _emit(_geometry.jumpProgressAt(_rel(local)));
    }
    _pan.addPointer(event);
    _doubleTap.addPointer(event);
  }

  void _onStart(DragStartDetails d) {
    final Offset p = _rel(d.localPosition);
    setState(() {
      _dragValue = _shownValue;
      _raw = _progress;
    });
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
      case DragTrackInput.both:
        _emit(_raw + (d.delta.dx - d.delta.dy) / _track.pixelsPerRange);
      case DragTrackInput.follow:
        if (_absolute) {
          _emit(_geometry.arcProgressAt(p));
        } else if (_track.shape == DragTrackShape.arc) {
          final Offset fromPivot = p - Offset(_track.pivotX, _track.pivotY);
          if (fromPivot.distance < _size.shortestSide * 0.12) {
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
          _emit(_geometry.nearest(p + _grab));
        }
    }
  }

  void _onEnd() {
    final double v = _shownValue;
    widget.onEnd?.call(v);
    // Hold the dragged value until the variable has caught up.
    setState(() => _dragValue = null);
  }

  void _onDoubleTap() {
    if (!widget.enabled) return;
    final double? v = _track.doubleTapTarget(widget.value);
    if (v == null) return;
    _set(v);
  }

  /// Reports [v] as a whole change: a wheel notch, a key, a double tap.
  void _set(double v) {
    if (v == widget.value) return;
    widget.onChanged(v);
    widget.onEnd?.call(v);
  }

  /// The value [steps] steps of [size] toward [DragTrackModel.max].
  double _stepped(double size, int steps) {
    final double up = _track.max >= _track.min ? 1 : -1;
    return _track.snap(widget.value + steps * up * size);
  }

  void _onWheel(PointerScrollEvent event) {
    if (!_track.wheel || !widget.enabled) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (e) {
      final PointerScrollEvent s = e as PointerScrollEvent;
      if (s.scrollDelta.dy == 0) return;
      _set(
        _stepped(_track.effectiveWheelStep, s.scrollDelta.dy < 0 ? 1 : -1),
      );
    });
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final double? step = _track.effectiveKeyStep;
    if (step == null || !widget.enabled) return KeyEventResult.ignored;
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

  @override
  Widget build(BuildContext context) {
    final double progress = _progress;
    Widget node = MouseRegion(
      cursor: widget.enabled
          ? (_dragValue != null
                ? SystemMouseCursors.grabbing
                : SystemMouseCursors.grab)
          : MouseCursor.defer,
      child: widget.child,
    );
    if (_track.effectiveKeyStep != null) {
      // Inside the track area, whose hit test reaches past the node's box.
      node = Focus(
        focusNode: _focus,
        canRequestFocus: widget.enabled,
        onKeyEvent: _onKey,
        child: node,
      );
    }
    final Widget area = _TrackArea(
      geometry: _geometry,
      progress: progress,
      jumpOnTap: _track.jumpOnTap,
      hitAreaBox: _track.hitArea == DragTrackHitArea.parent
          ? widget.hitAreaBox
          : null,
      onSize: (size) => _size = size,
      onPointerDown: _pointerDown,
      onWheel: _onWheel,
      child: node,
    );
    return TrackScope(
      values: TrackValues(
        value: _shownValue,
        progress: progress,
        dragging: _dragValue != null,
      ),
      child: area,
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
