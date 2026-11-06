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
    final Widget built = _build(context);
    final VarianceProperties? widths = node.isResponsive ? node.properties : null;
    if (widths == null ||
        (widths.tabletMinWidth == null && widths.desktopMinWidth == null)) {
      return built;
    }
    return ResponsiveWidthsScope(
      tabletMinWidth: widths.tabletMinWidth,
      desktopMinWidth: widths.desktopMinWidth,
      child: built,
    );
  }

  Widget _build(BuildContext context) {
    if (!settings.isPreview && node.isResponsive) {
      final double? canvasWidth =
          BreakpointWidthScope.maybeOf(context) ??
          CanvasWidthScope.maybeOf(context);
      if (canvasWidth != null) {
        return _buildVariant(context, node.variantForWidth(canvasWidth));
      }
      // Outside of a canvas: the width this node is given, by the rule
      // breakpoints are picked with.
      return MeasurableLayoutBuilder(
        fallbackSize: Size(node.basicBoxLocal.width, node.basicBoxLocal.height),
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

  /// The pins a responsive variant's [root] is placed by, or null when it is
  /// placed by its alignment. Only a root in pin mode that is pinned to the
  /// right or bottom edge is placed by its pins: a breakpoint root's start
  /// pins are often its offset on the design canvas (negative, or the
  /// variant's x there), so on their own they keep meaning top-start. A
  /// negative start pin is dropped for the same reason.
  @visibleForTesting
  static EdgePinsModel? responsiveRootPins(BaseNode root) {
    if (root.positioningMode != PositioningMode.pin) return null;
    final EdgePinsModel pins = root.edgePins;
    double? valid(double? pin) => pin != null && pin >= 0 ? pin : null;
    final double? right = valid(pins.right);
    final double? bottom = valid(pins.bottom);
    if (right == null && bottom == null) return null;
    return EdgePinsModel(
      left: valid(pins.left),
      top: valid(pins.top),
      right: right,
      bottom: bottom,
    );
  }

  Widget _buildChildren(BuildContext context, List<String> children) {
    if (children.isNotEmpty) {
      final childNode = getNode(children.first);

      // A breakpoint variant is designed at its breakpoint's size, not at
      // the variance's (the mobile design), so its root takes the space the
      // variance is given: placed in a Stack at its design insets, a root
      // wider than the variance's design stretched past the screen by the
      // difference. A root with an alignment (a centered card) is placed by
      // it.
      if (!settings.isPreview && node.isResponsive) {
        final Widget built = manager.buildWidgetFromNode(
          childNode,
          context,
          settings: settings,
        );
        final Widget aligned = Align(
          alignment:
              childNode.alignment.flutterAlignment ??
              AlignmentDirectional.topStart,
          child: built,
        );
        final EdgePinsModel? pins = responsiveRootPins(childNode);
        if (pins == null) return aligned;
        // A root pinned to the right or bottom edge (a menu above a bottom
        // bar) keeps those distances to the edges of the space it is given.
        return MeasurableLayoutBuilder(
          fallbackSize: Size(
            childNode.basicBoxLocal.width,
            childNode.basicBoxLocal.height,
          ),
          builder: (context, constraints) {
            if (!constraints.hasBoundedWidth || !constraints.hasBoundedHeight) {
              return aligned;
            }
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: pins.left,
                  top: pins.top,
                  right: pins.right,
                  bottom: pins.bottom,
                  child: built,
                ),
              ],
            );
          },
        );
      }

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
