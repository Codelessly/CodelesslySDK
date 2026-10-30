import 'dart:math' as math;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
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

/// Makes [child] a value control that moves along [track]: it is drawn at
/// [value]'s place on the track, and dragging it (or, with
/// [DragTrackModel.jumpOnTap], tapping along the track) reports new values
/// through [onChanged]. Double tap resets to [DragTrackModel.defaultValue];
/// the mouse wheel steps the value.
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
  });

  /// The track.
  final DragTrackModel track;

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
  late DragTrackGeometry _geometry = DragTrackGeometry(widget.track);

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
    if (oldWidget.track != widget.track) {
      _geometry = DragTrackGeometry(widget.track);
    }
  }

  @override
  void dispose() {
    _pan.dispose();
    _doubleTap.dispose();
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
    setState(() {
      _dragValue = widget.value;
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
      case DragTrackInput.follow:
        if (_track.shape == DragTrackShape.arc) {
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
    final double? reset = _track.defaultValue;
    if (reset == null || !widget.enabled) return;
    final double v = _track.snap(reset);
    widget.onChanged(v);
    widget.onEnd?.call(v);
  }

  void _onWheel(PointerScrollEvent event) {
    if (!_track.wheel || !widget.enabled) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (e) {
      final PointerScrollEvent s = e as PointerScrollEvent;
      final double dir = s.scrollDelta.dy < 0 ? 1 : -1;
      final double up = _track.max >= _track.min ? 1 : -1;
      final double v = _track.snap(widget.value + dir * up * _track.wheelStep);
      if (v != widget.value) {
        widget.onChanged(v);
        widget.onEnd?.call(v);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final double progress = _progress;
    return TrackScope(
      values: TrackValues(
        value: _shownValue,
        progress: progress,
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
