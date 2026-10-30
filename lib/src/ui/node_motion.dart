import 'dart:async';
import 'dart:math' as math;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'viewport_visibility.dart';

/// The Flutter curve for a [MotionCurve].
Curve flutterCurveOf(MotionCurve curve) => switch (curve) {
  MotionCurve.linear => Curves.linear,
  MotionCurve.easeInOut => Curves.easeInOut,
  MotionCurve.easeOut => Curves.easeOut,
  MotionCurve.easeIn => Curves.easeIn,
  MotionCurve.easeOutBack => Curves.easeOutBack,
  MotionCurve.easeOutCubic => Curves.easeOutCubic,
};

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
///
/// A [MotionModel.revealOnScroll] motion holds the node where its entrance
/// starts until [MotionModel.revealFraction] of it is in view, then plays
/// the entrance once.
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

  /// Whether [MotionModel.revealOnScroll] entrances wait for their node to
  /// scroll into view. Set it to false to show such nodes at rest at once,
  /// for example to take deterministic screenshots of a whole page.
  static bool revealsEnabled = true;

  @override
  State<NodeMotion> createState() => _NodeMotionState();
}

class _NodeMotionState extends State<NodeMotion> with TickerProviderStateMixin {
  late final AnimationController _transition = AnimationController(vsync: this)
    ..addListener(_rebuild);
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

  /// Whether the node holds at its entrance start until it scrolls into
  /// view; see [MotionModel.revealOnScroll].
  bool _awaitingReveal = false;

  /// Keeps the node's widget (and its state) when the transform around it
  /// comes and goes.
  final GlobalKey _childKey = GlobalKey();

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
    } else if (_revealsOnScroll(motion)) {
      _from = motion.entranceStart;
      _awaitingReveal = true;
    } else if (widget.animate &&
        motion.hasEntrance &&
        !motion.revealOnScroll &&
        motion.durationMs > 0) {
      _from = motion.entranceStart;
      _run(motion.durationMs);
    }
    _syncSpin();
  }

  /// Whether [motion] waits to scroll into view before its entrance.
  bool _revealsOnScroll(MotionModel motion) =>
      widget.animate &&
      motion.revealOnScroll &&
      motion.durationMs > 0 &&
      NodeMotion.revealsEnabled;

  /// Plays the entrance once enough of the node is in view.
  void _onVisibility(double fraction) {
    if (!_awaitingReveal) return;
    final MotionModel motion = widget.motion;
    if (!meetsVisibleFraction(fraction, motion.revealFraction)) return;
    _awaitingReveal = false;
    _from = motion.entranceStart;
    _to = motion;
    _run(motion.durationMs);
    setState(() {});
  }

  /// Animates from [_from] to [_to] over [ms], after the motion's delay.
  void _run(int ms) {
    _delay?.cancel();
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
        widget.animate && next.replayKey != oldWidget.motion.replayKey;
    if (_loops && replay) {
      _startLoop();
    } else if (replay && next.durationMs > 0) {
      // Plays the entrance again, wherever the node was.
      _from = next.entranceStart;
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
      a.opacity == b.opacity &&
      a.rotate == b.rotate &&
      a.rotateX == b.rotateX &&
      a.rotateY == b.rotateY &&
      a.perspective == b.perspective &&
      a.originX == b.originX &&
      a.originY == b.originY;

  /// Whether a transition is running or waiting out its delay.
  bool get _moving => _transition.isAnimating || _delay?.isActive == true;

  MotionModel get _current {
    if (!_moving && _transition.value == 0) return _to;
    final double t = flutterCurveOf(_to.curve).transform(_transition.value);
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
    _spinTicker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final MotionModel m = _awaitingReveal
        ? _from
        : _moving
        ? _current
        : _to;
    final Widget drawn = _draw(m);
    if (!widget.animate || !widget.motion.revealOnScroll) return drawn;
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
