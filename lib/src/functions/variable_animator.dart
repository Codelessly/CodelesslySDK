import 'dart:async';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../ui/codelessly_context.dart';

/// Animates number variables over time, for [AnimateVariableAction]: one
/// timeline per variable that plays from a value to another, pauses,
/// resumes from wherever the value is then (a scrubbed playhead), stops and
/// seeks.
///
/// Each frame writes the variable, so everything bound to it follows.
abstract final class VariableAnimator {
  static final Expando<_VariableTween> _tweens = Expando('animateVariable');

  /// Notifies when any animation starts, pauses, resumes or ends, so
  /// bindings reading `${animating.<variable>}` (see [playingIn]) update
  /// when an animation pauses (its variable then stops changing).
  static final ChangeNotifier changes = _Changes();

  static void _changed() => (changes as _Changes).ping();

  /// Whether each variable of [context] (by name) has an animation playing
  /// now (not paused): what `${animating.<variable>}` reads, e.g.
  /// `${= animating.sunriseT ? 'pause' : 'play_arrow'}` for a play button.
  static Map<String, bool> playingIn(CodelesslyContext? context) => {
    for (final ValueNotifier<VariableData> variable
        in context?.variables.values ?? const <ValueNotifier<VariableData>>[])
      variable.value.name: isPlaying(variable),
  };

  /// Completes when [variable]'s animation ends: true when it reaches its
  /// end, false when it is stopped or replaced. Null when it has none.
  static Future<bool>? completionOf(ValueNotifier<VariableData> variable) =>
      _tweens[variable]?.done.future;

  /// Plays [variable] from [from] (its current value when null) to [to]
  /// over [duration] with [curve], replacing an animation of it that runs.
  /// Completes with true when it reaches [to], false when it is stopped or
  /// replaced.
  ///
  /// With [fromCurrentPlace] the variable isn't reset to [from]: the
  /// timeline from [from] to [to] starts where its current value sits on
  /// it (a playhead left at 0.5 plays the second half, in half the time).
  static Future<bool> play(
    ValueNotifier<VariableData> variable, {
    double? from,
    required double to,
    required Duration duration,
    Curve curve = Curves.linear,
    bool fromCurrentPlace = false,
  }) {
    _tweens[variable]?.finish(false);
    final double start = from ?? valueOf(variable) ?? 0;
    if (!fromCurrentPlace) write(variable, start);
    final _VariableTween tween = _VariableTween(
      variable,
      from: start,
      to: to,
      duration: duration,
      curve: curve,
    );
    _tweens[variable] = tween;
    tween.start();
    return tween.done.future;
  }

  /// Holds [variable]'s animation where it is. False when none runs.
  static bool pauseVariable(ValueNotifier<VariableData> variable) {
    final _VariableTween? tween = _tweens[variable];
    if (tween == null || tween.paused) return false;
    tween.pause();
    return true;
  }

  /// Holds the animation of the variable named [name] in [context], e.g.
  /// while a drag track scrubs it.
  static bool pause(CodelesslyContext context, String name) {
    final ValueNotifier<VariableData>? variable = context.findVariableByName(
      name,
    );
    return variable != null && pauseVariable(variable);
  }

  /// Carries [variable]'s paused animation on from its current value. False
  /// when it has none, or it isn't paused.
  static bool resume(ValueNotifier<VariableData> variable) {
    final _VariableTween? tween = _tweens[variable];
    if (tween == null || !tween.paused) return false;
    tween.start();
    return true;
  }

  /// Ends [variable]'s animation where it is. False when it has none.
  static bool stop(ValueNotifier<VariableData> variable) {
    final _VariableTween? tween = _tweens[variable];
    if (tween == null) return false;
    tween.finish(false);
    return true;
  }

  /// Sets [variable] to [value] now; its animation carries on from there
  /// (or stays paused there).
  static void seek(ValueNotifier<VariableData> variable, double value) {
    final _VariableTween? tween = _tweens[variable];
    write(variable, value);
    if (tween != null && !tween.paused) tween.start();
  }

  /// Whether [variable] has an animation that is playing (not paused).
  static bool isPlaying(ValueNotifier<VariableData> variable) {
    final _VariableTween? tween = _tweens[variable];
    return tween != null && !tween.paused;
  }

  /// Whether [variable] has an animation, playing or paused.
  static bool isAnimating(ValueNotifier<VariableData> variable) =>
      _tweens[variable] != null;

  /// [variable]'s value as a number, or null.
  static double? valueOf(ValueNotifier<VariableData> variable) =>
      switch (variable.value.getValue()) {
        num n when n.isFinite => n.toDouble(),
        String s => double.tryParse(s.trim()),
        _ => null,
      };

  /// Writes [value] into [variable], whole for an integer variable.
  static void write(ValueNotifier<VariableData> variable, double value) {
    final Object v = variable.value.type == VariableType.integer
        ? value.round()
        : double.parse(value.toStringAsFixed(6));
    final String text = '$v';
    if (variable.value.value == text) return;
    variable.value = variable.value.copyWith(value: text);
  }

  static void _forget(_VariableTween tween) {
    if (identical(_tweens[tween.variable], tween)) _tweens[tween.variable] = null;
  }
}

class _Changes extends ChangeNotifier {
  void ping() => notifyListeners();
}

class _VariableTween {
  _VariableTween(
    this.variable, {
    required this.from,
    required this.to,
    required this.duration,
    required this.curve,
  });

  final ValueNotifier<VariableData> variable;
  final double from;
  final double to;
  final Duration duration;
  final Curve curve;
  final Completer<bool> done = Completer<bool>();

  Ticker? _ticker;

  /// How far along the timeline the ticker started from.
  Duration _base = Duration.zero;

  bool get paused => _ticker == null;

  /// Where on the timeline (0 to 1) the variable's current value sits: the
  /// curve inverted by bisection, so a value scrubbed by hand resumes from
  /// there.
  double _progressOfCurrent() {
    final double? value = VariableAnimator.valueOf(variable);
    if (value == null || to == from) return 0;
    final double target = ((value - from) / (to - from)).clamp(0.0, 1.0);
    if (curve == Curves.linear) return target;
    double lo = 0, hi = 1;
    for (int i = 0; i < 40; i++) {
      final double mid = (lo + hi) / 2;
      if (curve.transform(mid) < target) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return (lo + hi) / 2;
  }

  /// (Re)starts the ticker from the variable's current place.
  void start() {
    _ticker?.dispose();
    _ticker = null;
    if (duration <= Duration.zero) {
      VariableAnimator.write(variable, to);
      finish(true);
      return;
    }
    final double t = _progressOfCurrent();
    if (t >= 1) {
      VariableAnimator.write(variable, to);
      finish(true);
      return;
    }
    _base = duration * t;
    _ticker = Ticker(_tick, debugLabel: 'animateVariable')..start();
    VariableAnimator._changed();
  }

  void _tick(Duration elapsed) {
    final Duration at = _base + elapsed;
    final double t = (at.inMicroseconds / duration.inMicroseconds).clamp(
      0.0,
      1.0,
    );
    VariableAnimator.write(variable, from + (to - from) * curve.transform(t));
    if (t >= 1) finish(true);
  }

  void pause() {
    _ticker?.dispose();
    _ticker = null;
    VariableAnimator._changed();
  }

  void finish(bool completed) {
    _ticker?.dispose();
    _ticker = null;
    VariableAnimator._forget(this);
    if (!done.isCompleted) done.complete(completed);
    VariableAnimator._changed();
  }
}
