import 'dart:async';
import 'dart:math' as math;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// The Flutter curve for a [MotionCurve].
Curve flutterCurveOf(MotionCurve curve) => switch (curve) {
  MotionCurve.linear => Curves.linear,
  MotionCurve.easeInOut => Curves.easeInOut,
  MotionCurve.easeOut => Curves.easeOut,
  MotionCurve.easeIn => Curves.easeIn,
  MotionCurve.easeOutBack => Curves.easeOutBack,
  MotionCurve.easeOutCubic => Curves.easeOutCubic,
  // Where a spring can't run as physics (a loop), it overshoots once.
  MotionCurve.spring => Curves.easeOutBack,
  MotionCurve.elasticOut => Curves.elasticOut,
  MotionCurve.bounceOut => Curves.bounceOut,
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

/// The transform [motion] draws, without spin, around [origin] in a box of
/// [size]. [spinTurns] adds a spin angle.
Matrix4 motionMatrix(MotionModel motion, {double spinTurns = 0}) {
  final matrix = Matrix4.identity();
  if (motion.perspective > 0 && (motion.rotateX != 0 || motion.rotateY != 0)) {
    matrix.setEntry(3, 2, 0.0012 * motion.perspective);
  }
  matrix
    ..translateByDouble(motion.translateX, motion.translateY, 0, 1)
    ..scaleByDouble(motion.scale, motion.scale, 1, 1)
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

  /// Runs a [MotionCurve.spring] transition: 0 at its start, 1 at rest,
  /// overshooting past 1 on the way.
  late final AnimationController _spring = AnimationController.unbounded(
    vsync: this,
    value: 1,
  )..addListener(_rebuild);
  late MotionModel _from = widget.motion;
  late MotionModel _to = widget.motion;

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
    } else if (widget.animate &&
        motion.hasEntrance &&
        motionTransitionMs(motion) > 0) {
      _from = motion.entranceStart;
      _run(motionTransitionMs(motion));
    }
    _syncSpin();
  }

  /// Animates from [_from] to [_to] over [ms], after the motion's delay.
  void _run(int ms) {
    _delay?.cancel();
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

  /// Repeats between rest and the motion's values.
  void _startLoop() {
    _delay?.cancel();
    _from = widget.motion.atRest;
    _to = widget.motion;
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
    if (_loops && replay) {
      _startLoop();
    } else if (replay && motionTransitionMs(next) > 0) {
      // Plays the entrance again, wherever the node was.
      _from = next.entranceStart;
      _to = next;
      _run(motionTransitionMs(next));
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
      final ms = widget.animate ? motionTransitionMs(next) : 0;
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
      a.scale == b.scale &&
      a.opacity == b.opacity &&
      a.rotate == b.rotate &&
      a.rotateX == b.rotateX &&
      a.rotateY == b.rotateY &&
      a.perspective == b.perspective &&
      a.originX == b.originX &&
      a.originY == b.originY;

  /// Whether a transition is running or waiting out its delay.
  bool get _moving =>
      _transition.isAnimating ||
      _spring.isAnimating ||
      _delay?.isActive == true;

  MotionModel get _current {
    final bool spring = _spring.isAnimating || _spring.value != 1;
    if (!_moving && _transition.value == 0 && !spring) return _to;
    final double t = spring
        ? _spring.value
        : flutterCurveOf(_to.curve).transform(_transition.value);
    double lerp(String p) =>
        _from.valueOf(p) + (_to.valueOf(p) - _from.valueOf(p)) * t;
    return _to.copyWith(
      translateX: lerp('translateX'),
      translateY: lerp('translateY'),
      scale: lerp('scale'),
      opacity: lerp('opacity').clamp(0, 1).toDouble(),
      rotate: lerp('rotate'),
      rotateX: lerp('rotateX'),
      rotateY: lerp('rotateY'),
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
    _spring.dispose();
    _spinTicker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final MotionModel m = _moving ? _current : _to;
    if (!m.hasTransform && _turns == 0) return widget.child;
    Widget child = widget.child;
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
        m.rotate == 0 &&
        m.rotateX == 0 &&
        m.rotateY == 0 &&
        _turns == 0) {
      return child;
    }
    return Transform(
      alignment: Alignment(m.originX, m.originY),
      transform: motionMatrix(m, spinTurns: _turns),
      child: child,
    );
  }
}
