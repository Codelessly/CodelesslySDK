import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';

import '../../codelessly_sdk.dart';

/// Orchestrates the data flow for the SDK.
class DataManager {
  /// Determines whether the data manager has been initialized at least once.
  ///
  /// This is used to inform systems that rely on the data manager that it might
  /// not need to be initialized again.
  CStatus status = CStatus.empty();

  /// This is set to true once the while loop that processes the
  /// [_downloadQueue] finishes processing in the initialization of this
  /// [DataManager].
  ///
  /// Queuing is ignored after this is set to true.
  bool queuingDone = false;

  /// A unique identifier of this data manager instance.
  final String debugLabel;

  String get logLabel => '$debugLabel Data Manager';

  /// The passed config from the SDK.
  final CodelesslyConfig config;

  /// The network data repository to use. By default, it is going to be
  /// [FirebaseDataRepository].
  final NetworkDataRepository networkDataRepository;

  /// The local data repository to use. By default, it is going to be
  /// [LocalDataRepository] which uses [cacheManager] to abstract away data
  /// manager specific caching.
  final LocalDataRepository localDataRepository;

  /// The cache manager to use. By default, it is [CodelesslyCacheManager]
  /// which uses Hive.
  final CacheManager cacheManager;

  /// The auth manager to use. By default, it is [CodelesslyAuthManager].
  final AuthManager authManager;

  /// The firestore instance to use.
  final FirebaseFirestore firebaseFirestore;

  /// The error handler to use.
  final CodelesslyErrorHandler errorHandler;

  SDKPublishModel? _publishModel;

  LocalDatabase? _localDatabase;

  CloudDatabase? _cloudDatabase;

  /// The local storage instance used by this data manager.
  LocalDatabase get localDatabase {
    assert(_localDatabase != null, 'Local storage is not initialized yet.');
    return _localDatabase!;
  }

  /// The cloud storage instance used by this data manager.
  /// If it is null, it means it has not yet been initialized.
  CloudDatabase? get cloudDatabase => _cloudDatabase;

  /// The current publish model loaded by this data manager.
  SDKPublishModel? get publishModel => _publishModel;

  final StreamController<SDKPublishModel?> _publishModelStreamController =
      StreamController<SDKPublishModel?>.broadcast();

  /// The stream of the current publish model loaded by this data manager.
  ///
  /// This stream will emit whenever new publish model information is received.
  Stream<SDKPublishModel?> get publishModelStream =>
      _publishModelStreamController.stream;

  StreamSubscription<SDKPublishModel?>? _publishModelDocumentListener;

  /// The download queue holds the list of layout IDs that need to be
  /// downloaded in order. Tracking this as an external queue allows
  /// us to interrupt and inject different layouts to prioritize when needed.
  ///
  /// Use Case: Config preloading is set to true, but a CodelesslyWidget got
  /// rendered on the screen with a layoutID specified before preload could
  /// finish its queue.
  /// We inject the layoutID at the start of this queue to prioritize it.
  final List<String> _downloadQueue = [];

  /// Creates a new instance of with the given [config].
  DataManager(
    this.debugLabel, {
    required this.config,
    required this.cacheManager,
    required this.authManager,
    required this.networkDataRepository,
    required this.localDataRepository,
    required this.firebaseFirestore,
    required this.errorHandler,
    SDKPublishModel? publishModel,
  }) : _publishModel = publishModel;

  void log(
    String message, {
    bool largePrint = false,
  }) =>
      logger.log(
        logLabel,
        message,
        largePrint: largePrint,
      );

  void logError(
    String message, {
    required Object? error,
    required StackTrace? stackTrace,
  }) =>
      logger.error(
        logLabel,
        message,
        error: error,
        stackTrace: stackTrace,
      );

  /// Initializes the instance.
  ///
  /// If a [layoutID] is specified, that layout will be downloaded from the
  /// server first, then the rest of the layouts will be streamed passively
  /// in the background.
  ///
  /// If a [layoutID] is null, all layouts will be downloaded immediately and
  /// awaited.
  Future<void> init({required String? layoutID}) async {
    assert(
      layoutID != null || config.preload || config.slug != null,
      'If [layoutID] is null, [config.preload] must be true. If both are not '
      'specified, then a slug must be provided in the config.',
    );

    final Stopwatch stopwatch = Stopwatch()..start();

    status = CStatus.loading(CLoadingState.initializedDataManagers);

    queuingDone = false;

    // Initialize all locally cached data.
    final SDKPublishModel? cachedModel = localDataRepository.fetchPublishModel(
      source: config.publishSource,
    );

    _publishModel ??= cachedModel;

    if (_publishModel != null) {
      log('Publish model is cached locally. Emitting.');
      await emitPublishModel();

      loadFontsFromPublishModel();
    } else {
      log('Publish model is not cached locally. Proceeding with init...');
    }

    // A slug was specified. We need a layout, fast.
    // No authentication is required; download a complete publish bundle.
    if (config.slug case String slug) {
      log('[slug] Slug was specified [$slug]. Going through slug flow...');

      final Stopwatch bundleStopWatch = Stopwatch()..start();

      log('[slug] Downloading complete publish bundle for slug $slug.');

      if (_publishModel == null) {
        log('[slug] Publish model is not cached locally. Downloading complete publish bundle for slug $slug in foreground.');
      } else {
        log('[slug] Publish model is already cached locally. Downloading complete publish bundle for slug $slug in background.');
      }

      final Future<bool> publishBundleFuture = fetchCompletePublishBundle(
        slug: slug,
        source: config.publishSource,
      ).then((bool success) {
        if (success) {
          log('[slug] Complete publish model from slug is downloaded in background. Emitting.');
          log('[slug] Loading fonts from publish model.');
          loadFontsFromPublishModel();
        } else {
          // If the download failed, we need to show an error message to the
          // client. The only reasons this is allowed to fail is either
          // network issues or a slug that doesn't exist.
          //
          // Either way, no need to stop the data manager, as it can still
          // function offline and wait for the next publish model to arrive.
          log('[slug] Failed to download complete publish bundle for slug $slug.');
        }

        _logTime(bundleStopWatch);
        return success;
      });

      // If the publish model is null, we need to wait for the first publish
      // bundle to arrive from the server instead of waiting for it in
      // the background.
      if (_publishModel == null) {
        await publishBundleFuture;
      }
    } else {
      log('[slug] No slug specified. Skipping slug flow.');
    }

    if (authManager.authData == null) {
      log('No auth data is available. Discontinuing as if offline.');
      _logTime(stopwatch);
      return;
    }

    final AuthData authData = authManager.authData!;

    // If a [layoutID] is not null, then that layout must be prioritized and
    // downloaded first if it is not already cached.
    //
    // If the publish model is still null, then that needs to be downloaded
    // first, and we do that by getting the first event of the stream below.
    //
    // Once a publish model is available in the future, if a [layoutID] is
    // specified, we try to download that layout then instead of here.
    bool didPrepareLayout = false;
    if (_publishModel != null && layoutID != null) {
      if (!_publishModel!.layouts.containsKey(layoutID)) {
        log('Layout [$layoutID] during init is not cached locally. Downloading...');

        try {
          didPrepareLayout = await getOrFetchPopulatedLayout(
            layoutID: layoutID,
          );
        } on CodelesslyException catch (e, str) {
          errorHandler.captureException(e, trace: str);
        } catch (e, str) {
          final exception = CodelesslyException.layout(
            ErrorType.layoutFailed,
            message: 'Failed to download layout [$layoutID] during init.',
            originalException: e,
            layoutID: layoutID,
          );
          errorHandler.captureException(exception, trace: str);
        }
        log('Layout in init [$layoutID] fetch complete.');
      } else {
        log('Layout [$layoutID] during init is already cached locally. Skipping layout download.');
        didPrepareLayout = true;
      }
    } else {
      if (_publishModel == null) {
        log('Publish model during init is not cached locally. Going to wait for the first publish model from the server.');
      } else if (layoutID == null) {
        log('Publish model during init is available and layoutID is not specified. All layouts will be downloaded soon!');
      } else {
        log('Publish model during init is available and layoutID is specified. Layout [$layoutID] will be downloaded soon from stream.');
      }
      didPrepareLayout = false;
    }

    // Listen the publish model document.
    // It's either going to be fetched for the first time if it doesn't exist
    // in cache, or it's going to be updated with new data.
    log('Listening to publish model doc...');
    final Future<SDKPublishModel> firstPublishEvent =
        listenToPublishModel(authData.projectId);

    // If the publish model is still null, then we need to wait for the first
    // publish model to arrive from the server via the stream above.
    if (_publishModel == null || !didPrepareLayout) {
      log('Publish model is still null during init. Waiting for the first publish model from the server.');
      final model = await firstPublishEvent;
      _publishModel = model;
      await emitPublishModel();
      savePublishModel();

      log('Publish model during init is now available. Proceeding with init!');

      if (_publishModel == null) {
        log(
          'Publish model is still null.\n'
          'Is there a network problem or bad authentication?',
        );
        _logTime(stopwatch);
        return;
      }
    }

    // If a [layoutID] was specified, then that layout must be prioritized and
    // downloaded first if it is not already cached.
    //
    // If we could not download it earlier, that would be because we did not
    // have a publish model available and needed to wait for one to arrive
    // from the server for the first time or that it failed to download for
    // some reason, like the cached layout ID map in the SDKPublishModel being
    // out of date and requiring an update in the following steps to mapped
    // the provided layoutID into a layoutID that can be downloaded.
    //
    // At this stage of the function, we can be sure that a publish model
    // exists and can safely download the desired [layoutID], even if it's the
    // second time, because if a publish model is still null, we cannot proceed
    // further and this function terminates earlier.
    if (!didPrepareLayout && layoutID != null) {
      log('Safely downloading layout [$layoutID] now.');
      try {
        await getOrFetchPopulatedLayout(layoutID: layoutID);
        log('Layout [$layoutID] downloaded from init successfully.');
      } on CodelesslyException catch (e, str) {
        errorHandler.captureException(e, trace: str);
      } catch (e, str) {
        final exception = CodelesslyException.layout(
          ErrorType.layoutFailed,
          message: 'Failed to download layout [$layoutID] during init.',
          originalException: e,
          layoutID: layoutID,
        );

        errorHandler.captureException(exception, trace: str);
      }
    }

    // Add all the layouts to the download queue excluding the [layoutID] if
    // that was specified. We don't want to download that layout twice.
    if (config.preload) {
      log('Config preload was specified during init, adding ${_publishModel!.updates.layouts.length - 1} layouts to the download queue...');
      _downloadQueue.addAll(
        [..._publishModel!.updates.layouts.keys]..remove(layoutID),
      );
      log('All layouts during init download complete. ${_downloadQueue.length} layouts in queue.');
    }

    // If a [layoutID] was specified for this initialization, then the Future
    // callback of this init function must complete once the layout has been
    // downloaded.
    // Otherwise we need to await for all layouts to be downloaded before
    // completing the Future.
    if (layoutID != null) {
      log('Layout [$layoutID] was specified during init. Processing download queue in the background...');
      processDownloadQueue();
    } else {
      log('No layout was specified during init. Awaiting all layouts to be downloaded...');
      await processDownloadQueue();
    }

    _logTime(stopwatch);
  }

  Future<void> processDownloadQueue() async {
    while (_downloadQueue.isNotEmpty) {
      final String layoutID = _downloadQueue.removeAt(0);
      log('\tDownloading layout [$layoutID] in download queue...');
      try {
        await getOrFetchPopulatedLayout(layoutID: layoutID);

        log('\tLayout [$layoutID] downloaded from download queue complete.');
      } on CodelesslyException catch (e, str) {
        errorHandler.captureException(e, trace: str);
      } catch (e, str) {
        log('\tLayout [$layoutID] failed to download in download queue.');
        final exception = CodelesslyException.layout(
          ErrorType.layoutFailed,
          message:
              'Failed to download layout [$layoutID] during download queue.',
          originalException: e,
          layoutID: layoutID,
        );
        errorHandler.captureException(exception, trace: str);
      }
    }

    log('Download queue is now empty. All layouts during init have been downloaded.');
    queuingDone = true;
  }

  /// Called when the publish model is loaded.
  Future<bool> onPublishModelLoaded(String projectId) async {
    bool didChange = false;

    final bool shouldInitLocalStorage =
        _localDatabase == null || (_localDatabase!.identifier != projectId);

    if (shouldInitLocalStorage) {
      log('Initializing local storage for project $projectId...');
      _localDatabase?.reset();
      _localDatabase = await initializeLocalStorage(projectId: projectId);
      didChange = true;
      log('Local storage initialized.');
    } else {
      log('Local storage already initialized correctly. Skipping.');
    }

    final bool shouldInitCloudStorage = _cloudDatabase == null ||
        (cloudDatabase!.publishSource != config.publishSource ||
            cloudDatabase!.identifier != projectId);
    bool isAuthenticated = false;
    if (shouldInitCloudStorage) {
      isAuthenticated = authManager.isAuthenticated() &&
          authManager.hasCloudStorageAccess(projectId);
    }
    if (shouldInitCloudStorage && isAuthenticated) {
      log('Initializing cloud storage for project $projectId...');
      _cloudDatabase?.reset();
      _cloudDatabase = await initializeCloudStorage(projectId: projectId);
      _publishModelStreamController.add(_publishModel);
      didChange = true;
      log('Cloud storage initialized.');
    } else {
      if (shouldInitCloudStorage) {
        log('Cloud storage cannot be initialized because the user is not authenticated.');
      } else {
        log('Cloud storage already initialized correctly. Skipping.');
      }
    }

    return didChange;
  }

  Future<LocalDatabase> initializeLocalStorage(
      {required String projectId}) async {
    final Box box = await Hive.openBox(projectId);
    return HiveLocalDatabase(box, identifier: projectId);
  }

  Future<CloudDatabase> initializeCloudStorage(
      {required String projectId}) async {
    final instance = FirestoreCloudDatabase(
      projectId,
      firebaseFirestore,
      config.publishSource,
    );
    // initialize cloud storage.
    await instance.init();
    return instance;
  }

  /// This function serves to complete any post initialization steps like
  /// indicating that queuing is done and logging the time it took to
  /// initialize.
  void _logTime(Stopwatch stopwatch) {
    stopwatch.stop();
    log(
      'Initialization took ${stopwatch.elapsedMilliseconds}ms or ${stopwatch.elapsed.inSeconds}s.',
    );
  }

  /// Will consume all of the [SDKFontModel]s loaded in the [_publishModel]
  /// and either load them into the Flutter SDK or download them then load them.
  void loadFontsFromPublishModel() {
    assert(_publishModel != null, 'Publish model cannot be null here.');

    log('About to load all fonts that are present in the current publish model.');
    if (_publishModel!.fonts.isNotEmpty) {
      log('Fonts: ${_publishModel!.fonts.values.map((font) => font.fullFontName).join(', ')}');
    } else {
      log('No fonts to load.');
    }

    for (final SDKPublishFont font in _publishModel!.fonts.values) {
      getOrFetchFontBytesAndSaveAndLoad(font);
    }
  }

  /// Listen the publish model document.
  /// It's either going to be fetched for the first time if it doesn't exist
  /// in cache, or it's going to be updated with new data.
  ///
  /// [returns] the first publish model event from the stream & will continue
  /// to listen to the stream for future publish model events.
  Future<SDKPublishModel> listenToPublishModel(String projectId) async {
    log('About to listen to publish model doc.');
    final Completer<SDKPublishModel> completer = Completer();
    _publishModelDocumentListener?.cancel();

    _publishModelDocumentListener = networkDataRepository
        .streamPublishModel(
      projectID: projectId,
      source: config.publishSource,
    )
        .listen(
      (SDKPublishModel? serverModel) {
        if (serverModel == null) return;

        log('Publish model stream event received.');

        final bool isFirstEvent = !completer.isCompleted;

        // If the completer has not completed yet, it needs to be
        // completed with the first available publish model form the server.
        if (isFirstEvent) {
          log(
            'Completing publish model stream completer since this is the first event.',
          );
          completer.complete(serverModel);
        }

        // If the publish model is null, meaning no publish model was previously
        // cached, then this is the first available publish model we have that
        // just arrived from the server.
        //
        // We can skip publish model comparison as there is nothing to compare
        // to yet.
        //
        // Since it is null, it will be hydrated with a value outside of this
        // listener when the completer completes. The publish model is emitted
        // once that happens, therefore we don't need to emit it here, nor
        // compare.
        if (_publishModel == null) {
          log(
            'Publish model is null during init and received the first publish model from the server. Skipping comparison in stream.',
          );
          return;
        }

        if (config.slug != null) {
          log('Initialized using the slug, this event is not essential for initial loading.');
        } else if (isFirstEvent) {
          log('Publish model during init was not null, and we received a new publish model from the server. Comparing...');
        } else {
          log('Received a second publish model from the server. Comparing...');
        }
        final SDKPublishModel localModel = _publishModel!;

        // Comparison should always be a background process.
        processPublishDifference(
          serverModel: serverModel,
          localModel: localModel,
        );

        log('Publish model comparison complete.');
      },
      onError: (error, str) {
        errorHandler.captureException(error, trace: str);
      },
    );

    return completer.future;
  }

  /// Emits the current [_publishModel] to the [_publishModelStreamController].
  Future<void> emitPublishModel() async {
    await onPublishModelLoaded(_publishModel!.projectId);

    log('Emitting publish model to stream. has model: ${_publishModel != null}');
    status = CStatus.loaded();
    _publishModelStreamController.add(_publishModel);
  }

  /// Saves the current [_publishModel] if it is not null to the local cache
  /// using [localDataRepository].
  void savePublishModel() {
    if (_publishModel != null) {
      localDataRepository.savePublishModel(
        model: _publishModel!,
        source: config.publishSource,
      );
    }
  }

  /// Saves the provided [fontBytes] with the [SDKPublishFont.id] from [font]
  /// as the storage key.
  void saveFontBytes(SDKPublishFont font, Uint8List fontBytes) {
    localDataRepository.saveFontBytes(
      fontID: font.id,
      bytes: fontBytes,
      source: config.publishSource,
    );
  }

  /// Disposes the instance.
  void dispose() {
    log('Disposing...');
    _publishModelStreamController.close();
    _publishModelDocumentListener?.cancel();
    status = CStatus.empty();
    _publishModel = null;
    _localDatabase?.dispose();
    _localDatabase = null;
    _cloudDatabase?.dispose();
    _cloudDatabase = null;
  }

  /// Sets the [SDKPublishModel] as null and cancels document streaming.
  void reset() {
    log('Invalidating...');
    _publishModelDocumentListener?.cancel();
    _publishModelStreamController.add(null);
    _publishModel = null;
    _localDatabase?.dispose();
    _localDatabase = null;
    _cloudDatabase?.dispose();
    _cloudDatabase = null;
    status = CStatus.empty();
  }

  /// Takes a [serverModel], and [localModel] and compares them
  /// to determine what changed on the server.
  /// The changes are then processed and downloaded if necessary.
  ///
  /// Changes get reflected into the [_publishModel] and saved to the local
  /// cache.
  Future<void> processPublishDifference({
    required SDKPublishModel serverModel,
    required SDKPublishModel localModel,
  }) async {
    final Map<String, UpdateType> layoutUpdates = _collectLayoutUpdates(
      serverModel: serverModel,
      localModel: localModel,
    );
    final Map<String, UpdateType> fontUpdates = _collectFontUpdates(
      serverModel: serverModel,
      localModel: localModel,
    );
    final Map<String, UpdateType> apiUpdates = _collectApiUpdates(
      serverModel: serverModel,
      localModel: localModel,
    );

    final Map<String, UpdateType> variableUpdates = _collectVariableUpdates(
      serverModel: serverModel,
      localModel: localModel,
    );

    final Map<String, UpdateType> conditionUpdates = _collectConditionUpdates(
      serverModel: serverModel,
      localModel: localModel,
    );

    final bool templateChanged = config.publishSource.isTemplate;

    final bool entryChanged =
        localModel.entryLayoutId != serverModel.entryLayoutId ||
            localModel.entryCanvasId != serverModel.entryCanvasId ||
            localModel.entryPageId != serverModel.entryPageId;

    final bool didLayoutIDMapChange = !(const MapEquality().equals(
      localModel.layoutIDMap,
      serverModel.layoutIDMap,
    ));
    if (didLayoutIDMapChange) {
      localModel = localModel.copyWith(layoutIDMap: serverModel.layoutIDMap);
      log('Layout ID map changed. Updating...');
    }

    final bool disabledLayoutsChanged = !(const ListEquality()
        .equals(localModel.disabledLayouts, serverModel.disabledLayouts));
    if (disabledLayoutsChanged) {
      localModel =
          localModel.copyWith(disabledLayouts: serverModel.disabledLayouts);
      log('Disabled layouts changed. Updating...');
    }

    if (layoutUpdates.isEmpty &&
        fontUpdates.isEmpty &&
        apiUpdates.isEmpty &&
        variableUpdates.isEmpty &&
        conditionUpdates.isEmpty &&
        !templateChanged &&
        !entryChanged &&
        !didLayoutIDMapChange &&
        !disabledLayoutsChanged) {
      log('No updates to process.');
      return;
    } else {
      log('Processing updates:');
      log('      | ${layoutUpdates.length} layout updates.');
      log('      | ${fontUpdates.length} font updates.');
      log('      | ${apiUpdates.length} api updates.');
      log('      | ${variableUpdates.length} variable updates.');
      log('      | ${conditionUpdates.length} condition updates.');
      log('      | ${templateChanged ? 1 : 0} template update${templateChanged ? '' : 's'}.');
      log('      | ${entryChanged ? 1 : 0} entry id update${entryChanged ? '' : 's'}.');
      log('      | ${didLayoutIDMapChange ? 'Layout ID map changed.' : 'No layout ID map changes.'}');
      log('      | ${disabledLayoutsChanged ? 'Disabled layout IDs changed.' : 'No disabled layout IDs changed.'}');
    }

    for (final String layoutID in layoutUpdates.keys) {
      final UpdateType updateType = layoutUpdates[layoutID]!;

      switch (updateType) {
        case UpdateType.delete:
          localModel.layouts.remove(layoutID);
          localDataRepository.deletePublishLayout(
            layoutID: layoutID,
            source: config.publishSource,
          );
        case UpdateType.add:
        case UpdateType.update:
          final SDKPublishLayout? layout =
              await networkDataRepository.downloadLayoutModel(
            projectID: authManager.authData!.projectId,
            layoutID: layoutID,
            source: config.publishSource,
          );
          if (layout != null) {
            localModel.layouts[layoutID] = layout;
          }
      }
    }

    for (final String fontID in fontUpdates.keys) {
      final UpdateType updateType = fontUpdates[fontID]!;

      switch (updateType) {
        case UpdateType.delete:
          localModel.fonts.remove(fontID);
          localDataRepository.deleteFontBytes(
            fontID: fontID,
            source: config.publishSource,
          );
        case UpdateType.add:
        case UpdateType.update:
          final SDKPublishFont? font =
              await networkDataRepository.downloadFontModel(
            projectID: authManager.authData!.projectId,
            fontID: fontID,
            source: config.publishSource,
          );

          if (font != null) {
            localModel.fonts[fontID] = font;
            getOrFetchFontBytesAndSaveAndLoad(font);
          }
      }
    }

    for (final String apiId in apiUpdates.keys) {
      final UpdateType updateType = apiUpdates[apiId]!;

      switch (updateType) {
        case UpdateType.delete:
          localModel.apis.remove(apiId);
          localDataRepository.deletePublishApi(
            apiId: apiId,
            source: config.publishSource,
          );
        case UpdateType.add:
        case UpdateType.update:
          final HttpApiData? api = await networkDataRepository.downloadApi(
            projectID: authManager.authData!.projectId,
            apiId: apiId,
            source: config.publishSource,
          );
          if (api != null) {
            localModel.apis[apiId] = api;
          }
      }
    }

    for (final String layoutId in variableUpdates.keys) {
      final UpdateType updateType = variableUpdates[layoutId]!;

      switch (updateType) {
        case UpdateType.delete:
          localModel.variables.remove(layoutId);
          localDataRepository.deletePublishVariables(
            layoutID: layoutId,
            source: config.publishSource,
          );
        case UpdateType.add:
        case UpdateType.update:
          final SDKLayoutVariables? layoutVariables =
              await networkDataRepository.downloadLayoutVariables(
            projectID: authManager.authData!.projectId,
            layoutID: layoutId,
            source: config.publishSource,
          );
          if (layoutVariables != null) {
            localModel.variables[layoutId] = layoutVariables;
          }
      }
    }

    for (final String layoutID in conditionUpdates.keys) {
      final UpdateType updateType = conditionUpdates[layoutID]!;

      switch (updateType) {
        case UpdateType.delete:
          localModel.variables.remove(layoutID);
          localDataRepository.deletePublishConditions(
            layoutID: layoutID,
            source: config.publishSource,
          );
        case UpdateType.add:
        case UpdateType.update:
          final SDKLayoutConditions? layoutConditions =
              await networkDataRepository.downloadLayoutConditions(
            projectID: authManager.authData!.projectId,
            layoutID: layoutID,
            source: config.publishSource,
          );
          if (layoutConditions != null) {
            localModel.conditions[layoutID] = layoutConditions;
          }
      }
    }

    _publishModel = localModel.copyWith(
      updates: serverModel.updates,
      entryPageId: serverModel.entryPageId,
      entryCanvasId: serverModel.entryCanvasId,
      entryLayoutId: serverModel.entryLayoutId,
      layoutIDMap: serverModel.layoutIDMap,
    );

    if (templateChanged) {
      _publishModel = publishModel?.copyWith();
    }

    await emitPublishModel();
    savePublishModel();
  }

  /// Compares the current [localModel] with a newly fetched [serverModel] and
  /// returns a map of layout ids and their corresponding update types.
  ///
  /// - If a layout did not exist in the previous model, it is marked as new.
  ///
  /// - If a layout exists in both models but has a newer time stamp, it is
  /// marked as updated.
  ///
  /// - If a layout existed in the previous model, but was deleted in the
  /// updated model, it is marked as deleted.
  Map<String, UpdateType> _collectLayoutUpdates({
    required SDKPublishModel serverModel,
    required SDKPublishModel localModel,
  }) {
    final Map<String, DateTime> serverLayouts = serverModel.updates.layouts;
    final Map<String, DateTime> currentLayouts = localModel.updates.layouts;
    final Map<String, UpdateType> layoutUpdates = {};

    // Check for deleted layouts.
    for (final String layoutID in currentLayouts.keys) {
      if (!serverLayouts.containsKey(layoutID)) {
        layoutUpdates[layoutID] = UpdateType.delete;
      }
    }

    // Check for added or updated layouts.
    for (final String layoutID in serverLayouts.keys) {
      if (!currentLayouts.containsKey(layoutID)) {
        layoutUpdates[layoutID] = UpdateType.add;
      } else {
        final DateTime lastUpdated = currentLayouts[layoutID]!;
        final DateTime newlyUpdated = serverLayouts[layoutID]!;
        if (newlyUpdated.isAfter(lastUpdated)) {
          layoutUpdates[layoutID] = UpdateType.update;
        }
      }
    }

    return layoutUpdates;
  }

  Map<String, UpdateType> _collectFontUpdates({
    required SDKPublishModel serverModel,
    required SDKPublishModel localModel,
  }) {
    final Map<String, DateTime> serverFonts = serverModel.updates.fonts;
    final Map<String, DateTime> currentFonts = localModel.updates.fonts;
    final Map<String, UpdateType> fontUpdates = {};

    // Check for deleted fonts.
    for (final String fontID in currentFonts.keys) {
      if (!serverFonts.containsKey(fontID)) {
        fontUpdates[fontID] = UpdateType.delete;
      }
    }

    // Check for added or updated fonts.
    for (final String fontID in serverFonts.keys) {
      if (!currentFonts.containsKey(fontID)) {
        fontUpdates[fontID] = UpdateType.add;
      } else {
        final DateTime lastUpdated = currentFonts[fontID]!;
        final DateTime newlyUpdated = serverFonts[fontID]!;
        if (newlyUpdated.isAfter(lastUpdated)) {
          fontUpdates[fontID] = UpdateType.update;
        }
      }
    }

    return fontUpdates;
  }

  Map<String, UpdateType> _collectApiUpdates({
    required SDKPublishModel serverModel,
    required SDKPublishModel localModel,
  }) {
    final Map<String, DateTime> serverApis = serverModel.updates.apis;
    final Map<String, DateTime> currentApis = localModel.updates.apis;
    final Map<String, UpdateType> apiUpdates = {};

    // Check for deleted layouts.
    for (final String apiId in currentApis.keys) {
      if (!serverApis.containsKey(apiId)) {
        apiUpdates[apiId] = UpdateType.delete;
      }
    }

    // Check for added or updated layouts.
    for (final String apiId in serverApis.keys) {
      if (!currentApis.containsKey(apiId)) {
        apiUpdates[apiId] = UpdateType.add;
      } else {
        final DateTime lastUpdated = currentApis[apiId]!;
        final DateTime newlyUpdated = serverApis[apiId]!;
        if (newlyUpdated.isAfter(lastUpdated)) {
          apiUpdates[apiId] = UpdateType.update;
        }
      }
    }

    return apiUpdates;
  }

  Map<String, UpdateType> _collectVariableUpdates({
    required SDKPublishModel serverModel,
    required SDKPublishModel localModel,
  }) {
    final Map<String, DateTime> serverVariables = serverModel.updates.variables;
    final Map<String, DateTime> currentVariables = localModel.updates.variables;
    final Map<String, UpdateType> variableUpdates = {};

    // Check for deleted layouts.
    for (final String layoutID in currentVariables.keys) {
      if (!serverVariables.containsKey(layoutID)) {
        variableUpdates[layoutID] = UpdateType.delete;
      }
    }

    // Check for added or updated layouts.

    for (final String layoutID in serverVariables.keys) {
      if (!currentVariables.containsKey(layoutID)) {
        variableUpdates[layoutID] = UpdateType.add;
      } else {
        final DateTime lastUpdated = currentVariables[layoutID]!;
        final DateTime newlyUpdated = serverVariables[layoutID]!;
        if (newlyUpdated.isAfter(lastUpdated)) {
          variableUpdates[layoutID] = UpdateType.update;
        }
      }
    }

    return variableUpdates;
  }

  Map<String, UpdateType> _collectConditionUpdates({
    required SDKPublishModel serverModel,
    required SDKPublishModel localModel,
  }) {
    final Map<String, DateTime> serverConditions =
        serverModel.updates.conditions;
    final Map<String, DateTime> currentConditions =
        localModel.updates.conditions;
    final Map<String, UpdateType> conditionUpdates = {};

    // Check for deleted layouts.
    for (final String layoutID in currentConditions.keys) {
      if (!serverConditions.containsKey(layoutID)) {
        conditionUpdates[layoutID] = UpdateType.delete;
      }
    }

    // Check for added or updated layouts.
    for (final String layoutID in serverConditions.keys) {
      if (!currentConditions.containsKey(layoutID)) {
        conditionUpdates[layoutID] = UpdateType.add;
      } else {
        final DateTime lastUpdated = currentConditions[layoutID]!;
        final DateTime newlyUpdated = serverConditions[layoutID]!;
        if (newlyUpdated.isAfter(lastUpdated)) {
          conditionUpdates[layoutID] = UpdateType.update;
        }
      }
    }

    return conditionUpdates;
  }

  /// Similar to [getOrFetchPopulatedLayout], but utilizes the download queue
  /// to respect the order of downloads.
  Future<void> queueLayout({
    required String layoutID,
    bool prioritize = false,
  }) async {
    if (_publishModel != null && queuingDone) {
      log('[queueLayout] No longer queuing. Downloading layout [$layoutID] immediately...');
      try {
        await getOrFetchPopulatedLayout(layoutID: layoutID);
        log('[queueLayout] Layout [$layoutID] download complete.');
      } on CodelesslyException catch (e, str) {
        log('[queueLayout] Layout [$layoutID] failed to download immediately. CodelesslyException thrown.');
        errorHandler.captureException(e, trace: str);
      } catch (e, str) {
        log('[queueLayout] Layout [$layoutID] failed to download immediately.');
        final exception = CodelesslyException.layout(
          ErrorType.layoutFailed,
          message: 'Failed to download layout [$layoutID].',
          originalException: e,
          layoutID: layoutID,
        );
        errorHandler.captureException(exception, trace: str);
      }
    } else {
      if (_downloadQueue.contains(layoutID)) {
        if (prioritize) {
          if (_downloadQueue.first == layoutID) {
            log('[queueLayout] Layout [$layoutID] is already at the front of the queue. Skipping.');
            return;
          } else {
            log('[queueLayout] Layout [$layoutID] is already in the queue. Moving it to the front to prioritize it.');
            _downloadQueue.remove(layoutID);
          }
        } else {
          log('[queueLayout] Layout [$layoutID] is already in the queue. Skipping.');
          return;
        }
      }

      if (prioritize) {
        log('[queueLayout] Prioritizing this layout. Inserting [$layoutID] to the front of the queue.');
        _downloadQueue.insert(0, layoutID);
      } else {
        log('[queueLayout] Adding [$layoutID] to the back of the queue.');
        _downloadQueue.add(layoutID);
      }
    }
  }

  /// Downloads or looks up the requested [layoutID] along with its associated
  /// fonts, and emits the updated [_publishModel].
  ///
  /// [layoutID] is the identifier of the layout to be fetched or retrieved.
  ///
  /// This method first checks if the layout with the given [layoutID] is
  /// already cached.
  /// If it is, the method proceeds directly to fetching the required fonts.
  /// If not, it downloads the layout model, emits it, and saves it before
  /// moving on to processing the fonts.
  ///
  /// The [SDKPublishFont]s are then fetched or downloaded in the background,
  /// ensuring that they are ready to be used.
  /// After the font models are fetched, their bytes are either loaded from
  /// cache or downloaded from the network, and then saved and loaded into
  /// the Flutter engine.
  ///
  /// This method will return `false` if the user is not authenticated and the
  /// layout is not cached.
  ///
  /// Will return `true` if the layout and its associated fonts were fetched
  /// successfully, `false` otherwise.
  Future<bool> getOrFetchPopulatedLayout({
    required String layoutID,
  }) async {
    final SDKPublishModel? model = _publishModel;
    final AuthData? auth = authManager.authData;
    assert(
      model != null,
      'Data manager has not been initialized yet.',
    );

    // If the user is not authenticated, then they get whatever is cached and
    // nothing else.
    if (auth == null) return model!.layouts.containsKey(layoutID);

    if (_publishModel!.layoutIDMap.containsKey(layoutID)) {
      layoutID = _publishModel!.layoutIDMap[layoutID]!;
    }

    // Process Layouts
    SDKPublishLayout? layout;
    if (model!.layouts.containsKey(layoutID)) {
      log('\tLayout [$layoutID] is already cached. Skipping download.');
      layout = model.layouts[layoutID];
    } else {
      log('\tLayout [$layoutID] is not cached. Downloading...');
      layout = await networkDataRepository.downloadLayoutModel(
        layoutID: layoutID,
        projectID: auth.projectId,
        source: config.publishSource,
      );
      if (layout == null) {
        log('\tLayout [$layoutID] could not be downloaded.');
        return false;
      } else {
        log('\tLayout [$layoutID] downloaded successfully.');
      }

      model.layouts[layoutID] = layout;
    }

    assert(layout != null, 'Layout should not be null at this point.');

    // Process APIs
    if (model.updates.layoutApis.containsKey(layoutID)) {
      log('\tLayout [$layoutID] has ${model.updates.layoutApis[layoutID]!.length} apis.');
      final Set<Future<HttpApiData?>> apiModels = getOrFetchApis(
        apiIds: model.updates.layoutApis[layoutID]!,
      );

      final List<HttpApiData?> results =
          await Future.wait(apiModels.map((future) async {
        try {
          return await future;
        } catch (e, stacktrace) {
          logError(
            'Error while fetching apis',
            error: e,
            stackTrace: stacktrace,
          );
          return null;
        }
      }));

      for (final api in results) {
        if (api == null) continue;
        model.apis[api.id] = api;
      }
    } else {
      log('\tLayout [$layoutID] has no apis.');
    }

    // Process Variables
    if (model.updates.variables.containsKey(layoutID)) {
      log('\tLayout [$layoutID] has variables.');
      try {
        final SDKLayoutVariables? variables =
            await getOrFetchVariables(layoutID);
        if (variables != null) {
          model.variables[layoutID] = variables;
        }
      } catch (e, stacktrace) {
        logError(
          'Error while fetching variables',
          error: e,
          stackTrace: stacktrace,
        );
      }
    } else {
      log('Layout [$layoutID] has no variables.');
    }

    // Process Conditions
    if (model.updates.conditions.containsKey(layoutID)) {
      log('\tLayout [$layoutID] has conditions.');
      try {
        final SDKLayoutConditions? conditions =
            await getOrFetchConditions(layoutID);
        if (conditions != null) {
          model.conditions[layoutID] = conditions;
        }
      } catch (e, stacktrace) {
        logError(
          'Error while fetching conditions',
          error: e,
          stackTrace: stacktrace,
        );
      }
    } else {
      log('\tLayout [$layoutID] has no conditions.');
    }

    await emitPublishModel();
    savePublishModel();

    log('\tLayout [$layoutID] ready, time for fonts...');

    // Process Fonts
    if (model.updates.layoutFonts.containsKey(layoutID)) {
      log('\tLayout [$layoutID] has ${model.updates.layoutFonts[layoutID]!.length} fonts.');

      // Download or load fonts in the background.
      getOrFetchFontModels(
        fontIDs: model.updates.layoutFonts[layoutID]!,
      ).then((Set<SDKPublishFont> fontModels) async {
        log('\tFound ${fontModels.length} fonts to fetch for layout [$layoutID].');

        for (final SDKPublishFont fontModel in fontModels) {
          log('\t\tFontModel [${fontModel.id}] ready. Fetching bytes & loading...');

          model.fonts[fontModel.id] = fontModel;

          await getOrFetchFontBytesAndSaveAndLoad(fontModel).then((_) {
            log('\t\tFontModel [${fontModel.id}] loaded. Done!\n');
          });
        }
      }).catchError((error, stack) {
        logError(
          'Error while fetching fonts',
          error: error,
          stackTrace: stack,
        );
      });
    } else {
      log('\tLayout [$layoutID] has no fonts.');
    }

    return true;
  }

  /// Downloads a complete publish bundle json from Codelessly's Firebase
  /// storage based on the given [slug] and [source].
  ///
  /// If the download is successful, the publish model is updated and emitted.
  /// The updated publish model is also saved to the local cache.
  ///
  /// If the download fails, this function gracefully exits and returns false.
  ///
  /// [returns] true if the download was successful, false otherwise.
  Future<bool> fetchCompletePublishBundle({
    required String slug,
    required PublishSource source,
  }) async {
    final Stopwatch stopwatch = Stopwatch()..start();

    try {
      final SDKPublishModel? model =
          await networkDataRepository.downloadCompletePublishBundle(
        slug: slug,
        source: source,
      );

      if (model != null) {
        log('Successfully downloaded complete publish bundle. Emitting it.');
        _publishModel = model;
        await emitPublishModel();
        savePublishModel();
        return true;
      }
    } catch (e, str) {
      logError(
        'Failed to download complete publish bundle.',
        error: e,
        stackTrace: str,
      );
    } finally {
      stopwatch.stop();
    }

    return false;
  }

  /// Wrapper for [getOrFetchFontBytesAndSave] that additionally loads the font
  /// into the Flutter engine.
  Future<void> getOrFetchFontBytesAndSaveAndLoad(SDKPublishFont font) async {
    final Uint8List? fontBytes = await getOrFetchFontBytesAndSave(font);
    if (fontBytes == null) return;

    return loadFont(font, fontBytes);
  }

  /// Loads a [font] with its associated [fontBytes] into the Flutter engine.
  Future<void> loadFont(SDKPublishFont font, Uint8List fontBytes) async {
    log('[FLUTTER] Loading font [${font.id}](${font.fullFontName}) into Flutter framework.');
    final FontLoader fontLoader = FontLoader(font.fullFontName);

    fontLoader.addFont(Future.value(ByteData.view(fontBytes.buffer)));

    return fontLoader.load().then((_) {
      log('[FLUTTER] Successfully loaded font [${font.id}](${font.fullFontName}) into Flutter framework.');
    });
  }

  /// Given a [font], will fetch its bytes either from cache or download & save
  /// them.
  Future<Uint8List?> getOrFetchFontBytesAndSave(SDKPublishFont font) async {
    log('\t\tChecking bytes for [${font.id}](${font.fullFontName}).');
    final Uint8List? fontBytes = localDataRepository.fetchFontBytes(
      fontID: font.id,
      source: config.publishSource,
    );
    if (fontBytes != null) {
      log('\t\tFont [${font.id}] bytes already cached.');
      return Future.value(fontBytes);
    } else {
      log('\t\tFont [${font.id}] bytes not cached. Downloading...');
      return downloadFontBytesAndSave(font);
    }
  }

  /// Downloads the bytes of a [font] and saves them to cache.
  Future<Uint8List?> downloadFontBytesAndSave(SDKPublishFont font) async =>
      networkDataRepository.downloadFontBytes(url: font.url).then(
        (Uint8List? fontBytes) {
          // Save the font bytes to cache.
          if (fontBytes == null) return null;
          saveFontBytes(font, fontBytes);
          return fontBytes;
        },
      );

  /// Gets all [SDKPublishFont] models of a given set of [fontIDs] either from
  /// local cache or downloads them from the network.
  Future<Set<SDKPublishFont>> getOrFetchFontModels({
    required Set<String> fontIDs,
  }) async {
    final AuthData? auth = authManager.authData;

    final Set<SDKPublishFont> fonts = {};
    for (final String fontID in fontIDs) {
      final SDKPublishFont? font = _publishModel?.fonts[fontID];
      if (font != null) {
        fonts.add(font);
      } else {
        if (auth == null) continue;

        try {
          final SDKPublishFont? downloadedFont =
              await networkDataRepository.downloadFontModel(
            projectID: auth.projectId,
            fontID: fontID,
            source: config.publishSource,
          );
          if (downloadedFont != null) {
            fonts.add(downloadedFont);
          }
        } catch (e) {
          log('\t\tFont [$fontID] could not be downloaded.');
        }
      }
    }
    return fonts;
  }

  /// Gets all [SDKPublishFont] models of a given set of [fontIDs] either from
  /// local cache or downloads them from the network.
  Set<Future<HttpApiData?>> getOrFetchApis({
    required Set<String> apiIds,
  }) {
    final AuthData? auth = authManager.authData;

    final Set<Future<HttpApiData?>> apis = {};
    for (final String apiId in apiIds) {
      final HttpApiData? api = _publishModel?.apis[apiId];
      if (api != null) {
        apis.add(Future.value(api));
      } else {
        if (auth == null) continue;

        final Future<HttpApiData?> apiFuture =
            networkDataRepository.downloadApi(
          projectID: auth.projectId,
          apiId: apiId,
          source: config.publishSource,
        );
        apis.add(apiFuture);
      }
    }
    return apis;
  }

  /// fetches conditions for a given layoutID.
  Future<SDKLayoutConditions?> getOrFetchConditions(String layoutID) {
    final AuthData? auth = authManager.authData;

    final SDKLayoutConditions? conditions = _publishModel?.conditions[layoutID];
    if (conditions != null) return Future.value(conditions);

    if (auth == null) return Future.value(null);

    return networkDataRepository.downloadLayoutConditions(
      projectID: auth.projectId,
      layoutID: layoutID,
      source: config.publishSource,
    );
  }

  /// fetches conditions for a given layoutID.
  Future<SDKLayoutVariables?> getOrFetchVariables(String layoutID) {
    final AuthData? auth = authManager.authData;

    final SDKLayoutVariables? variables = _publishModel?.variables[layoutID];
    if (variables != null) return Future.value(variables);

    if (auth == null) return Future.value(null);

    return networkDataRepository.downloadLayoutVariables(
      projectID: auth.projectId,
      layoutID: layoutID,
      source: config.publishSource,
    );
  }
}
