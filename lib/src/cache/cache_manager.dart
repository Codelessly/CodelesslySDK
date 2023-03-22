import 'dart:typed_data';

import 'package:flutter/widgets.dart';

/// Abstraction for caching UI data locally for better performance.
abstract class CacheManager {
  /// Initializes the cache manager.
  @mustCallSuper
  Future<void> init();

  /// Disposes the cache manager.
  @mustCallSuper
  void dispose();

  /// Stores a value in the cache, given a [key].
  Future<void> store(String key, dynamic value);

  /// Fetches a value from the cache, given a [key].
  ///
  /// Can optionally have [decode] to specify haw to decode the value.
  /// Throws an exception if the value is not found or failed to load for some
  /// reason.
  T get<T>(String key, {T Function(Map<String, dynamic> value)? decode});

  /// Checks if a value is cached, given a [key].
  bool isCached(String key);

  /// Expires a value from the cache, given a [key].
  Future<void> delete(String key);

  /// Clears all of the cache.
  Future<void> clearAll();

  /// Stores a file in the application's directory.
  Future<void> saveFile(String pathKey, String name, Uint8List bytes);

  /// Fetches a file from the application's directory.
  ///
  /// Throws an exception if the file is not found.
  Future<Uint8List> getFile(String pathKey, String name);

  /// Checks if a file is stored in the application's directory.
  Future<bool> isFileCached(String pathKey, String name);

  /// Deletes a file from the application's directory.
  Future<void> deleteFile(String pathKey, String name);

  /// Deletes all of the files from the given path, excluding the given files.
  Future<void> purgeFiles(
    String pathKey, {
    Iterable<String> excludedFileNames = const [],
  });

  /// Clears all of the files from the application's directory.
  Future<void> deleteAllFiles();
}
