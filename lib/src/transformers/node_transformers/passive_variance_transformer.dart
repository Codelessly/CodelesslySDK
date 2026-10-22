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
        // A list's status with no variant of its own (loaded) shows the
        // default variant, whichever one the editor last showed.
        (node.isQueryStatus ? node.defaultVariant : node.currentVariant);
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
    final Variant variant = getVariant(ScopedValues.of(context));
    if (!settings.isPreview && node.isQueryStatus) {
      return _buildQueryStatus(context, variant);
    }
    return _buildVariant(context, variant);
  }

  /// Builds a node that shows a cloud list's status. The default variant,
  /// which holds the list, stays built whatever the status, so the list
  /// keeps its query: it is hidden while a status variant with its own
  /// children shows over it, and painted as a skeleton while a skeleton
  /// variant shows.
  Widget _buildQueryStatus(BuildContext context, Variant variant) {
    final Variant loaded = node.defaultVariant;
    final bool ownChildren =
        variant.id != loaded.id && !variant.sharesDefaultChildren;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Offstage(
          key: const ValueKey('loaded'),
          offstage: ownChildren,
          child: Skeleton(
            enabled: variant.skeleton,
            child: _buildChildren(context, loaded.children),
          ),
        ),
        if (ownChildren)
          KeyedSubtree(
            key: ValueKey(variant.id),
            child: _buildVariant(context, variant),
          ),
      ],
    );
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
