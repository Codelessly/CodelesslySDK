// Custom route transitions (`RouteTransition`, on navigate and open
// modal actions): a page route that moves the incoming screen from its
// enter side to rest and the covered screen to its exit side (3D,
// shifts, fades, blurs, reveals), the pop sides when closing, with a
// barrier, see-through screens, a swipe back from the edge and a drag that
// dismisses.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_api/codelessly_api.dart'
    show DragDirection, Motion, RevealOrigin, RevealShape, RouteDismiss, RouteSwipeBack, RouteTransition, TransitionReveal,
        TransitionSide, TransitionSpring;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../../render/behaviors.dart' show motionMatrix;
import 'hero_flights.dart';

/// The spring a released interactive transition settles with, and whether
/// a release closes the route.
abstract final class TransitionPhysics {
  static SpringDescription describe(TransitionSpring spring) => SpringDescription(
        mass: spring.mass <= 0 ? 1 : spring.mass,
        stiffness: spring.stiffness <= 0 ? 1 : spring.stiffness,
        damping: spring.damping < 0 ? 0 : spring.damping,
      );

  static Simulation settle(TransitionSpring spring, {required double from, required double to, required double velocity}) =>
      SpringSimulation(describe(spring), from, to, velocity, tolerance: const Tolerance(distance: 0.001, velocity: 0.01));

  /// A fling faster than [flingVelocity] decides by its direction; a slow
  /// release closes past [distance].
  static bool commits({required double progress, required double velocity, required double distance, required double flingVelocity}) {
    if (velocity.abs() >= flingVelocity) return velocity > 0;
    return progress >= distance;
  }
}

/// Where a reveal grows from: the last tap, and the box of the node that
/// navigated (global).
@immutable
class RevealAnchor {
  const RevealAnchor({this.tap, this.node});

  final Offset? tap;
  final Rect? node;

  /// The last pointer down anywhere (tracked once a transition is built).
  static Offset? lastTap;

  /// The box (global) of the node whose trigger fired last: what a modal
  /// anchored to its trigger sits by.
  static Rect? lastTrigger;

  /// The box (global) of the node a modal anchored to a named node sits by
  /// (`ModalAnchor.node`), found by the action that opens it.
  static Rect? named;
  static bool _tracking = false;

  static void track() {
    if (_tracking) return;
    _tracking = true;
    GestureBinding.instance.pointerRouter.addGlobalRoute((event) {
      if (event is PointerDownEvent) lastTap = event.position;
    });
  }

  /// The last tap, and [node]'s box when it's laid out.
  factory RevealAnchor.of(RenderBox? node) => RevealAnchor(
        tap: lastTap,
        node: node != null && node.attached && node.hasSize ? node.localToGlobal(Offset.zero) & node.size : null,
      );

  @override
  bool operator ==(Object other) => other is RevealAnchor && other.tap == tap && other.node == node;

  @override
  int get hashCode => Object.hash(tap, node);
}

/// [child] moved [amount] (0 at rest, 1 at its values) of the way to
/// [side]'s motion, and clipped by its reveal.
class TransitionSideView extends StatelessWidget {
  const TransitionSideView({super.key, required this.side, required this.amount, this.anchor = const RevealAnchor(), required this.child});

  final TransitionSide side;
  final double amount;
  final RevealAnchor anchor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (amount <= 0 || side.isStill) return child;
    final m = Motion.lerp(Motion.none, side.motion, amount);
    var out = child;
    if (m.opacity < 1) out = IgnorePointer(ignoring: m.opacity == 0, child: Opacity(opacity: m.opacity, child: out));
    if (m.blur > 0) out = ImageFiltered(imageFilter: ui.ImageFilter.blur(sigmaX: m.blur, sigmaY: m.blur), child: out);
    if (m.translateX != 0 || m.translateY != 0 || m.scale != 1 || m.scaleX != 1 || m.scaleY != 1 || m.rotate != 0 || m.rotateX != 0 || m.rotateY != 0) {
      out = Transform(alignment: Alignment(m.originX, m.originY), transform: motionMatrix(m), child: out);
    }
    if (m.shiftX != 0 || m.shiftY != 0) out = FractionalTranslation(translation: Offset(m.shiftX, m.shiftY), child: out);
    final reveal = side.reveal;
    if (reveal != null) {
      out = ClipPath(clipper: _RevealClipper(reveal: reveal, closed: amount, anchor: anchor, origin: _globalOrigin(context)), child: out);
    }
    return out;
  }

  Offset _globalOrigin(BuildContext context) {
    final box = context.findRenderObject();
    return box is RenderBox && box.hasSize && box.attached ? box.localToGlobal(Offset.zero) : Offset.zero;
  }
}

class _RevealClipper extends CustomClipper<Path> {
  _RevealClipper({required this.reveal, required this.closed, required this.anchor, required this.origin});

  final TransitionReveal reveal;

  /// 1 closed, 0 open.
  final double closed;
  final RevealAnchor anchor;
  final Offset origin;

  @override
  Path getClip(Size size) {
    final screen = Offset.zero & size;
    var center = screen.center;
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
    final open = 1 - closed.clamp(0.0, 1.0);
    if (reveal.shape == RevealShape.circle) {
      // The radius that covers the corner farthest from the center.
      final far = [screen.topLeft, screen.topRight, screen.bottomLeft, screen.bottomRight]
          .map((corner) => (corner - center).distance)
          .reduce(math.max);
      final from = math.max(reveal.startRadius, start == null ? 0.0 : start.shortestSide / 2);
      return Path()..addOval(Rect.fromCircle(center: center, radius: from + (far - from) * open));
    }
    final from = start ?? Rect.fromCenter(center: center, width: reveal.startRadius * 2, height: reveal.startRadius * 2);
    return Path()..addRect(Rect.lerp(from, screen, open)!);
  }

  @override
  bool shouldReclip(_RevealClipper old) =>
      old.closed != closed || old.reveal != reveal || old.origin != origin || old.anchor != anchor;
}

/// How far (0 at rest, 1 at its values) [side] is at [time] (0–1 of a
/// transition of [totalMs]): an entering side starts at its values.
double sideAmountAt(TransitionSide side, double time, {required int totalMs, required bool entering, bool linear = false}) {
  final (begin, end) = side.interval(totalMs);
  final local = end <= begin ? (time >= end ? 1.0 : 0.0) : ((time - begin) / (end - begin)).clamp(0.0, 1.0);
  final eased = linear
      ? local
      : side.curve == api.AnimationCurve.spring
          ? Curves.easeOutBack.transform(local)
          : side.curve.transform(local);
  return entering ? 1 - eased : eased;
}

/// A page route that plays a [RouteTransition] (resolved: its preset's
/// values filled in). A [modal] one shows a modal (see-through, with a
/// barrier, closed by a close modal action).
class CodelesslyRouteTransitionRoute<T> extends PageRoute<T> with CodelesslyHeroRoute<T> {
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

  final RouteTransition transition;
  final WidgetBuilder builder;
  final RevealAnchor anchor;
  final bool dismissibleBarrier;
  final Color? fallbackBarrierColor;
  final bool modal;

  bool _popping = false;
  bool _interactive = false;

  /// Whether a drag drives it now.
  bool get interactive => _interactive;

  @override
  Duration get transitionDuration => Duration(milliseconds: transition.resolvedDurationMs);

  @override
  Duration get reverseTransitionDuration => Duration(milliseconds: transition.resolvedReverseDurationMs);

  @override
  bool get opaque => !modal && (transition.opaque ?? true);

  @override
  bool get maintainState => true;

  @override
  Color? get barrierColor => transition.barrierColor == null ? fallbackBarrierColor : Color(transition.barrierColor!.value);

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

  bool _usesPopSide(TransitionSide? side) => _popping && !_interactive && side != null;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    Widget page = Builder(builder: builder);
    final swipes = switch (transition.swipeBack ?? RouteSwipeBack.platform) {
      RouteSwipeBack.always => true,
      RouteSwipeBack.never => false,
      RouteSwipeBack.platform =>
        !modal && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS),
    };
    if (transition.dismiss case final RouteDismiss dismiss?) page = RouteDragDismiss(route: this, dismiss: dismiss, child: page);
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
  Widget buildTransitions(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) =>
      AnimatedBuilder(
        animation: animation,
        child: child,
        builder: (context, child) {
          final popExit = transition.popExit;
          if (_usesPopSide(popExit)) {
            return TransitionSideView(
              side: popExit!,
              anchor: anchor,
              amount: sideAmountAt(popExit, 1 - animation.value, totalMs: transition.resolvedReverseDurationMs, entering: false),
              child: child!,
            );
          }
          final enter = transition.enter ?? TransitionSide.still;
          return TransitionSideView(
            side: enter,
            anchor: anchor,
            amount: sideAmountAt(enter, animation.value,
                totalMs: transition.resolvedDurationMs, entering: true, linear: _interactive),
            child: child!,
          );
        },
      );

  /// The covered screen moves to the exit side (the pop enter side when
  /// this closes).
  @override
  DelegatedTransitionBuilder? get delegatedTransition => _covered;

  Widget? _covered(
      BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, bool allowSnapshotting, Widget? child) {
    if (child == null) return null;
    return AnimatedBuilder(
      animation: secondaryAnimation,
      child: child,
      builder: (context, child) {
        final popEnter = transition.popEnter;
        if (_usesPopSide(popEnter)) {
          return TransitionSideView(
            side: popEnter!,
            amount: sideAmountAt(popEnter, 1 - secondaryAnimation.value,
                totalMs: transition.resolvedReverseDurationMs, entering: true),
            child: child!,
          );
        }
        final exit = transition.exit ?? TransitionSide.still;
        return TransitionSideView(
          side: exit,
          amount: sideAmountAt(exit, secondaryAnimation.value,
              totalMs: transition.resolvedDurationMs, entering: false, linear: _interactive),
          child: child!,
        );
      },
    );
  }

  // --- interactive closing (RouteDragDismiss) ---------------------------------------

  void startDrag() {
    if (_interactive) return;
    _interactive = true;
    navigator?.didStartUserGesture();
    startGestureFlights();
  }

  void dragTo(double progress) => controller?.value = progress.clamp(0.0, 1.0);

  void endDrag({required bool close, required double velocity, required TransitionSpring spring}) {
    final controller = this.controller;
    final navigator = this.navigator;
    if (controller == null || navigator == null) {
      _interactive = false;
      return;
    }
    void done() {
      _interactive = false;
      if (navigator.mounted && navigator.userGestureInProgress) navigator.didStopUserGesture();
    }

    if (close) {
      navigator.pop();
      controller.animateBackWith(TransitionPhysics.settle(spring, from: controller.value, to: 0, velocity: velocity));
    } else {
      controller.animateWith(TransitionPhysics.settle(spring, from: controller.value, to: 1, velocity: velocity));
    }
    if (!controller.isAnimating) return done();
    late final AnimationStatusListener listener;
    listener = (status) {
      if (status.isAnimating) return;
      controller.removeStatusListener(listener);
      done();
    };
    controller.addStatusListener(listener);
  }
}

/// A drag that closes [route] interactively: anywhere on it, or from its
/// edge within [edgeWidth] (a swipe back).
class RouteDragDismiss extends StatefulWidget {
  const RouteDragDismiss({super.key, required this.route, required this.dismiss, this.edgeWidth, required this.child});

  final CodelesslyRouteTransitionRoute<dynamic> route;
  final RouteDismiss dismiss;
  final double? edgeWidth;
  final Widget child;

  @override
  State<RouteDragDismiss> createState() => _RouteDragDismissState();
}

class _RouteDragDismissState extends State<RouteDragDismiss> {
  double _dragged = 0;
  bool _active = false;

  bool get _horizontal => widget.dismiss.direction == DragDirection.left || widget.dismiss.direction == DragDirection.right;

  double get _sign => switch (widget.dismiss.direction) {
        DragDirection.right || DragDirection.down => 1,
        DragDirection.left || DragDirection.up => -1,
      };

  double get _extent {
    final size = context.size ?? MediaQuery.sizeOf(context);
    return math.max(1, _horizontal ? size.width : size.height);
  }

  bool _startsInEdge(Offset local) {
    final edge = widget.edgeWidth;
    if (edge == null) return true;
    final size = context.size ?? Size.zero;
    return switch (widget.dismiss.direction) {
      DragDirection.right => local.dx <= edge,
      DragDirection.left => local.dx >= size.width - edge,
      DragDirection.down => local.dy <= edge,
      DragDirection.up => local.dy >= size.height - edge,
    };
  }

  void _start(DragStartDetails d) {
    if (!widget.route.isCurrent || !_startsInEdge(d.localPosition)) return;
    _active = true;
    _dragged = 0;
    widget.route.startDrag();
  }

  void _update(DragUpdateDetails d) {
    if (!_active) return;
    _dragged = math.max(0, _dragged + (_horizontal ? d.delta.dx : d.delta.dy) * _sign);
    widget.route.dragTo(1 - _dragged / _extent);
  }

  void _end(DragEndDetails d) {
    if (!_active) return;
    _active = false;
    final pixels = (_horizontal ? d.velocity.pixelsPerSecond.dx : d.velocity.pixelsPerSecond.dy) * _sign;
    final close = TransitionPhysics.commits(
      progress: _dragged / _extent,
      velocity: pixels,
      distance: widget.dismiss.distance,
      flingVelocity: widget.dismiss.velocity,
    );
    widget.route.endDrag(close: close, velocity: -pixels / _extent, spring: widget.dismiss.spring);
  }

  void _cancel() {
    if (!_active) return;
    _active = false;
    widget.route.endDrag(close: false, velocity: 0, spring: widget.dismiss.spring);
  }

  @override
  Widget build(BuildContext context) => _horizontal
      ? GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragStart: _start,
          onHorizontalDragUpdate: _update,
          onHorizontalDragEnd: _end,
          onHorizontalDragCancel: _cancel,
          child: widget.child,
        )
      : GestureDetector(
          behavior: HitTestBehavior.translucent,
          onVerticalDragStart: _start,
          onVerticalDragUpdate: _update,
          onVerticalDragEnd: _end,
          onVerticalDragCancel: _cancel,
          child: widget.child,
        );
}
