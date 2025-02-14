import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codelessly_api/codelessly_api.dart';
import 'package:collection/collection.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart';

import '../codelessly_sdk.dart';
import 'logging/debug_logger.dart';
import 'logging/error_logger.dart';
import 'logging/stat_tracker.dart';
import 'utils/codelessly_http_client.dart';

typedef NavigationListener = void Function(
  BuildContext context,
  String? layoutId,
  String? canvasId,
);

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
  static const String name = 'Codelessly';

  /// Internal singleton instance
  static final Codelessly _instance = Codelessly();

  /// Returns the global singleton instance of the SDK.
  /// Initialization is needed before usage.
  static Codelessly get instance => _instance;

  final Client _client = CodelesslyHttpClient();

  /// Returns the HTTP client used by this SDK instance.
  Client get client => _client;

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

  ErrorLogger? _errorLogger;

  /// Returns the error logger that is responsible for capturing and reporting
  /// errors to the Codelessly servers for this instance of the SDK.
  ErrorLogger get errorLogger => _errorLogger!;

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

  /// Sets the status of this SDK instance and emits a status update event.
  set status(CStatus newStatus) {
    if (_status == newStatus) {
      return;
    }
    _status = newStatus;
    _statusStreamController.add(_status);
  }

  final StreamController<CStatus> _statusStreamController =
      StreamController.broadcast()..add(CStatus.empty());

  /// Returns a stream of status updates for this SDK instance.
  Stream<CStatus> get statusStream => _statusStreamController.stream;

  /// Provides access to the local storage of this SDK instance.
  LocalDatabase get localDatabase => dataManager.localDatabase;

  /// Provides access to the cloud storage of this SDK instance.
  /// If it is null, it means it has not yet been initialized.
  CloudDatabase? get cloudDatabase => dataManager.cloudDatabase;

  // TODO(Saad): Move to [CodelesslyContext]
  String? _currentNavigatedLayoutId;

  String? get currentNavigatedLayoutId => _currentNavigatedLayoutId;

  // TODO(Saad): Move to [CodelesslyContext]
  String? _currentNavigatedCanvasId;

  String? get currentNavigatedCanvasId => _currentNavigatedCanvasId;

  final Map<String, NavigationListener> _navigationListeners = {};

  final Map<String, BreakpointsListener> _breakpointsListeners = {};

  final StreamController<BrightnessModel> _systemUIBrightnessStreamController =
      StreamController.broadcast()..add(BrightnessModel.system);

  /// A stream that produces events whenever a canvas node issues a system UI
  /// brightness change. Used for simulation purposes.
  Stream<BrightnessModel> get systemUIBrightnessStream =>
      _systemUIBrightnessStreamController.stream;

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
      status = CStatus.configured();
    }
  }

  /// Disposes this instance of the SDK permanently along with all of its
  /// managers.
  ///
  /// If [sealCache] is true, the cacheManager will be reset instead of
  /// disposed. This is useful for [CodelesslyCacheManager] to keep the [Hive]
  /// boxes open for other instances of the SDK that are still running.
  void dispose({bool sealCache = true}) {
    DebugLogger.instance.printFunction('dispose()', name: name);
    DebugLogger.instance.printInfo(
        'Disposing SDK. ${sealCache ? 'Sealing cache.' : 'Keeping cache open.'}',
        name: name);
    status = CStatus.empty();
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
    _breakpointsListeners.clear();
    _client.close();

    _systemUIBrightnessStreamController.close();
  }

  /// Resets the state of the SDK. This is useful for resetting the data without
  /// disposing the instance permanently.
  ///
  /// This does not close the status stream, and instead sets the SDK back to
  /// idle mode.
  FutureOr<void> reset({bool clearCache = false}) async {
    DebugLogger.instance.printFunction('reset()', name: name);
    DebugLogger.instance.printInfo(
        'Resetting SDK. ${clearCache ? 'Clearing cache.' : 'Keeping cache.'}',
        name: name);
    _cacheManager?.reset();
    _publishDataManager?.reset();
    _previewDataManager?.reset();
    _templateDataManager?.reset();
    _authManager?.reset();

    status = config == null ? CStatus.empty() : CStatus.configured();
    _statusStreamController.add(_status);

    if (clearCache) {
      try {
        await _cacheManager?.clearAll();
      } catch (e, str) {
        ErrorLogger.instance.captureException(
          e,
          message: 'Failed to clear cache',
          type: 'cache_clear_failed',
          stackTrace: str,
        );
      }

      try {
        await _cacheManager?.deleteAllByteData();
      } catch (e, str) {
        ErrorLogger.instance.captureException(
          e,
          message: 'Failed to delete cache',
          type: 'cache_delete_failed',
          stackTrace: str,
        );
      }
    }
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

    initErrorLogger();

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

    status = CStatus.configured();
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
    DebugLogger.instance.printFunction('initFirebase()', name: name);

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

    final String firebaseInstanceName = config.firebaseInstanceName;
    final FirebaseOptions firebaseOptions = config.firebaseOptions;

    DebugLogger.instance.printInfo(
        'Initializing Firebase instance with project ID: [${firebaseOptions.projectId}] and Firebase instance name [$firebaseInstanceName]',
        name: name);

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
          DebugLogger.instance.printInfo(
              'Firebase default app not initialized. Call Firebase.initializeApp() before initializing the CodelesslySDK.',
              name: name);
        }
      }

      if (_firebaseApp != null) {
        // Initialize Firestore and FirebaseAuth instances.
        _firebaseFirestore = FirebaseFirestore.instanceFor(app: _firebaseApp!);
        _firebaseAuth = FirebaseAuth.instanceFor(app: _firebaseApp!);
        _didInitializeFirebase = true;

        DebugLogger.instance.printInfo(
            'Codelessly successfully initialized the default Firebase app.',
            name: name);
        return;
      }

      DebugLogger.instance.printInfo(
          'A default Firebase app was found already registered. Checking for an existing [$firebaseInstanceName] Firebase app.',
          name: name);

      FirebaseApp? existingApp;

      // Check if an existing Firebase app instance can be reused.
      existingApp = Firebase.apps
          .firstWhereOrNull((app) => app.name == firebaseInstanceName);

      if (existingApp != null) {
        DebugLogger.instance.printInfo(
            'Found an existing Firebase app instance with name: [$firebaseInstanceName]. Using it.',
            name: name);
        _firebaseApp = existingApp;
      } else {
        // Create a new Firebase app instance if none exists
        DebugLogger.instance.printInfo(
            'No existing Firebase app instance found with name: [$firebaseInstanceName]. Registering a new one.',
            name: name);
        _firebaseApp = await Firebase.initializeApp(
            name: firebaseInstanceName, options: firebaseOptions);
      }

      // Initialize Firestore and FirebaseAuth instances.
      _firebaseFirestore = FirebaseFirestore.instanceFor(app: _firebaseApp!);
      _firebaseAuth = FirebaseAuth.instanceFor(app: _firebaseApp!);

      _didInitializeFirebase = true;

      DebugLogger.instance.printInfo(
          'Firebase instance initialized successfully [${_firebaseApp?.name}].',
          name: name);
    } catch (e, str) {
      ErrorLogger.instance.captureException(
        e,
        message: 'Failed to initialize Firebase',
        type: 'firebase_init_failed',
        stackTrace: str,
      );
    }

    stopwatch.stop();
    DebugLogger.instance.printInfo(
        'Firebase initialized in ${stopwatch.elapsed.inMilliseconds}ms or ${stopwatch.elapsed.inSeconds}s',
        name: name);
  }

  /// Initializes the internal Firestore instance used by this SDK and
  /// configures the error logger to use it.
  ///
  /// This will only fully run once if the [Firestore] instance is not already
  /// initialized. If it is initialized, this is ignored.
  ///
  /// If the SDK is running on web platform, this will be ignored.
  void initErrorLogger() {
    DebugLogger.instance.printFunction('initErrorLogger()', name: name);
    if (_errorLogger != null) return;

    _errorLogger = ErrorLogger();
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
    DebugLogger.instance.initialize(
      name: name,
      config: DebugLoggerConfig(
        debugLog: config?.debugLog ?? false,
      ),
    );
    DebugLogger.instance.printFunction('initialize()', name: name);

    if (status is CLoading) {
      return status;
    }

    status = CStatus.loading(CLoadingState.initializing);

    if (config != null) {
      _config = config;
    }

    assert(
      _config != null,
      'The SDK cannot be initialized without a configuration. '
      'Make sure you are correctly passing a [CodelesslyConfig] to the SDK.',
    );

    DebugLogger.instance.printInfo(
      'Initializing Codelessly with firebase project ID: ${_config!.firebaseOptions.projectId}',
      name: name,
    );
    DebugLogger.instance.printInfo(
      'Cloud Functions Base URL: ${_config!.firebaseCloudFunctionsBaseURL}',
      name: name,
    );

    final Stopwatch stopwatch = Stopwatch()..start();

    await initFirebase(config: _config!);

    initErrorLogger();

    try {
      status = CStatus.loading(CLoadingState.initializedFirebase);

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
          AuthManager(
            config: _config!,
            cacheManager: _cacheManager!,
            firebaseAuth: _firebaseAuth!,
            client: _client,
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
              config: _config!,
            ),
            localDataRepository: LocalDataRepository(
              cacheManager: _cacheManager!,
            ),
            firebaseFirestore: firebaseFirestore,
            errorLogger: errorLogger,
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
            ),
            localDataRepository: LocalDataRepository(
              cacheManager: _cacheManager!,
            ),
            firebaseFirestore: firebaseFirestore,
            errorLogger: errorLogger,
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
            ),
            localDataRepository: LocalDataRepository(
              cacheManager: _cacheManager!,
            ),
            firebaseFirestore: firebaseFirestore,
            errorLogger: errorLogger,
          );

      status = CStatus.loading(CLoadingState.createdManagers);

      DebugLogger.instance.printInfo(
        'Initializing cache manager',
        name: name,
      );
      await _cacheManager!.init();

      status = CStatus.loading(CLoadingState.initializedCache);

      if (_config!.slug == null) {
        DebugLogger.instance.printInfo(
          'Initializing auth manager.',
          name: name,
        );
        await _authManager!.init();
        _config!.publishSource = _authManager!.getBestPublishSource(_config!);

        if (_authManager?.authData?.projectId case String projectId) {
          StatTracker.instance.init(
            projectId: projectId,
            serverUrl: Uri.parse(
                '${_config!.firebaseCloudFunctionsBaseURL}/api/trackStatsRequest'),
          );
        }

        status = CStatus.loading(CLoadingState.initializedAuth);
      } else {
        DebugLogger.instance.printInfo(
          'A slug was provided. Acutely skipping authentication.',
          name: name,
        );
      }

      if (initializeDataManagers &&
          (_config!.preload || _config!.slug != null)) {
        DebugLogger.instance.printInfo(
          'Initializing data managers with publish source ${_config!.publishSource} ${_config!.slug != null ? 'and slug ${_config!.slug}' : ''}',
          name: name,
        );

        if (dataManager.status is! CLoaded && dataManager.status is! CLoaded) {
          await dataManager.init(layoutID: null);
        }

        DebugLogger.instance.printInfo(
          'Data manager initialized.',
          name: name,
        );
        status = CStatus.loading(CLoadingState.initializedDataManagers);
      } else {
        if (!initializeDataManagers) {
          DebugLogger.instance.printInfo(
            'Skipping data manager loading because [initializeDataManagers] is set to false.',
            name: name,
          );
        } else {
          DebugLogger.instance.printInfo(
            'Skipping data manager loading because preload is ${_config!.preload} & slug is ${_config!.slug}.',
            name: name,
          );
        }
      }

      if (_config!.slug != null) {
        DebugLogger.instance.printInfo(
          'Since a slug was provided & data manager finished, authenticating in the background...',
          name: name,
        );
        _authManager!.init().then((_) async {
          if (_authManager!.authData == null) return;

          if (_authManager?.authData?.projectId case String projectId) {
            StatTracker.instance.init(
              projectId: projectId,
              serverUrl: Uri.parse(
                  '${_config!.firebaseCloudFunctionsBaseURL}/api/trackStatsRequest'),
            );
          }

          DebugLogger.instance.printInfo(
            '[POST-INIT] Background authentication succeeded. Initializing layout storage.',
            name: name,
          );
          await dataManager
              .onPublishModelLoaded(_authManager!.authData!.projectId);

          DebugLogger.instance.printInfo(
            '[POST-INIT] Layout storage initialized. Listening to publish model.',
            name: name,
          );
          dataManager.listenToPublishModel(_authManager!.authData!.projectId);
        }).catchError((e, str) {
          DebugLogger.instance.printInfo(
            '[POST-INIT] Background authentication failed.',
            name: name,
          );
          ErrorLogger.instance.captureException(
            e,
            message: 'Failed to authenticate',
            type: 'authentication_failed',
            stackTrace: str,
          );
        });
        status = CStatus.loading(CLoadingState.initializedSlug);
      }

      DebugLogger.instance.printInfo(
        'Codelessly ${_instance == this ? 'global' : 'local'} instance initialization complete.',
        name: name,
      );

      status = CStatus.loaded();
    } catch (error, stacktrace) {
      ErrorLogger.instance.captureException(
        error,
        message: 'Failed to initialize SDK',
        type: 'sdk_init_failed',
        stackTrace: stacktrace,
      );
    } finally {
      stopwatch.stop();
      DebugLogger.instance.printInfo(
        'Initialization took ${stopwatch.elapsedMilliseconds}ms or ${stopwatch.elapsed.inSeconds}s',
        name: name,
      );
    }

    return status;
  }

  /// Calls navigation listeners when navigation happens.
  /// Provided [context] must be of the destination widget. This context
  /// can be used to retrieve new [CodelesslyContext].
  void notifyNavigationListeners(
    BuildContext context, {
    required String? layoutId,
    required String? canvasId,
  }) {
    _currentNavigatedLayoutId = layoutId;
    _currentNavigatedCanvasId = canvasId;
    for (final listener in [..._navigationListeners.values]) {
      listener(context, layoutId, canvasId);
    }
  }

  /// Adds a global listener for navigation.
  void addNavigationListener(String label, NavigationListener callback) {
    _navigationListeners[label] = callback;
  }

  /// Removes a global navigation listener.
  void removeNavigationListener(String label) {
    _navigationListeners.remove(label);
  }

  /// Calls navigation listeners when navigation happens.
  /// Provided [context] must be of the destination widget. This context
  /// can be used to retrieve new [CodelesslyContext].
  void notifyBreakpointsListeners(BuildContext context, Breakpoint breakpoint) {
    for (final listener in [..._breakpointsListeners.values]) {
      listener(context, breakpoint);
    }
  }

  /// Adds a global listener for navigation.
  void addBreakpointsListener(String label, BreakpointsListener callback) {
    _breakpointsListeners[label] = callback;
  }

  /// Removes a global navigation listener.
  void removeBreakpointsListener(String label) {
    _breakpointsListeners.remove(label);
  }

  /// Sets the system UI brightness to the provided [brightness]. Used for
  /// simulation purposes.
  void setSystemUIBrightness(BrightnessModel brightness) {
    _systemUIBrightnessStreamController.add(brightness);
  }
}
