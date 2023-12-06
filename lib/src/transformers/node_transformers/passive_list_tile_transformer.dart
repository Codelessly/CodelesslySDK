import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';

import '../../../codelessly_sdk.dart';
import '../../functions/functions_repository.dart';
import '../utils/placeholder_painter.dart';

class PassiveListTileTransformer extends NodeWidgetTransformer<ListTileNode> {
  PassiveListTileTransformer(super.getNode, super.manager);

  @override
  Widget buildWidget(
    ListTileNode node,
    BuildContext context,
    WidgetBuildSettings settings,
  ) {
    return PassiveListTileWidget(
      node: node,
      getNode: getNode,
      onTap: node.reactions.hasTriggerType(TriggerType.click)
          ? () => onTap(context, node.reactions)
          : null,
      onLongPress: node.reactions.hasTriggerType(TriggerType.longPress)
          ? () => onLongPress(context, node.reactions)
          : null,
      buildWidgetFromNode: (node, context) =>
          manager.buildWidgetFromNode(node, context, settings: settings),
      settings: settings,
    );
  }

  void onTap(BuildContext context, List<Reaction> reactions) =>
      FunctionsRepository.triggerAction(context, TriggerType.click,
          reactions: reactions);

  void onLongPress(BuildContext context, List<Reaction> reactions) =>
      FunctionsRepository.triggerAction(context, TriggerType.longPress,
          reactions: reactions);

  Widget buildPreview({
    ListTileProperties? properties,
    ListTileNode? node,
    double height = kDefaultListTileHeight,
    double width = kDefaultListTileWidth,
    BaseNode? leading,
    BaseNode? trailing,
    BaseNode? title,
    BaseNode? subtitle,
    WidgetBuildSettings settings =
        const WidgetBuildSettings(debugLabel: 'buildPreview'),
  }) {
    final previewNode = node ??
        ListTileNode(
          id: 'list_tile',
          name: 'List Tile',
          basicBoxLocal: NodeBox(0, 0, width, height),
          retainedOuterBoxLocal: NodeBox(0, 0, width, height),
          verticalFit: SizeFit.shrinkWrap,
          properties: properties ?? node?.properties ?? ListTileProperties(),
          children: [
            if (leading != null) leading.id,
            if (title != null) title.id,
            if (subtitle != null) subtitle.id,
            if (trailing != null) trailing.id,
          ],
          leading: leading?.id,
          title: title?.id,
          subtitle: subtitle?.id,
          trailing: trailing?.id,
        );

    leading?.parentID = previewNode.id;
    title?.parentID = previewNode.id;
    subtitle?.parentID = previewNode.id;
    trailing?.parentID = previewNode.id;

    return PassiveListTileWidget(
      node: previewNode,
      settings: settings,
      leading: leading,
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      getNode: getNode,
      buildWidgetFromNode: (node, context) =>
          manager.buildWidgetFromNode(node, context, settings: settings),
    );
  }

  Widget buildFromProps({
    required ListTileProperties properties,
    double height = kDefaultListTileHeight,
    double width = kDefaultListTileWidth,
    required WidgetBuildSettings settings,
    required BuildWidgetFromNode buildWidgetFromNode,
  }) {
    final leading = IconNode(
      id: 'leading_icon',
      name: 'Leading Icon',
      basicBoxLocal: NodeBox(0, 0, 24, 24),
      verticalFit: SizeFit.fixed,
      horizontalFit: SizeFit.fixed,
      icon: defaultIcon,
    );

    final trailing = IconNode(
      id: 'trailing_icon',
      name: 'Trailing Icon',
      basicBoxLocal: NodeBox(0, 0, 24, 24),
      verticalFit: SizeFit.fixed,
      horizontalFit: SizeFit.fixed,
      icon: defaultIcon,
    );

    const titleText = 'Title Text';
    final title = TextNode(
      id: 'title',
      name: 'Title',
      basicBoxLocal: NodeBox(0, 0, 180, 21),
      verticalFit: SizeFit.shrinkWrap,
      horizontalFit: SizeFit.expanded,
      characters: titleText,
      textMixedProps: [
        StartEndProp(
          start: 0,
          end: titleText.length,
          fills: [PaintModel.blackPaint],
          fontSize: 16,
        )
      ],
    );

    const subtitleText = 'Subtitle Text';
    final subtitle = TextNode(
      id: 'subtitle',
      name: 'Subtitle',
      basicBoxLocal: NodeBox(0, 0, 180, 21),
      verticalFit: SizeFit.shrinkWrap,
      horizontalFit: SizeFit.expanded,
      characters: subtitleText,
      textMixedProps: [
        StartEndProp(
          start: 0,
          end: subtitleText.length,
          fills: [PaintModel.blackPaint],
          fontSize: 14,
        )
      ],
    );

    final node = ListTileNode(
      id: 'list_tile',
      name: 'List Tile',
      basicBoxLocal: NodeBox(0, 0, width, height),
      retainedOuterBoxLocal: NodeBox(0, 0, width, height),
      properties: properties,
      children: [
        leading.id,
        title.id,
        subtitle.id,
        trailing.id,
      ],
      leading: leading.id,
      title: title.id,
      subtitle: subtitle.id,
      trailing: trailing.id,
    );

    leading.parentID = node.id;
    title.parentID = node.id;
    subtitle.parentID = node.id;
    trailing.parentID = node.id;
    return PassiveListTileWidget(
      node: node,
      settings: settings,
      leading: leading,
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      getNode: getNode,
      buildWidgetFromNode: buildWidgetFromNode,
    );
  }
}

class PassiveListTileWidget extends StatelessWidget {
  final ListTileNode node;
  final WidgetBuildSettings settings;

  final BaseNode? leading;
  final BaseNode? title;
  final BaseNode? subtitle;
  final BaseNode? trailing;

  final Widget? titleWidget;
  final Widget? subtitleWidget;
  final Widget? leadingWidget;
  final Widget? trailingWidget;
  final BuildWidgetFromNode buildWidgetFromNode;
  final GetNode getNode;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const PassiveListTileWidget({
    super.key,
    required this.node,
    required this.settings,
    this.leading,
    this.title,
    this.subtitle,
    this.trailing,
    this.titleWidget,
    this.subtitleWidget,
    this.leadingWidget,
    this.trailingWidget,
    required this.buildWidgetFromNode,
    required this.getNode,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    if (settings.isPreview) {
      return StrictNodeBox(
        node: node,
        child: CustomPaint(
          painter: PlaceholderPainter(
            scale: 1,
            scaleInverse: 1,
            bgColor: kDefaultPrimaryColor.withOpacity(0.15),
            dashColor: const Color(0xFFADB3F1),
            textSpan: TextSpan(
              text: node.type.camelToSentenceCase,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ),
      );
    }

    BaseNode? leading = !node.properties.showLeading ? null : this.leading;
    if (node.properties.showLeading &&
        leading == null &&
        node.leading != null) {
      leading = getNode(node.leading!);
    }
    BaseNode? title = !node.properties.showTitle ? null : this.title;
    if (node.properties.showTitle && title == null && node.title != null) {
      title = getNode(node.title!);
    }
    BaseNode? subtitle = !node.properties.showSubtitle ? null : this.subtitle;
    if (node.properties.showSubtitle &&
        subtitle == null &&
        node.subtitle != null) {
      subtitle = getNode(node.subtitle!);
    }
    BaseNode? trailing = !node.properties.showTrailing ? null : this.trailing;
    if (node.properties.showTrailing &&
        trailing == null &&
        node.trailing != null) {
      trailing = getNode(node.trailing!);
    }

    return SizedBox(
      width: node.basicBoxLocal.width,
      height: node.basicBoxLocal.height,
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          onTap: onTap,
          onLongPress: onLongPress,
          dense: node.properties.dense,
          autofocus: node.properties.autofocus,
          tileColor: node.properties.tileColor?.toFlutterColor(),
          isThreeLine: node.properties.isThreeLine,
          shape: getShapeFromMixin(node.properties),
          selected: node.properties.selected,
          selectedTileColor:
              node.properties.selectedTileColor?.toFlutterColor(),
          hoverColor: node.properties.hoverColor?.toFlutterColor(),
          focusColor: node.properties.focusColor?.toFlutterColor(),
          enabled: node.properties.enabled,
          contentPadding: node.properties.contentPadding.flutterEdgeInsets,
          visualDensity: node.properties.visualDensity.flutterVisualDensity,
          selectedColor: node.properties.selectedColor?.toFlutterColor(),
          iconColor: node.properties.iconColor?.toFlutterColor(),
          textColor: node.properties.textColor?.toFlutterColor(),
          enableFeedback: node.properties.enableFeedback,
          horizontalTitleGap: node.properties.horizontalTitleGap,
          minVerticalPadding: node.properties.minVerticalPadding,
          minLeadingWidth: node.properties.minLeadingWidth,
          title: title == null
              ? null
              : titleWidget ??
                  SizedBox(
                    width: title.basicBoxLocal.width,
                    height: title.basicBoxLocal.height,
                    child: buildWidgetFromNode(title, context),
                  ),
          subtitle: subtitle == null
              ? null
              : subtitleWidget ??
                  SizedBox(
                    width: subtitle.basicBoxLocal.width,
                    height: subtitle.basicBoxLocal.height,
                    child: buildWidgetFromNode(subtitle, context),
                  ),
          leading: leading == null
              ? null
              : leadingWidget ??
                  SizedBox(
                    width: leading.basicBoxLocal.width,
                    height: leading.basicBoxLocal.height,
                    child: buildWidgetFromNode(leading, context),
                  ),
          trailing: trailing == null
              ? null
              : trailingWidget ??
                  SizedBox(
                    width: trailing.basicBoxLocal.width,
                    height: trailing.basicBoxLocal.height,
                    child: buildWidgetFromNode(trailing, context),
                  ),
        ),
      ),
    );
  }
}
