import 'dart:async';
import 'dart:developer';

import 'package:flutter/services.dart';
import 'package:hive/hive.dart';

import '../../codelessly_sdk.dart';
import '../cache/codelessly_cache_manager.dart';
import '../logging/error_handler.dart';
import 'local_storage.dart';

/// Orchestrates the data flow for the SDK.
class DataManager {
  /// Determines whether the data manager has been initialized at least once.
  ///
  /// This is used to inform systems that rely on the data manager that it might
  /// not need to be initialized again.
  bool initialized = false;

  /// The passed config from the SDK.
  final CodelesslyConfig config;

  /// The network data repository to use. By default, it is going to be either
  /// [FirebaseDataRepository] or [WebDataRepository] depending on platform.
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

  SDKPublishModel? _publishModel;

  LocalStorage? _localStorage;

  /// The local storage instance used by this data manager.
  LocalStorage get localStorage {
    assert(_localStorage != null, 'Local storage is not initialized yet.');
    return _localStorage!;
  }

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

  /// The slug for the project as defined in the editor's publish settings.
  late String? slug = config.slug;

  /// Creates a new instance of [DataManager] with the given [config].
  DataManager({
    required this.config,
    required this.cacheManager,
    required this.authManager,
    required this.networkDataRepository,
    required this.localDataRepository,
    SDKPublishModel? publishModel,
  }) : _publishModel = publishModel;

  /// Initializes the [DataManager] instance.
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

    initialized = true;

    // Initialize all locally cached data.
    final cachedModel = localDataRepository.fetchPublishModel(
      source: config.publishSource,
    );

    if (_publishModel ?? cachedModel case var model?) {
      await onPublishModelLoaded(model, fromCache: true);
    }

    _publishModel ??= cachedModel;

    if (_publishModel != null) {
      log('[DataManager] Publish model is cached locally. Emitting.');
      emitPublishModel();

      loadFontsFromPublishModel();
    }

    // A slug was specified. We need a layout FAST.
    // No authentication is required; let's download a complete publish bundle.
    if (config.slug != null &&
        (slug != config.slug || authManager.authData == null)) {
      if (slug == config.slug) {
        log('[DataManager] [slug] Slug is the same as the last cached slug, but auth data is null, so going through slug flow again...');
      } else {
        log('[DataManager] [slug] Slug changed from $slug to ${config.slug}. Going through slug flow...');
      }

      final Stopwatch bundleStopWatch = Stopwatch()..start();
      try {
        log('[DataManager] [slug] Downloading complete publish bundle for slug $slug.');

        slug = config.slug;

        if (_publishModel == null) {
          log('[DataManager] [slug] Publish model is not cached locally. Downloading complete publish bundle for slug ${config.slug} in foreground.');
        } else {
          log('[DataManager] [slug] Publish model is already cached locally. Downloading complete publish bundle for slug ${config.slug} in background.');
        }

        final publishBundleFuture = fetchCompletePublishBundle(
          slug: slug!,
          source: config.publishSource,
        ).then((success) {
          if (success) {
            log('[DataManager] [slug] Complete publish model from slug is downloaded in background. Emitting.');

            loadFontsFromPublishModel();
          } else {
            log('[DataManager] [slug] Failed to download complete publish bundle for slug ${config.slug}.');
          }
        });

        if (_publishModel == null) {
          await publishBundleFuture;
        }

        _recordTime(stopwatch);
      } catch (e, stackTrace) {
        log('[DataManager] Error trying to download complete publish model from slug.');
        log('[DataManager] Since no publish model is cached, this is a complete stop to the data manager.');
        log('[DataManager]', level: 900, error: e, stackTrace: stackTrace);
        print(e);
        print(stackTrace);

        _recordTime(stopwatch);

        log('[DataManager] [slug] Failed to download complete publish bundle for slug ${config.slug}.');
        return;
      } finally {
        bundleStopWatch.stop();
        log('[DataManager] [slug] Publish bundle flow took ${bundleStopWatch.elapsedMilliseconds}ms or ${bundleStopWatch.elapsed.inSeconds}s.');
      }
    } else {
      if (config.slug == null) {
        log('[DataManager] [slug] Slug is null. Skipping slug flow.');
      } else if (config.slug == slug) {
        log('[DataManager] [slug] Slug is the same as the last cached slug and auth data exists. We can load through the normal flow. Skipping slug flow.');
      }
    }

    if (authManager.authData == null) {
      log('[DataManager] No auth data is available. Continuing as if offline.');
      _recordTime(stopwatch);
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
    final bool didPrepareLayout;
    if (_publishModel != null && layoutID != null) {
      if (!_publishModel!.layouts.containsKey(layoutID)) {
        log('[DataManager] Layout [$layoutID] during init is not cached locally. Downloading...');
        didPrepareLayout = await getOrFetchPopulatedLayout(
          layoutID: layoutID,
        );
        log('[DataManager] Layout in init [$layoutID] fetch complete.');
      } else {
        log('[DataManager] Layout [$layoutID] during init is already cached locally. Skipping layout download.');
        didPrepareLayout = true;
      }
    } else {
      if (_publishModel == null) {
        log('[DataManager] Publish model during init is not cached locally. Going to wait for the first publish model from the server.');
      } else if (layoutID == null) {
        log('[DataManager] Publish model during init is available and layoutID is not specified. All layouts will be downloaded soon!');
      }
      didPrepareLayout = false;
    }

    // Listen the publish model document.
    // It's either going to be fetched for the first time if it doesn't exist
    // in cache, or it's going to be updated with new data.
    final Future<SDKPublishModel> firstPublishEvent =
        listenToPublishModel(authData.projectId);

    // If the publish model is still null, then we need to wait for the first
    // publish model to arrive from the server via the stream above.
    if (_publishModel == null) {
      log(
        '[DataManager] Publish model is still null during init. Waiting for the first publish model from the server.',
      );
      final model = await firstPublishEvent;
      await onPublishModelLoaded(model);
      _publishModel = model;
      emitPublishModel();
      savePublishModel();

      log('[DataManager] Publish model during init is now available. Proceeding with init!');

      if (_publishModel == null) {
        log(
          '[DataManager] Publish model is still null.\n'
          'Is there a network problem or bad authentication?',
        );
        _recordTime(stopwatch);
        return;
      }

      // If a [layoutID] was specified, then that layout must be prioritized and
      // downloaded first if it is not already cached.
      //
      // If we could not download it earlier, that would be because we did not
      // have a publish model available and needed to wait for one to arrive
      // from the server for the first time or that it failed to download for some
      // unknown reason.
      //
      // Perhaps the publish model was simply out of date locally,
      // but now that we fetched a new one, and didPrepareLayout is still false,
      // we can try to download the layout again with the new publish model.
      //
      // At this stage of the function, we can be sure that a publish model exists
      // and can safely download the desired [layoutID], because if a publish
      // model is still null, we cannot proceed further and this function
      // terminates earlier.
      if (!didPrepareLayout && layoutID != null) {
        log(
          '[DataManager] Publish model is definitely available. We can safely download layout [$layoutID] now.',
        );
        await getOrFetchPopulatedLayout(layoutID: layoutID);

        log(
          '[DataManager] Layout [$layoutID] during init download complete.',
        );
      }

      // If a [layoutID] is not specified, then we need to download all layouts
      // in the background.
      if (config.preload) {
        final preloadFuture = Future(() async {
          log(
            '[DataManager] Config preload was specified during init. Downloading ${_publishModel!.updates.layouts.length} layouts...',
          );
          for (final String layoutID in _publishModel!.updates.layouts.keys) {
            log(
              '[DataManager] \tDownloading layout [$layoutID]...',
            );
            await getOrFetchPopulatedLayout(layoutID: layoutID);
            log(
              '[DataManager] \tLayout [$layoutID] during init download complete.',
            );
          }

          log(
            '[DataManager] All layouts during init download complete.',
          );
        });

        // Don't await for all the of the layouts to download if the data manager
        // is initialized with a layoutID. The layoutID should be prioritized
        // and downloaded first, the rest can be downloaded in the background.
        if (layoutID == null) {
          log(
            '[DataManager] Config preload was specified during init, but a layoutID was not specified. Waiting for all layouts to download...',
          );
          await preloadFuture;
        }
      }
    }

    _recordTime(stopwatch);
  }

  /// Called when the publish model is loaded.
  Future<void> onPublishModelLoaded(SDKPublishModel model,
      {bool fromCache = false}) async {
    log('[DataManager] Publish model loaded. Initializing local storage...');
    if (_localStorage == null) {
      // Initialize local storage
      final Box box = await Hive.openBox(model.projectId);
      _localStorage = HiveLocalStorage(box);
      log('[DataManager] Local storage initialized.');
    }
  }

  void _recordTime(Stopwatch stopwatch) {
    stopwatch.stop();
    log(
      '[DataManager] Initialization took ${stopwatch.elapsedMilliseconds}ms or ${stopwatch.elapsed.inSeconds}s.',
    );
  }

  /// Will consume all of the [SDKFontModel]s loaded in the [_publishModel]
  /// and either load them into the Flutter SDK or download them then load them.
  void loadFontsFromPublishModel() {
    assert(_publishModel != null, 'Publish model cannot be null here.');

    log('[DataManager] About to load all fonts that are present in the current publish model.');
    if (_publishModel!.fonts.isNotEmpty) {
      log('[DataManager] Fonts: ${_publishModel!.fonts.values.map((font) => font.fullFontName).join(', ')}');
    } else {
      log('[DataManager] No fonts to load.');
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
    log('[DataManager] About to listen to publish model doc.');
    final Completer<SDKPublishModel> completer = Completer();
    _publishModelDocumentListener?.cancel();

    _publishModelDocumentListener = networkDataRepository
        .streamPublishModel(
      projectID: projectId,
      source: config.publishSource,
    )
        .listen((SDKPublishModel? serverModel) {
      if (serverModel == null) return;

      log('[DataManager] Publish model stream event received.');

      final bool isFirstEvent = !completer.isCompleted;

      // If the completer has not completed yet, it needs to be
      // completed with the first available publish model form the server.
      if (isFirstEvent) {
        log(
          '[DataManager] Completing publish model stream completer since this is the first event.',
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
          '[DataManager] Publish model is null during init and received the first publish model from the server. Skipping comparison in stream.',
        );
        return;
      }

      if (config.slug != null) {
        log('[DataManager] Initialized using the slug, this event is not essential for initial loading.');
      } else if (isFirstEvent) {
        log('[DataManager] Publish model during init was not null, and we received a new publish model from the server. Comparing...');
      } else {
        log('[DataManager] Received a second publish model from the server. Comparing...');
      }
      final SDKPublishModel localModel = _publishModel!;

      // Comparison should always be a background process.
      processPublishDifference(
        serverModel: serverModel,
        localModel: localModel,
      );

      log('[DataManager] Publish model comparison complete.');
    })
      ..onError((error, str) {
        CodelesslyErrorHandler.instance
            .captureException(error, stacktrace: str);
      });

    return completer.future;
  }

  /// Emits the current [_publishModel] to the [_publishModelStreamController].
  void emitPublishModel() {
    log('[DataManager] Emitting publish model to stream. has model: ${_publishModel != null}');
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

  /// Disposes the [DataManager] instance.
  void dispose() {
    _publishModelStreamController.close();
    _publishModelDocumentListener?.cancel();
    initialized = false;
    _publishModel = null;
    _localStorage?.close();
    _localStorage = null;
  }

  /// Sets the [SDKPublishModel] as null and cancels document streaming.
  void invalidate([String? debugLabel]) {
    log('[DataManager] ${debugLabel == null ? '' : '[$debugLabel]'} Invalidating...');
    _publishModelDocumentListener?.cancel();
    _publishModelStreamController.add(null);
    _publishModel = null;
    _localStorage?.close();
    _localStorage = null;
    initialized = false;
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

    if (layoutUpdates.isEmpty &&
        fontUpdates.isEmpty &&
        apiUpdates.isEmpty &&
        variableUpdates.isEmpty &&
        conditionUpdates.isEmpty &&
        !templateChanged &&
        !entryChanged) {
      log('[DataManager] No updates to process.');
      return;
    } else {
      log('[DataManager] Processing updates:');
      log('      | ${layoutUpdates.length} layout updates.');
      log('      | ${fontUpdates.length} font updates.');
      log('      | ${apiUpdates.length} api updates.');
      log('      | ${variableUpdates.length} variable updates.');
      log('      | ${conditionUpdates.length} condition updates.');
      log('      | ${templateChanged ? 1 : 0} template update${templateChanged ? '' : 's'}.');
      log('      | ${entryChanged ? 1 : 0} entry id update${entryChanged ? '' : 's'}.');
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
          break;
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
          break;
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
          break;
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
          break;
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
          break;
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
          break;
      }
    }

    for (final String layoutID in variableUpdates.keys) {
      final UpdateType updateType = variableUpdates[layoutID]!;

      switch (updateType) {
        case UpdateType.delete:
          localModel.variables.remove(layoutID);
          localDataRepository.deletePublishVariables(
            layoutId: layoutID,
            source: config.publishSource,
          );
          break;
        case UpdateType.add:
        case UpdateType.update:
          final SDKLayoutVariables? layoutVariables =
              await networkDataRepository.downloadLayoutVariables(
            projectID: authManager.authData!.projectId,
            layoutID: layoutID,
            source: config.publishSource,
          );
          if (layoutVariables != null) {
            localModel.variables[layoutID] = layoutVariables;
          }
          break;
      }
    }

    for (final String layoutID in conditionUpdates.keys) {
      final UpdateType updateType = conditionUpdates[layoutID]!;

      switch (updateType) {
        case UpdateType.delete:
          localModel.variables.remove(layoutID);
          localDataRepository.deletePublishConditions(
            layoutId: layoutID,
            source: config.publishSource,
          );
          break;
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
          break;
      }
    }

    _publishModel = localModel.copyWith(
      updates: serverModel.updates,
      entryPageId: serverModel.entryPageId,
      entryCanvasId: serverModel.entryCanvasId,
      entryLayoutId: serverModel.entryLayoutId,
    );

    if (templateChanged) {
      _publishModel = publishModel?.copyWith();
    }

    savePublishModel();
    emitPublishModel();
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
    for (final String layoutId in currentVariables.keys) {
      if (!serverVariables.containsKey(layoutId)) {
        variableUpdates[layoutId] = UpdateType.delete;
      }
    }

    // Check for added or updated layouts.
    for (final String layoutId in serverVariables.keys) {
      if (!currentVariables.containsKey(layoutId)) {
        variableUpdates[layoutId] = UpdateType.add;
      } else {
        final DateTime lastUpdated = currentVariables[layoutId]!;
        final DateTime newlyUpdated = serverVariables[layoutId]!;
        if (newlyUpdated.isAfter(lastUpdated)) {
          variableUpdates[layoutId] = UpdateType.update;
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
    for (final String layoutId in currentConditions.keys) {
      if (!serverConditions.containsKey(layoutId)) {
        conditionUpdates[layoutId] = UpdateType.delete;
      }
    }

    // Check for added or updated layouts.
    for (final String layoutId in serverConditions.keys) {
      if (!currentConditions.containsKey(layoutId)) {
        conditionUpdates[layoutId] = UpdateType.add;
      } else {
        final DateTime lastUpdated = currentConditions[layoutId]!;
        final DateTime newlyUpdated = serverConditions[layoutId]!;
        if (newlyUpdated.isAfter(lastUpdated)) {
          conditionUpdates[layoutId] = UpdateType.update;
        }
      }
    }

    return conditionUpdates;
  }

  /// [layoutID] is the identifier of the layout to be fetched or retrieved.
  ///
  /// Fetches or gets the requested [layoutID] along with its associated fonts,
  /// and emits the updated [_publishModel].
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

    SDKPublishLayout? layout;
    if (model!.layouts.containsKey(layoutID)) {
      log('[DataManager] \tlayout [$layoutID] already cached. On Your Marks...');
      layout = model.layouts[layoutID];
    } else {
      log('[DataManager] \tlayout [$layoutID] not cached. On Your Marks...');
      layout = await networkDataRepository.downloadLayoutModel(
        layoutID: layoutID,
        projectID: auth.projectId,
        source: config.publishSource,
      );
      if (layout == null) {
        log('[DataManager] \tlayout [$layoutID] could not be downloaded.');
        return false;
      }

      model.layouts[layoutID] = layout;
    }

    assert(layout != null, 'Layout should not be null at this point.');

    if (model.updates.layoutApis.containsKey(layoutID)) {
      final Set<Future<HttpApiData?>> apiModels = getOrFetchApis(
        apiIds: model.updates.layoutApis[layoutID]!,
      );

      for (final future in apiModels) {
        try {
          final api = await future;
          if (api == null) continue;
          model.apis[api.id] = api;
        } catch (e, stacktrace) {
          log('[DataManager] Error while fetching api: $e');
          log(stacktrace.toString());
        }
      }
    } else {
      log('[DataManager] \tLayout [$layoutID] has no apis.');
    }

    if (model.updates.conditions.containsKey(layoutID)) {
      try {
        final SDKLayoutConditions? conditions =
            await getOrFetchConditions(layoutID);
        if (conditions != null) {
          model.conditions[layoutID] = conditions;
        }
      } catch (e, stacktrace) {
        log('[DataManager] Error while fetching conditions: $e');
        log(stacktrace.toString());
      }
    } else {
      log('[DataManager] \tLayout [$layoutID] has no conditions.');
    }

    if (model.updates.variables.containsKey(layoutID)) {
      try {
        final SDKLayoutVariables? variables =
            await getOrFetchVariables(layoutID);
        if (variables != null) {
          model.variables[layoutID] = variables;
        }
      } catch (e, stacktrace) {
        log('[DataManager] Error while fetching variables: $e');
        log(stacktrace.toString());
      }
    } else {
      log('[DataManager] \tLayout [$layoutID] has no variables.');
    }

    emitPublishModel();
    savePublishModel();

    log('[DataManager] \tLayoutModel [$layoutID] ready, time for fonts. Get Set...');
    log('[DataManager] \tLayoutModel [$layoutID] has ${model.updates.layoutFonts[layoutID]} fonts.');

    if (model.updates.layoutFonts.containsKey(layoutID)) {
      // Download or load fonts in the background.
      getOrFetchFontModels(
        fontIDs: model.updates.layoutFonts[layoutID]!,
      ).then((Set<SDKPublishFont> fontModels) async {
        log('[DataManager] \tFound ${fontModels.length} fonts to fetch for layout [$layoutID]. Go!');

        for (final SDKPublishFont fontModel in fontModels) {
          log('[DataManager] \t\tFontModel [${fontModel.id}] ready. Fetching bytes & loading...');

          model.fonts[fontModel.id] = fontModel;

          await getOrFetchFontBytesAndSaveAndLoad(fontModel).then((_) {
            log('[DataManager] \t\tFontModel [${fontModel.id}] loaded. Done!\n');
          });
        }
      });
    } else {
      log('[DataManager] \tLayout [$layoutID] has no fonts.');
    }

    return true;
  }

  Future<bool> fetchCompletePublishBundle({
    required String slug,
    required PublishSource source,
  }) async {
    final Stopwatch stopwatch = Stopwatch()..start();

    SDKPublishModel? model;
    try {
      model = await networkDataRepository.downloadCompletePublishBundle(
        slug: slug,
        source: source,
      );
    } catch (e) {
      log('[DataManager] Failed to download complete publish bundle.');
      return false;
    } finally {
      stopwatch.stop();
      log('[DataManager] Publish bundle download stopwatch done in ${stopwatch.elapsedMilliseconds}ms or ${stopwatch.elapsed.inSeconds}s.');
    }

    if (model != null) {
      log('[DataManager] Successfully downloaded complete publish bundle. Emitting it.');
      await onPublishModelLoaded(model);
      _publishModel = model;
      emitPublishModel();
      savePublishModel();
      return true;
    }

    log('[DataManager] Failed to download complete publish bundle in ${stopwatch.elapsedMilliseconds}ms or ${stopwatch.elapsed.inSeconds}s.');
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
    log('[DataManager] [FLUTTER] Loading font [${font.id}](${font.fullFontName}) into Flutter framework.');
    final FontLoader fontLoader = FontLoader(font.fullFontName);

    fontLoader.addFont(Future.value(ByteData.view(fontBytes.buffer)));

    return fontLoader.load().then((_) {
      log('[DataManager] [FLUTTER] Successfully loaded font [${font.id}](${font.fullFontName}) into Flutter framework.');
    });
  }

  /// Given a [font], will fetch its bytes either from cache or download & save
  /// them.
  Future<Uint8List?> getOrFetchFontBytesAndSave(SDKPublishFont font) async {
    log('[DataManager] \t\tChecking bytes for [${font.id}](${font.fullFontName}).');
    final Uint8List? fontBytes = localDataRepository.fetchFontBytes(
      fontID: font.id,
      source: config.publishSource,
    );
    if (fontBytes != null) {
      log('[DataManager] \t\tFont [${font.id}] bytes already cached.');
      return Future.value(fontBytes);
    } else {
      log('[DataManager] \t\tFont [${font.id}] bytes not cached. Downloading...');
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
          log('[DataManager] \t\tFont [$fontID] could not be downloaded.');
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
