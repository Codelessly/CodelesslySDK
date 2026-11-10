import 'dart:async';
import 'dart:math' as math;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/widgets.dart';

/// Runs a node's [LoopAnimation] on [child] over and over: it scales and
/// fades [child] for [LoopAnimationType.pulse], fades it for
/// [LoopAnimationType.fade], scales it for [LoopAnimationType.scale],
/// rotates it for [LoopAnimationType.spin], about its center, hops it for
/// [LoopAnimationType.bob] and rocks it for [LoopAnimationType.sway].
///
/// The animation runs on this widget's ticker, so it holds still at its
/// `from` values under a disabled [TickerMode], as on the editor's design
/// canvas. When [enabled] is false, [child] shows as designed; the widgets
/// around it stay the same, so turning the animation on and off keeps the
/// state of [child].
class LoopAnimationBox extends StatefulWidget {
  /// The animation to run.
  final LoopAnimation animation;

  /// Whether the animation runs. Defaults to [LoopAnimation.enabled].
  final bool? enabled;

  /// The widget to animate.
  final Widget child;

  /// Creates a [LoopAnimationBox].
  const LoopAnimationBox({
    super.key,
    required this.animation,
    this.enabled,
    required this.child,
  });

  /// The Flutter curve of [curve].
  static Curve curveOf(LoopAnimationCurve curve) => switch (curve) {
    LoopAnimationCurve.linear => Curves.linear,
    LoopAnimationCurve.easeIn => Curves.easeIn,
    LoopAnimationCurve.easeOut => Curves.easeOut,
    LoopAnimationCurve.easeInOut => Curves.easeInOut,
    LoopAnimationCurve.fastOutSlowIn => Curves.fastOutSlowIn,
    LoopAnimationCurve.decelerate => Curves.decelerate,
  };

  @override
  State<LoopAnimationBox> createState() => _LoopAnimationBoxState();
}

class _LoopAnimationBoxState extends State<LoopAnimationBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(vsync: this);

  /// Waits for [LoopAnimation.delayMs] before the first cycle.
  Timer? delay;

  late Animation<double> scale;
  late Animation<double> opacity;
  late Animation<double> turns;

  bool get enabled => widget.enabled ?? widget.animation.enabled;

  @override
  void initState() {
    super.initState();
    update();
  }

  @override
  void didUpdateWidget(covariant LoopAnimationBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool wasEnabled = oldWidget.enabled ?? oldWidget.animation.enabled;
    if (oldWidget.animation != widget.animation || wasEnabled != enabled) {
      update();
    }
  }

  /// Builds the animations of [LoopAnimationBox.animation] and starts it
  /// over, or stops it when it is disabled.
  void update() {
    delay?.cancel();
    delay = null;
    controller.reset();

    final LoopAnimation animation = widget.animation;
    if (!enabled) {
      scale = opacity = const AlwaysStoppedAnimation<double>(1);
      turns = const AlwaysStoppedAnimation<double>(0);
      return;
    }

    final Animation<double> curved = CurvedAnimation(
      parent: controller,
      curve: LoopAnimationBox.curveOf(animation.curve),
    );
    final LoopAnimationType type = animation.type;
    scale = type.scales
        ? Tween<double>(
            begin: animation.scaleFrom,
            end: animation.scaleTo,
          ).animate(curved)
        : const AlwaysStoppedAnimation<double>(1);
    opacity = type.fades
        ? Tween<double>(
            begin: animation.opacityFrom.clamp(0, 1),
            end: animation.opacityTo.clamp(0, 1),
          ).animate(curved)
        : const AlwaysStoppedAnimation<double>(1);
    turns = type == LoopAnimationType.spin
        ? Tween<double>(begin: 0, end: animation.turns).animate(curved)
        : const AlwaysStoppedAnimation<double>(0);

    controller.duration = Duration(
      milliseconds: animation.durationMs.clamp(1, 1 << 31),
    );
    if (animation.delayMs > 0) {
      delay = Timer(Duration(milliseconds: animation.delayMs), start);
    } else {
      start();
    }
  }

  void start() {
    if (!mounted) return;
    controller.repeat(reverse: widget.animation.reverse);
  }

  @override
  void dispose() {
    delay?.cancel();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Only the transitions of the animation's type wrap the child, so a
    // node that just spins doesn't pay for an opacity layer.
    Widget child = widget.child;
    final LoopAnimationType type = widget.animation.type;
    if (type == LoopAnimationType.spin) {
      child = RotationTransition(turns: turns, child: child);
    }
    if (type.scales) {
      child = ScaleTransition(scale: scale, child: child);
    }
    if (type.fades) {
      child = FadeTransition(opacity: opacity, child: child);
    }
    if (enabled &&
        (type == LoopAnimationType.bob || type == LoopAnimationType.sway)) {
      final LoopAnimation animation = widget.animation;
      final Curve curve = LoopAnimationBox.curveOf(animation.curve);
      child = AnimatedBuilder(
        animation: controller,
        child: child,
        builder: (context, child) {
          final double t = curve.transform(controller.value);
          // One hop per cycle: up and back down, like a bouncing ball.
          if (type == LoopAnimationType.bob) {
            return Transform.translate(
              offset: Offset(0, -math.sin(t * math.pi) * animation.distance),
              child: child,
            );
          }
          // One full swing per cycle: right, back, left, back.
          return Transform.rotate(
            angle: math.sin(t * 2 * math.pi) * animation.angle * math.pi / 180,
            child: child,
          );
        },
      );
    }
    return child;
  }
}
