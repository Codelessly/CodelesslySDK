import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../../codelessly_sdk.dart';
import '../logging/debug_logger.dart';

/// Handles caching of any data that needs to be cached via Hive.
class CodelesslyCacheManager extends CacheManager {
  static const String name = 'CacheManager';

  /// The configuration used by the [Codelessly] SDK.
  final CodelesslyConfig config;

  /// Creates a [CodelesslyCacheManager] instance with the provided [config].
  CodelesslyCacheManager({required this.config});

  /// The [Box] instance used to store any arbitrary data excluding byte
  /// information.
  late Box box;

  /// The [Box] instance used to store any byte information, mainly used for
  /// storing font files.
  late Box filesBox;

  @override
  Future<void> init() async {
    DebugLogger.instance.printFunction('init()', name: name);
    final Stopwatch stopwatch = Stopwatch()..start();
    try {
      await Hive.initFlutter('codelessly_sdk');
      box = await Hive.openBox(
        '${cacheBoxName}_${config.uniqueID.replaceAll('/', '')}',
      );
      filesBox = await Hive.openBox(
        '${cacheFilesBoxName}_${config.uniqueID.replaceAll('/', '')}',
      );
    } on HiveError catch (e, stacktrace) {
      throw CodelesslyException(
        'Failed to initialize cache manager.\n${e.message}',
        stacktrace: stacktrace,
      );
    } catch (e, stacktrace) {
      throw CodelesslyException(
        'Failed to initialize cache manager',
        originalException: e,
        stacktrace: stacktrace,
      );
    } finally {
      stopwatch.stop();

      DebugLogger.instance.printInfo(
        'Initialized Hive in ${stopwatch.elapsed.inMilliseconds}ms or ${stopwatch.elapsed.inSeconds}s',
        name: name,
      );
    }
  }

  @override
  Future<void> clearAll() async {
    DebugLogger.instance.printFunction('clearAll()', name: name);
    DebugLogger.instance.printInfo('Clearing cache...', name: name);
    try {
      await box.clear();
      DebugLogger.instance.printInfo('Cache cleared successfully!', name: name);
    } catch (e, stacktrace) {
      throw CodelesslyException.cacheClearException(
        message: 'Failed to clear cache. $e',
        originalException: e,
        stacktrace: stacktrace,
      );
    }
  }

  @override
  void reset() {
    DebugLogger.instance.printFunction('reset()', name: name);
  }

  @override
  void dispose() async {
    DebugLogger.instance.printFunction('dispose()', name: name);
    box.close();
    filesBox.close();
  }

  @override
  Future<void> store(String key, dynamic value) async {
    DebugLogger.instance.printFunction('store(key: $key)', name: name);
    try {
      if (value is String || value is num || value is bool || value is List) {
        return box.put(key, value);
      }
      return box.put(key, jsonEncode(value));
    } catch (e, stacktrace) {
      throw CodelesslyException.cacheStoreException(
        message: 'Failed to store value of $key\nValue: $value',
        originalException: e,
        stacktrace: stacktrace,
      );
    }
  }

  @override
  T get<T>(String key, {T Function(Map<String, dynamic> value)? decode}) {
    DebugLogger.instance.printFunction('get<$T>(key: $key)', name: name);
    try {
      final dynamic value = box.get(key);
      if (decode != null && value is String) {
        final json = jsonDecode(value);
        return decode(json);
      } else {
        return value as T;
      }
    } catch (e, stacktrace) {
      throw CodelesslyException.cacheLookupException(
        message: 'Failed to get value of $key from cache',
        originalException: e,
        stacktrace: stacktrace,
      );
    }
  }

  @override
  bool isCached(String key) {
    DebugLogger.instance.printFunction('isCached(key: $key)', name: name);
    return box.containsKey(key);
  }

  @override
  Future<void> delete(String key) {
    DebugLogger.instance.printFunction('delete(key: $key)', name: name);
    return box.delete(key);
  }

  @override
  Future<void> deleteAllByteData() async {
    DebugLogger.instance.printFunction('deleteAllByteData()', name: name);
    DebugLogger.instance.printInfo('Deleting all byte data...', name: name);
    try {
      filesBox.clear();
      DebugLogger.instance
          .printInfo('Cache bytes deleted successfully!', name: name);
    } catch (e, stacktrace) {
      throw CodelesslyException.fileIoException(
        message: 'Failed to clear files.\n$e',
        originalException: e,
        stacktrace: stacktrace,
      );
    }
  }

  @override
  Future<void> deleteBytes(String pathKey, String name) async {
    DebugLogger.instance.printFunction(
      'deleteBytes(pathKey: $pathKey, name: $name)',
      name: name,
    );
    try {
      final key = '$pathKey/$name';
      await filesBox.delete(key);
    } catch (e, stacktrace) {
      throw CodelesslyException.fileIoException(
        message: 'Failed to delete file $pathKey/$name',
        originalException: e,
        stacktrace: stacktrace,
      );
    }
  }

  @override
  Uint8List getBytes(String pathKey, String name) {
    DebugLogger.instance.printFunction(
      'getBytes(pathKey: $pathKey, name: $name)',
      name: name,
    );
    final key = '$pathKey/$name';
    if (filesBox.containsKey(key)) {
      return filesBox.get(key);
    }
    throw CodelesslyException.fileIoException(
      message: 'File $pathKey/$name does not exist',
    );
  }

  @override
  Future<bool> areBytesCached(String pathKey, String name) async {
    DebugLogger.instance.printFunction(
      'areBytesCached(pathKey: $pathKey, name: $name)',
      name: name,
    );
    try {
      final key = '$pathKey/$name';
      return filesBox.containsKey(key);
    } catch (e, stacktrace) {
      throw CodelesslyException.fileIoException(
        message: 'Failed to check if file $pathKey/$name is cached',
        originalException: e,
        stacktrace: stacktrace,
      );
    }
  }

  @override
  Future<void> purgeBytes(
    String pathKey, {
    Iterable<String> excludedFileNames = const [],
  }) async {
    DebugLogger.instance.printFunction(
      'purgeBytes(pathKey: $pathKey, excludedFileNames: ${excludedFileNames.join(', ')})',
      name: name,
    );
    DebugLogger.instance.printInfo(
      'Purging outdated files. (excluding: ${excludedFileNames.join(', ')})',
      name: name,
    );
    int purgedFiles = 0;
    try {
      for (final String path in filesBox.keys) {
        if (!path.startsWith(pathKey)) {
          continue;
        }
        final String fileName = path.split('/').last;
        if (!excludedFileNames.contains(fileName)) {
          DebugLogger.instance
              .printInfo('\t\tDeleting file: $path', name: name);

          await filesBox.delete(path);

          DebugLogger.instance
              .printInfo('\t\tSuccessfully deleted.', name: name);

          purgedFiles++;
        }
      }

      if (purgedFiles > 0) {
        DebugLogger.instance.printInfo(
          'Successfully purged $purgedFiles files.',
          name: name,
        );
      } else {
        DebugLogger.instance.printInfo('No files were purged.', name: name);
      }
    } catch (e, stacktrace) {
      throw CodelesslyException.fileIoException(
        message: 'Failed to purge files in $pathKey.\nError: $e',
        originalException: e,
        stacktrace: stacktrace,
      );
    }
  }

  @override
  Future<void> storeBytes(String pathKey, String name, Uint8List bytes) async {
    DebugLogger.instance.printFunction(
      'storeBytes(pathKey: $pathKey, name: $name)',
      name: name,
    );
    try {
      final key = '$pathKey/$name';
      await filesBox.put(key, bytes);
      DebugLogger.instance.printInfo(
        'Successfully saved file $pathKey/$name',
        name: name,
      );
    } catch (e, stacktrace) {
      throw CodelesslyException.fileIoException(
        message: 'Failed to save file $pathKey/$name',
        originalException: e,
        stacktrace: stacktrace,
      );
    }
  }
}
