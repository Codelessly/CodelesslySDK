import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';

import '../../../codelessly_sdk.dart';
import '../utils/property_value_delegate.dart';

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
      manager: manager,
    );
  }
}

class PassiveVarianceWidget extends StatelessWidget {
  final VarianceNode node;
  final WidgetBuildSettings settings;
  final GetNode getNode;
  final WidgetNodeTransformerManager manager;

  const PassiveVarianceWidget({
    super.key,
    required this.node,
    required this.getNode,
    required this.manager,
    this.settings = const WidgetBuildSettings(),
  });

  List<String> getChildren(BuildContext context) {
    final String variantIdOrName =
        PropertyValueDelegate.getPropertyValue<String>(
              context,
              node,
              'currentVariantId',
            ) ??
            node.currentVariantId;

    final Variant variant = node.variants.findById(variantIdOrName) ??
        node.variants.findByName(variantIdOrName)!;
    return variant.children;
  }

  @override
  Widget build(BuildContext context) {
    final List<String> children = getChildren(context);
    if (children.isNotEmpty) {
      final childNode = getNode(children.first);

      return ClipRect(
        child: manager
            .getTransformer<PassiveStackTransformer>()
            .buildWidgetForChildren(
          node,
          context,
          childrenNodes: [childNode],
        ),
      );
    }

    return SizedBox(
      width: node.basicBoxLocal.width,
      height: node.basicBoxLocal.height,
    );
  }
}
