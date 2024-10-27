import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../../codelessly_sdk.dart';
import '../logging/debug_logger.dart';

Widget _defaultLayoutBuilder(context, layout) => layout;

/// The provides advanced explicit control over
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
  static const String name = 'CodelesslyWidgetController';

  /// The ID of the layout provided from your Codelessly dashboard.
  /// This represents a single screen or canvas.
  ///
  /// If this is null, the controller's layoutID will be used.
  /// This cannot be null if no controller is provided.
  String? layoutID;

  /// The [Codelessly] instance to use.
  ///
  /// By default, this is the global instance, retrieved via
  /// [Codelessly.instance].
  Codelessly? codelessly;

  /// A convenience getter that returns the provided [codelessly] instance, or,
  /// if it's null, returns the global [Codelessly.instance].
  Codelessly get effectiveCodelessly => codelessly ?? Codelessly.instance;

  /// A boolean that helps keep track of whether this controller created an
  /// intrinsic [Codelessly] instance automatically.
  ///
  /// This may happen if the user does not pass a [codelessly] instance,
  /// implying they want to use the global instance, but they pass a custom
  /// config to this controller that is not the same as the global instance's
  /// config.
  ///
  /// In this case, a locally managed intrinsic [Codelessly] instance is created
  /// here with the provided config.
  late final bool createdIntrinsicCodelessly;

  /// A convenience getter that decides whether this controller is configured
  /// to use an explicitly-controlled [Codelessly] instance, or to use the
  /// global [Codelessly.instance].
  bool get isGlobalInstance => codelessly == null;

  /// Holds initialization configuration options for the SDK.
  late final CodelesslyConfig config;

  /// Optional auth manager for advanced control over the SDK's authentication
  /// flow.
  final AuthManager? authManager;

  /// Optional publish data manager for advanced control over the SDK's
  /// publish data flow.
  final DataManager? publishDataManager;

  /// Optional preview data manager for advanced control over the SDK's
  /// preview data flow.
  final DataManager? previewDataManager;

  /// Optional template data manager for advanced control over the SDK's
  /// template data flow.
  final DataManager? templateDataManager;

  /// Optional cache manager for advanced control over the SDK's caching
  /// behavior.
  final CacheManager? cacheManager;

  /// Listens to the SDK's status to figure out if it needs to manually
  /// initialize the opposite data manager if needed.
  StreamSubscription<CStatus>? _sdkStatusListener;

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

  /// Optional placeholder widget to show while the layout is loading.
  final WidgetBuilder? loadingBuilder;

  /// Optional placeholder widget to show if the layout fails to load.
  final CodelesslyWidgetErrorBuilder? errorBuilder;

  /// Optional widget builder to wrap the rendered layout widget with for
  /// advanced control over the layout's behavior.
  final CodelesslyWidgetLayoutBuilder? layoutBuilder;

  /// Returns a widget that decides how to load nested layouts of a rendered
  /// node.
  final LayoutRetrieverBuilder? layoutRetrievalBuilder;

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

    // UI.
    this.loadingBuilder,
    this.errorBuilder,
    this.layoutBuilder = _defaultLayoutBuilder,
    this.layoutRetrievalBuilder,

    // Optional managers. These are only used when using the global codelessly
    // instance.
    this.authManager,
    this.publishDataManager,
    this.previewDataManager,
    this.templateDataManager,
    this.cacheManager,
  })  : assert(
          (config ?? (codelessly ?? Codelessly.instance).config) != null,
          'A [config] must be provided. Please provide one either in the constructor of this controller, or in the passed Codelessly instance.',
        ),
        config = config ?? (codelessly ?? Codelessly.instance).config! {
    // If this controller is configured with its own Codelessly config but
    // wants to use the global instance, and the global instance is already
    // configured with a different config, then we need to create a custom
    // Codelessly instance with the provided config.
    if (codelessly == null &&
        config != null &&
        Codelessly.instance.config != config) {
      createdIntrinsicCodelessly = true;
      codelessly = Codelessly(config: config);
      DebugLogger.instance.printInfo(
        'Created an intrinsic Codelessly instance because the global instance is already configured with a different config than the one provided to this controller.',
        name: name,
      );
    } else {
      createdIntrinsicCodelessly = false;
    }
  }

  /// Creates a copy of this controller with the provided parameters.
  /// If no parameters are provided, then the current parameters are used.
  /// Note that some fields are nullable, so setting some values here to
  /// null may not have the desired effect.
  CodelesslyWidgetController copyWith({
    String? layoutID,
    Codelessly? codelessly,
    CodelesslyConfig? config,
    PublishSource? publishSource,
    AuthManager? authManager,
    DataManager? publishDataManager,
    DataManager? previewDataManager,
    DataManager? templateDataManager,
    CacheManager? cacheManager,
    WidgetBuilder? loadingBuilder,
    CodelesslyWidgetErrorBuilder? errorBuilder,
    CodelesslyWidgetLayoutBuilder? layoutBuilder,
    LayoutRetrieverBuilder? layoutRetrievalBuilder,
    FirebaseApp? firebaseApp,
  }) {
    return CodelesslyWidgetController(
      layoutID: layoutID ?? this.layoutID,
      codelessly: codelessly ?? this.codelessly,
      config: config ?? this.config,
      publishSource: publishSource ?? this.publishSource,
      authManager: authManager ?? this.authManager,
      publishDataManager: publishDataManager ?? this.publishDataManager,
      previewDataManager: previewDataManager ?? this.previewDataManager,
      templateDataManager: templateDataManager ?? this.templateDataManager,
      cacheManager: cacheManager ?? this.cacheManager,
      layoutBuilder: layoutBuilder ?? this.layoutBuilder,
      layoutRetrievalBuilder:
          layoutRetrievalBuilder ?? this.layoutRetrievalBuilder,
      loadingBuilder: loadingBuilder ?? this.loadingBuilder,
      errorBuilder: errorBuilder ?? this.errorBuilder,
    );
  }

  @override
  void dispose() {
    DebugLogger.instance.printFunction('dispose()', name: name);
    if (createdIntrinsicCodelessly) {
      codelessly?.dispose(sealCache: false);
    }
    _sdkStatusListener?.cancel();
    super.dispose();
  }

  /// Listens to the SDK's status. If the SDK is done, then we can start
  /// listening to the data manager's status for layout updates.
  void initialize({String? layoutID}) {
    DebugLogger.instance
        .printFunction('initialize(layoutID: $layoutID)', name: name);
    if (layoutID != null) {
      this.layoutID = layoutID;
    }

    didInitialize = true;

    try {
      CStatus status = effectiveCodelessly.status;

      // If the Codelessly global instance was passed and is still idle, that
      // means the user never triggered [Codelessly.init] but this
      // [CodelesslyWidget] is about to be rendered. Using the global instance
      // is the most common use case, so we initialize it automatically as the
      // user may have wished to use the global instance but didn't bother or
      // forgot to initialize it themselves.
      //
      // We initialize the global instance here. If this were a local Codelessly
      // instance, the user explicitly wants more control over the SDK, so we
      // do nothing and let the user handle it.
      //
      // Alternatively, if this controller made an intrinsic Codelessly instance
      // because the global instance is already configured with a different
      // config, then we need to initialize the intrinsic instance manually
      // here.
      if (isGlobalInstance || createdIntrinsicCodelessly) {
        if (status is CEmpty) {
          DebugLogger.instance
              .printInfo('Codelessly SDK is idle, configuring...', name: name);
          effectiveCodelessly.configure(
            config: config,
            authManager: authManager,
            publishDataManager: publishDataManager,
            previewDataManager: previewDataManager,
            cacheManager: cacheManager,
          );
        }
        status = effectiveCodelessly.status;
        if (status is CConfigured) {
          DebugLogger.instance.printInfo(
              'Codelessly SDK is configured, initializing...',
              name: name);
          effectiveCodelessly.initialize();
        }
      } else {
        DebugLogger.instance.printInfo(
            'Codelessly SDK is already configured and initialized.',
            name: name);
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
        automaticallySendCrashReports:
            effectiveCodelessly.config?.automaticallySendCrashReports ?? false,
      );

      effectiveCodelessly.errorHandler
          .captureException(exception, stacktrace: str);
    }

    // First event.
    if (effectiveCodelessly.status case CLoaded() || CLoading()) {
      if (effectiveCodelessly.status
          case CLoading(state: CLoadingState state)) {
        // Listen to data manager after it has been created. If it hasn't been
        // created yet, Firebase may still be initializing.
        DebugLogger.instance.printInfo(
            '[${this.layoutID}]: Codelessly SDK is loading with step $state.',
            name: name);
        if (state.hasPassed(CLoadingState.createdManagers)) {
          DebugLogger.instance.printInfo(
              '[${this.layoutID}]: Checking layout because it passed the created managers step.',
              name: name);
          _checkLayout();
        } else {
          DebugLogger.instance.printInfo(
              '[${this.layoutID}]: Waiting for data manager to be created. Skipping for now.',
              name: name);
        }
      } else {
        DebugLogger.instance.printInfo(
            '[${this.layoutID}]: Codelessly SDK is already loaded, checking layout.',
            name: name);
        _checkLayout();
      }
    }

    DebugLogger.instance.printInfo(
        '[${this.layoutID}]: Listening to sdk status stream.',
        name: name);
    DebugLogger.instance.printInfo(
        '[${this.layoutID}]: Initial sdk status is: ${effectiveCodelessly.status}',
        name: name);

    _sdkStatusListener?.cancel();
    _sdkStatusListener = effectiveCodelessly.statusStream.listen((status) {
      DebugLogger.instance.printInfo(
          '[${this.layoutID}]: (Listener) SDK status changed to $status.',
          name: name);

      if (status case CLoaded() || CLoading()) {
        if (status case CLoading(state: CLoadingState state)) {
          DebugLogger.instance.printInfo(
              '[${this.layoutID}]: (Listener) Codelessly SDK is loading with step $state.',
              name: name);

          // Listen to data manager after it has been created. If it hasn't been
          // created yet, Firebase may still be initializing.
          if (state.hasPassed(CLoadingState.createdManagers)) {
            DebugLogger.instance.printInfo(
                '[${this.layoutID}]: (Listener) Checking layout because it passed the created managers step.',
                name: name);

            _checkLayout();
          } else {
            DebugLogger.instance.printInfo(
                '[${this.layoutID}]: (Listener) Waiting for data manager to be created. Skipping for now.',
                name: name);
          }
        } else {
          DebugLogger.instance.printInfo(
              '[${this.layoutID}]: (Listener) Codelessly SDK is already loaded, checking layout.',
              name: name);
          _checkLayout();
        }
      } else {
        DebugLogger.instance.printInfo(
            '[${this.layoutID}]: (Listener) Codelessly SDK is not loaded, skipping layout check.',
            name: name);
      }
    });
  }

  /// Listens to the data manager's status. If the data manager is initialized,
  /// then we can signal to the manager that the desired layout passed to this
  /// widget is ready to be rendered and needs to be downloaded and prepared.
  void _checkLayout() {
    DebugLogger.instance.printFunction('_checkLayout()', name: name);
    DebugLogger.instance
        .printInfo('[$layoutID]: (Check) Checking layout...', name: name);

    // If this CodelesslyWidget wants to preview a layout but the SDK is
    // configured to load published layouts, then we need to initialize the
    // preview data manager.
    // Vice versa for published layouts if the SDK is configured to load preview
    // layouts.
    if ((dataManager.status is! CLoaded && dataManager.status is! CLoading) &&
        effectiveCodelessly.authManager.isAuthenticated()) {
      DebugLogger.instance.printInfo(
        '[$layoutID]: (Check) Initializing data manager for the first time with a publish source of $publishSource because the SDK is configured to load ${publishSource == PublishSource.publish ? 'published' : 'preview'} layouts.',
        name: name,
      );

      dataManager.init(layoutID: layoutID).catchError((error, str) {
        effectiveCodelessly.errorHandler.captureException(
          error,
          stacktrace: str,
          layoutID: layoutID,
        );
      });
    }
    // If the config has a slug specified and the data manager doesn't have
    // a publish model yet, then we need to fetch the publish model from the
    // data manager.
    else if (config.slug != null && dataManager.publishModel == null) {
      DebugLogger.instance.printInfo(
          '[$layoutID]: (Check) A slug is specified and publish model is null.',
          name: name);
      DebugLogger.instance.printInfo(
          '[$layoutID]: (Check) Fetching complete publish bundle from data manager.',
          name: name);
      dataManager
          .fetchCompletePublishBundle(
        slug: config.slug!,
        source: publishSource,
      )
          .catchError((error, str) {
        effectiveCodelessly.errorHandler.captureException(
          error,
          stacktrace: str,
          layoutID: layoutID,
        );
        return false;
      });
    }
    // DataManager is initialized or downloading a publish bundle. If the
    // layoutID is not null, then we need to signal to the data manager that we
    // want to download the layout.
    //
    // If the config has preloading set to true, then the DataManager is already
    // taking care of this layout and we just need to tell it to prioritize it.
    else if (layoutID != null) {
      DebugLogger.instance.printInfo(
          '[$layoutID]: (Check) Queuing layout [$layoutID] in data manager.',
          name: name);
      DebugLogger.instance.printInfo(
          '[$layoutID]: (Check) Using publish source $publishSource.',
          name: name);

      dataManager
          .queueLayout(layoutID: layoutID!, prioritize: true)
          .catchError((error, str) {
        effectiveCodelessly.errorHandler.captureException(
          error,
          stacktrace: str,
          layoutID: layoutID,
        );
      });
    }

    // At this point in the execution, layoutID is null, slug is not specified.
    // Preloading must be true, so this controller can only wait...
    else {
      if (layoutID != null) {
        DebugLogger.instance.printInfo(
            '[$layoutID]: (Check) LayoutID specified, but preload is set to ${config.preload}, skipping to let data manager to download everything',
            name: name);
      } else {
        DebugLogger.instance.printInfo(
            '[$layoutID]: (Check) LayoutID is null, skipping to let data manager to download everything.',
            name: name);
      }
    }
  }
}
