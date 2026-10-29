import 'dart:async';

import 'package:flutter/foundation.dart';

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
