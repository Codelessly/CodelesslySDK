import 'dart:math' as math;

import 'package:codelessly_api/codelessly_api.dart';
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

  Ticker? _spinTicker;
  Duration _lastTick = Duration.zero;

  /// Current spin speed and angle, in turns per second and turns.
  double _speed = 0;
  double _turns = 0;

  void _rebuild() => setState(() {});

  @override
  void initState() {
    super.initState();
    _syncSpin();
  }

  @override
  void didUpdateWidget(NodeMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    final MotionModel next = widget.motion;
    if (!_sameTransform(next, _to)) {
      final ms = widget.animate ? next.durationMs : 0;
      if (ms <= 0) {
        _transition.stop();
        _from = next;
        _to = next;
      } else {
        // Start from wherever the running transition has got to.
        _from = _current;
        _to = next;
        _transition
          ..duration = Duration(milliseconds: ms)
          ..forward(from: 0);
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

  MotionModel get _current {
    if (!_transition.isAnimating && _transition.value == 0) return _to;
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
    _transition.dispose();
    _spinTicker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final MotionModel m = _transition.isAnimating ? _current : _to;
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
