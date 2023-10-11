import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:hive/hive.dart';

abstract class LocalStorage extends ChangeNotifier {
  final Map<String, ValueNotifier> _notifiers = {};

  bool containsKey(String key);

  Map<String, dynamic> getAll();

  Future<void> put(String key, Object value);

  Object? get(String key);

  Future<void> remove(String key);

  Future<void> close();

  Future<void> clear();

  Listenable getNotifier(String? key) {
    if (key == null) return this;
    if (_notifiers.containsKey(key)) return _notifiers[key]!;

    final value = containsKey(key) ? get(key) : null;
    final notifier = ValueNotifier(value);
    _notifiers[key] = notifier;
    return notifier;
  }
}

class HiveLocalStorage extends LocalStorage {
  final Box _box;

  late final StreamSubscription? _subscription;

  HiveLocalStorage(this._box) {
    _subscription = _box.watch().listen(onBoxChanged);
  }

  void onBoxChanged(BoxEvent event) {
    final notifier = _notifiers[event.key.toString()];
    if (notifier != null) notifier.value = event.value;

    notifyListeners();
  }

  @override
  bool containsKey(String key) => _box.containsKey(key);

  @override
  Map<String, dynamic> getAll() => _box.toMap() as Map<String, dynamic>;

  @override
  Future<void> put(String key, Object value) => _box.put(key, value);

  @override
  Object? get(String key) {
    if (!_box.containsKey(key)) return null;
    return _box.get(key);
  }

  @override
  Future<void> remove(String key) => _box.delete(key);

  @override
  Future<void> close() {
    _subscription?.cancel();
    return _box.close();
  }

  @override
  Future<void> clear() => _box.clear();
}
