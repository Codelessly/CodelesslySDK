import 'package:codelessly_api/codelessly_api.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import '../../../codelessly_sdk.dart';

typedef TriggerAction = void Function(
  BuildContext context,
  List<Reaction> reactions,
);

class PassiveAppBarTransformer extends NodeWidgetTransformer<AppBarNode> {
  PassiveAppBarTransformer(super.getNode, super.manager);

  @override
  PreferredSizeWidget buildWidget(
    AppBarNode node,
    BuildContext context,
    WidgetBuildSettings settings,
  ) {
    if (settings.buildRawWidget) {
      return buildRawAppBar(context, node: node, settings: settings);
    }

    return PassiveAppBarWidget(
      node: node,
      settings: settings,
      onTriggerAction: onTriggerAction,
    );
  }

  PreferredSizeWidget buildRawAppBar(
    BuildContext context, {
    required AppBarNode node,
    WidgetBuildSettings settings = const WidgetBuildSettings(
      debugLabel: 'buildPreview',
      replaceVariablesWithSymbols: true,
    ),
    List<VariableData> variablesOverrides = const [],
  }) {
    final Widget? leading = node.properties.leading.icon.show &&
            !node.properties.automaticallyImplyLeading
        ? retrieveIconWidget(
            node.properties.leading.icon,
            node.properties.leading.icon.size,
          )
        : null;

    final Widget? title = node.properties.title.trim().isEmpty
        ? null
        : TextUtils.buildText(
            context,
            node.properties.title,
            fontSize: node.properties.titleStyle.fontSize,
            node: node,
            variablesOverrides: variablesOverrides,
            nullSubstitutionMode: settings.nullSubstitutionMode,
            replaceVariablesWithSymbol: settings.replaceVariablesWithSymbols,
          );

    return AppBar(
      centerTitle: node.properties.centerTitle,
      automaticallyImplyLeading: node.properties.leading.icon.show
          ? node.properties.automaticallyImplyLeading
          : false,
      leading: leading != null
          ? Center(
              child: buildIconOrButton(
                context,
                icon: leading,
                size: node.properties.leading.icon.size,
                tooltip: node.properties.leading.tooltip,
                reactions: node.properties.leading.reactions,
              ),
            )
          : null,
      title: title,
      titleTextStyle: TextUtils.retrieveTextStyleFromProp(
        node.properties.titleStyle,
        effects: const [],
      ),
      titleSpacing: node.properties.titleSpacing,
      // TODO(Saad,Birju): Make surfaceTintColor a property of the AppBarNode.
      surfaceTintColor: node.properties.backgroundColor.toFlutterColor(),
      backgroundColor: node.properties.backgroundColor.toFlutterColor(),
      elevation: node.properties.elevation,
      foregroundColor:
          node.properties.titleStyle.fills.firstOrNull?.toFlutterColor(),
      shadowColor: node.properties.shadowColor.toFlutterColor(),
      actions: [
        for (final item
            in node.properties.actions.whereType<IconAppBarActionItem>())
          buildIconOrButton(
            context,
            icon: retrieveIconWidget(item.icon, item.icon.size) ??
                const SizedBox.shrink(),
            size: item.icon.size,
            tooltip: item.tooltip,
            reactions: item.reactions,
          ),
      ],
    );
  }

  Widget buildIconOrButton(
    BuildContext context, {
    required Widget icon,
    required double? size,
    required String? tooltip,
    required List<Reaction> reactions,
  }) {
    final bool hasReactions = reactions
        .where(
          (reaction) => reaction.trigger.type == TriggerType.click,
        )
        .isNotEmpty;
    if (hasReactions) {
      return IconButton(
        onPressed: () => onTriggerAction.call(context, reactions),
        icon: icon,
        iconSize: size,
        tooltip: tooltip,
      );
    } else {
      return icon;
    }
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
    double height = kDefaultAppBarHeight,
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
          NodeBox(0, 0, width ?? 250, height ?? kDefaultAppBarHeight),
      retainedOuterBoxLocal:
          NodeBox(0, 0, width ?? 250, height ?? kDefaultAppBarHeight),
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

typedef AppBarBuilder = PreferredSizeWidget Function(BuildContext context);

class PassiveAppBarWidget extends StatelessWidget
    implements PreferredSizeWidget {
  final AppBarNode node;
  final double? elevation;
  final WidgetBuildSettings settings;
  final TriggerAction? onTriggerAction;
  final List<VariableData> variablesOverrides;

  const PassiveAppBarWidget({
    super.key,
    required this.node,
    required this.settings,
    this.elevation,
    this.onTriggerAction,
    this.variablesOverrides = const [],
  });

  @override
  Size get preferredSize => node.outerBoxLocal.size.flutterSize;

  Widget buildIconOrButton(
    BuildContext context, {
    required Widget icon,
    required double? size,
    required String? tooltip,
    required List<Reaction> reactions,
  }) {
    final bool hasReactions = reactions
        .where(
          (reaction) => reaction.trigger.type == TriggerType.click,
        )
        .isNotEmpty;
    if (hasReactions && onTriggerAction != null) {
      return IconButton(
        onPressed: () => onTriggerAction!.call(context, reactions),
        icon: icon,
        iconSize: size,
        tooltip: tooltip,
      );
    } else {
      return icon;
    }
  }

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
            fontSize: node.properties.titleStyle.fontSize,
            node: node,
            variablesOverrides: variablesOverrides,
            nullSubstitutionMode: settings.nullSubstitutionMode,
            replaceVariablesWithSymbol: settings.replaceVariablesWithSymbols,
          );
    return AdaptiveNodeBox(
      node: node,
      child: AppBar(
        toolbarHeight: node.middleBoxLocal.height,
        centerTitle: node.properties.centerTitle,
        leadingWidth: node.properties.leading.icon.size,
        leading: leading != null
            ? Center(
                child: buildIconOrButton(
                  context,
                  icon: leading,
                  size: node.properties.leading.icon.size,
                  tooltip: node.properties.leading.tooltip,
                  reactions: node.properties.leading.reactions,
                ),
              )
            : null,
        titleTextStyle: TextUtils.retrieveTextStyleFromProp(
          node.properties.titleStyle,
          effects: const [],
        ),
        // TODO(Saad,Birju): Make surfaceTintColor a property of the AppBarNode.
        surfaceTintColor: node.properties.backgroundColor.toFlutterColor(),
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
            buildIconOrButton(
              context,
              icon: retrieveIconWidget(item.icon, item.icon.size) ??
                  const SizedBox.shrink(),
              size: item.icon.size,
              tooltip: item.tooltip,
              reactions: item.reactions,
            ),
        ],
      ),
    );
  }
}
