// A node's behaviours as layers of its render chain (see node_tree.dart's
// outer layers). Outermost first, as SDK 8.x wrapped a node:
//
//   constraints → track pose → motion → scale → rotation → [ignore pointer]
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
import 'paint/svg_path.dart';
import 'recipe.dart';

/// Track pose, motion and scale: the layers between the constraints and
/// the rotation.
void motionLayers(NodeBuilder b, Node n, List<RenderBox> chain, {required bool animates}) {
  final be = n.behaviours;
  if (be.drag?.track case final api.DragTrack track) {
    // The variable's value comes with bindings; here its default.
    final p = track.progressOf(track.defaultValue ?? track.min);
    final pose = trackPose(track, p);
    if (pose != null) {
      chain.add(
        b.obtain<RenderPose>('trackPose', RenderPose.new)
          ..transform = pose
          ..origin = Alignment.center,
      );
    }
  }
  if (be.motion case final api.Motion motion) {
    chain.add(
      b.obtain<RenderMotion>('motion', RenderMotion.new)
        ..animates = animates
        ..motion = motion,
    );
  }
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
  final be = n.behaviours;
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
  if (n.behaviours.strokePath case final api.StrokePath path) {
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
  final ink = n.behaviours.inkWell!;
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

/// Where [track] puts its node at [progress]: a move (and a turn) about its
/// centre. Null at its place.
Matrix4? trackPose(api.DragTrack track, double progress) {
  final p = progress.clamp(0.0, 1.0);
  Offset offset = Offset.zero;
  double degrees = 0;
  switch (track.shape) {
    case api.DragTrackShape.line:
      offset = Offset.lerp(Offset(track.x1, track.y1), Offset(track.x2, track.y2), p)!;
    case api.DragTrackShape.arc:
      final pivot = Offset(track.pivotX, track.pivotY);
      final a = track.angleAt(p) * math.pi / 180;
      if (pivot != Offset.zero) {
        final r = -pivot;
        offset = pivot + Offset(r.dx * math.cos(a) - r.dy * math.sin(a), r.dx * math.sin(a) + r.dy * math.cos(a));
      }
      if (track.rotate) degrees = track.angleAt(p);
    case api.DragTrackShape.path:
      final at = track.path == null ? null : MeasuredPath.of(track.path!)?.at(p);
      if (at != null) {
        offset = at.$1;
        if (track.orientToPath) degrees = at.$2 * 180 / math.pi;
      }
  }
  if (offset == Offset.zero && degrees == 0) return null;
  return Matrix4.translationValues(offset.dx, offset.dy, 0)..rotateZ(degrees * math.pi / 180);
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
      final m = getTransformTo(null).storage;
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
  Duration _elapsed = Duration.zero;

  bool get ticking;
  void tick(Duration elapsed);

  void syncTicker() {
    if (attached && ticking) {
      _ticker ??= Ticker((e) {
        _elapsed = e;
        tick(e);
      });
      if (!_ticker!.isActive) {
        _elapsed = Duration.zero;
        _ticker!.start();
      }
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
/// draws each loop's first frame, as SDK 8.x's design canvas did.
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

  /// The run phase (0–1) of [l] [elapsed] after it started.
  static double phase(api.LoopAnimation l, Duration elapsed) {
    final ms = elapsed.inMicroseconds / 1000 - l.delay;
    if (ms <= 0) return 0;
    final d = math.max(1, l.duration);
    final runs = ms / d;
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
  api.Motion _motion = api.Motion.none;
  bool _animates = false;
  bool _entered = false;

  /// The running transition: from [_from] to [_to] since [_since] (its
  /// delay not yet counted).
  api.Motion? _from;
  api.Motion _to = api.Motion.none;
  Duration _since = Duration.zero;
  int _runs = 0;

  /// The pose drawn last (a new transition starts there).
  api.Motion _shown = api.Motion.none;
  double _turns = 0, _speed = 0;
  Duration _lastTick = Duration.zero;

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
    _to = v;
    if (_animates && _entered && !_samePose(old, v) && _transitionMs(v) > 0) {
      _start(_shown, v, at: _elapsed);
    } else if (_from != null) {
      _to = v;
    }
    _show();
    syncTicker();
  }

  static bool _samePose(api.Motion a, api.Motion b) =>
      api.Motion.properties.every((p) => p == 'spin' || a.valueOf(p) == b.valueOf(p)) && a.path == b.path;

  static int _transitionMs(api.Motion m) => m.curve == api.AnimationCurve.spring ? 1 : m.duration;

  void _start(api.Motion from, api.Motion to, {required Duration at}) {
    _from = from;
    _to = to;
    _since = at;
  }

  @override
  void attach(PipelineOwner owner) {
    if (!_entered && _animates) {
      final m = _motion;
      // Entering (or looping): from the entrance start to the values.
      final loops = m.loop != api.MotionLoop.none && m.duration > 0;
      if (loops || m.hasEntrance && _transitionMs(m) > 0) _start(m.entranceStart, m, at: Duration.zero);
      _runs = 0;
    }
    _entered = true;
    super.attach(owner);
    _show();
  }

  @override
  bool get ticking => _animates && (_from != null || _motion.spin != 0 || _speed != 0);

  @override
  void tick(Duration elapsed) {
    if (elapsed < _lastTick) _lastTick = Duration.zero;
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    // Spin reaches its speed over its ramp.
    final target = _motion.spin;
    if (_speed != target) {
      final perSecond = _motion.spinRamp <= 0
          ? double.infinity
          : math.max(target.abs(), _speed.abs()) / (_motion.spinRamp / 1000);
      final step = math.min((target - _speed).abs(), perSecond * dt);
      _speed += (target - _speed).sign * step;
    }
    _turns += _speed * dt;
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
    if (_animates && from != null) {
      final ms = (_elapsed - _since).inMicroseconds / 1000 - m.delay;
      final t = ms <= 0 ? 0.0 : _eased(ms);
      final done = ms > 0 && (m.curve == api.AnimationCurve.spring ? t == 1 : ms >= m.duration);
      m = api.Motion.lerp(from, _to, done ? 1 : t);
      if (done) {
        final loops = _motion.loop != api.MotionLoop.none && _motion.duration > 0;
        if (loops && (_motion.repeat == 0 || ++_runs < _motion.repeat)) {
          // The next run, without the delay: again, or back.
          final next = _elapsed - Duration(milliseconds: _motion.delay);
          if (_motion.loop == api.MotionLoop.reverse) {
            _start(_to, from, at: next);
          } else {
            _start(from, _to, at: next);
          }
        } else {
          // A counted loop that's done rests.
          if (loops) m = _motion.atRest;
          _from = null;
        }
      }
    }
    _shown = m;
    var shown = m;
    if (m.hasPath) {
      final at = MeasuredPath.of(m.path!)?.at(m.pathProgress);
      if (at != null) {
        shown = shown
            .withValue('translateX', m.translateX + at.$1.dx)
            .withValue('translateY', m.translateY + at.$1.dy)
            .withValue('rotate', m.orientToPath ? m.rotate + at.$2 * 180 / math.pi : m.rotate);
      }
    }
    transform = motionMatrix(shown, spinTurns: _turns);
    origin = Alignment(shown.originX, shown.originY);
    shift = Offset(shown.shiftX, shown.shiftY);
    opacity = shown.opacity;
    blur = shown.blur;
    backfaceHidden = shown.backfaceHidden;
  }
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

  @override
  void paint(Canvas canvas, Size size) {
    if (path.points.length < 2 || path.width <= 0) return;
    final paint = Paint()
      ..color = path.color.flutter
      ..style = PaintingStyle.stroke
      ..strokeWidth = path.width
      ..strokeCap = StrokeCap.values.byName(path.cap.name)
      ..strokeJoin = StrokeJoin.round;
    final full = pathFor(size);
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
