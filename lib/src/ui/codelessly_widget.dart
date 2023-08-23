import 'dart:async';
import 'dart:developer';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../../codelessly_sdk.dart';
import '../logging/error_handler.dart';
import 'codelessly_context.dart';
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
  dynamic exception,
);

Widget _defaultLayoutBuilder(context, layout) => layout;


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

  /// Optional cache manager for advanced control over the SDK's caching
  /// behavior.
  final CacheManager? cacheManager;

  /// Optional placeholder widget to show while the layout is loading.
  final WidgetBuilder? loadingBuilder;

  /// Optional map of widget builders used to build dynamic widgets.
  final Map<String, WidgetBuilder> externalComponentBuilders;

  /// Optional placeholder widget to show if the layout fails to load.
  final CodelesslyWidgetErrorBuilder? errorBuilder;

  /// Optional widget builder to wrap the rendered layout widget with for
  /// advanced control over the layout's behavior.
  final CodelesslyWidgetLayoutBuilder layoutBuilder;

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
  /// [previewDataManager], and [cacheManager] instances for advanced control
  /// over the SDK's behavior.
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
    this.layoutBuilder = _defaultLayoutBuilder,

    // Optional managers overrides.
    this.authManager,
    this.publishDataManager,
    this.previewDataManager,
    this.cacheManager,

    // Data and functions.
    Map<String, dynamic> data = const {},
    Map<String, CodelesslyFunction> functions = const {},
    Map<String, WidgetBuilder> externalComponentBuilders = const {},

    // Additional parameters.
    this.codelesslyContext,
  })  : data = {...data},
        functions = {...functions},
        externalComponentBuilders = {...externalComponentBuilders},
        assert(
          ((config ??
                  (codelessly ?? Codelessly.instance).config ??
                  (controller?.config)) !=
              null),
          controller != null
              ? 'You must provide a CodelesslyConfig inside of your CodelesslyWidgetController or configure the provided codelessly instance with one.'
              : 'You must provide a CodelesslyConfig inside of your CodelesslyWidget or through the Codelessly instance.',
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

  @override
  State<CodelesslyWidget> createState() => _CodelesslyWidgetState();
}

class _CodelesslyWidgetState extends State<CodelesslyWidget> {
  /// The internally created controller if the [CodelesslyWidget] was created
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

  StreamSubscription<CodelesslyException?>? _exceptionSubscription;

  @override
  void initState() {
    super.initState();

    // If a controller was not provided, then create a default internal one and
    // immediately initialize it.
    if (widget.controller == null) {
      _controller = createDefaultController();
      _effectiveController.initialize();
    }

    if (!CodelesslyErrorHandler.didInitialize) {
      _effectiveController.effectiveCodelessly.initErrorHandler(
        firebaseProjectId: _effectiveController.config?.firebaseProjectId,
        automaticallySendCrashReports:
            _effectiveController.config?.automaticallyCollectCrashReports ??
                false,
      );
    }

    _exceptionSubscription =
        CodelesslyErrorHandler.instance.exceptionStream.listen(
      (event) {
        setState(() {});
      },
    );

    if (widget.codelesslyContext != null) {
      log(
        '[CodelesslyWidget] A CodelesslyContext was provided explicitly by'
        ' the widget.',
      );
    }

    codelesslyContext = widget.codelesslyContext ??
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

  /// TODO: If Codelessly instance updates variables or functions, then we need
  ///       to trigger an update.
  ///       The global instance's variables and functions are currently only
  ///       read once, and never updated.
  @override
  void didUpdateWidget(covariant CodelesslyWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.codelesslyContext != widget.codelesslyContext) {
      if (oldWidget.codelesslyContext != null &&
          widget.codelesslyContext == null) {
        // explicitly provided context is removed
        codelesslyContext = codelesslyContext.copyWith();
      } else if (oldWidget.codelesslyContext == null &&
          widget.codelesslyContext != null) {
        // explicitly provided context is added
        codelesslyContext = widget.codelesslyContext!;
      }
      // explicitly provided context is updated
      codelesslyContext = widget.codelesslyContext!;
    }

    if (widget.data != codelesslyContext.data) {
      codelesslyContext.data = widget.data;
      // addPostFrameCallback is used to ensure that the data is updated after
      // the build method is called since setting the data will trigger a
      // rebuild and it will crash if this happens when a rebuild is ongoing.
      SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
        for (final notifier in codelesslyContext.variables.values) {
          notifier.value =
              notifier.value.copyWith(value: widget.data[notifier.value.name]);
        }
      });
    }

    if (widget.functions != codelesslyContext.functions) {
      codelesslyContext.functions = widget.functions;
    }

    if (widget.externalComponentBuilders != oldWidget.externalComponentBuilders) {
      codelesslyContext.externalComponentBuilders = widget.externalComponentBuilders;
    }

    if (widget.controller == null && oldWidget.controller != null) {
      _controller = oldWidget.controller ?? createDefaultController();
    } else if (widget.controller != null && oldWidget.controller == null) {
      _controller!.dispose();
      _controller = null;
    }

    // If the controller is intrinsic, then we need to dispose of the old one
    // and create a new one if any of the values change.
    if (widget.controller == null) {
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
        cacheManager: widget.cacheManager,
      );

  @override
  void dispose() {
    _controller?.dispose();
    _exceptionSubscription?.cancel();

    if (widget.codelesslyContext == null) {
      codelesslyContext.dispose();
    }
    super.dispose();
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
        if (snapshot.hasError) {
          return widget.errorBuilder?.call(context, snapshot.error) ??
              CodelesslyErrorScreen(
                exception: snapshot.error,
                publishSource: _effectiveController.publishSource,
              );
        }

        if (!snapshot.hasData) {
          return widget.loadingBuilder?.call(context) ??
              CodelesslyLoadingScreen();
        }

        if (_effectiveController.layoutID != null &&
            CodelesslyErrorHandler.instance.lastException?.layoutID ==
                _effectiveController.layoutID) {
          return widget.errorBuilder?.call(
                context,
                CodelesslyErrorHandler.instance.lastException,
              ) ??
              CodelesslyErrorScreen(
                exception: snapshot.error,
                publishSource: _effectiveController.publishSource,
              );
        }

        final SDKPublishModel model = snapshot.data!;
        final String layoutID =
            _effectiveController.layoutID ?? model.entryLayoutId!;

        if (!model.layouts.containsKey(layoutID)) {
          return widget.loadingBuilder?.call(context) ??
              CodelesslyLoadingScreen();
        }

        final layoutWidget = Material(
          type: MaterialType.transparency,
          child: CodelesslyPublishedLayoutBuilder(
            key: ValueKey(layoutID),
            layout: model.layouts[layoutID]!,
          ),
        );

        return widget.layoutBuilder(context, layoutWidget);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final Codelessly codelessly = _effectiveController.effectiveCodelessly;
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<CodelesslyContext>.value(
          value: codelesslyContext,
        ),
        Provider<Codelessly>.value(
          value: codelessly,
        ),
      ],
      child: StreamBuilder<CodelesslyStatus>(
        stream: codelessly.statusStream,
        initialData: codelessly.status,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return widget.errorBuilder?.call(context, snapshot.error) ??
                CodelesslyErrorScreen(
                  exception: snapshot.error,
                  publishSource: _effectiveController.publishSource,
                );
          }
          if (!snapshot.hasData) {
            return widget.loadingBuilder?.call(context) ??
                CodelesslyLoadingScreen();
          }
          final CodelesslyStatus status = snapshot.data!;
          switch (status) {
            case CodelesslyStatus.empty:
            case CodelesslyStatus.configured:
            case CodelesslyStatus.loading:
              return widget.loadingBuilder?.call(context) ??
                  CodelesslyLoadingScreen();
            case CodelesslyStatus.error:
              return widget.errorBuilder?.call(context, snapshot.error) ??
                  CodelesslyErrorScreen(
                    exception: CodelesslyErrorHandler.instance.lastException ??
                        snapshot.error,
                    publishSource: _effectiveController.publishSource,
                  );
            case CodelesslyStatus.loaded:
              return buildStreamedLayout();
          }
        },
      ),
    );
  }
}
