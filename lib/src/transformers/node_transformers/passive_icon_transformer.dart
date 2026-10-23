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

  /// [node]'s icon with its bound color and glyph applied: a bound or
  /// conditional `icon` names the glyph (e.g. star or star_border by a
  /// favorite flag), `iconColor` colors it.
  static MultiSourceIconModel resolvedIcon(
    IconNode node,
    ScopedValues scopedValues,
  ) {
    final ColorRGBA? iconColor =
        PropertyValueDelegate.getPropertyValue<ColorRGBA>(
          node,
          'iconColor',
          scopedValues: scopedValues,
        );
    final String? glyph = PropertyValueDelegate.getPropertyValue<String>(
      node,
      'icon',
      scopedValues: scopedValues,
    );
    MultiSourceIconModel icon = node.properties.icon;
    if (glyph != null && icon.icon != null) {
      icon = icon.copyWith(icon: icon.icon!.named(glyph));
    }
    if (iconColor != null) icon = icon.copyWith(color: iconColor);
    return icon;
  }

  @override
  Widget build(BuildContext context) {
    return retrieveIconWidget(
          resolvedIcon(node, ScopedValues.of(context)),
          node.basicBoxLocal.width,
        ) ??
        SizedBox(
          width: node.basicBoxLocal.width,
          height: node.basicBoxLocal.height,
        );
  }
}
