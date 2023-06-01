import 'dart:async';

import 'package:flutter/material.dart';

import '../../codelessly_sdk.dart';
import '../logging/error_handler.dart';

class CodelesslyWidgetController extends ChangeNotifier {
  String layoutID;

  bool didInitialize = false;

  /// The [Codelessly] instance to use.
  ///
  /// By default, this is the global instance, retrieved via
  /// [Codelessly.instance].
  final Codelessly codelessly;

  /// Whether to show the preview version of the provided layout rather than the
  /// published version.
  ///
  /// If a value is provided, it will override the value provided in
  /// [CodelesslyConfig.isPreview].
  final bool isPreview;

  final CodelesslyConfig? config;

  /// Optional managers. These are only used when using the global codelessly
  /// instance.
  final AuthManager? authManager;
  final DataManager? publishDataManager;
  final DataManager? previewDataManager;
  final CacheManager? cacheManager;

  /// Listens to the SDK's status to figure out if it needs to manually
  /// initialize the opposite data manager if needed.
  StreamSubscription<SDKStatus>? _sdkStatusListener;

  DataManager get dataManager =>
      isPreview ? codelessly.previewDataManager : codelessly.publishDataManager;

  Stream<SDKPublishModel?> get publishModelStream =>
      dataManager.publishModelStream;

  SDKPublishModel? get publishModel => dataManager.publishModel;

  CodelesslyWidgetController({
    required this.layoutID,
    bool? isPreview,
    Codelessly? codelessly,
    CodelesslyConfig? config,

    // Optional managers. These are only used when using the global codelessly
    // instance.
    this.authManager,
    this.publishDataManager,
    this.previewDataManager,
    this.cacheManager,
  })  : codelessly = codelessly ?? Codelessly.instance,
        config = config ?? (codelessly ?? Codelessly.instance).config,
        isPreview = isPreview ??
            config?.isPreview ??
            (codelessly ?? Codelessly.instance).config?.isPreview ??
            false {
    final codelessly = this.codelessly;
    assert(
      (config == null) != (codelessly.config == null) ||
          (config == codelessly.config),
      codelessly.config == null
          ? 'The SDK cannot be initialized if it is not configured. '
              '\nConsider specifying a [CodelesslyConfig] when initializing.'
              '\n\nYou can initialize the SDK by calling [Codelessly.initializeSDK]'
              '\nor call [Codelessly.configureSDK] to lazily load instead.'
          : 'A [CodelesslyConfig] was already provided.'
              '\nConsider removing the duplicate config or calling '
              '[Codelessly.dispose] before reinitializing.',
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
      SDKStatus status = codelessly.status;
      final bool isGlobal = Codelessly.isGlobalInstance(codelessly);

      // If the Codelessly global instance was passed and is still idle, that
      // means the user never triggered [Codelessly.init] but this
      // [CodelesslyWidget] is about to be rendered.
      //
      // We initialize the global instance here. If this were a local Codelessly
      // instance, the user explicitly wants more control over the SDK, so we
      // do nothing and let the user handle it.
      if (isGlobal) {
        if (status == SDKStatus.idle) {
          codelessly.configure(
            config: config,
            authManager: authManager,
            publishDataManager: publishDataManager,
            previewDataManager: previewDataManager,
            cacheManager: cacheManager,
          );
        }
        status = codelessly.status;
        if (status == SDKStatus.configured) {
          codelessly.init(initializeDataManagers: false);
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
        automaticallySendCrashReports:
            codelessly.config?.automaticallyCollectCrashReports ?? false,
      );
      CodelesslyErrorHandler.instance.captureException(
        exception,
        stacktrace: str,
      );
    }

    // First event.
    if (codelessly.status == SDKStatus.done) {
      print(
          '[CodelesslyWidgetController] [$layoutID]: Codelessly SDK is already loaded. Woo!');
      _verifyAndListenToDataManager();
    }

    print(
        '[CodelesslyWidgetController] [$layoutID]: Listening to sdk status stream.');
    _sdkStatusListener?.cancel();
    _sdkStatusListener = codelessly.statusStream.listen((status) {
      switch (status) {
        case SDKStatus.idle:
        case SDKStatus.configured:
        case SDKStatus.loading:
        case SDKStatus.errored:
          break;
        case SDKStatus.done:
          print(
              '[CodelesslyWidgetController] [$layoutID]: Codelessly SDK is done loading.');
          _verifyAndListenToDataManager();
          break;
      }
    });
  }

  /// Listens to the data manager's status. If the data manager is initialized,
  /// then we can signal to the manager that the desired layout passed to this
  /// widget is ready to be rendered and needs to be downloaded and prepared.
  void _verifyAndListenToDataManager() {
    print(
        '[CodelesslyWidgetController] [$layoutID]: verifying and listening to datamanager stream.');

    notifyListeners();

    // If this CodelesslyWidget wants to preview a layout but the SDK is
    // configured to load published layouts, then we need to initialize the
    // preview data manager.
    // Vice versa for published layouts if the SDK is configured to load preview
    // layouts.
    if (!dataManager.initialized) {
      print(
          '[CodelesslyWidgetController] [$layoutID]: initialized data manager for the first time. [${isPreview ? 'preview' : 'publish'}]');
      dataManager.init(layoutID: layoutID).catchError((error, str) {
        CodelesslyErrorHandler.instance.captureException(
          error,
          stacktrace: str,
          layoutID: layoutID,
        );
      });
    } else {
      print(
          '[CodelesslyWidgetController] [$layoutID]: requesting layout from data manager. [${isPreview ? 'preview' : 'publish'}]');
      dataManager
          .getOrFetchLayoutWithFontsAndApisAndEmit(layoutID: layoutID)
          .catchError((error, str) {
        CodelesslyErrorHandler.instance.captureException(
          error,
          stacktrace: str,
          layoutID: layoutID,
        );
        return false;
      });
    }
  }

  bool hasLayoutModel(String layoutID) =>
      publishModel?.layouts.containsKey(layoutID) ?? false;
}
