// The app's lifecycle as a Flutter widget app reports it: the binding's
// observer, handed to what needs it (the automations) as an
// [AppLifecycleSource].
import 'package:flutter/widgets.dart';

import '../features/engage/automations.dart' show AppLifecycleSource;

/// The widget binding's lifecycle changes. One for the process; it observes
/// the binding while something listens. Where there is no binding (a
/// headless test), nothing is reported.
class WidgetsLifecycleSource with WidgetsBindingObserver implements AppLifecycleSource {
  WidgetsLifecycleSource._();

  static final WidgetsLifecycleSource instance = WidgetsLifecycleSource._();

  final List<ValueChanged<AppLifecycleState>> _listeners = [];
  bool _observing = false;

  @override
  void addListener(ValueChanged<AppLifecycleState> listener) {
    _listeners.add(listener);
    if (_observing) return;
    try {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    } catch (_) {
      // No binding: the app reports lifecycle changes itself.
    }
  }

  @override
  void removeListener(ValueChanged<AppLifecycleState> listener) {
    _listeners.remove(listener);
    if (_listeners.isEmpty && _observing) {
      WidgetsBinding.instance.removeObserver(this);
      _observing = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    for (final l in List.of(_listeners)) {
      l(state);
    }
  }
}
