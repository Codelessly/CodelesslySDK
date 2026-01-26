import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';

import '../../../codelessly_sdk.dart';

class PassiveBadgeTransformer extends NodeWidgetTransformer<BadgeNode> {
  PassiveBadgeTransformer(super.getNode, super.manager);

  @override
  Widget buildWidget(
    BadgeNode node,
    BuildContext context,
    WidgetBuildSettings settings,
  ) {
    return PassiveBadgeWidget(
      node: node,
      settings: settings,
      manager: manager,
    );
  }
}

class PassiveBadgeWidget extends StatelessWidget {
  final BadgeNode node;
  final WidgetBuildSettings settings;
  final WidgetNodeTransformerManager manager;
  final List<VariableData> variablesOverrides;

  const PassiveBadgeWidget({
    super.key,
    required this.node,
    required this.settings,
    required this.manager,
    this.variablesOverrides = const [],
  });

  @override
  Widget build(BuildContext context) {
    final ScopedValues scopedValues = ScopedValues.of(
      context,
      variablesOverrides: variablesOverrides,
    );

    final String label = PropertyValueDelegate.substituteVariables(
      node.properties.label,
      scopedValues: scopedValues,
      nullSubstitutionMode: settings.nullSubstitutionMode,
    );

    // Build badge label widget
    final Widget? badgeLabel;
    if (node.properties.badgeType == BadgeType.dot || !node.properties.isLabelVisible) {
      badgeLabel = null;
    } else {
      badgeLabel = Text(
        label,
        style: TextUtils.retrieveTextStyleFromProp(
          node.properties.labelStyle,
          effects: const [],
        ),
      );
    }

    // Determine alignment
    final Alignment alignment;
    switch (node.properties.alignment) {
      case BadgeAlignment.topRight:
        alignment = Alignment.topRight;
      case BadgeAlignment.topLeft:
        alignment = Alignment.topLeft;
      case BadgeAlignment.bottomRight:
        alignment = Alignment.bottomRight;
      case BadgeAlignment.bottomLeft:
        alignment = Alignment.bottomLeft;
    }

    // Get child widget if specified - Badge typically doesn't have children in this implementation
    // as it wraps other widgets via the parent-child relationship
    final Widget? child = null;

    return AdaptiveNodeBox(
      node: node,
      child: Badge(
        key: ValueKey(
          '${node.id}-${IndexedItemProvider.maybeOf(context)?.index ?? ''}',
        ),
        isLabelVisible: node.properties.isLabelVisible,
        label: badgeLabel,
        backgroundColor: node.properties.backgroundColor?.toFlutterColor(),
        textStyle: TextUtils.retrieveTextStyleFromProp(
          node.properties.labelStyle,
          effects: const [],
        ),
        padding: node.properties.badgeType == BadgeType.dot
            ? null
            : node.properties.padding.flutterEdgeInsets,
        smallSize: node.properties.badgeType == BadgeType.dot
            ? node.properties.dotSize
            : null,
        alignment: AlignmentDirectional(
          alignment.x + (node.properties.offsetX / 100),
          alignment.y + (node.properties.offsetY / 100),
        ),
        child: child,
      ),
    );
  }
}
