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

  /// The values the icon's bindings read; by default the ones in scope
  /// where it builds. A design canvas passes its variable defaults, which
  /// its build context doesn't hold.
  final ScopedValues? scopedValues;

  const PassiveIconWidget({
    super.key,
    required this.node,
    this.useFonts = false,
    this.scopedValues,
  });

  /// Resolve the bound Material Icon glyph, Material Symbol name and color.
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
    // `icon` binds Material Icons; `iconName` explicitly opts into Symbols.
    final String? glyph = node.variables['icon'] == null
        ? null
        : PropertyValueDelegate.getPropertyValue<String>(
            node,
            'icon',
            scopedValues: scopedValues,
          );
    MultiSourceIconModel icon = iconWithName(node.properties.icon, glyph);
    final String? iconName = PropertyValueDelegate.getPropertyValue<String>(
      node,
      'iconName',
      scopedValues: scopedValues,
    );
    if (iconName != null && iconName.trim().isNotEmpty) {
      icon = withIconName(icon, iconName.trim());
    }
    if (iconColor != null) icon = icon.copyWith(color: iconColor);
    return icon;
  }

  @override
  Widget build(BuildContext context) {
    final MultiSourceIconModel icon = resolvedIcon(
      node,
      scopedValues ?? ScopedValues.of(context),
    );
    Widget paint(MultiSourceIconModel icon) =>
        retrieveIconWidget(icon, node.basicBoxLocal.width) ??
        SizedBox(
          width: node.basicBoxLocal.width,
          height: node.basicBoxLocal.height,
        );

    // With a transition the icon eases to a new color (its `iconColor`
    // binding following a palette), as a solid fill does. Where tickers
    // are off (the design canvas, its captures) it jumps.
    final Color? color = icon.color?.toFlutterColor();
    if (node.transitionMs <= 0 || color == null) return paint(icon);
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: color),
      duration: implicitTransitionDuration(context, node.transitionMs),
      curve: Curves.easeOutCubic,
      builder: (context, eased, _) => paint(
        eased == null || eased == color
            ? icon
            : icon.copyWith(color: eased.toColorRGBA()),
      ),
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
