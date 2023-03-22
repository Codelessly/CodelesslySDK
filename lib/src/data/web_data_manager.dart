import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart';

import '../../codelessly_sdk.dart';
import '../auth/auth_manager.dart';
import '../cache/cache_manager.dart';
import '../error/error_handler.dart';

/// Handles the data flow of [SDKPublishModel] from the server.
class WebDataManager extends DataManager {
  /// The passed config from the SDK.
  final CodelesslyConfig config;

  /// The auth manager instance to ensure that the user is authenticated before
  /// fetching the published model.
  final AuthManager authManager;

  /// The cache manager used to store the the published model and associated
  /// layouts and font files.
  final CacheManager cacheManager;

  /// Whether this data manager fetches data from the previews instead of the
  /// published collection.
  final bool isPreview;

  /// The key used to locate the publish model from firestore.
  final String publishPath;

  /// The key used to store & load the publish model from the cache.
  final String modelCacheKey;

  /// The key used to store & load the fonts for this publish model from
  /// the cache.
  final String fontsCacheKey;

  /// The stream controller that emits the current status of the data manager.
  /// This is used to notify [CodelesslyWidget]s when the data manager is ready
  /// to be used.
  final StreamController<DataManagerStatus> _statusStreamController;

  /// A stream controller that emits the latest publish model whenever it is
  /// updated.
  final StreamController<SDKPublishModel> _publishModelStreamController;

  /// Creates a new instance of [WebDataManager] with the given
  /// parameters.
  ///
  /// [config] is the configuration used to authenticate the token.
  ///
  /// [cacheManager] is the cache manager used to store the the published model
  ///                and associated layouts and font files.
  ///
  /// [authManager] is the auth manager instance to ensure that the user is
  ///               authenticated before fetching the published model.
  ///
  /// [isPreview] is a boolean that indicates whether the published model is
  ///             should be retrieved from the preview collection or the publish
  ///             collection. Caching is separated accordingly as well.
  WebDataManager({
    required this.config,
    required this.cacheManager,
    required this.authManager,
    required this.isPreview,
  })  : publishPath = isPreview ? 'publish_preview' : 'publish',
        modelCacheKey = isPreview ? previewModelCacheKey : publishModelCacheKey,
        fontsCacheKey = isPreview ? previewFontsCacheKey : publishFontsCacheKey,
        _statusStreamController =
            StreamController<DataManagerStatus>.broadcast(),
        _publishModelStreamController =
            StreamController<SDKPublishModel>.broadcast();

  @override
  Stream<DataManagerStatus> get statusStream => _statusStreamController.stream;

  /// The current loaded publish model.
  SDKPublishModel? _publishModel;

  @override
  SDKPublishModel? get publishModel => _publishModel;

  @override
  Stream<SDKPublishModel> get publishModelStream =>
      _publishModelStreamController.stream;

  @override
  Future<void> init() async {
    status = DataManagerStatus.initializing;
    _statusStreamController.add(status);

    if (!authManager.isAuthenticated()) {
      throw CodelesslyException.notAuthenticated();
    }

    final StreamController controller = _publishModelStreamController;

    // If the publish model is already cached, load it from cache.
    if (cacheManager.isCached(modelCacheKey)) {
      print('Publish model is cached. Loading from cache directly.');

      try {
        _publishModel = cacheManager.get<SDKPublishModel>(
          modelCacheKey,
          decode: SDKPublishModel.fromJson,
        );
      } on CodelesslyException catch (_) {
        print('Cache lookup failed, fetching from server directly...');
        cacheManager.delete(modelCacheKey);
        _publishModel = null;
      }

      print('Publish model loaded from cache.');
      print('Layout IDs: [${_publishModel?.layouts.keys.join(', ')}]');
    }

    // If the publish model is not cached, fetch it from the server and await
    // the entire process to complete before proceeding. We can't proceed
    // without a publish model.
    //
    // Store the publish model in cache after fetching it from the server.
    if (_publishModel == null) {
      print('Publish model is not cached. Fetching from server...');

      _publishModel = await downloadPublishModel();
      controller.add(_publishModel!);
      cacheManager.store(modelCacheKey, _publishModel!.toFullJson());

      // Load fonts in the background.
      loadFonts(
        model: _publishModel!,
        fonts: {..._publishModel!.fonts.values},
        cacheManager: cacheManager,
        cacheKey: fontsCacheKey,
      ).then((_) {
        // Notify again once font loading is done.
        controller.add(_publishModel!);
        cacheManager.store(modelCacheKey, _publishModel!.toFullJson());
      });

      print('Publish model fetched from server.');
    }

    // The model was cached, but we still need a fresh copy from the server.
    // Fetch it in the background instead.
    else {
      // This makes it so it runs in the background instead of blocking
      // initialization.
      Future(() async {
        try {
          final SDKPublishModel freshModel = await downloadPublishModel();
          // If the fresh model is different from the cached model, update the
          // cached model and emit the new model.
          if (freshModel != _publishModel) {
            _publishModel = freshModel;
            controller.add(_publishModel!);
            cacheManager.store(modelCacheKey, _publishModel!.toFullJson());
          }

          // Load fonts in the background.
          loadFonts(
            model: _publishModel!,
            fonts: {..._publishModel!.fonts.values},
            cacheManager: cacheManager,
            cacheKey: fontsCacheKey,
          ).then((_) {
            // Notify again once font loading is done.
            controller.add(_publishModel!);
            cacheManager.store(modelCacheKey, _publishModel!.toFullJson());
          });
        } on CodelesslyException catch (error) {
          print('Failed to fetch fresh publish model: $error');
        }
      });
    }

    status = DataManagerStatus.initialized;
    _statusStreamController.add(status);

    assert(
      _publishModel != null,
      'The publish model is null at this point, which means initialization '
      'failed without throwing a proper exception. Why?',
    );
  }

  @override
  void dispose() {
    _publishModelStreamController.close();
    _statusStreamController.close();
    status = DataManagerStatus.idle;
  }

  @override
  void invalidate() {
    _publishModel = null;
    status = DataManagerStatus.idle;
    _statusStreamController.add(status);
  }

  @override
  Future<SDKPublishModel> downloadPublishModel() async {
    if (!authManager.isAuthenticated()) {
      throw CodelesslyException.invalidAuthToken();
    }

    try {
      final Response result = await post(
        Uri.parse('$firebaseCloudFunctionsBaseURL/getPublishModel'),
        headers: <String, String>{
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'projectId': authManager.authData!.projectId,
          'environment': !isPreview ? 'prod' : 'dev'
        }),
      );

      if (result.statusCode != 200) {
        throw CodelesslyException.projectNotFound(
          message:
              'Failed to download layouts from project [${authManager.authData!.projectId}]\n${result.body}',
        );
      }

      final Map<String, dynamic> modelDoc = jsonDecode(result.body);
      final SDKPublishModel model = SDKPublishModel.fromJson(modelDoc);

      cacheManager.store(modelCacheKey, model.toFullJson());

      // Purge all the unused fonts from the cache.
      await cacheManager.purgeFiles(
        fontsCacheKey,
        excludedFileNames: {
          ...model.fonts.values.map((font) => font.fullFontName)
        },
      );
      return model;
    } on CodelesslyException {
      rethrow;
    } catch (error, str) {
      throw CodelesslyException.projectNotFound(
        message:
            'Failed to download layouts from project [${authManager.authData!.projectId}]\nError: $error',
        originalException:
            error is Exception ? error : Exception(error.toString()),
        stacktrace: str,
      );
    }
  }
}
