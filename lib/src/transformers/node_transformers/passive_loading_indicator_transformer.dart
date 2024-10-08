import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../codelessly_sdk.dart';

class PassiveLoadingIndicatorTransformer
    extends NodeWidgetTransformer<LoadingIndicatorNode> {
  PassiveLoadingIndicatorTransformer(super.getNode, super.manager);

  @override
  Widget buildWidget(
    LoadingIndicatorNode node,
    BuildContext context,
    WidgetBuildSettings settings,
  ) {
    return buildFromNode(node, settings: settings);
  }

  Widget buildFromProps(
    BuildContext context, {
    required LoadingIndicatorProperties props,
    required double height,
    required double width,
    bool animate = true,
    WidgetBuildSettings settings =
        const WidgetBuildSettings(debugLabel: 'buildFromProps'),
  }) {
    final node = LoadingIndicatorNode(
      id: '',
      name: 'LoadingIndicator',
      basicBoxLocal: NodeBox(0, 0, width, height),
      retainedOuterBoxLocal: NodeBox(0, 0, width, height),
      properties: props,
    );
    return buildFromNode(node, animate: animate, settings: settings);
  }

  Widget buildPreview({
    LoadingIndicatorProperties? properties,
    LoadingIndicatorNode? node,
    double? height,
    double? width,
    ValueChanged<bool>? onChanged,
    bool animate = false,
    WidgetBuildSettings settings =
        const WidgetBuildSettings(debugLabel: 'buildPreview'),
  }) {
    final previewNode = LoadingIndicatorNode(
      properties: node?.properties ?? properties!,
      id: '',
      name: 'LoadingIndicator',
      basicBoxLocal: NodeBox(0, 0, width ?? 32, height ?? 32),
      retainedOuterBoxLocal: NodeBox(0, 0, width ?? 32, height ?? 32),
    );
    return PassiveLoadingIndicatorWidget(
      node: previewNode,
      onChanged: onChanged,
      animate: animate,
      settings: settings,
    );
  }

  Widget buildFromNode(
    LoadingIndicatorNode node, {
    bool animate = true,
    WidgetBuildSettings settings =
        const WidgetBuildSettings(debugLabel: 'buildFromNode'),
  }) {
    return PassiveLoadingIndicatorWidget(
      node: node,
      settings: settings,
      animate: animate,
      onChanged: (value) => onChanged(node.reactions),
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

class PassiveLoadingIndicatorWidget extends StatelessWidget {
  final LoadingIndicatorNode node;
  final List<VariableData> variables;
  final ValueChanged<bool>? onChanged;
  final bool animate;
  final WidgetBuildSettings settings;

  const PassiveLoadingIndicatorWidget({
    super.key,
    required this.node,
    required this.onChanged,
    this.animate = true,
    this.variables = const [],
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    if (node.properties.isMaterial) {
      final MaterialLoadingIndicatorProperties props =
          node.properties.asMaterial();

      return Center(
        child: SizedBox.square(
          dimension: node.innerBoxLocal.size.shortestSide,
          child: CircularProgressIndicator(
            strokeWidth: props.strokeWidth,
            value: !animate ? props.value ?? 0.7 : props.value,
            color: props.color.toFlutterColor(),
            backgroundColor: props.backgroundColor.toFlutterColor(),
            strokeCap: props.strokeCap.flutterStrokeCap,
          ),
        ),
      );
    } else if (node.properties.isCupertino) {
      final CupertinoLoadingIndicatorProperties props =
          node.properties.asCupertino();
      return CupertinoActivityIndicator(
        radius: (node.basicBoxLocal.width ~/ 2).toDouble(),
        color: props.color.toFlutterColor(),
        animating: animate,
      );
    }

    throw Exception('LoadingIndicatorProperties type not supported');
  }
}
