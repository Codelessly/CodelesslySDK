import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';

import '../../../codelessly_sdk.dart';
import '../utils/placeholder_painter.dart';

class PassiveExpansionTileTransformer
    extends NodeWidgetTransformer<ExpansionTileNode> {
  PassiveExpansionTileTransformer(super.getNode, super.manager);

  @override
  Widget buildWidget(
    ExpansionTileNode node,
    BuildContext context,
    WidgetBuildSettings settings,
  ) {
    return PassiveExpansionTileWidget(
      node: node,
      settings: settings,
      getNode: getNode,
      buildWidgetFromNode: (node, context) =>
          manager.buildWidgetFromNode(node, context, settings: settings),
    );
  }

  Widget buildFromProps(
    BuildContext context, {
    required ExpansionTileProperties props,
    required double height,
    required double width,
    required WidgetBuildSettings settings,
  }) {
    final node = ExpansionTileNode(
      id: '',
      name: 'Expansion Tile',
      basicBoxLocal: NodeBox(0, 0, width, height),
      retainedOuterBoxLocal: NodeBox(0, 0, width, height),
      properties: props,
      children: [],
    );
    return buildFromNode(node, settings: settings);
  }

  Widget buildPreview(
    BuildContext context, {
    ExpansionTileProperties? props,
    ExpansionTileNode? node,
    double height = kDefaultListTileHeight * 2,
    double width = kDefaultListTileWidth,
    BaseNode? leadingNode,
    BaseNode? titleNode,
    BaseNode? subtitleNode,
    BaseNode? trailingNode,
    ListTileControlAffinityC? controlAffinity,
    bool? initiallyExpanded,
    WidgetBuildSettings settings = const WidgetBuildSettings(
      debugLabel: 'buildPreview',
      replaceVariablesWithSymbols: true,
    ),
  }) {
    final listTileNode = node == null
        ? ListTileNode(
            id: 'list_tile',
            name: 'List Tile',
            basicBoxLocal: NodeBox(0, 0, width, kDefaultListTileHeight),
            properties: ListTileProperties(),
            children: [],
            title: titleNode?.id,
          )
        : null;

    final ExpansionTileNode previewNode = node ??
        ExpansionTileNode(
          id: 'expansion_tile',
          name: 'Expansion Tile',
          basicBoxLocal: NodeBox(0, 0, width, height),
          retainedOuterBoxLocal: NodeBox(0, 0, width, height),
          verticalFit: SizeFit.shrinkWrap,
          properties: (props ??
              node?.properties ??
              ExpansionTileProperties(
                controlAffinity: controlAffinity,
                initiallyExpanded: false,
              )),
          children: [],
          listTileChild: listTileNode?.id,
        );

    listTileNode?.parentID = previewNode.id;
    // previewNode.properties.initiallyExpanded = false;

    return PassiveExpansionTileWidget(
      node: previewNode,
      settings: settings,
      listTileNode: listTileNode,
      leadingNode: leadingNode,
      titleNode: titleNode,
      subtitleNode: subtitleNode,
      trailingNode: trailingNode,
      initiallyExpanded: initiallyExpanded,
      getNode: getNode,
      buildWidgetFromNode: (node, context) => manager.buildWidgetFromNode(
        node,
        context,
        settings: settings,
      ),
    );
  }

  Widget buildFromNode(
    ExpansionTileNode node, {
    required WidgetBuildSettings settings,
  }) {
    return PassiveExpansionTileWidget(
      node: node,
      settings: settings,
      getNode: getNode,
      buildWidgetFromNode: (node, context) =>
          manager.buildWidgetFromNode(node, context, settings: settings),
    );
  }
}

class PassiveExpansionTileWidget extends StatelessWidget {
  final ExpansionTileNode node;
  final WidgetBuildSettings settings;

  final ListTileNode? listTileNode;
  final BaseNode? titleNode;
  final BaseNode? subtitleNode;
  final BaseNode? leadingNode;
  final BaseNode? trailingNode;
  final BuildWidgetFromNode buildWidgetFromNode;
  final GetNode getNode;

  /// Allows to override initial expansion state.
  final bool? initiallyExpanded;

  const PassiveExpansionTileWidget({
    super.key,
    required this.node,
    required this.settings,
    this.listTileNode,
    this.titleNode,
    this.subtitleNode,
    this.leadingNode,
    this.trailingNode,
    required this.buildWidgetFromNode,
    required this.getNode,
    this.initiallyExpanded,
  });

  /// Defines whether the ExpansionTile should render its internal rotating
  /// chevron icon on the leading part.
  bool shouldBuildLeading() {
    final effectiveAffinity =
        node.properties.effectiveAffinity(node.properties.controlAffinity);
    return effectiveAffinity == ListTileControlAffinityC.leading;
  }

  /// Defines whether the ExpansionTile should render its internal trailing
  /// icon on the trailing part.
  bool shouldBuildTrailing() {
    final effectiveAffinity =
        node.properties.effectiveAffinity(node.properties.controlAffinity);
    return effectiveAffinity == ListTileControlAffinityC.trailing;
  }

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

    if (node.listTileChild == null) {
      return Container(
        color: Colors.red,
        alignment: Alignment.center,
        child: const Text(
          'This ExpansionTile node does not have a listTileChild defined for some reason...',
        ),
      );
    }

    final ListTileNode listTileNode =
        this.listTileNode ?? (getNode(node.listTileChild!) as ListTileNode);

    BaseNode? leading = leadingNode;
    if (listTileNode.leading != null) {
      leading ??= getNode(listTileNode.leading!);
    }
    BaseNode? title = titleNode;
    if (listTileNode.title != null) {
      title ??= getNode(listTileNode.title!);
    }

    if (title == null) {
      return Container(
        color: Colors.red,
        alignment: Alignment.center,
        child: const Text(
          "ExpansionTile's internal ListTile is missing it's title node id.",
        ),
      );
    }

    BaseNode? subtitle = subtitleNode;
    if (listTileNode.subtitle != null) {
      subtitle ??= getNode(listTileNode.subtitle!);
    }
    BaseNode? trailing = trailingNode;
    if (listTileNode.trailing != null) {
      trailing ??= getNode(listTileNode.trailing!);
    }

    final List<String> children = node.children.toList()
      ..remove(node.listTileChild);

    return AdaptiveNodeBox(
      node: node,
      child: Theme(
        data: Theme.of(context).copyWith(
          visualDensity: node.properties.visualDensity.flutterVisualDensity,
          dividerColor:
              node.properties.showDividers ? null : Colors.transparent,
        ),
        child: ExpansionTile(
          key: ValueKey(node.id),
          initiallyExpanded:
              initiallyExpanded ?? node.properties.initiallyExpanded,
          maintainState: node.properties.maintainState,
          tilePadding: node.properties.tilePadding?.flutterEdgeInsets,
          expandedCrossAxisAlignment:
              node.properties.expandedCrossAxisAlignment.flutterAxis,
          expandedAlignment:
              node.properties.expandedAlignment?.flutterAlignment,
          childrenPadding: node.properties.childrenPadding?.flutterEdgeInsets,
          backgroundColor: node.properties.backgroundColor?.toFlutterColor(),
          collapsedBackgroundColor:
              node.properties.collapsedBackgroundColor?.toFlutterColor(),
          iconColor: node.properties.iconColor?.toFlutterColor(),
          textColor: node.properties.textColor?.toFlutterColor(),
          collapsedTextColor:
              node.properties.collapsedTextColor?.toFlutterColor(),
          collapsedIconColor:
              node.properties.collapsedIconColor?.toFlutterColor(),
          controlAffinity: node.properties
              .effectiveAffinity(node.properties.controlAffinity)
              .flutterControlAffinity,
          title: StrictNodeBox(
            node: title,
            child: buildWidgetFromNode(title, context),
          ),
          subtitle: subtitle == null
              ? null
              : StrictNodeBox(
                  node: subtitle,
                  child: buildWidgetFromNode(subtitle, context),
                ),
          leading: leading == null
              ? null
              : leading is SinglePlaceholderNode &&
                      leading.children.isEmpty &&
                      shouldBuildLeading()
                  ? null
                  : StrictNodeBox(
                      node: leading,
                      child: Stack(
                        children: [
                          buildWidgetFromNode(leading, context),
                        ],
                      ),
                    ),
          trailing: trailing == null
              ? null
              : trailing is SinglePlaceholderNode &&
                      trailing.children.isEmpty &&
                      shouldBuildTrailing()
                  ? null
                  : StrictNodeBox(
                      node: trailing,
                      child: buildWidgetFromNode(
                        trailing,
                        context,
                      ),
                    ),
          children: children
              .map((id) => buildWidgetFromNode(getNode(id), context))
              .toList(),
          onExpansionChanged: (value) {},
        ),
      ),
    );
  }
}
