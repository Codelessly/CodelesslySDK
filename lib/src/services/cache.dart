// Caching: JSON values by key (publish models, auth data, paywalls) and files
// by folder and name (fonts, images). In memory by default; an app plugs in
// a persistent cache.
import 'dart:async';
import 'dart:typed_data';

/// JSON values by key. Values are JSON-encodable (maps, lists, scalars).
abstract interface class KeyValueCache {
  /// The value at [key], or null.
  FutureOr<Object?> read(String key);

  /// Stores [value] at [key].
  Future<void> write(String key, Object? value);

  Future<bool> contains(String key);
  Future<void> delete(String key);

  /// Removes every value.
  Future<void> clear();
}

/// Files by folder ([folder], such as `fonts`) and [name].
abstract interface class FileCache {
  Future<Uint8List?> read(String folder, String name);
  Future<void> write(String folder, String name, Uint8List bytes);
  Future<bool> contains(String folder, String name);
  Future<void> delete(String folder, String name);

  /// Deletes the files of [folder] except [keep].
  Future<void> purge(String folder, {Iterable<String> keep = const []});

  /// Deletes every file.
  Future<void> clear();
}

/// A [KeyValueCache] in memory.
class MemoryKeyValueCache implements KeyValueCache {
  final Map<String, Object?> values = {};

  @override
  Object? read(String key) => values[key];

  @override
  Future<void> write(String key, Object? value) async => values[key] = value;

  @override
  Future<bool> contains(String key) async => values.containsKey(key);

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<void> clear() async => values.clear();
}

/// A [FileCache] in memory.
class MemoryFileCache implements FileCache {
  /// Folder → name → bytes.
  final Map<String, Map<String, Uint8List>> files = {};

  @override
  Future<Uint8List?> read(String folder, String name) async => files[folder]?[name];

  @override
  Future<void> write(String folder, String name, Uint8List bytes) async =>
      files.putIfAbsent(folder, () => {})[name] = bytes;

  @override
  Future<bool> contains(String folder, String name) async => files[folder]?.containsKey(name) ?? false;

  @override
  Future<void> delete(String folder, String name) async => files[folder]?.remove(name);

  @override
  Future<void> purge(String folder, {Iterable<String> keep = const []}) async {
    final kept = keep.toSet();
    files[folder]?.removeWhere((name, _) => !kept.contains(name));
  }

  @override
  Future<void> clear() async => files.clear();
}

/// Reads [key] from [cache] with [decode], deleting a value that doesn't
/// decode (so a stale format never breaks a load).
Future<T?> readCached<T>(KeyValueCache cache, String key, T Function(Object? json) decode) async {
  final raw = await cache.read(key);
  if (raw == null) return null;
  try {
    return decode(raw);
  } catch (_) {
    await cache.delete(key);
    return null;
  }
}
