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
  final String? layoutID;

  /// The [Codelessly] instance to use.
  ///
  /// By default, this is the global instance, retrieved via Codelessly.instance.
  final Codelessly? codelessly;

  /// Whether to show the preview version of the provided layout rather than the
  /// published version.
  ///
  /// If a value is provided, it will override the value provided in
  /// [CodelesslyConfig.isPreview].
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

  final CodelesslyConfig? config;

  /// Optional managers. These are only used when using the global codelessly
  /// instance.
  final AuthManager? authManager;
  final DataManager? publishDataManager;
  final DataManager? previewDataManager;
  final CacheManager? cacheManager;

  /// Creates a [CodelesslyWidget].
  ///
  /// Can be instantiated in several ways:
  ///
  /// 1. Using the global instance of the SDK by not passing any of the
  ///    relevant parameters.
  ///
  /// 2. Using your own [codelessly] instance, initialization will be done
  ///    implicitly if the instance has not already been initialized.
  ///
  /// 3. Using your own [config] instance, which will be used to initialize
  ///    the [codelessly] instance, uses the global [codelessly] instance if
  ///    not provided.
  ///
  /// 5. Using your own [authManager], [dataManager] and [cacheManager].
  ///    You don't need to specify them all, only what you want to override.
  ///    These will only be used when using the global codelessly instance and
  ///    when it is not already configured.
  ///
  /// [data] is a map of data that will be used to populate the layout.
  ///
  /// [functions] is a map of functions that will be used to populate the
  /// layout.
  CodelesslyWidget({
    super.key,
    this.layoutID,
    this.controller,
    this.isPreview,
    this.codelessly,
    this.config,

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
          'You must provide either a layoutID or a controller. One must be specified, and both cannot be specified at the same time.',
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
  CodelesslyWidgetController? _controller;

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

        if (!snapshot.hasData || snapshot.data == null) {
          return CodelesslyLoadingScreen();
        }

        final SDKPublishModel model = snapshot.data!;
        final String layoutID = _effectiveController.layoutID;

        if (!model.layouts.containsKey(layoutID)) {
          return CodelesslyLoadingScreen();
        }

        return CodelesslyPublishedLayoutBuilder(
          key: ValueKey(layoutID),
          layout: model.layouts[layoutID]!,
        );
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
      child: Material(
        color: Colors.white,
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
              return CodelesslyLoadingScreen();
            }
            final SDKStatus status = snapshot.data!;
            switch (status) {
              case SDKStatus.idle:
              case SDKStatus.configured:
              case SDKStatus.loading:
                return CodelesslyLoadingScreen();
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
      ),
    );
  }
}
