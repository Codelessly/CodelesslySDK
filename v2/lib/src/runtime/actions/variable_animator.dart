// Number variables moving over time: a set variable action's glide
// (`animateMs`) and the animate variable action's timelines (play, pause,
// resume, stop, seek). SDK 8.x's VariableAnimator, over a VariableScope:
// every frame writes the variable, so everything bound to it follows.
import 'dart:async';

import 'package:codelessly_api_v2/codelessly_api.dart' show AnimationCurve, VariableType;
import 'package:flutter/scheduler.dart';

import '../expressions/scopes.dart';

/// The timelines of number variables, one per variable (its scope and
/// name). A newer play or glide of a variable replaces the one it has.
abstract final class VariableAnimator {
  static final Expando<Map<String, VariableTween>> _tweens = Expando('animateVariable');

  /// The timeline [name] of [scope] runs, if any.
  static VariableTween? of(VariableScope scope, String name) => _tweens[scope]?[name];

  /// Plays [name] from [from] (its value now when null) to [to] over
  /// [duration] along [curve], replacing a timeline it runs. Completes
  /// with true when it arrives, false when stopped or replaced.
  ///
  /// With [fromCurrentPlace] the variable isn't reset to [from]: the
  /// timeline starts where its value sits on it (a playhead left half way
  /// plays the second half, in half the time).
  static Future<bool> play(
    VariableScope scope,
    String name, {
    double? from,
    required double to,
    required Duration duration,
    AnimationCurve curve = AnimationCurve.linear,
    bool fromCurrentPlace = false,
    bool glide = false,
  }) {
    of(scope, name)?.finish(false);
    final start = from ?? valueOf(scope, name) ?? 0;
    if (!fromCurrentPlace) write(scope, name, start);
    final tween = VariableTween._(scope, name, from: start, to: to, duration: duration, curve: curve, glide: glide);
    (_tweens[scope] ??= {})[name] = tween;
    tween._start();
    return tween.done.future;
  }

  /// Holds [name]'s timeline where it is; false when none plays.
  static bool pause(VariableScope scope, String name) {
    final t = of(scope, name);
    if (t == null || t.paused) return false;
    t._pause();
    return true;
  }

  /// Goes on with [name]'s paused timeline from its value now; false when
  /// it has none, or it isn't paused.
  static bool resume(VariableScope scope, String name) {
    final t = of(scope, name);
    if (t == null || !t.paused) return false;
    t._start();
    return true;
  }

  /// Ends [name]'s timeline where it is; false when it has none.
  static bool stop(VariableScope scope, String name) {
    final t = of(scope, name);
    if (t == null) return false;
    t.finish(false);
    return true;
  }

  /// Sets [name] to [value] now; its timeline goes on from there (or stays
  /// paused there).
  static void seek(VariableScope scope, String name, double value) {
    final t = of(scope, name);
    write(scope, name, value);
    if (t != null && !t.paused) t._start();
  }

  /// Ends [name]'s glide (a set variable's `animateMs`), not a timeline an
  /// animate variable action plays: a plain set takes over from a glide.
  static void stopGlide(VariableScope scope, String name) {
    final t = of(scope, name);
    if (t != null && t.glide) t.finish(false);
  }

  /// Ends every timeline of [scope] (its screen went).
  static void stopAll(VariableScope scope) {
    for (final t in [...?_tweens[scope]?.values]) {
      t.finish(false);
    }
  }

  static bool isPlaying(VariableScope scope, String name) => of(scope, name)?.paused == false;

  /// [name]'s value as a number, or null.
  static double? valueOf(VariableScope scope, String name) => switch (scope.valueOf(name, scope)) {
        final num n when n.isFinite => n.toDouble(),
        final String s => double.tryParse(s.trim()),
        _ => null,
      };

  /// Writes [value] into [name]: whole for an integer variable.
  static void write(VariableScope scope, String name, double value) {
    final type = scope.variable(name)?.type;
    scope.set(name, type == VariableType.integer ? value.round() : double.parse(value.toStringAsFixed(6)));
  }

  static void _forget(VariableTween t) {
    final m = _tweens[t.scope];
    if (identical(m?[t.name], t)) m!.remove(t.name);
  }
}

/// One variable's timeline from [from] to [to].
class VariableTween {
  VariableTween._(this.scope, this.name,
      {required this.from, required this.to, required this.duration, required this.curve, this.glide = false});

  /// A set variable's glide (not an animate variable's timeline).
  final bool glide;

  final VariableScope scope;
  final String name;
  final double from, to;
  final Duration duration;
  final AnimationCurve curve;

  /// True when it arrived, false when stopped or replaced.
  final Completer<bool> done = Completer<bool>();

  Ticker? _ticker;
  Duration _base = Duration.zero;

  bool get paused => _ticker == null;

  /// Where on the timeline (0–1) the variable's value sits now: the curve
  /// inverted by bisection, so a value scrubbed by hand resumes from there.
  double _progressOfCurrent() {
    final value = VariableAnimator.valueOf(scope, name);
    if (value == null || to == from) return 0;
    final target = ((value - from) / (to - from)).clamp(0.0, 1.0);
    if (curve == AnimationCurve.linear) return target;
    double lo = 0, hi = 1;
    for (var i = 0; i < 40; i++) {
      final mid = (lo + hi) / 2;
      if (curve.transform(mid) < target) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return (lo + hi) / 2;
  }

  void _start() {
    _ticker?.dispose();
    _ticker = null;
    final t = duration <= Duration.zero ? 1.0 : _progressOfCurrent();
    if (t >= 1) {
      VariableAnimator.write(scope, name, to);
      finish(true);
      return;
    }
    _base = duration * t;
    _ticker = Ticker(_tick, debugLabel: 'animateVariable')..start();
  }

  void _tick(Duration elapsed) {
    final at = _base + elapsed;
    final t = (at.inMicroseconds / duration.inMicroseconds).clamp(0.0, 1.0);
    VariableAnimator.write(scope, name, from + (to - from) * curve.transform(t));
    if (t >= 1) finish(true);
  }

  void _pause() {
    _ticker?.dispose();
    _ticker = null;
  }

  /// Ends it: [completed] when it arrived.
  void finish(bool completed) {
    _ticker?.dispose();
    _ticker = null;
    VariableAnimator._forget(this);
    if (!done.isCompleted) done.complete(completed);
  }
}
