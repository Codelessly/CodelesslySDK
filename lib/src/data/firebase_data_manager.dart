import 'dart:async';

import '../../codelessly_sdk.dart';
import '../../firedart.dart';
import '../auth/auth_manager.dart';
import '../cache/cache_manager.dart';
import '../error/error_handler.dart';

/// Handles the data flow of [SDKPublishModel] from the server.
class FirebaseDataManager extends DataManager {
  /// The passed config from the SDK.
  final CodelesslyConfig config;

  /// The firestore instance to fetch the published model from.
  final Firestore firestore;

  /// The auth manager instance to ensure that the user is authenticated before
  /// fetching the published model.
  final AuthManager authManager;

  /// The cache manager used to store the the published model and associated
  /// layouts and font files.
  final CacheManager cacheManager;

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

  /// Creates a new instance of [FirebaseDataManager] with the given
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
  /// [firestore] is the firestore instance to fetch the published model from.
  ///             This is used to fetch the published model from the server.
  ///
  /// [isPreview] is a boolean that indicates whether the published model is
  ///             should be retrieved from the preview collection or the publish
  ///             collection. Caching is separated accordingly as well.
  FirebaseDataManager({
    required this.config,
    required this.cacheManager,
    required this.authManager,
    required this.firestore,
    required bool isPreview,
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

  /// A stream that listens to the publish model stream for changes and updates
  /// [_publishModel] whenever a new publish model is emitted.
  StreamSubscription<Document?>? publishModelUpdateStream;

  @override
  Future<void> init() async {
    status = DataManagerStatus.initializing;
    _statusStreamController.add(status);

    if (!authManager.isAuthenticated()) {
      throw CodelesslyException.notAuthenticated();
    }

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
      cacheManager.store(modelCacheKey, _publishModel!.toFullJson());

      print('Publish model fetched from server.');
    }

    assert(
      _publishModel != null,
      'The publish model is null at this point, which means initialization '
      'failed without throwing a proper exception. Why?',
    );

    _publishModelStreamController.add(_publishModel!);

    // Load fonts in the background.
    loadFonts(
      model: _publishModel!,
      fonts: {..._publishModel!.fonts.values},
      cacheManager: cacheManager,
      cacheKey: fontsCacheKey,
    ).then((_) {
      // Notify again once font loading is done.
      _publishModelStreamController.add(_publishModel!);
      cacheManager.store(modelCacheKey, _publishModel!.toFullJson());
    });

    status = DataManagerStatus.initialized;
    _statusStreamController.add(status);

    // Now that a publish model is definitely available, we can start listening
    // to the publish model stream for further updates in the background.
    _listenToPublishModelStream();
  }

  @override
  void dispose() {
    _publishModelStreamController.close();
    publishModelUpdateStream?.cancel();
    _statusStreamController.close();
    status = DataManagerStatus.idle;
  }

  @override
  void invalidate() {
    _publishModel = null;
    status = DataManagerStatus.idle;
    _statusStreamController.add(status);
  }

  /// Compares the current [_publishModel] with the newly fetched
  /// [updatedModel] and returns a map of layout ids and their corresponding
  /// update type.
  ///
  /// - If a layout did not exist in the previous model, it is marked for
  /// download.
  ///
  /// - If a layout exists in both models but has a newer time stamp, it is
  /// marked for download.
  ///
  /// - If a layout existed in the previous model, but was deleted in the
  /// updated model, it marked for deletion.
  Map<String, UpdateType> _collectLayoutUpdates({
    required SDKPublishModel updatedModel,
  }) {
    final Map<String, DateTime> updatedLayouts = updatedModel.updates.layouts;
    final Map<String, DateTime> lastLayouts = _publishModel!.updates.layouts;
    final Map<String, UpdateType> layoutUpdates = {};

    // Check for deleted layouts.
    for (final String layoutID in lastLayouts.keys) {
      if (!updatedLayouts.containsKey(layoutID)) {
        layoutUpdates[layoutID] = UpdateType.delete;
      }
    }

    // Check for added or updated layouts.
    for (final String layoutID in updatedLayouts.keys) {
      if (!lastLayouts.containsKey(layoutID)) {
        layoutUpdates[layoutID] = UpdateType.add;
      } else {
        final DateTime lastUpdated = lastLayouts[layoutID]!;
        final DateTime newlyUpdated = updatedLayouts[layoutID]!;
        if (newlyUpdated.isAfter(lastUpdated)) {
          layoutUpdates[layoutID] = UpdateType.update;
        }
      }
    }

    return layoutUpdates;
  }

  bool _doFontsNeedUpdate({
    required SDKPublishModel updatedModel,
  }) {
    final DateTime newlyUpdated = updatedModel.updates.fonts;
    final DateTime lastUpdated = _publishModel!.updates.fonts;
    return newlyUpdated.isAfter(lastUpdated);
  }

  /// The future is to ensure that the layout does exist on the server before
  /// listening to the stream.
  ///
  /// Listens to the SDKPublishModel document on Firestore. When a new update
  /// is triggered, we process the layout and font updates and then emit
  /// the updated model to the [_publishModelStreamController].
  Future<void> _listenToPublishModelStream() async {
    assert(
      _publishModel != null,
      'Publish model is null, initialization should have thrown an error and '
      'prevented this function from running. What happened?',
    );

    if (!authManager.isAuthenticated()) {
      throw CodelesslyException.notAuthenticated();
    }

    final DocumentReference publishModelDoc = firestore
        .collection(publishPath)
        .document(authManager.authData!.projectId);
    final bool doesExist = await publishModelDoc.exists;

    if (!doesExist) {
      throw CodelesslyException.projectNotFound(
        message:
            'Project with id [${authManager.authData!.projectId}] does not exist.',
      );
    }

    publishModelUpdateStream?.cancel();
    publishModelUpdateStream =
        publishModelDoc.stream.listen((Document? doc) async {
      if (!authManager.isAuthenticated()) {
        throw CodelesslyException.notAuthenticated();
      }

      try {
        if (doc == null) {
          throw CodelesslyException.projectNotFound(
            message:
                'Failed to get publish data from project [${authManager.authData!.projectId}]',
          );
        }
        print('Publish model update detected from stream!');
        SDKPublishModel updatedModel = SDKPublishModel.fromJson(doc.map);

        // Compare the old _publishModel with the new updatedModel to see
        // what kind of updates have been made to the layouts and fonts.
        final Map<String, UpdateType> layoutUpdates =
            _collectLayoutUpdates(updatedModel: updatedModel);
        final bool doFontsNeedUpdate =
            _doFontsNeedUpdate(updatedModel: updatedModel);

        if (layoutUpdates.isNotEmpty) {
          print('Found ${layoutUpdates.length} layout changes. ');
          print(
            'Updates: ${layoutUpdates.entries.map((entry) => '\n\t\t${entry.key}: ${entry.value.name}').join()}',
          );
        } else {
          print('No layout changes found.');
        }

        if (doFontsNeedUpdate) {
          print('Fonts need to be updated.');
        } else {
          print('No font changes found.');
        }

        // We don't want to use the updatedModel directly because it
        // contains a map of not-yet-loaded layouts and fonts, we copy over
        // the old layouts and fonts from the _publishModel and update
        // the layouts and fonts with the new ones in the next few steps.
        updatedModel = updatedModel.copyWith(
          layouts: _publishModel!.layouts,
          fonts: _publishModel!.fonts,
        );

        // Wait for layout updates to finish processing.
        if (layoutUpdates.isNotEmpty) {
          await _updateLayouts(
            model: updatedModel,
            layoutUpdates: layoutUpdates,
          );
        }

        // Same for fonts, wait for the updates to finish processing.
        if (doFontsNeedUpdate) {
          await fetchFonts(updatedModel);
          await loadFonts(
            model: _publishModel!,
            fonts: {..._publishModel!.fonts.values},
            cacheManager: cacheManager,
            cacheKey: fontsCacheKey,
          );
        }

        // Update the cache.
        cacheManager.store(modelCacheKey, updatedModel.toFullJson());
        print('Publish model updated from stream.');

        // Update the _publishModel.
        _publishModel = updatedModel;
        _publishModelStreamController.add(_publishModel!);
        print('Layout IDs: [${_publishModel?.layouts.keys.join(', ')}]');
      } catch (exception, stacktrace) {
        CodelesslyErrorHandler.instance.captureException(
          exception,
          stacktrace: stacktrace,
        );
        rethrow;
      }
    });
  }

  @override
  Future<SDKPublishModel> downloadPublishModel() async {
    if (!authManager.isAuthenticated()) {
      throw CodelesslyException.invalidAuthToken();
    }

    final DocumentReference publishModelDoc = firestore
        .collection(publishPath)
        .document(authManager.authData!.projectId);

    final bool doesExist = await publishModelDoc.exists;
    if (!doesExist) {
      throw CodelesslyException.projectNotFound(
        message:
            'Failed to get the publish data for project [${authManager.authData!.projectId}]',
      );
    }

    try {
      final Document modelDoc = await publishModelDoc.get();
      final SDKPublishModel model = SDKPublishModel.fromJson(modelDoc.map);

      await downloadAllLayouts(model);
      await fetchFonts(model);

      cacheManager.store(modelCacheKey, model.toFullJson());

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

  /// Downloads new and updated layouts, and deletes deleted layouts.
  ///
  /// Modifies the [model]'s layouts map directly.
  Future<void> _updateLayouts({
    required SDKPublishModel model,
    required Map<String, UpdateType> layoutUpdates,
  }) async {
    // Download layouts that are new or updated.
    await downloadLayouts(
      model: model,
      layoutIDs: layoutUpdates.entries
          .where((entry) => entry.value != UpdateType.delete)
          .map((entry) => entry.key)
          .toSet(),
    );

    // Delete layouts that are deleted.
    for (final String layoutID in layoutUpdates.keys) {
      if (layoutUpdates[layoutID] == UpdateType.delete) {
        model.layouts.remove(layoutID);
      }
    }
  }

  /// Downloads layouts with the given [layoutIDs].
  ///
  /// Modifies the [model]'s layouts map directly.
  Future<void> downloadLayouts({
    required SDKPublishModel model,
    required Set<String> layoutIDs,
  }) async {
    print('\tDownloading layouts: ${layoutIDs.join(', ')}');
    final Map<String, SDKPublishLayout> layouts = {};

    final CollectionReference layoutsCollection = firestore
        .collection(publishPath)
        .document(authManager.authData!.projectId)
        .collection('layouts');

    for (final String layoutID in layoutIDs) {
      try {
        final DocumentReference layoutDoc =
            layoutsCollection.document(layoutID);
        final Document layoutDocSnapshot = await layoutDoc.get();
        final SDKPublishLayout layout = SDKPublishLayout.fromJson(
            {...layoutDocSnapshot.map, 'id': layoutID});
        layouts[layoutID] = layout;

        print('\tDownloaded layout: $layoutID');
      } on CodelesslyException {
        rethrow;
      } catch (error, str) {
        throw CodelesslyException.layoutNotFound(
          layoutID: layoutID,
          message:
              'Failed to download layout [$layoutID] from project [${authManager.authData!.projectId}]\nError: $error',
          originalException:
              error is Exception ? error : Exception(error.toString()),
          stacktrace: str,
        );
      }
    }

    model.layouts.addAll(layouts);
    print('\tDownloaded ${layouts.length} layouts.');
  }

  /// Gets the full list of layouts from firestore and loads them one by one.
  /// Once loading is done:
  ///   - The [model] is updated with the list of layouts,
  Future<void> downloadAllLayouts(SDKPublishModel model) async {
    print('Downloading layouts...');
    final CollectionReference publishedLayoutsCollection = firestore
        .collection(publishPath)
        .document(authManager.authData!.projectId)
        .collection('layouts');

    // TODO: Use a cloud function to access layouts.
    // TODO: Should we be loading all layouts? Or just the one we need?
    final Map<String, SDKPublishLayout> layouts = {};

    try {
      final Page<Document> docs = await publishedLayoutsCollection.get();
      for (final Document doc in docs) {
        final SDKPublishLayout layout =
            SDKPublishLayout.fromJson({...doc.map, 'id': doc.id});
        layouts[layout.id] = layout;
      }
    } on CodelesslyException {
      rethrow;
    } catch (error, str) {
      throw CodelesslyException.layoutNotFound(
        message:
            'Failed to download layouts from project [${authManager.authData!.projectId}]\nError: $error',
        originalException:
            error is Exception ? error : Exception(error.toString()),
        stacktrace: str,
      );
    }

    model.layouts.addAll(layouts);
    print('Downloaded ${layouts.length} layouts.');
    print(layouts.keys.join(', '));
  }

  /// Gets the full list of fonts from firestore and loads them all.
  /// Updates the publish model's fonts map with the new fonts.
  /// Purges all fonts that are no longer in the list from cache.
  Future<void> fetchFonts(SDKPublishModel model) async {
    print('Loading fonts...');
    final CollectionReference uploadedFontsCollection = firestore
        .collection(publishPath)
        .document(authManager.authData!.projectId)
        .collection('fonts');

    // TODO: Use a cloud function to access fonts
    // TODO: Should we be loading all layouts? Or just the one we need?
    final Map<String, SDKPublishFont> fonts = {};
    try {
      final Page<Document> docs = await uploadedFontsCollection.get();
      for (final Document doc in docs) {
        final SDKPublishFont font =
            SDKPublishFont.fromJson({...doc.map, 'id': doc.id});
        fonts[font.id] = font;
      }
    } on CodelesslyException {
      rethrow;
    } catch (error, str) {
      throw CodelesslyException.fontLoadException(
        message:
            'Failed to download fonts for project [${authManager.authData!.projectId}]',
        originalException: error,
        stacktrace: str,
      );
    }

    model.fonts.addAll(fonts);

    print('Downloaded ${fonts.length} fonts.');

    // Purge all the unused fonts from the cache.
    cacheManager.purgeFiles(
      fontsCacheKey,
      excludedFileNames: {
        ...model.fonts.values.map((font) => font.fullFontName)
      },
    );
  }
}
