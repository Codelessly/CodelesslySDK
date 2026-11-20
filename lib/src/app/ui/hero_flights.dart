// Shared element flights between the screens a navigation moves between:
// the app shell's
// routes ([CodelesslyHeroRoute]) find the hero marks (render/hero.dart) with
// the same tag on the screen below and the screen on top, hide both, and fly
// a drawing of the node in the navigator's overlay on the route's
// animation, as each node's `hero.flightShuttle` says.
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:codelessly_api/core.dart' show AnimationCurve, HeroFlies, HeroFlightShuttle, HeroPlaceholder;
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../render/control_theme.dart' show ThemeTokensScope, kPaper, kPaperDark, rolesOf;
import '../../render/hero.dart';
import '../../render/node_tree.dart';
import '../../render/play.dart' show FlightRegistry;

/// The routes the screens of each node tree show in, as the app shell
/// reports them.
abstract final class HeroRoutes {
  static final Expando<ModalRoute<Object?>> _routeOf = Expando('heroRoute');

  /// [tree] shows in [route] now.
  static void bind(RenderTree tree, ModalRoute<Object?>? route) {
    _routeOf[tree] = route;
    FlightRegistry.leaving = leaving;
    HeroMarks.leaving = leaving;
    HeroLifts._install();
  }

  /// The navigator [tree]'s screen shows in, when it is known.
  static NavigatorState? navigatorOf(RenderTree tree) => _routeOf[tree]?.navigator;

  /// Whether [tree]'s route is closing (popped, its exit still playing) or
  /// gone: what it shows is on its way out.
  static bool leaving(RenderTree tree) {
    final route = _routeOf[tree];
    if (route == null) return false;
    return !route.isActive || route.animation?.status == AnimationStatus.reverse;
  }

  /// The marks with a tag on the screens [route] shows, the first per tag.
  static Map<String, RenderHeroMark> marksOf(ModalRoute<Object?> route) {
    final out = <String, RenderHeroMark>{};
    for (final entry in HeroMarks.trees) {
      if (!identical(_routeOf[entry], route)) continue;
      for (final m in HeroMarks.of(entry)) {
        // A lifted hero flies on its own (HeroLifts), not with a navigation.
        if (m.flies != HeroFlies.betweenScreens) continue;
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
      _startWhenShown(upper, framesLeft: 6);
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  /// Starts [upper]'s push flights once its screen has drawn its shared
  /// elements: a screen builds its tree a frame or two after its route goes
  /// in (loading its layout, its data), so it is looked for again on the
  /// next frames while the transition is still early.
  static void _startWhenShown(CodelesslyHeroRoute<Object?> upper, {required int framesLeft}) {
    final lower = upper.heroRouteBelow;
    if (lower == null || upper.navigator == null || !upper.isActive) return;
    if (HeroRoutes.marksOf(upper).isNotEmpty || framesLeft <= 0 || (upper.animation?.value ?? 1) > 0.35) {
      _start(lower: lower, upper: upper, push: true);
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _startWhenShown(upper, framesLeft: framesLeft - 1));
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
    final tops = HeroRoutes.marksOf(upper);
    if (bottoms.isEmpty) return;
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
  HeroFlightShuttle get flight =>
      bottom.flightShuttle.index > top.flightShuttle.index ? bottom.flightShuttle : top.flightShuttle;

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
    // tween: an arc, a straight line for a container, else two corners on
    // quarter-circle arcs.
    _tween = switch (destination.flightShuttle) {
      HeroFlightShuttle.arc => HeroArcRectTween(begin: from, end: to),
      HeroFlightShuttle.containerTransform => RectTween(begin: from, end: to),
      _ => HeroCornerArcRectTween(begin: from, end: to),
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
        // The layout's surface: the flight is in the app's overlay, whose
        // theme isn't the layout's.
        final surface = ThemeTokensScope.maybeOf(context) != null
            ? rolesOf(context).surface
            : (MediaQuery.maybePlatformBrightnessOf(context) == Brightness.dark ? kPaperDark : kPaper);
        stack = ColoredBox(color: surface, child: stack);
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
    return shuttle;
  }
}

/// The path of an arc flight: the center travels a quadratic curve bowed to
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

/// The default path of a flight: the two corners of the box on the diagonal
/// nearest its direction of travel each go along a circular arc
/// ([_PointArc]), and the box is what they span. What Flutter's own hero
/// flies on in a Material app.
class HeroCornerArcRectTween extends RectTween {
  HeroCornerArcRectTween({super.begin, super.end});

  _PointArc? _first, _second;

  static Offset _corner(Rect r, int id) => switch (id) {
        0 => r.topLeft,
        1 => r.topRight,
        2 => r.bottomLeft,
        _ => r.bottomRight,
      };

  // The diagonals, as (from corner, to corner): the first that lies most
  // along the centers' travel is flown.
  static const _diagonals = [(0, 3), (3, 0), (1, 2), (2, 1)];

  void _initialize(Rect b, Rect e) {
    final travel = e.center - b.center;
    var best = _diagonals.first;
    double? bestSupport;
    for (final d in _diagonals) {
      final delta = _corner(b, d.$2) - _corner(b, d.$1);
      final length = delta.distance;
      final support = travel.dx * delta.dx / length + travel.dy * delta.dy / length;
      if (bestSupport == null || support > bestSupport) {
        best = d;
        bestSupport = support;
      }
    }
    _first = _PointArc(_corner(b, best.$1), _corner(e, best.$1));
    _second = _PointArc(_corner(b, best.$2), _corner(e, best.$2));
  }

  @override
  set begin(Rect? value) {
    if (value != begin) _first = null;
    super.begin = value;
  }

  @override
  set end(Rect? value) {
    if (value != end) _first = null;
    super.end = value;
  }

  @override
  Rect? lerp(double t) {
    final b = begin, e = end;
    if (b == null || e == null) return super.lerp(t);
    if (t == 0) return b;
    if (t == 1) return e;
    if (_first == null) _initialize(b, e);
    return Rect.fromPoints(_first!.at(t), _second!.at(t));
  }
}

/// A point's way from [begin] to [end] on a circular arc of at most a
/// quarter turn: the circle's center is level with the end when the way is
/// taller than wide, else in line with the beginning. A way that is (within
/// 2 px) straight across or straight down is a straight line.
class _PointArc {
  _PointArc(this.begin, this.end) {
    final delta = end - begin;
    final dx = delta.dx.abs(), dy = delta.dy.abs();
    final distance = delta.distance;
    if (dx <= 2 || dy <= 2) return;
    final corner = Offset(end.dx, begin.dy);
    double sweep(double radius) => 2 * math.asin(distance / (2 * radius));
    if (dx < dy) {
      final r = _radius = distance * distance / (corner - begin).distance / 2;
      _center = Offset(end.dx + r * (begin.dx - end.dx).sign, end.dy);
      if (begin.dx < end.dx) {
        _from = sweep(r) * (begin.dy - end.dy).sign;
        _to = 0;
      } else {
        _from = math.pi + sweep(r) * (end.dy - begin.dy).sign;
        _to = math.pi;
      }
    } else {
      final r = _radius = distance * distance / (corner - end).distance / 2;
      _center = Offset(begin.dx, begin.dy + (end.dy - begin.dy).sign * r);
      if (begin.dy < end.dy) {
        _from = -math.pi / 2;
        _to = _from! + sweep(r) * (end.dx - begin.dx).sign;
      } else {
        _from = math.pi / 2;
        _to = _from! + sweep(r) * (begin.dx - end.dx).sign;
      }
    }
  }

  final Offset begin, end;
  double _radius = 0;
  Offset _center = Offset.zero;
  double? _from, _to;

  Offset at(double t) {
    final from = _from, to = _to;
    if (from == null || to == null) return Offset.lerp(begin, end, t)!;
    final angle = lerpDouble(from, to, t)!;
    return _center + Offset(math.cos(angle) * _radius, math.sin(angle) * _radius);
  }
}

/// Draws [mark]'s node stretched over the box it's given (the flight's box
/// in between), repainting with [repaint].
class HeroMarkPaint extends LeafRenderObjectWidget {
  const HeroMarkPaint({super.key, required this.mark, this.repaint});

  final RenderHeroMark mark;
  final Listenable? repaint;

  @override
  RenderHeroMarkPaint createRenderObject(BuildContext context) => RenderHeroMarkPaint(mark, repaint);

  @override
  void updateRenderObject(BuildContext context, RenderHeroMarkPaint renderObject) => renderObject
    ..mark = mark
    ..repaint = repaint;
}

// --- lifted shared elements (`hero` with `flies: lift`) ----------------------------

/// Lifted shared elements ([HeroFlies.lift]): of the marks with one tag on
/// screen, the newest is the one shown; when it changes (a node with the
/// tag comes while another is shown, or the one shown goes), the node is
/// flown from the one it leaves to the one it goes to, drawn in the
/// navigator's overlay above every route (an overlay's backdrop too), both
/// ends followed every frame. The mark it left keeps its place, hidden
/// ([RenderHeroMark.liftShown]).
abstract final class HeroLifts {
  static bool _installed = false;
  static bool _scheduled = false;

  /// The mark of each tag shown now.
  static final Map<String, RenderHeroMark> _front = {};
  static final List<_Lift> _lifts = [];

  /// Whether a lift is in the air (tests).
  static bool get flying => _lifts.isNotEmpty;

  /// Where the lift of [tag] is drawn now (global), null when none flies
  /// (tests).
  static Rect? rectOf(String tag) => _lifts.where((l) => l.tag == tag).firstOrNull?.rect;

  static void _install() {
    if (_installed) return;
    _installed = true;
    HeroMarks.onLiftChange = _schedule;
    // A screen that starts closing changes no mark: while lifted marks are
    // on screen, each frame looks again (after it is drawn).
    // Runs after the frame is laid out and drawn (the renderer's callback is
    // added first): each lifted node's place is recorded for a flight back
    // from it once it has gone, however it got there (a scroll moves a row
    // without painting it again).
    SchedulerBinding.instance.addPersistentFrameCallback((_) {
      for (final m in HeroMarks.allLifted) {
        m.notePlace();
      }
      if (_front.isNotEmpty || _lifts.isNotEmpty) _schedule(frame: false);
    });
  }

  static void _schedule({bool frame = true}) {
    if (_scheduled) return;
    _scheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) => _check());
    if (frame) SchedulerBinding.instance.ensureVisualUpdate();
  }

  static bool _going(RenderHeroMark m) => !m.attached || (m.tree != null && HeroMarks.leaving(m.tree!));

  static void _check() {
    _scheduled = false;
    final tags = {for (final m in HeroMarks.allLifted) m.tag, ..._front.keys};
    for (final tag in tags) {
      final shown = [for (final m in HeroMarks.lifted(tag)) if (!_going(m) && m.hasSize) m];
      final newest = shown.lastOrNull;
      var front = _front[tag];
      // A screen closed and gone: nothing flies from it.
      if (front != null && (front.tree == null || front.tree!.isDisposed)) {
        _front.remove(tag);
        front = null;
      }
      if (identical(newest, front)) continue;
      if (newest == null) {
        // Nothing to go to: the last one shown stays while it is on screen.
        if (front != null && !front.attached) _front.remove(tag);
        continue;
      }
      _front[tag] = newest;
      newest.liftFront = true;
      if (front == null) continue;
      front.liftFront = false;
      _fly(tag, front, newest);
    }
  }

  static void _fly(String tag, RenderHeroMark from, RenderHeroMark to) {
    // A lift of the tag in the air turns round from where it is drawn.
    Rect? start;
    for (final l in [..._lifts]) {
      if (l.tag == tag) {
        start = l.rect;
        l.end();
      }
    }
    final navigator = (to.tree == null ? null : HeroRoutes.navigatorOf(to.tree!)) ??
        (from.tree == null ? null : HeroRoutes.navigatorOf(from.tree!));
    final overlay = navigator?.overlay;
    if (overlay == null || !overlay.mounted) return;
    if (MediaQuery.maybeDisableAnimationsOf(overlay.context) ?? false) return;
    // Out (the newer one comes) on the lifted node's flight; back on the
    // same flight's curve played backward.
    final out = to.arrival > from.arrival;
    final lifted = out ? to : from;
    final f = lifted.flight;
    final lift = _Lift(
      tag: tag,
      from: from,
      to: to,
      // Only a turn-round has a fixed start: else the node it leaves is read
      // where it is on screen, every frame ([_Lift._at]).
      start: start,
      duration: Duration(milliseconds: f != null && f.duration > 0 ? f.duration : 300),
      curve: f?.curve ?? AnimationCurve.easeInOut,
      back: !out,
    );
    if (lift.begin(overlay)) _lifts.add(lift);
  }
}

class _Lift {
  _Lift({
    required this.tag,
    required this.from,
    required this.to,
    required this.start,
    required this.duration,
    required this.curve,
    required this.back,
  });

  final String tag;
  final RenderHeroMark from, to;

  /// Where it starts (global) when it turns round from a lift in the air.
  final Rect? start;
  final Duration duration;
  final AnimationCurve curve;

  /// The way back: the curve played backward.
  final bool back;

  final ValueNotifier<double> _t = ValueNotifier(0);
  Ticker? _ticker;
  OverlayEntry? _entry;
  RenderBox? _space;
  bool _ended = false;

  /// Where it is drawn now (global).
  Rect? rect;

  /// The share of the way flown at [t] (0–1 of the time).
  double _progress(double t) => back ? 1 - curve.transform(1 - t) : curve.transform(t);

  Rect? _live(RenderHeroMark m) {
    if (!m.attached || !m.hasSize) return null;
    try {
      return MatrixUtils.transformRect(m.getTransformTo(null), Offset.zero & m.size);
    } catch (_) {
      return null;
    }
  }

  /// Where it is at the clock's [t], both ends where they are now.
  Rect? _at(double t) {
    // A turn-round starts where it was drawn; else the place it leaves is
    // followed where it is now (a list scrolling under it), and once that
    // node has gone, where it was at the end of its last frame.
    final begin = start ?? _live(from) ?? from.lastRect;
    final e = _live(to);
    if (begin == null || e == null) return null;
    return Rect.lerp(begin, e, _progress(t));
  }

  bool begin(OverlayState overlay) {
    final first = _at(0);
    if (first == null) return false;
    rect = first;
    final box = overlay.context.findRenderObject();
    _space = box is RenderBox ? box : null;
    to.flying = true;
    _entry = OverlayEntry(builder: _build);
    overlay.insert(_entry!);
    _ticker = Ticker((elapsed) {
      final t = duration.inMicroseconds == 0 ? 1.0 : (elapsed.inMicroseconds / duration.inMicroseconds).clamp(0.0, 1.0);
      if (!to.attached) {
        // The place it went to is gone (its row removed): nothing to land on.
        end();
        return;
      }
      _t.value = t;
      rect = _at(t) ?? rect;
      _entry?.markNeedsBuild();
      if (t >= 1) end();
    })
      ..start();
    return true;
  }

  void end() {
    if (_ended) return;
    _ended = true;
    HeroLifts._lifts.remove(this);
    _ticker?.dispose();
    _ticker = null;
    _entry?.remove();
    _entry?.dispose();
    _entry = null;
    to.flying = false;
    SchedulerBinding.instance.addPostFrameCallback((_) => _t.dispose());
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  Widget _build(BuildContext context) {
    final r = rect;
    if (r == null || _ended) return const SizedBox.shrink();
    final space = _space;
    final local = space != null && space.attached
        ? Rect.fromPoints(space.globalToLocal(r.topLeft), space.globalToLocal(r.bottomRight))
        : r;
    return Positioned.fromRect(rect: local, child: IgnorePointer(child: HeroMarkPaint(mark: to, repaint: _t)));
  }
}
