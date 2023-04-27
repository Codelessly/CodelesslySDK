import 'dart:async';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../codelessly_sdk.dart';
import '../auth/auth_manager.dart';
import '../cache/cache_manager.dart';
import '../error/error_handler.dart';
import 'codelessly_error_screen.dart';
import 'codelessly_loading_screen.dart';
import 'codelessly_widget_controller.dart';
import 'layout_builder.dart';

typedef CodelesslyWidgetLayoutBuilder = Widget Function(
  BuildContext context,
  Widget layout,
);

Widget _defaultLayoutBuilder(context, layout) => layout;

/// Holds data passed from the Codelessly instance down the widget tree where
/// all of the [WidgetNodeTransformer]s have access to it.
class CodelesslyContext with EquatableMixin {
  /// A map of data that is passed to loaded layouts for nodes to replace
  /// their values with.
  final Map<String, dynamic> data;

  /// A map of functions that is passed to loaded layouts for nodes to call
  /// when they are triggered.
  final Map<String, CodelesslyFunction> functions;

  /// A map that holds the current values of nodes that have internal values.
  final Map<String, ValueNotifier<List<ValueModel>>> nodeValues;

  /// Creates a [CodelesslyContext] with the given [data], [functions], and
  /// [nodeValues].
  const CodelesslyContext({
    required this.data,
    required this.functions,
    required this.nodeValues,
  });

  /// Creates a [CodelesslyContext] with empty an empty map of each property.
  CodelesslyContext.empty()
      : data = {},
        functions = {},
        nodeValues = {};

  /// Creates a copy of this [CodelesslyContext] with the given [data],
  /// [functions], and [nodeValues].
  CodelesslyContext copyWith({
    Map<String, dynamic>? data,
    Map<String, CodelesslyFunction>? functions,
    Map<String, ValueNotifier<List<ValueModel>>>? nodeValues,
  }) {
    return CodelesslyContext(
      data: data ?? this.data,
      functions: functions ?? this.functions,
      nodeValues: nodeValues ?? this.nodeValues,
    );
  }

  /// TODO: @Aachman document this
  void handleActionConnections(
    ActionModel actionModel,
    Map<String, BaseNode> nodes,
  ) {
    switch (actionModel.type) {
      case ActionType.submit:
        final action = actionModel as MailchimpSubmitAction;
        final BaseNode? primaryField = nodes[action.primaryTextField];
        final BaseNode? firstNameField = nodes[action.firstNameField];
        final BaseNode? lastNameField = nodes[action.lastNameField];
        if (primaryField != null) {
          addToNodeValues(primaryField, [StringValue(name: 'inputValue')]);
        }
        if (firstNameField != null) {
          addToNodeValues(firstNameField, [StringValue(name: 'inputValue')]);
        }
        if (lastNameField != null) {
          addToNodeValues(lastNameField, [StringValue(name: 'inputValue')]);
        }
        break;
      case ActionType.setValue:
        final action = actionModel as SetValueAction;
        final SceneNode? connectedNode = nodes[action.nodeID] as SceneNode?;
        // Populate node values with node's values, not action's values.
        if (connectedNode != null) {
          addToNodeValues(
              connectedNode,
              connectedNode.propertyVariables
                  .where((property) =>
                      action.values.any((value) => property.name == value.name))
                  .toList());
        }
        break;
      case ActionType.setVariant:
        final action = actionModel as SetVariantAction;
        final VarianceNode? connectedNode =
            nodes[action.nodeID] as VarianceNode?;
        // Populate node values with node's variant value, not action's variant
        // value.
        if (connectedNode != null) {
          addToNodeValues(connectedNode, [
            StringValue(name: 'variant', value: connectedNode.currentVariantId)
          ]);
        }
        break;
      default:
    }
  }

  /// TODO: @Aachman document this
  void addToNodeValues(BaseNode node, List<ValueModel> values) {
    // Get current values for the node, if any.
    final List<ValueModel> currentValues = nodeValues[node.id]?.value ?? [];
    // New values.
    final List<ValueModel> newValues = [];
    // Filter out and populate new values.
    for (final ValueModel value in values) {
      if (!currentValues
          .any((currentValue) => currentValue.name == value.name)) {
        newValues.add(value);
      }
    }
    // Add new values to the node's values list.
    nodeValues[node.id] = ValueNotifier([...currentValues, ...newValues]);
  }

  @override
  List<Object?> get props => [data, functions];
}

/// SDK widget that requires the SDK to be initialized before hand.
class CodelesslyWidget extends StatefulWidget {
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
  /// retrieved via Codelessly.instance.
  final Codelessly? codelessly;

  /// Whether to show the preview version of the provided layout rather than the
  /// published version.
  ///
  /// If a value is provided, it will override the value provided in
  /// [CodelesslyConfig.isPreview].
  /// If a [controller is provided, the controller's [isPreview] value will
  /// override this value.
  final bool? isPreview;

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
  final WidgetBuilder? loadingPlaceholder;

  /// Optional widget builder to wrap the rendered layout widget with for
  /// advanced control over the layout's behavior.
  final CodelesslyWidgetLayoutBuilder layoutBuilder;

  /// Creates a [CodelesslyWidget].
  ///
  /// Can be instantiated in several ways:
  ///
  /// 1. Using the global instance of the SDK by not passing any of the
  ///    relevant parameters. Initialization of the global instance is done
  ///    implicitly if not already initialized.
  ///
  /// 2. Using your own [codelessly] instance, initialization of the
  ///    [codelessly] instance must be done explicitly.
  ///
  /// 3. Using your own [config], which will be used to initialize the global
  ///    [codelessly] instance.
  ///
  /// You can optionally provide your own [authManager], [publishDataManager],
  /// [previewDataManager], and [cacheManager] instances for advanced control
  /// over the SDK's behavior.
  ///
  /// [data] is a map of data that will be used to populate the layout.
  ///
  /// [functions] is a map of functions that will be used to populate the
  /// layout.
  ///
  /// [loadingPlaceholder] is a widget that will be shown while the layout is
  /// being loaded.
  ///
  /// [layoutBuilder] can be used to wrap any widget provided to it around the
  /// loaded layout for advanced control over the rendered widget.
  CodelesslyWidget({
    super.key,
    this.layoutID,
    this.controller,
    this.isPreview,
    this.codelessly,
    this.config,
    this.loadingPlaceholder,
    this.layoutBuilder = _defaultLayoutBuilder,

    // Optional managers. These are only used when using the global codelessly
    // instance.
    this.authManager,
    this.publishDataManager,
    this.previewDataManager,
    this.cacheManager,

    // Data and functions.
    Map<String, String> data = const {},
    Map<String, CodelesslyFunction> functions = const {},
  })  : data = {...data},
        functions = {...functions},
        assert(
          (layoutID != null) != (controller != null),
          'You must provide either a [layoutID] or a [controller]. One must be specified, and both cannot be specified at the same time.',
        ),
        assert(
          (isPreview == null && controller == null) ||
              (isPreview != null) != (controller != null),
          'You must provide either an [isPreview] or a [controller]. One must be specified, and both cannot be specified at the same time.',
        ),
        assert(
          (codelessly == null && controller == null) ||
              (codelessly != null) != (controller != null),
          'You must provide either a [codelessly] or a [controller]. One must be specified, and both cannot be specified at the same time.',
        ),
        assert(
          ((config ??
                  (codelessly ?? Codelessly.instance).config ??
                  (controller?.config)) !=
              null),
          controller != null
              ? 'You must provide a CodelesslyConfig inside of your CodelesslyWidgetController or configure the provided codelessly instance with one.'
              : 'You must provide a CodelesslyConfig inside of your CodelesslyWidget or through the Codelessly instance.',
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

  /// The [CodelesslyContext] that will hold the data and functions that will
  /// be used to render the layout.
  ///
  /// This object is observed through InheritedWidget. Node transformers can
  /// find this object using: `Provider.of<CodelesslyContext>(context)`.
  /// or `context.read<CodelesslyContext>()`.
  late CodelesslyContext codelesslyContext = CodelesslyContext(
    data: widget.data,
    functions: widget.functions,
    nodeValues: {},
  );

  @override
  void initState() {
    super.initState();

    if (widget.controller == null) {
      _controller = createDefaultController();
    }

    if (!_effectiveController.didInitialize) {
      _effectiveController.init();
    }
  }

  /// TODO: If Codelessly instance updates variables or functions, then we need
  ///       to trigger an update.
  ///       The global instance's variables and functions are currently only
  ///       read once, and never updated.
  @override
  void didUpdateWidget(covariant CodelesslyWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.data != codelesslyContext.data ||
        widget.functions != codelesslyContext.functions) {
      codelesslyContext = codelesslyContext.copyWith(
        data: widget.data,
        functions: widget.functions,
      );
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
      if (widget.isPreview != oldWidget.isPreview ||
          widget.layoutID != oldWidget.layoutID ||
          widget.codelessly != oldWidget.codelessly) {
        _controller?.dispose();
        _controller = createDefaultController();
        _effectiveController.init();
      }
    }
  }

  /// Creates a default controller if one was not provided in the constructor.
  CodelesslyWidgetController createDefaultController() =>
      CodelesslyWidgetController(
        layoutID: widget.layoutID!,
        codelessly: widget.codelessly,
        isPreview: widget.isPreview,
        config: widget.config,
        authManager: widget.authManager,
        publishDataManager: widget.publishDataManager,
        previewDataManager: widget.previewDataManager,
        cacheManager: widget.cacheManager,
      );

  @override
  void dispose() {
    _controller?.dispose();
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
          return CodelesslyErrorScreen(
            exception: snapshot.error,
            isPreview: _effectiveController.isPreview,
          );
        }

        if (!snapshot.hasData) {
          return widget.loadingPlaceholder?.call(context) ??
              CodelesslyLoadingScreen();
        }

        final SDKPublishModel model = snapshot.data!;
        final String layoutID = _effectiveController.layoutID;

        if (!model.layouts.containsKey(layoutID)) {
          return widget.loadingPlaceholder?.call(context) ??
              CodelesslyLoadingScreen();
        }

        final layoutWidget = Material(
          color: Colors.white,
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
    return MultiProvider(
      providers: [
        Provider<CodelesslyContext>.value(value: codelesslyContext),
        Provider<Codelessly>.value(value: _effectiveController.codelessly),
      ],
      child: StreamBuilder<SDKStatus>(
        stream: _effectiveController.codelessly.statusStream,
        initialData: _effectiveController.codelessly.status,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return CodelesslyErrorScreen(
              exception: snapshot.error,
              isPreview: _effectiveController.isPreview,
            );
          }
          if (!snapshot.hasData) {
            return widget.loadingPlaceholder?.call(context) ??
                CodelesslyLoadingScreen();
          }
          final SDKStatus status = snapshot.data!;
          switch (status) {
            case SDKStatus.idle:
            case SDKStatus.configured:
            case SDKStatus.loading:
              return widget.loadingPlaceholder?.call(context) ??
                  CodelesslyLoadingScreen();
            case SDKStatus.errored:
              return CodelesslyErrorScreen(
                exception: CodelesslyErrorHandler.instance.lastException ??
                    snapshot.error,
                isPreview: _effectiveController.isPreview,
              );
            case SDKStatus.done:
              return buildStreamedLayout();
          }
        },
      ),
    );
  }
}
