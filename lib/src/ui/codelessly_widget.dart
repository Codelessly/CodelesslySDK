import 'dart:async';
import 'dart:developer';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../codelessly_sdk.dart';
import '../logging/error_handler.dart';
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

/// Holds data passed from the Codelessly instance down the widget tree where
/// all of the [WidgetNodeTransformer]s have access to it.
class CodelesslyContext with ChangeNotifier, EquatableMixin {
  /// A map of data that is passed to loaded layouts for nodes to replace their
  /// values with.
  Map<String, dynamic> _data;

  /// A map of data that is passed to loaded layouts for nodes to replace their
  /// values with.
  Map<String, dynamic> get data => _data;

  /// A map of data that is passed to loaded layouts for nodes to replace their
  /// values with.
  set data(Map<String, dynamic> value) {
    _data = value;
    notifyListeners();
  }

  /// The passed ID of the layout to load.
  String? layoutID;

  /// A map of functions that is passed to loaded layouts for nodes to call when
  /// they are triggered.
  Map<String, CodelesslyFunction> functions;

  set setFunctions(Map<String, CodelesslyFunction> functions) {
    this.functions = functions;
    notifyListeners();
  }

  /// A map that holds the current values of nodes that have internal values.
  final Map<String, ValueNotifier<List<ValueModel>>> nodeValues;

  /// A map that holds the current state of all variables.
  /// The key is the variable's id.
  final Map<String, ValueNotifier<VariableData>> variables;

  /// A map that holds the current state of all conditions.
  /// The key is the condition's id.
  final Map<String, BaseCondition> conditions;

  /// Creates a [CodelesslyContext] with the given [data], [functions], and
  /// [nodeValues].
  CodelesslyContext({
    required Map<String, dynamic> data,
    required this.functions,
    required this.nodeValues,
    required this.variables,
    required this.conditions,
    required this.layoutID,
  }) : _data = data;

  /// Creates a [CodelesslyContext] with empty an empty map of each property.
  CodelesslyContext.empty({String? layoutID})
      : _data = {},
        functions = {},
        nodeValues = {},
        variables = {},
        conditions = {};

  /// Returns a map of all of the [VariableData]s in [variables] mapped by their
  /// name.
  Map<String, VariableData> variableNamesMap() =>
      variables.map((key, value) => MapEntry(value.value.name, value.value));

  /// Creates a copy of this [CodelesslyContext] with the given [data],
  /// [functions], and [nodeValues].
  CodelesslyContext copyWith({
    Map<String, dynamic>? data,
    Map<String, CodelesslyFunction>? functions,
    Map<String, ValueNotifier<List<ValueModel>>>? nodeValues,
    Map<String, ValueNotifier<VariableData>>? variables,
    Map<String, BaseCondition>? conditions,
    String? layoutID,
    bool forceLayoutID = false,
  }) {
    return CodelesslyContext(
      data: data ?? this.data,
      functions: functions ?? this.functions,
      nodeValues: nodeValues ?? this.nodeValues,
      variables: variables ?? this.variables,
      layoutID: forceLayoutID ? layoutID : layoutID ?? this.layoutID,
      conditions: conditions ?? this.conditions,
    );
  }

  /// Used for actions that are connected to one or more nodes.
  /// Ex. submit action is connected to a text field node to access its data to
  /// submit to the server.
  Future<void> handleActionConnections(
    ActionModel actionModel,
    Map<String, BaseNode> nodes,
  ) async {
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
            StringValue(
              name: 'currentVariantId',
              value: connectedNode.currentVariantId,
            )
          ]);
        }
        break;
      case ActionType.setVariable:
        final action = actionModel as SetVariableAction;
        final VariableData variable = action.variable;
        variables[variable.id] = ValueNotifier(variable);
      default:
    }
  }

  /// Add [values] to the [nodeValues] map corresponding to the [node].
  /// [values] refer to the local values of the node's properties that can be
  /// changed, for example, with set value action.
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
    if (nodeValues[node.id] == null) {
      nodeValues[node.id] = ValueNotifier([...currentValues, ...newValues]);
    } else {
      nodeValues[node.id]!.value = [...currentValues, ...newValues];
    }
  }

  /// Returns a reverse-lookup of the [VariableData] associated with a given
  /// [name].
  ValueNotifier<VariableData>? findVariableByName(String? name) =>
      variables.values
          .firstWhereOrNull((variable) => variable.value.name == name);

  /// Allows to easily [value] of a variable with a given [name].
  /// Returns false if the variable does not exist.
  /// Returns true if the variable was updated successfully.
  bool updateVariable(String name, Object? value) {
    final ValueNotifier<VariableData>? variable = findVariableByName(name);
    if (variable == null) {
      log('[CodelesslyContext] Variable with name $name does not exist.');
      return false;
    }
    final String newValue = value == null ? '' : '$value';

    // If the value is the same, then the underlying value notifier will not
    // notify listeners, so we need to return false.
    if (variable.value.value == newValue) {
      log('[CodelesslyContext] Variable with name $name already has the value $newValue.');
      return false;
    }
    variable.value = variable.value.copyWith(value: newValue);
    return true;
  }

  /// Allows to easily get the [value] of a variable with a given [name].
  /// Returns null if the variable does not exist.
  /// If [R] is provided, the returned value will be cast to that type.
  R? getVariableValue<R extends Object>(String name) {
    final ValueNotifier<VariableData>? variable = findVariableByName(name);
    if (variable == null) {
      log('[CodelesslyContext] Variable with name $name does not exist.');
      return null;
    }
    return variable.value.getValue().typedValue<R>();
  }

  @override
  List<Object?> get props => [layoutID, data, functions];
}

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

    // Additional parameters.
    this.codelesslyContext,
  })  : data = {...data},
        functions = {...functions},
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
          'You must provide either a [codelessly] or a [controller]. One must be specified, and both cannot be specified at the same time.',
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

    if (widget.controller == null) {
      _controller = createDefaultController();
    }

    if (!_effectiveController.didInitialize) {
      _effectiveController.init();
    }

    if (!CodelesslyErrorHandler.didInitialize) {
      _effectiveController.codelessly.initErrorHandler(
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
    }

    if (widget.functions != codelesslyContext.functions) {
      codelesslyContext.functions = widget.functions;
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
        _effectiveController.init();
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
                  context, CodelesslyErrorHandler.instance.lastException) ??
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
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<CodelesslyContext>.value(
          value: codelesslyContext,
        ),
        Provider<Codelessly>.value(
          value: _effectiveController.codelessly,
        ),
      ],
      child: StreamBuilder<CodelesslyStatus>(
        stream: _effectiveController.codelessly.statusStream,
        initialData: _effectiveController.codelessly.status,
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
