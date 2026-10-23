import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../../codelessly_sdk.dart';
import '../functions/action_chain.dart';
import '../logging/stat_tracker.dart';
import 'codelessly_error_screen.dart';
import 'codelessly_loading_screen.dart';
import 'layout_builder.dart';

/// Allows wrapping a loaded [Codelessly] layout with any widget for additional
/// control over the rendering.
typedef CodelesslyWidgetLayoutBuilder = Widget Function(
  BuildContext context,
  Widget layout,
);

/// Allows creation of a custom error screen for when a [Codelessly] layout
/// fails to load.
typedef CodelesslyWidgetErrorBuilder = Widget Function(
  BuildContext context,
  ErrorLog error,
);

Widget _defaultLayoutBuilder(BuildContext context, Widget layout) => layout;

/// SDK widget that requires the SDK to be initialized beforehand.
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
///
/// 4. Using a [controller], which can be customized in any of the ways
///    described above but with explicit control over the state.
class CodelesslyWidget extends StatefulWidget {
  static const String name = 'CodelesslyWidget';

  /// An external [CodelesslyWidgetController] to use. If this is not provided,
  /// an internal one will be created.
  final CodelesslyWidgetController? controller;

  /// The ID of the layout provided from your Codelessly dashboard.
  /// This represents a single screen or canvas.
  ///
  /// If this is null, the controller's layoutID will be used.
  /// This cannot be null if no controller is provided.
  final String? layoutID;

  /// The [Codelessly] instance to use.
  ///
  /// By default, if this is null, the global instance is used, which is
  /// retrieved via [Codelessly.instance].
  final Codelessly? codelessly;

  /// Whether to show the preview version of the provided layout rather than the
  /// published version.
  ///
  /// If a value is provided, it will override the value provided in
  /// [CodelesslyConfig.publishSource].
  /// If a [controller] is provided, the controller's [publishSource] value will
  /// override this value.
  final PublishSource? publishSource;

  /// Holds a map of data to replace.
  ///
  /// This is in addition to the data map provided inside the [Codelessly]
  /// instance. Keys in this map will override keys in the [Codelessly]
  /// instance.
  final Map<String, dynamic> data;

  /// Holds a map of functions to run when called.
  ///
  /// This is in addition to the functions map provided inside the [Codelessly]
  /// instance. Keys in this map will override keys in the [Codelessly]
  /// instance.
  final Map<String, CodelesslyFunction> functions;

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

  /// Optional template data manager for advanced control over the SDK's
  /// template data flow.
  final DataManager? templateDataManager;

  /// Optional cache manager for advanced control over the SDK's caching
  /// behavior.
  final CacheManager? cacheManager;

  /// Optional widget builder to wrap the rendered layout widget with for
  /// advanced control over the layout's behavior.
  final CodelesslyWidgetLayoutBuilder? layoutBuilder;

  /// Returns a widget that decides how to load nested layouts of a rendered
  /// node.
  final LayoutRetrieverBuilder? layoutRetrievalBuilder;

  /// Optional placeholder widget to show while the layout is loading.
  final WidgetBuilder? loadingBuilder;

  /// Optional placeholder widget to show if the layout fails to load.
  final CodelesslyWidgetErrorBuilder? errorBuilder;

  /// Optional map of widget builders used to build dynamic widgets.
  final Map<String, WidgetBuilder> externalComponentBuilders;

  /// Optional [CodelesslyContext] that can be provided explicitly if needed.
  final CodelesslyContext? codelesslyContext;

  /// Creates a [CodelesslyWidget].
  ///
  /// Required parameters for base functionality:
  /// A [layoutID] will determine which layout to load. If that is not provided,
  /// then a [controller] must be provided with its own [layoutID].
  ///
  /// If neither are provided, then it is assumed that the published model is
  /// public via a defined slug or is a template for the template gallery, in
  /// which case, the [SDKPublishModel.entryLayoutID] is provided and must not
  /// be null. If it is not provided, than there is an error in the data,
  /// perhaps from a usage bug in the Codelessly Editor.
  ///
  /// [data] is a map of data that will be used to populate the layout.
  ///
  /// [functions] is a map of functions that will be used to populate the
  /// layout.
  ///
  /// [loadingBuilder] is a widget that will be shown while the layout is
  /// being loaded.
  ///
  /// [errorBuilder] is a widget that will be shown if the layout fails to load.
  ///
  /// [layoutBuilder] can be used to wrap any widget provided to it around the
  /// loaded layout for advanced control over the rendered widget.
  ///
  /// Optionally, provide custom [authManager], [publishDataManager],
  /// [previewDataManager], [templateDataManager], and [cacheManager] instances
  /// for advanced control over the SDK's behavior.
  CodelesslyWidget({
    super.key,
    this.layoutID,
    this.controller,
    this.codelessly,
    this.config,
    this.publishSource,

    // UI.
    this.loadingBuilder,
    this.errorBuilder,
    this.layoutBuilder,
    this.layoutRetrievalBuilder,

    // Optional managers overrides.
    this.authManager,
    this.publishDataManager,
    this.previewDataManager,
    this.templateDataManager,
    this.cacheManager,

    // Data and functions.
    Map<String, dynamic> data = const {},
    Map<String, CodelesslyFunction> functions = const {},
    Map<String, WidgetBuilder> externalComponentBuilders = const {},

    // Additional parameters.
    this.codelesslyContext,
  }) : data = {...data},
       functions = {...functions},
       externalComponentBuilders = {...externalComponentBuilders},
       assert(
         ((config ??
                 (codelessly ?? Codelessly.instance).config ??
                 (controller?.config)) !=
             null),
         controller != null
             ? 'You must provide a [config] inside of your [controller] or configure the provided codelessly instance with one.'
             : 'You must provide a [config] inside of your CodelesslyWidget or through the Codelessly instance.',
       ),
       assert(
         ((layoutID != null) != (controller != null)) ||
             ((config ??
                         (codelessly ?? Codelessly.instance).config ??
                         (controller?.config)))!
                     .slug !=
                 null,
         'You must provide either a [layoutID] or a [controller]. One must be specified, and both cannot be specified at the same time.'
         '\nIf you provided neither, then a slug must be configured in the config.',
       ),
       assert(
         (publishSource == null && controller == null) ||
             (publishSource != null) != (controller != null),
         'You must provide either an [publishSource] or a [controller]. One must be specified, and both cannot be specified at the same time.',
       ),
       assert(
         (codelessly == null && controller == null) ||
             (codelessly != null) != (controller != null),
         'You must provide either a [codelessly] or a [controller]. One may be specified, and both cannot be specified at the same time.',
       );

  /// Retrieves the canvas ID of [layoutID] for a layout of [width] logical
  /// pixels. Returns null if the layout does not exist or has no canvas for
  /// that width.
  static String? canvasIDForWidth(
    String? layoutID,
    SDKPublishModel model,
    double width,
  ) {
    if (layoutID == null) return null;
    final SDKPublishLayout? layout = model.layouts[layoutID];
    if (layout == null) return null;
    // A standalone layout: no breakpoints to check.
    if (layout.canvases.length == 1) return layout.canvases.keys.first;
    // A layout group: the canvas whose breakpoint covers [width].
    return layout.breakpoints.findForWidth(width)?.nodeId;
  }

  /// The width breakpoints are picked by: the width this widget is laid out
  /// in, so a layout embedded in a 390 wide frame inside a 1440 wide window
  /// shows its 390 canvas. Only when that width is unbounded (inside a
  /// horizontal scroll view) does the screen width stand in for it.
  static double breakpointWidth(BuildContext context, BoxConstraints box) =>
      box.hasBoundedWidth ? box.maxWidth : MediaQuery.sizeOf(context).width;

  @override
  State<CodelesslyWidget> createState() => _CodelesslyWidgetState();
}

class _CodelesslyWidgetState extends State<CodelesslyWidget> {
  /// The internally created controller if the was created
  /// without one.
  CodelesslyWidgetController? _controller;

  /// The [CodelesslyWidgetController] that will be used to control the
  /// [CodelesslyWidget].
  ///
  /// Falls back to the internally created controller if
  /// one was not provided in the constructor of the [CodelesslyWidget].
  CodelesslyWidgetController get _effectiveController =>
      widget.controller ?? _controller!;

  /// The [CodelesslyContext] that will hold the data and functions that will be
  /// used to render the layout.
  ///
  /// This object is observed through InheritedWidget. Node transformers can
  /// find this object using: `Provider.of<CodelesslyContext>(context)`.
  /// or `context.read<CodelesslyContext>()`.
  late CodelesslyContext codelesslyContext;

  Stopwatch? _stopwatch;

  CodelesslyWidgetLayoutBuilder get _effectiveLayoutBuilder =>
      widget.layoutBuilder ??
      _effectiveController.layoutBuilder ??
      _defaultLayoutBuilder;

  LayoutRetrieverBuilder? get _effectiveLayoutRetrieverBuilder =>
      widget.layoutRetrievalBuilder ??
      _effectiveController.layoutRetrievalBuilder;

  WidgetBuilder? get _effectiveLoadingBuilder =>
      widget.loadingBuilder ?? _effectiveController.loadingBuilder;

  CodelesslyWidgetErrorBuilder? get _effectiveErrorBuilder =>
      widget.errorBuilder ?? _effectiveController.errorBuilder;

  StreamSubscription<ErrorLog>? _errorSubscription;
  ErrorLog? _lastError;

  /// The canvas shown for the current breakpoint. Compared with the canvas
  /// picked for the latest available width to tell when the breakpoint
  /// changes.
  String? canvasID;

  /// The layout being shown.
  String? effectiveLayoutID;

  /// The canvas the controller's [CodelesslyWidgetController.initialLocation]
  /// opened, if any.
  CanvasLocationMatch? locationMatch;

  /// Tracks whether this widget went through a full layout load and was made
  /// visible to the user successfully at least once.
  bool didView = false;

  @override
  void initState() {
    super.initState();

    // If a controller was not provided, then create a default internal one and
    // immediately initialize it.
    if (widget.controller == null) {
      _controller = createDefaultController();
      _effectiveController.initialize();
    }

    _errorSubscription = ErrorLogger.instance.errorStream.listen((
      ErrorLog error,
    ) {
      if (error.layoutID == _effectiveController.layoutID) {
        setState(() {
          _lastError = error;
        });
      }
    });

    if (widget.codelesslyContext != null) {
      DebugLogger.instance.printInfo(
        'A CodelesslyContext was provided explicitly by the widget.',
        name: CodelesslyWidget.name,
      );
    }

    codelesslyContext =
        widget.codelesslyContext ??
        CodelesslyContext(
          data: widget.data,
          functions: widget.functions,
          externalComponentBuilders: widget.externalComponentBuilders,
          nodeValues: {},
          variables: {},
          conditions: {},
          layoutID: _effectiveController.layoutID,
        );
  }

  @override
  void didUpdateWidget(covariant CodelesslyWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.codelesslyContext != widget.codelesslyContext) {
      if (oldWidget.codelesslyContext != null &&
          widget.codelesslyContext == null) {
        // explicitly provided context is removed
        codelesslyContext = codelesslyContext.copyWith();
      } else {
        // explicitly provided context is added or replaced
        codelesslyContext = widget.codelesslyContext!;
      }
    }

    if (widget.data != codelesslyContext.data) {
      codelesslyContext.data = widget.data;
      // addPostFrameCallback is used to ensure that the data is updated after
      // the build method is called since setting the data will trigger a
      // rebuild and it will crash if this happens when a rebuild is ongoing.
      SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
        if (!mounted) return;
        for (final notifier in codelesslyContext.variables.values) {
          notifier.value = notifier.value.copyWith(
            value: widget.data[notifier.value.name],
          );
        }
      });
    }

    if (widget.functions != codelesslyContext.functions) {
      codelesslyContext.functions = widget.functions;
    }

    if (widget.externalComponentBuilders !=
        oldWidget.externalComponentBuilders) {
      codelesslyContext.externalComponentBuilders =
          widget.externalComponentBuilders;
    }

    if (widget.controller == null && oldWidget.controller != null) {
      // The external controller was removed. It belongs to the caller, so
      // create and own a new internal one instead of adopting it.
      _controller = createDefaultController();
      _effectiveController.initialize();
      codelesslyContext.layoutID = _effectiveController.layoutID;
    } else if (widget.controller != null && oldWidget.controller == null) {
      _controller!.dispose();
      _controller = null;
    } else if (widget.controller == null) {
      // If the controller is intrinsic, then we need to dispose of the old one
      // and create a new one if any of the values change.
      if (widget.publishSource != oldWidget.publishSource ||
          widget.layoutID != oldWidget.layoutID ||
          widget.codelessly != oldWidget.codelessly) {
        _controller?.dispose();
        _controller = createDefaultController();
        _effectiveController.initialize();
        codelesslyContext.layoutID = _effectiveController.layoutID;
      }
    }
  }

  /// Creates a default controller if one was not provided in the constructor.
  CodelesslyWidgetController createDefaultController() =>
      CodelesslyWidgetController(
        layoutID: widget.layoutID,
        codelessly: widget.codelessly,
        publishSource: widget.publishSource,
        config: widget.config,
        authManager: widget.authManager,
        publishDataManager: widget.publishDataManager,
        previewDataManager: widget.previewDataManager,
        templateDataManager: widget.templateDataManager,
        cacheManager: widget.cacheManager,
        layoutBuilder: widget.layoutBuilder,
        layoutRetrievalBuilder: widget.layoutRetrievalBuilder,
        loadingBuilder: widget.loadingBuilder,
        errorBuilder: widget.errorBuilder,
      );

  @override
  void dispose() {
    _errorSubscription?.cancel();
    _controller?.dispose();
    _stopwatch?.stop();

    if (widget.codelesslyContext == null) {
      codelesslyContext.dispose();
    }
    super.dispose();
  }

  /// Builds the layout for the canvas that fits the width this widget is given,
  /// switching canvases (and notifying breakpoint listeners) when it changes.
  Widget _buildForBreakpoint(
    SDKPublishModel model,
    Widget Function(BuildContext context) builder,
  ) {
    final SDKPublishLayout layout = model.layouts[effectiveLayoutID!]!;
    if (layout.canvases.length == 1) {
      canvasID = layout.canvases.keys.first;
      return builder(context);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final String? newCanvasID = CodelesslyWidget.canvasIDForWidth(
          effectiveLayoutID,
          model,
          CodelesslyWidget.breakpointWidth(context, constraints),
        );
        final bool changed = canvasID != null && newCanvasID != canvasID;
        canvasID = newCanvasID ?? canvasID ?? layout.canvases.keys.first;
        if (changed) {
          final breakpoint = layout.breakpoints.firstWhereOrNull(
            (breakpoint) => breakpoint.nodeId == canvasID,
          );
          // Listeners may rebuild widgets, which is not allowed mid-layout.
          if (breakpoint != null) {
            SchedulerBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _effectiveController.effectiveCodelessly
                  .notifyBreakpointsListeners(context, breakpoint);
            });
          }
        }
        return builder(context);
      },
    );
  }

  /// Once the SDK is successfully initialized, we can build the layout.
  /// A [StreamBuilder] is used to listen to layout changes whenever a user
  /// publishes a new update through the Codelessly publish menu, the changes
  /// are immediately reflected here.
  Widget buildStreamedLayout() {
    return StreamBuilder<SDKPublishModel?>(
      stream: _effectiveController.publishModelStream,
      initialData: _effectiveController.publishModel,
      builder: (context, AsyncSnapshot<SDKPublishModel?> snapshot) {
        final status = _effectiveController.dataManager.status;
        try {
          if (snapshot.hasError || status is CError) {
            final ErrorLog error;
            if (_lastError != null) {
              error = _lastError!;
            } else {
              error = ErrorLog(
                timestamp: DateTime.now(),
                message: snapshot.error?.toString() ?? 'Unknown error',
                type: 'stream_error',
              );
            }

            return _effectiveErrorBuilder?.call(context, error) ??
                CodelesslyErrorScreen(
                  errors: [error],
                  publishSource: _effectiveController.publishSource,
                );
          }

          if (!snapshot.hasData || status is! CLoaded) {
            return _effectiveLoadingBuilder?.call(context) ??
                const CodelesslyLoadingScreen();
          }

          final SDKPublishModel model = snapshot.data!;
          final String? initialLocation = _effectiveController.initialLocation;
          locationMatch =
              _effectiveController.layoutID == null && initialLocation != null
              ? CanvasLocation.match(model, initialLocation)
              : null;
          effectiveLayoutID =
              _effectiveController.layoutID ??
              locationMatch?.layoutId ??
              model.entryLayoutId;

          if (effectiveLayoutID == null) {
            final errorLog = ErrorLog(
              timestamp: DateTime.now(),
              message: 'A layoutID was not specified and the model does not have an entry layoutID specified.',
              type: 'layout_not_initialized',
            );

            return _effectiveErrorBuilder?.call(context, errorLog) ??
                CodelesslyErrorScreen(
                  errors: [errorLog],
                  publishSource: _effectiveController.publishSource,
                );
          }

          if (model.disabledLayouts.contains(effectiveLayoutID)) {
            return const SizedBox.shrink();
          }

          if (!model.layouts.containsKey(effectiveLayoutID!)) {
            return _effectiveLoadingBuilder?.call(context) ??
                const CodelesslyLoadingScreen();
          }

          if (!didView) {
            didView = true;
            StatTracker.instance.track(StatType.view);
          }

          // A screen opened at a location gets its params as route params,
          // which its host's route was not pushed with.
          Widget withRouteParams(Widget child) => locationMatch == null
              ? child
              : CodelesslyRouteParams(
                  route: ModalRoute.of(context),
                  params: locationMatch!.params,
                  child: child,
                );

          Widget buildLayout(BuildContext context) => Material(
            clipBehavior: Clip.none,
            type: MaterialType.transparency,
            child: CodelesslyLayoutBuilder(
              // This key is important to ensure that the layout is rebuilt
              // from scratch whenever the layout ID changes, not when the
              // canvas ID changes. This is because when the layout ID changes,
              // the controller changes too and everything is reinitialized. So
              // it makes sense to rebuild the layout from scratch. However,
              // when the canvas ID changes, we don't reinitialize the
              // controller, only the widget needs to reload the layout,
              // conditions, and variables which is done in the [loadLayout]
              // method of the this widget. It uses the passed [canvasId] to
              // reload necessary data for given canvas ID.
              key: ValueKey(effectiveLayoutID),
              controller: _effectiveController,
              layout: model.layouts[effectiveLayoutID!]!,
              // ID of the canvas to load for current breakpoint.
              canvasId: canvasID!,
              layoutRetrievalBuilder: _effectiveLayoutRetrieverBuilder,
            ),
          );

          if (_stopwatch != null && _stopwatch!.isRunning) {
            final millis = _stopwatch!.elapsedMilliseconds;
            _stopwatch?.stop();
            DebugLogger.instance.printInfo(
              'Layout loaded in ${millis}ms or ${millis / 1000}s',
              name: CodelesslyWidget.name,
            );
          }

          // The breakpoint (and so the canvas) is known only once the width
          // this widget gets is, so navigation listeners hear of the canvas
          // from inside the breakpoint builder.
          return _effectiveLayoutBuilder(
            context,
            _buildForBreakpoint(
              model,
              (context) => _NavigationBuilder(
                key: ValueKey(effectiveLayoutID),
                layoutId: effectiveLayoutID,
                canvasId: canvasID,
                builder: (context) => withRouteParams(buildLayout(context)),
              ),
            ),
          );
        } catch (e, str) {
          final errorLog = ErrorLog(
            timestamp: DateTime.now(),
            message: e.toString(),
            type: 'build_error',
            stackTrace: str,
          );

          ErrorLogger.instance.captureException(
            e,
            message: 'Error building layout',
            type: 'layout_build_failed',
            layoutID: _effectiveController.layoutID,
            stackTrace: str,
          );

          return _effectiveErrorBuilder?.call(context, errorLog) ??
              CodelesslyErrorScreen(
                errors: [errorLog],
                publishSource: _effectiveController.publishSource,
              );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    _stopwatch ??= Stopwatch()..start();
    final Codelessly codelessly = _effectiveController.effectiveCodelessly;

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<CodelesslyContext>.value(
          value: codelesslyContext,
        ),
        ChangeNotifierProvider<CodelesslyWidgetController>.value(
          value: _effectiveController,
        ),
        Provider<Codelessly>.value(value: codelessly),
      ],
      // Action chains started in this layout finish with this context when
      // the widget that started them unmounts, e.g. a list row whose
      // document the chain removed.
      child: ActionChainHost(
        child: StreamBuilder<CStatus>(
          stream: codelessly.statusStream,
          initialData: codelessly.status,
          builder: (context, snapshot) {
            Widget loading() =>
                _effectiveLoadingBuilder?.call(context) ??
                const CodelesslyLoadingScreen();

            Widget error(Object? error) {
              final ErrorLog errorLog;
              if (_lastError != null) {
                errorLog = _lastError!;
              } else {
                errorLog = ErrorLog(
                  timestamp: DateTime.now(),
                  message: error?.toString() ?? 'Unknown error',
                  type: 'build_error',
                );
              }

              return _effectiveErrorBuilder?.call(context, errorLog) ??
                  CodelesslyErrorScreen(
                    errors: [errorLog],
                    publishSource: _effectiveController.publishSource,
                  );
            }

            if (snapshot.hasError) return error(snapshot.error);
            if (!snapshot.hasData) return loading();

            final CStatus status = snapshot.data!;
            return switch (status) {
              CEmpty() || CConfigured() => loading(),
              CError(message: final msg) => error(msg),
              CLoading(state: CLoadingState state) =>
                state.hasPassed(CLoadingState.createdManagers)
                    ? buildStreamedLayout()
                    : loading(),
              CLoaded() => buildStreamedLayout(),
            };
          },
        ),
      ),
    );
  }
}

class _NavigationBuilder extends StatefulWidget {
  final WidgetBuilder builder;
  final String? layoutId;
  final String? canvasId;

  const _NavigationBuilder({
    super.key,
    required this.builder,
    required this.layoutId,
    required this.canvasId,
  });

  @override
  State<_NavigationBuilder> createState() => _NavigationBuilderState();
}

class _NavigationBuilderState extends State<_NavigationBuilder> {
  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
      if (!context.mounted) return;
      context.read<Codelessly>().notifyNavigationListeners(
        context,
        layoutId: widget.layoutId,
        canvasId: widget.canvasId,
      );
    });
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}
