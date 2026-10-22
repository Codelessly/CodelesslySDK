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
    final String? iconName = PropertyValueDelegate.getPropertyValue<String>(
      node,
      'iconName',
      scopedValues: scopedValues,
    );
    MultiSourceIconModel icon = iconColor == null
        ? node.properties.icon
        : node.properties.icon.copyWith(color: iconColor);
    if (iconName != null && iconName.trim().isNotEmpty) {
      icon = withIconName(icon, iconName.trim());
    }
    return retrieveIconWidget(icon, node.basicBoxLocal.width) ??
        SizedBox(
          width: node.basicBoxLocal.width,
          height: node.basicBoxLocal.height,
        );
  }
}

/// [icon] showing the Material Symbol [name] instead, for an `iconName`
/// bound to data. Material Symbols load by name alone (Material Icons need
/// each icon's version), so a Material Icon becomes the Material Symbol of
/// the same style, filled when it was filled.
MultiSourceIconModel withIconName(MultiSourceIconModel icon, String name) {
  final IconModel? current = icon.icon;
  if (current is MaterialSymbol) {
    return icon.copyWith(icon: current.copyWith(name: name), show: true);
  }
  final MaterialIconStyle? style = current is MaterialIcon
      ? current.style
      : null;
  return icon.copyWith(
    type: IconTypeEnum.icon,
    show: true,
    icon: MaterialSymbol(
      codepoint: 0,
      fontFamily: 'MaterialSymbols',
      name: name,
      style: switch (style) {
        MaterialIconStyle.rounded => MaterialSymbolStyle.rounded,
        MaterialIconStyle.sharp => MaterialSymbolStyle.sharp,
        _ => MaterialSymbolStyle.outlined,
      },
    ),
    fill: style == MaterialIconStyle.filled ? 1 : icon.fill,
  );
}
