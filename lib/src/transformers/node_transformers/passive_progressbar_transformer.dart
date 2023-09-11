import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animation_progress_bar/flutter_animation_progress_bar.dart';

import '../../../codelessly_sdk.dart';
import '../../functions/functions_repository.dart';

class PassiveProgressBarTransformer
    extends NodeWidgetTransformer<ProgressBarNode> {
  PassiveProgressBarTransformer(super.getNode, super.manager);

  @override
  Widget buildWidget(
    ProgressBarNode node,
    BuildContext context,
    WidgetBuildSettings settings,
  ) {
    return buildFromNode(context, node, settings);
  }

  Widget buildFromProps(
    BuildContext context, {
    required ProgressBarProperties props,
    required double height,
    required double width,
    required WidgetBuildSettings settings,
  }) {
    final node = ProgressBarNode(
      id: '',
      name: 'ProgressBar',
      basicBoxLocal: NodeBox(0, 0, width, height),
      retainedOuterBoxLocal: NodeBox(0, 0, width, height),
      properties: props,
    );
    return buildFromNode(context, node, settings);
  }

  Widget buildPreview({
    ProgressBarProperties? properties,
    ProgressBarNode? node,
    double? height,
    double? width,
    double? currentValue,
    ValueChanged<bool>? onChanged,
    bool animate = false,
    WidgetBuildSettings settings =
        const WidgetBuildSettings(debugLabel: 'buildPreview'),
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
      settings: settings,
    );
  }

  Widget buildFromNode(
    BuildContext context,
    ProgressBarNode node,
    WidgetBuildSettings settings,
  ) {
    return PassiveProgressBarWidget(
      node: node,
      settings: settings,
      onChanged: (value) => onChanged(context, node, value),
    );
  }

  void onChanged(BuildContext context, ProgressBarNode node, double value) {
    FunctionsRepository.setPropertyValue(context,
        node: node, property: 'currentValue', value: value);

    FunctionsRepository.triggerAction(context, node, TriggerType.changed,
        value: value);
  }
}

class PassiveProgressBarWidget extends StatelessWidget {
  final ProgressBarNode node;
  final WidgetBuildSettings settings;
  final List<VariableData> variablesOverrides;
  final bool? animate;
  final ValueChanged<double>? onChanged;

  const PassiveProgressBarWidget({
    super.key,
    required this.node,
    required this.settings,
    this.variablesOverrides = const [],
    this.animate,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final double currentValue = PropertyValueDelegate.getPropertyValue<double>(
          context,
          node,
          'currentValue',
          variablesOverrides: variablesOverrides,
        ) ??
        node.currentValue;

    final Color progressColor =
        PropertyValueDelegate.getPropertyValue<ColorRGBA>(
              context,
              node,
              'progressColor',
              variablesOverrides: variablesOverrides,
            )?.toFlutterColor() ??
            node.properties.progressColor.toFlutterColor();

    return AdaptiveNodeBox(
      node: node,
      child: FAProgressBar(
        size: node.properties.isVertical
            ? node.basicBoxLocal.width
            : node.basicBoxLocal.height,
        direction: node.properties.isVertical ? Axis.vertical : Axis.horizontal,
        verticalDirection: VerticalDirection.up,
        currentValue: currentValue,
        maxValue: node.properties.maxValue,
        backgroundColor: node.properties.backgroundColor.toFlutterColor(),
        progressColor: progressColor,
        animatedDuration: (animate ?? node.properties.animate)
            ? Duration(milliseconds: node.properties.animationDurationInMillis)
            : Duration.zero,
        borderRadius: node.properties.cornerRadius.borderRadius,
      ),
    );
  }
}
