import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../../codelessly_sdk.dart';

const String _label = 'Codelessly Widget Controller';

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

  /// Listens to exceptions thrown by the SDK and updates the state of this
  /// controller if the exception is for this layout.
  StreamSubscription<(CodelesslyException, StackTrace)>? _exceptionSubscription;

  /// The last exception that was thrown by the SDK that is relevant to this
  /// specific layout. Used by the CodelesslyWidget attached to this controller
  /// to figure out whether it needs to show an error screen for itself or not.
  CodelesslyException? lastException;

  /// The last trace that was thrown by the SDK that is relevant to this
  /// specific layout. Used by the CodelesslyWidget attached to this controller
  /// to figure out whether it needs to show an error screen for itself or not.
  StackTrace? lastTrace;

  /// Listens to the publish model stream to figure out if the layout is
  /// available in the publish model. If not, then the layout is not published
  /// and the data manager needs to be notified to download it.
  StreamSubscription<SDKPublishModel?>? _publishModelListener;

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
      log(
        'Created an intrinsic Codelessly instance because the global instance is already configured with a different config than the one provided to this controller.',
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
    if (createdIntrinsicCodelessly) {
      codelessly?.dispose(sealCache: false);
    }
    _sdkStatusListener?.cancel();
    _exceptionSubscription?.cancel();
    _publishModelListener?.cancel();
    super.dispose();
  }

  void log(String message) => logger.log(_label, message);

  /// Listens to the SDK's status. If the SDK is done, then we can start
  /// listening to the data manager's status for layout updates.
  void initialize({String? layoutID}) {
    if (layoutID != null) {
      this.layoutID = layoutID;
    }

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
          log('Codelessly SDK is idle, configuring...');
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
          log('Codelessly SDK is configured, initializing...');
          effectiveCodelessly.initialize();
        }
      } else {
        log('Codelessly SDK is already configured and initialized.');
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

      effectiveCodelessly.errorHandler.captureException(exception, trace: str);
    }

    // First event.
    if (effectiveCodelessly.status case CLoaded() || CLoading()) {
      if (effectiveCodelessly.status
          case CLoading(state: CLoadingState state)) {
        // Listen to data manager after it has been created. If it hasn't been
        // created yet, Firebase may still be initializing.
        log('[${this.layoutID}]: Codelessly SDK is loading with step $state.');
        if (state.hasPassed(CLoadingState.createdManagers)) {
          log('[${this.layoutID}]: Checking layout because it passed the create managers step.');
          _checkLayout();
        } else {
          log('[${this.layoutID}]: Waiting for data manager to be created. Skipping for now.');
        }
      } else {
        log('[${this.layoutID}]: Codelessly SDK is already loaded, checking layout.');
        _checkLayout();
      }
    }

    log('[${this.layoutID}]: Listening to sdk status stream.');
    log('[${this.layoutID}]: Initial sdk status is: ${effectiveCodelessly.status}');

    _sdkStatusListener?.cancel();
    _sdkStatusListener = effectiveCodelessly.statusStream.listen((status) {
      log('[${this.layoutID}]: (Listener) SDK status changed to $status.');

      if (status case CLoaded() || CLoading()) {
        if (status case CLoading(state: CLoadingState state)) {
          log('[${this.layoutID}]: (Listener) Codelessly SDK is loading with step $state.');

          // Listen to data manager after it has been created. If it hasn't been
          // created yet, Firebase may still be initializing.
          if (state.hasPassed(CLoadingState.createdManagers)) {
            log('[${this.layoutID}]: (Listener) Checking layout because it passed the create managers step.');

            _checkLayout();
          } else {
            log('[${this.layoutID}]: (Listener) Waiting for data manager to be created. Skipping for now.');
          }
        } else {
          log('[${this.layoutID}]: (Listener) Codelessly SDK is already loaded, checking layout.');
          _checkLayout();
        }
      } else {
        log('[${this.layoutID}]: (Listener) Codelessly SDK is not loaded, skipping layout check.');
      }
    });
  }

  bool didListenToDataManager = false;

  /// If the data manager changes and this layout id does not yet exist, request
  /// it again.
  void _listenToDataManager() {
    if (didListenToDataManager) return;
    didListenToDataManager = true;

    _publishModelListener?.cancel();
    _publishModelListener = publishModelStream.listen((model) {
      if (model == null) return;
      if (layoutID == null) return;

      log('[$layoutID]: (Data manager listener) Publish model changed, checking if layout still exists in it.');

      if (!model.layouts.containsKey(layoutID!)) {
        log('[$layoutID]: (Data manager listener) Publish model changed, but layout [$layoutID] does not exist in it anymore. Forcing a re-check.');
        _checkLayout();
      } else {
        log('[$layoutID]: (Data manager listener) Publish model changed, [$layoutID] exists in the publish model. Clearing exceptions if any.');
        clearExceptions();
      }
    });
  }

  bool didInitExceptionNotifications = false;

  /// Listens to exceptions thrown by the SDK and updates the state of this
  /// controller if the exception is for this layout.
  ///
  /// The reason this function is separate from initialize is because
  /// the CodelesslySDK may not have initialized it's error handler just yet.
  void _initExceptionNotifications() {
    if (didInitExceptionNotifications) return;
    didInitExceptionNotifications = true;

    // When this function is first called, the last events of the exception
    // controller will not be buffered and emitted here. Therefore, before this
    // listener is first attached, we check the current exceptions that have
    // last been thrown by the SDK for relevance.
    final exception = effectiveCodelessly.errorHandler.lastException;
    final trace = effectiveCodelessly.errorHandler.lastTrace;

    if (exception != null && trace != null) {
      if (exception.identifier == layoutID) {
        lastException = exception;
        lastTrace = trace;

        if (hasListeners) {
          notifyListeners();
        }
      }
    }

    // Listen to future exceptions.
    _exceptionSubscription?.cancel();
    _exceptionSubscription =
        effectiveCodelessly.errorHandler.exceptionStream.listen((event) {
      final exception = event.$1;
      final trace = event.$2;

      if (exception.identifier == layoutID) {
        lastException = exception;
        lastTrace = trace;

        if (hasListeners) {
          notifyListeners();
        }
      }
    });
  }

  void clearExceptions() {
    if (lastException != null || lastTrace != null) {
      lastException = null;
      lastTrace = null;

      if (hasListeners) {
        notifyListeners();
      }
    }
  }

  /// Listens to the data manager's status. If the data manager is initialized,
  /// then we can signal to the manager that the desired layout passed to this
  /// widget is ready to be rendered and needs to be downloaded and prepared.
  void _checkLayout() {
    log('[$layoutID]: (Check) Checking layout...');
    _initExceptionNotifications();
    _listenToDataManager();

    // If this CodelesslyWidget wants to preview a layout but the SDK is
    // configured to load published layouts, then we need to initialize the
    // preview data manager.
    // Vice versa for published layouts if the SDK is configured to load preview
    // layouts.
    if ((dataManager.status is! CLoaded && dataManager.status is! CLoading) &&
        effectiveCodelessly.authManager.isAuthenticated()) {
      log('[$layoutID]: (Check) Initializing data manager for the first time with a publish source of $publishSource because the SDK is configured to load ${publishSource == PublishSource.publish ? 'published' : 'preview'} layouts.');

      dataManager.init(layoutID: layoutID).catchError((error, str) {
        effectiveCodelessly.errorHandler.captureException(error, trace: str);
      });
    }
    // If the config has a slug specified and the data manager doesn't have
    // a publish model yet, then we need to fetch the publish model from the
    // data manager.
    else if (config.slug != null && dataManager.publishModel == null) {
      log('[$layoutID]: (Check) A slug is specified and publish model is null.');
      log('[$layoutID]: (Check) Fetching complete publish bundle from data manager.');
      dataManager.fetchCompletePublishBundle(
        slug: config.slug!,
        source: publishSource,
      );
    }
    // DataManager is initialized or downloading a publish bundle. If the
    // layoutID is not null, then we need to signal to the data manager that we
    // want to download the layout.
    //
    // If the config has preloading set to true, then the DataManager is already
    // taking care of this layout and we just need to tell it to prioritize it.
    else if (layoutID != null) {
      log('[$layoutID]: (Check) Queuing layout [$layoutID] in data manager. ${lastException != null ? 'Clearing current exceptions.' : ''}');
      log('[$layoutID]: (Check) Using publish source $publishSource.');

      clearExceptions();
      dataManager.queueLayout(layoutID: layoutID!, prioritize: true);
    }

    // At this point in the execution, layoutID is null, slug is not specified.
    // Preloading must be true, so this controller can only wait...
    else {
      if (layoutID != null) {
        log('[$layoutID]: (Check) LayoutID specified, but preload is set to ${config.preload}, skipping to let data manager download everything.');
      } else {
        log('[$layoutID]: (Check) LayoutID is null, skipping to let data manager to download everything.');
      }
    }
  }
}
