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
    return PassiveBadgeWidget(node: node, settings: settings, manager: manager);
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

  /// The node the badge is anchored to, if it exists.
  BaseNode? get childNode {
    final String? childID = node.childID;
    if (childID == null || childID.isEmpty || childID == node.id) return null;
    try {
      return manager.getNode(childID);
    } on Object {
      // A dangling child ID renders the badge on its own.
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final BadgeProperties properties = node.properties;
    final ScopedValues scopedValues = ScopedValues.of(
      context,
      variablesOverrides: variablesOverrides,
    );

    final String label = properties.effectiveLabel(
      PropertyValueDelegate.getPropertyValue<String>(
            node,
            'label',
            scopedValues: scopedValues,
          ) ??
          PropertyValueDelegate.substituteVariables(
            properties.label,
            scopedValues: scopedValues,
            nullSubstitutionMode: settings.nullSubstitutionMode,
          ),
    );
    final bool isLabelVisible =
        PropertyValueDelegate.getPropertyValue<bool>(
          node,
          'isLabelVisible',
          scopedValues: scopedValues,
        ) ??
        properties.isLabelVisible;

    final TextStyle textStyle = TextUtils.retrieveTextStyleFromProp(
      properties.textStyle,
    );
    final Alignment alignment = switch (properties.alignment) {
      BadgeAlignment.topRight => Alignment.topRight,
      BadgeAlignment.topLeft => Alignment.topLeft,
      BadgeAlignment.bottomRight => Alignment.bottomRight,
      BadgeAlignment.bottomLeft => Alignment.bottomLeft,
    };

    final BaseNode? childNode = this.childNode;
    final bool isDot = properties.badgeType == BadgeType.dot;

    final Widget badge = Badge(
      key: ValueKey(
        '${node.id}-${IndexedItemProvider.maybeOf(context)?.index ?? ''}',
      ),
      isLabelVisible: isLabelVisible,
      label: isDot ? null : Text(label),
      backgroundColor: properties.backgroundColor?.toFlutterColor(),
      // Flutter applies textColor over the text style's color, so a color
      // set on the style is used when no text color is given.
      textColor: properties.textColor?.toFlutterColor() ?? textStyle.color,
      textStyle: textStyle,
      smallSize: properties.smallSize,
      largeSize: properties.largeSize,
      padding: properties.padding.flutterEdgeInsets,
      alignment: alignment,
      offset: Offset(properties.offsetX, properties.offsetY),
      child: childNode == null
          ? null
          : manager.buildWidgetFromNode(childNode, context, settings: settings),
    );

    return AdaptiveNodeBox(
      node: node,
      // Without a child, the badge keeps its own size and sits at its
      // alignment inside the node's box. The size factors keep it from
      // filling loose constraints when the node wraps its content.
      child: childNode == null
          ? Align(
              alignment: alignment,
              widthFactor: 1,
              heightFactor: 1,
              child: badge,
            )
          : badge,
    );
  }
}
