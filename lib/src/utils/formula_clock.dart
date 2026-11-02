import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Ticks once a second while anything listens, so widgets whose formulas call
/// `now()` or `today()` rebuild and their clocks and countdowns stay live.
///
/// The timer only runs while there are listeners.
class FormulaClock extends ChangeNotifier {
  FormulaClock._();

  /// Optional instant pinned by an editor or preview for deterministic dates.
  static DateTime? pinned;

  /// The pinned instant, or the device clock for live formulas.
  static DateTime now() => pinned ?? DateTime.now();

  /// The clock every formula-bound widget shares.
  static final FormulaClock instance = FormulaClock._();

  /// Time between ticks.
  static Duration interval = const Duration(seconds: 1);

  Timer? _timer;

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    _timer ??= Timer.periodic(interval, (_) => notifyListeners());
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
