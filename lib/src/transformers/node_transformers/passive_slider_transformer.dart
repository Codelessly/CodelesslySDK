import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../codelessly_sdk.dart';
import '../../functions/functions_repository.dart';

class PassiveSliderTransformer extends NodeWidgetTransformer<SliderNode> {
  PassiveSliderTransformer(super.getNode, super.manager);

  @override
  Widget buildWidget(
    SliderNode node,
    BuildContext context, [
    WidgetBuildSettings settings = const WidgetBuildSettings(),
  ]) {
    return buildFromNode(context, node, settings);
  }

  Widget buildFromProps(
    BuildContext context, {
    required SliderProperties props,
    required double height,
    required double width,
    double value = 0,
  }) {
    final node = SliderNode(
      id: '',
      name: 'Slider',
      basicBoxLocal: NodeBox(0, 0, width, height),
      retainedOuterBoxLocal: NodeBox(0, 0, width, height),
      properties: props,
      value: value,
    );
    return buildFromNode(context, node);
  }

  Widget buildPreview({
    SliderProperties? properties,
    SliderNode? node,
    double height = kSliderDefaultHeight,
    double width = kSliderDefaultWidth,
    double value = 0,
    ValueChanged<double>? onChanged,
  }) {
    final previewNode = SliderNode(
      properties: properties ?? node?.properties ?? SliderProperties(),
      id: '',
      name: 'Slider',
      value: value,
      basicBoxLocal: NodeBox(0, 0, width, height),
      retainedOuterBoxLocal: NodeBox(0, 0, width, height),
    );
    previewNode.value = value;
    return PassiveSliderWidget(
      node: previewNode,
      onChanged: onChanged,
      settings: WidgetBuildSettings(),
    );
  }

  Widget buildFromNode(
    BuildContext context,
    SliderNode node, [
    WidgetBuildSettings settings = const WidgetBuildSettings(),
  ]) {
    return PassiveSliderWidget(
      node: node,
      settings: settings,
      onChanged: (value) => onChanged(context, node, value),
    );
  }

  void onChanged(BuildContext context, SliderNode node, double internalValue) {
    final CodelesslyContext payload = context.read<CodelesslyContext>();

    if (node.variables.containsKey('value')) {
      // a variable is linked to this node.
      final ValueNotifier<VariableData>? variable =
          payload.variables[node.variables['value'] ?? ''];
      if (variable != null) {
        variable.value = variable.value.copyWith(
            value: internalValue.toStringAsFixed(
                variable.value.type == VariableType.integer ? 0 : 2));
      }
    }
    if (payload.nodeValues.containsKey(node.id)) {
      // Change local state of checkbox.
      payload.nodeValues[node.id]!.value = [
        DoubleValue(name: 'value', value: internalValue)
      ];
    }
    node.reactions
        .where((reaction) => reaction.trigger.type == TriggerType.changed)
        .forEach((reaction) => FunctionsRepository.performAction(
              context,
              reaction.action,
              internalValue: internalValue,
            ));
  }
}

class PassiveSliderWidget extends StatelessWidget
    with PropertyValueGetterMixin {
  final SliderNode node;
  final WidgetBuildSettings settings;
  final List<VariableData> variables;
  final ValueChanged<double>? onChanged;

  const PassiveSliderWidget({
    super.key,
    required this.node,
    required this.settings,
    required this.onChanged,
    this.variables = const [],
  });

  @override
  Widget build(BuildContext context) {
    final double value =
        getPropertyValue<double>(context, node, 'value') ?? node.value;

    // final double value = variables.getDoubleById(node.variables['value'] ?? '',
    //     defaultValue: node.value);
    final SliderTrackShape trackShape;
    if (node.properties.trackShape == SliderTrackShapeEnum.rectangle) {
      trackShape = RectangularSliderTrackShape();
    } else {
      trackShape = RoundedRectSliderTrackShape();
    }

    final valueIndicatorShape = node.properties.valueIndicatorShape ==
            SliderValueIndicatorShape.rectangle
        ? RectangularSliderValueIndicatorShape()
        : PaddleSliderValueIndicatorShape();

    return SizedBox(
      width: node.basicBoxLocal.width,
      height: node.basicBoxLocal.height,
      child: SliderTheme(
        data: SliderThemeData(
          trackHeight: node.properties.trackHeight,
          overlayColor: node.properties.showThumb
              ? node.properties.overlayColor.toFlutterColor()
              : Colors.transparent,
          activeTrackColor: node.properties.activeTrackColor.toFlutterColor(),
          inactiveTrackColor:
              node.properties.inactiveTrackColor.toFlutterColor(),
          thumbColor: node.properties.thumbColor.toFlutterColor(),
          thumbShape: RoundSliderThumbShape(
            enabledThumbRadius:
                node.properties.showThumb ? node.properties.thumbRadius : 0,
          ),
          trackShape: trackShape,
          tickMarkShape: node.properties.isDiscrete
              ? RoundSliderTickMarkShape(
                  tickMarkRadius: node.properties.tickMarkRadius,
                )
              : null,
          showValueIndicator: node.properties.showLabel
              ? ShowValueIndicator.always
              : ShowValueIndicator.never,
          activeTickMarkColor:
              node.properties.activeTickMarkColor.toFlutterColor(),
          inactiveTickMarkColor:
              node.properties.inactiveTickMarkColor.toFlutterColor(),
          valueIndicatorColor:
              node.properties.valueIndicatorColor.toFlutterColor(),
          valueIndicatorTextStyle: TextStyle(
            color: node.properties.valueIndicatorTextColor.toFlutterColor(),
            fontSize: node.properties.valueIndicatorFontSize,
          ),
          valueIndicatorShape: valueIndicatorShape,
          overlayShape: RoundSliderOverlayShape(
            overlayRadius:
                node.properties.showThumb ? node.properties.overlayRadius : 0,
          ),
        ),
        child: Slider(
          value: value,
          onChanged: onChanged,
          autofocus: node.properties.autofocus,
          min: node.properties.min,
          max: node.properties.max,
          divisions:
              node.properties.isDiscrete ? node.properties.divisions : null,
          label: node.properties.showLabel ? getSliderLabel(node, value) : null,
        ),
      ),
    );
  }
}
