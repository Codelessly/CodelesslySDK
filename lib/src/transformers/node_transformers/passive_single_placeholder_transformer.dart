import 'package:codelessly_api/api.dart';
import 'package:flutter/material.dart';

import '../../../codelessly_sdk.dart';

class PassiveSinglePlaceholderTransformer
    extends NodeWidgetTransformer<SinglePlaceholderNode> {
  PassiveSinglePlaceholderTransformer(super.getNode, super.manager);

  @override
  Widget buildWidget(
    SinglePlaceholderNode node,
    BuildContext context, [
    WidgetBuildSettings settings = const WidgetBuildSettings(),
  ]) {
    return PassiveSinglePlaceholderWidget(
      node: node,
      buildWidgetFromID: (id, context) =>
          manager.buildWidgetByID(id, context, settings: settings),
    );
  }
}

class PassiveSinglePlaceholderWidget extends StatelessWidget
    implements PreferredSizeWidget {
  final SinglePlaceholderNode node;
  final BuildWidgetFromID buildWidgetFromID;

  const PassiveSinglePlaceholderWidget({
    super.key,
    required this.node,
    required this.buildWidgetFromID,
  });

  @override
  Widget build(BuildContext context) {
    final List<String> children = node.children;
    if (children.isNotEmpty) {
      return buildWidgetFromID(children.first, context);
    }

    return SizedBox(
      width: node.basicBoxLocal.width,
      height: node.basicBoxLocal.height,
    );
  }

  @override
  Size get preferredSize => node.basicBoxLocal.size.flutterSize;
}
