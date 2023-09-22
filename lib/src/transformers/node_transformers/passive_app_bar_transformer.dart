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
    return PassiveAppBarWidget(node: node, settings: settings);
  }

  PreferredSizeWidget buildAppBarWidgetFromProps({
    required AppBarProperties props,
    WidgetBuildSettings settings =
        const WidgetBuildSettings(debugLabel: 'buildPreview'),
  }) {
    final node = AppBarNode(
      id: '',
      name: 'AppBar',
      basicBoxLocal: NodeBox(0, 0, 250, kAppBarDefaultHeight),
      properties: props,
    );
    return PassiveAppBarWidget(
      node: node,
      settings: settings,
    );
  }

  Widget buildPreview(
    BuildContext context, {
    AppBarProperties? properties,
    AppBarNode? node,
    double? height,
    double? width,
    WidgetBuildSettings settings =
        const WidgetBuildSettings(debugLabel: 'buildPreview'),
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
      child: PassiveAppBarWidget(
        node: previewNode,
        settings: settings,
      ),
    );
  }
}

class PassiveAppBarWidget extends StatelessWidget
    implements PreferredSizeWidget {
  final AppBarNode node;
  final double? elevation;
  final bool useIconFonts;
  final WidgetBuildSettings settings;

  const PassiveAppBarWidget({
    super.key,
    required this.node,
    this.elevation,
    this.useIconFonts = false,
    required this.settings,
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
        title: Text(
          PropertyValueDelegate.substituteVariables(
            context,
            node.properties.title,
            nullSubstitutionMode: settings.nullSubstitutionMode,
          ),
        ),
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
