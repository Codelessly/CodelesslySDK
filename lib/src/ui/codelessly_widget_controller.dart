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
  final Codelessly? codelessly;

  /// A convenience getter that returns the provided [codelessly] instance, or,
  /// if it's null, returns the global [Codelessly.instance].
  Codelessly get effectiveCodelessly => codelessly ?? Codelessly.instance;

  /// A convenience getter that decides whether this controller is configured
  /// to use an explicitly-controlled [Codelessly] instance, or to use the
  /// global [Codelessly.instance].
  bool get isGlobalInstance => codelessly == null;

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
  DataManager get dataManager => effectiveCodelessly.dataManager;

  /// Helper getter to retrieve the active publish model stream being used by
  /// the [Codelessly] instance.
  Stream<SDKPublishModel?> get publishModelStream =>
      dataManager.publishModelStream;

  /// Helper getter to retrieve the active publish model being used by
  /// the [Codelessly] instance.
  SDKPublishModel? get publishModel => dataManager.publishModel;

  /// Helper getter to retrieve the publish source being used by
  /// the [Codelessly] instance.
  PublishSource get publishSource => effectiveCodelessly.config!.publishSource;

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
    this.codelessly,
    CodelesslyConfig? config,
    PublishSource? publishSource,

    // Optional managers. These are only used when using the global codelessly
    // instance.
    this.authManager,
    this.publishDataManager,
    this.previewDataManager,
    this.cacheManager,
  }) : config = config ?? (codelessly ?? Codelessly.instance).config {
    assert(
      config == null || effectiveCodelessly.config == null,
      'You cannot provide a [config] if you are also providing one '
      'inside the [codelessly] instance.',
    );
  }

  @override
  void dispose() {
    _sdkStatusListener?.cancel();
    super.dispose();
  }

  /// Listens to the SDK's status. If the SDK is done, then we can start
  /// listening to the data manager's status for layout updates.
  void initialize({
    CodelesslyConfig? config,
    String? layoutID,
  }) {
    assert(
      (config == null) != (this.config == null),
      config == null
          ? 'A [config] must be provided. Please provide one either in the initialize() function, or the constructor of this controller, or in the Codelessly instance.'
          : 'A config was already provided from '
              '${effectiveCodelessly.config == null ? 'the constructor of this controller.' : 'from the configured Codelessly instance.'}'
              ' You cannot specify it again in the initialize function of this controller.',
    );

    config ??= this.config;

    assert(
      config!.slug != null || ((layoutID == null) != (this.layoutID == null)),
      layoutID == null
          ? 'The [layoutID] must be provided once either from the constructor of this controller or in the initialize function.'
              "\nIf you don't, then a slug must be configured in the config."
          : 'The [layoutID] must be provided only once either from the constructor of this controller or in the initialize function. Not in both at the same time.',
    );

    didInitialize = true;

    try {
      CodelesslyStatus status = effectiveCodelessly.status;

      // If the Codelessly global instance was passed and is still idle, that
      // means the user never triggered [Codelessly.init] but this
      // [CodelesslyWidget] is about to be rendered.
      //
      // We initialize the global instance here. If this were a local Codelessly
      // instance, the user explicitly wants more control over the SDK, so we
      // do nothing and let the user handle it.
      if (isGlobalInstance) {
        if (status == CodelesslyStatus.empty) {
          effectiveCodelessly.configure(
            config: config,
            authManager: authManager,
            publishDataManager: publishDataManager,
            previewDataManager: previewDataManager,
            cacheManager: cacheManager,
          );
        }
        status = effectiveCodelessly.status;
        if (status == CodelesslyStatus.configured) {
          effectiveCodelessly.initialize();
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
      effectiveCodelessly.initErrorHandler(
        firebaseProjectId: effectiveCodelessly.config?.firebaseProjectId,
        automaticallySendCrashReports:
            effectiveCodelessly.config?.automaticallyCollectCrashReports ??
                false,
      );
      CodelesslyErrorHandler.instance
          .captureException(exception, stacktrace: str);
    }

    // First event.
    if (effectiveCodelessly.status == CodelesslyStatus.loaded) {
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
    _sdkStatusListener = effectiveCodelessly.statusStream.listen((status) {
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
