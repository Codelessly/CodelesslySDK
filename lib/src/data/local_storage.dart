import 'dart:async';
import 'dart:developer';

import 'package:flutter/cupertino.dart';
import 'package:hive/hive.dart';

abstract class LocalStorage extends ChangeNotifier {
  final Map<String, StorageListenable> _notifiers = {};

  bool containsKey(String key);

  Map<String, dynamic> getAll();

  Future<void> put(String key, Object? value);

  Object? get(String key, {Object? defaultValue});

  Future<void> remove(String key);

  Future<void> close();

  Future<void> clear();

  Listenable getNotifier(String? key);
}

class HiveLocalStorage extends LocalStorage {
  final Box _box;

  late final StreamSubscription? _subscription;

  HiveLocalStorage(this._box) {
    _subscription = _box.watch().listen(onBoxChanged);
  }

  void onBoxChanged(BoxEvent event) {
    log('storage changed for key: ${event.key}');
    final notifier = _notifiers[event.key.toString()];
    if (notifier != null) notifier.notify();

    notifyListeners();
  }

  @override
  Listenable getNotifier(String? key) {
    if (key == null) return this;
    if (_notifiers.containsKey(key)) return _notifiers[key]!;

    final notifier = StorageListenable._(key);
    _notifiers[key] = notifier;
    return notifier;
  }

  @override
  bool containsKey(String key) => _box.containsKey(key);

  @override
  Map<String, dynamic> getAll() => Map<String, dynamic>.from(_box.toMap());

  @override
  Future<void> put(String key, Object? value) => _box.put(key, value);

  @override
  Object? get(String key, {Object? defaultValue}) {
    if (!_box.containsKey(key)) return defaultValue;
    return _box.get(key) ?? defaultValue;
  }

  @override
  Future<void> remove(String key) => _box.delete(key);

  @override
  Future<void> close() {
    _subscription?.cancel();
    _notifiers.values.forEach((notifier) => notifier.dispose());
    _notifiers.clear();
    return _box.close();
  }

  @override
  Future<void> clear() => _box.clear();
}

class StorageListenable extends ChangeNotifier {
  final String? _key;

  StorageListenable._(this._key);

  void notify() {
    log('notifying storage changed for key: $_key');
    notifyListeners();
  }
}
