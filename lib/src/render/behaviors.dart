// A node's behaviors as layers of its render chain (see node_tree.dart's
// outer layers). Outermost first:
//
//   constraints → track pose → transform gesture → motion → shimmer → flip / tilt → [ignore pointer]
//   → animations (render/animations.dart) → opacity → blurs → stroke path → content
//
// The design canvas (a tree that doesn't animate) draws each at rest: the
// motion's values, an animation at its previewAt (a loop's first frame), a
// track at its variable's value. A running app plays them (tickers in the
// render objects).
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:codelessly_api/core.dart' as api;
import 'package:codelessly_api/core.dart' show Node;
import 'package:flutter/foundation.dart' show protected;
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import 'animations.dart';
import 'convert.dart';
import 'drag_track.dart';
import 'flip_card.dart';
import 'transform_gesture.dart';
import 'node_tree.dart' show NodeBox;
import 'paint/svg_path.dart';
import 'recipe.dart';

/// Track pose, transform gesture, motion, shimmer, flip and tilt: the
/// layers between the constraints and the animations. The motion is the
/// node's one transform (Flutter's `Transform`): 30.1.0 folded the node's
/// own scale and rotation into it.
void motionLayers(NodeBuilder b, Node n, List<RenderBox> chain, {required bool animates}) {
  final be = n.behaviors;
  if (be.track case final api.Track track) {
    // At its value (`track.value`, else its variable's, else its start),
    // and in a running app dragged along the track
    // (render/drag_track.dart).
    final box = b is NodeBox ? b : null;
    final reads = track.value == null && track.hasVariable && (box?.tree.bindings?.hasValues ?? false);
    final p = track.restProgressOf(track.value ?? track.min);
    final moves = animates ||
        reads ||
        track.relative ||
        track.units == api.TrackUnits.parent ||
        track.usesViewBox ||
        trackPose(track, p) != null;
    if (moves) {
      chain.add(
        b.obtain<RenderDragTrack>('trackPose', RenderDragTrack.new)
          ..configure(box, track, enabled: track.enabled, interactive: animates),
      );
    }
  }
  // Pinch, pan and rotate in a running app (render/transform_gesture.dart),
  // inside the track.
  if (animates && n.type != 'canvas') {
    if (be.transformGesture case final api.TransformGesture gesture) {
      chain.add(
        b.obtain<RenderTransformGesture>('transformGesture', RenderTransformGesture.new)
          ..configure(b is NodeBox ? b : null, gesture),
      );
    }
  } else if (n.type != 'canvas') {
    // The design canvas draws a pose given by data (a sticker or a caption
    // placed by its record: `transformGesture.x` bound), as a running app
    // starts at it: translate, then rotate, then scale, about the center.
    if (be.transformGesture case final api.TransformGesture g
        when g.x != null || g.y != null || g.scale != null || g.rotation != null || g.scaleX != null || g.scaleY != null) {
      final s = g.scale ?? 1;
      chain.add(
        b.obtain<RenderPose>('transformPose', RenderPose.new)
          ..transform = (Matrix4.translationValues(g.x ?? 0, g.y ?? 0, 0)
            ..rotateZ((g.rotation ?? 0) * math.pi / 180)
            ..scaleByDouble(s * (g.scaleX ?? 1), s * (g.scaleY ?? 1), 1, 1)),
      );
    }
  }
  // A motion layer for the node's motion, or for the motion values its
  // animations or state styles set.
  if (_hasMotionLayer(b, n, animates)) {
    final motion = be.motion ?? api.Motion.none;
    chain.add(b.obtain<RenderMotion>('motion', RenderMotion.new)..motion = motion);
  }
  if (be.shimmer case final api.Shimmer shimmer) {
    chain.add(b.obtain<RenderShimmer>('shimmer', RenderShimmer.new)..shimmer = shimmer);
  }
  cardLayers(b, n, chain, animates: animates);
}

/// Whether node [n] has a motion layer: for its motion, the motion values its
/// animations set, or (in a running app) a state style that moves it. A
/// state style that moves the node (a press shrink) keeps the layer at rest
/// too: adding it mid-press rewired the chain under the pointer and the tap
/// was lost.
bool _hasMotionLayer(NodeBuilder b, Node n, bool animates) =>
    n.behaviors.motion != null || replacedMotionProperties(n).isNotEmpty || (animates && _stateMoves(b, n));

/// The animations, between the rotation and the opacity.
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
  final hasMotion = _hasMotionLayer(b, n, animates);
  animationLayers(b, n, chain,
      animates: animates,
      motion: hasMotion ? b.obtain<RenderMotion>('motion', RenderMotion.new) : null,
      shimmer: be.shimmer != null ? b.obtain<RenderShimmer>('shimmer', RenderShimmer.new) : null);
}

/// Blurs, inside the opacity, around the content.
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

/// Where a [api.Track] puts its node, in the node's coordinates with
/// the origin at its rest center: a line,
/// an arc about its pivot, or a path, measured in pixels, in the node's own
/// size ([api.Track.relative]), in its parent's
/// ([api.TrackUnits.parent]) or in a viewBox stretched to the parent
/// ([api.Track.usesViewBox]).
class TrackGeometry {
  TrackGeometry(this.track, {this.size = Size.zero, this.parent, this.rest = Offset.zero});

  final api.Track track;

  /// The node's size, the parent's (null unknown), and the node's rest
  /// center in the parent (for a viewBox).
  final Size size;
  final Size? parent;
  final Offset rest;

  bool get _inParent => track.units == api.TrackUnits.parent && parent != null;
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
      final (w, h) = track.path!.viewBoxSize!;
      final sx = parent!.width / w, sy = parent!.height / h;
      return Offset((point.dx + start.dx) * sx, (point.dy + start.dy) * sy) - rest;
    }
    return Offset(_x(point.dx), _y(point.dy));
  }

  /// Where the node's center sits at [progress], from rest. A line or arc
  /// goes on past its ends (overscroll, a parked node); a path stops there.
  Offset offsetAt(double progress) {
    switch (track.shape) {
      case api.TrackShape.line:
        return Offset.lerp(_lineStart, _lineEnd, progress)!;
      case api.TrackShape.arc:
        // Round the pivot, on a circle through rest.
        final pivot = Offset(_x(track.pivotX), _y(track.pivotY));
        if (pivot == Offset.zero) return Offset.zero;
        final a = _angle(progress) * math.pi / 180;
        final r = -pivot;
        return pivot + Offset(r.dx * math.cos(a) - r.dy * math.sin(a), r.dx * math.sin(a) + r.dy * math.cos(a));
      case api.TrackShape.path:
        final path = track.path == null ? null : MeasuredPath.of(track.path!.path);
        if (path == null) return Offset.zero;
        // An unbounded path goes round again.
        final p = track.unbounded ? progress - progress.floorToDouble() : progress.clamp(0.0, 1.0);
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
      case api.TrackShape.line:
        return 0;
      case api.TrackShape.arc:
        return track.rotate ? _angle(progress) : 0;
      case api.TrackShape.path:
        final orient = track.path?.orient ?? api.PathOrient.none;
        if (orient == api.PathOrient.none) return 0;
        final at = MeasuredPath.of(track.path!.path)?.at(
            track.unbounded ? progress - progress.floorToDouble() : progress.clamp(0.0, 1.0));
        if (at == null) return 0;
        var angle = at.$2;
        // A path stretched unevenly turns as drawn.
        if (_inParent && !_inViewBox && parent!.width != parent!.height) {
          angle = math.atan2(math.sin(angle) * parent!.height, math.cos(angle) * parent!.width);
        }
        final upright = orient == api.PathOrient.upright;
        return (upright ? api.Motion.uprightAngle(angle) : angle) * 180 / math.pi;
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
Matrix4? trackPose(api.Track track, double progress) => TrackGeometry(track).poseAt(progress);

/// A node drawn where its [api.Track] puts it at [progress], worked out
/// from its laid-out size and its parent's.
class RenderTrackPose extends RenderPose {
  api.Track _track = const api.Track();
  api.Track get track => _track;
  set track(api.Track v) {
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
  bool get _measuresParent => _track.units == api.TrackUnits.parent || _track.usesViewBox;

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

  /// The pose it draws its child with.
  Matrix4 get transform => _transform;
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
  double get opacity => _opacity;
  set opacity(double v) {
    if (v == _opacity) return;
    final composited = alwaysNeedsCompositing;
    _opacity = v;
    if (composited != alwaysNeedsCompositing) markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  double _blur = 0;
  set blur(double v) {
    if (v == _blur) return;
    final composited = alwaysNeedsCompositing;
    _blur = v;
    if (composited != alwaysNeedsCompositing) markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  /// A partly transparent or blurred pose paints its child into a layer
  /// (an opacity or image filter layer), so what's above it must composite
  /// too: an ancestor that scales or clips with the canvas alone (a fitted
  /// board, a clip) would otherwise leave the layer unscaled and unclipped.
  @override
  bool get alwaysNeedsCompositing => child != null && ((_opacity > 0 && _opacity < 1) || _blur > 0);

  /// Hidden while its back faces the viewer (through every transform above).
  bool _backfaceHidden = false;
  set backfaceHidden(bool v) {
    if (v == _backfaceHidden) return;
    _backfaceHidden = v;
    markNeedsPaint();
  }

  /// Whether it draws its child moved (a subclass with a pose of its own
  /// says so).
  @protected
  bool get posed => _shift != Offset.zero || !_transform.isIdentity();

  bool get _moved => posed;

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
    // Not laid out yet: a layer a hover style just put in, hit before the
    // frame that lays it out (two mouse events in one frame).
    if (!hasSize) return false;
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

/// A node's [api.Motion]: its transform, drawn over its layout, and the
/// path it sits on. What moves it is the node's animation player
/// (render/animations.dart): its animations and transitions hand this layer
/// the values it draws over the motion's own ([overrides]).
class RenderMotion extends RenderPose {
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
  set motion(api.Motion v) {
    if (v == _motion) return;
    _motion = v;
    _show();
  }

  /// Values the node's animations and transitions set, by property
  /// ([api.Motion.properties]): drawn over the motion's own.
  Map<String, double> _overrides = const {};
  set overrides(Map<String, double> v) {
    if (v.length == _overrides.length && v.entries.every((e) => _overrides[e.key] == e.value)) return;
    _overrides = v;
    _show();
  }

  /// While the node is pushed off its path (keyframes on its translation
  /// playing), a path that turns it follows where it actually goes.
  bool _headingFromMovement = false;
  set headingFromMovement(bool v) {
    if (v == _headingFromMovement) return;
    _headingFromMovement = v;
    _show();
  }

  Offset? _lastPathPosition;
  double? _pathHeading;

  /// The motion as drawn: its own values with the [overrides].
  api.Motion get shown {
    var m = _motion;
    for (final e in _overrides.entries) {
      m = m.withValue(e.key, e.value);
    }
    return m;
  }

  /// A path in a viewBox follows the parent's size: placed again once laid
  /// out (the parent has its size by then).
  Size? _stage;
  @override
  void performLayout() {
    super.performLayout();
    if (_motion.hasPath && _motion.path!.effectiveViewBox != null) {
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

  void _show() {
    final m = shown;
    var pose = m;
    final path = m.path;
    if (path != null && path.hasPath) {
      final measured = MeasuredPath.of(path.path);
      // A closed path wraps its progress; an open one stops at its ends.
      final progress = measured != null && measured.isClosed ? api.PathFollow.wrap(path.progress) : path.progress;
      final at = measured?.at(progress);
      if (at != null) {
        // A path in a viewBox is stretched over the node's parent.
        var point = at.$1;
        var heading = at.$2;
        final box = path.effectiveViewBox;
        final stage = box != null ? _parentSize() : null;
        if (stage != null && box != null) {
          // In a viewBox the path is placed over the parent: its points are
          // where the node goes (from the parent's origin), not offsets from
          // the path's start, so the node is laid out at the origin.
          final sx = stage.width / box[0], sy = stage.height / box[1];
          final absolute = point + measured!.start;
          point = Offset(absolute.dx * sx, absolute.dy * sy);
          heading = math.atan2(math.sin(heading) * sy, math.cos(heading) * sx);
        }
        final total = Offset(m.translateX + point.dx, m.translateY + point.dy);
        final turns = path.orient != api.PathOrient.none;
        // Keyframes that push the node off its path turn it too: its nose
        // follows where it actually goes.
        if (turns && _headingFromMovement) {
          final previous = _lastPathPosition;
          if (previous != null && (total - previous).distance > 0.25) _pathHeading = (total - previous).direction;
          _lastPathPosition = total;
          heading = _pathHeading ?? heading;
        } else {
          _lastPathPosition = null;
          _pathHeading = null;
        }
        final upright = path.orient == api.PathOrient.upright;
        final turn = upright ? api.PathFollow.uprightAngle(heading) : heading;
        pose = pose
            .withValue('translateX', total.dx)
            .withValue('translateY', total.dy)
            .withValue('rotate', turns ? m.rotate + turn * 180 / math.pi : m.rotate);
      }
    }
    transform = motionMatrix(pose);
    origin = Alignment(pose.alignment.x, pose.alignment.y);
    shift = Offset(pose.shiftX, pose.shiftY);
    backfaceHidden = pose.backfaceHidden;
  }
}

/// [api.Shimmer]'s band of light across what the node paints (blended over
/// its own pixels only), at its [position]: the `shimmer` animation preset
/// sweeps it across (render/animations.dart).
class RenderShimmer extends RenderShaderMask {
  RenderShimmer() : super(shaderCallback: _clear, blendMode: BlendMode.srcATop);

  static Shader _clear(Rect bounds) => ui.Gradient.linear(Offset.zero, const Offset(1, 0), const [
    Color(0x00000000),
    Color(0x00000000),
  ]);

  api.Shimmer _shimmer = const api.Shimmer();
  set shimmer(api.Shimmer v) {
    if (v == _shimmer) return;
    _shimmer = v;
    _sync();
  }

  /// Where the band is, set by the node's animations; null: the shimmer's
  /// own position.
  double? _position;
  set position(double? v) {
    if (v == _position) return;
    _position = v;
    _sync();
  }

  Shader _shader(Rect bounds) => shimmerShader(_shimmer, _position ?? _shimmer.position, bounds);

  void _sync() {
    shaderCallback = _shader;
    markNeedsPaint();
  }
}

/// The shader of [s]'s band [t] (0–1) of the way across [bounds]: from
/// fully off one side to fully off the other, along its angle.
Shader shimmerShader(api.Shimmer s, double t, Rect bounds) {
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

/// The transform [m] draws, without its shift and about the box's origin
/// (a [RenderPose] puts it about the motion's alignment): its translation,
/// then the scale, the rotation about z, and the 3D rotations seen with its
/// perspective (outermost first).
Matrix4 motionMatrix(api.Motion m) {
  final matrix = Matrix4.identity();
  if (m.perspective > 0 && (m.rotateX != 0 || m.rotateY != 0)) matrix.setEntry(3, 2, 0.0012 * m.perspective);
  return matrix
    ..translateByDouble(m.translateX, m.translateY, 0, 1)
    ..scaleByDouble(m.scale * m.scaleX, m.scale * m.scaleY, 1, 1)
    ..rotateZ(m.rotate * math.pi / 180)
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

// --- 3D: flip cards and tilt ----------------------------------------------------

/// The flip card and tilt of [n], and its face of a flip card around it:
/// inside the motion.
void cardLayers(NodeBuilder b, Node n, List<RenderBox> chain, {required bool animates}) {
  final be = n.behaviors;
  // A face of the flip card it sits in: the front hides when turned away,
  // the back is turned over in advance.
  final parentId = b.source.parentOf(b.id);
  final parent = parentId == null ? null : b.source.node(parentId);
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
          : (values) => box.tree.bindings?.publish(box.source, box.id, box.instance, 'tilt', values);
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
        ..configure(b is NodeBox ? b : null, flip, be.motion,
            animates: animates, transition: api.Transition.of(be.transitions, 'motion.rotateY')),
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
    origin = Alignment(max.alignment.x, max.alignment.y);
  }
}

/// Whether a state style (the node's own, or one of a node around it that
/// targets it) can set node [n]'s motion.
bool _stateMoves(NodeBuilder b, Node n) {
  bool moves(Node? owner) =>
      owner != null && owner.behaviors.states.patches.values.any((p) => p[n.id]?.containsKey('motion') ?? false);
  if (moves(b.source.node(n.id))) return true;
  for (String? id = b.source.parentOf(n.id); id != null; id = b.source.parentOf(id)) {
    if (moves(b.source.node(id))) return true;
  }
  return false;
}
