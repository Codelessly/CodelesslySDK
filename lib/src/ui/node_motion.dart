import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show PathMetric, Tangent;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:path_parsing/path_parsing.dart';

/// The Flutter curve for a [MotionCurve].
Curve flutterCurveOf(MotionCurve curve) => switch (curve) {
  MotionCurve.linear => Curves.linear,
  MotionCurve.easeInOut => Curves.easeInOut,
  MotionCurve.easeOut => Curves.easeOut,
  MotionCurve.easeIn => Curves.easeIn,
  MotionCurve.easeOutBack => Curves.easeOutBack,
  MotionCurve.easeOutCubic => Curves.easeOutCubic,
  MotionCurve.spring => const SpringCurve(),
  MotionCurve.elasticOut => Curves.elasticOut,
  MotionCurve.bounceOut => Curves.bounceOut,
  MotionCurve.fastOutSlowIn => Curves.fastOutSlowIn,
};

/// An under-damped spring settling on 1: it passes the target once by about
/// 12%, swings back a little and settles, the way a released card snaps
/// home.
class SpringCurve extends Curve {
  /// Creates a [SpringCurve].
  const SpringCurve();

  @override
  double transformInternal(double t) =>
      1 - math.exp(-6.5 * t) * math.cos(2 * math.pi * 1.25 * t) * (1 - t * t);
}

final Map<String, _MeasuredPath?> _pathCache = {};

class _MeasuredPath {
  _MeasuredPath(this.metrics, this.start)
    : length = metrics.fold(0, (sum, m) => sum + m.length);

  final List<PathMetric> metrics;
  final Offset start;
  final double length;

  /// Position (relative to the path's start) and direction at [progress].
  (Offset, double)? at(double progress) {
    if (length <= 0) return null;
    double distance = progress.clamp(0, 1).toDouble() * length;
    for (final PathMetric metric in metrics) {
      if (distance <= metric.length || metric == metrics.last) {
        final Tangent? tangent = metric.getTangentForOffset(
          distance.clamp(0, metric.length).toDouble(),
        );
        if (tangent == null) return null;
        return (tangent.position - start, -tangent.angle);
      }
      distance -= metric.length;
    }
    return null;
  }
}

class _PathBuilder extends PathProxy {
  final Path path = Path();
  Offset? start;

  @override
  void moveTo(double x, double y) {
    start ??= Offset(x, y);
    path.moveTo(x, y);
  }

  @override
  void lineTo(double x, double y) => path.lineTo(x, y);

  @override
  void cubicTo(
    double x1,
    double y1,
    double x2,
    double y2,
    double x3,
    double y3,
  ) => path.cubicTo(x1, y1, x2, y2, x3, y3);

  @override
  void close() => path.close();
}

_MeasuredPath? _measure(String data) => _pathCache.putIfAbsent(data, () {
  try {
    final builder = _PathBuilder();
    writeSvgPathDataToPath(data, builder);
    final metrics = builder.path.computeMetrics().toList();
    if (metrics.isEmpty) return null;
    return _MeasuredPath(metrics, builder.start ?? Offset.zero);
  } catch (_) {
    return null;
  }
});

/// Where a node moving along SVG path [data] is at [progress] (0 to 1, by
/// arc length), relative to the path's start, and the path's direction
/// there in radians. Null when the path can't be read or is empty.
(Offset, double)? pointOnMotionPath(String data, double progress) =>
    _measure(data)?.at(progress);

/// The transform [motion] draws, without spin, around [origin] in a box of
/// [size]. [spinTurns] adds a spin angle.
Matrix4 motionMatrix(MotionModel motion, {double spinTurns = 0}) {
  final matrix = Matrix4.identity();
  if (motion.perspective > 0 && (motion.rotateX != 0 || motion.rotateY != 0)) {
    matrix.setEntry(3, 2, 0.0012 * motion.perspective);
  }
  matrix
    ..translateByDouble(motion.translateX, motion.translateY, 0, 1)
    ..scaleByDouble(
      motion.scale * motion.scaleX,
      motion.scale * motion.scaleY,
      1,
      1,
    )
    ..rotateZ(motion.rotate * math.pi / 180 + spinTurns * 2 * math.pi)
    ..rotateX(motion.rotateX * math.pi / 180)
    ..rotateY(motion.rotateY * math.pi / 180);
  return matrix;
}

/// Draws [child] with a node's [motion]: a transform over its layout that
/// animates whenever its values change, plus an optional continuous spin.
///
/// [motion] holds the values to show now, with bound variables already
/// resolved. When they change the widget animates to them over
/// [MotionModel.durationMs]. When [animate] is false (the design canvas) it
/// jumps to them and doesn't spin.
class NodeMotion extends StatefulWidget {
  /// Creates a [NodeMotion].
  const NodeMotion({
    super.key,
    required this.motion,
    required this.child,
    this.animate = true,
  });

  /// The values to show.
  final MotionModel motion;

  /// Whether changes animate and spin runs.
  final bool animate;

  /// The node's widget.
  final Widget child;

  @override
  State<NodeMotion> createState() => _NodeMotionState();
}

class _NodeMotionState extends State<NodeMotion> with TickerProviderStateMixin {
  late final AnimationController _transition = AnimationController(vsync: this)
    ..addListener(_rebuild);
  late MotionModel _from = widget.motion;
  late MotionModel _to = widget.motion;

  /// The curve of the running transition, kept from when it started so a
  /// bound curve that changes mid-way doesn't jump it.
  late MotionCurve _curve = widget.motion.curve;

  Ticker? _spinTicker;
  Duration _lastTick = Duration.zero;

  /// Current spin speed and angle, in turns per second and turns.
  double _speed = 0;
  double _turns = 0;

  /// Holds a transition back for [MotionModel.delayMs]; until it fires the
  /// node stays where the transition starts.
  Timer? _delay;

  void _rebuild() => setState(() {});

  bool get _loops =>
      widget.animate &&
      widget.motion.loop != MotionLoop.none &&
      widget.motion.durationMs > 0;

  @override
  void initState() {
    super.initState();
    final MotionModel motion = widget.motion;
    if (_loops) {
      _startLoop();
    } else if (widget.animate && motion.hasEntrance && motion.durationMs > 0) {
      _from = motion.entranceStart;
      _run(motion.durationMs);
    }
    _syncSpin();
  }

  /// Animates from [_from] to [_to] over [ms], after the motion's delay.
  void _run(int ms) {
    _delay?.cancel();
    _curve = _to.curve;
    _transition
      ..stop()
      ..duration = Duration(milliseconds: ms)
      ..value = 0;
    void start() {
      if (mounted) _transition.forward(from: 0);
    }

    final int delay = widget.motion.delayMs;
    if (delay > 0) {
      _delay = Timer(Duration(milliseconds: delay), start);
    } else {
      start();
    }
  }

  /// Repeats between rest and the motion's values.
  void _startLoop() {
    _delay?.cancel();
    _from = widget.motion.atRest;
    _to = widget.motion;
    _curve = _to.curve;
    _transition.duration = Duration(milliseconds: widget.motion.durationMs);
    void start() {
      if (!mounted) return;
      _transition.repeat(reverse: widget.motion.loop == MotionLoop.reverse);
    }

    final int delay = widget.motion.delayMs;
    if (delay > 0) {
      _transition.value = 0;
      _delay = Timer(Duration(milliseconds: delay), start);
    } else {
      start();
    }
  }

  @override
  void didUpdateWidget(NodeMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    final MotionModel next = widget.motion;
    final bool replay =
        widget.animate && next.replayKey != oldWidget.motion.replayKey;
    final bool pulse =
        widget.animate &&
        next.hasKeyframes &&
        next.pulseKey != oldWidget.motion.pulseKey;
    if (_loops && replay) {
      _startLoop();
    } else if (replay && next.durationMs > 0) {
      // Plays the entrance again, wherever the node was.
      _from = next.entranceStart;
      _to = next;
      _run(next.durationMs);
    } else if (pulse && !_loops && next.durationMs > 0) {
      // Plays the keyframes once, from wherever the node is to its values
      // (the same, unless they changed too).
      _from = _current;
      _to = next;
      _run(next.durationMs);
    } else if (_loops) {
      final MotionModel old = oldWidget.motion;
      if (!_sameTransform(next, _to) ||
          next.loop != old.loop ||
          next.durationMs != old.durationMs ||
          !_transition.isAnimating && _delay?.isActive != true) {
        _startLoop();
      } else {
        _to = next;
      }
    } else if (!_sameTransform(next, _to) ||
        oldWidget.motion.loop != MotionLoop.none) {
      final ms = widget.animate ? next.durationMs : 0;
      if (ms <= 0) {
        _delay?.cancel();
        _transition.stop();
        _transition.value = 0;
        _from = next;
        _to = next;
      } else {
        // Start from wherever the running transition has got to.
        _from = _current;
        _to = next;
        _run(ms);
      }
    } else {
      // Settings that don't animate (duration, curve, spin) apply at once.
      _from = _from.copyWith(spin: next.spin);
      _to = next;
    }
    _syncSpin();
  }

  static bool _sameTransform(MotionModel a, MotionModel b) =>
      a.translateX == b.translateX &&
      a.translateY == b.translateY &&
      a.scale == b.scale &&
      a.scaleX == b.scaleX &&
      a.scaleY == b.scaleY &&
      a.opacity == b.opacity &&
      a.rotate == b.rotate &&
      a.rotateX == b.rotateX &&
      a.rotateY == b.rotateY &&
      a.perspective == b.perspective &&
      a.originX == b.originX &&
      a.originY == b.originY &&
      a.pathProgress == b.pathProgress &&
      a.path == b.path &&
      a.orientToPath == b.orientToPath &&
      a.backfaceHidden == b.backfaceHidden;

  /// Whether a transition is running or waiting out its delay.
  bool get _moving => _transition.isAnimating || _delay?.isActive == true;

  MotionModel get _current {
    if (!_moving && _transition.value == 0) return _to;
    final double time = _transition.value;
    final double t = flutterCurveOf(_curve).transform(time);
    // A value the keyframes key follows them in time; the others follow
    // the curve.
    double lerp(String p) =>
        MotionModel.keyframedValue(
          _to.keyframes,
          p,
          _from.valueOf(p),
          _to.valueOf(p),
          time,
        ) ??
        _from.valueOf(p) + (_to.valueOf(p) - _from.valueOf(p)) * t;
    return _to.copyWith(
      translateX: lerp('translateX'),
      translateY: lerp('translateY'),
      scale: lerp('scale'),
      scaleX: lerp('scaleX'),
      scaleY: lerp('scaleY'),
      opacity: lerp('opacity').clamp(0, 1).toDouble(),
      rotate: lerp('rotate'),
      rotateX: lerp('rotateX'),
      rotateY: lerp('rotateY'),
      pathProgress: lerp('pathProgress'),
    );
  }

  void _syncSpin() {
    final bool wantsTicker =
        widget.animate && (widget.motion.spin != 0 || _speed != 0);
    if (wantsTicker && _spinTicker == null) {
      _lastTick = Duration.zero;
      _spinTicker = createTicker(_onSpinTick)..start();
    } else if (!widget.animate && _spinTicker != null) {
      _spinTicker!.dispose();
      _spinTicker = null;
      _speed = 0;
    }
  }

  void _onSpinTick(Duration elapsed) {
    final double dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    if (dt <= 0 || dt > 0.25) return;
    final double target = widget.motion.spin;
    final int ramp = widget.motion.spinRampMs;
    if (ramp <= 0) {
      _speed = target;
    } else {
      // Ease toward the target speed, like a belt drive.
      final double k = math.min(1, dt * 3000 / ramp);
      _speed += (target - _speed) * k;
      if ((target - _speed).abs() < 0.002) _speed = target;
    }
    _turns = (_turns + _speed * dt) % 1;
    if (_speed == 0 && target == 0) {
      _spinTicker?.dispose();
      _spinTicker = null;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _delay?.cancel();
    _transition.dispose();
    _spinTicker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Where tickers are off (the editor's design canvas holds still), an
    // entrance or transition would stay at its first frame forever: show
    // the values at rest instead, as the design canvas should.
    final bool still = !TickerMode.valuesOf(context).enabled;
    final MotionModel m = still ? widget.motion : (_moving ? _current : _to);
    if (!m.hasTransform && _turns == 0) return widget.child;
    Widget child = widget.child;
    if (m.backfaceHidden) child = BackfaceHidden(child: child);
    if (m.opacity < 1) {
      // A fully transparent node also stops taking taps, like a hidden one.
      child = IgnorePointer(
        ignoring: m.opacity == 0,
        child: Opacity(opacity: m.opacity, child: child),
      );
    }
    if (m.translateX == 0 &&
        m.translateY == 0 &&
        m.scale == 1 &&
        m.scaleX == 1 &&
        m.scaleY == 1 &&
        m.rotate == 0 &&
        m.rotateX == 0 &&
        m.rotateY == 0 &&
        _turns == 0 &&
        !m.hasPath) {
      return child;
    }
    MotionModel shown = m;
    if (m.hasPath) {
      final (Offset, double)? point = pointOnMotionPath(
        m.path!,
        m.pathProgress,
      );
      if (point != null) {
        final (Offset offset, double angle) = point;
        shown = m.copyWith(
          translateX: m.translateX + offset.dx,
          translateY: m.translateY + offset.dy,
          rotate: m.orientToPath ? m.rotate + angle * 180 / math.pi : null,
        );
      }
    }
    return Transform(
      alignment: Alignment(shown.originX, shown.originY),
      transform: motionMatrix(shown, spinTurns: _turns),
      child: child,
    );
  }
}

/// Paints [child] only while its front faces the viewer, judged by its
/// whole transform to the screen, so a face turned away by its own motion
/// or by any rotating parent disappears (CSS `backface-visibility: hidden`).
/// A hidden face takes no taps either.
class BackfaceHidden extends SingleChildRenderObjectWidget {
  /// Creates a [BackfaceHidden].
  const BackfaceHidden({super.key, super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => RenderBackface();
}

/// The render object of [BackfaceHidden].
class RenderBackface extends RenderProxyBox {
  /// Whether the box's front faces the viewer through [transform], a
  /// transform from the box to the screen: the box's corners keep their
  /// winding (clockwise) when projected.
  static bool facesViewer(Matrix4 transform, Size size) {
    final List<double> m = transform.storage;
    Offset project(double x, double y) {
      final double w = m[3] * x + m[7] * y + m[15];
      final double d = w == 0 ? 1e-9 : w;
      return Offset(
        (m[0] * x + m[4] * y + m[12]) / d,
        (m[1] * x + m[5] * y + m[13]) / d,
      );
    }

    final w = size.width <= 0 ? 1.0 : size.width;
    final h = size.height <= 0 ? 1.0 : size.height;
    final a = project(0, 0);
    final b = project(w, 0);
    final c = project(0, h);
    final double cross =
        (b.dx - a.dx) * (c.dy - a.dy) - (b.dy - a.dy) * (c.dx - a.dx);
    return cross > 0;
  }

  bool get _facing {
    if (!attached) return true;
    try {
      return facesViewer(getTransformTo(null), size);
    } catch (_) {
      return true;
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_facing) super.paint(context, offset);
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) =>
      _facing && super.hitTest(result, position: position);
}
