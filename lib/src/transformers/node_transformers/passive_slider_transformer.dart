import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';

import '../../../codelessly_sdk.dart';
import '../utils/node_state_provider.dart';

class PassiveSliderTransformer extends NodeWidgetTransformer<SliderNode> {
  PassiveSliderTransformer(super.getNode, super.manager);

  @override
  Widget buildWidget(
    SliderNode node,
    BuildContext context,
    WidgetBuildSettings settings,
  ) {
    return buildFromNode(context, node, settings);
  }

  Widget buildFromProps(
    BuildContext context, {
    required SliderProperties props,
    required double height,
    required double width,
    double value = 0,
    required WidgetBuildSettings settings,
  }) {
    final node = SliderNode(
      id: '',
      name: 'Slider',
      basicBoxLocal: NodeBox(0, 0, width, height),
      retainedOuterBoxLocal: NodeBox(0, 0, width, height),
      properties: props,
      value: value,
    );
    return buildFromNode(context, node, settings);
  }

  Widget buildPreview({
    SliderProperties? properties,
    SliderNode? node,
    double height = kSliderDefaultHeight,
    double width = kSliderDefaultWidth,
    double value = 0,
    ValueChanged<double>? onChanged,
    WidgetBuildSettings settings = const WidgetBuildSettings(
      debugLabel: 'buildPreview',
      replaceVariablesWithSymbols: true,
    ),
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
      onChanged: (context, value) => onChanged?.call(value),
      settings: settings,
    );
  }

  Widget buildFromNode(
    BuildContext context,
    SliderNode node,
    WidgetBuildSettings settings,
  ) {
    return PassiveSliderWidget(
      node: node,
      settings: settings,
      onChanged: (context, value) => onChanged(context, node, value),
    );
  }

  void onChanged(BuildContext context, SliderNode node, double internalValue) {
    NodeStateProvider.setState(context, internalValue);
    FunctionsRepository.setPropertyValue(context,
        node: node, property: 'value', value: internalValue);

    FunctionsRepository.triggerAction(
        context, node: node, TriggerType.changed, value: internalValue);
  }
}

class PassiveSliderWidget extends StatelessWidget {
  final SliderNode node;
  final WidgetBuildSettings settings;
  final List<VariableData> variablesOverrides;
  final void Function(BuildContext context, double value)? onChanged;

  const PassiveSliderWidget({
    super.key,
    required this.node,
    required this.settings,
    required this.onChanged,
    this.variablesOverrides = const [],
  });

  @override
  Widget build(BuildContext context) {
    final ScopedValues scopedValues = ScopedValues.of(
      context,
      variablesOverrides: variablesOverrides,
    );
    final double value = PropertyValueDelegate.getPropertyValue<double>(
          node,
          'value',
          scopedValues: scopedValues,
        ) ??
        node.value;

    // final double value = variables.getDoubleById(node.variables['value'] ?? '',
    //     defaultValue: node.value);
    final SliderTrackShape trackShape;
    if (node.properties.trackShape == SliderTrackShapeEnum.rectangle) {
      trackShape = const RectangularSliderTrackShape();
    } else {
      trackShape = const RoundedRectSliderTrackShape();
    }

    final valueIndicatorShape = node.properties.valueIndicatorShape ==
            SliderValueIndicatorShape.rectangle
        ? const RectangularSliderValueIndicatorShape()
        : const PaddleSliderValueIndicatorShape();

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
          onChanged: (value) => onChanged?.call(context, value),
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
