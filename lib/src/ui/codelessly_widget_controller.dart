import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';

import '../../codelessly_sdk.dart';
import '../logging/error_handler.dart';

/// The [CodelesslyWidgetController] provides advanced explicit control over
/// the state of the instantiated [CodelesslyWidget] that it is attached to.
///
/// The SDK must be instantiated when using a [CodelesslyWidget] or
/// [CodelesslyWidgetController].
///
/// The SDK can be instantiated in several ways:
///
/// 1. Using the global instance of the SDK by not passing any of the
///    relevant parameters. Initialization of the global instance is done
///    implicitly if not already initialized.
///
/// 2. Using a custom [codelessly] instance, initialization of the
///    [codelessly] instance must be done explicitly.
///
/// 3. Using a custom [config], which will be used to initialize the global
///    [codelessly] instance.
class CodelesslyWidgetController extends ChangeNotifier {
  /// The ID of the layout provided from your Codelessly dashboard.
  /// This represents a single screen or canvas.
  ///
  /// If this is null, the controller's layoutID will be used.
  /// This cannot be null if no controller is provided.
  final String? layoutID;

  /// The [Codelessly] instance to use.
  ///
  /// By default, this is the global instance, retrieved via
  /// [Codelessly.instance].
  final Codelessly codelessly;

  /// Holds initialization configuration options for the SDK.
  final CodelesslyConfig? config;

  /// Optional auth manager for advanced control over the SDK's authentication
  /// flow.
  final AuthManager? authManager;

  /// Optional publish data manager for advanced control over the SDK's
  /// publish data flow.
  final DataManager? publishDataManager;

  /// Optional preview data manager for advanced control over the SDK's
  /// preview data flow.
  final DataManager? previewDataManager;

  /// Optional cache manager for advanced control over the SDK's caching
  /// behavior.
  final CacheManager? cacheManager;

  /// Listens to the SDK's status to figure out if it needs to manually
  /// initialize the opposite data manager if needed.
  StreamSubscription<CodelesslyStatus>? _sdkStatusListener;

  /// Helper getter to retrieve the active data manager being used by
  /// the [Codelessly] instance.
  DataManager get dataManager => codelessly.dataManager;

  /// Helper getter to retrieve the active publish model stream being used by
  /// the [Codelessly] instance.
  Stream<SDKPublishModel?> get publishModelStream =>
      dataManager.publishModelStream;

  /// Helper getter to retrieve the active publish model being used by
  /// the [Codelessly] instance.
  SDKPublishModel? get publishModel => dataManager.publishModel;

  /// Helper getter to retrieve the publish source being used by
  /// the [Codelessly] instance.
  PublishSource get publishSource => codelessly.config!.publishSource;

  /// A boolean that helps keep track of the state of this controller's
  /// initialization.
  bool didInitialize = false;

  /// Creates a [CodelesslyWidgetController].
  ///
  /// If the [layoutID] is not provided, then it is assumed that the published
  /// model is public via a defined slug or is a template for the template
  /// gallery, in which case, the [SDKPublishModel.entryLayoutID] is provided
  /// and must not be null. If it is not provided, than there is an error in
  /// the data, perhaps from a usage bug in the Codelessly Editor.
  ///
  /// Optionally, provide custom [authManager], [publishDataManager],
  /// [previewDataManager], and [cacheManager] instances for advanced control
  /// over the SDK's behavior.
  CodelesslyWidgetController({
    this.layoutID,
    PublishSource? publishSource,
    Codelessly? codelessly,
    CodelesslyConfig? config,

    // Optional managers. These are only used when using the global codelessly
    // instance.
    this.authManager,
    this.publishDataManager,
    this.previewDataManager,
    this.cacheManager,
  })  : codelessly = codelessly ?? Codelessly.instance,
        config = config ?? (codelessly ?? Codelessly.instance).config {
    final codelessly = this.codelessly;
    assert(
      (config == null) != (codelessly.config == null) ||
          (config == codelessly.config),
      codelessly.config == null
          ? 'The SDK cannot be initialized if it is not configured. '
              '\nConsider specifying a [CodelesslyConfig] when initializing.'
              '\nYou can initialize the SDK by calling [Codelessly.instance.initialize()].'
              '\nOr call [Codelessly.instance.configure()] to load the SDK lazily instead.'
          : 'A [CodelesslyConfig] was already provided.'
              '\nConsider removing the duplicate config or calling '
              '[Codelessly.instance.dispose()] before reinitializing.',
    );
    assert(
      (layoutID != null) || (config ?? codelessly.config)!.slug != null,
      'You must specify a [layoutID] in the constructor of this controller.'
      "\nIf you don't, then a slug must be configured in the config.",
    );
  }

  @override
  void dispose() {
    _sdkStatusListener?.cancel();
    super.dispose();
  }

  /// Listens to the SDK's status. If the SDK is done, then we can start
  /// listening to the data manager's status for layout updates.
  void init() {
    didInitialize = true;

    try {
      CodelesslyStatus status = codelessly.status;
      final bool isGlobal = codelessly == Codelessly.instance;

      // If the Codelessly global instance was passed and is still idle, that
      // means the user never triggered [Codelessly.init] but this
      // [CodelesslyWidget] is about to be rendered.
      //
      // We initialize the global instance here. If this were a local Codelessly
      // instance, the user explicitly wants more control over the SDK, so we
      // do nothing and let the user handle it.
      if (isGlobal) {
        if (status == CodelesslyStatus.empty) {
          codelessly.configure(
            config: config,
            authManager: authManager,
            publishDataManager: publishDataManager,
            previewDataManager: previewDataManager,
            cacheManager: cacheManager,
          );
        }
        status = codelessly.status;
        if (status == CodelesslyStatus.configured) {
          codelessly.initialize(initializeDataManagers: false);
        }
      }
    } catch (exception, str) {
      // Makes sure the error handler is initialized before capturing.
      // There are cases (like the above asserts and throws) that can
      // trigger unhandled widget/flutter errors that are not handled
      // from the Codelessly instance.
      //
      // We need to handle them, and if the codelessly instance is not
      // configured yet, we need to initialize the error handler regardless.
      codelessly.initErrorHandler(
        firebaseProjectId: codelessly.config?.firebaseProjectId,
        automaticallySendCrashReports:
            codelessly.config?.automaticallyCollectCrashReports ?? false,
      );
      CodelesslyErrorHandler.instance
          .captureException(exception, stacktrace: str);
    }

    // First event.
    if (codelessly.status == CodelesslyStatus.loaded) {
      log(
        '[CodelesslyWidgetController] [$layoutID]: Codelessly SDK is already'
        ' loaded. Woo!',
      );
      _verifyAndListenToDataManager();
    }

    log(
      '[CodelesslyWidgetController] [$layoutID]: Listening to sdk status'
      ' stream.',
    );
    _sdkStatusListener?.cancel();
    _sdkStatusListener = codelessly.statusStream.listen((status) {
      switch (status) {
        case CodelesslyStatus.empty:
        case CodelesslyStatus.configured:
        case CodelesslyStatus.loading:
        case CodelesslyStatus.error:
          break;
        case CodelesslyStatus.loaded:
          log(
            '[CodelesslyWidgetController] [$layoutID]: Codelessly SDK is'
            ' done loading.',
          );
          _verifyAndListenToDataManager();
          break;
      }
    });
  }

  /// Listens to the data manager's status. If the data manager is initialized,
  /// then we can signal to the manager that the desired layout passed to this
  /// widget is ready to be rendered and needs to be downloaded and prepared.
  void _verifyAndListenToDataManager() {
    log(
      '[CodelesslyWidgetController] [$layoutID]: verifying and listening to'
      ' data manager stream.',
    );

    notifyListeners();

    // If this CodelesslyWidget wants to preview a layout but the SDK is
    // configured to load published layouts, then we need to initialize the
    // preview data manager.
    // Vice versa for published layouts if the SDK is configured to load preview
    // layouts.
    if (!dataManager.initialized) {
      log(
        '[CodelesslyWidgetController] [$layoutID]: initialized data manager'
        ' for the first time with a publish source of $publishSource.',
      );
      dataManager.init(layoutID: layoutID).catchError((error, str) {
        CodelesslyErrorHandler.instance.captureException(
          error,
          stacktrace: str,
          layoutID: layoutID,
        );
      });
    } else if (config!.preload == false && layoutID != null) {
      log(
        '[CodelesslyWidgetController] [$layoutID]: Config preloading is false.',
      );
      log(
        '[CodelesslyWidgetController] [$layoutID]: Requesting layout from'
        ' data manager since preloading is false',
      );
      log(
        '[CodelesslyWidgetController] [$layoutID]: Using publish source'
        ' $publishSource.',
      );
      dataManager
          .getOrFetchPopulatedLayout(layoutID: layoutID!)
          .catchError((error, str) {
        CodelesslyErrorHandler.instance.captureException(
          error,
          stacktrace: str,
          layoutID: layoutID,
        );
        return false;
      });
    } else {
      log(
        '[CodelesslyWidgetController] [$layoutID]: Config preloading is true. Doing nothing while DataManager finishes.',
      );
    }
  }
}
