import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../codelessly_sdk.dart';

/// A widget that builds a layout from an [SDKPublishLayout].
///
/// The internal node list is resolved by linking parentIDs based on the node
/// tree's children hierarchy. It additionally resolve action links and updates
/// the internal [CodelesslyContext] with the node values.
class CodelesslyPublishedLayoutBuilder extends StatefulWidget {
  /// The layout to build. The nodes list must be populated inside.
  final SDKPublishLayout layout;

  /// Creates a [CodelesslyPublishedLayoutBuilder] instance given a [layout].
  const CodelesslyPublishedLayoutBuilder({
    super.key,
    required this.layout,
  });

  @override
  State<CodelesslyPublishedLayoutBuilder> createState() =>
      _CodelesslyPublishedLayoutBuilderState();
}

/// The state of the [CodelesslyPublishedLayoutBuilder].
class _CodelesslyPublishedLayoutBuilderState
    extends State<CodelesslyPublishedLayoutBuilder> {
  /// The node registry that is used to store the nodes.
  /// The [NodeWidgetTransformer]s use this to get nodes by their ids (via the
  /// [transformerManager]).
  late final NodeRegistry nodeRegistry = NodeRegistry();

  /// The [PassiveNodeTransformerManager] that is used to build the widgets
  /// from the nodes.
  ///
  /// The transformer is responsible for getting the appropriate transformer for
  /// each node and building them. It also stores the [nodeRegistry] and
  /// delegates the node lookup to it.
  late final PassiveNodeTransformerManager transformerManager =
      PassiveNodeTransformerManager(nodeRegistry.getNodeByID);

  @override
  void initState() {
    super.initState();

    loadLayout(context);
  }

  @override
  void didUpdateWidget(covariant CodelesslyPublishedLayoutBuilder oldWidget) {
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
    nodeRegistry.clear();
    nodeRegistry.setNodes(widget.layout.nodes);
    codelesslyContext.nodeValues.clear();
    final List<BaseNode> allNodes = nodeRegistry.getNodes().values.toList();

    // Populate node values for nodes with internal values.
    final List<SceneNode> nodesWithInternalValue = allNodes
        .whereType<SceneNode>()
        .where((node) => node.triggerTypes.contains(TriggerType.changed))
        .toList();
    for (final SceneNode node in nodesWithInternalValue) {
      final ValueModel value = node.propertyVariables.firstWhere((property) =>
          property.name == 'value' || property.name == 'inputValue');
      codelesslyContext.addToNodeValues(node, [value]);
    }

    for (final BaseNode node in allNodes) {
      node.parentID = resolveParentNodeIDs(node: node, nodes: allNodes);
    }

    // Handle node action connections and populate local node values.
    for (final ReactionMixin node in allNodes.whereType<ReactionMixin>()) {
      for (final Reaction reaction in node.reactions) {
        final ActionModel actionModel = reaction.action;
        codelesslyContext.handleActionConnections(
            actionModel, nodeRegistry.getNodes());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final BaseNode canvasNode = widget.layout.nodes[widget.layout.canvasId]!;

    return transformerManager.buildWidgetFromNode(canvasNode, context);
  }
}
