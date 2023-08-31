import 'dart:math';

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
    BuildContext context, [
    WidgetBuildSettings settings = const WidgetBuildSettings(),
  ]) {
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
    final IconModel icon = node.icon;

    final iconWidget = SvgIcon(
      icon: icon,
      color: node.color?.toFlutterColor(),
      size: min(node.basicBoxLocal.width, node.basicBoxLocal.height),
    );

    // final iconWidget = Icon(
    //   useFonts ? icon.toFontIconData() : icon.toFlutterIconData(),
    //   size: min(node.basicBoxLocal.width, node.basicBoxLocal.height),
    //   color: node.color?.toFlutterColor(),
    // );

    return iconWidget;
  }
}
