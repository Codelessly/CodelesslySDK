import 'package:codelessly_api/codelessly_api.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import '../../../codelessly_sdk.dart';
import '../../functions/functions_repository.dart';

class PassiveAppBarTransformer extends NodeWidgetTransformer<AppBarNode> {
  PassiveAppBarTransformer(super.getNode, super.manager);

  @override
  Widget buildWidget(
    AppBarNode node,
    BuildContext context,
    WidgetBuildSettings settings,
  ) {
    return PassiveAppBarWidget(
      node: node,
      settings: settings,
      onLeadingPressed: onTriggerAction,
      onActionPressed: onTriggerAction,
    );
  }

  void onTriggerAction(BuildContext context, List<Reaction> reactions) async {
    final bool executed = await FunctionsRepository.triggerAction(
        context, reactions: reactions, TriggerType.click);

    // only navigate back by default if no actions are defined on the leading
    // icon.
    if (!executed && context.mounted) Navigator.of(context).maybePop();
  }

  PreferredSizeWidget buildFromProps(
    BuildContext context, {
    required AppBarProperties props,
    double width = 250,
    double height = kAppBarDefaultHeight,
    WidgetBuildSettings settings = const WidgetBuildSettings(
      debugLabel: 'buildPreview',
      replaceVariablesWithSymbols: true,
    ),
  }) {
    final node = AppBarNode(
      id: '',
      name: 'AppBar',
      basicBoxLocal: NodeBox(0, 0, width, height),
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
    WidgetBuildSettings settings = const WidgetBuildSettings(
      debugLabel: 'buildPreview',
      replaceVariablesWithSymbols: true,
    ),
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
  final WidgetBuildSettings settings;
  final Function(BuildContext context, List<Reaction> reactions)?
      onLeadingPressed;
  final Function(BuildContext context, List<Reaction> reactions)?
      onActionPressed;
  final List<VariableData> variablesOverrides;

  const PassiveAppBarWidget({
    super.key,
    required this.node,
    this.elevation,
    required this.settings,
    this.onLeadingPressed,
    this.onActionPressed,
    this.variablesOverrides = const [],
  });

  @override
  Widget build(BuildContext context) {
    final Widget? leading = node.properties.leading.icon.show &&
            !node.properties.automaticallyImplyLeading
        ? retrieveIconWidget(node.properties.leading.icon, null)
        : null;

    final Widget? title = node.properties.title.trim().isEmpty
        ? null
        : TextUtils.buildText(
            context,
            node.properties.title,
            textAlignHorizontal: null,
            maxLines: null,
            overflow: null,
            node: node,
            variablesOverrides: variablesOverrides,
            nullSubstitutionMode: settings.nullSubstitutionMode,
            replaceVariablesWithSymbol: settings.replaceVariablesWithSymbols,
          );
    return AdaptiveNodeBox(
      node: node,
      child: AppBar(
        centerTitle: node.properties.centerTitle,
        leading: leading != null
            ? IconButton(
                onPressed: () => onLeadingPressed?.call(
                    context, node.properties.leading.reactions),
                icon: leading,
              )
            : null,
        titleTextStyle: TextUtils.retrieveTextStyleFromProp(
          node.properties.titleStyle,
          effects: const [],
        ),
        backgroundColor: node.properties.backgroundColor.toFlutterColor(),
        elevation: elevation ?? node.properties.elevation,
        automaticallyImplyLeading: node.properties.leading.icon.show
            ? node.properties.automaticallyImplyLeading
            : false,
        title: title,
        foregroundColor:
            node.properties.titleStyle.fills.firstOrNull?.toFlutterColor(),
        titleSpacing: node.properties.titleSpacing,
        shadowColor: node.properties.shadowColor.toFlutterColor(),
        actions: [
          for (final item
              in node.properties.actions.whereType<IconAppBarActionItem>())
            IconButton(
              onPressed: () => onActionPressed?.call(context, item.reactions),
              // splashRadius: 20,
              iconSize: item.icon.size,
              tooltip: item.tooltip,
              icon: retrieveIconWidget(item.icon, item.icon.size) ??
                  const SizedBox.shrink(),
            ),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => node.basicBoxLocal.size.flutterSize;
}
