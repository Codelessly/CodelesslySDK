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
// Its transitions (api.Transition, docs/design/03-motion.md §3.2) are the
// node's implicit animations, played on the same ticker: when a value they
// ease changes, it tweens from what is drawn to the new value (a `motion`
// number into the motion layer, `opacity` into this layer, any other path
// as a patch).
//
// A design canvas (a tree that doesn't animate) runs no clock: it draws an
// animation only at its `previewAt`, else the node's own values (an
// entrance at its end), and new values at once.
import 'dart:async';
import 'dart:math' as math;

import 'package:codelessly_api/core.dart' as api;
import 'package:codelessly_api/core.dart' show Node;
import 'package:flutter/animation.dart' show AnimationStatus;
import 'package:flutter/foundation.dart' show Listenable;
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import 'behaviors.dart' show RenderMotion, RenderPose, RenderShimmer;
import 'contracts.dart';
import 'node_tree.dart' show NodeBox;
import 'physics.dart' show describeSpring;
import 'recipe.dart';
import 'visible_share.dart';

/// The `motion.*` properties a track or a transition can drive
/// ([api.Motion.properties]).
const Set<String> motionTrackProperties = {...api.Motion.properties};

/// The properties of [n]'s motion its animations replace (their tracks set
/// them): the node needs a motion layer for them.
Set<String> replacedMotionProperties(Node n) => {
      for (final a in n.behaviors.animations)
        if (a.enabled)
          for (final t in a.expanded.tracks)
            if (t.variable.isEmpty && t.node.isEmpty && t.blend == api.TrackBlend.replace && t.path.startsWith('motion.'))
              if (motionTrackProperties.contains(t.path.substring(7))) t.path.substring(7),
    };

/// Whether [n]'s animations replace its own opacity, or a transition eases
/// it: its player draws it (the node has no opacity layer of its own).
bool animatesOpacity(Node n) =>
    api.Transition.of(n.behaviors.transitions, 'opacity') != null ||
    n.behaviors.animations.any((a) =>
        a.enabled &&
        a.expanded.tracks.any((t) => t.variable.isEmpty && t.node.isEmpty && t.path == 'opacity' && t.blend == api.TrackBlend.replace));

/// Adds [n]'s animation player to [chain] (where the loops were: inside the
/// motion and rotation, outside the opacity): for its animations and its
/// transitions.
void animationLayers(NodeBuilder b, Node n, List<RenderBox> chain,
    {required bool animates, RenderMotion? motion, RenderShimmer? shimmer}) {
  if (n.behaviors.animations.isEmpty && n.behaviors.transitions.isEmpty) return;
  final box = b is NodeBox ? b : null;
  chain.add(
    b.obtain<RenderAnimations>('animations', RenderAnimations.new)
      ..configure(box, n, animates: animates, motion: motion, shimmer: shimmer),
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
  double x(double time) => valueAt(runs(time), reverse, count);

  /// The value [r] runs in: as Flutter's `repeat(count:)` ends, at the start
  /// of the run after the last (0 for a restart, a reverse's end of its
  /// last way).
  static double valueAt(double r, bool reverse, int count) {
    if (count > 0 && r >= count) r = count.toDouble();
    final k = r.floor(), f = r - k;
    return reverse && k.isOdd ? 1 - f : f;
  }

  bool backward(double time) => isBackward(runs(time), reverse, count);

  static bool isBackward(double r, bool reverse, int count) {
    if (count > 0 && r >= count) return reverse && (count - 1).isOdd;
    return reverse && r.floor().isOdd;
  }

  @override
  double dx(double time) => (backward(time) ? -1 : 1) / period;

  @override
  bool isDone(double time) => count > 0 && runs(time) >= count;
}

/// A repeat whose pace eases ([api.NodeAnimation.ramp]): its speed (runs a
/// second) moves toward [targetSpeed] (its full pace, 0 while paused) over
/// the ramp, and the runs it has gone are the sum of it. Stateful: read once
/// a tick, in order.
class _RampedRepeat extends Simulation {
  _RampedRepeat({
    required this.runs,
    required this.speed,
    required this.rampSeconds,
    required this.reverse,
    required this.count,
    required this.targetSpeed,
  });

  double runs, speed;
  final double rampSeconds;
  final bool reverse;
  final int count;
  final double Function() targetSpeed;
  double? _last;

  /// It wound down to a stop (paused), rather than finished its count.
  bool get stopped => speed == 0 && targetSpeed() == 0 && !(count > 0 && runs >= count);

  @override
  double x(double time) {
    final dt = _last == null ? 0.0 : math.max(0.0, time - _last!);
    _last = time;
    final target = targetSpeed();
    if (speed != target) {
      if (rampSeconds <= 0) {
        speed = target;
      } else if (dt > 0) {
        final perSecond = math.max(target.abs(), speed.abs()) / rampSeconds;
        final change = math.min((target - speed).abs(), perSecond * dt);
        speed += (target - speed).sign * change;
        if ((target - speed).abs() < 0.002) speed = target;
      }
    }
    runs += speed * dt;
    return _RepeatSimulation.valueAt(runs, reverse, count);
  }

  bool get backward => _RepeatSimulation.isBackward(runs, reverse, count);

  @override
  double dx(double time) => (backward ? -1 : 1) * speed;

  @override
  bool isDone(double time) => (count > 0 && runs >= count) || stopped;
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
  /// says, from [startRuns] runs into a cycle (null: where it is now). With
  /// a [api.NodeAnimation.ramp] it speeds up from still (or from its pace
  /// now) and slows to a stop while paused; with no duration it holds still.
  Future<void> repeat({double? startRuns, int delay = 0}) {
    final r = spec.repeat ?? api.AnimationRepeat.forever;
    final start = startRuns ?? (r.reverse && _direction == _Direction.reverse ? 2 - value : value);
    if (spec.ramp > 0) {
      final running = _simulation;
      final sim = _RampedRepeat(
        runs: start,
        speed: running is _RampedRepeat ? running.speed : 0,
        rampSeconds: spec.ramp / 1000,
        reverse: r.reverse,
        count: r.count,
        targetSpeed: () => spec.paused || !spec.enabled || spec.durationMs <= 0 ? 0 : 1000 / spec.durationMs,
      );
      return _run(sim, sim.backward ? _Direction.reverse : _Direction.forward, delay: delay);
    }
    if (spec.durationMs <= 0) {
      stop();
      return Future.value();
    }
    final sim = _RepeatSimulation(math.max(1, spec.durationMs) / 1000, r.reverse, r.count, start);
    return _run(sim, sim.backward(0) ? _Direction.reverse : _Direction.forward, delay: delay);
  }

  /// Whether it eases its pace to a stop rather than stopping at once.
  bool get windsDown => spec.ramp > 0 && _simulation is _RampedRepeat;

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
    if (sim is _RepeatSimulation || sim is _RampedRepeat) {
      final back = sim is _RampedRepeat ? sim.backward : (sim as _RepeatSimulation).backward(t);
      _direction = back ? _Direction.reverse : _Direction.forward;
      status = _direction == _Direction.forward ? AnimationStatus.forward : AnimationStatus.reverse;
    }
    if (sim is _RampedRepeat && sim.stopped) {
      // Wound down (paused): it holds there, as `stop()` does.
      _simulation = null;
      _finish();
    } else if (sim.isDone(t)) {
      if (sim is SpringSimulation) value = sim.x(double.infinity).isFinite ? (_direction == _Direction.forward ? 1 : 0) : value;
      _simulation = null;
      // As `repeat(count:)` ends: completed going forward, dismissed back.
      status = _direction == _Direction.forward ? AnimationStatus.completed : AnimationStatus.dismissed;
      _finish();
    }
    moved = value != before || _simulation == null;
    return moved;
  }

  /// The animation's exposed state, `${animation.<id>}`.
  Map<String, Object?> get state => {'value': curved, 'status': status.name, 'isAnimating': isAnimating};

  void dispose() => stop();
}

// --- transitions -----------------------------------------------------------------

/// One running transition: [from] to [to] on its [transition]'s timing,
/// through its [keyframes].
class _Tween {
  _Tween(this.transition, this.from, this.to, this.keyframes);

  final api.Transition transition;
  final double from, to;
  final List<api.Keyframe> keyframes;

  /// The ticker time it started at (its delay not yet counted); null until
  /// its first tick.
  Duration? since;

  /// The value drawn now, and the eased share it's at.
  double value = 0, eased = 0;

  /// The value on the straight way (before an arc bends it).
  double straight = 0;

  late final Simulation? _spring = transition.spring == null
      ? null
      : SpringSimulation(describeSpring(transition.spring!), 0, 1, 0);

  /// Moves to [ms] into its run; whether it's done.
  bool advance(double ms) {
    final bool done;
    if (_spring case final Simulation s) {
      final t = ms / 1000;
      done = ms > 0 && s.isDone(t);
      eased = done ? 1 : s.x(t);
    } else {
      final u = (ms / math.max(1, transition.duration)).clamp(0.0, 1.0);
      done = ms >= transition.duration;
      eased = done ? 1 : transition.curve.transform(u);
    }
    if (keyframes.isEmpty) {
      straight = from + (to - from) * eased;
    } else {
      final track = api.AnimationTrack(keyframes: keyframes, interpolation: transition.interpolation);
      straight = api.readDouble(track.valueAt(eased.clamp(0.0, 1.0), begin: from, end: to)) ?? to;
    }
    value = done ? to : straight;
    return done;
  }
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
  RenderShimmer? _shimmer;
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

  void configure(NodeBox? box, Node n, {required bool animates, RenderMotion? motion, RenderShimmer? shimmer}) {
    _box = box;
    final previous = _node;
    final previousBase = _base;
    _node = n;
    _base = _patchesOwnPaths(n) && box != null ? box.tree.resolveUnanimated(box.id, instance: box.instance) ?? n : n;
    _motion = motion;
    _shimmer = shimmer;
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
      if (previous != null && wasAnimating) _transition(previousBase ?? previous, _base!);
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
    return box?.tree.bindings?.valuesFor(box.source, box.id, box.instance);
  }

  double? _number(Object? v) {
    if (v is String && v.contains(r'${')) {
      final values = _values;
      if (values is ExpressionValues) return api.readDouble(values.evaluate(v));
      return null;
    }
    return api.readDouble(v);
  }

  /// Starts the animations that play when the node appears; one that waits
  /// for the node to be in view ([api.NodeAnimation.visibleFraction])
  /// starts once it is.
  void _appear() {
    _appeared = true;
    _tweens.clear();
    _waitingInView.clear();
    for (final a in _specs) {
      if (!a.enabled) continue;
      final clock = _clocks[a.id]!;
      clock.reset();
      _seedPhase(clock);
      if (a.autoplays && a.visibleFraction != null) {
        _waitingInView.add(a.id);
      } else if (a.autoplays && !a.paused) {
        _autoplay(clock);
      }
    }
    if (_waitingInView.isNotEmpty) {
      _watchInView();
      SchedulerBinding.instance.scheduleFrame();
    }
  }

  /// Animations waiting for the node to be in view.
  final Set<String> _waitingInView = {};
  bool _inViewScheduled = false;

  /// Checks after each frame, while some wait, how much of the node shows.
  void _watchInView() {
    if (_inViewScheduled || _waitingInView.isEmpty) return;
    _inViewScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _inViewScheduled = false;
      if (!attached || !_animates) return;
      _checkInView();
      _watchInView();
    });
  }

  void _checkInView() {
    // The node's box as laid out (outside its motion), as a reveal measured.
    final RenderBox target = _motion ?? this;
    if (!target.hasSize) return;
    final share = visibleShare(target);
    for (final id in _waitingInView.toList()) {
      final clock = _clocks[id];
      final a = clock?.spec;
      if (clock == null || a == null || !a.enabled) {
        _waitingInView.remove(id);
        continue;
      }
      if (share <= 0 || share < a.visibleFraction!.clamp(0.0, 1.0)) continue;
      _waitingInView.remove(id);
      if (!a.paused) _autoplay(clock);
    }
    _show();
    _sync();
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
    if (_waitingInView.contains(id)) return;
    if (a.paused) {
      // A ramped repeat slows to a stop; anything else holds at once.
      if (!clock.windsDown) clock.stop();
      return;
    }
    if (a.repeats) {
      if (!reducedMotion) unawaited(clock.repeat());
    } else if (a.autoplays && clock.status != AnimationStatus.completed) {
      // Released before it ever started: from its start, after its delay.
      unawaited(clock.forward(delay: clock.value == 0 && clock.status == AnimationStatus.dismissed ? a.delay : 0));
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

  bool get _ticking => attached && _animates && (_clocks.values.any((c) => c.isAnimating) || _tweens.isNotEmpty);

  void _sync() {
    if (_ticking) {
      _ticker ??= Ticker(_tick, debugLabel: 'animations');
      if (!_ticker!.isActive) {
        // A ticker started now counts from this frame: what waits to start
        // starts at its 0 (as a motion's own ticker did), not a tick late.
        _now = Duration.zero;
        for (final c in _clocks.values) {
          if (c.isAnimating) c._start ??= Duration(milliseconds: c._delayMs);
        }
        for (final t in _tweens.values) {
          t.since ??= Duration.zero;
        }
        _ticker!.start();
      }
    } else if (_ticker?.isActive ?? false) {
      _ticker!.stop();
    }
  }

  void _tick(Duration elapsed) {
    _now = elapsed;
    var changed = _tweens.isNotEmpty;
    for (final c in _clocks.values) {
      if (c.tick(elapsed)) changed = true;
    }
    if (changed) _show();
    for (final c in _clocks.values) {
      c.moved = false;
    }
    if (!_clocks.values.any((c) => c.isAnimating) && _tweens.isEmpty) {
      _ticker?.stop();
    }
  }

  /// The ticker's time at its last tick (a transition starts on the tick
  /// after it's asked for, as a clock's play does).
  Duration _now = Duration.zero;

  // --- transitions --------------------------------------------------------------

  /// Running transitions, by binding path.
  final Map<String, _Tween> _tweens = {};

  /// What is drawn now at [path] (a transition starts there): a running
  /// transition's value, else what was last drawn, else [own].
  double _drawnAt(String path, double own) => _tweens[path]?.value ?? _lastDrawn[path] ?? own;

  /// The values last drawn, by path (motion numbers and opacity).
  Map<String, double> _lastDrawn = const {};

  /// The numbers [n] has at the paths its transitions ease: its motion's,
  /// its opacity, and the single paths they name.
  Map<String, double> _eased(Node n) {
    final out = <String, double>{};
    final list = n.behaviors.transitions;
    final motion = n.behaviors.motion ?? api.Motion.none;
    for (final p in api.Motion.properties) {
      if (api.Transition.of(list, 'motion.$p') != null) out['motion.$p'] = motion.valueOf(p);
    }
    if (api.Transition.of(list, 'opacity') != null) out['opacity'] = n.opacity;
    for (final t in list) {
      final path = t.property;
      if (path == '*' || path == 'opacity' || path.startsWith('motion') || out.containsKey(path)) continue;
      if (api.readDouble(_ownValue(n.id, path, node: n)) case final double v) out[path] = v;
    }
    return out;
  }

  /// Starts the transitions [previous] → [next] calls for: each eased path
  /// whose value changed, unless an animation is playing it. A prefix's
  /// transition (`motion`) moves what's under it as one: a change restarts
  /// every number it is moving, and runs the ones its keyframes name.
  void _transition(Node previous, Node next) {
    if (next.behaviors.transitions.isEmpty) {
      _tweens.clear();
      return;
    }
    final before = _eased(previous), after = _eased(next);
    final list = next.behaviors.transitions;
    final started = <api.Transition>{};
    for (final e in after.entries) {
      final was = before[e.key];
      if (was == null || was == e.value) continue;
      final t = api.Transition.of(list, e.key);
      if (t == null || _playing(e.key)) continue;
      _startTween(e.key, t, from: _drawnAt(e.key, was), to: e.value);
      started.add(t);
    }
    // A prefix moves as one value: its other numbers in flight restart from
    // where they are, and the ones its keyframes name run too.
    for (final t in started) {
      if (t.property.contains('.') && !t.property.startsWith('motion')) continue;
      for (final e in after.entries) {
        if (_tweens[e.key]?.since == null && _tweens[e.key]?.transition == t) continue;
        if (api.Transition.of(list, e.key) != t || _playing(e.key)) continue;
        final running = _tweens[e.key];
        final keyed = t.keyframesOf(_keyUnder(t, e.key)).isNotEmpty;
        if (running != null || keyed) _startTween(e.key, t, from: _drawnAt(e.key, e.value), to: e.value);
      }
    }
    if (_tweens.isNotEmpty) _sync();
  }

  /// [path]'s key under [t]'s property (`motion.rotate` under `motion`:
  /// `rotate`); empty for the property itself.
  static String _keyUnder(api.Transition t, String path) =>
      path == t.property || t.property == '*' ? (t.property == '*' ? path : '') : path.substring(t.property.length + 1);

  void _startTween(String path, api.Transition t, {required double from, required double to}) {
    final keyframes = t.keyframesOf(_keyUnder(t, path));
    if (t.spring == null && t.duration <= 0) {
      _tweens.remove(path);
      return;
    }
    _tweens[path] = _Tween(t, from, to, keyframes)..value = from;
  }

  /// Whether an animation is playing a track that replaces [path] (a
  /// transition leaves it to the animation).
  bool _playing(String path) {
    for (final c in _clocks.values) {
      if (!c.isAnimating || !c.spec.enabled) continue;
      if (c.spec.tracks.any((t) => t.variable.isEmpty && t.node.isEmpty && t.path == path && t.blend == api.TrackBlend.replace)) {
        return true;
      }
    }
    return false;
  }

  /// Moves the running transitions to the ticker's time; done ones end.
  void _advanceTweens() {
    if (_tweens.isEmpty) return;
    for (final e in _tweens.entries.toList()) {
      final tw = e.value;
      if (_playing(e.key)) {
        _tweens.remove(e.key);
        continue;
      }
      tw.since ??= _now;
      final ms = (_now - tw.since!).inMicroseconds / 1000 - tw.transition.delay;
      if (tw.advance(math.max(0.0, ms))) _tweens.remove(e.key);
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

  /// The node without what its own tracks patch into it (a path that is
  /// not its motion, opacity or shimmer): what an omitted end and a
  /// transition read. [_node] itself when nothing is patched.
  Node? _base;

  /// Whether [n]'s own tracks or transitions are on paths the player
  /// patches into the node ([RenderTree.setAnimatedValues]).
  static bool _patchesOwnPaths(Node n) {
    bool patched(String path) =>
        path.isNotEmpty && path != 'opacity' && path != 'shimmer.position' && !path.startsWith('motion') && path != '*';
    for (final a in n.behaviors.animations) {
      if (a.tracks.any((t) => t.node.isEmpty && t.variable.isEmpty && patched(t.path))) return true;
    }
    return n.behaviors.transitions.any((t) => patched(t.property));
  }

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
    if (_animates) _advanceTweens();
    final ownMotion = n.behaviors.motion ?? api.Motion.none;
    final parts = <(Alignment, Matrix4)>[];
    var opacity = 1.0;
    double? opacityOverride;
    final motion = <String, double>{};
    final patches = <String, Map<String, Object?>>{};
    final values = _animates ? _values : null;
    // Transitions first: a playing animation's track is drawn over them.
    for (final e in _tweens.entries) {
      if (e.key.startsWith('motion.')) {
        motion[e.key.substring(7)] = e.value.value;
      } else if (e.key == 'opacity') {
        opacityOverride = e.value.value.clamp(0.0, 1.0);
      } else {
        (patches[n.id] ??= {})[e.key] = e.value.value;
      }
    }
    double? shimmerAt;
    var pushed = false;
    for (final clock in _clocks.values.toList()) {
      final v = _drawn(clock);
      if (v == null) continue;
      final a = clock.spec;
      var dx = 0.0, dy = 0.0, sc = 1.0, sx = 1.0, sy = 1.0, rot = 0.0;
      // A settled track leaves what a transition is moving to it.
      bool eased(String path) => !clock.isAnimating && _tweens.containsKey(path);
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
          if (eased('opacity')) continue;
          final x = api.readDouble(t.valueAt(v, own: n.opacity, begin: _resolved(t.from), end: _resolved(t.to)));
          if (x != null) opacityOverride = x.clamp(0.0, 1.0);
          continue;
        }
        if (t.node.isEmpty && prop != null && motionTrackProperties.contains(prop)) {
          if (eased(path)) continue;
          final x = api.readDouble(t.valueAt(v, own: ownMotion.valueOf(prop), begin: _resolved(t.from), end: _resolved(t.to)));
          if (x != null) motion[prop] = x;
          if (clock.isAnimating && t.keyframes.isNotEmpty && (prop == 'translateX' || prop == 'translateY')) pushed = true;
          continue;
        }
        if (t.node.isEmpty && path == 'shimmer.position') {
          shimmerAt = api.readDouble(t.valueAt(v, own: n.behaviors.shimmer?.position, begin: _resolved(t.from), end: _resolved(t.to)));
          continue;
        }
        if (t.node.isEmpty && eased(path)) continue;
        // Any other path: a patch of the node (or of node [t.node]).
        final target = t.node.isEmpty ? n.id : t.node;
        final value = t.valueAt(v, own: _resolved(_ownValue(target, path)), begin: _resolved(t.from), end: _resolved(t.to));
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
    for (final e in _tweens.entries) {
      if ((e.key == 'motion.translateX' || e.key == 'motion.translateY') && e.value.keyframes.isNotEmpty) pushed = true;
    }
    if (!_sameMap(motion, _lastMotion)) {
      _lastMotion = motion;
      _motion?.overrides = motion;
    }
    _motion?.headingFromMovement = pushed;
    _shimmer?.position = shimmerAt;
    _lastDrawn = {
      for (final p in api.Motion.properties) 'motion.$p': motion[p] ?? ownMotion.valueOf(p),
      'opacity': opacityOverride ?? n.opacity,
      for (final e in patches[n.id]?.entries ?? const <MapEntry<String, Object?>>[])
        if (api.readDouble(e.value) case final double d) e.key: d,
    };
    _patch(patches);
    _publish();
  }

  /// The node's own [path] value as stored (an omitted `from` or `to`), its
  /// declared default where the JSON omits it.
  Object? _ownValue(String id, String path, {Node? node}) {
    node ??= id == _node?.id ? (_base ?? _node) : _box?.nodeOf(id);
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
    // Omitted from its JSON: the field's declared default.
    return at ?? api.BindPaths.declaredDefault(node, path);
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
      box.tree.bindings?.publish(box.source, box.id, box.instance, 'animation', state);
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

