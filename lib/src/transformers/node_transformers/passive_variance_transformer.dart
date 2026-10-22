import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';

import '../../../codelessly_sdk.dart';

class PassiveVarianceTransformer extends NodeWidgetTransformer<VarianceNode> {
  PassiveVarianceTransformer(super.getNode, super.manager);

  @override
  Widget buildWidget(
    VarianceNode node,
    BuildContext context,
    WidgetBuildSettings settings,
  ) {
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
    required this.settings,
  });

  /// The variant to show: the current one on the design canvas, otherwise
  /// the one the bound variable or a condition picks by id or name.
  Variant getVariant(ScopedValues scopedValues) {
    if (settings.isPreview) return node.currentVariant;
    final String variantIdOrName =
        PropertyValueDelegate.getPropertyValue<String>(
          node,
          'currentVariantId',
          scopedValues: scopedValues,
        ) ??
        node.currentVariantId;

    return node.variants.findById(variantIdOrName) ??
        node.variants.findByName(variantIdOrName) ??
        node.currentVariant;
  }

  @override
  Widget build(BuildContext context) {
    if (!settings.isPreview && node.isResponsive) {
      final double? canvasWidth = CanvasWidthScope.maybeOf(context);
      if (canvasWidth != null) {
        return _buildVariant(context, node.variantForWidth(canvasWidth));
      }
      // Outside of a canvas: the width this node is given, by the rule
      // breakpoints are picked with.
      return LayoutBuilder(
        builder: (context, constraints) => _buildVariant(
          context,
          node.variantForWidth(
            CodelesslyWidget.breakpointWidth(context, constraints),
          ),
        ),
      );
    }
    return _buildVariant(context, getVariant(ScopedValues.of(context)));
  }

  /// Builds only [variant]: the other variants are never built. A
  /// property-override variant builds the default variant's children with
  /// its overrides.
  Widget _buildVariant(BuildContext context, Variant variant) {
    final List<String> children = node.childrenOf(variant);
    final PropertyOverrides? overrides = variant.overrides;
    if (overrides == null) return _buildChildren(context, children);
    return PropertyOverrideScope.wrap(
      context,
      overrides: overrides,
      child: Builder(builder: (context) => _buildChildren(context, children)),
    );
  }

  Widget _buildChildren(BuildContext context, List<String> children) {
    if (children.isNotEmpty) {
      final childNode = getNode(children.first);

      return manager
          .getTransformer<PassiveStackTransformer>()
          .buildWidgetForChildren(
            node,
            context,
            childrenNodes: [childNode],
            settings: settings,
          );
    }

    return SizedBox(
      width: node.basicBoxLocal.width,
      height: node.basicBoxLocal.height,
    );
  }
}
