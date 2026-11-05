import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter, PathMetric, Tangent;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:path_parsing/path_parsing.dart';

import 'viewport_visibility.dart';

/// The Flutter curve for a [MotionCurve].
Curve flutterCurveOf(MotionCurve curve) => switch (curve) {
  MotionCurve.linear => Curves.linear,
  MotionCurve.easeInOut => Curves.easeInOut,
  MotionCurve.easeOut => Curves.easeOut,
  MotionCurve.easeIn => Curves.easeIn,
  MotionCurve.easeOutBack => Curves.easeOutBack,
  MotionCurve.easeOutCubic => Curves.easeOutCubic,
  MotionCurve.easeInOutSine => Curves.easeInOutSine,
  MotionCurve.easeInOutCubic => Curves.easeInOutCubic,
  MotionCurve.spring => const SpringCurve(),
  MotionCurve.elasticOut => Curves.elasticOut,
  MotionCurve.bounceOut => Curves.bounceOut,
  MotionCurve.fastOutSlowIn => Curves.fastOutSlowIn,
  MotionCurve.step => const Threshold(0.5),
};

/// The spring a [MotionCurve.spring] motion runs with.
SpringDescription motionSpring(MotionModel motion) => SpringDescription(
  mass: 1,
  stiffness: motion.springStiffness <= 0 ? 380 : motion.springStiffness,
  damping: motion.springDamping < 0 ? 20 : motion.springDamping,
);

/// How long a transition of [motion] runs, for deciding whether it animates
/// at all: a spring runs at its own pace, whatever its duration.
int motionTransitionMs(MotionModel motion) =>
    motion.curve == MotionCurve.spring ? 1 : motion.durationMs;

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

/// Turns animation of node motion off for the nodes below it: a design
/// canvas or an editor capture, which show every node at rest.
///
/// Below a [NodeMotionScope] whose [animate] is false, a [NodeMotion] acts
/// as with [NodeMotion.animate] false: it shows its values without
/// transitions, entrances, loops or spin, so a
/// [MotionModel.revealOnScroll] node is visible at rest instead of waiting
/// to scroll into view, and a [NodeSizeTransition] jumps to its final size.
class NodeMotionScope extends InheritedWidget {
  /// Creates a [NodeMotionScope].
  const NodeMotionScope({
    super.key,
    required this.animate,
    required super.child,
  });

  /// Whether node motion below animates.
  final bool animate;

  /// Whether node motion animates at [context]: false below a
  /// [NodeMotionScope] that turns it off, else true.
  static bool animatesAt(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<NodeMotionScope>()?.animate ??
      true;

  @override
  bool updateShouldNotify(NodeMotionScope oldWidget) =>
      animate != oldWidget.animate;
}

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
/// [MotionModel.durationMs]. When [animate] is false, or its tickers are
/// muted (the design canvas runs under a disabled [TickerMode]), it jumps to
/// them and doesn't spin: a transition would otherwise never advance and the
/// node would stay where it started.
///
/// A [MotionModel.revealOnScroll] motion holds the node where its entrance
/// starts until [MotionModel.revealFraction] of it is in view, then plays
/// the entrance once.
class NodeMotion extends StatelessWidget {
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

  /// Whether [MotionModel.revealOnScroll] entrances wait for their node to
  /// scroll into view. Set it to false to show such nodes at rest at once,
  /// for example to take deterministic screenshots of a whole page.
  static bool revealsEnabled = true;

  @override
  Widget build(BuildContext context) => _NodeMotionBody(
    motion: motion,
    animate: animate && NodeMotionScope.animatesAt(context),
    child: child,
  );
}

/// [NodeMotion] with its [NodeMotionScope] applied.
class _NodeMotionBody extends StatefulWidget {
  const _NodeMotionBody({
    required this.motion,
    required this.child,
    required this.animate,
  });

  final MotionModel motion;
  final bool animate;
  final Widget child;

  @override
  State<_NodeMotionBody> createState() => _NodeMotionState();
}

class _NodeMotionState extends State<_NodeMotionBody>
    with TickerProviderStateMixin {
  late final AnimationController _transition = AnimationController(vsync: this)
    ..addListener(_rebuild);

  /// Runs a [MotionCurve.spring] transition: 0 at its start, 1 at rest,
  /// overshooting past 1 on the way.
  late final AnimationController _spring = AnimationController.unbounded(
    vsync: this,
    value: 1,
  )..addListener(_rebuild);
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

  /// Whether a counted loop has played all its times: the node rests.
  bool _rested = false;

  /// Whether the node holds at its entrance start until it scrolls into
  /// view; see [MotionModel.revealOnScroll].
  bool _awaitingReveal = false;

  /// Keeps the node's widget (and its state) when the transform around it
  /// comes and goes.
  final GlobalKey _childKey = GlobalKey();

  void _rebuild() => setState(() {});

  /// Whether changes animate: [NodeMotion.animate], with tickers running.
  bool get _animates => widget.animate && TickerMode.getNotifier(context).value;

  /// Whether tickers ran at the last dependency change: when they stop (a
  /// capture of the design canvas) a running transition settles at its end.
  bool _tickersEnabled = true;

  bool get _loops =>
      _animates &&
      widget.motion.loop != MotionLoop.none &&
      widget.motion.durationMs > 0;

  @override
  void initState() {
    super.initState();
    final MotionModel motion = widget.motion;
    if (_loops) {
      _startLoop();
    } else if (_revealsOnScroll(motion)) {
      _from = motion.entranceStart;
      _awaitingReveal = true;
    } else if (_animates &&
        motion.hasEntrance &&
        !motion.revealOnScroll &&
        motionTransitionMs(motion) > 0) {
      _from = motion.entranceStart;
      _run(motionTransitionMs(motion));
    }
    _syncSpin();
  }

  /// Whether [motion] waits to scroll into view before its entrance.
  bool _revealsOnScroll(MotionModel motion) =>
      _animates &&
      motion.revealOnScroll &&
      motionTransitionMs(motion) > 0 &&
      NodeMotion.revealsEnabled;

  /// Plays the entrance once enough of the node is in view.
  void _onVisibility(double fraction) {
    if (!_awaitingReveal) return;
    final MotionModel motion = widget.motion;
    if (!meetsVisibleFraction(fraction, motion.revealFraction)) return;
    _awaitingReveal = false;
    _from = motion.entranceStart;
    _to = motion;
    _run(motionTransitionMs(motion));
    setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool enabled = TickerMode.valuesOf(context).enabled;
    if (enabled == _tickersEnabled) return;
    _tickersEnabled = enabled;
    if (!enabled && !_loops) _settle();
  }

  /// Ends any transition or entrance at once, at the values to show.
  void _settle() {
    _delay?.cancel();
    _transition
      ..stop()
      ..value = 0;
    _from = widget.motion;
    _to = widget.motion;
  }

  /// Animates from [_from] to [_to] over [ms], after the motion's delay.
  void _run(int ms) {
    _delay?.cancel();
    _curve = _to.curve;
    _transition
      ..stop()
      ..duration = Duration(milliseconds: ms)
      ..value = 0;
    final bool spring = widget.motion.curve == MotionCurve.spring;
    _spring
      ..stop()
      ..value = spring ? 0 : 1;
    void start() {
      if (!mounted) return;
      if (spring) {
        _spring.animateWith(
          SpringSimulation(motionSpring(widget.motion), 0, 1, 0),
        );
      } else {
        _transition.forward(from: 0);
      }
    }

    final int delay = widget.motion.delayMs;
    if (delay > 0) {
      _delay = Timer(Duration(milliseconds: delay), start);
    } else {
      start();
    }
  }

  /// Repeats between the loop's start (rest, or what
  /// [MotionModel.enterFrom] gives) and the motion's values.
  void _startLoop() {
    _delay?.cancel();
    _rested = false;
    _from = widget.motion.loopStart;
    _to = widget.motion;
    _curve = _to.curve;
    _transition.duration = Duration(milliseconds: widget.motion.durationMs);
    // A loop with a phase starts that far through its cycle; repeat carries
    // on from there.
    _transition.value = widget.motion.phase.clamp(0.0, 1.0);
    void start() {
      // A paused loop waits at its start until it is resumed.
      if (!mounted || widget.motion.paused) return;
      final bool reverse = widget.motion.loop == MotionLoop.reverse;
      final int repeat = widget.motion.repeat;
      if (repeat <= 0) {
        _transition.repeat(reverse: reverse);
        return;
      }
      // A counted loop comes to rest when it is done; a reverse loop counts
      // each way, so one time is there and back.
      _transition
          .repeat(reverse: reverse, count: reverse ? repeat * 2 : repeat)
          .then((_) {
            if (mounted) {
              setState(() {
                _transition.value = 0;
                _rested = true;
              });
            }
          }, onError: (_) {});
    }

    final int delay = widget.motion.delayMs;
    if (delay > 0) {
      _delay = Timer(Duration(milliseconds: delay), start);
    } else {
      start();
    }
  }

  @override
  void didUpdateWidget(_NodeMotionBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    final MotionModel next = widget.motion;
    if (_awaitingReveal) {
      // Still out of view: follow the new values without moving.
      if (_revealsOnScroll(next)) {
        _from = next.entranceStart;
      } else {
        _awaitingReveal = false;
        _from = next;
      }
      _to = next;
      _syncSpin();
      return;
    }
    final bool replay =
        _animates && next.replayKey != oldWidget.motion.replayKey;
    final bool pulse =
        _animates &&
        next.hasKeyframes &&
        next.pulseKey != oldWidget.motion.pulseKey;
    if (_loops && !replay && next.paused != oldWidget.motion.paused) {
      // Freezes the loop where it is, or carries on from there.
      _to = next;
      if (next.paused) {
        _delay?.cancel();
        _transition.stop();
      } else if (_delay?.isActive != true) {
        _transition.repeat(reverse: next.loop == MotionLoop.reverse);
      }
    } else if (_loops && replay) {
      _startLoop();
    } else if (replay && motionTransitionMs(next) > 0) {
      // Plays the entrance again, wherever the node was.
      _from = next.entranceStart;
      _to = next;
      _run(motionTransitionMs(next));
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
          next.repeat != old.repeat ||
          next.durationMs != old.durationMs ||
          next.phase != old.phase ||
          !next.paused &&
              !_transition.isAnimating &&
              _delay?.isActive != true) {
        _startLoop();
      } else {
        _to = next;
      }
    } else if (!_sameTransform(next, _to) ||
        oldWidget.motion.loop != MotionLoop.none) {
      final ms = _animates ? motionTransitionMs(next) : 0;
      if (ms <= 0) {
        _delay?.cancel();
        _transition.stop();
        _transition.value = 0;
        _spring
          ..stop()
          ..value = 1;
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
      a.shiftX == b.shiftX &&
      a.shiftY == b.shiftY &&
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
      a.blur == b.blur &&
      a.pathProgress == b.pathProgress &&
      a.path == b.path &&
      a.orientToPath == b.orientToPath &&
      a.backfaceHidden == b.backfaceHidden;

  /// Whether a transition is running or waiting out its delay.
  bool get _moving =>
      _transition.isAnimating ||
      _spring.isAnimating ||
      _delay?.isActive == true;

  MotionModel get _current {
    final bool spring = _spring.isAnimating || _spring.value != 1;
    if (!_moving && _transition.value == 0 && !spring) {
      // A loop paused before it started sits at its start.
      return _loops && widget.motion.paused ? _from : _to;
    }
    // A spring runs on real physics (and may overshoot past 1); a curve on
    // the transition's time.
    final double time = spring
        ? _spring.value.clamp(0.0, 1.0)
        : _transition.value;
    final double t = spring
        ? _spring.value
        : flutterCurveOf(_curve).transform(time);
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
      shiftX: lerp('shiftX'),
      shiftY: lerp('shiftY'),
      scale: lerp('scale'),
      scaleX: lerp('scaleX'),
      scaleY: lerp('scaleY'),
      opacity: lerp('opacity').clamp(0, 1).toDouble(),
      rotate: lerp('rotate'),
      rotateX: lerp('rotateX'),
      rotateY: lerp('rotateY'),
      blur: math.max(0, lerp('blur')),
      pathProgress: lerp('pathProgress'),
    );
  }

  void _syncSpin() {
    final bool wantsTicker =
        _animates && (widget.motion.spin != 0 || _speed != 0);
    if (wantsTicker && _spinTicker == null) {
      _lastTick = Duration.zero;
      _spinTicker = createTicker(_onSpinTick)..start();
    } else if (!_animates && _spinTicker != null) {
      _spinTicker!.dispose();
      _spinTicker = null;
      _speed = 0;
    }
  }

  void _onSpinTick(Duration elapsed) {
    final double dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    if (dt <= 0 || dt > 0.25) return;
    // A paused motion's spin winds down and stops.
    final double target = widget.motion.paused ? 0 : widget.motion.spin;
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
    if (_speed == 0 && widget.motion.spin == 0) {
      _spinTicker?.dispose();
      _spinTicker = null;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _delay?.cancel();
    _transition.dispose();
    _spring.dispose();
    _spinTicker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Where tickers are off (the editor's design canvas holds still), an
    // entrance or transition would stay at its first frame forever: show
    // the values at rest instead, as the design canvas should.
    final bool still = !TickerMode.valuesOf(context).enabled;
    // A loop that ran its [MotionModel.repeat] runs rests.
    final MotionModel m = still
        ? widget.motion
        : _awaitingReveal
        ? _from
        : _rested && _loops
        ? _to.atRest
        // A paused loop holds wherever it stopped.
        : (_moving || _loops && widget.motion.paused ? _current : _to);
    final Widget drawn = _draw(m);
    if (still || !widget.animate || !widget.motion.revealOnScroll) {
      return drawn;
    }
    return ViewportVisibility(
      enabled: _awaitingReveal,
      onChanged: _onVisibility,
      child: drawn,
    );
  }

  /// The node's widget drawn with the values of [m].
  Widget _draw(MotionModel m) {
    Widget child = KeyedSubtree(key: _childKey, child: widget.child);
    if (!m.hasTransform && _turns == 0) return child;
    if (m.backfaceHidden) child = BackfaceHidden(child: child);
    if (m.opacity < 1) {
      // A fully transparent node also stops taking taps, like a hidden one.
      child = IgnorePointer(
        ignoring: m.opacity == 0,
        child: Opacity(opacity: m.opacity, child: child),
      );
    }
    if (m.blur > 0) {
      child = ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: m.blur, sigmaY: m.blur),
        child: child,
      );
    }
    // Shifts move by the node's own size, whatever size it got (paint only,
    // like the transform: taps go where the node was laid out).
    Widget shifted(Widget child) => m.shiftX == 0 && m.shiftY == 0
        ? child
        : FractionalTranslation(
            translation: Offset(m.shiftX, m.shiftY),
            child: child,
          );
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
      return shifted(child);
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
    return shifted(
      Transform(
        alignment: Alignment(shown.originX, shown.originY),
        transform: motionMatrix(shown, spinTurns: _turns),
        child: child,
      ),
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

/// How long an implicit transition of [ms] milliseconds (a `transitionMs`
/// fill or opacity, a drawScale change) runs where it builds: zero under a
/// disabled [TickerMode] (the editor's design canvas and its captures),
/// where the transition could never tick and would hold the old value, so
/// it jumps to the new one instead. Unchanged where tickers run.
Duration implicitTransitionDuration(BuildContext context, int ms) =>
    TickerMode.valuesOf(context).enabled
    ? Duration(milliseconds: ms)
    : Duration.zero;
