import 'dart:math';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';

import '../../../codelessly_sdk.dart';
import '../../functions/functions_repository.dart';

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
    return PassiveIconWidget(
      node: node,
      onPressed: () => onPressed(context, node),
      onLongPressed: () => onLongPressed(context, node),
    );
  }

  void onPressed(BuildContext context, IconNode node) =>
      FunctionsRepository.triggerAction(context, node, TriggerType.click);

  void onLongPressed(BuildContext context, IconNode node) =>
      FunctionsRepository.triggerAction(context, node, TriggerType.longPress);
}

class PassiveIconWidget extends StatelessWidget {
  final IconNode node;
  final bool useFonts;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPressed;

  const PassiveIconWidget({
    super.key,
    required this.node,
    this.useFonts = false,
    this.onPressed,
    this.onLongPressed,
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

    if (node.reactions.isNotEmpty) {
      return GestureDetector(
        onTap: onPressed,
        onLongPress: onLongPressed,
        child: iconWidget,
      );
    }

    return iconWidget;
  }
}
