import 'package:codelessly_api/api.dart';
import 'package:flutter/material.dart';

import '../../../codelessly_sdk.dart';

class PassiveVarianceTransformer extends NodeWidgetTransformer<VarianceNode> {
  PassiveVarianceTransformer(super.getNode, super.manager);

  @override
  Widget buildWidget(
    VarianceNode node,
    BuildContext context, [
    WidgetBuildSettings settings = const WidgetBuildSettings(),
  ]) {
    return PassiveVarianceWidget(
      node: node,
      settings: settings,
      getNode: getNode,
      buildWidgetFromID: (id, context) =>
          manager.buildWidgetByID(id, context, settings: settings),
    );
  }
}

class PassiveVarianceWidget extends StatelessWidget {
  final VarianceNode node;
  final WidgetBuildSettings settings;
  final GetNode getNode;
  final BuildWidgetFromID buildWidgetFromID;

  const PassiveVarianceWidget({
    super.key,
    required this.node,
    required this.getNode,
    required this.buildWidgetFromID,
    this.settings = const WidgetBuildSettings(),
  });

  List<String> getChildren(BuildContext context) {
    final String variantID =
        context.getNodeValue(node.id, 'variant') ?? node.currentVariantId;
    final Variant variant = node.variants.firstWhere((v) => v.id == variantID);
    return variant.children;
  }

  @override
  Widget build(BuildContext context) {
    final List<String> children = getChildren(context);
    if (children.isNotEmpty) {
      final childNode = getNode(children.first);
      Widget child = buildWidgetFromID(children.first, context);

      // Manually handle positioning.
      if (childNode.isBothExpanded) {
        // no need to wrap with anything.
        child = child;
      } else if (childNode.alignment.data != null) {
        // align mode.
        child = Align(
          alignment: childNode.alignment.flutterAlignment!,
          child: child,
        );
      } else {
        // pinning mode. use stack.
        child = Stack(
          children: [
            Positioned(
              left: childNode.edgePins.left,
              top: childNode.edgePins.top,
              right: childNode.edgePins.right,
              bottom: childNode.edgePins.bottom,
              child: child,
            ),
          ],
        );
      }

      return AdaptiveNodeBox(node: node, child: child);
    }

    return SizedBox(
      width: node.basicBoxLocal.width,
      height: node.basicBoxLocal.height,
    );
  }
}
