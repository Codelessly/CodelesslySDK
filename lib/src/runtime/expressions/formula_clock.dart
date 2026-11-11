import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// How often a formula's value can change as time passes, finest first:
/// what a widget showing it must be rebuilt on ([FormulaClock.of]).
///
/// * [frame]: `nowMs()`, a millisecond clock (every frame);
/// * [second]: `now()`, a time of day or a countdown (every second);
/// * [minute]: `today()`, `timeAgo(date)`, `isToday(date)`: values that
///   change at most once a minute (every minute).
enum ClockTick {
  frame,
  second,
  minute;

  /// The finer of this and [other] (either may be null).
  ClockTick finer(ClockTick? other) => other == null || index <= other.index ? this : other;
}

/// Ticks while anything listens, so widgets whose formulas read the clock
/// rebuild and their clocks, countdowns and relative times stay live:
/// [instance] once a second (`now()`), [minutes] once a minute (`today()`,
/// `timeAgo(date)`).
///
/// The timer only runs while there are listeners. Tests pin the time with
/// [pinned] and step it with [tick].
class FormulaClock extends ChangeNotifier {
  FormulaClock._(this._interval);

  /// Optional instant pinned by an editor or preview for deterministic dates.
  static DateTime? pinned;

  /// The pinned instant, or the device clock for live formulas.
  static DateTime now() => pinned ?? DateTime.now();

  /// The clock every formula reading `now()` shares: ticks every [interval].
  static final FormulaClock instance = FormulaClock._(() => interval);

  /// The clock every formula whose value changes at most once a minute
  /// shares (`today()`, `timeAgo(date)`): ticks every [minuteInterval].
  static final FormulaClock minutes = FormulaClock._(() => minuteInterval);

  /// Time between [instance]'s ticks.
  static Duration interval = const Duration(seconds: 1);

  /// Time between [minutes]' ticks.
  static Duration minuteInterval = const Duration(minutes: 1);

  /// What a widget showing a formula that changes every [tick] listens to:
  /// [FrameClock.instance], [instance] or [minutes].
  static Listenable of(ClockTick tick) => switch (tick) {
        ClockTick.frame => FrameClock.instance,
        ClockTick.second => instance,
        ClockTick.minute => minutes,
      };

  final Duration Function() _interval;
  Timer? _timer;

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    _timer ??= Timer.periodic(_interval(), (_) => notifyListeners());
  }

  // Whether anything still listens is asked of the notifier: a count of
  // adds and removes drifts when a widget removes a listener it never
  // added, and would stop the clock under widgets still listening.
  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (!hasListeners) {
      _timer?.cancel();
      _timer = null;
    }
  }

  /// Whether the timer is running.
  @visibleForTesting
  bool get isTicking => _timer != null;

  /// Whether anything listens.
  @visibleForTesting
  bool get isListened => hasListeners;

  /// Ticks now, as the timer would: tests and editors move [pinned] and
  /// call it.
  void tick() => notifyListeners();
}

/// Ticks on every frame while anything listens, so widgets whose formulas
/// call `nowMs()` rebuild each frame: a meter decaying from its last hit
/// (`${= hit * exp(-7 * (nowMs() - at) / 1000)}`), a progress bar, a timer
/// to the millisecond. Nothing runs while nothing listens, and a pinned
/// [FormulaClock] (an editor or test) doesn't tick.
class FrameClock extends ChangeNotifier {
  FrameClock._();

  /// The clock every frame-bound widget shares.
  static final FrameClock instance = FrameClock._();

  /// Whether the clock ticks. An editor turns it off: its design canvas
  /// shows a still frame instead of redrawing every frame.
  static bool enabled = true;

  bool _scheduled = false;

  // Whether anything listens is asked of the notifier itself: a count of
  // adds and removes drifts when a widget removes a listener it never
  // added (or twice), and the clock would stop with widgets still
  // listening, freezing them.
  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    _schedule();
  }

  void _schedule() {
    if (_scheduled ||
        !hasListeners ||
        !enabled ||
        FormulaClock.pinned != null) {
      return;
    }
    _scheduled = true;
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      _scheduled = false;
      if (!hasListeners) return;
      notifyListeners();
      _schedule();
    });
    SchedulerBinding.instance.scheduleFrame();
  }

  /// Whether a frame is scheduled for the clock.
  @visibleForTesting
  bool get isTicking => _scheduled;
}
