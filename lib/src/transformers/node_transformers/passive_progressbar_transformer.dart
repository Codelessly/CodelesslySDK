import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animation_progress_bar/flutter_animation_progress_bar.dart';

import '../../../codelessly_sdk.dart';

class PassiveProgressBarTransformer
    extends NodeWidgetTransformer<ProgressBarNode> {
  PassiveProgressBarTransformer(super.getNode, super.manager);

  @override
  Widget buildWidget(
    ProgressBarNode node,
    BuildContext context, [
    WidgetBuildSettings settings = const WidgetBuildSettings(),
  ]) {
    return buildFromNode(node, settings);
  }

  Widget buildFromProps({
    required ProgressBarProperties props,
    required double height,
    required double width,
  }) {
    final node = ProgressBarNode(
      id: '',
      name: 'ProgressBar',
      basicBoxLocal: NodeBox(0, 0, width, height),
      retainedOuterBoxLocal: NodeBox(0, 0, width, height),
      properties: props,
    );
    return buildFromNode(node);
  }

  Widget buildPreview({
    ProgressBarProperties? properties,
    ProgressBarNode? node,
    double? height,
    double? width,
    double? currentValue,
    ValueChanged<bool>? onChanged,
    bool animate = false,
  }) {
    final previewNode = ProgressBarNode(
      properties: properties ?? node?.properties ?? ProgressBarProperties(),
      id: '',
      name: 'ProgressBar',
      basicBoxLocal: NodeBox(0, 0, width ?? kProgressBarDefaultWidth,
          height ?? kProgressBarDefaultHeight),
      retainedOuterBoxLocal: NodeBox(0, 0, width ?? kProgressBarDefaultWidth,
          height ?? kProgressBarDefaultHeight),
      currentValue: currentValue ?? node?.currentValue ?? 0,
    );
    return PassiveProgressBarWidget(
      node: previewNode,
      animate: animate,
    );
  }

  Widget buildFromNode(
    ProgressBarNode node, [
    WidgetBuildSettings settings = const WidgetBuildSettings(),
  ]) {
    return PassiveProgressBarWidget(
      node: node,
      settings: settings,
    );
  }
}

class PassiveProgressBarWidget extends StatelessWidget {
  final ProgressBarNode node;
  final WidgetBuildSettings settings;
  final List<VariableData> variables;
  final bool? animate;

  const PassiveProgressBarWidget({
    super.key,
    required this.node,
    this.settings = const WidgetBuildSettings(),
    this.variables = const [],
    this.animate,
  });

  @override
  Widget build(BuildContext context) {
    final double currentValue =
        context.getNodeValue(node.id, 'currentValue') ?? node.currentValue;

    return AdaptiveNodeBox(
      node: node,
      child: FAProgressBar(
        key: ValueKey(currentValue),
        size: node.properties.isVertical
            ? node.basicBoxLocal.width
            : node.basicBoxLocal.height,
        direction: node.properties.isVertical ? Axis.vertical : Axis.horizontal,
        verticalDirection: VerticalDirection.up,
        currentValue: currentValue,
        maxValue: node.properties.maxValue,
        backgroundColor: node.properties.backgroundColor.toFlutterColor(),
        progressColor: node.properties.progressColor.toFlutterColor(),
        animatedDuration: (animate ?? node.properties.animate)
            ? Duration(milliseconds: node.properties.animationDurationInMillis)
            : Duration.zero,
        borderRadius: node.properties.cornerRadius.borderRadius,
      ),
    );
  }
}
