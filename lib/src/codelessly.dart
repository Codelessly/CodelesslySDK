import 'dart:async';
import 'dart:developer';

import 'package:flutter/foundation.dart';

import '../codelessly_sdk.dart';
import '../firedart.dart';
import 'auth/codelessly_auth_manager.dart';
import 'cache/codelessly_cache_manager.dart';
import 'data/firebase_data_repository.dart';
import 'data/web_data_repository.dart';
import 'logging/error_handler.dart';
import 'logging/reporter.dart';

/// The entry point for accessing the Codelessly SDK.
///
/// Usage:
///
///   // Initialize SDK
///   Codelessly.initializeSDK(CodelesslyConfig(authToken: XXX));
///
///   // Get global instance
///   Codelessly.instance;
///
/// Look at [CodelesslyConfig] for more information on available configuration
/// options.
class Codelessly {
  /// Internal singleton instance
  static Codelessly _instance = Codelessly();

  /// Returns the global singleton instance of the SDK.
  /// Initialization is needed before formal usage.
  static Codelessly get instance => _instance;

  /// Returns the current status of the SDK.
  static CodelesslyStatus get sdkStatus => _instance.status;

  /// Returns a stream of SDK status changes.
  static Stream<CodelesslyStatus> get sdkStatusStream => _instance.statusStream;

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

  CacheManager? _cacheManager;

  /// Returns the cache manager that is responsible for providing an interface
  /// to the local device's cache.
  CacheManager get cacheManager => _cacheManager!;

  Firestore? _firestore;

  DataManager get dataManager =>
      _config!.isPreview ? _previewDataManager! : _publishDataManager!;

  /// Returns the local instance of the Firestore SDK. Used by the data manager
  /// to retrieve server data.
  Firestore get firestore => _firestore!;

  /// A map of data that is passed to loaded layouts for nodes to replace their
  /// property values with.
  final Map<String, dynamic> data = {};

  /// A map of functions that is passed to loaded layouts for nodes to call
  /// when they are triggered.
  final Map<String, CodelesslyFunction> functions = {};

  CodelesslyStatus _status = CodelesslyStatus.empty;

  /// Returns the current status of this SDK instance.
  CodelesslyStatus get status => _status;

  final StreamController<CodelesslyStatus> _statusStreamController =
      StreamController.broadcast()..add(CodelesslyStatus.empty);

  /// Returns a stream of status updates for this SDK instance.
  Stream<CodelesslyStatus> get statusStream => _statusStreamController.stream;

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
  }) {
    _config = config;
    _cacheManager = cacheManager;
    _authManager = authManager;
    _publishDataManager = publishDataManager;
    _previewDataManager = previewDataManager;

    // Set data and functions.
    if (data != null) {
      this.data.addAll(data);
    }

    if (functions != null) {
      this.functions.addAll(functions);
    }

    // If the config is not null, update the status to configured.
    if (_config != null) {
      _updateStatus(CodelesslyStatus.configured);
    }
  }

  /// Disposes this instance of the SDK permanently.
  void dispose() {
    assert(
      !isGlobalInstance(this),
      'Cannot dispose global instance. Only dispose locally created instances.',
    );

    _status = CodelesslyStatus.empty;
    _statusStreamController.close();

    _cacheManager?.dispose();
    _authManager?.dispose();
    _publishDataManager?.dispose();
    _previewDataManager?.dispose();

    _cacheManager = null;
    _authManager = null;
    _publishDataManager = null;
    _previewDataManager = null;
  }

  /// Initializes this instance of the SDK.
  ///
  /// To know when the SDK is ready, simply listen to the status events from the
  /// [Codelessly.instance.statusStream]. No need to await the future.
  ///
  /// If the [CodelesslyWidget] recognizes that this instance of the
  /// [Codelessly] SDK is the global instance rather than a local one, it will
  /// initialize the SDK automatically, if specified.
  Future<CodelesslyStatus> initialize({
    CodelesslyConfig? config,

    // Raw managers.
    AuthManager? authManager,
    DataManager? publishDataManager,
    DataManager? previewDataManager,
    CacheManager? cacheManager,

    // Raw data.
    Map<String, dynamic>? data,
    Map<String, CodelesslyFunction>? functions,
  }) async {
    assert(
      (config == null) != (_instance._config == null),
      _instance._config == null
          ? 'The SDK cannot be initialized if it is not configured. '
              '\nConsider specifying a [CodelesslyConfig] when initializing.'
          : 'A [CodelesslyConfig] was already provided.'
              '\nConsider removing the duplicate config or calling '
              '[Codelessly.dispose] before reinitializing.',
    );

    try {
      return _instance.init(
        config: config,
        cacheManager: cacheManager,
        authManager: authManager,
        publishDataManager: publishDataManager,
        previewDataManager: previewDataManager,
        data: data,
        functions: functions,
      );
    } catch (error, stacktrace) {
      _instance._config ??= config;
      _instance.initErrorHandler(
        automaticallySendCrashReports:
            (_instance._config?.automaticallyCollectCrashReports) ?? false,
      );

      CodelesslyErrorHandler.instance.captureException(
        error,
        stacktrace: stacktrace,
      );
      return CodelesslyStatus.error;
    }
  }

  /// Resets the state of the SDK. This is useful for resetting the data without
  /// disposing the instance permanently.
  ///
  /// This does not close the status stream, and instead sets the SDK back to
  /// idle mode.
  Future<void> resetAndClearCache() async {
    await _cacheManager?.clearAll();
    await _cacheManager?.deleteAllByteData();
    _publishDataManager?.invalidate();
    _previewDataManager?.invalidate();
    _authManager?.invalidate();

    _status = CodelesslyStatus.empty;
    _statusStreamController.add(_status);
  }

  static Future<void> resetAndClearSDKCache() => _instance.resetAndClearCache();

  /// Returns true if the provided instance is the global instance.
  static bool isGlobalInstance(Codelessly codelessly) {
    return _instance == codelessly;
  }

  /// Internally updates the status of this instance of the SDK and emits a
  /// status update event to the [statusStream].
  void _updateStatus(CodelesslyStatus status) {
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
  /// [Codelessly] SDK is the global instance rather than a local one, it will
  /// configure and initialize the SDK automatically via its widget's
  /// constructor parameters.
  CodelesslyStatus configure({
    CodelesslyConfig? config,

    // Optional data and functions.
    Map<String, String>? data,
    Map<String, CodelesslyFunction>? functions,

    // Optional managers.
    CacheManager? cacheManager,
    AuthManager? authManager,
    DataManager? publishDataManager,
    DataManager? previewDataManager,
  }) {
    _config ??= config;

    initErrorHandler(
      automaticallySendCrashReports: _config!.automaticallyCollectCrashReports,
    );

    assert(
      status == CodelesslyStatus.empty,
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

    if (data != null) {
      this.data.addAll(data);
    }
    if (functions != null) {
      this.functions.addAll(functions);
    }
    _updateStatus(CodelesslyStatus.configured);
    return status;
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
    if (!kIsWeb) {
      if (_firestore != null) {
        return;
      }
      _firestore = Firestore(defaultProjectId);
    }
    CodelesslyErrorHandler.init(
      reporter: automaticallySendCrashReports && !kIsWeb
          ? FirestoreErrorReporter(_firestore!)
          : null,
      onException: (CodelesslyException exception) {
        // Layout errors are not SDK errors.
        if (exception.layoutID != null) {
          return;
        }
        _updateStatus(CodelesslyStatus.error);
      },
    );
  }

  /// Initializes this instance of the SDK.
  ///
  /// To know when the SDK is ready, simply listen to the status events from
  /// [statusStream]. There's no need to await the future.
  ///
  /// If the [CodelesslyWidget] recognizes that this instance of the
  /// [Codelessly] SDK is the global instance rather than a local one, it will
  /// configure and/or initialize the SDK automatically via its widget's
  /// constructor parameters, if specified.
  Future<CodelesslyStatus> init({
    CodelesslyConfig? config,

    // Optional data and functions.
    Map<String, dynamic>? data,
    Map<String, CodelesslyFunction>? functions,

    // Optional managers.
    CacheManager? cacheManager,
    AuthManager? authManager,
    DataManager? publishDataManager,
    DataManager? previewDataManager,
    bool initializeDataManagers = true,
  }) async {
    assert(
      (config == null) != (_config == null),
      _config == null
          ? 'The SDK cannot be initialized if it is not configured. '
              '\nConsider specifying a [CodelesslyConfig] when initializing.'
          : 'A [CodelesslyConfig] was already provided.'
              '\nConsider removing the duplicate config or calling '
              '[Codelessly.dispose] before reinitializing.',
    );

    _config ??= config;
    initErrorHandler(
      automaticallySendCrashReports: _config!.automaticallyCollectCrashReports,
    );
    try {
      _updateStatus(CodelesslyStatus.configured);

      // Clean up.
      if (cacheManager != null) _cacheManager?.dispose();
      if (authManager != null) _authManager?.dispose();
      if (publishDataManager != null) _publishDataManager?.dispose();
      if (previewDataManager != null) _previewDataManager?.dispose();
      if (data != null) this.data.addAll(data);
      if (functions != null) this.functions.addAll(functions);

      _cacheManager = cacheManager ??
          _cacheManager ??
          CodelesslyCacheManager(
            config: _config!,
          );
      _authManager = authManager ??
          _authManager ??
          CodelesslyAuthManager(
            config: _config!,
            cacheManager: this.cacheManager,
          );
      _publishDataManager = publishDataManager ??
          _publishDataManager ??
          DataManager(
            config: _config!.copyWith(isPreview: false),
            cacheManager: this.cacheManager,
            authManager: this.authManager,
            networkDataRepository: kIsWeb
                ? WebDataRepository()
                : FirebaseDataRepository(firestore: firestore),
            localDataRepository:
                LocalDataRepository(cacheManager: this.cacheManager),
          );

      _previewDataManager = previewDataManager ??
          _previewDataManager ??
          DataManager(
            config: _config!.copyWith(isPreview: true),
            cacheManager: this.cacheManager,
            authManager: this.authManager,
            networkDataRepository: kIsWeb
                ? WebDataRepository()
                : FirebaseDataRepository(firestore: firestore),
            localDataRepository:
                LocalDataRepository(cacheManager: this.cacheManager),
          );

      _updateStatus(CodelesslyStatus.loading);

      log('Initializing cache manager');
      // The cache manager initializes first to load the local cache.
      await this.cacheManager.init();

      log('Initializing auth manager');
      // The auth manager initializes second to look up cached auth data
      // from the cache manager. If no auth data is available, it halts the
      // entire process and awaits to authenticate with the server.
      //
      // After either of those is done, the relevant auth data is immediately
      // emitted to the internal stream controller, ready for immediate usage.
      await this.authManager.init();

      log('Initializing data managers');
      // The data manager initializes last to load the last stored publish
      // model, or, if it doesn't exist, halts the entire process and awaits
      // to fetch the latest publish model from the server.
      //
      // The config sets the default data manager to initialize. If the
      // [CodelesslyWidget] wants to load the opposite manager, the other will
      // lazily initialize.
      if (initializeDataManagers && _config!.preload) {
        if (_config!.isPreview) {
          if (!this.previewDataManager.initialized) {
            await this.previewDataManager.init(layoutID: null);
          }
        } else {
          if (!this.publishDataManager.initialized) {
            await this.publishDataManager.init(layoutID: null);
          }
        }
      }

      log('Codelessly ${isGlobalInstance(this) ? 'global' : 'local'} instance initialization complete.');

      _updateStatus(CodelesslyStatus.loaded);
    } catch (error, stacktrace) {
      _updateStatus(CodelesslyStatus.error);
      CodelesslyErrorHandler.instance.captureException(
        error,
        stacktrace: stacktrace,
      );
    }

    return _status;
  }

  /// Configures this instance of the SDK with the provided configuration
  /// options. This will mark the SDK as ready to be initialized.
  ///
  /// This function can still be used to lazily initialize the SDK. Layouts and
  /// fonts will only be downloaded and cached when [initialize] is called.
  ///
  /// To immediately configure and initialize the SDK, [initialize] can be
  /// called directly without needing to call this function first.
  ///
  /// If the [CodelesslyWidget] recognizes that this instance of the
  /// [Codelessly] SDK is the global instance rather than a local one, it will
  /// configure and initialize the SDK automatically via its widget's
  /// constructor parameters.
  static CodelesslyStatus configureSDK({
    CodelesslyConfig? config,

    // Optional data and functions.
    Map<String, String>? data,
    Map<String, CodelesslyFunction>? functions,

    // Optional managers.
    CacheManager? cacheManager,
    AuthManager? authManager,
    DataManager? publishDataManager,
    DataManager? previewDataManager,
  }) {
    return _instance.configure(
      config: config,
      cacheManager: cacheManager,
      authManager: authManager,
      publishDataManager: publishDataManager,
      previewDataManager: previewDataManager,
      data: data,
      functions: functions,
    );
  }
}
