import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';

import '../../../codelessly_sdk.dart';

const String kIconBaseUrl =
    'https://fonts.gstatic.com/s/i/materialiconsoutlined/home/v16/24px.svg';

class PassiveIconTransformer extends NodeWidgetTransformer<IconNode> {
  PassiveIconTransformer(super.getNode, super.manager);

  @override
  Widget buildWidget(
    IconNode node,
    BuildContext context,
    WidgetBuildSettings settings,
  ) {
    return buildFromNode(context, node);
  }

  Widget buildFromNode(BuildContext context, IconNode node) {
    return PassiveIconWidget(node: node);
  }
}

class PassiveIconWidget extends StatelessWidget {
  final IconNode node;
  final bool useFonts;

  const PassiveIconWidget({
    super.key,
    required this.node,
    this.useFonts = false,
  });

  @override
  Widget build(BuildContext context) {
    final ScopedValues scopedValues = ScopedValues.of(context);
    final ColorRGBA? iconColor =
        PropertyValueDelegate.getPropertyValue<ColorRGBA>(
          node,
          'iconColor',
          scopedValues: scopedValues,
        );
    // An `icon` binding names the icon to show, e.g. a list item's.
    MultiSourceIconModel icon = iconWithName(
      node.properties.icon,
      node.variables['icon'] == null
          ? null
          : PropertyValueDelegate.getPropertyValue<String>(
              node,
              'icon',
              scopedValues: scopedValues,
            ),
    );
    if (iconColor != null) icon = icon.copyWith(color: iconColor);
    return retrieveIconWidget(icon, node.basicBoxLocal.width) ??
        SizedBox(
          width: node.basicBoxLocal.width,
          height: node.basicBoxLocal.height,
        );
  }
}
