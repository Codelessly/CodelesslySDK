// A node's particles and its in-place hero flight (`hero` with
// `flies: inPlace`), as layers of its chain outside its motion. (Its one-shot effects are animations now:
// render/animations.dart.) A design canvas draws them at rest.
import 'dart:math' as math;

import 'package:codelessly_api/core.dart' as api;
import 'package:codelessly_api/core.dart' show Node;
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import 'behaviors.dart' show RenderPose;
import 'node_tree.dart' show NodeBox, RenderTree;
import 'recipe.dart';
import 'particles.dart';

/// Adds node [n]'s particles and in-place hero flight to [chain].
void playLayers(NodeBuilder b, Node n, List<RenderBox> chain, {required bool animates}) {
  final be = n.behaviors;
  if (animates && be.particles != null) {
    chain.add(b.obtain<RenderParticles>('particles', RenderParticles.new)
      ..nodeId = b.id
      ..emitter = be.particles!);
  }
  final hero = be.hero;
  if (animates && hero != null && hero.flies == api.HeroFlies.inPlace && hero.tag.trim().isNotEmpty) {
    // The spring of the node's motion transition, when it has one.
    final spring = api.Transition.of(be.transitions, 'motion')?.spring;
    chain.add(
      b.obtain<RenderFlightBox>('flight', RenderFlightBox.new)
        ..spring = spring != null
            ? SpringDescription(
                mass: 1,
                stiffness: spring.effectiveStiffness <= 0 ? 380 : spring.effectiveStiffness,
                damping: spring.effectiveDamping < 0 ? 20 : spring.effectiveDamping,
              )
            : const SpringDescription(mass: 1, stiffness: 420, damping: 24)
        ..flight = hero.flight
        ..flightKey = hero.tag.trim(),
    );
  }
}

// --- in-place hero flights: moves between nodes with the same tag ------------

class _FlightRecord {
  _FlightRecord(this.rect, this.time, this.owner);

  Rect rect;
  DateTime time;

  /// The box that drew it, or null for a dropped drag copy (or a box gone).
  final RenderFlightBox? owner;
}

/// Where each in-place hero tag was last seen, by every box that has it,
/// plus where dragged copies were let go.
abstract final class FlightRegistry {
  static final Map<String, List<_FlightRecord>> _records = {};

  /// Whether a tree's screen is on its way out (its route closing): a
  /// holder there is as good as gone, so a picked emoji flies from a
  /// popover while it fades. Set by the runtime that knows the routes.
  static bool Function(RenderTree tree) leaving = _never;
  static bool _never(RenderTree tree) => false;

  /// A dragged copy with [key] was let go at [rect] (global): the node that
  /// shows the drop next flies from there.
  static void recordDrop(String key, Rect rect) {
    if (key.isEmpty) return;
    final list = _records[key] ??= [];
    list.removeWhere((r) => r.owner == null);
    list.add(_FlightRecord(rect, DateTime.now(), null));
  }

  static void _paint(RenderFlightBox box, String key, Rect rect) {
    final list = _records[key] ??= [];
    final mine = list.where((r) => r.owner == box).firstOrNull;
    if (mine == null) {
      list.add(_FlightRecord(rect, DateTime.now(), box));
    } else {
      mine
        ..rect = rect
        ..time = DateTime.now();
    }
  }

  static void _forget(RenderFlightBox box, String key) {
    final list = _records[key];
    if (list == null) return;
    // A box that goes keeps its last place for a moment, so the node that
    // replaces it can fly from there.
    for (final r in list) {
      if (r.owner == box) {
        list
          ..remove(r)
          ..add(_FlightRecord(r.rect, DateTime.now(), null));
        break;
      }
    }
  }

  /// Where a node with [key] that [box] now shows flies from: the latest
  /// place another holder of the key was seen that isn't on screen any more
  /// (hidden, removed within two seconds, or a drag let go).
  static Rect? _source(RenderFlightBox? box, String key) {
    final list = _records[key];
    if (list == null) return null;
    final now = DateTime.now();
    // Two seconds of animation time: a popover that takes its time closing
    // (slowed animations, a busy device) still lets its emoji fly.
    final keep = const Duration(seconds: 2) * timeDilation;
    list.removeWhere((r) => r.owner == null && now.difference(r.time) >= keep);
    _FlightRecord? best;
    for (final r in list) {
      if (box != null && r.owner == box) continue;
      if (r.owner != null && r.owner!.isShowing) continue;
      if (best == null || r.time.isAfter(best.time)) best = r;
    }
    return best?.rect;
  }

  /// Where a node with [key] would fly from now (tests).
  @visibleForTesting
  static Rect? sourceOf(String key) => _source(null, key);

  /// Clears every record (tests).
  static void reset() => _records.clear();
}

/// Records where its node is drawn under its in-place hero tag and, the
/// first time it's drawn, flies it in from where another node with the tag
/// was, on a spring (or as its hero's `flight` says).
class RenderFlightBox extends RenderPose {
  String _flightKey = '';
  bool _placed = false;
  set flightKey(String v) {
    if (v == _flightKey) return;
    if (_flightKey.isNotEmpty) FlightRegistry._forget(this, _flightKey);
    _flightKey = v;
    _placed = false;
    markNeedsPaint();
  }

  SpringDescription spring = const SpringDescription(mass: 1, stiffness: 420, damping: 24);

  /// A timed, curved flight instead of the spring (when its duration is
  /// set).
  api.Flight? flight;

  /// The flight's path in this box's rest coordinates: from the source's
  /// center offset to zero, through [_control].
  Offset _control = Offset.zero;
  double _turnSign = 1;
  double _u = 1;

  Offset _fromOffset = Offset.zero;
  double _fromScale = 1;
  double _value = 1;
  Ticker? _ticker;
  SpringSimulation? _sim;

  /// Whether it's on screen: attached, and not under an offstage or fully
  /// transparent ancestor.
  bool get isShowing {
    if (!attached) return false;
    RenderObject? node = this;
    while (node != null) {
      if (node is RenderOffstage && node.offstage) return false;
      if (node is RenderOpacity && node.opacity == 0) return false;
      if (node is RenderAnimatedOpacity && node.opacity.value == 0) return false;
      if (node is NodeBox && (!node.drawn || FlightRegistry.leaving(node.tree))) return false;
      node = node.parent;
    }
    return true;
  }

  void _placedAt(Rect rect, Rect? from) {
    if (from == null || from == rect) return;
    // Starts in the next frame: this one is being painted.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!attached) return;
      _fromOffset = from.center - rect.center;
      _fromScale = rect.width > 0 ? from.width / rect.width : 1;
      final f = flight;
      if (f != null && f.duration > 0) {
        // The control point: halfway across, risen above the higher end.
        final rise = math.max(f.lift, f.liftShare * _fromOffset.distance);
        final top = math.min(_fromOffset.dy, 0.0);
        _control = Offset(_fromOffset.dx / 2, top - rise);
        _turnSign = _fromOffset.dx <= 0 ? 1 : -1; // flying right (from the left) turns clockwise
        _sim = null;
        _u = 0;
      } else {
        _sim = SpringSimulation(spring, 0, 1, 0);
      }
      _value = 0;
      _show();
      _ticker ??= Ticker(_tick);
      if (_ticker!.isActive) _ticker!.stop();
      _ticker!.start();
    });
    SchedulerBinding.instance.scheduleFrame();
  }

  /// A point of the curved flight at [u] (0 at the source, 1 at rest).
  Offset _pathAt(double u) {
    final a = _fromOffset, c = _control;
    final v = 1 - u;
    return a * (v * v) + c * (2 * v * u);
  }

  void _tick(Duration elapsed) {
    final f = flight;
    if (f != null && f.duration > 0 && _value < 1) {
      final t = (elapsed.inMicroseconds / 1000 / f.duration).clamp(0.0, 1.0);
      _u = f.curve.transform(t);
      _value = t >= 1 ? 1 : _u;
      if (t >= 1) {
        _u = 1;
        _ticker?.stop();
      }
      _showFlight(f);
      return;
    }
    final sim = _sim;
    if (sim == null) return;
    final t = elapsed.inMicroseconds / 1e6;
    _value = sim.x(t);
    if (sim.isDone(t)) {
      _value = 1;
      _sim = null;
      _ticker?.stop();
    }
    _show();
  }

  void _showFlight(api.Flight f) {
    final u = _u;
    final p = _pathAt(u);
    final s = (1 + (_fromScale - 1) * (1 - u)) * (1 + (f.swell - 1) * math.sin(u * math.pi));
    shift = Offset.zero;
    origin = Alignment.center;
    transform = u >= 1
        ? Matrix4.identity()
        : (Matrix4.translationValues(p.dx, p.dy, 0)
          ..rotateZ(_turnSign * f.turns * 2 * math.pi * u)
          ..scaleByDouble(s, s, 1, 1));
    markNeedsPaint();
  }

  void _show() {
    final rest = 1 - _value;
    final s = 1 + (_fromScale - 1) * rest;
    shift = Offset.zero;
    origin = Alignment.center;
    transform = Matrix4.translationValues(_fromOffset.dx * rest, _fromOffset.dy * rest, 0)..scaleByDouble(s, s, 1, 1);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    // Back from a re-parenting (a hover style lifting its card): the flight
    // carries on where its clock is.
    _ticker?.muted = false;
  }

  @override
  void detach() {
    if (_flightKey.isNotEmpty) FlightRegistry._forget(this, _flightKey);
    // Muted, not stopped: a box only moved to another parent comes back in
    // the same frame and must not freeze where its flight began.
    _ticker?.muted = true;
    super.detach();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _ticker = null;
    super.dispose();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final f = flight;
    if (f != null && f.trail > 0 && f.duration > 0 && _u < 1 && _value < 1 && hasSize) {
      // Fading dots where the flight just was.
      final center = offset + size.center(Offset.zero);
      for (var i = f.trail; i >= 1; i--) {
        final u = _u - i * 26 / f.duration;
        if (u <= 0) continue;
        final alpha = (0.55 - i * 0.11).clamp(0.0, 1.0);
        context.canvas.drawCircle(
          center + _pathAt(f.curve.transform(u.clamp(0.0, 1.0))),
          math.max(1.0, 5.0 - i),
          Paint()..color = Color(f.trailColor.value).withValues(alpha: alpha * ((f.trailColor.value >> 24) / 255)),
        );
      }
    }
    super.paint(context, offset);
    if (_flightKey.isEmpty || !hasSize) return;
    // Its layout place, not where the flight draws it.
    final rect = localToGlobal(Offset.zero) & size;
    if (!_placed) {
      _placed = true;
      _placedAt(rect, FlightRegistry._source(this, _flightKey));
    }
    FlightRegistry._paint(this, _flightKey, rect);
  }
}
