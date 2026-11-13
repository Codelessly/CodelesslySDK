// A node's `animations` (api.NodeAnimation, docs/design/02-animation.md):
// one player per node, ticking inside its render object. Each animation is
// an [AnimationClock], an `AnimationController` on the player's ticker;
// each tick maps every clock's value through its tracks:
//
//   * tracks that add or multiply on `motion.*` and `opacity` pose this
//     layer itself (a `ScaleTransition`/`RotationTransition`/
//     `SlideTransition`/`FadeTransition` around the node's content, about
//     the animation's alignment);
//   * tracks that replace `motion.*` values set the node's motion layer;
//     `opacity` the node's opacity;
//   * any other binding path patches the node as shown (the tree re-applies
//     it); a `variable` track writes the variable.
//
// A design canvas (a tree that doesn't animate) runs no clock: it draws an
// animation only at its `previewAt`, else the node's own values (an
// entrance at its end).
import 'dart:async';
import 'dart:math' as math;

import 'package:codelessly_api/core.dart' as api;
import 'package:codelessly_api/core.dart' show Node;
import 'package:flutter/animation.dart' show AnimationStatus;
import 'package:flutter/foundation.dart' show Listenable;
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import 'behaviors.dart' show RenderMotion, RenderPose;
import 'contracts.dart';
import 'node_tree.dart' show NodeBox;
import 'physics.dart' show describeSpring;
import 'recipe.dart';

/// The `motion.*` properties a track can drive.
const Set<String> motionTrackProperties = {
  'translateX', 'translateY', 'scale', 'scaleX', 'scaleY', 'shiftX', 'shiftY', 'opacity', 'rotate', 'rotateX', //
  'rotateY', 'pathProgress', 'blur',
};

/// The properties of [n]'s motion its animations replace (their tracks set
/// them): the node needs a motion layer for them.
Set<String> replacedMotionProperties(Node n) => {
      for (final a in n.behaviors.animations)
        if (a.enabled)
          for (final t in a.expanded.tracks)
            if (t.variable.isEmpty && t.node.isEmpty && t.blend == api.TrackBlend.replace && t.path.startsWith('motion.'))
              if (motionTrackProperties.contains(t.path.substring(7))) t.path.substring(7),
    };

/// Whether [n]'s animations replace its own opacity.
bool animatesOpacity(Node n) => n.behaviors.animations.any((a) =>
    a.enabled &&
    a.expanded.tracks.any((t) => t.variable.isEmpty && t.node.isEmpty && t.path == 'opacity' && t.blend == api.TrackBlend.replace));

/// Adds [n]'s animation player to [chain] (where the loops were: inside the
/// motion and rotation, outside the opacity).
void animationLayers(NodeBuilder b, Node n, List<RenderBox> chain, {required bool animates, RenderMotion? motion}) {
  if (n.behaviors.animations.isEmpty) return;
  final box = b is NodeBox ? b : null;
  chain.add(
    b.obtain<RenderAnimations>('animations', RenderAnimations.new)
      ..configure(box, n, animates: animates, motion: motion),
  );
}

// --- the controller ------------------------------------------------------------

enum _Direction { forward, reverse }

/// `controller.repeat(reverse:, count:)` starting [start] runs in (a share
/// of a run, more than 1 with [reverse]: on the way back).
class _RepeatSimulation extends Simulation {
  _RepeatSimulation(this.period, this.reverse, this.count, this.start);

  final double period;
  final bool reverse;
  final int count;
  final double start;

  double runs(double t) => t / period + start;

  @override
  double x(double time) {
    final r = runs(time);
    if (count > 0 && r >= count) return reverse && (count - 1).isOdd ? 0 : 1;
    final k = r.floor(), f = r - k;
    return reverse && k.isOdd ? 1 - f : f;
  }

  bool backward(double time) {
    final r = runs(time);
    if (count > 0 && r >= count) return reverse && (count - 1).isOdd;
    return reverse && r.floor().isOdd;
  }

  @override
  double dx(double time) => (backward(time) ? -1 : 1) / period;

  @override
  bool isDone(double time) => count > 0 && runs(time) >= count;
}

/// `forward`/`reverse`/`animateTo`: [begin] to [end] over [seconds] on
/// [curve] (Flutter's `_InterpolationSimulation`).
class _Interpolation extends Simulation {
  _Interpolation(this.begin, this.end, this.seconds, this.curve);
  final double begin, end, seconds;
  final api.AnimationCurve curve;

  @override
  double x(double time) {
    final t = seconds <= 0 ? 1.0 : (time / seconds).clamp(0.0, 1.0);
    if (t == 0) return begin;
    if (t == 1) return end;
    return begin + (end - begin) * curve.transform(t);
  }

  @override
  double dx(double time) => seconds <= 0 ? 0 : (x(time + 0.001) - x(time - 0.001)) / 0.002;

  @override
  bool isDone(double time) => time > seconds;
}

/// One animation's controller: Flutter's `AnimationController` (value 0–1,
/// status, forward/reverse/repeat/animateTo/animateWith/stop/reset), on
/// its player's ticker. A play starts on the first tick after it's asked
/// for (as a `Ticker`'s elapsed does), after the animation's delay.
class AnimationClock {
  AnimationClock(this.spec);

  /// The expanded animation.
  api.NodeAnimation spec;

  double value = 0;
  AnimationStatus status = AnimationStatus.dismissed;
  _Direction _direction = _Direction.forward;

  Simulation? _simulation;
  Duration? _start;
  int _delayMs = 0;
  Completer<void>? _done;

  /// Whether a play is running (or waiting for its delay).
  bool get isAnimating => _simulation != null;

  /// Moved on its last tick (a play's last frame included): what its
  /// variable tracks write.
  bool moved = false;

  /// The value the tracks see: through the animation's curve (none on a
  /// spring, which replaces it).
  double get curved => spec.spring != null ? value : spec.effectiveCurve.transform(value);

  int _ms(_Direction d) => d == _Direction.reverse && spec.reverseDuration != null ? spec.reverseDuration! : spec.durationMs;

  Future<void> _run(Simulation simulation, _Direction direction, {int delay = 0}) {
    _finish();
    _direction = direction;
    _simulation = simulation;
    _start = null;
    _delayMs = delay;
    status = direction == _Direction.forward ? AnimationStatus.forward : AnimationStatus.reverse;
    return (_done = Completer<void>()).future;
  }

  void _finish() {
    final done = _done;
    _done = null;
    if (done != null && !done.isCompleted) done.complete();
  }

  void _settle(double target, _Direction direction) {
    _finish();
    _simulation = null;
    value = target;
    _direction = direction;
    status = direction == _Direction.forward ? AnimationStatus.completed : AnimationStatus.dismissed;
  }

  /// `animateTo(target)`: on the spring when the animation has one, else
  /// over [durationMs] (null: the animation's, scaled by the distance as
  /// Flutter's is) on [curve].
  Future<void> animateTo(double target, {int? durationMs, api.AnimationCurve? curve, api.Spring? spring, int delay = 0}) {
    final direction = target >= value ? _Direction.forward : _Direction.reverse;
    final s = spring ?? spec.spring;
    if (s != null) {
      return _run(SpringSimulation(describeSpring(s), value, target, 0), direction, delay: delay);
    }
    final ms = durationMs ?? _ms(direction) * (target - value).abs();
    if (ms <= 0 || target == value) {
      _settle(target, direction);
      return Future.value();
    }
    return _run(_Interpolation(value, target, ms / 1000, curve ?? api.AnimationCurve.linear), direction, delay: delay);
  }

  /// `forward(from:)`.
  Future<void> forward({double? from, int? durationMs, api.Spring? spring, int delay = 0}) {
    if (from != null) value = from.clamp(0.0, 1.0);
    return animateTo(1, durationMs: durationMs, spring: spring, delay: delay);
  }

  /// `reverse(from:)`.
  Future<void> reverse({double? from, int? durationMs, api.Spring? spring, int delay = 0}) {
    if (from != null) value = from.clamp(0.0, 1.0);
    final f = animateTo(0, durationMs: durationMs, spring: spring, delay: delay);
    _direction = _Direction.reverse;
    if (isAnimating) status = AnimationStatus.reverse;
    return f;
  }

  /// `repeat(reverse:, count:)` as the animation's [api.NodeAnimation.repeat]
  /// says, from [startRuns] runs into a cycle (null: where it is now).
  Future<void> repeat({double? startRuns, int delay = 0}) {
    final r = spec.repeat ?? api.AnimationRepeat.forever;
    final start = startRuns ?? (r.reverse && _direction == _Direction.reverse ? 2 - value : value);
    final sim = _RepeatSimulation(math.max(1, spec.durationMs) / 1000, r.reverse, r.count, start);
    return _run(sim, sim.backward(0) ? _Direction.reverse : _Direction.forward, delay: delay);
  }

  /// `stop()`: holds where it is; a chain waiting on it goes on.
  void stop() {
    _finish();
    _simulation = null;
  }

  /// `reset()`.
  void reset() {
    stop();
    value = 0;
    _direction = _Direction.forward;
    status = AnimationStatus.dismissed;
  }

  /// `value = v`: a running play carries on from there.
  void set(double v) {
    value = v;
    final sim = _simulation;
    if (sim == null) {
      status = v <= 0 ? AnimationStatus.dismissed : (v >= 1 ? AnimationStatus.completed : status);
      return;
    }
    if (sim is _RepeatSimulation) {
      unawaited(repeat());
    } else {
      unawaited(animateTo(_direction == _Direction.forward ? 1 : 0));
    }
  }

  /// Advances to the player's ticker time [now]; whether the value changed.
  bool tick(Duration now) {
    final sim = _simulation;
    if (sim == null) return false;
    final start = _start ??= now + Duration(milliseconds: _delayMs);
    if (now < start) return false;
    final t = (now - start).inMicroseconds / Duration.microsecondsPerSecond;
    final before = value;
    // A spring isn't held to 0–1: its bounce shows.
    value = sim is SpringSimulation ? sim.x(t) : sim.x(t).clamp(0.0, 1.0);
    if (sim is _RepeatSimulation) {
      _direction = sim.backward(t) ? _Direction.reverse : _Direction.forward;
      status = _direction == _Direction.forward ? AnimationStatus.forward : AnimationStatus.reverse;
    }
    if (sim.isDone(t)) {
      if (sim is SpringSimulation) value = sim.x(double.infinity).isFinite ? (_direction == _Direction.forward ? 1 : 0) : value;
      _simulation = null;
      status = _direction == _Direction.forward ? AnimationStatus.completed : AnimationStatus.dismissed;
      if (sim is _RepeatSimulation) status = value >= 1 ? AnimationStatus.completed : AnimationStatus.dismissed;
      _finish();
    }
    moved = value != before || _simulation == null;
    return moved;
  }

  /// The animation's exposed state, `${animation.<id>}`.
  Map<String, Object?> get state => {'value': curved, 'status': status.name, 'isAnimating': isAnimating};

  void dispose() => stop();
}

// --- the player ------------------------------------------------------------------

/// Whether a play key fires: a new value that isn't empty, 0, false or null.
bool _cues(String? key) {
  final k = key?.trim().toLowerCase();
  return k != null && k.isNotEmpty && k != '0' && k != 'false' && k != 'null';
}

/// A node's animations: their clocks, ticked inside this render object, and
/// what their tracks pose. The pose of its adding and multiplying tracks is
/// its own (as `RenderPose`); the rest it hands to the node's motion layer,
/// the tree (a patch of the node as shown) or the node's variables.
class RenderAnimations extends RenderPose {
  RenderAnimations() {
    origin = Alignment.topLeft;
  }

  NodeBox? _box;
  Node? _node;
  RenderMotion? _motion;
  bool _animates = false;
  bool _appeared = false;
  final Map<String, AnimationClock> _clocks = {};
  List<api.NodeAnimation> _specs = const [];
  Map<String, String?> _playKeys = {};
  Ticker? _ticker;

  /// The clock of animation [id], if the node has one.
  AnimationClock? clockOf(String id) => _clocks[id];

  /// Every clock, by animation id (tests, tools).
  Map<String, AnimationClock> get clocks => Map.unmodifiable(_clocks);

  /// The platform asks for no animation: repeating animations rest where
  /// they start, as the design canvas draws them.
  static bool get reducedMotion => SchedulerBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;

  void configure(NodeBox? box, Node n, {required bool animates, RenderMotion? motion}) {
    _box = box;
    _node = n;
    _motion = motion;
    final wasAnimating = _animates;
    _animates = animates;
    final specs = [for (final a in n.behaviors.animations) a.expanded];
    final ids = {for (final a in specs) a.id};
    for (final id in _clocks.keys.toList()) {
      if (!ids.contains(id)) _clocks.remove(id)!.dispose();
    }
    final cues = <String>[];
    final restart = <String>[];
    for (final a in specs) {
      final old = _specs.where((s) => s.id == a.id).firstOrNull;
      final clock = _clocks[a.id] ??= AnimationClock(a);
      clock.spec = a;
      if (old != null) {
        final before = _playKeys[a.id];
        if (a.playKey != before && _cues(a.playKey)) cues.add(a.id);
        if (old.enabled != a.enabled || old.paused != a.paused || old.repeat != a.repeat || old.durationMs != a.durationMs) {
          restart.add(a.id);
        } else if (old.phase != a.phase && a.repeats && !old.paused) {
          restart.add(a.id);
        }
      }
    }
    _playKeys = {for (final a in specs) a.id: a.playKey};
    _specs = specs;
    _watchProgress();
    if (_animates != wasAnimating) _appeared = false;
    if (attached && _animates) {
      if (!_appeared) {
        _appear();
      } else {
        for (final id in restart) {
          _resume(id);
        }
      }
      for (final id in cues) {
        unawaited(play(id));
      }
    }
    _show();
    _sync();
  }

  /// What tells that a `progress` expression's names changed.
  final Map<String, Listenable> _progressWatches = {};

  void _onProgress() {
    if (attached) _show();
  }

  void _watchProgress() {
    final values = _animates ? _values : null;
    final names = <String>{
      if (values is ExpressionValues)
        for (final a in _specs)
          if (a.enabled && a.progress != null) ...values.namesRead(a.progress!),
    };
    for (final name in _progressWatches.keys.toList()) {
      if (!names.contains(name)) _progressWatches.remove(name)!.removeListener(_onProgress);
    }
    for (final name in names) {
      if (_progressWatches.containsKey(name)) continue;
      final w = values!.watch(name);
      if (w == null) continue;
      w.addListener(_onProgress);
      _progressWatches[name] = w;
    }
  }

  /// The values a binding reads, for expressions in tracks.
  BoundValues? get _values {
    final box = _box;
    return box?.tree.bindings?.valuesFor(box.tree.source, box.id, box.instance);
  }

  double? _number(Object? v) {
    if (v is String && v.contains(r'${')) {
      final values = _values;
      if (values is ExpressionValues) return api.readDouble(values.evaluate(v));
      return null;
    }
    return api.readDouble(v);
  }

  /// Starts the animations that play when the node appears.
  void _appear() {
    _appeared = true;
    for (final a in _specs) {
      if (!a.enabled) continue;
      final clock = _clocks[a.id]!;
      clock.reset();
      _seedPhase(clock);
      if (a.autoplays && !a.paused) _autoplay(clock);
    }
  }

  void _seedPhase(AnimationClock clock) {
    final a = clock.spec;
    final phase = a.phase.isFinite ? a.phase - a.phase.floorToDouble() : 0.0;
    if (a.repeats) {
      final runs = phase * (a.repeat!.reverse ? 2 : 1);
      clock.value = a.repeat!.reverse && runs >= 1 ? 2 - runs : runs;
    } else {
      clock.value = phase;
    }
  }

  void _autoplay(AnimationClock clock) {
    final a = clock.spec;
    if (a.progress != null) return;
    if (a.repeats) {
      if (reducedMotion) return;
      final phase = a.phase.isFinite ? a.phase - a.phase.floorToDouble() : 0.0;
      unawaited(clock.repeat(startRuns: phase * (a.repeat!.reverse ? 2 : 1), delay: a.delay));
    } else {
      unawaited(clock.forward(delay: a.delay));
    }
  }

  /// A changed switch (enabled, paused, its repeat): carries on from where
  /// it is, or holds.
  void _resume(String id) {
    final clock = _clocks[id];
    if (clock == null) return;
    final a = clock.spec;
    if (!a.enabled) {
      clock.reset();
      return;
    }
    if (a.paused) {
      clock.stop();
      return;
    }
    if (a.repeats) {
      if (!reducedMotion) unawaited(clock.repeat());
    } else if (a.autoplays && clock.status != AnimationStatus.completed) {
      unawaited(clock.forward());
    }
  }

  /// Plays animation [id] from its start (a cue, `animate forward from 0`).
  Future<void> play(String id) => command(id, api.AnimateCommand.forward, from: 0);

  /// Runs `AnimationController` [command] on animation [id]; completes when
  /// it ends (at once when there's no such animation or it isn't playing).
  Future<void> command(
    String id,
    api.AnimateCommand command, {
    double? from,
    double? target,
    int? durationMs,
    api.AnimationCurve? curve,
    api.Spring? spring,
  }) {
    final clock = _clocks[id];
    if (clock == null || !attached || !_animates || !clock.spec.enabled) return Future.value();
    final a = clock.spec;
    final delay = a.delay;
    final Future<void> done;
    switch (command) {
      case api.AnimateCommand.forward:
        done = a.repeats && target == null
            ? clock.repeat(startRuns: from, delay: delay)
            : clock.forward(from: from, durationMs: durationMs, spring: spring, delay: delay);
      case api.AnimateCommand.reverse:
        done = clock.reverse(from: from, durationMs: durationMs, spring: spring, delay: delay);
      case api.AnimateCommand.toggle:
        final back = clock.status == AnimationStatus.completed || clock.status == AnimationStatus.forward;
        done = back
            ? clock.reverse(durationMs: durationMs, spring: spring)
            : clock.forward(durationMs: durationMs, spring: spring);
      case api.AnimateCommand.repeat:
        done = clock.repeat(startRuns: from);
      case api.AnimateCommand.stop:
        clock.stop();
        done = Future.value();
      case api.AnimateCommand.reset:
        clock.reset();
        done = Future.value();
      case api.AnimateCommand.animateTo:
      case api.AnimateCommand.animateBack:
        if (from != null) clock.value = from;
        done = clock.animateTo(target ?? (command == api.AnimateCommand.animateTo ? 1 : 0),
            durationMs: durationMs, curve: curve, spring: spring);
      case api.AnimateCommand.set:
        clock.set(target ?? clock.value);
        done = Future.value();
    }
    _show();
    _sync();
    return done;
  }

  // --- ticking ------------------------------------------------------------------

  bool get _ticking => attached && _animates && _clocks.values.any((c) => c.isAnimating);

  void _sync() {
    if (_ticking) {
      _ticker ??= Ticker(_tick, debugLabel: 'animations');
      if (!_ticker!.isActive) _ticker!.start();
    } else if (_ticker?.isActive ?? false) {
      _ticker!.stop();
    }
  }

  void _tick(Duration elapsed) {
    var changed = false;
    for (final c in _clocks.values) {
      if (c.tick(elapsed)) changed = true;
    }
    if (changed) _show();
    for (final c in _clocks.values) {
      c.moved = false;
    }
    if (!_clocks.values.any((c) => c.isAnimating)) {
      _ticker?.stop();
    }
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    if (_animates && !_appeared) _appear();
    _show();
    _sync();
  }

  @override
  void detach() {
    _ticker?.stop();
    super.detach();
  }

  @override
  void dispose() {
    for (final w in _progressWatches.values) {
      w.removeListener(_onProgress);
    }
    _progressWatches.clear();
    _ticker?.dispose();
    _ticker = null;
    for (final c in _clocks.values) {
      c.dispose();
    }
    _clocks.clear();
    super.dispose();
  }

  // --- applying tracks ----------------------------------------------------------

  Map<String, double> _lastMotion = const {};
  Map<String, Map<String, Object?>> _lastPatches = const {};
  Map<String, Object?> _lastState = const {};

  /// The controller value of [clock] to draw with: its own in a running
  /// app; on a design canvas its `previewAt` (null: not drawn).
  double? _drawn(AnimationClock clock) {
    final a = clock.spec;
    if (!a.enabled) return null;
    if (_animates) {
      if (a.progress case final String p) {
        final v = _number(p);
        if (v != null) clock.value = v.clamp(0.0, 1.0);
      }
      return clock.curved;
    }
    final at = a.previewAt;
    if (at == null) return null;
    final phase = a.phase.isFinite ? a.phase : 0.0;
    if (a.repeats) {
      final runs = ((phase + at) % 1) * (a.repeat!.reverse ? 2 : 1);
      final v = a.repeat!.reverse && runs >= 1 ? 2 - runs : runs;
      return a.effectiveCurve.transform(v);
    }
    return a.effectiveCurve.transform((phase + at).clamp(0.0, 1.0));
  }

  void _show() {
    final n = _node;
    if (n == null) return;
    final ownMotion = n.behaviors.motion ?? api.Motion.none;
    final parts = <(Alignment, Matrix4)>[];
    var opacity = 1.0;
    double? opacityOverride;
    final motion = <String, double>{};
    final patches = <String, Map<String, Object?>>{};
    final values = _animates ? _values : null;
    for (final clock in _clocks.values.toList()) {
      final v = _drawn(clock);
      if (v == null) continue;
      final a = clock.spec;
      var dx = 0.0, dy = 0.0, sc = 1.0, sx = 1.0, sy = 1.0, rot = 0.0;
      for (final t in a.tracks) {
        if (t.variable.isNotEmpty) {
          if (!_animates || values == null) continue;
          final value = api.readDouble(t.valueAt(v, begin: _resolved(t.from), end: _resolved(t.to)));
          if (value != null && (clock.isAnimating || clock.moved)) values.write(t.variable, value);
          continue;
        }
        final path = t.path;
        final prop = path.startsWith('motion.') ? path.substring(7) : (path == 'opacity' ? 'opacity!' : null);
        if (t.node.isEmpty && prop != null && t.blend != api.TrackBlend.replace) {
          final x = api.readDouble(t.valueAt(v, begin: _resolved(t.from), end: _resolved(t.to)));
          if (x == null) continue;
          switch (prop) {
            case 'translateX':
              dx += x;
            case 'translateY':
              dy += x;
            case 'scale':
              sc *= x;
            case 'scaleX':
              sx *= x;
            case 'scaleY':
              sy *= x;
            case 'rotate':
              rot += x;
            case 'opacity' || 'opacity!':
              opacity *= x.clamp(0.0, 1.0);
          }
          continue;
        }
        if (t.node.isEmpty && prop == 'opacity!') {
          final x = api.readDouble(t.valueAt(v, own: n.opacity, begin: _resolved(t.from), end: _resolved(t.to)));
          if (x != null) opacityOverride = x.clamp(0.0, 1.0);
          continue;
        }
        if (t.node.isEmpty && prop != null && motionTrackProperties.contains(prop)) {
          final x = api.readDouble(t.valueAt(v, own: ownMotion.valueOf(prop), begin: _resolved(t.from), end: _resolved(t.to)));
          if (x != null) motion[prop] = x;
          continue;
        }
        // Any other path: a patch of the node (or of node [t.node]).
        final target = t.node.isEmpty ? n.id : t.node;
        final value = t.valueAt(v, own: _ownValue(target, path), begin: _resolved(t.from), end: _resolved(t.to));
        if (value != null) (patches[target] ??= {})[path] = value;
      }
      if (dx != 0 || dy != 0 || sc != 1 || sx != 1 || sy != 1 || rot != 0) {
        final al = a.effectiveAlignment;
        parts.add((
          Alignment(al.x, al.y),
          Matrix4.translationValues(dx, dy, 0)
            ..scaleByDouble(sc * sx, sc * sy, 1, 1)
            ..rotateZ(rot * math.pi / 180),
        ));
      }
    }
    _setParts(parts);
    // A track that sets the node's opacity draws it here (the node then
    // has no opacity layer of its own); else that layer, inside, does.
    final own = animatesOpacity(n) && n.opacity < 0.99 ? n.opacity : 1.0;
    this.opacity = (opacity * (opacityOverride ?? own)).clamp(0.0, 1.0);
    if (!_sameMap(motion, _lastMotion)) {
      _lastMotion = motion;
      _motion?.overrides = motion;
    }
    _patch(patches);
    _publish();
  }

  /// The node's own [path] value as stored (an omitted `from` or `to`).
  Object? _ownValue(String id, String path) {
    final node = id == _node?.id ? _node : _box?.nodeOf(id);
    if (node == null) return null;
    Object? at = node.toJson();
    for (final k in api.BindPaths.parse(path)) {
      if (k is int) {
        final l = api.readList(at);
        at = l != null && k < l.length ? l[k] : null;
      } else if (api.readList(at) case final List<Object?> l) {
        at = l.map(api.readMap).firstWhere((m) => m?['id'] == k, orElse: () => null);
      } else {
        at = api.readMap(at)?[k];
      }
    }
    return at;
  }

  Object? _resolved(Object? v) => v is String && v.contains(r'${') ? _number(v) ?? (_values?.interpolate(v)) : v;

  void _patch(Map<String, Map<String, Object?>> patches) {
    final box = _box;
    if (box == null) return;
    final ids = {..._lastPatches.keys, ...patches.keys};
    for (final id in ids) {
      final next = patches[id] ?? const {};
      if (_sameMap(next, _lastPatches[id] ?? const {})) continue;
      box.tree.setAnimatedValues(id, next, instance: box.instance);
    }
    _lastPatches = patches;
  }

  bool _publishScheduled = false;

  /// Publishes `${animation.*}` after the current build or tick (readers
  /// re-apply then, not inside this node's own build).
  void _publish() {
    final box = _box;
    if (box == null || box.tree.bindings == null || _publishScheduled) return;
    _publishScheduled = true;
    scheduleMicrotask(() {
      _publishScheduled = false;
      if (_box == null || box.tree.isDisposed) return;
      final state = {for (final c in _clocks.entries) c.key: c.value.state};
      if (_sameState(state, _lastState)) return;
      _lastState = state;
      box.tree.bindings?.publish(box.tree.source, box.id, box.instance, 'animation', state);
    });
  }

  static bool _sameMap(Map<String, Object?> a, Map<String, Object?> b) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (!b.containsKey(e.key) || b[e.key] != e.value) return false;
    }
    return true;
  }

  static bool _sameState(Map<String, Object?> a, Map<String, Object?> b) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      final x = e.value, y = b[e.key];
      if (x is! Map<String, Object?> || y is! Map<String, Object?> || !_sameMap(x, y)) return false;
    }
    return true;
  }

  /// The adding and multiplying tracks' pose: per animation, a matrix
  /// about its alignment in the box, outermost first.
  List<(Alignment, Matrix4)> _parts = const [];

  void _setParts(List<(Alignment, Matrix4)> parts) {
    var same = parts.length == _parts.length;
    for (var i = 0; same && i < parts.length; i++) {
      same = parts[i].$1 == _parts[i].$1 && parts[i].$2 == _parts[i].$2;
    }
    if (same) return;
    _parts = parts;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  @override
  bool get posed => _parts.isNotEmpty;

  @override
  Matrix4 get effectiveTransform {
    final m = Matrix4.identity();
    final s = hasSize ? size : Size.zero;
    for (final (alignment, pose) in _parts) {
      final o = alignment.alongSize(s);
      m
        ..translateByDouble(o.dx, o.dy, 0, 1)
        ..multiply(pose)
        ..translateByDouble(-o.dx, -o.dy, 0, 1);
    }
    return m;
  }
}

