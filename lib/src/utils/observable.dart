import 'package:flutter/foundation.dart';

/// A custom Value notifier that lets you set the value without notifying
/// listeners via [set] method.
class Observable<T> extends ValueNotifier<T> {
  Observable(this._myValue) : super(_myValue);

  T _myValue;

  @override
  T get value => _myValue;

  @override
  set value(T newValue) {
    if (_myValue == newValue) {
      return;
    }
    _myValue = newValue;
    notifyListeners();
  }

  void set(T newValue, {bool notify = true}) {
    if (_myValue == newValue) return;
    _myValue = newValue;
    if (notify) notifyListeners();
  }
}
