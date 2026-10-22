import 'dart:async';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../codelessly_sdk.dart';

/// A widget that retrieves a layout from a [CodelesslyWidgetController].
class CodelesslyLayoutRetriever extends StatefulWidget {
  static const String name = 'LayoutBuilder';

  final CodelesslyWidgetController controller;
  final SizeC bounds;
  final String layoutID;
  final String pageID;

  const CodelesslyLayoutRetriever({
    super.key,
    required this.controller,
    required this.bounds,
    required this.layoutID,
    required this.pageID,
  });

  @override
  State<CodelesslyLayoutRetriever> createState() =>
      _CodelesslyLayoutRetrieverState();
}

class _CodelesslyLayoutRetrieverState extends State<CodelesslyLayoutRetriever> {
  late final Codelessly codelessly = Codelessly(
    config: widget.controller.config,
  );
  late final CodelesslyWidgetController controller = widget.controller.copyWith(
    layoutID: widget.layoutID,
    codelessly: codelessly,
  );

  @override
  void initState() {
    super.initState();
    codelessly.initialize();
    controller.initialize();
  }

  @override
  void dispose() {
    controller.dispose();
    codelessly.dispose(sealCache: false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.bounds.width,
      height: widget.bounds.height,
      child: CodelesslyWidget(controller: controller),
    );
  }
}

/// A widget that builds a layout from an [SDKPublishLayout].
///
/// The internal node list is resolved by linking parentIDs based on the node
/// tree's children hierarchy. It additionally resolve action links and updates
/// the internal [CodelesslyContext] with the node values.
class CodelesslyLayoutBuilder extends StatefulWidget {
  /// The [CodelesslyWidgetController] that is used to control the layout.
  final CodelesslyWidgetController controller;

  /// The layout to build. The nodes list must be populated inside.
  final SDKPublishLayout layout;

  /// The effective canvas id to build the layout from. This is the canvas id
  /// that was determined for the current breakpoint by the [CodelesslyWidget].
  /// We call [_CodelesslyLayoutBuilderState.loadLayout] when this changes
  /// to reload data like conditions, variables, etc for the new canvas.
  final String canvasId;

  /// Returns a widget that decides how to load nested layouts of a rendered
  /// node.
  final LayoutRetrieverBuilder? layoutRetrievalBuilder;

  /// Creates a [CodelesslyLayoutBuilder] instance given a [layout].
  const CodelesslyLayoutBuilder({
    super.key,
    required this.controller,
    required this.layout,
    required this.canvasId,
    this.layoutRetrievalBuilder,
  });

  @override
  State<CodelesslyLayoutBuilder> createState() =>
      _CodelesslyLayoutBuilderState();
}

/// The state of the [CodelesslyLayoutBuilder].
class _CodelesslyLayoutBuilderState extends State<CodelesslyLayoutBuilder> {
  /// The node registry that is used to store the nodes.
  /// The [NodeWidgetTransformer]s use this to get nodes by their ids (via the
  /// [transformerManager]).
  final NodeRegistry nodeRegistry = NodeRegistry();

  /// The [PassiveNodeTransformerManager] that is used to build the widgets
  /// from the nodes.
  ///
  /// The transformer is responsible for getting the appropriate transformer for
  /// each node and building them. It also stores the [nodeRegistry] and
  /// delegates the node lookup to it.
  late final PassiveNodeTransformerManager transformerManager =
      PassiveNodeTransformerManager(
        nodeRegistry.getNodeByID,
        (context, bounds, pageID, layoutID, canvasID) =>
            widget.layoutRetrievalBuilder?.call(
              context,
              bounds,
              pageID,
              layoutID,
              canvasID,
            ) ??
            CodelesslyLayoutRetriever(
              controller: widget.controller,
              pageID: pageID,
              layoutID: layoutID,
              bounds: bounds,
            ),
      );

  /// The canvas node from [nodeRegistry], whose parent links [loadLayout]
  /// resolved.
  ///
  /// [widget.layout] can be replaced by a freshly decoded copy with the same
  /// [SDKPublishLayout.lastUpdated], which [didUpdateWidget] does not reload.
  /// Its nodes have no parent links, so building from it would look up a
  /// parent with an empty ID.
  CanvasNode get canvasNode =>
      nodeRegistry.getNodeByIdOrNull(widget.canvasId) as CanvasNode? ??
      widget.layout.canvases[widget.canvasId]![widget.canvasId] as CanvasNode;

  /// Whether the layout should be loaded. This is used to prevent the layout
  /// from being loaded multiple times since we call [loadLayout] in
  /// [didChangeDependencies] to ensure access to inherited widgets which is
  /// something that cannot be accessed in [initState].
  bool shouldLoadLayout = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (shouldLoadLayout) {
      shouldLoadLayout = false;
      loadLayout(context);
    }
  }

  /// The layout's variables and conditions that [loadLayout] last loaded.
  SDKLayoutVariables? loadedVariables;
  SDKLayoutConditions? loadedConditions;

  @override
  void didUpdateWidget(covariant CodelesslyLayoutBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.layout.id != widget.layout.id ||
        oldWidget.canvasId != widget.canvasId ||
        oldWidget.layout.lastUpdated != widget.layout.lastUpdated ||
        didVariablesOrConditionsChange(context)) {
      loadLayout(context);
    }
  }

  /// Whether the publish model has different variables or conditions for
  /// this layout than [loadLayout] last loaded. They can arrive after the
  /// layout, e.g. when the layout was cached without them, or be published
  /// on their own.
  bool didVariablesOrConditionsChange(BuildContext context) {
    final SDKPublishModel? model = context
        .read<Codelessly>()
        .dataManager
        .publishModel;
    if (model == null) return false;
    bool changed(Object? loaded, Object? current) =>
        !identical(loaded, current) && loaded != current;
    return changed(loadedVariables, model.variables[widget.layout.id]) ||
        changed(loadedConditions, model.conditions[widget.layout.id]);
  }

  /// Loads the layout into the [nodeRegistry] and updates the
  /// [CodelesslyContext] with the node values.
  void loadLayout(BuildContext context) {
    final CodelesslyContext codelesslyContext = context
        .read<CodelesslyContext>();
    nodeRegistry.clear();
    nodeRegistry.setNodes(widget.layout.canvases[widget.canvasId]!);
    final List<BaseNode> allNodes = nodeRegistry.getNodes().values.toList();

    // Populate node values for nodes with internal values.
    codelesslyContext.nodeValues.clear();
    final List<PropertyVariableMixin> nodesWithInternalValue = allNodes
        .whereType<ReactionMixin>()
        .where((node) => node.triggerTypes.contains(TriggerType.changed))
        .whereType<PropertyVariableMixin>()
        .toList();
    for (final node in nodesWithInternalValue) {
      final ValueModel? value = node.propertyVariables.firstWhereOrNull(
        (property) => property.name == 'value' || property.name == 'inputValue',
      );
      if (value == null) continue;
      codelesslyContext.addToNodeValues(node, [value]);
    }

    for (final BaseNode node in allNodes) {
      node.parentID = resolveParentNodeIDs(node: node, nodes: allNodes);

      if (node is ReactionMixin) {
        // Handle node action connections and populate local node values.
        for (final Reaction reaction in (node as ReactionMixin).reactions) {
          final ActionModel actionModel = reaction.action;
          codelesslyContext.handleActionConnections(
            actionModel,
            nodeRegistry.getNodes(),
          );
        }
      }

      if (node is ParentReactionMixin) {
        for (final ReactionMixin reactiveChild
            in (node as ParentReactionMixin).reactiveChildren) {
          // Handle node action connections and populate local node values.
          for (final Reaction reaction in reactiveChild.reactions) {
            final ActionModel actionModel = reaction.action;
            codelesslyContext.handleActionConnections(
              actionModel,
              nodeRegistry.getNodes(),
            );
          }
        }
      }
    }
    final publishModel = context.read<Codelessly>().dataManager.publishModel!;
    loadedVariables = publishModel.variables[widget.layout.id];
    loadedConditions = publishModel.conditions[widget.layout.id];

    final Map<String, Map<String, VariableData>> layoutVariables =
        publishModel.variables[widget.layout.id]?.variables ?? {};
    final Map<String, VariableData> variablesMap =
        layoutVariables[widget.canvasId] ?? {};

    // Clear all the variables that are not api variables. We persist api
    // variables across canvases from the same layout group so that the
    // api request is not made again.
    codelesslyContext.variables.removeWhere(
      (key, value) => !value.value.isApiVariable,
    );
    // App, then page variables, so a screen's own variable of the same name
    // wins. Their notifiers are shared by every layout of this instance.
    final Codelessly codelessly = context.read<Codelessly>();
    for (final String scope in [kAppVariablesScope, kPageVariablesScope]) {
      for (final variable in (layoutVariables[scope] ?? {}).values) {
        codelesslyContext.variables[variable.id] = codelessly.sharedVariables
            .putIfAbsent(
              variable.id,
              () => Observable(
                variable.copyWith(value: codelesslyContext.data[variable.name]),
              ),
            );
      }
    }
    for (final variable in variablesMap.values) {
      // Override default values of variables with values provided in data.
      final notifier = Observable(
        variable.copyWith(value: codelesslyContext.data[variable.name]),
      );
      codelesslyContext.variables[variable.id] = notifier;
    }

    final conditions =
        publishModel.conditions[widget.layout.id]?.conditions[widget
            .canvasId] ??
        {};
    codelesslyContext.conditions.clear();
    codelesslyContext.conditions.addAll(conditions);

    // Load apis and its variables. This has to be done after the variables
    // are loaded above because the api can have parameters with values
    // from the variables.
    loadApisAndItsVariables(context);

    setCloudStorageVariables(context);
  }

  /// This loads all the apis for the layout as variables to be available
  /// in the layout. Any api that is defined on canvas' load action will be
  /// called right away. Otherwise, the api will be available as a variable
  /// with idle state.
  void loadApisAndItsVariables(BuildContext context) {
    final apiCallActions = canvasNode.reactions
        .whereTriggerType(TriggerType.load)
        .map((e) => e.action)
        .whereType<ApiCallAction>()
        .where((action) => action.enabled && action.apiId != null)
        .toList();

    final CodelesslyContext codelesslyContext = context
        .read<CodelesslyContext>();

    final apisMap = context.read<Codelessly>().dataManager.publishModel!.apis;

    for (final api in apisMap.values) {
      final ApiCallAction? canvasAction = apiCallActions.firstWhereOrNull(
        (action) => action.apiId == api.id,
      );

      final variableName = apiNameToVariableName(api.name);

      final data = canvasAction != null
          ? ApiResponseVariableUtils.loading(api.url)
          : ApiResponseVariableUtils.idle(api.url);

      final existingVariable = codelesslyContext
          .variableNamesMap()[variableName];

      final RuntimeVariableData variable =
          existingVariable is RuntimeVariableData
          ? existingVariable
          : RuntimeVariableData(
              name: variableName,
              type: VariableType.map,
              value: data,
            );

      // Override default values of variables with values provided in data.
      final notifier = Observable(variable);
      codelesslyContext.variables[variable.id] = notifier;

      // Make api request right away if it is a canvas action.
      if (canvasAction != null) {
        DebugLogger.instance.printInfo(
          'Making api request for onLoad canvas action',
          name: CodelesslyLayoutRetriever.name,
        );
        // The variable carries the error state; report the failure instead
        // of leaving it as an unhandled async error.
        unawaited(
          FunctionsRepository.makeApiRequestFromAction(
            canvasAction,
            context,
            notifier,
          ).then<void>(
            (_) {},
            onError: (Object e, StackTrace stackTrace) =>
                ErrorLogger.instance.captureException(
                  e,
                  message: 'onLoad API call failed',
                  type: 'api_call_failed',
                  stackTrace: stackTrace,
                ),
          ),
        );
      }
    }
  }

  /// Sets all cloud storage variables to idle state.
  void setCloudStorageVariables(BuildContext context) {
    final loadFromStorageActions = canvasNode.reactions
        .whereTriggerType(TriggerType.load)
        .map((e) => e.action)
        .whereType<LoadFromCloudStorageAction>()
        .where((action) => action.enabled && action.variable != null)
        .toList();

    final CodelesslyContext codelesslyContext = context
        .read<CodelesslyContext>();

    for (final action in loadFromStorageActions) {
      final data = CloudDatabaseVariableUtils.idle();

      final variable = codelesslyContext.findVariableByName(
        action.variable!.name,
      );

      if (variable == null) {
        DebugLogger.instance.printInfo(
          'Variable with name ${action.variable!.name} does not exist',
          name: CodelesslyLayoutRetriever.name,
        );
        continue;
      }

      variable.set(variable.value.copyWith(value: data), notify: false);
    }
  }

  FeedbackTheme? _feedbackTheme;
  Map<String, BaseNode>? _feedbackThemeNodes;

  /// The look of this layout that its confirm dialogs and toasts take, read
  /// again when the canvas's nodes change.
  FeedbackTheme get feedbackTheme {
    final Map<String, BaseNode> nodes =
        widget.layout.canvases[widget.canvasId] ?? const {};
    if (_feedbackTheme == null || !identical(nodes, _feedbackThemeNodes)) {
      _feedbackThemeNodes = nodes;
      // The project's theme wins; what it leaves out comes from the nodes.
      _feedbackTheme = FeedbackTheme.fromTokens(widget.layout.theme)
          .merge(FeedbackTheme.fromNodes(nodes.values));
    }
    return _feedbackTheme!;
  }

  @override
  Widget build(BuildContext context) {
    final CodelesslyConfig config = widget.controller.config;
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    return MediaQuery(
      data: mediaQuery.copyWith(
        textScaler: config.maxTextScaleFactor <= 1
            ? TextScaler.noScaling
            : mediaQuery.textScaler.clamp(
                maxScaleFactor: config.maxTextScaleFactor,
              ),
      ),
      child: Theme(
        data: config.useHostTheme ? Theme.of(context) : ThemeData(),
        child: FeedbackThemeScope(
          theme: feedbackTheme,
          child: transformerManager.buildWidgetFromNode(
            canvasNode,
            context,
            settings: const WidgetBuildSettings(
              debugLabel: 'layout builder',
              nullSubstitutionMode: NullSubstitutionMode.emptyString,
            ),
          ),
        ),
      ),
    );
  }
}
