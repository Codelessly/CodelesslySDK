// A node's one-shot effects (shake, wiggle, jelly... on cue) and its fly-in
// by flight key, as layers of its chain outside its motion. SDK 8.x's
// NodePlayBox and FlightBox. A design canvas draws them at rest.
import 'dart:async';
import 'dart:math' as math;

import 'package:codelessly_api_v2/codelessly_api.dart' as api;
import 'package:codelessly_api_v2/codelessly_api.dart' show Node;
import 'package:flutter/animation.dart' show Curves;
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import 'behaviours.dart' show RenderPose;
import 'node_tree.dart' show NodeBox;
import 'recipe.dart';
import 'particles.dart';

/// Adds node [n]'s fly-in and one-shot effects to [chain].
void playLayers(NodeBuilder b, Node n, List<RenderBox> chain, {required bool animates}) {
  final be = n.behaviours;
  if (animates && be.particles != null) {
    chain.add(b.obtain<RenderParticles>('particles', RenderParticles.new)
      ..nodeId = b.id
      ..emitter = be.particles!);
  }
  if (animates && be.flightKey.isNotEmpty) {
    final motion = be.motion;
    chain.add(
      b.obtain<RenderFlightBox>('flight', RenderFlightBox.new)
        ..spring = motion != null && motion.curve == api.AnimationCurve.spring
            ? SpringDescription(
                mass: 1,
                stiffness: motion.springStiffness <= 0 ? 380 : motion.springStiffness,
                damping: motion.springDamping < 0 ? 20 : motion.springDamping,
              )
            : const SpringDescription(mass: 1, stiffness: 420, damping: 24)
        ..flightKey = be.flightKey,
    );
  }
  if (animates && be.effectAnimations.isNotEmpty) {
    chain.add(
      b.obtain<RenderEffects>('effects', RenderEffects.new)
        ..nodeId = b.id
        ..effects = be.effectAnimations,
    );
  }
}

/// The transform of a one-shot [type] at progress [t] (0 to 1) and strength
/// [amount]: offsets in logical pixels, scales, a rotation in radians and
/// an opacity. [cycles] (when above 0) is how many times a shake, wiggle or
/// jelly swings, or a flash blinks.
({double dx, double dy, double sx, double sy, double rotation, double opacity}) effectTransformAt(
  api.EffectAnimationType type,
  double t,
  double amount, {
  double cycles = 0,
}) {
  final decay = 1 - t;
  double swings(double usual) => cycles > 0 ? cycles : usual;
  switch (type) {
    case api.EffectAnimationType.shake:
      return (dx: math.sin(t * math.pi * 2 * swings(4)) * 12 * amount * decay, dy: 0, sx: 1, sy: 1, rotation: 0, opacity: 1);
    case api.EffectAnimationType.bounce:
      // Up fast, down, two smaller hops; squashes as it lands.
      final hop = (math.sin(t * math.pi * 3) * decay).abs();
      final squash = t > 0.3 ? math.sin((t - 0.3) / 0.7 * math.pi * 3) * 0.08 * decay : 0.0;
      return (dx: 0, dy: -22 * amount * hop, sx: 1 + squash * amount, sy: 1 - squash * amount, rotation: 0, opacity: 1);
    case api.EffectAnimationType.pop:
      final s = 1 + math.sin(t * math.pi) * 0.22 * amount * (1 - t / 2);
      return (dx: 0, dy: 0, sx: s, sy: s, rotation: 0, opacity: 1);
    case api.EffectAnimationType.wiggle:
      return (dx: 0, dy: 0, sx: 1, sy: 1, rotation: math.sin(t * math.pi * 2 * swings(3)) * 0.14 * amount * decay, opacity: 1);
    case api.EffectAnimationType.jelly:
      final w = math.sin(t * math.pi * 2 * swings(2)) * 0.16 * amount * decay;
      return (dx: 0, dy: 0, sx: 1 + w, sy: 1 - w, rotation: 0, opacity: 1);
    case api.EffectAnimationType.flash:
      return (dx: 0, dy: 0, sx: 1, sy: 1, rotation: 0, opacity: 0.5 + math.cos(t * math.pi * 2 * swings(2)) * 0.5);
    case api.EffectAnimationType.spin:
      return (dx: 0, dy: 0, sx: 1, sy: 1, rotation: Curves.easeInOutCubic.transform(t) * 2 * math.pi * amount, opacity: 1);
  }
}

/// The nodes' effects on screen, by node id, for `playAnimation`.
abstract final class EffectPlayers {
  static final Map<String, Set<RenderEffects>> _byNode = {};

  /// Plays effect [name] on every shown instance of node [nodeId];
  /// completes when the longest ends (at once when none is shown).
  static Future<void> play(String nodeId, String name) async {
    await Future.wait([
      for (final e in [...?_byNode[nodeId]])
        if (e.attached) e.play(name),
    ]);
  }

  static void _add(RenderEffects e) => (_byNode[e._nodeId] ??= {}).add(e);

  static void _remove(RenderEffects e) {
    final set = _byNode[e._nodeId];
    set?.remove(e);
    if (set != null && set.isEmpty) _byNode.remove(e._nodeId);
  }
}

class _Play {
  _Play(this.effect);
  api.EffectAnimation effect;
  Duration? start;
  Timer? delay;
  double t = 0;
  final Completer<void> done = Completer();

  void finish() {
    delay?.cancel();
    if (!done.isCompleted) done.complete();
  }
}

/// Plays a node's one-shot effects: when an action names one, when its
/// bound `playKey` changes, or when it first shows (`playOnAppear`). Each
/// draws over the node's layout like a motion, about its own origin.
class RenderEffects extends RenderPose {
  RenderEffects() {
    origin = Alignment.topLeft;
  }

  String _nodeId = '';
  set nodeId(String v) {
    if (v == _nodeId) return;
    if (attached) EffectPlayers._remove(this);
    _nodeId = v;
    if (attached) EffectPlayers._add(this);
  }

  List<api.EffectAnimation> _effects = const [];
  bool _set = false;
  set effects(List<api.EffectAnimation> v) {
    final old = _effects;
    _effects = v;
    if (!_set) {
      _set = true;
      return;
    }
    // A changed cue plays the effect (not the first one it shows with).
    for (final e in v) {
      final before = old.where((o) => o.name == e.name).firstOrNull;
      if (before != null && before.playKey != e.playKey) play(e.name);
    }
  }

  final Map<String, _Play> _playing = {};
  Ticker? _ticker;
  bool _appeared = false;

  /// Plays effect [name]; completes when it ends.
  Future<void> play(String name) {
    final effect = _effects.where((e) => e.name == name).firstOrNull;
    if (effect == null) return Future.value();
    final previous = _playing.remove(name);
    previous?.finish();
    final p = _playing[name] = _Play(effect);
    void begin() {
      if (!attached || !identical(_playing[name], p)) return p.finish();
      p.start = null;
      _ticker ??= Ticker(_tick);
      if (!_ticker!.isActive) _ticker!.start();
    }

    if (effect.delay > 0) {
      p.delay = Timer(Duration(milliseconds: effect.delay), begin);
    } else {
      begin();
    }
    return p.done.future;
  }

  Duration _now = Duration.zero;

  void _tick(Duration elapsed) {
    _now = elapsed;
    for (final e in [..._playing.entries]) {
      final p = e.value;
      if (p.delay?.isActive ?? false) continue;
      p.start ??= elapsed;
      final ms = math.max(1, p.effect.duration);
      p.t = ((elapsed - p.start!).inMicroseconds / 1000 / ms).clamp(0.0, 1.0);
      if (p.t >= 1) {
        _playing.remove(e.key);
        p.finish();
      }
    }
    _apply();
    if (_playing.values.every((p) => p.delay?.isActive ?? false)) _ticker?.stop();
  }

  /// Each playing effect over the last: a move, then a turn and scale about
  /// the effect's origin, and its opacity.
  void _apply() {
    final m = Matrix4.identity();
    var opacity = 1.0;
    final s = hasSize ? size : Size.zero;
    for (final effect in _effects) {
      final p = _playing[effect.name];
      if (p == null || p.start == null) continue;
      final e = effectTransformAt(effect.type, p.t, effect.amount, cycles: effect.cycles);
      final o = Alignment(effect.originX, effect.originY).alongSize(s);
      final step = Matrix4.translationValues(e.dx + o.dx, e.dy + o.dy, 0)
        ..rotateZ(e.rotation)
        ..scaleByDouble(e.sx, e.sy, 1, 1)
        ..translateByDouble(-o.dx, -o.dy, 0, 1);
      m.setFrom(step..multiply(m));
      opacity *= e.opacity.clamp(0.0, 1.0);
    }
    transform = m;
    this.opacity = opacity;
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    EffectPlayers._add(this);
    if (!_appeared) {
      _appeared = true;
      for (final e in _effects) {
        if (e.playOnAppear) play(e.name);
      }
    }
    if (_playing.isNotEmpty) {
      // A restarted ticker counts from zero: the effects playing start over.
      for (final p in _playing.values) {
        p.start = null;
      }
      _ticker ??= Ticker(_tick);
      if (!_ticker!.isActive) _ticker!.start();
    }
  }

  @override
  void detach() {
    EffectPlayers._remove(this);
    _ticker?.stop();
    super.detach();
  }

  @override
  void dispose() {
    for (final p in _playing.values) {
      p.finish();
    }
    _playing.clear();
    _ticker?.dispose();
    _ticker = null;
    super.dispose();
  }

  /// Elapsed time of the last frame (tests).
  Duration get debugNow => _now;
}

// --- flights: moves between nodes with the same flight key ---------------------

class _FlightRecord {
  _FlightRecord(this.rect, this.time, this.owner);

  Rect rect;
  DateTime time;

  /// The box that drew it, or null for a dropped drag copy (or a box gone).
  final RenderFlightBox? owner;
}

/// Where each flight key was last seen, by every box that has it, plus
/// where dragged copies were let go.
abstract final class FlightRegistry {
  static final Map<String, List<_FlightRecord>> _records = {};

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
  static Rect? _source(RenderFlightBox box, String key) {
    final list = _records[key];
    if (list == null) return null;
    final now = DateTime.now();
    list.removeWhere((r) => r.owner == null && now.difference(r.time).inSeconds >= 2);
    _FlightRecord? best;
    for (final r in list) {
      if (r.owner == box) continue;
      if (r.owner != null && r.owner!.isShowing) continue;
      if (best == null || r.time.isAfter(best.time)) best = r;
    }
    return best?.rect;
  }

  /// Clears every record (tests).
  static void reset() => _records.clear();
}

/// Records where its node is drawn under its flight key and, the first time
/// it's drawn, flies it in from where another node with the key was, on a
/// spring.
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
      if (node is NodeBox && !node.drawn) return false;
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
      _sim = SpringSimulation(spring, 0, 1, 0);
      _value = 0;
      _show();
      _ticker ??= Ticker(_tick);
      if (_ticker!.isActive) _ticker!.stop();
      _ticker!.start();
    });
    SchedulerBinding.instance.scheduleFrame();
  }

  void _tick(Duration elapsed) {
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

  void _show() {
    final rest = 1 - _value;
    final s = 1 + (_fromScale - 1) * rest;
    shift = Offset.zero;
    origin = Alignment.center;
    transform = Matrix4.translationValues(_fromOffset.dx * rest, _fromOffset.dy * rest, 0)..scaleByDouble(s, s, 1, 1);
  }

  @override
  void detach() {
    if (_flightKey.isNotEmpty) FlightRegistry._forget(this, _flightKey);
    _ticker?.stop();
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
