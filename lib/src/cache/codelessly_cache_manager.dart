import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../codelessly_sdk.dart';

const String _label = 'Cache Manager';

/// Handles caching of any data that needs to be cached via Hive.
class CodelesslyCacheManager extends CacheManager {
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

      logger.log(
        _label,
        'Initialized Hive in ${stopwatch.elapsed.inMilliseconds}ms or ${stopwatch.elapsed.inSeconds}s',
      );
    }
  }

  @override
  Future<void> clearAll() async {
    logger.log(_label, 'Clearing cache...');
    try {
      await box.clear();
      logger.log(_label, 'Cache cleared successfully!');
    } catch (e, stacktrace) {
      throw CodelesslyException.cacheClearException(
        message: 'Failed to clear cache. $e',
        originalException: e,
        stacktrace: stacktrace,
      );
    }
  }

  @override
  void reset() {}

  @override
  void dispose() async {
    box.close();
    filesBox.close();
  }

  @override
  Future<void> store(String key, dynamic value) {
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
  bool isCached(String key) => box.containsKey(key);

  @override
  Future<void> delete(String key) => box.delete(key);

  @override
  Future<void> deleteAllByteData() async {
    logger.log(_label, 'Deleting all byte data...');
    try {
      filesBox.clear();
      logger.log(_label, 'Cache bytes deleted successfully!');
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
    logger.log(_label,
        'Purging outdated files. (excluding: ${excludedFileNames.join(', ')})');
    int purgedFiles = 0;
    try {
      for (final String path in filesBox.keys) {
        if (!path.startsWith(pathKey)) {
          continue;
        }
        final String fileName = path.split('/').last;
        if (!excludedFileNames.contains(fileName)) {
          logger.log(_label, '\t\tDeleting file: $path');

          await filesBox.delete(path);

          logger.log(_label, '\t\tSuccessfully deleted.');

          purgedFiles++;
        }
      }

      if (purgedFiles > 0) {
        logger.log(_label, 'Successfully purged $purgedFiles files.');
      } else {
        logger.log(_label, 'No files were purged.');
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
    try {
      final key = '$pathKey/$name';
      await filesBox.put(key, bytes);
      logger.log(_label, 'Successfully saved file $pathKey/$name');
    } catch (e, stacktrace) {
      throw CodelesslyException.fileIoException(
        message: 'Failed to save file $pathKey/$name',
        originalException: e,
        stacktrace: stacktrace,
      );
    }
  }
}
