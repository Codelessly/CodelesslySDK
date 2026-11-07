// Shared element flights between the screens a navigation moves between
// (SDK 8.x's NodeHero over Flutter's HeroController): the app shell's
// routes ([CodelesslyHeroRoute]) find the hero marks (render/hero.dart) with
// the same tag on the screen below and the screen on top, hide both, and fly
// a drawing of the node in the navigator's overlay on the route's
// animation, as each node's `hero.flight` says.
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:codelessly_api_v2/codelessly_api.dart' show HeroFlightShuttle, HeroPlaceholder;
import 'package:flutter/material.dart';

import '../../render/hero.dart';
import '../../render/node_tree.dart';

/// The routes the screens of each node tree show in, as the app shell
/// reports them.
abstract final class HeroRoutes {
  static final Expando<ModalRoute<Object?>> _routeOf = Expando('heroRoute');

  /// [tree] shows in [route] now.
  static void bind(NodeTree tree, ModalRoute<Object?>? route) => _routeOf[tree] = route;

  /// The marks with a tag on the screens [route] shows, the first per tag.
  static Map<String, RenderHeroMark> marksOf(ModalRoute<Object?> route) {
    final out = <String, RenderHeroMark>{};
    for (final entry in HeroMarks.trees) {
      if (!identical(_routeOf[entry], route)) continue;
      for (final m in HeroMarks.of(entry)) {
        out.putIfAbsent(m.tag, () => m);
      }
    }
    return out;
  }
}

/// A route of the app shell that flies shared elements when it opens and
/// closes (and while a drag closes it, [startGestureFlights]).
mixin CodelesslyHeroRoute<T> on ModalRoute<T> {
  ModalRoute<Object?>? _below;

  /// The route under this one, whose screen its shared elements fly from.
  ModalRoute<Object?>? get heroRouteBelow => _below;

  @override
  void didChangePrevious(Route<dynamic>? previousRoute) {
    _below = previousRoute is ModalRoute<Object?> ? previousRoute : null;
    super.didChangePrevious(previousRoute);
  }

  @override
  TickerFuture didPush() {
    final future = super.didPush();
    HeroFlights._pushed(this);
    return future;
  }

  @override
  bool didPop(T? result) {
    final popped = super.didPop(result);
    if (popped) HeroFlights._popped(this);
    return popped;
  }

  /// A drag started closing this route: its shared elements follow it.
  void startGestureFlights() => HeroFlights._popped(this, gesture: true);
}

/// The flights in the air.
abstract final class HeroFlights {
  static final List<_Flight> _flights = [];

  /// Whether a flight is in the air (tests).
  static bool get flying => _flights.isNotEmpty;

  static void _pushed(CodelesslyHeroRoute<Object?> upper) {
    final animation = upper.animation;
    if (animation == null || upper.navigator == null) return;
    // Put the route offstage for its first frame (its animation reads 1):
    // once laid out, its shared elements' places are known.
    final measure = animation.value == 0;
    if (measure) upper.offstage = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (measure && upper.isActive) upper.offstage = false;
      final lower = upper.heroRouteBelow;
      if (lower == null || upper.navigator == null || !upper.isActive) return;
      _start(lower: lower, upper: upper, push: true);
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  static void _popped(CodelesslyHeroRoute<Object?> upper, {bool gesture = false}) {
    // A drag's flights carry on as it lets go.
    if (_flights.any((f) => identical(f.upper, upper))) return;
    final lower = upper.heroRouteBelow;
    if (lower == null || upper.navigator == null) return;
    _start(lower: lower, upper: upper, push: false);
  }

  static void _start({required ModalRoute<Object?> lower, required ModalRoute<Object?> upper, required bool push}) {
    final overlay = upper.navigator?.overlay;
    final animation = upper.animation;
    if (overlay == null || animation == null) return;
    final bottoms = HeroRoutes.marksOf(lower);
    if (bottoms.isEmpty) return;
    final tops = HeroRoutes.marksOf(upper);
    for (final e in tops.entries) {
      final bottom = bottoms[e.key];
      if (bottom == null) continue;
      // A flight already flying either end ends: this one takes over.
      for (final f in [..._flights]) {
        if (f.involves(bottom) || f.involves(e.value)) f.end();
      }
      final flight = _Flight(bottom: bottom, top: e.value, lower: lower, upper: upper, push: push);
      if (flight.begin(overlay, animation)) _flights.add(flight);
    }
  }
}

class _Flight {
  _Flight({required this.bottom, required this.top, required this.lower, required this.upper, required this.push});

  final RenderHeroMark bottom, top;
  final ModalRoute<Object?> lower, upper;
  final bool push;

  late final Animation<double> _route;
  late final CurvedAnimation _curved;
  late RectTween _tween;
  OverlayEntry? _entry;
  bool _ended = false;

  bool involves(RenderHeroMark m) => identical(m, bottom) || identical(m, top);

  /// The flight the two ends make: the more specific one when they differ.
  HeroFlightShuttle get flight => bottom.flight.index > top.flight.index ? bottom.flight : top.flight;

  RenderHeroMark get destination => push ? top : bottom;
  RenderHeroMark get origin => push ? bottom : top;

  static Rect? _rectOf(RenderHeroMark m, ModalRoute<Object?> route) {
    final box = route.subtreeContext?.findRenderObject();
    return m.rectIn(box is RenderBox && box.attached ? box : null);
  }

  bool begin(OverlayState overlay, Animation<double> route) {
    final from = _rectOf(origin, push ? lower : upper);
    final to = _rectOf(destination, push ? upper : lower);
    if (from == null || to == null) return false;
    _route = route;
    _curved = CurvedAnimation(parent: route, curve: Curves.fastOutSlowIn, reverseCurve: Curves.fastOutSlowIn.flipped);
    // The destination's path, as Flutter flies on the destination hero's
    // tween: an arc, a straight line for a container, else Material's arc.
    _tween = switch (destination.flight) {
      HeroFlightShuttle.arc => HeroArcRectTween(begin: from, end: to),
      HeroFlightShuttle.containerTransform => RectTween(begin: from, end: to),
      _ => MaterialRectArcTween(begin: from, end: to),
    };
    bottom.flying = true;
    top.flying = true;
    _entry = OverlayEntry(builder: _build);
    overlay.insert(_entry!);
    route.addStatusListener(_status);
    return true;
  }

  void _status(AnimationStatus status) {
    if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) end();
  }

  /// Lands: the ends show again, the destination keeping the origin under
  /// it while its images load (`placeholder: source`).
  void end() {
    if (_ended) return;
    _ended = true;
    HeroFlights._flights.remove(this);
    _route.removeStatusListener(_status);
    _curved.dispose();
    _entry?.remove();
    _entry?.dispose();
    _entry = null;
    bottom.flying = false;
    top.flying = false;
    // Where it landed: the top on a push or a drag let go back, else the
    // bottom.
    final landed = _route.value >= 1 ? top : bottom;
    final left = identical(landed, top) ? bottom : top;
    if (landed.placeholder == HeroPlaceholder.source) landed.placeholderSource = left;
  }

  /// How far along the flight is, 0 at the start, 1 landed.
  double get _progress => push ? _curved.value : 1 - _curved.value;

  Widget _build(BuildContext context) => AnimatedBuilder(
        animation: _route,
        builder: (context, _) {
          if (!bottom.attached || !top.attached) {
            WidgetsBinding.instance.addPostFrameCallback((_) => end());
            return const SizedBox.shrink();
          }
          // The destination may still move (laid out late, scrolled).
          final to = _rectOf(destination, push ? upper : lower);
          if (to != null && to != _tween.end) _tween.end = to;
          final rect = _tween.lerp(_progress) ?? Rect.zero;
          return Positioned.fromRect(rect: rect, child: IgnorePointer(child: _shuttle(context)));
        },
      );

  Widget _shuttle(BuildContext context) {
    final t = _curved.value.clamp(0.0, 1.0);
    final flight = this.flight;
    Widget drawn(RenderHeroMark m) => HeroMarkPaint(mark: m, repaint: _route);
    Widget clipped(Widget child, {required bool morph}) {
      if (!morph || top.corners == bottom.corners) return child;
      return ClipRRect(
        borderRadius: BorderRadius.lerp(bottom.corners, top.corners, Curves.easeInOut.transform(t))!,
        child: child,
      );
    }

    Widget shuttle;
    if (flight.crossFades) {
      // Both nodes fly, fitted to the box: the top one fades in as the route
      // opens, the bottom one out, timed per flight.
      final (bottomOut, topIn) = switch (flight) {
        HeroFlightShuttle.fadeThrough => (const Interval(0, 0.35), const Interval(0.35, 1)),
        HeroFlightShuttle.containerTransform => (const Interval(0, 0.3), const Interval(0.2, 1)),
        _ => (const Interval(0, 1), const Interval(0, 1)),
      };
      Widget stack = Stack(
        fit: StackFit.expand,
        children: [
          Opacity(opacity: 1 - bottomOut.transform(t), child: drawn(bottom)),
          Opacity(opacity: topIn.transform(t), child: drawn(top)),
        ],
      );
      if (flight == HeroFlightShuttle.containerTransform) {
        // The container the two drawings fade on, as the card grows.
        stack = ColoredBox(color: Theme.of(context).colorScheme.surface, child: stack);
      }
      shuttle = clipped(stack, morph: true);
    } else {
      // The destination flies (the top one both ways when morphing the
      // corners); the other shows under it while its images load.
      final morph = flight == HeroFlightShuttle.morphCorners;
      final shown = morph ? top : destination;
      final other = identical(shown, top) ? bottom : top;
      shuttle = clipped(
        Stack(
          fit: StackFit.expand,
          children: [
            if (shown.child != null && imagesPendingUnder(shown.child!)) drawn(other),
            drawn(shown),
          ],
        ),
        morph: morph,
      );
    }
    if (flight == HeroFlightShuttle.arc) {
      // A curved flight that turns upright as it lands, with a swelling glow.
      final glow = top.glow ?? bottom.glow ?? const Color(0x80FFFFFF);
      final turn = push ? 0.6 : -0.6;
      final swell = math.sin(t * math.pi);
      final content = shuttle;
      shuttle = LayoutBuilder(builder: (context, constraints) {
        final size = constraints.biggest.shortestSide.isFinite ? constraints.biggest.shortestSide : 100.0;
        return Transform.rotate(
          angle: turn * (1 - t),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: glow.withValues(alpha: glow.a * swell), blurRadius: size * 0.5, spreadRadius: size * 0.06),
              ],
            ),
            child: content,
          ),
        );
      });
    }
    return Material(type: MaterialType.transparency, child: shuttle);
  }
}

/// The path of an arc flight: the centre travels a quadratic curve bowed to
/// the side by 28% of the distance (like Material's arc), while the size
/// changes evenly.
class HeroArcRectTween extends RectTween {
  HeroArcRectTween({super.begin, super.end});

  @override
  Rect? lerp(double t) {
    final b = begin, e = end;
    if (b == null || e == null) return super.lerp(t);
    final c0 = b.center, c1 = e.center;
    final mid = Offset.lerp(c0, c1, 0.5)!;
    final d = c1 - c0;
    final control = mid + Offset(-d.dy, d.dx) * 0.28;
    final u = 1 - t;
    final c = c0 * (u * u) + control * (2 * u * t) + c1 * (t * t);
    return Rect.fromCenter(center: c, width: lerpDouble(b.width, e.width, t)!, height: lerpDouble(b.height, e.height, t)!);
  }
}
