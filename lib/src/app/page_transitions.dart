// A navigation's page transition (NavigateAction.transition): fade, rise,
// slide or scale in over its duration, or none; the platform's is none on
// the web.
import 'dart:math' as math;

import 'package:codelessly_api/codelessly_api.dart' show PageTransition, RouteTransition;
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/gestures.dart' show HorizontalDragGestureRecognizer;
import 'package:flutter/services.dart' show PredictiveBackEvent;
import 'package:flutter/widgets.dart';

import 'ui/hero_flights.dart';

/// [transition] where the app runs: the platform's page transition off
/// Apple platforms is Android's zoom, which a website shouldn't play, so on
/// the web it is none.
PageTransition webTransition(PageTransition transition, {bool isWeb = kIsWeb}) =>
    isWeb && transition == PageTransition.platform ? PageTransition.none : transition;

/// Milliseconds [transition] takes when the action doesn't say.
int defaultTransitionMs(PageTransition transition) => switch (transition) {
      PageTransition.platform => 300,
      PageTransition.none => 0,
      PageTransition.fade => 250,
      PageTransition.fadeUp => 520,
      PageTransition.slideUp => 400,
      PageTransition.slideLeft => 350,
      PageTransition.scale => 300,
    };

/// A screen's route playing [transition] (not the platform's) over
/// [transitionMs] and back over [reverseTransitionMs], flying shared
/// elements as long as it lasts.
class CodelesslyPageTransitionRoute<T> extends PageRouteBuilder<T> with CodelesslyHeroRoute<T> {
  CodelesslyPageTransitionRoute({
    required this.transition,
    required WidgetBuilder builder,
    int? transitionMs,
    int? reverseTransitionMs,
    super.settings,
  }) : super(
          transitionDuration: Duration(milliseconds: _ms(transitionMs ?? defaultTransitionMs(transition))),
          reverseTransitionDuration:
              Duration(milliseconds: _ms(reverseTransitionMs ?? transitionMs ?? defaultTransitionMs(transition))),
          pageBuilder: (context, _, _) => builder(context),
          transitionsBuilder: (context, animation, _, child) => buildPageTransition(context, transition, animation, child),
        );

  final PageTransition transition;

  static int _ms(int ms) => ms.clamp(0, 60000);
}

/// Draws [child], a screen coming in, with [transition] at [animation]'s
/// value (0 hidden, 1 shown; it runs back when the screen leaves).
Widget buildPageTransition(BuildContext context, PageTransition transition, Animation<double> animation, Widget child) {
  final eased = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
  switch (transition) {
    case PageTransition.platform || PageTransition.none:
      return child;
    case PageTransition.fade:
      return FadeTransition(opacity: eased, child: child);
    case PageTransition.fadeUp:
      // Fades in over the first 60% while rising 3% of its height.
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: const Interval(0, 0.6)),
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero).animate(eased),
          child: child,
        ),
      );
    case PageTransition.slideUp:
      return SlideTransition(position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(eased), child: child);
    case PageTransition.slideLeft:
      final rtl = Directionality.maybeOf(context) == TextDirection.rtl;
      return SlideTransition(
        position: Tween<Offset>(begin: Offset(rtl ? -1 : 1, 0), end: Offset.zero).animate(eased),
        child: child,
      );
    case PageTransition.scale:
      return FadeTransition(
        opacity: eased,
        child: ScaleTransition(scale: Tween<double>(begin: 0.9, end: 1).animate(eased), child: child),
      );
  }
}

// --- the default page transition -------------------------------------------------
//
// How a screen with no transition of its own comes and goes. A project has
// one ([CodelesslyConfig.pageTransitions]): the platform's
// ([CodelesslyPageTransitions.platform]), one of the native ones by name on
// every platform, any transition of the animation system
// ([CodelesslyPageTransitions.animated]: a [RouteTransition], as a navigate
// action's `routeTransition` is), or the host's own subclass.

/// How a screen with no transition of its own comes and goes: the incoming
/// screen's half ([buildEntering]) and the half of the screen it covers
/// ([buildCovered]).
abstract class CodelesslyPageTransitions {
  const CodelesslyPageTransitions();

  /// The platform's: [fadeForwards] on Android, [cupertino] on iOS and
  /// macOS, [zoom] on Windows, Linux and Fuchsia, [none] on the web.
  static const CodelesslyPageTransitions platform = _PlatformPageTransitions();

  /// Android's: the new screen slides in a quarter of the width as it fades
  /// in, the old one slides out the other way and fades out (450 ms). The
  /// system's back swipe plays it backwards under the finger.
  static const CodelesslyPageTransitions fadeForwards = _FadeForwardsPageTransitions();

  /// iOS's: the new screen slides in from the trailing edge over the old
  /// one, which moves a third of the way out (500 ms); a full-screen dialog
  /// rises from the bottom. A drag from the leading edge goes back.
  static const CodelesslyPageTransitions cupertino = _CupertinoPageTransitions();

  /// The desktop's: the new screen fades in growing from 85% while the old
  /// one grows to 105% under a scrim (300 ms).
  static const CodelesslyPageTransitions zoom = _ZoomPageTransitions();

  /// No transition: the new screen is there at once.
  static const CodelesslyPageTransitions none = _NoPageTransitions();

  /// Any transition of the animation system: a [RouteTransition] (a preset
  /// such as `sharedAxisX`, `fadeThrough` or `iosPush`, or its own `enter`
  /// and `exit` poses, curves and durations), played as a navigate action's
  /// `routeTransition` is.
  const factory CodelesslyPageTransitions.animated(RouteTransition transition) = AnimatedPageTransitions;

  Duration get duration;
  Duration get reverseDuration => duration;

  /// [child], [route]'s screen, coming in ([animation] from 0 to 1) and
  /// leaving (back to 0).
  Widget buildEntering(PageRoute<Object?> route, BuildContext context, Animation<double> animation, Widget child);

  /// [child], a screen, as another comes in over it ([secondaryAnimation]
  /// from 0 to 1) and leaves it. [fill] is painted behind the two while
  /// they move, where the transition shows what is behind them (null:
  /// nothing, above a backdrop).
  Widget buildCovered(BuildContext context, Animation<double> secondaryAnimation, Widget child, {Color? fill}) => child;

  /// Whether a drag from the screen's leading edge takes [route] back.
  bool swipesBack(PageRoute<Object?> route) => false;

  /// Whether the system's back gesture (Android's predictive back) plays
  /// [route]'s way out under the finger.
  bool followsSystemBack(PageRoute<Object?> route) => false;
}

/// A [RouteTransition] of the animation system as a project's page
/// transition ([CodelesslyPageTransitions.animated]). Its screens open in a
/// [CodelesslyRouteTransitionRoute], which plays it.
final class AnimatedPageTransitions extends CodelesslyPageTransitions {
  const AnimatedPageTransitions(this.transition);

  final RouteTransition transition;

  @override
  Duration get duration => Duration(milliseconds: transition.resolved.resolvedDurationMs);

  @override
  Duration get reverseDuration => Duration(milliseconds: transition.resolved.resolvedReverseDurationMs);

  // (Played by its own route: these draw the screen as it is.)
  @override
  Widget buildEntering(PageRoute<Object?> route, BuildContext context, Animation<double> animation, Widget child) => child;
}

/// The page transitions of the project the screens below belong to: what a
/// full-screen modal opens with.
class CodelesslyPageTransitionsScope extends InheritedWidget {
  const CodelesslyPageTransitionsScope({super.key, required this.transitions, this.fill, required super.child});

  final CodelesslyPageTransitions transitions;

  /// The project's surface, behind two screens that move.
  final Color Function()? fill;

  static CodelesslyPageTransitionsScope? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<CodelesslyPageTransitionsScope>();

  @override
  bool updateShouldNotify(CodelesslyPageTransitionsScope oldWidget) => transitions != oldWidget.transitions;
}

final class _PlatformPageTransitions extends CodelesslyPageTransitions {
  const _PlatformPageTransitions();

  CodelesslyPageTransitions get _now => kIsWeb
      ? CodelesslyPageTransitions.none
      : switch (defaultTargetPlatform) {
          TargetPlatform.android => CodelesslyPageTransitions.fadeForwards,
          TargetPlatform.iOS || TargetPlatform.macOS => CodelesslyPageTransitions.cupertino,
          TargetPlatform.windows || TargetPlatform.linux || TargetPlatform.fuchsia => CodelesslyPageTransitions.zoom,
        };

  @override
  Duration get duration => _now.duration;

  @override
  Duration get reverseDuration => _now.reverseDuration;

  @override
  Widget buildEntering(PageRoute<Object?> route, BuildContext context, Animation<double> animation, Widget child) =>
      _now.buildEntering(route, context, animation, child);

  @override
  Widget buildCovered(BuildContext context, Animation<double> secondaryAnimation, Widget child, {Color? fill}) =>
      _now.buildCovered(context, secondaryAnimation, child, fill: fill);

  @override
  bool swipesBack(PageRoute<Object?> route) => _now.swipesBack(route);

  @override
  bool followsSystemBack(PageRoute<Object?> route) => _now.followsSystemBack(route);
}

final class _NoPageTransitions extends CodelesslyPageTransitions {
  const _NoPageTransitions();

  @override
  Duration get duration => Duration.zero;

  @override
  Widget buildEntering(PageRoute<Object?> route, BuildContext context, Animation<double> animation, Widget child) => child;
}

/// Android's page transition (Material 3's "fade forwards").
final class _FadeForwardsPageTransitions extends CodelesslyPageTransitions {
  const _FadeForwardsPageTransitions();

  static const Curve _curve = Curves.easeInOutCubicEmphasized;

  static final _in = Tween<Offset>(begin: const Offset(0.25, 0), end: Offset.zero).chain(CurveTween(curve: _curve));
  static final _out = Tween<Offset>(begin: Offset.zero, end: const Offset(0.25, 0)).chain(CurveTween(curve: _curve));
  static final _coveredOut =
      Tween<Offset>(begin: Offset.zero, end: const Offset(-0.25, 0)).chain(CurveTween(curve: _curve));
  static final _coveredIn =
      Tween<Offset>(begin: const Offset(-0.25, 0), end: Offset.zero).chain(CurveTween(curve: _curve));
  static final _fadeIn = Tween<double>(begin: 0, end: 1).chain(CurveTween(curve: const Interval(0, 0.75)));
  static final _fadeOut = Tween<double>(begin: 1, end: 0).chain(CurveTween(curve: const Interval(0, 0.25)));

  @override
  Duration get duration => const Duration(milliseconds: 450);

  @override
  Widget buildEntering(PageRoute<Object?> route, BuildContext context, Animation<double> animation, Widget child) =>
      DualTransitionBuilder(
        animation: animation,
        forwardBuilder: (context, animation, child) => FadeTransition(
          opacity: _fadeIn.animate(animation),
          child: SlideTransition(position: _in.animate(animation), child: child),
        ),
        reverseBuilder: (context, animation, child) => IgnorePointer(
          ignoring: animation.status == AnimationStatus.forward,
          child: FadeTransition(
            opacity: _fadeOut.animate(animation),
            child: SlideTransition(position: _out.animate(animation), child: child),
          ),
        ),
        child: child,
      );

  @override
  Widget buildCovered(BuildContext context, Animation<double> secondaryAnimation, Widget child, {Color? fill}) {
    final Widget moved = DualTransitionBuilder(
      animation: ReverseAnimation(secondaryAnimation),
      forwardBuilder: (context, animation, child) => FadeTransition(
        opacity: _fadeIn.animate(animation),
        child: SlideTransition(position: _coveredIn.animate(animation), child: child),
      ),
      reverseBuilder: (context, animation, child) => FadeTransition(
        opacity: _fadeOut.animate(animation),
        child: SlideTransition(position: _coveredOut.animate(animation), child: child),
      ),
      child: child,
    );
    if (fill == null || !(ModalRoute.opaqueOf(context) ?? true)) return moved;
    // Behind the two screens while they are both part faded.
    return ColoredBox(color: secondaryAnimation.isAnimating ? fill : const Color(0x00000000), child: moved);
  }

  @override
  bool followsSystemBack(PageRoute<Object?> route) => true;
}

/// iOS's page transition.
final class _CupertinoPageTransitions extends CodelesslyPageTransitions {
  const _CupertinoPageTransitions();

  @override
  Duration get duration => const Duration(milliseconds: 500);

  @override
  Widget buildEntering(PageRoute<Object?> route, BuildContext context, Animation<double> animation, Widget child) =>
      _CupertinoEntering(animation: animation, rises: route.fullscreenDialog, linear: route.popGestureInProgress, child: child);

  @override
  Widget buildCovered(BuildContext context, Animation<double> secondaryAnimation, Widget child, {Color? fill}) =>
      _CupertinoCovered(
        animation: secondaryAnimation,
        linear: ModalRoute.of(context)?.navigator?.userGestureInProgress ?? false,
        child: child,
      );

  @override
  bool swipesBack(PageRoute<Object?> route) => !route.fullscreenDialog;
}

class _CupertinoEntering extends StatefulWidget {
  const _CupertinoEntering({required this.animation, required this.rises, required this.linear, required this.child});

  final Animation<double> animation;

  /// From the bottom (a full-screen dialog), not from the side.
  final bool rises;

  /// Straight under a finger that swipes back.
  final bool linear;
  final Widget child;

  @override
  State<_CupertinoEntering> createState() => _CupertinoEnteringState();
}

class _CupertinoEnteringState extends State<_CupertinoEntering> {
  static final _fromSide = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero);
  static final _fromBottom = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero);

  CurvedAnimation? _positionCurve, _shadowCurve;
  late Animation<Offset> _position;
  late Animation<double> _shadow;

  @override
  void initState() {
    super.initState();
    _setUp();
  }

  @override
  void didUpdateWidget(_CupertinoEntering old) {
    super.didUpdateWidget(old);
    if (old.animation != widget.animation || old.linear != widget.linear || old.rises != widget.rises) {
      _tearDown();
      _setUp();
    }
  }

  @override
  void dispose() {
    _tearDown();
    super.dispose();
  }

  void _tearDown() {
    _positionCurve?.dispose();
    _shadowCurve?.dispose();
    _positionCurve = _shadowCurve = null;
  }

  void _setUp() {
    if (widget.rises) {
      _positionCurve = CurvedAnimation(
        parent: widget.animation,
        curve: Curves.linearToEaseOut,
        reverseCurve: Curves.linearToEaseOut.flipped,
      );
      _position = _positionCurve!.drive(_fromBottom);
      _shadow = kAlwaysDismissedAnimation;
      return;
    }
    if (!widget.linear) {
      _positionCurve = CurvedAnimation(
        parent: widget.animation,
        curve: Curves.fastEaseInToSlowEaseOut,
        reverseCurve: Curves.fastEaseInToSlowEaseOut.flipped,
      );
      _shadowCurve = CurvedAnimation(parent: widget.animation, curve: Curves.linearToEaseOut);
    }
    _position = (_positionCurve ?? widget.animation).drive(_fromSide);
    _shadow = _shadowCurve ?? widget.animation;
  }

  @override
  Widget build(BuildContext context) {
    final direction = Directionality.of(context);
    if (widget.rises) return SlideTransition(position: _position, child: widget.child);
    return SlideTransition(
      position: _position,
      textDirection: direction,
      child: AnimatedBuilder(
        animation: _shadow,
        child: widget.child,
        builder: (context, child) => DecoratedBox(decoration: _EdgeShadow(_shadow.value), child: child),
      ),
    );
  }
}

/// The faint shadow at the leading edge of a screen sliding in: 5% of the
/// screen's width, black at 1.6% fading to none, there as far as [amount].
class _EdgeShadow extends Decoration {
  const _EdgeShadow(this.amount);

  final double amount;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) => _EdgeShadowPainter(amount, onChanged);

  @override
  bool operator ==(Object other) => other is _EdgeShadow && other.amount == amount;

  @override
  int get hashCode => amount.hashCode;
}

class _EdgeShadowPainter extends BoxPainter {
  _EdgeShadowPainter(this.amount, super.onChanged);

  final double amount;

  static const _edge = Color(0x04000000), _none = Color(0x00000000);

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    if (amount <= 0) return;
    final from = Color.lerp(null, _edge, amount)!, to = Color.lerp(null, _none, amount)!;
    final size = configuration.size!;
    final width = 0.05 * size.width;
    final (sign, start) =
        configuration.textDirection == TextDirection.rtl ? (1.0, offset.dx + size.width) : (-1.0, offset.dx);
    for (var dx = 0; dx < width; dx += 1) {
      final paint = Paint()..color = Color.lerp(from, to, (dx % width) / width)!;
      canvas.drawRect(Rect.fromLTWH(start + sign * dx - 1, offset.dy, 1, size.height), paint);
    }
  }
}

class _CupertinoCovered extends StatefulWidget {
  const _CupertinoCovered({required this.animation, required this.linear, required this.child});

  final Animation<double> animation;
  final bool linear;
  final Widget child;

  @override
  State<_CupertinoCovered> createState() => _CupertinoCoveredState();
}

class _CupertinoCoveredState extends State<_CupertinoCovered> {
  static final _aside = Tween<Offset>(begin: Offset.zero, end: const Offset(-1 / 3, 0));

  CurvedAnimation? _curve;
  late Animation<Offset> _position;

  @override
  void initState() {
    super.initState();
    _setUp();
  }

  @override
  void didUpdateWidget(_CupertinoCovered old) {
    super.didUpdateWidget(old);
    if (old.animation != widget.animation || old.linear != widget.linear) {
      _curve?.dispose();
      _curve = null;
      _setUp();
    }
  }

  @override
  void dispose() {
    _curve?.dispose();
    super.dispose();
  }

  void _setUp() {
    if (!widget.linear) {
      _curve = CurvedAnimation(
        parent: widget.animation,
        curve: Curves.linearToEaseOut,
        reverseCurve: Curves.easeInToLinear,
      );
    }
    _position = (_curve ?? widget.animation).drive(_aside);
  }

  @override
  Widget build(BuildContext context) => SlideTransition(
        position: _position,
        textDirection: Directionality.of(context),
        transformHitTests: false,
        child: widget.child,
      );
}

/// The desktop's page transition (Material's zoom).
final class _ZoomPageTransitions extends CodelesslyPageTransitions {
  const _ZoomPageTransitions();

  // Like the native fastOutExtraSlowIn.
  static final _curve = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(begin: 0, end: 0.4).chain(CurveTween(curve: const Cubic(0.05, 0, 0.133333, 0.06))),
      weight: 0.166666,
    ),
    TweenSequenceItem(
      tween: Tween<double>(begin: 0.4, end: 1).chain(CurveTween(curve: const Cubic(0.208333, 0.82, 0.25, 1))),
      weight: 1 - 0.166666,
    ),
  ]);
  static final _fadeIn = Tween<double>(begin: 0, end: 1).chain(CurveTween(curve: const Interval(0.125, 0.25)));
  static final _fadeOut = Tween<double>(begin: 1, end: 0).chain(CurveTween(curve: const Interval(0.0825, 0.2075)));
  static final _scrim = Tween<double>(begin: 0, end: 0.6).chain(CurveTween(curve: const Interval(0.2075, 0.4175)));
  static final _enterUp = Tween<double>(begin: 0.85, end: 1).chain(_curve);
  static final _enterDown = Tween<double>(begin: 1.10, end: 1).chain(_curve);
  static final _exitUp = Tween<double>(begin: 1, end: 1.05).chain(_curve);
  static final _exitDown = Tween<double>(begin: 1, end: 0.90).chain(_curve);

  static Widget _zoom(Animation<double> fade, Animation<double> scale, Widget? child) => FadeTransition(
        opacity: fade,
        child: ScaleTransition(scale: scale, filterQuality: FilterQuality.medium, child: child),
      );

  /// A screen coming in ([reverse]: back in, as the one above leaves).
  static Widget _enter(Animation<double> animation, Widget? child, {bool reverse = false}) => _zoom(
        reverse ? kAlwaysCompleteAnimation : _fadeIn.animate(animation),
        (reverse ? _enterDown : _enterUp).animate(animation),
        child,
      );

  /// A screen leaving ([reverse]: popped), or covered.
  static Widget _exit(Animation<double> animation, Widget? child, {bool reverse = false}) => _zoom(
        reverse ? _fadeOut.animate(animation) : kAlwaysCompleteAnimation,
        (reverse ? _exitDown : _exitUp).animate(animation),
        child,
      );

  @override
  Duration get duration => const Duration(milliseconds: 300);

  @override
  Widget buildEntering(PageRoute<Object?> route, BuildContext context, Animation<double> animation, Widget child) {
    final scope = CodelesslyPageTransitionsRoute.maybeOf(route);
    final fill = scope == null || scope.seeThroughAt(context) ? null : scope.fill?.call();
    return DualTransitionBuilder(
      animation: animation,
      forwardBuilder: (context, animation, child) {
        final zoomed = _enter(animation, child);
        if (fill == null) return zoomed;
        // The scrim over the screen beneath, under the one coming in.
        return AnimatedBuilder(
          animation: animation,
          child: zoomed,
          builder: (context, child) => ColoredBox(
            color: animation.isAnimating && !animation.isCompleted
                ? fill.withValues(alpha: fill.a * _scrim.evaluate(animation))
                : const Color(0x00000000),
            child: child,
          ),
        );
      },
      reverseBuilder: (context, animation, child) => _exit(animation, child, reverse: true),
      child: child,
    );
  }

  @override
  Widget buildCovered(BuildContext context, Animation<double> secondaryAnimation, Widget child, {Color? fill}) =>
      DualTransitionBuilder(
        animation: ReverseAnimation(secondaryAnimation),
        forwardBuilder: (context, animation, child) => _enter(animation, child, reverse: true),
        reverseBuilder: (context, animation, child) => _exit(animation, child),
        child: child,
      );
}

/// What a route that plays a [CodelesslyPageTransitions] is made of: the
/// two halves, the half it gives a route of another kind beneath it, the
/// back swipe and the system's back gesture.
mixin CodelesslyPageTransitionsRoute<T> on PageRoute<T> {
  /// What it plays.
  CodelesslyPageTransitions get transitions;

  /// The fill behind two screens that move (the project's surface).
  Color Function()? get fill;

  /// Whether a backdrop shows behind the screens at [context]: the
  /// transition then paints nothing behind them.
  bool seeThroughAt(BuildContext context);

  static CodelesslyPageTransitionsRoute<Object?>? maybeOf(PageRoute<Object?> route) =>
      route is CodelesslyPageTransitionsRoute<Object?> ? route : null;

  @override
  Duration get transitionDuration => transitions.duration;

  @override
  Duration get reverseTransitionDuration => transitions.reverseDuration;

  // A screen is covered with its half of the transition by another page
  // (not by a full-screen dialog, which rises over it): one of ours, or one
  // that says what the screen beneath it plays.
  @override
  bool canTransitionTo(TransitionRoute<dynamic> nextRoute) =>
      nextRoute is PageRoute<dynamic> &&
      !nextRoute.fullscreenDialog &&
      (nextRoute is CodelesslyPageTransitionsRoute<dynamic> || nextRoute.delegatedTransition != null);

  Color? _fillAt(BuildContext context) => seeThroughAt(context) ? null : fill?.call();

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    Widget page = transitions.buildCovered(context, secondaryAnimation, child, fill: _fillAt(context));
    page = transitions.buildEntering(this, context, animation, page);
    if (transitions.swipesBack(this)) page = _BackSwipe(route: this, child: page);
    if (transitions.followsSystemBack(this)) page = _SystemBack(route: this, child: page);
    return page;
  }

  /// What a route of another kind beneath this one plays as this one comes
  /// in over it and leaves.
  @override
  DelegatedTransitionBuilder? get delegatedTransition => _delegated;

  Widget? _delegated(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation,
          bool allowSnapshotting, Widget? child) =>
      child == null ? null : transitions.buildCovered(context, secondaryAnimation, child, fill: _fillAt(context));

  // --- the back swipe (iOS) ---

  /// Whether a swipe from the leading edge may start now: not on the first
  /// screen, nor one that handles back itself or blocks it, nor while it is
  /// still coming in or is covered, nor during another gesture.
  bool get swipeBackEnabled =>
      !isFirst &&
      !willHandlePopInternally &&
      popDisposition != RoutePopDisposition.doNotPop &&
      !fullscreenDialog &&
      animation?.status == AnimationStatus.completed &&
      secondaryAnimation?.status == AnimationStatus.dismissed &&
      !popGestureInProgress;

  void _swipeStart() => navigator?.didStartUserGesture();

  void _swipeBy(double fraction) {
    final c = controller;
    if (c != null) c.value -= fraction;
  }

  /// The finger lifted at [velocity] (screen widths a second, positive:
  /// back): it goes back on a fling that way or past half way.
  void _swipeEnd(double velocity) {
    final c = controller, nav = navigator;
    if (c == null || nav == null) return;
    const curve = Curves.fastEaseInToSlowEaseOut;
    final forward = velocity.abs() >= 1 ? velocity <= 0 : c.value > 0.5;
    if (forward) {
      c.animateTo(1, duration: Duration(milliseconds: (800 * (1 - c.value)).round().clamp(1, 800)), curve: curve);
    } else {
      if (isCurrent) nav.pop();
      if (c.isAnimating) {
        c.animateBack(0, duration: Duration(milliseconds: (800 * c.value).round().clamp(1, 800)), curve: curve);
      }
    }
    if (c.isAnimating) {
      late final AnimationStatusListener done;
      done = (_) {
        nav.didStopUserGesture();
        c.removeStatusListener(done);
      };
      c.addStatusListener(done);
    } else {
      nav.didStopUserGesture();
    }
  }

  // --- the system's back gesture (Android) ---

  /// How much of the way out a whole back gesture plays before it is let
  /// go: enough to show where back leads, not the whole transition.
  static const double systemBackReach = 0.15;

  bool _systemBackStart(double progress) {
    if (!isCurrent || !popGestureEnabled) return false;
    handleStartBackGesture(progress: 1 - progress * systemBackReach);
    return true;
  }

  void _systemBackUpdate(double progress) => handleUpdateBackGestureProgress(progress: 1 - progress * systemBackReach);

  /// Let go to go back: the screen leaves from where the gesture left it.
  void _systemBackCommit() {
    final c = controller, nav = navigator;
    if (nav == null) return;
    if (isCurrent) nav.pop();
    if (c != null && c.isAnimating) {
      late final AnimationStatusListener done;
      done = (_) {
        nav.didStopUserGesture();
        c.removeStatusListener(done);
      };
      c.addStatusListener(done);
    } else {
      nav.didStopUserGesture();
    }
  }
}

/// A drag from the leading 20 px of [child] that takes [route] back.
class _BackSwipe extends StatefulWidget {
  const _BackSwipe({required this.route, required this.child});

  final CodelesslyPageTransitionsRoute<dynamic> route;
  final Widget child;

  @override
  State<_BackSwipe> createState() => _BackSwipeState();
}

class _BackSwipeState extends State<_BackSwipe> {
  static const double _edge = 20;

  late final HorizontalDragGestureRecognizer _drag = HorizontalDragGestureRecognizer(debugOwner: this)
    ..onStart = ((_) {
      _dragging = true;
      widget.route._swipeStart();
    })
    ..onUpdate = ((d) => widget.route._swipeBy(_signed(d.primaryDelta! / context.size!.width)))
    ..onEnd = ((d) => _end(_signed(d.velocity.pixelsPerSecond.dx / context.size!.width)))
    ..onCancel = (() => _end(0));

  bool _dragging = false;

  void _end(double velocity) {
    if (!_dragging) return;
    _dragging = false;
    widget.route._swipeEnd(velocity);
  }

  // Positive: toward the trailing edge (back).
  double _signed(double value) => Directionality.of(context) == TextDirection.rtl ? -value : value;

  @override
  void dispose() {
    _drag.dispose();
    // The screen went away under the finger: the navigator's gesture ends.
    if (_dragging) widget.route.navigator?.didStopUserGesture();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final width = math.max(rtl ? padding.right : padding.left, _edge);
    return Stack(
      fit: StackFit.passthrough,
      children: [
        widget.child,
        PositionedDirectional(
          start: 0,
          width: width,
          top: 0,
          bottom: 0,
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (event) {
              if (widget.route.swipeBackEnabled) _drag.addPointer(event);
            },
          ),
        ),
      ],
    );
  }
}

/// Follows the system's back gesture: [route] plays its way out under the
/// finger, then leaves or comes back.
class _SystemBack extends StatefulWidget {
  const _SystemBack({required this.route, required this.child});

  final CodelesslyPageTransitionsRoute<dynamic> route;
  final Widget child;

  @override
  State<_SystemBack> createState() => _SystemBackState();
}

class _SystemBackState extends State<_SystemBack> with WidgetsBindingObserver {
  bool _following = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  bool handleStartBackGesture(PredictiveBackEvent backEvent) {
    if (backEvent.isButtonEvent) return false;
    return _following = widget.route._systemBackStart(backEvent.progress);
  }

  @override
  void handleUpdateBackGestureProgress(PredictiveBackEvent backEvent) {
    if (_following) widget.route._systemBackUpdate(backEvent.progress);
  }

  @override
  void handleCancelBackGesture() {
    if (!_following) return;
    _following = false;
    widget.route.handleCancelBackGesture();
  }

  @override
  void handleCommitBackGesture() {
    if (!_following) return;
    _following = false;
    widget.route._systemBackCommit();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
