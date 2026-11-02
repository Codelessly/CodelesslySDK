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
  int _listeners = 0;

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    _listeners++;
    _timer ??= Timer.periodic(interval, (_) => notifyListeners());
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    _listeners = _listeners > 0 ? _listeners - 1 : 0;
    if (_listeners == 0) {
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

  int _listeners = 0;
  bool _scheduled = false;

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    _listeners++;
    _schedule();
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    _listeners = _listeners > 0 ? _listeners - 1 : 0;
  }

  void _schedule() {
    if (_scheduled || _listeners == 0 || FormulaClock.pinned != null) return;
    _scheduled = true;
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      _scheduled = false;
      if (_listeners == 0) return;
      notifyListeners();
      _schedule();
    });
    SchedulerBinding.instance.scheduleFrame();
  }

  /// Whether a frame is scheduled for the clock.
  @visibleForTesting
  bool get isTicking => _scheduled;
}
