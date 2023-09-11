import 'package:codelessly_api/codelessly_api.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import '../../../codelessly_sdk.dart';

class PassiveAppBarTransformer extends NodeWidgetTransformer<AppBarNode> {
  PassiveAppBarTransformer(super.getNode, super.manager);

  @override
  Widget buildWidget(
    AppBarNode node,
    BuildContext context,
    WidgetBuildSettings settings,
  ) {
    return PassiveAppBarWidget(node: node);
  }

  PreferredSizeWidget buildAppBarWidgetFromProps({
    required AppBarProperties props,
  }) {
    final node = AppBarNode(
      id: '',
      name: 'AppBar',
      basicBoxLocal: NodeBox(0, 0, 250, kAppBarDefaultHeight),
      properties: props,
    );
    return PassiveAppBarWidget(node: node);
  }

  Widget buildPreview(
    BuildContext context, {
    AppBarProperties? properties,
    AppBarNode? node,
    double? height,
    double? width,
  }) {
    final previewNode = AppBarNode(
      properties: properties ?? node!.properties,
      id: '',
      name: 'AppBar',
      basicBoxLocal:
          NodeBox(0, 0, width ?? 250, height ?? kAppBarDefaultHeight),
      retainedOuterBoxLocal:
          NodeBox(0, 0, width ?? 250, height ?? kAppBarDefaultHeight),
    );
    return Theme(
      data: Theme.of(context).copyWith(platform: TargetPlatform.android),
      child: PassiveAppBarWidget(node: previewNode),
    );
  }
}

class PassiveAppBarWidget extends StatelessWidget
    implements PreferredSizeWidget {
  final AppBarNode node;
  final double? elevation;
  final bool useIconFonts;

  const PassiveAppBarWidget({
    super.key,
    required this.node,
    this.elevation,
    this.useIconFonts = false,
  });

  @override
  Widget build(BuildContext context) {
    final Widget? leading = node.properties.leading.icon.show &&
            !node.properties.automaticallyImplyLeading
        ? retrieveIconWidget(node.properties.leading.icon, null, useIconFonts)
        : null;
    return AdaptiveNodeBox(
      node: node,
      child: AppBar(
        centerTitle: node.properties.centerTitle,
        leading: leading != null
            ? IconButton(
                onPressed: () {},
                icon: leading,
              )
            : null,
        titleTextStyle: PassiveTextTransformer.retrieveTextStyleFromTextProp(
            node.properties.titleStyle),
        backgroundColor: node.properties.backgroundColor.toFlutterColor(),
        elevation: elevation ?? node.properties.elevation,
        automaticallyImplyLeading: node.properties.leading.icon.show
            ? node.properties.automaticallyImplyLeading
            : false,
        title: Text(node.properties.title),
        foregroundColor:
            node.properties.titleStyle.fills.firstOrNull?.toFlutterColor(),
        titleSpacing: node.properties.titleSpacing,
        shadowColor: node.properties.shadowColor.toFlutterColor(),
        actions: [
          for (final item
              in node.properties.actions.whereType<IconAppBarActionItem>())
            IconButton(
              onPressed: () {},
              // splashRadius: 20,
              iconSize: item.icon.size,
              tooltip: item.tooltip,
              icon:
                  retrieveIconWidget(item.icon, item.icon.size, useIconFonts) ??
                      SizedBox.shrink(),
            ),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => node.basicBoxLocal.size.flutterSize;
}
