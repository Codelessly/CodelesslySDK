import 'package:codelessly_api/codelessly_api.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../codelessly_sdk.dart';
import '../functions/functions_repository.dart';

class CodelesslyLayoutRetriever extends StatefulWidget {
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
    codelessly.dispose(completeDispose: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.bounds.width,
      height: widget.bounds.height,
      child: CodelesslyWidget(
        controller: controller,
        loadingBuilder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
        errorBuilder: (context, error) => Center(
          child: Text(
            error.toString(),
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ),
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

  /// Returns a widget that decides how to load nested layouts of a rendered
  /// node.
  final LayoutRetrieverBuilder? layoutRetrievalBuilder;

  /// Creates a [CodelesslyLayoutBuilder] instance given a [layout].
  const CodelesslyLayoutBuilder({
    super.key,
    required this.controller,
    required this.layout,
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
        widget.layoutRetrievalBuilder
            ?.call(context, bounds, pageID, layoutID, canvasID) ??
        CodelesslyLayoutRetriever(
          controller: widget.controller,
          pageID: pageID,
          layoutID: layoutID,
          bounds: bounds,
        ),
  );

  late final CanvasNode canvasNode =
      widget.layout.nodes[widget.layout.canvasId] as CanvasNode;

  @override
  void initState() {
    super.initState();

    loadLayout(context);
  }

  @override
  void didUpdateWidget(covariant CodelesslyLayoutBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.layout.id != widget.layout.id ||
        oldWidget.layout.lastUpdated != widget.layout.lastUpdated) {
      loadLayout(context);
    }
  }

  /// Loads the layout into the [nodeRegistry] and updates the
  /// [CodelesslyContext] with the node values.
  void loadLayout(BuildContext context) {
    final CodelesslyContext codelesslyContext =
        context.read<CodelesslyContext>();
    final Codelessly codelessly = context.read<Codelessly>();
    nodeRegistry.clear();
    nodeRegistry.setNodes(widget.layout.nodes);
    codelesslyContext.nodeValues.clear();
    final List<BaseNode> allNodes = nodeRegistry.getNodes().values.toList();

    // Populate node values for nodes with internal values.
    final List<PropertyVariableMixin> nodesWithInternalValue = allNodes
        .whereType<ReactionMixin>()
        .where((node) => node.triggerTypes.contains(TriggerType.changed))
        .whereType<PropertyVariableMixin>()
        .toList();
    for (final node in nodesWithInternalValue) {
      final ValueModel? value = node.propertyVariables.firstWhereOrNull(
          (property) =>
              property.name == 'value' || property.name == 'inputValue');
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
              actionModel, nodeRegistry.getNodes());
        }
      }

      if (node is ParentReactionMixin) {
        for (final ReactionMixin reactiveChild
            in (node as ParentReactionMixin).reactiveChildren) {
          // Handle node action connections and populate local node values.
          for (final Reaction reaction in reactiveChild.reactions) {
            final ActionModel actionModel = reaction.action;
            codelesslyContext.handleActionConnections(
                actionModel, nodeRegistry.getNodes());
          }
        }
      }
    }

    final String layoutID = widget.layout.id;
    final Map<String, VariableData> variablesMap = context
            .read<Codelessly>()
            .dataManager
            .publishModel!
            .variables[layoutID]
            ?.variables ??
        {};

    loadApisAndItsVariables(context);

    for (final variable in variablesMap.values) {
      // Override default values of variables with values provided in data.
      final notifier = Observable(variable.copyWith(
        value: codelesslyContext.data[variable.name],
      ));
      codelesslyContext.variables[variable.id] = notifier;
    }

    final conditions =
        codelessly.dataManager.publishModel?.conditions[layoutID]?.conditions ??
            {};
    codelesslyContext.conditions.addAll(conditions);
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
        .where((action) => action.apiId != null)
        .toList();

    final CodelesslyContext codelesslyContext =
        context.read<CodelesslyContext>();

    final apisMap = context.read<Codelessly>().dataManager.publishModel!.apis;

    for (final api in apisMap.values) {
      final ApiCallAction? canvasAction =
          apiCallActions.firstWhereOrNull((action) => action.apiId == api.id);

      final variableName = apiNameToVariableName(api.name);

      final data = canvasAction != null
          ? ApiResponseVariableUtils.loading()
          : ApiResponseVariableUtils.idle();

      final RuntimeVariableData variable = RuntimeVariableData(
        name: variableName,
        type: VariableType.map,
        value: data,
      );

      // Override default values of variables with values provided in data.
      final notifier = Observable(variable);
      codelesslyContext.variables[variable.id] = notifier;

      // Make api request right away if it is a canvas action.
      if (canvasAction != null) {
        FunctionsRepository.makeApiRequestFromAction(
            canvasAction, context, notifier);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return transformerManager.buildWidgetFromNode(
      canvasNode,
      context,
      settings: const WidgetBuildSettings(
        debugLabel: 'layout builder',
        nullSubstitutionMode: NullSubstitutionMode.emptyString,
      ),
    );
  }
}
