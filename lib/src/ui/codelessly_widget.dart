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
  /// The [Codelessly] instance to use.
  ///
  /// By default, this is the global instance, retrieved via Codelessly.instance.
  final Codelessly codelessly;

  /// The ID of the layout provided from your Codelessly dashboard.
  /// This represents a single screen or canvas.
  final String layoutID;

  /// Whether to show the preview version of the provided layout rather than the
  /// published version.
  ///
  /// If a value is provided, it will override the value provided in
  /// [CodelesslyConfig.isPreview].
  final bool isPreview;

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
    required this.layoutID,
    bool? isPreview,
    Codelessly? codelessly,
    CodelesslyConfig? config,

    // Data and functions.
    Map<String, String> data = const {},
    Map<String, CodelesslyFunction> functions = const {},

    // Optional managers. These are only used when using the global codelessly
    // instance.
    AuthManager? authManager,
    DataManager? publishDataManager,
    DataManager? previewDataManager,
    CacheManager? cacheManager,
  })  : data = {...data},
        functions = {...functions},
        codelessly = codelessly ?? Codelessly.instance,
        isPreview = isPreview ??
            config?.isPreview ??
            (codelessly ?? Codelessly.instance).config?.isPreview ??
            false {
    final codelessly = this.codelessly;
    try {
      assert(
        (config == null) != (codelessly.config == null),
        codelessly.config == null
            ? 'The SDK cannot be initialized if it is not configured. '
                '\nConsider specifying a [CodelesslyConfig] when initializing.'
                '\n\nYou can initialize the SDK by calling [Codelessly.initializeSDK]'
                '\nor call [Codelessly.configureSDK] to lazily load instead.'
            : 'A [CodelesslyConfig] was already provided.'
                '\nConsider removing the duplicate config or calling '
                '[Codelessly.dispose] before reinitializing.',
      );

      final data = this.data;
      final functions = this.functions;
      final SDKStatus status = codelessly.status;
      final bool isGlobal = Codelessly.isGlobalInstance(codelessly);

      // Merge [data] and [functions] from the codelessly instance
      // into the provided fields.
      for (final entry in codelessly.data.entries) {
        if (!data.containsKey(entry.key)) {
          data[entry.key] = entry.value;
        }
      }
      for (final entry in codelessly.functions.entries) {
        if (!functions.containsKey(entry.key)) {
          functions[entry.key] = entry.value;
        }
      }

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

        if (status == SDKStatus.configured) {
          codelessly.init();
        }
      }

      if (codelessly.status == SDKStatus.done) {
        final model = codelessly.publishDataManager.publishModel;
        if (!(model?.layouts.containsKey(layoutID) ?? true)) {
          throw CodelesslyException.layoutNotFound(
            message: 'Layout with ID [$layoutID] does not exist.',
            layoutID: layoutID,
          );
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
  }

  @override
  State<CodelesslyWidget> createState() => _CodelesslyWidgetState();
}

class _CodelesslyWidgetState extends State<CodelesslyWidget> {
  /// Get the relevant data manager that this [CodelesslyWidget] cares about.
  late DataManager dataManager = widget.isPreview
      ? widget.codelessly.previewDataManager
      : widget.codelessly.publishDataManager;

  /// Listens to the SDK's status to figure out if it needs to manually
  /// initialize the opposite data manager if needed.
  late final StreamSubscription<SDKStatus> statusListener;

  late CodelesslyContext codelesslyContext = CodelesslyContext(
    data: widget.data,
    functions: widget.functions,
    nodeValues: {},
  );

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

    // If this CodelesslyWidget wants to preview a layout but the SDK is
    // configured to load published layouts, then we need to initialize the
    // preview data manager.
    // Vice versa for published layouts if the SDK is configured to load
    // preview layouts.
    if (widget.isPreview != oldWidget.isPreview) {
      dataManager = widget.isPreview
          ? widget.codelessly.previewDataManager
          : widget.codelessly.publishDataManager;

      if (widget.codelessly.status == SDKStatus.done) {
        if (dataManager.status == DataManagerStatus.idle) {
          dataManager.init();
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();

    // If this CodelesslyWidget wants to preview a layout but the SDK is
    // configured to load published layouts, then we need to initialize the
    // preview data manager.
    // Vice versa for published layouts if the SDK is configured to load
    // preview layouts.
    if (widget.codelessly.status == SDKStatus.done) {
      if (widget.codelessly.config?.isPreview != widget.isPreview) {
        if (dataManager.status == DataManagerStatus.idle) {
          dataManager.init();
        }
      }
    }

    // If the SDK has not yet been initialized, the stream will emit events
    // to do so here.
    statusListener = widget.codelessly.statusStream.listen((status) {
      switch (status) {
        case SDKStatus.idle:
        case SDKStatus.configured:
        case SDKStatus.loading:
        case SDKStatus.errored:
          break;
        case SDKStatus.done:
          if (widget.codelessly.config?.isPreview != widget.isPreview) {
            if (dataManager.status == DataManagerStatus.idle) {
              dataManager.init();
            }
          }
          break;
      }
    });
  }

  @override
  void dispose() {
    statusListener.cancel();
    super.dispose();
  }

  /// Once the SDK is successfully initialized, we can build the layout.
  /// A [StreamBuilder] is used to listen to layout changes whenever a user
  /// publishes a new update through the Codelessly publish menu, the changes
  /// are immediately reflected here.
  Widget buildStreamedLayout() {
    return StreamBuilder<DataManagerStatus>(
      key: ValueKey(widget.isPreview),
      stream: dataManager.statusStream,
      initialData: dataManager.status,
      builder: (context, AsyncSnapshot<DataManagerStatus> statusSnapshot) {
        if (statusSnapshot.hasError) {
          return CodelesslyErrorScreen(
            exception: statusSnapshot.error,
            isPreview: widget.isPreview,
          );
        }

        if (!statusSnapshot.hasData) {
          return CodelesslyLoadingScreen();
        }

        final DataManagerStatus status = statusSnapshot.data!;

        switch (status) {
          case DataManagerStatus.idle:
            return CodelesslyLoadingScreen();
          case DataManagerStatus.initializing:
          case DataManagerStatus.initialized:
            return StreamBuilder<SDKPublishModel>(
              stream: dataManager.publishModelStream,
              initialData: dataManager.publishModel,
              builder: (context, AsyncSnapshot<SDKPublishModel> snapshot) {
                if (snapshot.hasError) {
                  return CodelesslyErrorScreen(
                    exception: snapshot.error,
                    isPreview: widget.isPreview,
                  );
                }

                if (!snapshot.hasData) {
                  return CodelesslyLoadingScreen();
                }

                final SDKPublishModel model = snapshot.data!;
                final String layoutID = widget.layoutID;

                if (!model.layouts.containsKey(layoutID)) {
                  CodelesslyErrorHandler.instance.captureException(
                    CodelesslyException.layoutNotFound(
                      message: 'Layout with ID [$layoutID] does not exist.',
                      layoutID: layoutID,
                    ),
                  );

                  return CodelesslyErrorScreen(
                    exception: CodelesslyException.layoutNotFound(
                      message: 'Layout with ID [$layoutID] does not exist.',
                      stacktrace: StackTrace.current,
                      layoutID: layoutID,
                    ),
                    isPreview: widget.isPreview,
                  );
                }

                return CodelesslyPublishedLayoutBuilder(
                  key: ValueKey(layoutID),
                  layout: model.layouts[layoutID]!,
                );
              },
            );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<CodelesslyContext>.value(value: codelesslyContext),
        Provider<Codelessly>.value(value: widget.codelessly),
      ],
      child: Material(
        color: Colors.white,
        child: StreamBuilder<SDKStatus>(
          stream: widget.codelessly.statusStream,
          initialData: widget.codelessly.status,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return CodelesslyErrorScreen(
                exception: snapshot.error,
                isPreview: widget.isPreview,
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
                  isPreview: widget.isPreview,
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
