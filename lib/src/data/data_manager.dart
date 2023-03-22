import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart';

import '../../codelessly_sdk.dart';
import '../cache/cache_manager.dart';
import '../error/error_handler.dart';

enum DataManagerStatus {
  /// The data manager has not been initialized.
  idle,

  /// The data manager is currently initializing.
  initializing,

  /// The data manager has been initialized.
  initialized,
}

/// Abstraction for loading UI data from a remote source.
abstract class DataManager {
  /// Initializes the [DataManager] instance.
  @mustCallSuper
  Future<void> init();

  /// Disposes the [DataManager] instance.
  @mustCallSuper
  void dispose();

  /// Sets the [SDKPublishModel] as null.
  @mustCallSuper
  void invalidate();

  /// The current status of this data manager.
  DataManagerStatus status = DataManagerStatus.idle;

  /// The status stream that updates as the status of this data manager changes.
  Stream<DataManagerStatus> get statusStream;

  /// [returns] the publish model that is currently loaded.
  SDKPublishModel? get publishModel;

  /// [returns] the publish model stream that updates as the publish model
  ///           changes, either pulled from cache or server.
  Stream<SDKPublishModel> get publishModelStream;

  /// Fetches the relevant [SDKPublishModel] from the server based on the
  /// configurations of the implementation.
  Future<SDKPublishModel> downloadPublishModel();

  /// Loads font families using [FontLoader]. Will either pull the font
  /// variants from cache or downloads them.
  ///
  /// Flutter's FontLoader is used to load the font into the app.
  ///
  /// If [DataUtils] already contains the font, then it is already loaded
  /// in Flutter and will be skipped.
  Future<void> loadFonts({
    required SDKPublishModel model,
    required Iterable<SDKPublishFont> fonts,
    required CacheManager cacheManager,
    required String cacheKey,
  }) async {
    final List<Future> futures = [];
    model.fonts.clear();

    for (final SDKPublishFont font in fonts) {
      // Reconstruct the full font name.
      final String fullFontName = font.fullFontName;
      print(
          'Font id: $fullFontName name: ${font.family} | style: ${font.style} | weight: ${font.weight}');
      futures.add(Future(() async {
        try {
          print('\tLoading font [$fullFontName]...');
          // Fetch the bytes of this font, either from file cache or from a get
          // request.
          final Uint8List? fontBytes = await fetchFontBytes(
            fullFontName,
            font.url,
            cacheManager: cacheManager,
            cacheKey: cacheKey,
          );

          // If the request failed, don't throw an exception, just don't load
          // the font instead.
          if (fontBytes == null) {
            return;
          }

          print('\t\tLoaded font bytes for [$fullFontName].');

          // Prime it using the FontLoader.
          final FontLoader fontLoader = FontLoader(fullFontName);
          fontLoader.addFont(Future.value(ByteData.view(fontBytes.buffer)));

          // Wait for the font to finish loading.
          await fontLoader.load();

          model.fonts[fullFontName] = font;

          print('\t\tSuccessfully Loaded font [$fullFontName].');
        } on CodelesslyException {
          rethrow;
        } catch (exception, stacktrace) {
          throw CodelesslyException.fontLoadException(
            message: 'Failed to load font [$fullFontName].',
            originalException: exception,
            stacktrace: stacktrace,
          );
        }
      }));
    }

    await Future.wait(futures);
  }

  /// Fetches the bytes of a font variant either from cache or from a get
  /// network request.
  ///
  /// If the font is not cached, it will be downloaded and saved to cache.
  ///
  /// If the font is cached, it will be loaded from cache.
  Future<Uint8List?> fetchFontBytes(
    String id,
    String url, {
    required CacheManager cacheManager,
    required String cacheKey,
  }) async {
    // Load bytes from file if the file is cached.
    if (await cacheManager.isFileCached(cacheKey, id)) {
      print('\t\tLoading font [$id] from cache.');
      return cacheManager.getFile(cacheKey, id);
    }
    // Otherwise, download the bytes from the url.
    else {
      print('\t\tDownloading font [$id] from url...');
      final Response response = await get(Uri.parse(url));

      // Convert the buffer to a Uint8List and save the new file to cache.
      if (response.statusCode == 200) {
        final Uint8List bytes = Uint8List.view(response.bodyBytes.buffer);
        await cacheManager.saveFile(cacheKey, id, bytes);

        return bytes;
      } else {
        // If the request failed, don't throw an exception, just don't load
        // the font instead.
        return null;
        // throw CodelesslyException.fontDownloadException(
        //   message: 'Failed to fetch font bytes from url [$url].'
        //       '\nStatus Code: ${response.statusCode}'
        //       '\nReason: ${response.reasonPhrase}',
        // );
      }
    }
  }
}
