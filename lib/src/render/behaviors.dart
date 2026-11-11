// A node's behaviors as layers of its render chain (see node_tree.dart's
// outer layers). Outermost first:
//
//   constraints → track pose → transform gesture → motion → scale → rotation → [ignore pointer]
//   → loops → opacity → blurs → stroke path → content
//
// The design canvas (a tree that doesn't animate) draws each at rest: the
// motion's values, the first frame of each loop, a track at its variable's
// value. A running app plays them (tickers in the render objects).
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_api/codelessly_api.dart' show Node;
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import 'convert.dart';
import 'drag_track.dart';
import 'flip_card.dart';
import 'transform_gesture.dart';
import 'node_tree.dart' show NodeBox;
import 'paint/svg_path.dart';
import '../runtime/actions/wiring.dart' show visibleShare;
import 'recipe.dart';

/// Track pose, motion and scale: the layers between the constraints and
/// the rotation.
void motionLayers(NodeBuilder b, Node n, List<RenderBox> chain, {required bool animates}) {
  final be = n.behaviors;
  if (be.drag?.track case final api.DragTrack track) {
    // At its value (`drag.track.value`, else its variable's, else its
    // default or start; parked when out of range or empty), and in a
    // running app dragged along the track (render/drag_track.dart).
    final box = b is NodeBox ? b : null;
    final reads = track.value == null && track.hasVariable && box?.tree.binder?.scope != null;
    final p = track.restProgressOf(track.value ?? track.defaultValue ?? track.min);
    final moves = animates ||
        reads ||
        track.parkedProgress != null ||
        track.relative ||
        track.units == api.DragTrackUnits.parent ||
        track.usesViewBox ||
        trackPose(track, p) != null;
    if (moves) {
      chain.add(
        b.obtain<RenderDragTrack>('trackPose', RenderDragTrack.new)
          ..configure(box, track, enabled: be.drag!.enabled, interactive: animates),
      );
    }
  }
  // Pinch, pan and rotate in a running app (render/transform_gesture.dart),
  // inside the track.
  if (animates && n.type != 'canvas') {
    if (be.effectiveTransformGesture case final api.TransformGesture gesture) {
      chain.add(
        b.obtain<RenderTransformGesture>('transformGesture', RenderTransformGesture.new)
          ..configure(b is NodeBox ? b : null, gesture),
      );
    }
  }
  if (be.motion case final api.Motion motion) {
    chain.add(
      b.obtain<RenderMotion>('motion', RenderMotion.new)
        ..animates = animates
        ..motion = motion,
    );
    if (motion.shimmer case final api.MotionShimmer shimmer) {
      chain.add(
        b.obtain<RenderShimmer>('shimmer', RenderShimmer.new)
          ..animates = animates
          ..shimmer = shimmer,
      );
    }
  }
  cardLayers(b, n, chain, animates: animates);
  if (be.scale != 1) {
    chain.add(
      b.obtain<RenderPose>('scale', RenderPose.new)
        ..transform = Matrix4.diagonal3Values(be.scale, be.scale, 1)
        ..origin = Alignment.center,
    );
  }
}

/// Loops, between the rotation and the opacity.
void loopLayers(NodeBuilder b, Node n, List<RenderBox> chain, {required bool animates}) {
  final be = n.behaviors;
  if (be.ignorePointer && animates) chain.add(b.obtain<RenderIgnorePointer>('ignorePointer', RenderIgnorePointer.new));
  // Pointer states a running app tracks (hover and press), for the node's
  // state styles and ink.
  final states = be.states.patches.keys;
  final tracksHover = be.inkWell != null || states.contains(api.WidgetState.hovered);
  final tracksPress = be.inkWell != null || states.contains(api.WidgetState.pressed);
  if (animates && tracksHover) {
    void hover(bool on) => b.tree.setState(b.id, api.WidgetState.hovered, on, instance: b.instance);
    chain.add(
      b.obtain<RenderMouseRegion>('hover', RenderMouseRegion.new)
        ..onEnter = ((_) => hover(true))
        ..onExit = ((_) => hover(false)),
    );
  }
  if (animates && tracksPress) {
    void press(bool on) => b.tree.setState(b.id, api.WidgetState.pressed, on, instance: b.instance);
    chain.add(
      b.obtain<RenderPointerListener>('press', RenderPointerListener.new)
        ..onPointerDown = ((_) => press(true))
        ..onPointerUp = ((_) => press(false))
        ..onPointerCancel = ((_) => press(false)),
    );
  }
  if (be.loops.isNotEmpty) {
    chain.add(
      b.obtain<RenderLoops>('loops', RenderLoops.new)
        ..animates = animates
        ..loops = be.loops,
    );
  }
}

/// Blurs and the stroke path, inside the opacity, around the content.
void paintLayers(NodeBuilder b, Node n, List<RenderBox> chain) {
  double layer = 0, background = 0;
  for (final e in n.decoration.effects) {
    if (!e.visible || e.blurRadius <= 0) continue;
    if (e.type == api.EffectType.layerBlur) layer = math.max(layer, e.blurRadius);
    if (e.type == api.EffectType.backgroundBlur) background = math.max(background, e.blurRadius);
  }
  if (background > 0) {
    // Frosted glass: what's behind, clipped to the corners.
    chain.add(
      b.obtain<RenderClipRRect>('backdropClip', () => RenderClipRRect(clipBehavior: Clip.antiAlias))
        ..borderRadius = n.decoration.radius.flutter,
    );
    chain.add(
      b.obtain<RenderBackdropFilter>(
        'backdrop',
        () => RenderBackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: background, sigmaY: background),
        ),
      )..filter = ui.ImageFilter.blur(sigmaX: background, sigmaY: background),
    );
  }
  if (layer > 0) {
    chain.add(
      b.obtain<RenderImageFilter>('layerBlur', RenderImageFilter.new)
        ..filter = ui.ImageFilter.blur(sigmaX: layer, sigmaY: layer),
    );
  }
  if (n.behaviors.strokePath case final api.StrokePath path) {
    final painter = StrokePathPainter(path);
    chain.add(
      b.obtain<RenderCustomPaint>('strokePath', RenderCustomPaint.new)
        ..painter = path.inFront ? null : painter
        ..foregroundPainter = path.inFront ? painter : null,
    );
  }
}

/// The ink a running app shows over a box's paint, under its content: the
/// overlay of its current hover, focus or press state.
RenderBox inkOverlay(NodeBuilder b, Node n, BorderRadius? radius) {
  final ink = n.behaviors.inkWell!;
  final active = b.tree.statesOf(b.id, instance: b.instance);
  api.Color? color;
  for (final s in const [api.WidgetState.pressed, api.WidgetState.hovered, api.WidgetState.focused]) {
    if (active.contains(s)) {
      color = ink.colorFor(s);
      break;
    }
  }
  return b.obtain<RenderInkOverlay>('ink', RenderInkOverlay.new)
    ..color = color?.flutter
    ..radius = radius;
}

/// Paints the [color] of a box's ink state over its size.
class RenderInkOverlay extends RenderBox {
  Color? _color;
  set color(Color? v) {
    if (v == _color) return;
    _color = v;
    markNeedsPaint();
  }

  BorderRadius? _radius;
  set radius(BorderRadius? v) {
    if (v == _radius) return;
    _radius = v;
    markNeedsPaint();
  }

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      constraints.biggest.isFinite ? constraints.biggest : constraints.smallest;

  @override
  void paint(PaintingContext context, Offset offset) {
    final color = _color;
    if (color == null || color.a == 0) return;
    final rect = offset & size;
    final paint = Paint()..color = color;
    if (_radius == null) {
      context.canvas.drawRect(rect, paint);
    } else {
      context.canvas.drawRRect(_radius!.toRRect(rect), paint);
    }
  }
}

/// Where a [api.DragTrack] puts its node, in the node's coordinates with
/// the origin at its rest center: a line,
/// an arc about its pivot, or a path, measured in pixels, in the node's own
/// size ([api.DragTrack.relative]), in its parent's
/// ([api.DragTrackUnits.parent]) or in a viewBox stretched to the parent
/// ([api.DragTrack.usesViewBox]).
class TrackGeometry {
  TrackGeometry(this.track, {this.size = Size.zero, this.parent, this.rest = Offset.zero});

  final api.DragTrack track;

  /// The node's size, the parent's (null unknown), and the node's rest
  /// center in the parent (for a viewBox).
  final Size size;
  final Size? parent;
  final Offset rest;

  bool get _inParent => track.units == api.DragTrackUnits.parent && parent != null;
  bool get _inViewBox => track.usesViewBox && parent != null;

  /// A length along x or y in pixels.
  double _x(double v) => _inParent ? v * parent!.width : v;
  double _y(double v) => _inParent ? v * parent!.height : v;

  Offset get _lineStart => track.relative
      ? Offset(track.x1 * size.width, track.y1 * size.height)
      : Offset(_x(track.x1), _y(track.y1));
  Offset get _lineEnd => track.relative
      ? Offset(track.x2 * size.width, track.y2 * size.height)
      : Offset(_x(track.x2), _y(track.y2));

  double _angle(double p) => track.startAngle + (track.endAngle - track.startAngle) * p;

  /// A path point (relative to the path's start) as an offset from rest.
  Offset _place(Offset point, Offset start) {
    if (_inViewBox) {
      final sx = parent!.width / track.viewBoxWidth, sy = parent!.height / track.viewBoxHeight;
      return Offset((point.dx + start.dx) * sx, (point.dy + start.dy) * sy) - rest;
    }
    return Offset(_x(point.dx), _y(point.dy));
  }

  /// Where the node's center sits at [progress], from rest. A line or arc
  /// goes on past its ends (overscroll, a parked node); a path stops there.
  Offset offsetAt(double progress) {
    switch (track.shape) {
      case api.DragTrackShape.line:
        return Offset.lerp(_lineStart, _lineEnd, progress)!;
      case api.DragTrackShape.arc:
        // Round the pivot, on a circle through rest.
        final pivot = Offset(_x(track.pivotX), _y(track.pivotY));
        if (pivot == Offset.zero) return Offset.zero;
        final a = _angle(progress) * math.pi / 180;
        final r = -pivot;
        return pivot + Offset(r.dx * math.cos(a) - r.dy * math.sin(a), r.dx * math.sin(a) + r.dy * math.cos(a));
      case api.DragTrackShape.path:
        final path = track.path == null ? null : MeasuredPath.of(track.path!);
        if (path == null) return Offset.zero;
        final p = track.clampProgress(progress);
        if (_inViewBox) return _alongStretched(path, p);
        return _place(path.at(p)?.$1 ?? Offset.zero, path.start);
    }
  }

  /// [p] of the way along the path as stretched into the viewBox, by its
  /// stretched length.
  Offset _alongStretched(MeasuredPath path, double p) {
    const n = 240;
    final samples = [
      for (var i = 0; i <= n; i++)
        if (path.at(i / n) case final at?) _place(at.$1, path.start),
    ];
    if (samples.isEmpty) return Offset.zero;
    var total = 0.0;
    for (var i = 1; i < samples.length; i++) {
      total += (samples[i] - samples[i - 1]).distance;
    }
    var d = p * total;
    for (var i = 1; i < samples.length; i++) {
      final seg = (samples[i] - samples[i - 1]).distance;
      if (d <= seg && seg > 0) return Offset.lerp(samples[i - 1], samples[i], d / seg)!;
      d -= seg;
    }
    return samples.last;
  }

  /// How much the node turns at [progress] (degrees).
  double rotationAt(double progress) {
    switch (track.shape) {
      case api.DragTrackShape.line:
        return 0;
      case api.DragTrackShape.arc:
        return track.rotate ? _angle(progress) : 0;
      case api.DragTrackShape.path:
        if (!track.orientToPath || track.path == null) return 0;
        final at = MeasuredPath.of(track.path!)?.at(track.clampProgress(progress));
        if (at == null) return 0;
        var angle = at.$2;
        // A path stretched unevenly turns as drawn.
        if (_inParent && !_inViewBox && parent!.width != parent!.height) {
          angle = math.atan2(math.sin(angle) * parent!.height, math.cos(angle) * parent!.width);
        }
        return (track.orientUpright ? api.Motion.uprightAngle(angle) : angle) * 180 / math.pi;
    }
  }

  /// The move and turn about the node's center at [progress]; null at rest.
  Matrix4? poseAt(double progress) {
    final o = offsetAt(progress);
    final r = rotationAt(progress);
    if (o == Offset.zero && r == 0) return null;
    return Matrix4.translationValues(o.dx, o.dy, 0)..rotateZ(r * math.pi / 180);
  }
}

/// Where [track] puts its node at [progress] (in pixels; see
/// [TrackGeometry] for a track measured in its node or parent): a move (and
/// a turn) about its center. Null at its place.
Matrix4? trackPose(api.DragTrack track, double progress) => TrackGeometry(track).poseAt(progress);

/// A node drawn where its [api.DragTrack] puts it at [progress], worked out
/// from its laid-out size and its parent's.
class RenderTrackPose extends RenderPose {
  api.DragTrack _track = const api.DragTrack();
  api.DragTrack get track => _track;
  set track(api.DragTrack v) {
    if (v == _track) return;
    _track = v;
    markNeedsPaint();
  }

  double _progress = 0;
  double get progress => _progress;
  set progress(double v) {
    if (v == _progress) return;
    _progress = v;
    markNeedsPaint();
  }

  /// Whether the pose needs the parent's size and the node's place in it.
  bool get _measuresParent => _track.units == api.DragTrackUnits.parent || _track.usesViewBox;

  /// The box this node sits in (its parent's layout), and where this
  /// node's center is in it.
  (Size, Offset)? _frame() {
    RenderObject? o = parent;
    while (o != null && o is! NodeBuilder) {
      o = o.parent;
    }
    final frame = o?.parent;
    if (frame is! RenderBox || !frame.hasSize || !hasSize) return null;
    try {
      return (frame.size, MatrixUtils.transformPoint(getTransformTo(frame), size.center(Offset.zero)));
    } catch (_) {
      return (frame.size, Offset.zero);
    }
  }

  /// Works the pose out from the sizes now (while painting or hit
  /// testing: set without marking), and gives the geometry it used.
  TrackGeometry pose() {
    final frame = _measuresParent ? _frame() : null;
    final geometry = TrackGeometry(
      _track,
      size: hasSize ? size : Size.zero,
      parent: frame?.$1,
      rest: frame?.$2 ?? Offset.zero,
    );
    _transform = geometry.poseAt(_progress) ?? Matrix4.identity();
    _origin = Alignment.center;
    return geometry;
  }

  void _pose() => pose();

  @override
  void paint(PaintingContext context, Offset offset) {
    _pose();
    super.paint(context, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    _pose();
    return super.hitTestChildren(result, position: position);
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    _pose();
    super.applyPaintTransform(child, transform);
  }
}

/// A pose drawn over the layout (Flutter's `Transform`, plus a fractional
/// shift, opacity and blur): [transform] about [origin] in the box, then
/// moved by [shift] times the box's size. Hit testing follows it.
class RenderPose extends RenderProxyBox {
  RenderPose();

  Matrix4 _transform = Matrix4.identity();
  set transform(Matrix4 v) {
    if (v == _transform) return;
    _transform = v;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  Alignment _origin = Alignment.center;
  set origin(Alignment v) {
    if (v == _origin) return;
    _origin = v;
    markNeedsPaint();
  }

  Offset _shift = Offset.zero;
  set shift(Offset v) {
    if (v == _shift) return;
    _shift = v;
    markNeedsPaint();
  }

  double _opacity = 1;
  set opacity(double v) {
    if (v == _opacity) return;
    _opacity = v;
    markNeedsPaint();
  }

  double _blur = 0;
  set blur(double v) {
    if (v == _blur) return;
    _blur = v;
    markNeedsPaint();
  }

  /// Hidden while its back faces the viewer (through every transform above).
  bool _backfaceHidden = false;
  set backfaceHidden(bool v) {
    if (v == _backfaceHidden) return;
    _backfaceHidden = v;
    markNeedsPaint();
  }

  bool get _moved => _shift != Offset.zero || !_transform.isIdentity();

  /// The transform from the child to this box.
  Matrix4 get effectiveTransform {
    final o = _origin.alongSize(size);
    return Matrix4.translationValues(_shift.dx * size.width + o.dx, _shift.dy * size.height + o.dy, 0)
      ..multiply(_transform)
      ..multiply(Matrix4.translationValues(-o.dx, -o.dy, 0));
  }

  final LayerHandle<TransformLayer> _transformLayer = LayerHandle();
  final LayerHandle<OpacityLayer> _opacityLayer = LayerHandle();
  final LayerHandle<ImageFilterLayer> _blurLayer = LayerHandle();

  bool get _faces {
    if (!_backfaceHidden || !attached) return true;
    try {
      // Through every transform above, and its own (what its child is drawn
      // with: a card's back turned over in advance).
      final full = getTransformTo(null);
      if (_moved) full.multiply(effectiveTransform);
      final m = full.storage;
      Offset project(double x, double y) {
        final w = m[3] * x + m[7] * y + m[15];
        final d = w == 0 ? 1e-9 : w;
        return Offset((m[0] * x + m[4] * y + m[12]) / d, (m[1] * x + m[5] * y + m[13]) / d);
      }

      final w = size.width <= 0 ? 1.0 : size.width, h = size.height <= 0 ? 1.0 : size.height;
      final a = project(0, 0), b = project(w, 0), c = project(0, h);
      return (b.dx - a.dx) * (c.dy - a.dy) - (b.dy - a.dy) * (c.dx - a.dx) > 0;
    } catch (_) {
      return true;
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null || _opacity <= 0 || !_faces) {
      _transformLayer.layer = null;
      _opacityLayer.layer = null;
      _blurLayer.layer = null;
      return;
    }
    void content(PaintingContext context, Offset offset) {
      if (_opacity < 1) {
        _opacityLayer.layer = context.pushOpacity(
          offset,
          (_opacity * 255).round(),
          super.paint,
          oldLayer: _opacityLayer.layer,
        );
      } else {
        _opacityLayer.layer = null;
        super.paint(context, offset);
      }
    }

    void blurred(PaintingContext context, Offset offset) {
      if (_blur > 0) {
        final layer = _blurLayer.layer ??= ImageFilterLayer();
        layer
          ..imageFilter = ui.ImageFilter.blur(sigmaX: _blur, sigmaY: _blur)
          ..offset = offset;
        context.pushLayer(layer, content, Offset.zero);
      } else {
        _blurLayer.layer = null;
        content(context, offset);
      }
    }

    if (_moved) {
      _transformLayer.layer = context.pushTransform(
        needsCompositing,
        offset,
        effectiveTransform,
        blurred,
        oldLayer: _transformLayer.layer,
      );
    } else {
      _transformLayer.layer = null;
      blurred(context, offset);
    }
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    if (_moved) transform.multiply(effectiveTransform);
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (_opacity <= 0 || !_faces) return false;
    return hitTestChildren(result, position: position);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final child = this.child;
    if (child == null) return false;
    if (!_moved) return child.hitTest(result, position: position);
    return result.addWithPaintTransform(
      transform: effectiveTransform,
      position: position,
      hitTest: (result, position) => child.hitTest(result, position: position),
    );
  }

  @override
  void dispose() {
    _transformLayer.layer = null;
    _opacityLayer.layer = null;
    _blurLayer.layer = null;
    super.dispose();
  }
}

/// Runs a [Ticker] while attached and [ticking].
mixin _Ticking on RenderPose {
  Ticker? _ticker;

  bool get ticking;
  void tick(Duration elapsed);

  void syncTicker() {
    if (attached && ticking) {
      _ticker ??= Ticker(tick);
      if (!_ticker!.isActive) _ticker!.start();
    } else if (_ticker?.isActive ?? false) {
      _ticker!.stop();
    }
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    syncTicker();
  }

  @override
  void detach() {
    _ticker?.stop();
    super.detach();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _ticker = null;
    super.dispose();
  }
}

/// A node's [api.LoopAnimation]s, combined. At rest (the design canvas) it
/// draws each loop's first frame.
class RenderLoops extends RenderPose with _Ticking {
  List<api.LoopAnimation> _loops = const [];
  set loops(List<api.LoopAnimation> v) {
    if (api.jsonEquality.equals(v, _loops)) return;
    _loops = v;
    _ticker?.stop();
    _show(Duration.zero);
    syncTicker();
  }

  bool _animates = false;
  set animates(bool v) {
    if (v == _animates) return;
    _animates = v;
    _show(Duration.zero);
    syncTicker();
  }

  @override
  bool get ticking => _animates && _loops.any((l) => l.enabled);

  @override
  void tick(Duration elapsed) => _show(elapsed);

  /// The run phase (0–1) of [l] [elapsed] after it started: from its
  /// [api.LoopAnimation.startFraction] of a whole loop, after its delay.
  static double phase(api.LoopAnimation l, Duration elapsed) {
    final ms = math.max(0.0, elapsed.inMicroseconds / 1000 - l.delay);
    final d = math.max(1, l.duration);
    final runs = ms / d + l.startFraction * (l.reverse ? 2 : 1);
    final f = runs - runs.floorToDouble();
    return l.reverse && runs.floor().isOdd ? 1 - f : f;
  }

  void _show(Duration elapsed) {
    var m = Matrix4.identity();
    var opacity = 1.0;
    for (final l in _loops) {
      final p = l.poseAt(phase(l, elapsed));
      m = m
        ..translateByDouble(0, p.dy, 0, 1)
        ..scaleByDouble(p.scale, p.scale, 1, 1)
        ..rotateZ(p.turns * 2 * math.pi);
      opacity *= p.opacity;
    }
    transform = m;
    origin = Alignment.center;
    this.opacity = opacity.clamp(0.0, 1.0);
  }
}

/// A node's [api.Motion]. At rest (the design canvas) it draws its values;
/// a running app plays its entrance, loop and spin, and transitions to new
/// values when they change.
class RenderMotion extends RenderPose with _Ticking {
  /// The size of the node's parent node (the second node box above it), for
  /// a path in a viewBox; null before layout.
  Size? _parentSize() {
    var boxes = 0;
    for (var p = parent; p != null; p = p.parent) {
      if (p is NodeBox) {
        boxes++;
        if (boxes == 2) {
          final b = p.contentBox ?? p;
          return b.hasSize ? b.size : null;
        }
      }
    }
    return null;
  }

  api.Motion _motion = api.Motion.none;
  bool _animates = false;
  bool _entered = false;
  bool _waitingForReveal = false;

  /// The running transition: from [_from] to [_to] since [_since] (its
  /// delay not yet counted), [_offset] ms into its run (a loop's phase).
  api.Motion? _from;
  api.Motion _to = api.Motion.none;
  Duration _since = Duration.zero;
  double _offset = 0;
  int _runs = 0;

  /// Whether the loop's current run goes from its values back to its start.
  bool _backward = false;

  /// The motion's own time: the ticker's, less what it spent paused.
  Duration _clock = Duration.zero;

  /// The pose drawn last (a new transition starts there).
  api.Motion _shown = api.Motion.none;
  double _turns = 0, _speed = 0;
  Duration _lastTick = Duration.zero;

  /// Where the node last was on its path and the way it moved, for
  /// [api.Motion.orientToPath] under keyframes that push it off the path.
  Offset? _lastPathPosition;
  double? _pathHeading;

  set animates(bool v) {
    if (v == _animates) return;
    _animates = v;
    _from = null;
    _show();
    syncTicker();
  }

  set motion(api.Motion v) {
    if (v == _motion) return;
    final old = _motion;
    _motion = v;
    if (_animates && _entered && _loops(v)) {
      if (!_loops(old) ||
          old.loop != v.loop ||
          old.repeat != v.repeat ||
          old.duration != v.duration ||
          old.phase != v.phase ||
          _from == null && !_samePose(old, v)) {
        _startLoop();
      } else if (_from != null) {
        // The loop runs on (or holds, paused) toward the new values.
        _setLoopEnds();
      }
    } else {
      _to = v;
      if (_animates && _entered && !_samePose(old, v) && _transitionMs(v) > 0) {
        _start(_shown, v, at: _clock);
      }
    }
    _show();
    syncTicker();
  }

  static bool _loops(api.Motion m) => m.loop != api.MotionLoop.none && m.duration > 0;

  static bool _samePose(api.Motion a, api.Motion b) =>
      api.Motion.properties.every((p) => p == 'spin' || a.valueOf(p) == b.valueOf(p)) && a.path == b.path;

  static int _transitionMs(api.Motion m) => m.curve == api.AnimationCurve.spring ? 1 : m.duration;

  void _start(api.Motion from, api.Motion to, {required Duration at, double offset = 0}) {
    _from = from;
    _to = to;
    _since = at;
    _offset = offset;
  }

  /// Starts the loop over, at its phase.
  void _startLoop() {
    final m = _motion;
    _runs = 0;
    _backward = false;
    final phase = m.phase.isFinite ? m.phase - m.phase.floorToDouble() : 0.0;
    _start(m.loopStart, m, at: _clock, offset: phase * m.duration);
  }

  void _setLoopEnds() {
    final start = _motion.loopStart;
    _from = _backward ? _motion : start;
    _to = _backward ? start : _motion;
  }

  @override
  void attach(PipelineOwner owner) {
    if (!_entered && _animates) {
      final m = _motion;
      _waitingForReveal = m.revealOnScroll && m.hasEntrance;
      if (_loops(m)) {
        _startLoop();
      } else if (m.hasEntrance && _transitionMs(m) > 0) {
        _start(m.entranceStart, m, at: _clock);
      }
      _entered = !_waitingForReveal;
    }
    super.attach(owner);
    _show();
    if (_waitingForReveal) _MotionRevealWatcher.add(this);
  }

  void _checkReveal() {
    if (!attached || !hasSize || !_waitingForReveal) return;
    final share = visibleShare(this);
    if (share <= 0 || share < _motion.revealFraction.clamp(0.0, 1.0)) return;
    _waitingForReveal = false;
    _entered = true;
    _since = _clock;
    _MotionRevealWatcher.remove(this);
    _show();
    syncTicker();
  }

  /// A path in a viewBox follows the parent's size: placed again once laid
  /// out (the parent has its size by then).
  Size? _stage;
  @override
  void performLayout() {
    super.performLayout();
    if (_motion.hasPath && _motion.pathViewBox.length >= 2) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!attached) return;
        final stage = _parentSize();
        if (stage != null && stage != _stage) {
          _stage = stage;
          _show();
        }
      });
    }
  }

  @override
  void detach() {
    _MotionRevealWatcher.remove(this);
    super.detach();
  }

  @override
  void dispose() {
    _MotionRevealWatcher.remove(this);
    super.dispose();
  }

  @override
  bool get ticking => _animates && !_waitingForReveal && ((!_motion.paused && (_from != null || _motion.spin != 0)) || _speed != 0);

  @override
  void tick(Duration elapsed) {
    if (elapsed < _lastTick) _lastTick = Duration.zero;
    final step = elapsed - _lastTick;
    final dt = step.inMicroseconds / 1e6;
    _lastTick = elapsed;
    // A paused motion holds its time; its spin winds down.
    if (!_motion.paused) _clock += step;
    final target = _motion.paused ? 0.0 : _motion.spin;
    if (_speed != target) {
      final perSecond = _motion.spinRamp <= 0
          ? double.infinity
          : math.max(target.abs(), _speed.abs()) / (_motion.spinRamp / 1000);
      final change = math.min((target - _speed).abs(), perSecond * dt);
      _speed += (target - _speed).sign * change;
      if ((target - _speed).abs() < 0.002) _speed = target;
    }
    _turns = (_turns + _speed * dt) % 1;
    _show();
    if (!ticking) _ticker?.stop();
  }

  double _eased(double ms) {
    final m = _motion;
    if (m.curve == api.AnimationCurve.spring) {
      final spring = SpringDescription(
        mass: 1,
        stiffness: m.springStiffness <= 0 ? 380 : m.springStiffness,
        damping: m.springDamping < 0 ? 20 : m.springDamping,
      );
      final sim = SpringSimulation(spring, 0, 1, 0);
      final t = ms / 1000;
      return sim.isDone(t) ? 1 : sim.x(t);
    }
    return m.curve.transform(ms / math.max(1, m.duration));
  }

  void _show() {
    var m = _motion;
    final from = _from;
    var moving = false;
    if (_animates && from != null) {
      moving = true;
      var ms = (_clock - _since).inMicroseconds / 1000 - m.delay;
      ms = math.max(0.0, ms) + _offset;
      final bool done;
      if (m.loop == api.MotionLoop.swing && _loops(m)) {
        // Around rest on a sine, linear in time.
        final runs = ms / math.max(1, m.duration);
        done = runs >= 1;
        m = swingPose(from, _to, done ? 0 : math.sin(2 * math.pi * runs));
      } else {
        final t = ms <= 0 ? 0.0 : _eased(ms);
        done = ms > 0 && (m.curve == api.AnimationCurve.spring ? t == 1 : ms >= m.duration);
        m = _between(from, _to, done ? 1 : t);
      }
      if (done) {
        if (_loops(_motion) && (_motion.repeat == 0 || ++_runs < _motion.repeat)) {
          // The next run, without the delay: again, or back.
          final next = _clock - Duration(milliseconds: _motion.delay);
          if (_motion.loop == api.MotionLoop.reverse) _backward = !_backward;
          _start(_from!, _to, at: next);
          _setLoopEnds();
        } else {
          // A counted loop that's done rests.
          if (_loops(_motion)) m = _motion.atRest;
          _from = null;
        }
      }
    }
    _shown = m;
    var shown = m;
    if (m.hasPath) {
      final progress = m.pathWrap ? api.Motion.wrapProgress(m.pathProgress) : m.pathProgress;
      final measured = MeasuredPath.of(m.path!);
      final at = measured?.at(
        progress,
        byArea: m.pathPacing == api.MotionPathPacing.area,
        focus: Offset(m.pathFocusX, m.pathFocusY),
      );
      if (at != null) {
        // A path in a viewBox is stretched over the node's parent.
        var point = at.$1;
        var heading = at.$2;
        final stage = m.pathViewBox.length >= 2 ? _parentSize() : null;
        if (stage != null && m.pathViewBox[0] > 0 && m.pathViewBox[1] > 0) {
          // In a viewBox the path is placed over the parent: its points are
          // where the node goes (from the parent's origin), not offsets from
          // the path's start, so the node is laid out at the origin.
          final sx = stage.width / m.pathViewBox[0], sy = stage.height / m.pathViewBox[1];
          final absolute = point + measured!.start;
          point = Offset(absolute.dx * sx, absolute.dy * sy);
          heading = math.atan2(math.sin(heading) * sy, math.cos(heading) * sx);
        }
        final total = Offset(m.translateX + point.dx, m.translateY + point.dy);
        // Keyframes that push the node off its path turn it too: its nose
        // follows where it actually goes.
        final pushed =
            m.orientToPath && moving && m.keyframes.any((k) => k.translateX != null || k.translateY != null);
        if (pushed) {
          final previous = _lastPathPosition;
          if (previous != null && (total - previous).distance > 0.25) _pathHeading = (total - previous).direction;
          _lastPathPosition = total;
          heading = _pathHeading ?? heading;
        } else {
          _lastPathPosition = null;
          _pathHeading = null;
        }
        final turn = m.orientUpright ? api.Motion.uprightAngle(heading) : heading;
        shown = shown
            .withValue('translateX', total.dx)
            .withValue('translateY', total.dy)
            .withValue('rotate', m.orientToPath ? m.rotate + turn * 180 / math.pi : m.rotate);
      }
    }
    transform = motionMatrix(shown, spinTurns: _turns);
    origin = Alignment(shown.originX, shown.originY);
    shift = Offset(shown.shiftX, shown.shiftY);
    opacity = shown.opacity;
    blur = shown.blur;
    backfaceHidden = shown.backfaceHidden;
  }

  /// [t] (eased) of the way from [a] to [b]: bent by [api.Motion.arc], the
  /// short way round a [api.Motion.pathWrap] path.
  static api.Motion _between(api.Motion a, api.Motion b, double t) {
    var m = api.Motion.lerp(a, b, t);
    if (b.arc != 0) {
      // On a quadratic curve whose middle is `arc` of the distance off the
      // line, to the right of the way it goes: (-dy, dx) · arc · 2t(1 − t).
      final bend = b.arc * 2 * t * (1 - t);
      for (final (x, y) in const [('translateX', 'translateY'), ('shiftX', 'shiftY')]) {
        if (b.keyframes.any((k) => k.valueOf(x) != null || k.valueOf(y) != null)) continue;
        final dx = b.valueOf(x) - a.valueOf(x), dy = b.valueOf(y) - a.valueOf(y);
        m = m.withValue(x, m.valueOf(x) - dy * bend).withValue(y, m.valueOf(y) + dx * bend);
      }
    }
    if (b.pathWrap) {
      final from = api.Motion.wrapProgress(a.pathProgress);
      var to = api.Motion.wrapProgress(b.pathProgress);
      if (to - from > 0.5) to -= 1;
      if (from - to > 0.5) to += 1;
      m = m.withValue('pathProgress', api.Motion.wrapProgress(from + (to - from) * t));
    }
    return m;
  }
}

/// A [api.MotionLoop.swing] at [s] (−1–1 on its sine): [rest] ± ([values] −
/// [rest]), keyframes aside.
api.Motion swingPose(api.Motion rest, api.Motion values, double s) {
  var m = values;
  for (final p in api.Motion.properties) {
    if (p == 'spin') continue;
    m = m.withValue(p, rest.valueOf(p) + (values.valueOf(p) - rest.valueOf(p)) * s);
  }
  return m;
}

/// [api.MotionShimmer]'s band of light swept across what the node paints
/// (blended over its own pixels only), over and over in a running app;
/// still, halfway across, on the design canvas.
class RenderShimmer extends RenderShaderMask {
  RenderShimmer() : super(shaderCallback: _clear, blendMode: BlendMode.srcATop);

  static Shader _clear(Rect bounds) => ui.Gradient.linear(Offset.zero, const Offset(1, 0), const [
    Color(0x00000000),
    Color(0x00000000),
  ]);

  api.MotionShimmer _shimmer = const api.MotionShimmer();
  set shimmer(api.MotionShimmer v) {
    if (v == _shimmer) return;
    _shimmer = v;
    _sync();
  }

  bool _animates = false;
  set animates(bool v) {
    if (v == _animates) return;
    _animates = v;
    _sync();
  }

  Ticker? _ticker;
  double _t = 0.5;

  Shader _shader(Rect bounds) => shimmerShader(_shimmer, _t, bounds);

  void _sync() {
    shaderCallback = _shader;
    if (attached && _animates) {
      _ticker ??= Ticker((e) {
        final f = e.inMicroseconds / 1000 / math.max(1, _shimmer.duration);
        _t = f - f.floorToDouble();
        markNeedsPaint();
      });
      if (!_ticker!.isActive) _ticker!.start();
    } else {
      _ticker?.stop();
      _t = 0.5;
    }
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _sync();
  }

  @override
  void detach() {
    _ticker?.stop();
    super.detach();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _ticker = null;
    super.dispose();
  }
}

/// The shader of [s]'s band [t] (0–1) of the way across [bounds]: from
/// fully off one side to fully off the other, along its angle.
Shader shimmerShader(api.MotionShimmer s, double t, Rect bounds) {
  final color = s.color.flutter;
  final glow = color.withValues(alpha: color.a * s.strength.clamp(0.0, 1.0));
  final clear = color.withValues(alpha: 0);
  final half = math.max(0.001, s.width / 2);
  final center = -half + t * (1 + 2 * half);
  final a = s.angle * math.pi / 180;
  final dir = Offset(math.cos(a), math.sin(a));
  final extent = (bounds.width * dir.dx).abs() + (bounds.height * dir.dy).abs();
  final mid = bounds.center;
  Offset at(double f) => mid + dir * ((f - 0.5) * extent);
  return ui.Gradient.linear(at(center - half), at(center + half), [clear, glow, clear], const [0, 0.5, 1]);
}

/// The transform [m] draws (without its shift), plus [spinTurns] turns.
Matrix4 motionMatrix(api.Motion m, {double spinTurns = 0}) {
  final matrix = Matrix4.identity();
  if (m.perspective > 0 && (m.rotateX != 0 || m.rotateY != 0)) matrix.setEntry(3, 2, 0.0012 * m.perspective);
  return matrix
    ..translateByDouble(m.translateX, m.translateY, 0, 1)
    ..scaleByDouble(m.scale * m.scaleX, m.scale * m.scaleY, 1, 1)
    ..rotateZ(m.rotate * math.pi / 180 + spinTurns * 2 * math.pi)
    ..rotateX(m.rotateX * math.pi / 180)
    ..rotateY(m.rotateY * math.pi / 180);
}

/// Flutter's `ImageFiltered`: [filter] over what the child paints.
class RenderImageFilter extends RenderProxyBox {
  ui.ImageFilter? _filter;
  set filter(ui.ImageFilter v) {
    if (v == _filter) return;
    _filter = v;
    markNeedsCompositedLayerUpdate();
  }

  @override
  bool get alwaysNeedsCompositing => child != null && _filter != null;

  @override
  bool get isRepaintBoundary => alwaysNeedsCompositing;

  @override
  OffsetLayer updateCompositedLayer({required covariant ImageFilterLayer? oldLayer}) =>
      (oldLayer ?? ImageFilterLayer())..imageFilter = _filter;
}

/// Paints a [api.StrokePath] in the box.
class StrokePathPainter extends CustomPainter {
  StrokePathPainter(this.path);

  final api.StrokePath path;

  Path pathFor(Size size) {
    Offset at(api.Offset p) => Offset(
      path.xUnit == api.PathUnit.fraction ? p.dx * size.width : p.dx,
      path.yUnit == api.PathUnit.fraction ? p.dy * size.height : p.dy,
    );
    final out = Path();
    final points = path.points;
    if (points.isEmpty) return out;
    var prev = at(points.first);
    out.moveTo(prev.dx, prev.dy);
    for (final p in points.skip(1)) {
      final next = at(p);
      switch (path.curve) {
        case api.PathCurve.straight:
          out.lineTo(next.dx, next.dy);
        case api.PathCurve.vertical:
          final midY = (prev.dy + next.dy) / 2;
          out.cubicTo(prev.dx, midY, next.dx, midY, next.dx, next.dy);
        case api.PathCurve.horizontal:
          final midX = (prev.dx + next.dx) / 2;
          out.cubicTo(midX, prev.dy, midX, next.dy, next.dx, next.dy);
      }
      prev = next;
    }
    return out;
  }

  Path visiblePathFor(Size size) {
    final full = pathFor(size);
    final progress = path.progress.clamp(0.0, 1.0);
    if (progress >= 1) return full;
    final visible = Path();
    final metrics = full.computeMetrics().toList();
    var remaining = metrics.fold(0.0, (double length, metric) => length + metric.length) * progress;
    for (final metric in metrics) {
      if (remaining <= 0) break;
      visible.addPath(metric.extractPath(0, math.min(remaining, metric.length)), Offset.zero);
      remaining -= metric.length;
    }
    return visible;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (path.points.length < 2 || path.width <= 0 || path.progress <= 0) return;
    final paint = Paint()
      ..color = path.color.flutter
      ..style = PaintingStyle.stroke
      ..strokeWidth = path.width
      ..strokeCap = StrokeCap.values.byName(path.cap.name)
      ..strokeJoin = StrokeJoin.round;
    final full = visiblePathFor(size);
    final dash = [
      for (final d in path.dashPattern)
        if (d > 0) d,
    ];
    if (dash.isEmpty) {
      canvas.drawPath(full, paint);
      return;
    }
    for (final metric in full.computeMetrics()) {
      var distance = 0.0;
      var i = 0;
      while (distance < metric.length) {
        final length = dash[i % dash.length];
        if (i.isEven) canvas.drawPath(metric.extractPath(distance, math.min(distance + length, metric.length)), paint);
        distance += length;
        i++;
      }
    }
  }

  @override
  bool shouldRepaint(StrokePathPainter oldDelegate) => oldDelegate.path != path;
}

// --- 3D: flip cards and tilt ----------------------------------------------------

/// The flip card and tilt of [n], and its face of a flip card around it:
/// inside the motion.
void cardLayers(NodeBuilder b, Node n, List<RenderBox> chain, {required bool animates}) {
  final be = n.behaviors;
  // A face of the flip card it sits in: the front hides when turned away,
  // the back is turned over in advance.
  final parentId = b.tree.source.parentOf(b.id);
  final parent = parentId == null ? null : b.tree.source.node(parentId);
  if (parent?.behaviors.flip case final api.FlipCard card) {
    final face = parent!.children.indexOf(b.id);
    if (face == 0 || face == 1) {
      final back = face == 1;
      chain.add(
        b.obtain<RenderPose>('flipFace', RenderPose.new)
          ..transform = !back
              ? Matrix4.identity()
              : card.axis == api.FlipAxis.y
              ? Matrix4.rotationY(math.pi)
              : Matrix4.rotationX(math.pi)
          ..origin = Alignment.center
          ..backfaceHidden = true,
      );
    }
  }
  if (be.tilt case final api.Tilt tilt) {
    final box = b is NodeBox ? b : null;
    final pose = b.obtain<RenderTilt>('tilt', RenderTilt.new)
      ..tilt = tilt
      // `${tilt.*}` for the nodes inside it, as it moves.
      ..onValues = box == null
          ? null
          : (values) => box.tree.binder?.nodeScope(box.tree.source, box.id, instance: box.instance)?.update('tilt', values);
    if (animates && tilt.hover) {
      chain.add(
        b.obtain<RenderMouseRegion>('tiltHover', RenderMouseRegion.new)
          ..onHover = ((e) => pose.track(e.localPosition))
          ..onExit = ((_) => pose.release()),
      );
    }
    if (animates && tilt.drag) {
      chain.add(
        b.obtain<RenderPointerListener>('tiltDrag', RenderPointerListener.new)
          ..onPointerDown = ((e) => pose.track(e.localPosition))
          ..onPointerMove = ((e) => pose.track(e.localPosition))
          ..onPointerUp = ((_) => pose.release())
          ..onPointerCancel = ((_) => pose.release()),
      );
    }
    chain.add(pose..animates = animates);
  }
  if (be.flip case final api.FlipCard flip) {
    // Turned by its variable, a tap or a drag (render/flip_card.dart).
    chain.add(
      b.obtain<RenderFlip>('flip', RenderFlip.new)
        ..configure(b is NodeBox ? b : null, flip, be.motion, animates: animates),
    );
  }
}

/// Tilts its node in 3D toward the pointer ([api.Tilt]): the edge under it
/// tips away, the node lifts while the pointer is over it, and it settles
/// back over the tilt's reset when the pointer leaves.
class RenderTilt extends RenderPose with _Ticking {
  api.Tilt _tilt = const api.Tilt();

  /// Gets `${tilt}` (x, y, active) as the pointer moves it.
  void Function(Map<String, Object?> values)? onValues;
  set tilt(api.Tilt v) {
    if (v == _tilt) return;
    _tilt = v;
    _show();
  }

  bool _animates = false;
  set animates(bool v) {
    if (v == _animates) return;
    _animates = v;
    if (!v) {
      _from = _to = Offset.zero;
      _activeFrom = _activeTo = 0;
      _moving = false;
    }
    _show();
    syncTicker();
  }

  Offset _from = Offset.zero, _to = Offset.zero;
  double _activeFrom = 0, _activeTo = 0, _t = 1;
  bool _reset = false, _moving = false;
  Duration? _since;

  double get _eased => (_reset ? _tilt.curve : api.AnimationCurve.easeOut).transform(_t);
  Offset get _position => Offset.lerp(_from, _to, _eased)!;
  double get _active => _activeFrom + (_activeTo - _activeFrom) * _eased;

  void _moveTo(Offset target, double active, {required bool reset}) {
    _from = _position;
    _activeFrom = _active;
    _to = target;
    _activeTo = active;
    _reset = reset;
    _t = 0;
    _moving = true;
    _since = null;
    syncTicker();
  }

  /// The pointer at [local] in the node's box.
  void track(Offset local) {
    if (!hasSize || size.isEmpty) return;
    _moveTo(
      Offset(
        (local.dx / size.width * 2 - 1).clamp(-1.0, 1.0),
        (local.dy / size.height * 2 - 1).clamp(-1.0, 1.0),
      ),
      1,
      reset: false,
    );
  }

  void release() => _moveTo(Offset.zero, 0, reset: true);

  @override
  bool get ticking => _animates && _moving;

  @override
  void tick(Duration elapsed) {
    final since = _since ??= elapsed;
    final d = _reset ? math.max(1, _tilt.reset) : 90;
    _t = ((elapsed - since).inMicroseconds / 1000 / d).clamp(0.0, 1.0);
    if (_t >= 1) _moving = false;
    _show();
    final p = _position;
    onValues?.call({'x': p.dx, 'y': p.dy, 'active': _active > 0.5});
    if (!ticking) _ticker?.stop();
  }

  void _show() {
    final max = _tilt.max, p = _position, active = _active;
    transform = motionMatrix(
      api.Motion(
        rotateX: p.dy * max.rotateX,
        rotateY: -p.dx * max.rotateY,
        perspective: max.perspective,
        scale: 1 + (max.scale - 1) * active,
        translateX: max.translateX * active,
        translateY: max.translateY * active,
      ),
    );
    origin = Alignment(max.originX, max.originY);
  }
}

abstract final class _MotionRevealWatcher {
  static final Set<RenderMotion> _waiting = {};
  static bool _scheduled = false;
  static void add(RenderMotion motion) {
    _waiting.add(motion);_schedule();SchedulerBinding.instance.scheduleFrame();
  }
  static void remove(RenderMotion motion) => _waiting.remove(motion);
  static void _schedule() {
    if(_scheduled||_waiting.isEmpty)return;
    _scheduled=true;
    SchedulerBinding.instance.addPostFrameCallback((_){
      _scheduled=false;
      for(final motion in _waiting.toList()) {
        motion._checkReveal();
      }
      _schedule();
    });
  }
}
