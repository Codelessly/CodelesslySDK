import 'dart:async';
import 'dart:developer';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import '../codelessly_sdk.dart';
import '../firedart.dart';
import 'auth/auth_manager.dart';
import 'auth/codelessly_auth_manager.dart';
import 'cache/cache_manager.dart';
import 'cache/codelessly_cache_manager.dart';
import 'data/firebase_data_repository.dart';
import 'data/local_data_repository.dart';
import 'data/web_data_repository.dart';
import 'error/error_handler.dart';
import 'error/reporter.dart';

/// Represents the current status of the SDK.
enum SDKStatus {
  /// The SDK has not been initialized.
  idle('Idle'),

  /// The SDK has configurations set and ready to be initialized.
  configured('Configured'),

  /// The SDK is initializing.
  loading('Loading'),

  /// The SDK is initialized.
  done('Done'),

  /// The SDK crashed.
  errored('Errored');

  /// The label of the status.
  final String label;

  /// A const constructor for [SDKStatus].
  const SDKStatus(this.label);
}

/// Holds initialization configuration options for the SDK.
class CodelesslyConfig with EquatableMixin {
  /// The SDK auth token required for using the SDK.
  /// You can retrieve it from your project's settings page.
  final String authToken;

  /// Allows the SDK to automatically send crash reports back to Codelessly's
  /// servers for developer analysis.
  final bool automaticallyCollectCrashReports;

  /// Whether [CodelesslyWidget]s should show the preview versions of their
  /// layouts or the published versions.
  ///
  /// Defaults to `false`.
  final bool isPreview;

  /// Notifies the data manager to download all layouts and fonts of the
  /// configured project during the initialization process of the SDK.
  final bool preload;

  /// Creates a new instance of [CodelesslyConfig].
  ///
  /// [authToken] is the SDK auth token required to initialize the SDK.
  ///             You can retrieve it from your project's publish menu.
  ///
  /// [automaticallyCollectCrashReports] allows the SDK to automatically send
  /// crash reports back to Codelessly's servers for developer analysis.
  ///
  /// No device data is sent with the crash report. Only the stack trace and
  /// the error message.
  const CodelesslyConfig({
    required this.authToken,
    this.automaticallyCollectCrashReports = true,
    this.isPreview = false,
    this.preload = true,
  });

  /// Creates a new instance of [CodelesslyConfig] with the provided
  /// optional parameters.
  CodelesslyConfig copyWith({
    String? authToken,
    bool? automaticallyCollectCrashReports,
    bool? isPreview,
    bool? preload,
  }) =>
      CodelesslyConfig(
        authToken: authToken ?? this.authToken,
        automaticallyCollectCrashReports: automaticallyCollectCrashReports ??
            this.automaticallyCollectCrashReports,
        isPreview: isPreview ?? this.isPreview,
        preload: preload ?? this.preload,
      );

  @override
  List<Object?> get props => [
        authToken,
        automaticallyCollectCrashReports,
        isPreview,
      ];
}

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
/// Look at [CodelesslyConfig] for more information on available
/// configuration options.
class Codelessly {
  /// Internal singleton instance
  static Codelessly _instance = Codelessly();

  /// [returns] the global singleton instance of the SDK.
  /// Initialization is needed before formal usage.
  static Codelessly get instance => _instance;

  /// [returns] the current status of the SDK.
  static SDKStatus get sdkStatus => _instance.status;

  /// [returns] a stream of SDK status changes.
  static Stream<SDKStatus> get sdkStatusStream => _instance.statusStream;

  CodelesslyConfig? _config;

  /// [returns] the configuration options provided to this SDk.
  CodelesslyConfig? get config => _config;

  AuthManager? _authManager;

  /// [returns] the authentication manager that is responsible for managing
  /// auth token validation and project ID retrieval.
  AuthManager get authManager => _authManager!;

  DataManager? _publishDataManager;

  /// [returns] the data manager that is responsible for retrieving layout
  /// information to and from the Codelessly servers or the local device's
  /// cache.
  DataManager get publishDataManager => _publishDataManager!;

  DataManager? _previewDataManager;

  /// [returns] the data manager that is responsible for retrieving layout
  /// information to and from the Codelessly servers or the local device's
  /// cache.
  ///
  /// The difference between [publishDataManager] and [previewDataManager] is
  /// that the preview data manager will retrieve the preview versions of
  /// layouts.
  DataManager get previewDataManager => _previewDataManager!;

  CacheManager? _cacheManager;

  /// [returns] the cache manager that is responsible for providing an interface
  /// to the local device's cache.
  CacheManager get cacheManager => _cacheManager!;

  Firestore? _firestore;

  DataManager get dataManager =>
      _config!.isPreview ? _previewDataManager! : _publishDataManager!;

  /// [returns] the local instance of the Firestore SDK. Used by the
  /// data manager to retrieve server data.
  Firestore get firestore => _firestore!;

  /// A map of data that is passed to loaded layouts for nodes to replace
  /// their values with.
  final Map<String, dynamic> data = {};

  /// A map of functions that is passed to loaded layouts for nodes to call
  /// when they are triggered.
  final Map<String, CodelesslyFunction> functions = {};

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
      _updateStatus(SDKStatus.configured);
    }
  }

  SDKStatus _status = SDKStatus.idle;

  /// [returns] the current status of this sdk instance.
  SDKStatus get status => _status;

  final StreamController<SDKStatus> _statusStreamController =
      StreamController.broadcast()..add(SDKStatus.idle);

  /// [returns] a stream of status updates for this sdk instance.
  Stream<SDKStatus> get statusStream => _statusStreamController.stream;

  /// Disposes this instance of the SDK permanently.
  @mustCallSuper
  void dispose() {
    assert(
      !isGlobalInstance(this),
      'Cannot dispose global instance. Only dispose locally created instances.',
    );

    _status = SDKStatus.idle;
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

  /// Resets the state of the SDK. This is useful for resetting the data without
  /// disposing the instance permanently.
  ///
  /// This will not close the status stream, and will instead set the SDK back
  /// to idle mode.
  Future<void> resetAndClearCache() async {
    await _cacheManager?.clearAll();
    await _cacheManager?.deleteAllByteData();
    _publishDataManager?.invalidate();
    _previewDataManager?.invalidate();
    _authManager?.invalidate();

    _status = SDKStatus.idle;
    _statusStreamController.add(_status);
  }

  static Future<void> resetAndClearSDKCache() => _instance.resetAndClearCache();

  /// [returns] true if the provided instance is the global instance.
  static bool isGlobalInstance(Codelessly codelessly) {
    return _instance == codelessly;
  }

  /// Internally updates the status of this instance of the SDK and emits
  /// a status update event to the [statusStream].
  void _updateStatus(SDKStatus status) {
    if (_status == status) {
      return;
    }
    _status = status;
    _statusStreamController.add(_status);
  }

  /// Configures this instance of the SDK with the provided configuration
  /// options. This will mark the SDK as ready to be initialized.
  ///
  /// You can use this function to lazily initialize the SDK. Layouts and fonts
  /// will only be downloaded and cached when [initialize] is called.
  ///
  /// You can call [initialize] directly without needing to call this function
  /// first to immediately configure and initialize the SDK.
  ///
  /// If the [CodelesslyWidget] recognizes that this instance of the
  /// [Codelessly] SDK is the global instance rather than a local one, it will
  /// configure and initialize the SDK automatically for you via its widget's
  /// constructor parameters.
  SDKStatus configure({
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
      status == SDKStatus.idle,
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
    _updateStatus(SDKStatus.configured);
    return status;
  }

  /// Initializes the internal Firestore instance used by this SDK and
  /// configures the error handler to use it.
  ///
  /// This will only fully run once if the [Firestore] instance is not already
  /// initialized. If it is, this is ignored.
  ///
  /// If the SDK is running on a web platform, this will be ignored.
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
        _updateStatus(SDKStatus.errored);
      },
    );
  }

  /// Initializes this instance of the SDK.
  ///
  /// You do not need to await the future. You can simply listen to the status
  /// events from the [statusStream] to know when the SDK is ready.
  ///
  /// If the [CodelesslyWidget] recognizes that this instance of the
  /// [Codelessly] SDK is the global instance rather than a local one, it will
  /// configure and/or initialize the SDK automatically for you via its
  /// widget's constructor parameters, if specified.
  Future<SDKStatus> init({
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
      _updateStatus(SDKStatus.configured);

      // Clean up.
      if (cacheManager != null) _cacheManager?.dispose();
      if (authManager != null) _authManager?.dispose();
      if (publishDataManager != null) _publishDataManager?.dispose();
      if (previewDataManager != null) _previewDataManager?.dispose();
      if (data != null) this.data.addAll(data);
      if (functions != null) this.functions.addAll(functions);

      _cacheManager = cacheManager ??
          CodelesslyCacheManager(
            config: _config!,
          );
      _authManager = authManager ??
          CodelesslyAuthManager(
            config: _config!,
            cacheManager: this.cacheManager,
          );
      _publishDataManager = publishDataManager ??
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

      _updateStatus(SDKStatus.loading);

      log('Initializing cache manager');
      // The cache manager initializes first to load the local cache.
      await this.cacheManager.init();

      log('Initializing auth manager');
      // The auth manager initializes second to look up cached auth data
      // from the cache manager. If no auth data is available, it will
      // halt the entire process and awaits to authenticate with the server.
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
      // [CodelesslyWidget] want to load the opposite manager, the other will
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

      _updateStatus(SDKStatus.done);
    } catch (error, stacktrace) {
      _updateStatus(SDKStatus.errored);
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
  /// You can use this function to lazily initialize the SDK. Layouts and fonts
  /// will only be downloaded and cached when [initialize] is called.
  ///
  /// You can call [initialize] directly without needing to call this function
  /// first to immediately configure and initialize the SDK.
  ///
  /// If the [CodelesslyWidget] recognizes that this instance of the
  /// [Codelessly] SDK is the global instance rather than a local one, it will
  /// configure and initialize the SDK automatically for you via its widget's
  /// constructor parameters.
  static SDKStatus configureSDK({
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

  /// Initializes this instance of the SDK.
  ///
  /// You do not need to await the future. You can simply listen to the status
  /// events from the [Codelessly.instance.statusStream] to know when the SDK
  /// is ready.
  ///
  /// If the [CodelesslyWidget] recognizes that this instance of the
  /// [Codelessly] SDK is the global instance rather than a local one, it will
  /// initialize the SDK automatically for you, if specified.
  static Future<SDKStatus> initializeSDK({
    CodelesslyConfig? config,

    // raw managers
    AuthManager? authManager,
    DataManager? publishDataManager,
    DataManager? previewDataManager,
    CacheManager? cacheManager,

    // raw data
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
      return SDKStatus.errored;
    }
  }
}
