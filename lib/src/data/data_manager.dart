import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:flutter/services.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';

import '../../codelessly_sdk.dart';
import '../logging/debug_logger.dart';

/// Orchestrates the data flow for the SDK.
class DataManager {
  static const String name = 'DataManager';

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

  /// The auth manager to use. By default, it is [AuthManager].
  final AuthManager authManager;

  // TODO(Saad): This is only used to initialize CloudDatabase. We may be able
  //  to decouple it.
  /// The firestore instance to use.
  final FirebaseFirestore firebaseFirestore;

  /// The error handler to use.
  final CodelesslyErrorHandler errorHandler;

  /// The stat tracker to use, used to track various reads and writes in this
  /// data manager.
  final StatTracker tracker;

  SDKPublishModel? _publishModel;

  // TODO(Saad): LocalDatabase is only initialized and never truly accessed by
  //  the DataManager itself. We can decouple it by moving it to the
  //  [Codelessly] level. Maybe through a new shared manager for it and
  //  CloudDatabase.
  LocalDatabase? _localDatabase;

  // TODO(Saad): CloudDatabase is only initialized and never truly accessed by
  //  the DataManager itself. We can decouple it by moving it to the
  //  [Codelessly] level. Maybe through a new shared manager for it and
  //  LocalDatabase.
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
    required this.tracker,
    SDKPublishModel? publishModel,
  }) : _publishModel = publishModel;

  /// Initializes the instance.
  ///
  /// If a [layoutID] is specified, that layout will be downloaded from the
  /// server first, then the rest of the layouts will be streamed passively
  /// in the background.
  ///
  /// If a [layoutID] is null, all layouts will be downloaded immediately and
  /// awaited.
  Future<void> init({required String? layoutID}) async {
    DebugLogger.instance.printFunction('init(layoutID: $layoutID)', name: name);

    assert(
      layoutID != null || config.preload || config.slug != null,
      'If [layoutID] is null, [config.preload] must be true. If both are not '
      'specified, then a slug must be provided in the config.',
    );

    final Stopwatch stopwatch = Stopwatch()..start();

    status = CStatus.loading(CLoadingState.initializedDataManagers);

    queuingDone = false;

    // Initialize all locally cached data.
    final cachedModel = localDataRepository.fetchPublishModel(
      source: config.publishSource,
    );

    _publishModel ??= cachedModel;

    if (_publishModel != null) {
      DebugLogger.instance
          .printInfo('Publish model is cached locally. Emitting.', name: name);
      await emitPublishModel();

      loadFontsFromPublishModel();
    }

    // A slug was specified. We need a layout FAST.
    if (config.slug case String slug) {
      DebugLogger.instance.printInfo(
        '[slug] Slug was specified [$slug]. Going through slug flow...',
        name: name,
      );

      final Stopwatch bundleStopWatch = Stopwatch()..start();
      try {
        DebugLogger.instance.printInfo(
          '[slug] Downloading complete publish bundle for slug $slug.',
          name: name,
        );

        if (_publishModel == null) {
          DebugLogger.instance.printInfo(
            '[slug] Publish model is not cached locally. Downloading complete publish bundle for slug $slug in foreground.',
            name: name,
          );
        } else {
          DebugLogger.instance.printInfo(
            '[slug] Publish model is already cached locally. Downloading complete publish bundle for slug $slug in background.',
            name: name,
          );
        }

        final publishBundleFuture = fetchCompletePublishBundle(
          slug: slug,
          source: config.publishSource,
        ).then((success) {
          if (success) {
            DebugLogger.instance.printInfo(
              '[slug] Complete publish model from slug is downloaded in background. Emitting.',
              name: name,
            );

            loadFontsFromPublishModel();
          } else {
            errorHandler.captureException(CodelesslyException.networkException(
              message:
                  'Failed to download complete publish bundle for slug $slug.',
            ));
          }
        });

        if (_publishModel == null) {
          await publishBundleFuture;
        }

        _logTime(stopwatch);
      } catch (e, stackTrace) {
        DebugLogger.instance.log(
          '[slug] Failed to download complete publish bundle for slug $slug.\nError: $e',
          category: DebugCategory.error,
          name: name,
          level: Level.WARNING,
        );
        DebugLogger.instance.printInfo(
          '[slug] Since no publish model is cached, this is a complete stop to the data manager.',
          name: name,
        );

        _logTime(stopwatch);

        if (e is CodelesslyException) {
          rethrow;
        } else {
          throw CodelesslyException.networkException(
            message:
                'Failed to download complete publish bundle for slug $slug.',
            originalException: e,
            stacktrace: stackTrace,
          );
        }
      } finally {
        bundleStopWatch.stop();
        DebugLogger.instance.printInfo(
          '[slug] Publish bundle flow took ${bundleStopWatch.elapsedMilliseconds}ms or ${bundleStopWatch.elapsed.inSeconds}s.',
          name: name,
        );
      }
    } else {
      DebugLogger.instance.printInfo(
        '[slug] Slug is ${config.slug}. Skipping slug flow.',
        name: name,
      );
    }

    if (authManager.authData == null) {
      DebugLogger.instance.printInfo(
        'No auth data is available. Continuing as if offline.',
        name: name,
      );
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
    final bool didPrepareLayout;
    if (_publishModel != null && layoutID != null) {
      if (!_publishModel!.layouts.containsKey(layoutID)) {
        // If the layout is disabled, we skip it.
        if (publishModel!.disabledLayouts.contains(layoutID)) {
          DebugLogger.instance.printInfo(
            'Layout [$layoutID] is marked as disabled. Skipping it during init.',
            name: name,
          );
          didPrepareLayout = false;
          _logTime(stopwatch);
        } else {
          DebugLogger.instance.printInfo(
            'Layout [$layoutID] during init is not cached locally. Downloading...',
            name: name,
          );

          try {
            didPrepareLayout = await getOrFetchPopulatedLayout(
              layoutID: layoutID,
            );
            DebugLogger.instance.printInfo(
              'Layout in init [$layoutID] fetch complete.',
              name: name,
            );
          } catch (e, str) {
            DebugLogger.instance.log(
              'Layout [$layoutID] failed to download during init.\nError: $e',
              category: DebugCategory.error,
              name: name,
              level: Level.WARNING,
            );
            final exception = CodelesslyException(
              'Failed to download layout [$layoutID] during init.',
              originalException: e,
              stacktrace: str,
              layoutID: layoutID,
            );
            errorHandler.captureException(exception, stacktrace: str);

            _logTime(stopwatch);
            return;
          }
        }
      } else {
        DebugLogger.instance.printInfo(
          'Layout [$layoutID] during init is already cached locally. Skipping layout download.',
          name: name,
        );
        didPrepareLayout = true;
      }
    } else {
      if (_publishModel == null) {
        DebugLogger.instance.printInfo(
          'Publish model during init is not cached locally. Going to wait for the first publish model from the server.',
          name: name,
        );
      } else if (layoutID == null) {
        DebugLogger.instance.printInfo(
          'Publish model during init is available and layoutID is not specified. All layouts will be downloaded soon!',
          name: name,
        );
      } else {
        DebugLogger.instance.printInfo(
          'Publish model during init is available and layoutID is specified. Layout [$layoutID] will be downloaded soon from stream.',
          name: name,
        );
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
      DebugLogger.instance.printInfo(
        'Publish model is still null during init. Waiting for the first publish model from the server.',
        name: name,
      );
      final model = await firstPublishEvent;
      _publishModel = model;
      await emitPublishModel();
      savePublishModel();

      DebugLogger.instance.printInfo(
        'Publish model during init is now available. Proceeding with init!',
        name: name,
      );

      if (_publishModel == null) {
        DebugLogger.instance.printInfo(
          'Publish model is still null.\n'
          'Is there a network problem or bad authentication?',
          name: name,
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
    // some unknown reason.
    //
    // Perhaps the publish model was simply out of date locally,
    // but now that we fetched a new one, and [didPrepareLayout] is still
    // false, we can try to download the layout again with the new publish
    // model.
    //
    // At this stage of the function, we can be sure that a publish model
    // exists and can safely download the desired [layoutID], because if a
    // publish model is still null, we cannot proceed further and this
    // function terminates earlier.
    if (!didPrepareLayout && layoutID != null) {
      DebugLogger.instance.printInfo(
        'We can safely download layout [$layoutID] now.',
        name: name,
      );

      if (publishModel!.disabledLayouts.contains(layoutID)) {
        DebugLogger.instance.printInfo(
          'Layout [$layoutID] is disabled. Skipping it during init.',
          name: name,
        );
      }
      try {
        await getOrFetchPopulatedLayout(layoutID: layoutID);
        DebugLogger.instance.printInfo(
          'Layout [$layoutID] downloaded from init successfully.',
          name: name,
        );
      } catch (e, str) {
        final exception = CodelesslyException(
          'Failed to download layout [$layoutID] during init.',
          originalException: e,
          stacktrace: str,
          layoutID: layoutID,
        );
        errorHandler.captureException(exception, stacktrace: str);
        // _logTime(stopwatch);
        // return;
      }
    }

    // Add all the layouts to the download queue excluding the [layoutID] if
    // that was specified. We don't want to download that layout twice.
    if (config.preload) {
      DebugLogger.instance.printInfo(
        'Config preload was specified during init, adding ${_publishModel!.updates.layouts.length - 1} layouts to the download queue...',
        name: name,
      );
      _downloadQueue.addAll(
        [..._publishModel!.updates.layouts.keys]..remove(layoutID),
      );
      DebugLogger.instance.printInfo(
        'All layouts during init download complete. ${_downloadQueue.length} layouts in queue.',
        name: name,
      );
    }

    // If a [layoutID] was specified for this initialization, then the Future
    // callback of this init function must complete once the layout has been
    // downloaded.
    // Otherwise we need to await for all layouts to be downloaded before
    // completing the Future.
    if (layoutID != null) {
      DebugLogger.instance.printInfo(
        'Layout [$layoutID] was specified during init. Processing download queue in the background...',
        name: name,
      );
      processDownloadQueue();
    } else {
      DebugLogger.instance.printInfo(
        'No layout was specified during init. Awaiting all layouts to be downloaded...',
        name: name,
      );
      await processDownloadQueue();
    }

    purgeDisabledLayouts(notify: true);

    _logTime(stopwatch);
  }

  Future<void> processDownloadQueue() async {
    while (_downloadQueue.isNotEmpty) {
      final String layoutID = _downloadQueue.removeAt(0);

      if (publishModel!.disabledLayouts.contains(layoutID)) {
        DebugLogger.instance.printInfo(
          '\tLayout [$layoutID] is disabled. Skipping it in download queue...',
          name: name,
        );
        continue;
      }

      DebugLogger.instance.printInfo(
        '\tDownloading layout [$layoutID] in download queue...',
        name: name,
      );
      try {
        await getOrFetchPopulatedLayout(layoutID: layoutID);

        DebugLogger.instance.printInfo(
          '\tLayout [$layoutID] downloaded from download queue complete.',
          name: name,
        );
      } catch (e, str) {
        DebugLogger.instance.log(
          '\tLayout [$layoutID] failed to download in download queue.\nError: $e',
          category: DebugCategory.error,
          name: name,
          level: Level.WARNING,
        );
        final exception = CodelesslyException(
          'Failed to download layout [$layoutID] during download queue.',
          originalException: e,
          stacktrace: str,
          layoutID: layoutID,
        );
        errorHandler.captureException(exception, stacktrace: str);
      }
    }

    DebugLogger.instance.printInfo(
      'Download queue is now empty. All layouts during init have been downloaded.',
      name: name,
    );
    queuingDone = true;
  }

  Future<void> purgeDisabledLayouts({required bool notify}) async {
    bool didChange = false;
    for (final String layoutID in publishModel!.disabledLayouts) {
      if (!publishModel!.layouts.containsKey(layoutID)) {
        continue;
      }
      DebugLogger.instance.printInfo(
        'Purging disabled layout [$layoutID]...',
        name: name,
      );
      localDataRepository.deletePublishLayout(
        layoutID: layoutID,
        source: config.publishSource,
      );
      publishModel!.layouts.remove(layoutID);
      didChange = true;
    }

    if (didChange && notify) {
      await emitPublishModel();
      savePublishModel();
    }
  }

  /// Called when the publish model is loaded.
  Future<bool> onPublishModelLoaded(String projectId) async {
    bool didChange = false;

    final bool shouldInitLocalStorage =
        _localDatabase == null || (_localDatabase!.identifier != projectId);

    if (shouldInitLocalStorage) {
      DebugLogger.instance.printInfo(
        'Initializing local storage for project $projectId...',
        name: name,
      );
      _localDatabase?.reset();
      _localDatabase = await initializeLocalStorage(projectId: projectId);
      didChange = true;
      DebugLogger.instance.printInfo(
        'Local storage initialized.',
        name: name,
      );
    } else {
      DebugLogger.instance.printInfo(
        'Local storage already initialized correctly. Skipping.',
        name: name,
      );
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
      DebugLogger.instance.printInfo(
        'Initializing cloud storage for project $projectId...',
        name: name,
      );
      _cloudDatabase?.reset();
      _cloudDatabase = await initializeCloudStorage(projectId: projectId);
      _publishModelStreamController.add(_publishModel);
      didChange = true;
      DebugLogger.instance.printInfo(
        'Cloud storage initialized.',
        name: name,
      );
    } else {
      if (shouldInitCloudStorage) {
        DebugLogger.instance.printInfo(
          'Cloud storage cannot be initialized because the user is not authenticated.',
          name: name,
        );
      } else {
        DebugLogger.instance.printInfo(
          'Cloud storage already initialized correctly. Skipping.',
          name: name,
        );
      }
    }

    return didChange;
  }

  Future<LocalDatabase> initializeLocalStorage(
      {required String projectId}) async {
    final Box box = await Hive.openBox(projectId);
    return HiveLocalDatabase(box, identifier: projectId);
  }

  // TODO(Saad): We can de-couple [firebaseFirestore] and [tracker] from
  //  [DataManager] by delegating this initialization to the creator of
  //  [DataManager], maybe through a callback so that DataManager can decide
  //  exactly when to initialize this.
  Future<CloudDatabase> initializeCloudStorage(
      {required String projectId}) async {
    final instance = FirestoreCloudDatabase(
      projectId,
      config.publishSource,
      firestore: firebaseFirestore,
      tracker: tracker,
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
    DebugLogger.instance.printInfo(
      'Initialization took ${stopwatch.elapsedMilliseconds}ms or ${stopwatch.elapsed.inSeconds}s.',
      name: name,
    );
  }

  /// Will consume all of the [SDKFontModel]s loaded in the [_publishModel]
  /// and either load them into the Flutter SDK or download them then load them.
  void loadFontsFromPublishModel() {
    assert(_publishModel != null, 'Publish model cannot be null here.');

    DebugLogger.instance.printInfo(
      'About to load all fonts that are present in the current publish model.',
      name: name,
    );
    if (_publishModel!.fonts.isNotEmpty) {
      DebugLogger.instance.printInfo(
        'Fonts: ${_publishModel!.fonts.values.map((font) => font.fullFontName).join(', ')}',
        name: name,
      );
    } else {
      DebugLogger.instance.printInfo(
        'No fonts to load.',
        name: name,
      );
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
    DebugLogger.instance.printInfo(
      'About to listen to publish model doc.',
      name: name,
    );
    final Completer<SDKPublishModel> completer = Completer();
    _publishModelDocumentListener?.cancel();

    _publishModelDocumentListener = networkDataRepository
        .streamPublishModel(
      projectID: projectId,
      source: config.publishSource,
    )
        .listen((SDKPublishModel? serverModel) {
      if (serverModel == null) return;

      DebugLogger.instance.printInfo(
        'Publish model stream event received.',
        name: name,
      );

      final bool isFirstEvent = !completer.isCompleted;

      // If the completer has not completed yet, it needs to be
      // completed with the first available publish model form the server.
      if (isFirstEvent) {
        DebugLogger.instance.printInfo(
          'Completing publish model stream completer since this is the first event.',
          name: name,
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
        DebugLogger.instance.printInfo(
          'Publish model is null during init and received the first publish model from the server. Skipping comparison in stream.',
          name: name,
        );
        return;
      }

      if (config.slug != null) {
        DebugLogger.instance.printInfo(
          'Initialized using the slug, this event is not essential for initial loading.',
          name: name,
        );
      } else if (isFirstEvent) {
        DebugLogger.instance.printInfo(
          'Publish model during init was not null, and we received a new publish model from the server. Comparing...',
          name: name,
        );
      } else {
        DebugLogger.instance.printInfo(
          'Received a new publish model from the server. Comparing...',
          name: name,
        );
      }
      final SDKPublishModel localModel = _publishModel!;

      // Comparison should always be a background process.
      processPublishDifference(
        serverModel: serverModel,
        localModel: localModel,
      );

      DebugLogger.instance.printInfo(
        'Publish model comparison complete.',
        name: name,
      );
    })
      ..onError((error, str) {
        errorHandler.captureException(error, stacktrace: str);
      });

    return completer.future;
  }

  /// Emits the current [_publishModel] to the [_publishModelStreamController].
  Future<void> emitPublishModel() async {
    await onPublishModelLoaded(_publishModel!.projectId);

    DebugLogger.instance.printInfo(
      'Emitting publish model to stream. has model: ${_publishModel != null}',
      name: name,
    );
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
    DebugLogger.instance.printFunction('dispose()', name: name);
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
    DebugLogger.instance.printFunction('reset()', name: name);
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

    final bool didLayoutIDMapChange = const MapEquality().equals(
      localModel.layoutIDMap,
      serverModel.layoutIDMap,
    );
    if (didLayoutIDMapChange) {
      localModel = localModel.copyWith(layoutIDMap: serverModel.layoutIDMap);
      DebugLogger.instance
          .printInfo('DIFF: Layout ID map changed. Updating...', name: name);
    }

    final bool disabledLayoutsChanged = !(const ListEquality()
        .equals(localModel.disabledLayouts, serverModel.disabledLayouts));
    if (disabledLayoutsChanged) {
      localModel =
          localModel.copyWith(disabledLayouts: serverModel.disabledLayouts);
      DebugLogger.instance
          .printInfo('DIFF: Disabled layouts changed. Updating...', name: name);
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
      DebugLogger.instance
          .printInfo('DIFF: No updates to process.', name: name);
      return;
    } else {
      DebugLogger.instance.printInfo('DIFF: Processing updates:', name: name);
      DebugLogger.instance.printInfo(
          '      | ${layoutUpdates.length} layout updates.',
          name: name);
      DebugLogger.instance
          .printInfo('      | ${fontUpdates.length} font updates.', name: name);
      DebugLogger.instance
          .printInfo('      | ${apiUpdates.length} api updates.', name: name);
      DebugLogger.instance.printInfo(
          '      | ${variableUpdates.length} variable updates.',
          name: name);
      DebugLogger.instance.printInfo(
          '      | ${conditionUpdates.length} condition updates.',
          name: name);
      DebugLogger.instance.printInfo(
          '      | ${templateChanged ? 1 : 0} template update${templateChanged ? '' : 's'}.',
          name: name);
      DebugLogger.instance.printInfo(
          '      | ${entryChanged ? 1 : 0} entry id update${entryChanged ? '' : 's'}.',
          name: name);
      DebugLogger.instance.printInfo(
          '      | ${didLayoutIDMapChange ? 'Layout ID map changed.' : 'No layout ID map changes.'}',
          name: name);
      DebugLogger.instance.printInfo(
          '      | ${disabledLayoutsChanged ? 'Disabled layout IDs changed.' : 'No disabled layout IDs changed.'}',
          name: name);
    }

    for (final String layoutID in layoutUpdates.keys) {
      final UpdateType updateType = layoutUpdates[layoutID]!;

      switch (updateType) {
        case UpdateType.delete:
          DebugLogger.instance
              .printInfo('DIFF: Deleting layout [$layoutID]...', name: name);
          localModel.layouts.remove(layoutID);
          localDataRepository.deletePublishLayout(
            layoutID: layoutID,
            source: config.publishSource,
          );
        case UpdateType.add:
        case UpdateType.update:
          DebugLogger.instance
              .printInfo('DIFF: Downloading layout [$layoutID]...', name: name);
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
          DebugLogger.instance
              .printInfo('DIFF: Deleting font [$fontID]...', name: name);
          localModel.fonts.remove(fontID);
          localDataRepository.deleteFontBytes(
            fontID: fontID,
            source: config.publishSource,
          );
        case UpdateType.add:
        case UpdateType.update:
          DebugLogger.instance
              .printInfo('DIFF: Downloading font [$fontID]...', name: name);
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
          DebugLogger.instance
              .printInfo('DIFF: Deleting api [$apiId]...', name: name);
          localModel.apis.remove(apiId);
          localDataRepository.deletePublishApi(
            apiId: apiId,
            source: config.publishSource,
          );
        case UpdateType.add:
        case UpdateType.update:
          DebugLogger.instance
              .printInfo('DIFF: Downloading api [$apiId]...', name: name);
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
          DebugLogger.instance.printInfo(
              'DIFF: Deleting variables for layout [$layoutId]...',
              name: name);
          localModel.variables.remove(layoutId);
          localDataRepository.deletePublishVariables(
            layoutID: layoutId,
            source: config.publishSource,
          );
        case UpdateType.add:
        case UpdateType.update:
          DebugLogger.instance.printInfo(
              'DIFF: Downloading variables for layout [$layoutId]...',
              name: name);
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
          DebugLogger.instance.printInfo(
              'DIFF: Deleting conditions for layout [$layoutID]...',
              name: name);
          localModel.variables.remove(layoutID);
          localDataRepository.deletePublishConditions(
            layoutID: layoutID,
            source: config.publishSource,
          );
        case UpdateType.add:
        case UpdateType.update:
          DebugLogger.instance.printInfo(
              'DIFF: Downloading conditions for layout [$layoutID]...',
              name: name);
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

    DebugLogger.instance
        .printInfo('DIFF: Done processing updates.', name: name);
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
  ///
  /// - If a layout existed in the previous model, but was disabled in the
  /// updated model, it is marked as deleted.
  ///
  /// - If a layout existed in the previous model, but was enabled in the
  /// updated model, it is marked as added.
  Map<String, UpdateType> _collectLayoutUpdates({
    required SDKPublishModel serverModel,
    required SDKPublishModel localModel,
  }) {
    final Map<String, DateTime> serverLayouts = serverModel.updates.layouts;
    final Map<String, DateTime> localLayouts = localModel.updates.layouts;
    final Map<String, UpdateType> layoutUpdates = {};

    // Check for deleted layouts.
    for (final String layoutID in localLayouts.keys) {
      if (!serverLayouts.containsKey(layoutID)) {
        layoutUpdates[layoutID] = UpdateType.delete;
      }
    }

    // Check for added or updated layouts.
    for (final String layoutID in serverLayouts.keys) {
      if (!localLayouts.containsKey(layoutID)) {
        layoutUpdates[layoutID] = UpdateType.add;
      } else {
        final DateTime lastUpdated = localLayouts[layoutID]!;
        final DateTime newlyUpdated = serverLayouts[layoutID]!;

        // Check if the publish date is after the last updated date.
        if (newlyUpdated.isAfter(lastUpdated)) {
          layoutUpdates[layoutID] = UpdateType.update;
        }
        // Check if the layout got enabled to add it.
        else if (!serverModel.disabledLayouts.contains(layoutID) &&
            localModel.disabledLayouts.contains(layoutID)) {
          layoutUpdates[layoutID] = UpdateType.add;
        }
        // Check if the layout got disabled to remove it.
        else if (serverModel.disabledLayouts.contains(layoutID) &&
            !localModel.disabledLayouts.contains(layoutID)) {
          layoutUpdates[layoutID] = UpdateType.delete;
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
      DebugLogger.instance.printInfo(
          '[queueLayout] No longer queuing. Downloading layout [$layoutID] immediately...',
          name: name);
      try {
        await getOrFetchPopulatedLayout(layoutID: layoutID);
        DebugLogger.instance.printInfo(
            '[queueLayout] Layout [$layoutID] download complete.',
            name: name);
      } catch (e, str) {
        DebugLogger.instance.log(
          '[queueLayout] Layout [$layoutID] failed to download immediately.\nError: $e',
          category: DebugCategory.error,
          name: name,
          level: Level.WARNING,
        );
        final exception = CodelesslyException(
          'Failed to download layout [$layoutID].',
          originalException: e,
          stacktrace: str,
          layoutID: layoutID,
          type: ErrorType.layoutFailed,
        );
        errorHandler.captureException(exception, stacktrace: str);
      }
    } else {
      if (_downloadQueue.contains(layoutID)) {
        if (prioritize) {
          if (_downloadQueue.first == layoutID) {
            DebugLogger.instance.printInfo(
                '[queueLayout] Layout [$layoutID] is already at the front of the queue. Skipping.',
                name: name);
            return;
          } else {
            DebugLogger.instance.printInfo(
                '[queueLayout] Layout [$layoutID] is already in the queue. Moving it to the front to prioritize it.',
                name: name);
            _downloadQueue.remove(layoutID);
          }
        } else {
          DebugLogger.instance.printInfo(
              '[queueLayout] Layout [$layoutID] is already in the queue. Skipping.',
              name: name);
          return;
        }
      }

      if (prioritize) {
        DebugLogger.instance.printInfo(
            '[queueLayout] Prioritizing this layout. Inserting [$layoutID] to the front of the queue.',
            name: name);
        _downloadQueue.insert(0, layoutID);
      } else {
        DebugLogger.instance.printInfo(
            '[queueLayout] Adding [$layoutID] to the back of the queue.',
            name: name);
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
    DebugLogger.instance.printFunction(
      'getOrFetchPopulatedLayout(layoutID: $layoutID)',
      name: name,
    );

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
      DebugLogger.instance.printInfo(
          '\tLayout [$layoutID] is already cached. Skipping download.',
          name: name);
      layout = model.layouts[layoutID];
    } else {
      DebugLogger.instance.printInfo(
          '\tLayout [$layoutID] is not cached. Downloading...',
          name: name);
      layout = await networkDataRepository.downloadLayoutModel(
        layoutID: layoutID,
        projectID: auth.projectId,
        source: config.publishSource,
      );
      if (layout == null) {
        DebugLogger.instance.printInfo(
            '\tLayout [$layoutID] could not be downloaded.',
            name: name);
        return false;
      } else {
        DebugLogger.instance.printInfo(
            '\tLayout [$layoutID] downloaded successfully.',
            name: name);
      }

      model.layouts[layoutID] = layout;
    }

    assert(layout != null, 'Layout should not be null at this point.');

    // Process APIs
    if (model.updates.layoutApis.containsKey(layoutID)) {
      DebugLogger.instance.printInfo(
          '\tLayout [$layoutID] has ${model.updates.layoutApis[layoutID]!.length} apis.',
          name: name);
      final Set<Future<HttpApiData?>> apiModels = getOrFetchApis(
        apiIds: model.updates.layoutApis[layoutID]!,
      );

      final List<HttpApiData?> results =
          await Future.wait(apiModels.map((future) async {
        try {
          return await future;
        } catch (e, stacktrace) {
          DebugLogger.instance.log(
            'Error while fetching apis.\nError: $e',
            category: DebugCategory.error,
            name: name,
            level: Level.WARNING,
          );
          return null;
        }
      }));

      for (final api in results) {
        if (api == null) continue;
        model.apis[api.id] = api;
      }
    } else {
      DebugLogger.instance
          .printInfo('\tLayout [$layoutID] has no apis.', name: name);
    }

    // Process Variables
    if (model.updates.variables.containsKey(layoutID)) {
      DebugLogger.instance
          .printInfo('\tLayout [$layoutID] has variables.', name: name);
      try {
        final SDKLayoutVariables? variables =
            await getOrFetchVariables(layoutID);
        if (variables != null) {
          model.variables[layoutID] = variables;
        }
      } catch (e, stacktrace) {
        DebugLogger.instance.log(
          'Error while fetching variables.\nError: $e',
          category: DebugCategory.error,
          name: name,
          level: Level.WARNING,
        );
      }
    } else {
      DebugLogger.instance
          .printInfo('Layout [$layoutID] has no variables.', name: name);
    }

    // Process Conditions
    if (model.updates.conditions.containsKey(layoutID)) {
      DebugLogger.instance
          .printInfo('\tLayout [$layoutID] has conditions.', name: name);
      try {
        final SDKLayoutConditions? conditions =
            await getOrFetchConditions(layoutID);
        if (conditions != null) {
          model.conditions[layoutID] = conditions;
        }
      } catch (e, stacktrace) {
        DebugLogger.instance.log(
          'Error while fetching conditions.\nError: $e',
          category: DebugCategory.error,
          name: name,
          level: Level.WARNING,
        );
      }
    } else {
      DebugLogger.instance
          .printInfo('\tLayout [$layoutID] has no conditions.', name: name);
    }

    await emitPublishModel();
    savePublishModel();

    DebugLogger.instance
        .printInfo('\tLayout [$layoutID] ready, time for fonts...', name: name);

    // Process Fonts
    if (model.updates.layoutFonts.containsKey(layoutID)) {
      DebugLogger.instance.printInfo(
          '\tLayout [$layoutID] has ${model.updates.layoutFonts[layoutID]!.length} fonts.',
          name: name);

      // Download or load fonts in the background.
      getOrFetchFontModels(
        fontIDs: model.updates.layoutFonts[layoutID]!,
      ).then((Set<SDKPublishFont> fontModels) async {
        DebugLogger.instance.printInfo(
            '\tFound ${fontModels.length} fonts to fetch for layout [$layoutID].',
            name: name);

        for (final SDKPublishFont fontModel in fontModels) {
          DebugLogger.instance.printInfo(
              '\t\tFontModel [${fontModel.id}] ready. Fetching bytes & loading...',
              name: name);

          model.fonts[fontModel.id] = fontModel;

          await getOrFetchFontBytesAndSaveAndLoad(fontModel).then((_) {
            DebugLogger.instance.printInfo(
                '\t\tFontModel [${fontModel.id}] loaded. Done!\n',
                name: name);
          });
        }
      }).catchError((error, stack) {
        DebugLogger.instance.log(
          'Error while fetching fonts.\nError: $error',
          category: DebugCategory.error,
          name: name,
          level: Level.WARNING,
        );
      });
    } else {
      DebugLogger.instance
          .printInfo('\tLayout [$layoutID] has no fonts.', name: name);
    }

    tracker.trackPopulatedLayoutDownload(layoutID);
    return true;
  }

  Future<bool> fetchCompletePublishBundle({
    required String slug,
    required PublishSource source,
  }) async {
    DebugLogger.instance.printFunction(
      'fetchCompletePublishBundle(slug: $slug, source: $source)',
      name: name,
    );

    final Stopwatch stopwatch = Stopwatch()..start();

    SDKPublishModel? model;
    try {
      model = await networkDataRepository.downloadCompletePublishBundle(
        slug: slug,
        source: source,
      );
    } catch (e) {
      DebugLogger.instance.log(
        'Failed to download complete publish bundle.\nError: $e',
        category: DebugCategory.error,
        name: name,
        level: Level.WARNING,
      );
      rethrow;
    } finally {
      stopwatch.stop();
      DebugLogger.instance.printInfo(
          'Publish bundle download stopwatch done in ${stopwatch.elapsedMilliseconds}ms or ${stopwatch.elapsed.inSeconds}s.',
          name: name);
    }

    if (model != null) {
      DebugLogger.instance.printInfo(
          'Successfully downloaded complete publish bundle. Emitting it.',
          name: name);
      _publishModel = model;
      await emitPublishModel();
      savePublishModel();
      return true;
    }

    DebugLogger.instance.printInfo(
        'Failed to download complete publish bundle in ${stopwatch.elapsedMilliseconds}ms or ${stopwatch.elapsed.inSeconds}s.',
        name: name);
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
    DebugLogger.instance.printInfo(
        '[FLUTTER] Loading font [${font.id}](${font.fullFontName}) into Flutter framework.',
        name: name);
    final FontLoader fontLoader = FontLoader(font.fullFontName);

    fontLoader.addFont(Future.value(ByteData.view(fontBytes.buffer)));

    return fontLoader.load().then((_) {
      DebugLogger.instance.printInfo(
          '[FLUTTER] Successfully loaded font [${font.id}](${font.fullFontName}) into Flutter framework.',
          name: name);
    });
  }

  /// Given a [font], will fetch its bytes either from cache or download & save
  /// them.
  Future<Uint8List?> getOrFetchFontBytesAndSave(SDKPublishFont font) async {
    DebugLogger.instance.printInfo(
        '\t\tChecking bytes for [${font.id}](${font.fullFontName}).',
        name: name);
    final Uint8List? fontBytes = localDataRepository.fetchFontBytes(
      fontID: font.id,
      source: config.publishSource,
    );
    if (fontBytes != null) {
      DebugLogger.instance
          .printInfo('\t\tFont [${font.id}] bytes already cached.', name: name);
      return Future.value(fontBytes);
    } else {
      DebugLogger.instance.printInfo(
          '\t\tFont [${font.id}] bytes not cached. Downloading...',
          name: name);
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
          DebugLogger.instance.printInfo(
              '\t\tFont [$fontID] could not be downloaded.',
              name: name);
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
