import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codelessly_api/codelessly_api.dart';
import 'package:collection/collection.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';

import '../codelessly_sdk.dart';
import 'logging/reporter.dart';

typedef NavigationListener = void Function(BuildContext context);
typedef BreakpointsListener = void Function(
    BuildContext context, Breakpoint breakpoint);

/// The entry point for accessing the Codelessly SDK.
///
/// Usage:
///
///   // Initialize SDK
///   Codelessly.instance.initialize(config: CodelesslyConfig(authToken: XXX));
///
///   // Get global instance
///   Codelessly.instance;
///
/// Look at [CodelesslyConfig] for more information on available configuration
/// options.
class Codelessly {
  /// Internal singleton instance
  static final Codelessly _instance = Codelessly();

  /// Returns the global singleton instance of the SDK.
  /// Initialization is needed before usage.
  static Codelessly get instance => _instance;

  CodelesslyConfig? _config;

  /// Returns the configuration options provided to this SDK.
  CodelesslyConfig? get config => _config;

  AuthManager? _authManager;

  /// Returns the authentication manager that is responsible for managing
  /// auth token validation and project ID retrieval.
  AuthManager get authManager => _authManager!;

  DataManager? _publishDataManager;

  /// Returns the data manager that is responsible for retrieving layout
  /// information from the Codelessly servers or the local device's cache.
  DataManager get publishDataManager => _publishDataManager!;

  DataManager? _previewDataManager;

  /// Returns the data manager that is responsible for retrieving layout
  /// information from the Codelessly servers or the local device's cache.
  ///
  /// The difference between [publishDataManager] and [previewDataManager] is
  /// that the preview data manager will retrieve the preview versions of
  /// layouts.
  DataManager get previewDataManager => _previewDataManager!;

  DataManager? _templateDataManager;

  /// Returns the data manager that is responsible for retrieving layout
  /// information from the Codelessly servers or the local device's cache.
  ///
  /// The difference between [publishDataManager] and [templateDataManager] is
  /// that the template data manager will retrieve the template versions of
  /// layouts.
  DataManager get templateDataManager => _templateDataManager!;

  CacheManager? _cacheManager;

  /// Returns the cache manager that is responsible for providing an interface
  /// to the local device's cache.
  CacheManager get cacheManager => _cacheManager!;

  CodelesslyErrorHandler? _errorHandler;

  /// Returns the error handler that is responsible for capturing and reporting
  /// errors to the Codelessly servers for this instance of the SDK.
  CodelesslyErrorHandler get errorHandler => _errorHandler!;

  FirebaseApp? _firebaseApp;
  FirebaseFirestore? _firebaseFirestore;
  FirebaseAuth? _firebaseAuth;

  /// A helper getter to retrieve the active [DataManager] based on the
  /// [PublishSource] provided by the [CodelesslyConfig].
  DataManager get dataManager => switch (config!.publishSource) {
        PublishSource.publish => publishDataManager,
        PublishSource.preview => previewDataManager,
        PublishSource.template => templateDataManager,
      };

  /// Returns the local instance of the Firebase SDK that this instance of the
  /// Codelessly SDK is using.
  FirebaseApp get firebaseApp => _firebaseApp!;

  /// Returns the local instance of the Firestore SDK. Used by the data manager
  /// to retrieve server data.
  FirebaseFirestore get firebaseFirestore => _firebaseFirestore!;

  /// Returns the local instance of the FirebaseAuth SDK. Used by the auth
  /// manager to retrieve auth data.
  FirebaseAuth get firebaseAuth => _firebaseAuth!;

  /// Whether this Codelessly instance already initialized firebase or not.
  bool _didInitializeFirebase = false;

  /// A map of data that is passed to loaded layouts for nodes to replace their
  /// property values with.
  final Map<String, dynamic> data = {};

  /// A map of functions that is passed to loaded layouts for nodes to call
  /// when they are triggered.
  final Map<String, CodelesslyFunction> functions = {};

  CStatus _status = CStatus.empty();

  /// Returns the current status of this SDK instance.
  CStatus get status => _status;

  final StreamController<CStatus> _statusStreamController =
      StreamController.broadcast()..add(CStatus.empty());

  final StatTracker _tracker = CodelesslyStatTracker();

  /// Tracks statistics of various operations in the SDK.
  StatTracker get tracker => _tracker;

  /// Returns a stream of status updates for this SDK instance.
  Stream<CStatus> get statusStream => _statusStreamController.stream;

  /// Provides access to the local storage of this SDK instance.
  LocalDatabase get localDatabase => dataManager.localDatabase;

  /// Provides access to the cloud storage of this SDK instance.
  /// If it is null, it means it has not yet been initialized.
  CloudDatabase? get cloudDatabase => dataManager.cloudDatabase;

  final List<NavigationListener> _navigationListeners = [];

  final List<BreakpointsListener> _breakpointsListeners = [];

  /// Creates a new instance of [Codelessly].
  Codelessly({
    CodelesslyConfig? config,

    // Optional data and functions.
    Map<String, String>? data,
    Map<String, CodelesslyFunction>? functions,

    // Optional managers.
    CacheManager? cacheManager,
    AuthManager? authManager,
    DataManager? publishDataManager,
    DataManager? previewDataManager,
    DataManager? templateDataManager,
  }) {
    _config = config;
    _cacheManager = cacheManager;
    _authManager = authManager;
    _publishDataManager = publishDataManager;
    _previewDataManager = previewDataManager;
    _templateDataManager = templateDataManager;

    // Set data and functions.
    if (data != null) {
      this.data.addAll(data);
    }

    if (functions != null) {
      this.functions.addAll(functions);
    }

    // If the config is not null, update the status to configured.
    if (_config != null) {
      _updateStatus(CStatus.configured());
    }
  }

  void log(
    String message, {
    bool largePrint = false,
  }) =>
      logger.log(
        'Codelessly SDK',
        message,
        largePrint: largePrint,
      );

  void logError(
    String message, {
    required Object? error,
    required StackTrace? stackTrace,
  }) =>
      logger.error(
        'Codelessly SDK',
        message,
        error: error,
        stackTrace: stackTrace,
      );

  /// Disposes this instance of the SDK permanently along with all of its
  /// managers.
  ///
  /// If [sealCache] is true, the cacheManager will be reset instead of
  /// disposed. This is useful for [CodelesslyCacheManager] to keep the [Hive]
  /// boxes open for other instances of the SDK that are still running.
  void dispose({bool sealCache = true}) {
    log('Disposing SDK. ${sealCache ? 'Sealing cache.' : 'Keeping cache open.'}');
    _status = CStatus.empty();
    _statusStreamController.close();

    if (sealCache) {
      _cacheManager?.dispose();
    }
    _authManager?.dispose();
    _publishDataManager?.dispose();
    _previewDataManager?.dispose();
    _templateDataManager?.dispose();

    _cacheManager = null;
    _authManager = null;
    _publishDataManager = null;
    _previewDataManager = null;
    _config = null;
    _navigationListeners.clear();
  }

  /// Resets the state of the SDK. This is useful for resetting the data without
  /// disposing the instance permanently.
  ///
  /// This does not close the status stream, and instead sets the SDK back to
  /// idle mode.
  FutureOr<void> reset({bool clearCache = false}) async {
    log('Resetting SDK. ${clearCache ? 'Clearing cache.' : 'Keeping cache.'}');
    _cacheManager?.reset();
    _publishDataManager?.reset();
    _previewDataManager?.reset();
    _templateDataManager?.reset();
    _authManager?.reset();

    _status = config == null ? CStatus.empty() : CStatus.configured();
    _statusStreamController.add(_status);

    if (clearCache) {
      try {
        await _cacheManager?.clearAll();
      } catch (e, str) {
        logError(
          'Error clearing cache.',
          error: e,
          stackTrace: str,
        );
      }

      try {
        await _cacheManager?.deleteAllByteData();
      } catch (e, str) {
        logError(
          'Error deleting cached bytes.',
          error: e,
          stackTrace: str,
        );
      }
    }
  }

  /// Internally updates the status of this instance of the SDK and emits a
  /// status update event to the [statusStream].
  void _updateStatus(CStatus status) {
    if (_status == status) {
      return;
    }
    _status = status;
    _statusStreamController.add(_status);
  }

  /// Configures this instance of the SDK with the provided configuration
  /// options. This will mark the SDK as ready to be initialized.
  ///
  /// This function can be used to lazily initialize the SDK. Layouts and fonts
  /// will only be downloaded and cached when [initialize] is called.
  ///
  /// Calling [initialize] directly without calling this function first
  /// immediately configures and initializes the SDK.
  ///
  /// If the [CodelesslyWidget] recognizes that this instance of the
  /// SDK is the global instance rather than a local one, it will
  /// configure and initialize the SDK automatically via its widget's
  /// constructor parameters.
  CStatus configure({
    CodelesslyConfig? config,

    // Optional data and functions.
    Map<String, String>? data,
    Map<String, CodelesslyFunction>? functions,

    // Optional managers.
    CacheManager? cacheManager,
    AuthManager? authManager,
    DataManager? publishDataManager,
    DataManager? previewDataManager,
    DataManager? templateDataManager,
  }) {
    _config ??= config;

    initErrorHandler(
      automaticallySendCrashReports: _config!.automaticallySendCrashReports,
    );

    assert(
      status is! CEmpty,
      'The SDK cannot be configured if it is not idle. '
      'Consider calling [Codelessly.dispose] before reconfiguring.',
    );

    if (cacheManager != null) {
      _cacheManager?.dispose();
      _cacheManager = cacheManager;
    }
    if (authManager != null) {
      _authManager?.dispose();
      _authManager = authManager;
    }
    if (publishDataManager != null) {
      _publishDataManager?.dispose();
      _publishDataManager = publishDataManager;
    }
    if (previewDataManager != null) {
      _previewDataManager?.dispose();
      _previewDataManager = previewDataManager;
    }
    if (templateDataManager != null) {
      _templateDataManager?.dispose();
      _templateDataManager = templateDataManager;
    }

    if (data != null) {
      this.data.addAll(data);
    }
    if (functions != null) {
      this.functions.addAll(functions);
    }

    _updateStatus(CStatus.configured());
    return status;
  }

  /// Initializes the internal Firebase instance used by this SDK.
  /// This will only fully run once if the [FirebaseApp] instance is not already
  /// initialized. If it is initialized, this is ignored.
  ///
  /// Instead of initializing firebase directly, we first check if an existing
  /// instance exists with the same [CodelesslyConfig.firebaseInstanceName]
  /// and use that to avoid duplicate initialization.
  Future<void> initFirebase({required CodelesslyConfig config}) async {
    // Early return if Firebase is already initialized. This is important
    // because this function is asynchronous and there may be an attempt at
    // initialization twice.
    if (_didInitializeFirebase) return;

    // Early return if Firebase instances are already initialized
    if (_firebaseFirestore != null &&
        _firebaseAuth != null &&
        _firebaseApp != null) {
      return;
    }

    final String name = config.firebaseInstanceName;
    final FirebaseOptions firebaseOptions = config.firebaseOptions;

    log('Initializing Firebase instance with project ID: [${firebaseOptions.projectId}] and Firebase instance name [$name]');

    final Stopwatch stopwatch = Stopwatch()..start();
    try {
      // If no [DEFAULT] firebase app is initialized, the entire Firebase SDK
      // will crash. To avoid this, we initialize the default app with the
      // provided configuration.
      try {
        // Initialize default app if no default app exists.
        if (Firebase.apps.isEmpty) {
          _firebaseApp = await Firebase.initializeApp(options: firebaseOptions);
        }
      } catch (e) {
        // On web, Firebase.apps crashes with error [core/not-initialized] if
        // the list is empty and no app is registered. Catch the error here and ignore it.
        _firebaseApp = await Firebase.initializeApp(options: firebaseOptions);
      } finally {
        if (_firebaseApp != null) {
          log(
            'Firebase default app not initialized. Call Firebase.initializeApp() before initializing the CodelesslySDK.',
            largePrint: true,
          );
        }
      }

      if (_firebaseApp != null) {
        // Initialize Firestore and FirebaseAuth instances.
        _firebaseFirestore = FirebaseFirestore.instanceFor(app: _firebaseApp!);
        _firebaseAuth = FirebaseAuth.instanceFor(app: _firebaseApp!);
        _didInitializeFirebase = true;

        log('Codelessly successfully initialized the default Firebase app.');
        return;
      }

      log('A default Firebase app was found already registered. Checking for an existing [$name] Firebase app.');

      FirebaseApp? existingApp;

      // Check if an existing Firebase app instance can be reused.
      //
      // This code is only run if a default Firebase app was already registered.
      // Otherwise, calling Firebase.apps crashes on web.
      existingApp = Firebase.apps.firstWhereOrNull((app) => app.name == name);

      if (existingApp != null) {
        log('Found an existing Firebase app instance with name: [$name]. Using it.');
        _firebaseApp = existingApp;
      } else {
        // Create a new Firebase app instance if none exists
        log('No existing Firebase app instance found with name: [$name]. Registering a new one.');
        _firebaseApp =
            await Firebase.initializeApp(name: name, options: firebaseOptions);
      }

      // Initialize Firestore and FirebaseAuth instances.
      _firebaseFirestore = FirebaseFirestore.instanceFor(app: _firebaseApp!);
      _firebaseAuth = FirebaseAuth.instanceFor(app: _firebaseApp!);

      _didInitializeFirebase = true;

      log('Firebase instance initialized successfully [${_firebaseApp?.name}].');
    } catch (e, str) {
      initErrorHandler(
        automaticallySendCrashReports: false,
      );
      errorHandler.captureException(
        e,
        stacktrace: str,
      );
    }

    stopwatch.stop();
    log('Firebase initialized in ${stopwatch.elapsed.inMilliseconds}ms or ${stopwatch.elapsed.inSeconds}s');
  }

  /// Initializes the internal Firestore instance used by this SDK and
  /// configures the error handler to use it.
  ///
  /// This will only fully run once if the [Firestore] instance is not already
  /// initialized. If it is initialized, this is ignored.
  ///
  /// If the SDK is running on web platform, this will be ignored.
  void initErrorHandler({
    required bool automaticallySendCrashReports,
  }) {
    if (_errorHandler != null) return;

    _errorHandler = CodelesslyErrorHandler(
      reporter: automaticallySendCrashReports
          ? FirestoreErrorReporter(_firebaseApp!, _firebaseFirestore!)
          : null,
      onException: (CodelesslyException exception) {
        // Layout errors are not SDK errors.
        if (exception.layoutID != null) {
          return;
        }
        _updateStatus(CStatus.error(exception));
        log('Error received. Status is now $status');
      },
    );
  }

  /// Initializes this instance of the SDK.
  ///
  /// To know when the SDK is ready, simply listen to the status events from
  /// [statusStream]. There's no need to await the future.
  ///
  /// If the [CodelesslyWidget] recognizes that this instance of the
  /// SDK is the global instance rather than a local one, it will
  /// configure and/or initialize the SDK automatically via its widget's
  /// constructor parameters, if specified.
  Future<CStatus> initialize({
    CodelesslyConfig? config,

    // Optional data and functions.
    Map<String, dynamic>? data,
    Map<String, CodelesslyFunction>? functions,

    // Optional managers.
    CacheManager? cacheManager,
    AuthManager? authManager,
    DataManager? publishDataManager,
    DataManager? previewDataManager,
    DataManager? templateDataManager,
    bool initializeDataManagers = true,
  }) async {
    if (_status is CLoading) {
      return _status;
    }

    _updateStatus(CStatus.loading(CLoadingState.initializing));

    if (config != null) {
      _config = config;
    }

    assert(
      _config != null,
      'The SDK cannot be initialized without a configuration. '
      'Make sure you are correctly passing a [CodelesslyConfig] to the SDK.',
    );

    log('Initializing Codelessly with firebase project ID: ${_config!.firebaseOptions.projectId}');
    log('Cloud Functions Base URL: ${_config!.firebaseCloudFunctionsBaseURL}');

    final Stopwatch stopwatch = Stopwatch()..start();

    await initFirebase(config: _config!);

    initErrorHandler(
      automaticallySendCrashReports: _config!.automaticallySendCrashReports,
    );

    try {
      _updateStatus(CStatus.loading(CLoadingState.initializedFirebase));

      // Clean up.
      if (cacheManager != null) _cacheManager?.dispose();
      if (authManager != null) _authManager?.dispose();
      if (publishDataManager != null) _publishDataManager?.dispose();
      if (previewDataManager != null) _previewDataManager?.dispose();
      if (templateDataManager != null) _templateDataManager?.dispose();
      if (data != null) this.data.addAll(data);
      if (functions != null) this.functions.addAll(functions);

      // Create the cache manager.
      _cacheManager = cacheManager ?? CodelesslyCacheManager(config: _config!);

      // Create the auth manager.
      _authManager = authManager ??
          CodelesslyAuthManager(
            config: _config!,
            cacheManager: _cacheManager!,
            firebaseAuth: _firebaseAuth!,
            errorHandler: errorHandler,
          );

      // Create the publish data manager.
      _publishDataManager = publishDataManager ??
          DataManager(
            'Publish',
            config: _config!.copyWith(isPreview: false),
            cacheManager: _cacheManager!,
            authManager: _authManager!,
            networkDataRepository: FirebaseDataRepository(
              firestore: firebaseFirestore,
              tracker: tracker,
              config: _config!,
            ),
            localDataRepository: LocalDataRepository(
              cacheManager: _cacheManager!,
            ),
            firebaseFirestore: firebaseFirestore,
            errorHandler: errorHandler,
            tracker: tracker,
          );

      // Create the preview data manager.
      _previewDataManager = previewDataManager ??
          DataManager(
            'Preview',
            config: _config!.copyWith(isPreview: true),
            cacheManager: _cacheManager!,
            authManager: _authManager!,
            networkDataRepository: FirebaseDataRepository(
              firestore: firebaseFirestore,
              config: _config!,
              tracker: tracker,
            ),
            localDataRepository: LocalDataRepository(
              cacheManager: _cacheManager!,
            ),
            firebaseFirestore: firebaseFirestore,
            errorHandler: errorHandler,
            tracker: tracker,
          );

      // Create the template data manager. This is always automatically
      // created.
      _templateDataManager = templateDataManager ??
          DataManager(
            'Template',
            config: _config!.copyWith(
              isPreview: false,
              publishSource: PublishSource.template,
            ),
            cacheManager: _cacheManager!,
            authManager: _authManager!,
            networkDataRepository: FirebaseDataRepository(
              firestore: firebaseFirestore,
              config: _config!,
              tracker: tracker,
            ),
            localDataRepository: LocalDataRepository(
              cacheManager: _cacheManager!,
            ),
            firebaseFirestore: firebaseFirestore,
            errorHandler: errorHandler,
            tracker: tracker,
          );

      _updateStatus(CStatus.loading(CLoadingState.createdManagers));

      log('Initializing cache manager');
      // The cache manager initializes first to load the local cache.
      await _cacheManager!.init();

      _updateStatus(CStatus.loading(CLoadingState.initializedCache));

      // The auth manager initializes second to look up cached auth data
      // from the cache manager. If no auth data is available, it halts the
      // entire process and awaits to authenticate with the server.
      //
      // After either of those is done, the relevant auth data is immediately
      // emitted to the internal stream controller, ready for immediate usage.
      //
      // If the slug is specified, the SDK can skip all authentication and
      // immediately jump to loading the data manager.
      if (_config!.slug == null) {
        log('Initializing auth manager.');
        await _authManager!.init();
        _config!.publishSource = _authManager!.getBestPublishSource(_config!);

        if (_authManager?.authData?.projectId case String projectId) {
          tracker.init(
            projectId: projectId,
            serverUrl: Uri.parse(_config!.firebaseCloudFunctionsBaseURL),
          );
        }

        _updateStatus(CStatus.loading(CLoadingState.initializedAuth));
      } else {
        log('A slug was provided. Acutely skipping authentication.');
      }

      // The data manager initializes last to load the last stored publish
      // model, or, if it doesn't exist, halts the entire process and awaits
      // to fetch the latest publish model from the server.
      //
      // The config sets the default data manager to initialize. If the
      // [CodelesslyWidget] wants to load the opposite manager, the other will
      // lazily initialize.
      if (initializeDataManagers &&
          (_config!.preload || _config!.slug != null)) {
        log(
          'Initializing data managers with publish source '
          '${_config!.publishSource}'
          ' ${_config!.slug != null ? 'and slug ${_config!.slug}' : ''}',
        );

        if (dataManager.status is! CLoaded && dataManager.status is! CLoaded) {
          await dataManager.init(layoutID: null);
        }

        log('Data manager initialized.');
        _updateStatus(CStatus.loading(CLoadingState.initializedDataManagers));
      } else {
        if (!initializeDataManagers) {
          log(
            'Skipping data manager loading because [initializeDataManagers] is set to false.',
          );
        } else {
          log(
            'Skipping data manager loading because preload is ${_config!.preload} & slug is ${_config!.slug}.',
          );
        }
      }

      // If the slug is specified, the SDK can skip all authentication for
      // initial layout as it will use the slug to fetch a complete publish
      // bundle. After that though, we can safely authenticate in the
      // background to keep listening for updates to the publish model.
      if (_config!.slug != null) {
        log('Since a slug was provided & data manager finished, authenticating in the background...');
        _authManager!.init().then((_) async {
          if (_authManager!.authData == null) return;

          if (_authManager?.authData?.projectId case String projectId) {
            tracker.init(
              projectId: projectId,
              serverUrl: Uri.parse(_config!.firebaseCloudFunctionsBaseURL),
            );
          }

          log('[POST-INIT] Background authentication succeeded. Initializing layout storage.');
          await dataManager
              .onPublishModelLoaded(_authManager!.authData!.projectId);

          log('[POST-INIT] Layout storage initialized. Listening to publish model.');
          dataManager.listenToPublishModel(_authManager!.authData!.projectId);
        }).catchError((e, str) {
          log('[POST-INIT] Background authentication failed.');
          errorHandler.captureException(
            e,
            stacktrace: str,
          );
        });
        _updateStatus(CStatus.loading(CLoadingState.initializedSlug));
      }

      log('Codelessly ${_instance == this ? 'global' : 'local'} instance initialization complete.');

      _updateStatus(CStatus.loaded());
    } catch (error, stacktrace) {
      errorHandler.captureException(
        error,
        stacktrace: stacktrace,
      );
    } finally {
      stopwatch.stop();
      log('Initialization took ${stopwatch.elapsedMilliseconds}ms or ${stopwatch.elapsed.inSeconds}s');
    }

    return _status;
  }

  /// Calls navigation listeners when navigation happens.
  /// Provided [context] must be of the destination widget. This context
  /// can be used to retrieve new [CodelesslyContext].
  void notifyNavigationListeners(BuildContext context) {
    _navigationListeners.forEach((listener) => listener(context));
  }

  /// Adds a global listener for navigation.
  void addNavigationListener(NavigationListener callback) {
    if (!_navigationListeners.contains(callback)) {
      _navigationListeners.add(callback);
    }
  }

  /// Removes a global navigation listener.
  void removeNavigationListener(NavigationListener callback) {
    _navigationListeners.remove(callback);
  }

  /// Calls navigation listeners when navigation happens.
  /// Provided [context] must be of the destination widget. This context
  /// can be used to retrieve new [CodelesslyContext].
  void notifyBreakpointsListener(BuildContext context, Breakpoint breakpoint) {
    _breakpointsListeners.forEach((listener) => listener(context, breakpoint));
  }

  /// Adds a global listener for navigation.
  void addBreakpointsListener(BreakpointsListener callback) {
    if (!_breakpointsListeners.contains(callback)) {
      _breakpointsListeners.add(callback);
    }
  }

  /// Removes a global navigation listener.
  void removeBreakpointsListener(BreakpointsListener callback) {
    _breakpointsListeners.remove(callback);
  }
}
