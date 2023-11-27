import 'dart:async';
import 'dart:developer';

import 'package:flutter/cupertino.dart';
import 'package:hive/hive.dart';

/// Allows access to local storage on the device. Implementations of this class
/// should be able to store and retrieve data from the device's local storage.
/// This is mainly used to store data via actions for the SDK.
///
/// This abstraction provides access to the local storage via a key-value store.
/// The key is a string and the value is an object. The object can be any
/// primitive type or a list or map of primitive types depending on the
/// implementation.
abstract class LocalStorage extends ChangeNotifier {
  /// A map of notifiers for a key in the storage. This is used to notify
  /// listeners when the value for a key in the storage changes.
  final Map<String, _StorageListenable> _notifiers = {};

  /// Whether or not the storage contains the given [key].
  bool containsKey(String key);

  /// Returns all the data in the storage as a map.
  Map<String, dynamic> getAll();

  /// Stores the given [value] in the storage with the given [key].
  Future<void> put(String key, Object? value);

  /// Returns the value stored in the storage with the given [key].
  /// If the key is not found or has a null value, then
  /// the [defaultValue] is returned.
  Object? get(String key, {Object? defaultValue});

  /// Removes the value stored in the storage with the given [key].
  Future<void> remove(String key);

  /// Clears all the data in the storage.
  Future<void> clear();

  /// Returns a [_StorageListenable] that notifies when the value for the
  /// given [key] in the storage changes. These listeners are automatically
  /// disposed when the storage is closed using [close] method.
  ///
  /// If the [key] is null, then the returned listenable notifies when any
  /// value in the storage changes.
  Listenable getNotifier(String? key);

  @override
  void dispose() {
    // Dispose all the notifiers.
    _notifiers.values.forEach((notifier) => notifier.dispose());
    _notifiers.clear();

    super.dispose();
  }
}

/// A [LocalStorage] implementation that uses [Hive] as the underlying storage.
/// This is used to store data via actions for the SDK.
class HiveLocalStorage extends LocalStorage {
  final Box _box;

  late final StreamSubscription? _subscription;

  /// Creates a [HiveLocalStorage] with the given [box].
  HiveLocalStorage(this._box) {
    // Listen to changes in the storage.
    _subscription = _box.watch().listen(_onBoxChanged);
  }

  /// Called when the storage changes. This notifies the listeners for the
  /// given [key] in the storage. This also notifies the listeners for the
  /// storage itself.
  void _onBoxChanged(BoxEvent event) {
    log('storage changed for key: ${event.key}');

    // Get the notifier for the given key.
    final notifier = _notifiers[event.key.toString()];

    // Notify the notifier for the given key if it exists.
    if (notifier != null) notifier.notify();

    // Notify the notifier for the storage itself.
    notifyListeners();
  }

  @override
  Listenable getNotifier(String? key) {
    // Return this as the listenable if key is null, notifying when any key
    // in the storage changes.
    if (key == null) return this;

    // Return the notifier for the given key if it already exists.
    if (_notifiers.containsKey(key)) return _notifiers[key]!;

    // Create a new notifier for the given key.
    final notifier = _StorageListenable._(key);

    // Add the notifier to the map of notifiers.
    _notifiers[key] = notifier;

    // Return the notifier.
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
    // Return default value if key is not found.
    if (!_box.containsKey(key)) return defaultValue;
    return _box.get(key) ?? defaultValue;
  }

  @override
  Future<void> remove(String key) => _box.delete(key);

  @override
  void dispose() async {
    // Cancel the subscription to the storage updates.
    _subscription?.cancel();

    // Close the box itself.
    await _box.close();

    super.dispose();
  }

  @override
  Future<void> clear() => _box.clear();
}

/// A [Listenable] that notifies when the value for the given [key] in the
/// storage changes.
class _StorageListenable extends ChangeNotifier {
  final String? _key;

  _StorageListenable._(this._key);

  /// Notifies the listeners that the value for the given [key] in the storage
  /// has changed.
  void notify() {
    log('notifying storage changed for key: $_key');
    notifyListeners();
  }
}
