import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../codelessly_sdk.dart';

class PassiveDividerTransformer extends NodeWidgetTransformer<DividerNode> {
  PassiveDividerTransformer(super.getNode, super.manager);

  @override
  Widget buildWidget(
    DividerNode node,
    BuildContext context,
    WidgetBuildSettings settings,
  ) {
    return buildFromNode(node);
  }

  Widget buildFromProps(
    BuildContext context, {
    required DividerProperties props,
    required double height,
    required double width,
    WidgetBuildSettings settings =
        const WidgetBuildSettings(debugLabel: 'buildFromProps'),
  }) {
    final node = DividerNode(
      id: '',
      name: 'Divider',
      basicBoxLocal: NodeBox(0, 0, width, height),
      retainedOuterBoxLocal: NodeBox(0, 0, width, height),
      properties: props,
    );
    return buildFromNode(node, settings: settings);
  }

  Widget buildPreview({
    DividerProperties? properties,
    DividerNode? node,
    double? height,
    double? width,
    ValueChanged<bool>? onChanged,
    WidgetBuildSettings settings =
        const WidgetBuildSettings(debugLabel: 'buildPreview'),
  }) {
    final previewNode = DividerNode(
      properties: properties ?? node?.properties ?? DividerProperties(),
      id: '',
      name: 'Divider',
      basicBoxLocal: NodeBox(0, 0, width ?? 32, height ?? 32),
      retainedOuterBoxLocal: NodeBox(0, 0, width ?? 32, height ?? 32),
    );
    return PassiveDividerWidget(
      node: previewNode,
      onChanged: onChanged,
      settings: settings,
    );
  }

  Widget buildFromNode(
    DividerNode node, {
    WidgetBuildSettings settings =
        const WidgetBuildSettings(debugLabel: 'buildFromNode'),
  }) {
    return PassiveDividerWidget(
      node: node,
      onChanged: (value) => onChanged(node.reactions),
      settings: settings,
    );
  }

  void onChanged(List<Reaction> reactions) => reactions
      .where((reaction) => reaction.trigger.type == TriggerType.click)
      .forEach(onAction);

  void onAction(Reaction reaction) {
    switch (reaction.action.type) {
      case ActionType.link:
        launchUrl(Uri.parse((reaction.action as LinkAction).url));
      default:
        break;
    }
  }
}

class PassiveDividerWidget extends StatelessWidget {
  final DividerNode node;
  final List<VariableData> variables;
  final ValueChanged<bool>? onChanged;
  final WidgetBuildSettings settings;

  const PassiveDividerWidget({
    super.key,
    required this.node,
    required this.onChanged,
    this.variables = const [],
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    if (node.properties.isVertical) {
      return AdaptiveNodeBox(
        node: node,
        child: VerticalDivider(
          width: node.basicBoxLocal.width,
          thickness: node.properties.thickness,
          color: node.properties.color.toFlutterColor(),
          indent: node.properties.indent,
          endIndent: node.properties.endIndent,
        ),
      );
    }
    return AdaptiveNodeBox(
      node: node,
      child: Divider(
        height: node.basicBoxLocal.height,
        thickness: node.properties.thickness,
        color: node.properties.color.toFlutterColor(),
        indent: node.properties.indent,
        endIndent: node.properties.endIndent,
      ),
    );
  }
}
