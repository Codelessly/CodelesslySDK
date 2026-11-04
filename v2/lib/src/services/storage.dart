// Local storage: the app's own values on the device (storage actions, the
// `storage` variable), and cloud files (uploads).
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Values the app keeps on the device, by key. Notifies its listeners on
/// every change; [listenable] narrows that to one key.
abstract interface class LocalStorage implements Listenable {
  Object? get(String key);
  bool containsKey(String key);

  /// Every value, by key.
  Map<String, Object?> getAll();

  /// Stores [value] (JSON-encodable).
  Future<void> put(String key, Object? value);
  Future<void> remove(String key);
  Future<void> clear();

  /// Notifies when [key] changes (any key, for null).
  Listenable listenable(String? key);
}

/// Shared [LocalStorage] bookkeeping: per-key notifiers.
abstract class LocalStorageBase extends ChangeNotifier implements LocalStorage {
  final Map<String, ChangeNotifier> _keys = {};

  @override
  Listenable listenable(String? key) => key == null ? this : _keys.putIfAbsent(key, _KeyNotifier.new);

  /// Tells listeners of [key] (every key, for null) and of all keys.
  @protected
  void changed(String? key) {
    if (key == null) {
      for (final n in _keys.values) {
        (n as _KeyNotifier).notify();
      }
    } else {
      (_keys[key] as _KeyNotifier?)?.notify();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    for (final n in _keys.values) {
      n.dispose();
    }
    super.dispose();
  }
}

class _KeyNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

/// [LocalStorage] in memory: the default, and for tests.
class MemoryLocalStorage extends LocalStorageBase {
  MemoryLocalStorage([Map<String, Object?>? values]) : _values = {...?values};

  final Map<String, Object?> _values;

  @override
  Object? get(String key) => _values[key];

  @override
  bool containsKey(String key) => _values.containsKey(key);

  @override
  Map<String, Object?> getAll() => Map.unmodifiable(_values);

  @override
  Future<void> put(String key, Object? value) async {
    _values[key] = value;
    changed(key);
  }

  @override
  Future<void> remove(String key) async {
    if (_values.remove(key) != null) changed(key);
  }

  @override
  Future<void> clear() async {
    _values.clear();
    changed(null);
  }
}

/// [LocalStorage] in the platform's preferences (SharedPreferences,
/// NSUserDefaults, localStorage), each value JSON-encoded under
/// `prefix + key`, so apps with several projects keep them apart.
class PreferencesLocalStorage extends LocalStorageBase {
  PreferencesLocalStorage._(this._prefs, this.prefix) {
    for (final key in _prefs.getKeys()) {
      if (!key.startsWith(prefix)) continue;
      final raw = _prefs.getString(key);
      if (raw == null) continue;
      try {
        _values[key.substring(prefix.length)] = jsonDecode(raw);
      } on FormatException {
        _values[key.substring(prefix.length)] = raw;
      }
    }
  }

  /// Opens the storage for [prefix] (`codelessly.{projectId}.`).
  static Future<PreferencesLocalStorage> open({String prefix = 'codelessly.'}) async =>
      PreferencesLocalStorage._(await SharedPreferences.getInstance(), prefix);

  final SharedPreferences _prefs;
  final String prefix;
  final Map<String, Object?> _values = {};

  @override
  Object? get(String key) => _values[key];

  @override
  bool containsKey(String key) => _values.containsKey(key);

  @override
  Map<String, Object?> getAll() => Map.unmodifiable(_values);

  @override
  Future<void> put(String key, Object? value) async {
    _values[key] = value;
    changed(key);
    await _prefs.setString('$prefix$key', jsonEncode(value));
  }

  @override
  Future<void> remove(String key) async {
    _values.remove(key);
    changed(key);
    await _prefs.remove('$prefix$key');
  }

  @override
  Future<void> clear() async {
    final keys = [..._values.keys];
    _values.clear();
    changed(null);
    for (final key in keys) {
      await _prefs.remove('$prefix$key');
    }
  }
}

/// Who can read an uploaded file.
enum CloudFileAccess {
  /// Anyone with its URL.
  public,

  /// Only the user who uploaded it (under `users/{uid}`).
  private,
}

/// A stored file.
@immutable
class CloudFile {
  const CloudFile({required this.path, required this.url, this.name = '', this.size, this.contentType});

  /// Its path in the storage.
  final String path;

  /// Where it downloads from.
  final String url;
  final String name;
  final int? size;
  final String? contentType;

  Map<String, Object?> toValue() => {
        'path': path,
        'url': url,
        'name': name,
        'size': ?size,
        'contentType': ?contentType,
      };
}

/// Files in the cloud (uploads). Paths are relative to the project's
/// folder; implementations keep a path from leaving it.
abstract interface class CloudFileStorage {
  Future<CloudFile> upload(String path, Uint8List bytes, {String? contentType});

  /// Deletes the file at [pathOrUrl].
  Future<void> delete(String pathOrUrl);

  /// The files directly in [folder].
  Future<List<CloudFile>> list(String folder);

  /// The download URL of the file at [path].
  Future<String> downloadUrl(String path);
}

/// Path helpers shared by cloud file storages.
abstract final class CloudFilePaths {
  static const _contentTypes = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'gif': 'image/gif',
    'webp': 'image/webp',
    'heic': 'image/heic',
    'bmp': 'image/bmp',
    'svg': 'image/svg+xml',
    'pdf': 'application/pdf',
  };

  /// The content type for a file [extension].
  static String contentTypeFor(String extension) =>
      _contentTypes[extension.toLowerCase()] ?? 'application/octet-stream';

  /// [path]'s segments without empty and `..` ones, so it can't leave its
  /// root.
  static List<String> segments(String path) => [
        for (final s in path.split('/'))
          if (s.trim().isNotEmpty && s.trim() != '..') s.trim(),
      ];

  /// [folder] under [root]; a private file goes under its uploader's
  /// `users/{uid}`, which storage rules keep to them. Throws a [StateError]
  /// for a private file without a signed-in user.
  static String folderFor({required String root, required String folder, CloudFileAccess access = CloudFileAccess.public, String? uid}) {
    if (access == CloudFileAccess.public) return [root, ...segments(folder)].join('/');
    if (uid == null || uid.isEmpty) throw StateError('Sign in to upload private files.');
    return [root, 'users', uid, ...segments(folder)].join('/');
  }
}

/// [CloudFileStorage] in memory (tests, previews): URLs are `memory://path`.
class MemoryFileStorage implements CloudFileStorage {
  final Map<String, (Uint8List, String?)> files = {};

  String _clean(String path) => CloudFilePaths.segments(path.replaceFirst('memory://', '')).join('/');

  @override
  Future<CloudFile> upload(String path, Uint8List bytes, {String? contentType}) async {
    final p = _clean(path);
    files[p] = (bytes, contentType);
    return CloudFile(path: p, url: 'memory://$p', name: p.split('/').last, size: bytes.length, contentType: contentType);
  }

  @override
  Future<void> delete(String pathOrUrl) async => files.remove(_clean(pathOrUrl));

  @override
  Future<List<CloudFile>> list(String folder) async {
    final f = _clean(folder);
    return [
      for (final e in files.entries)
        if (e.key.startsWith('$f/') && !e.key.substring(f.length + 1).contains('/'))
          CloudFile(path: e.key, url: 'memory://${e.key}', name: e.key.split('/').last, size: e.value.$1.length, contentType: e.value.$2),
    ];
  }

  @override
  Future<String> downloadUrl(String path) async {
    final p = _clean(path);
    if (!files.containsKey(p)) throw StateError('No file at $p.');
    return 'memory://$p';
  }
}
