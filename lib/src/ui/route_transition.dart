import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../utils/extensions.dart';
import 'node_motion.dart';

/// PROVISIONAL INTERFACE (see [TransitionSpring]): the physics an
/// interactive transition settles with once it is let go. The Gestures
/// project's shared physics model replaces this adapter when it lands; until
/// then every interactive transition (route dismissal, swipe-back, a card
/// flip pulled halfway) goes through here, so the swap touches one place.
abstract final class TransitionPhysics {
  /// [spring] as a Flutter [SpringDescription].
  static SpringDescription describe(TransitionSpring spring) =>
      SpringDescription(
        mass: spring.mass <= 0 ? 1 : spring.mass,
        stiffness: spring.stiffness <= 0 ? 1 : spring.stiffness,
        damping: spring.damping < 0 ? 0 : spring.damping,
      );

  /// The simulation that settles a progress (0 to 1) at [from] moving at
  /// [velocity] (progress per second) on [to].
  static Simulation settle(
    TransitionSpring spring, {
    required double from,
    required double to,
    required double velocity,
  }) => SpringSimulation(
    describe(spring),
    from,
    to,
    velocity,
    tolerance: const Tolerance(distance: 0.001, velocity: 0.01),
  );

  /// Whether a release at [progress] (0 at rest, 1 fully dragged) moving
  /// at [velocity] (logical pixels per second toward the commit way)
  /// commits: past [distance] of the way, or a fling faster than
  /// [flingVelocity] toward it. A fling the other way always cancels.
  static bool commits({
    required double progress,
    required double velocity,
    required double distance,
    required double flingVelocity,
  }) {
    if (velocity.abs() >= flingVelocity) return velocity > 0;
    return progress >= distance;
  }
}

/// [value] of [base] (at rest for [amount] 0) moved [amount] of the way to
/// [target]'s values. Origin and perspective are [target]'s.
MotionModel motionTowards(MotionModel target, double amount) {
  const MotionModel rest = MotionModel.none;
  double v(String p) =>
      rest.valueOf(p) + (target.valueOf(p) - rest.valueOf(p)) * amount;
  return target.copyWith(
    translateX: v('translateX'),
    translateY: v('translateY'),
    shiftX: v('shiftX'),
    shiftY: v('shiftY'),
    scale: v('scale'),
    scaleX: v('scaleX'),
    scaleY: v('scaleY'),
    opacity: v('opacity').clamp(0, 1).toDouble(),
    rotate: v('rotate'),
    rotateX: v('rotateX'),
    rotateY: v('rotateY'),
    blur: math.max(0, v('blur')),
  );
}

/// Where a [TransitionReveal] grows from, measured when the transition
/// starts: the tap point and the box of the node that navigated.
class RevealAnchor {
  /// The last pointer-down position, in global coordinates.
  final Offset? tap;

  /// The navigating node's box, in global coordinates.
  final Rect? node;

  /// Creates a [RevealAnchor].
  const RevealAnchor({this.tap, this.node});

  /// The last place anything was touched or clicked, in global
  /// coordinates, recorded by [RevealAnchor.track].
  static Offset? lastTap;

  static bool _tracking = false;

  /// Starts recording [lastTap]. Safe to call any number of times.
  static void track() {
    if (_tracking) return;
    _tracking = true;
    GestureBinding.instance.pointerRouter.addGlobalRoute((event) {
      if (event is PointerDownEvent) lastTap = event.position;
    });
  }

  /// The anchor of a navigation run from [context]: the last tap, and
  /// [context]'s box when it has one.
  factory RevealAnchor.of(BuildContext? context) {
    Rect? node;
    final RenderObject? box = context != null && context.mounted
        ? context.findRenderObject()
        : null;
    if (box is RenderBox && box.hasSize && box.attached) {
      node = box.localToGlobal(Offset.zero) & box.size;
    }
    return RevealAnchor(tap: lastTap, node: node);
  }
}

/// Draws a screen as one [TransitionSide] has it at [amount]: 0 at rest,
/// 1 fully at the side's values (a reveal fully closed).
class TransitionSideView extends StatelessWidget {
  /// The side.
  final TransitionSide side;

  /// How far toward the side's values, 0 to 1.
  final double amount;

  /// Where a reveal grows from.
  final RevealAnchor anchor;

  /// The screen.
  final Widget child;

  /// Creates a [TransitionSideView].
  const TransitionSideView({
    super.key,
    required this.side,
    required this.amount,
    this.anchor = const RevealAnchor(),
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (amount <= 0 || side.isStill) return child;
    final MotionModel m = motionTowards(side.motion, amount);
    Widget out = child;
    if (m.opacity < 1) {
      out = IgnorePointer(
        ignoring: m.opacity == 0,
        child: Opacity(opacity: m.opacity, child: out),
      );
    }
    if (m.blur > 0) {
      out = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: m.blur, sigmaY: m.blur),
        child: out,
      );
    }
    if (m.hasTransform) {
      out = Transform(
        alignment: Alignment(m.originX, m.originY),
        transform: motionMatrix(m),
        child: out,
      );
    }
    if (m.shiftX != 0 || m.shiftY != 0) {
      out = FractionalTranslation(
        translation: Offset(m.shiftX, m.shiftY),
        child: out,
      );
    }
    final TransitionReveal? reveal = side.reveal;
    if (reveal != null) {
      out = ClipPath(
        clipper: _RevealClipper(
          reveal: reveal,
          closed: amount,
          anchor: anchor,
          origin: _globalOrigin(context),
        ),
        child: out,
      );
    }
    return out;
  }

  /// This view's top left on screen, to turn global anchors local.
  Offset _globalOrigin(BuildContext context) {
    final RenderObject? box = context.findRenderObject();
    if (box is RenderBox && box.hasSize && box.attached) {
      return box.localToGlobal(Offset.zero);
    }
    return Offset.zero;
  }
}

class _RevealClipper extends CustomClipper<Path> {
  _RevealClipper({
    required this.reveal,
    required this.closed,
    required this.anchor,
    required this.origin,
  });

  final TransitionReveal reveal;

  /// 1 fully closed, 0 fully open.
  final double closed;
  final RevealAnchor anchor;
  final Offset origin;

  @override
  Path getClip(Size size) {
    final Rect screen = Offset.zero & size;
    Offset center = screen.center;
    Rect? start;
    switch (reveal.origin) {
      case RevealOrigin.tap:
        if (anchor.tap != null) center = anchor.tap! - origin;
      case RevealOrigin.node:
        if (anchor.node != null) {
          start = anchor.node!.shift(-origin);
          center = start.center;
        } else if (anchor.tap != null) {
          center = anchor.tap! - origin;
        }
      case RevealOrigin.center:
        break;
      case RevealOrigin.point:
        center = Alignment(reveal.x, reveal.y).withinRect(screen);
    }
    final double open = 1 - closed.clamp(0.0, 1.0);
    if (reveal.shape == RevealShape.circle) {
      // The radius that covers the farthest corner from the centre.
      final double far = [
        screen.topLeft,
        screen.topRight,
        screen.bottomLeft,
        screen.bottomRight,
      ].map((corner) => (corner - center).distance).reduce(math.max);
      final double from = math.max(
        reveal.startRadius,
        start == null ? 0 : start.shortestSide / 2,
      );
      final double radius = from + (far - from) * open;
      return Path()..addOval(Rect.fromCircle(center: center, radius: radius));
    }
    final Rect from =
        start ??
        Rect.fromCenter(
          center: center,
          width: reveal.startRadius * 2,
          height: reveal.startRadius * 2,
        );
    return Path()..addRect(Rect.lerp(from, screen, open)!);
  }

  @override
  bool shouldReclip(_RevealClipper old) =>
      old.closed != closed ||
      old.reveal != reveal ||
      old.origin != origin ||
      old.anchor != anchor;
}

/// The amount of [side] (0 at rest, 1 at its values) at [time], a share of
/// the transition from 0 to 1, given the whole transition's [totalMs].
///
/// With [linear] the side's curve is left out, so a screen a drag moves
/// stays under the finger.
double sideAmountAt(
  TransitionSide side,
  double time, {
  required int totalMs,
  required bool entering,
  bool linear = false,
}) {
  final (double begin, double end) = side.interval(totalMs);
  final double local = end <= begin
      ? (time >= end ? 1 : 0)
      : ((time - begin) / (end - begin)).clamp(0.0, 1.0);
  final double eased = linear
      ? local
      : side.curve == MotionCurve.spring
      ? Curves.easeOutBack.transform(local)
      : flutterCurveOf(side.curve).transform(local);
  // An entering side starts at its values and comes to rest.
  return entering ? 1 - eased : eased;
}

/// A screen (or modal) shown with a [RouteTransition]: the incoming screen
/// plays its entering side, the screen it covers plays the leaving side
/// (through Flutter's [ModalRoute.delegatedTransition], whatever kind of
/// route that screen is), and closing plays them back. Shared elements fly
/// because this is a [PageRoute], modals included. A drag can close it
/// interactively ([RouteTransition.dismiss], [RouteTransition.swipeBack]).
class CodelesslyRouteTransitionRoute<T> extends PageRoute<T> {
  /// The transition, resolved ([RouteTransition.resolved]).
  final RouteTransition transition;

  /// Builds the screen.
  final WidgetBuilder builder;

  /// Where reveals grow from.
  final RevealAnchor anchor;

  /// Whether tapping the barrier closes it (modals).
  final bool dismissibleBarrier;

  /// Color drawn behind the route when [transition] gives none (modals).
  final Color? fallbackBarrierColor;

  /// Whether this is a modal over a screen rather than a screen.
  final bool modal;

  /// Creates a [CodelesslyRouteTransitionRoute].
  CodelesslyRouteTransitionRoute({
    required RouteTransition transition,
    required this.builder,
    this.anchor = const RevealAnchor(),
    this.dismissibleBarrier = false,
    this.fallbackBarrierColor,
    this.modal = false,
    super.settings,
  }) : transition = transition.resolved {
    RevealAnchor.track();
  }

  bool _popping = false;
  bool _interactive = false;

  /// Whether a drag is moving the transition now, or let it go and it is
  /// still settling.
  bool get interactive => _interactive;

  @override
  Duration get transitionDuration =>
      Duration(milliseconds: transition.resolvedDurationMs);

  @override
  Duration get reverseTransitionDuration =>
      Duration(milliseconds: transition.resolvedReverseDurationMs);

  @override
  bool get opaque => !modal && (transition.opaque ?? true);

  @override
  bool get maintainState => true;

  @override
  Color? get barrierColor =>
      transition.barrierColor?.toFlutterColor() ?? fallbackBarrierColor;

  @override
  bool get barrierDismissible => dismissibleBarrier;

  @override
  String? get barrierLabel => dismissibleBarrier ? 'Close' : null;

  @override
  bool get popGestureEnabled => false;

  @override
  bool didPop(T? result) {
    _popping = true;
    return super.didPop(result);
  }

  /// Whether closing plays its own pop side for [side]: it is closing for
  /// real (not dragged) and the transition gives that pop side.
  bool _usesPopSide(TransitionSide? side) =>
      _popping && !_interactive && side != null;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    Widget page = Builder(builder: builder);
    final bool swipes = switch (transition.swipeBack ??
        RouteSwipeBack.platform) {
      RouteSwipeBack.always => true,
      RouteSwipeBack.never => false,
      RouteSwipeBack.platform =>
        !modal &&
            (defaultTargetPlatform == TargetPlatform.iOS ||
                defaultTargetPlatform == TargetPlatform.macOS),
    };
    if (transition.dismiss case final RouteDismiss dismiss?) {
      page = RouteDragDismiss(route: this, dismiss: dismiss, child: page);
    }
    if (swipes && !isFirst) {
      page = RouteDragDismiss(
        route: this,
        dismiss: RouteDismiss(
          direction: DragDirection.right,
          distance: 0.5,
          velocity: 600,
          spring: transition.dismiss?.spring ?? const TransitionSpring(),
        ),
        edgeWidth: 24,
        child: page,
      );
    }
    return page;
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final TransitionSide? popExit = transition.popExit;
        if (_usesPopSide(popExit)) {
          return TransitionSideView(
            side: popExit!,
            anchor: anchor,
            amount: sideAmountAt(
              popExit,
              1 - animation.value,
              totalMs: transition.resolvedReverseDurationMs,
              entering: false,
            ),
            child: child!,
          );
        }
        final TransitionSide enter = transition.enter ?? TransitionSide.still;
        return TransitionSideView(
          side: enter,
          anchor: anchor,
          amount: sideAmountAt(
            enter,
            animation.value,
            totalMs: transition.resolvedDurationMs,
            entering: true,
            linear: _interactive,
          ),
          child: child!,
        );
      },
    );
  }

  @override
  DelegatedTransitionBuilder? get delegatedTransition =>
      _buildCoveredTransition;

  /// The screen this route covers: it plays [RouteTransition.exit] while
  /// this one opens, and [RouteTransition.popEnter] (or the exit, back)
  /// while this one closes. [secondaryAnimation] is this route's animation.
  Widget? _buildCoveredTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    bool allowSnapshotting,
    Widget? child,
  ) {
    if (child == null) return null;
    return AnimatedBuilder(
      animation: secondaryAnimation,
      child: child,
      builder: (context, child) {
        final TransitionSide? popEnter = transition.popEnter;
        if (_usesPopSide(popEnter)) {
          return TransitionSideView(
            side: popEnter!,
            amount: sideAmountAt(
              popEnter,
              1 - secondaryAnimation.value,
              totalMs: transition.resolvedReverseDurationMs,
              entering: true,
            ),
            child: child!,
          );
        }
        final TransitionSide exit = transition.exit ?? TransitionSide.still;
        return TransitionSideView(
          side: exit,
          amount: sideAmountAt(
            exit,
            secondaryAnimation.value,
            totalMs: transition.resolvedDurationMs,
            entering: false,
            linear: _interactive,
          ),
          child: child!,
        );
      },
    );
  }

  // Interactive closing, driven by [RouteDragDismiss].

  /// Starts a drag that moves this route's transition backwards.
  void startDrag() {
    if (_interactive) return;
    _interactive = true;
    navigator?.didStartUserGesture();
  }

  /// Moves the transition to [progress] (1 open, 0 closed).
  void dragTo(double progress) {
    controller?.value = progress.clamp(0.0, 1.0);
  }

  /// Lets go: closes the route ([close]) or springs it open again, from
  /// [velocity] (progress per second, negative toward closed).
  void endDrag({
    required bool close,
    required double velocity,
    required TransitionSpring spring,
  }) {
    final AnimationController? controller = this.controller;
    final NavigatorState? navigator = this.navigator;
    if (controller == null || navigator == null) {
      _interactive = false;
      return;
    }
    void done() {
      _interactive = false;
      if (navigator.mounted && navigator.userGestureInProgress) {
        navigator.didStopUserGesture();
      }
    }

    if (close) {
      navigator.pop();
      controller.animateBackWith(
        TransitionPhysics.settle(
          spring,
          from: controller.value,
          to: 0,
          velocity: velocity,
        ),
      );
    } else {
      controller.animateWith(
        TransitionPhysics.settle(
          spring,
          from: controller.value,
          to: 1,
          velocity: velocity,
        ),
      );
    }
    if (!controller.isAnimating) {
      done();
      return;
    }
    late final AnimationStatusListener listener;
    listener = (status) {
      if (status.isAnimating) return;
      controller.removeStatusListener(listener);
      done();
    };
    controller.addStatusListener(listener);
  }
}

/// Closes [route] by dragging toward [dismiss]'s direction: the drag moves
/// the route's transition backwards (its shared elements follow), and on
/// release it closes or springs back. With [edgeWidth] only a drag that
/// starts that close to the edge it moves away from counts (iOS swipe back).
class RouteDragDismiss extends StatefulWidget {
  /// The route the drag closes.
  final CodelesslyRouteTransitionRoute<dynamic> route;

  /// Direction, thresholds and spring.
  final RouteDismiss dismiss;

  /// Width of the edge a drag must start in, or null for anywhere.
  final double? edgeWidth;

  /// The screen.
  final Widget child;

  /// Creates a [RouteDragDismiss].
  const RouteDragDismiss({
    super.key,
    required this.route,
    required this.dismiss,
    this.edgeWidth,
    required this.child,
  });

  @override
  State<RouteDragDismiss> createState() => _RouteDragDismissState();
}

class _RouteDragDismissState extends State<RouteDragDismiss> {
  double _dragged = 0;
  bool _active = false;

  bool get _horizontal =>
      widget.dismiss.direction == DragDirection.left ||
      widget.dismiss.direction == DragDirection.right;

  /// +1 when the dismissing way is positive on the axis.
  double get _sign => switch (widget.dismiss.direction) {
    DragDirection.right || DragDirection.down => 1,
    DragDirection.left || DragDirection.up => -1,
  };

  double get _extent {
    final Size size = context.size ?? MediaQuery.sizeOf(context);
    return math.max(1, _horizontal ? size.width : size.height);
  }

  bool _startsInEdge(Offset local) {
    final double? edge = widget.edgeWidth;
    if (edge == null) return true;
    final Size size = context.size ?? Size.zero;
    return switch (widget.dismiss.direction) {
      DragDirection.right => local.dx <= edge,
      DragDirection.left => local.dx >= size.width - edge,
      DragDirection.down => local.dy <= edge,
      DragDirection.up => local.dy >= size.height - edge,
    };
  }

  void _start(DragStartDetails details) {
    if (!widget.route.isCurrent || !_startsInEdge(details.localPosition)) {
      return;
    }
    _active = true;
    _dragged = 0;
    widget.route.startDrag();
  }

  void _update(DragUpdateDetails details) {
    if (!_active) return;
    final double delta = _horizontal
        ? details.delta.dx
        : details.delta.dy;
    _dragged = math.max(0, _dragged + delta * _sign);
    widget.route.dragTo(1 - _dragged / _extent);
  }

  void _end(DragEndDetails details) {
    if (!_active) return;
    _active = false;
    final double pixels =
        (_horizontal
            ? details.velocity.pixelsPerSecond.dx
            : details.velocity.pixelsPerSecond.dy) *
        _sign;
    final bool close = TransitionPhysics.commits(
      progress: _dragged / _extent,
      velocity: pixels,
      distance: widget.dismiss.distance,
      flingVelocity: widget.dismiss.velocity,
    );
    widget.route.endDrag(
      close: close,
      velocity: -pixels / _extent,
      spring: widget.dismiss.spring,
    );
  }

  void _cancel() {
    if (!_active) return;
    _active = false;
    widget.route.endDrag(
      close: false,
      velocity: 0,
      spring: widget.dismiss.spring,
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget child = widget.child;
    if (_horizontal) {
      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: _start,
        onHorizontalDragUpdate: _update,
        onHorizontalDragEnd: _end,
        onHorizontalDragCancel: _cancel,
        child: child,
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragStart: _start,
      onVerticalDragUpdate: _update,
      onVerticalDragEnd: _end,
      onVerticalDragCancel: _cancel,
      child: child,
    );
  }
}
