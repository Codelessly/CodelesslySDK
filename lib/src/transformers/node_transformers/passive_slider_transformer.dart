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
    if (settings.isPreview) {
      return PreviewSliderWidget(node: node, settings: settings);
    } else {
      return PassiveSliderWidget(node: node, settings: settings);
    }
  }
}

class PreviewSliderWidget extends StatefulWidget {
  const PreviewSliderWidget({
    super.key,
    required this.node,
    required this.settings,
  });

  final SliderNode node;
  final WidgetBuildSettings settings;

  @override
  State<PreviewSliderWidget> createState() => _PreviewSliderWidgetState();
}

class _PreviewSliderWidgetState extends State<PreviewSliderWidget> {
  double effectiveValue = 0;

  @override
  Widget build(BuildContext context) {
    return TransformerSlider(
      node: widget.node,
      settings: widget.settings,
      onChanged: (value) => setState(() {
        effectiveValue = value;
      }),
      value: effectiveValue,
    );
  }
}

class PassiveSliderWidget extends StatelessWidget {
  final SliderNode node;
  final WidgetBuildSettings settings;
  final List<VariableData> variablesOverrides;

  /// The values the slider's bindings read instead of the build context's,
  /// such as the variable defaults a design canvas shows.
  final ScopedValues? scopedValues;

  const PassiveSliderWidget({
    super.key,
    required this.node,
    required this.settings,
    this.variablesOverrides = const [],
    this.scopedValues,
  });

  void onChanged(BuildContext context, double internalValue) {
    NodeStateProvider.setState(context, internalValue);

    FunctionsRepository.setPropertyValue(
      context,
      node: node,
      property: 'value',
      value: internalValue,
    );

    FunctionsRepository.triggerAction(
      context,
      node: node,
      TriggerType.changed,
      value: internalValue,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ScopedValues scopedValues =
        this.scopedValues ??
        ScopedValues.of(context, variablesOverrides: variablesOverrides);
    final double value =
        PropertyValueDelegate.getPropertyValue<double>(
          node,
          'value',
          scopedValues: scopedValues,
        ) ??
        node.value;

    return TransformerSlider(
      node: node,
      settings: settings,
      variablesOverrides: variablesOverrides,
      onChanged: (value) => onChanged(context, value),
      value: value,
    );
  }
}

class TransformerSlider extends StatelessWidget {
  const TransformerSlider({
    super.key,
    required this.node,
    required this.settings,
    required this.onChanged,
    required this.value,
    this.variablesOverrides = const [],
  });

  final SliderNode node;
  final WidgetBuildSettings settings;
  final List<VariableData> variablesOverrides;
  final ValueChanged<double>? onChanged;
  final double value;

  @override
  Widget build(BuildContext context) {
    final SliderTrackShape trackShape = switch (node.properties.trackShape) {
      SliderTrackShapeEnum.rectangle => const RectangularSliderTrackShape(),
      SliderTrackShapeEnum.roundedRectangle =>
        const RoundedRectSliderTrackShape(),
      SliderTrackShapeEnum.gapped => const GappedSliderTrackShape(),
    };

    final SliderComponentShape valueIndicatorShape = switch (node
        .properties
        .valueIndicatorShape) {
      SliderValueIndicatorShape.rectangle =>
        const RectangularSliderValueIndicatorShape(),
      SliderValueIndicatorShape.paddle =>
        const PaddleSliderValueIndicatorShape(),
      SliderValueIndicatorShape.drop => const DropSliderValueIndicatorShape(),
      SliderValueIndicatorShape.roundedRectangle =>
        const RoundedRectSliderValueIndicatorShape(),
    };

    final ShowValueIndicator showValueIndicator = switch (node
        .properties
        .showValueIndicator) {
      null =>
        node.properties.showLabel
            ? ShowValueIndicator.onDrag
            : ShowValueIndicator.never,
      ShowValueIndicatorC.onlyForDiscrete => ShowValueIndicator.onlyForDiscrete,
      ShowValueIndicatorC.onlyForContinuous =>
        ShowValueIndicator.onlyForContinuous,
      ShowValueIndicatorC.onDrag => ShowValueIndicator.onDrag,
      ShowValueIndicatorC.alwaysVisible => ShowValueIndicator.alwaysVisible,
      ShowValueIndicatorC.never => ShowValueIndicator.never,
    };
    final bool showsLabel = showValueIndicator != ShowValueIndicator.never;

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
          inactiveTrackColor: node.properties.inactiveTrackColor
              .toFlutterColor(),
          thumbColor: node.properties.thumbColor.toFlutterColor(),
          thumbShape: RoundSliderThumbShape(
            enabledThumbRadius: node.properties.showThumb
                ? node.properties.thumbRadius
                : 0,
          ),
          trackShape: trackShape,
          // GappedSliderTrackShape requires a gap; 6 is the Material 3
          // (2024) default.
          trackGap: node.properties.trackShape == SliderTrackShapeEnum.gapped
              ? 6
              : null,
          tickMarkShape: node.properties.isDiscrete
              ? RoundSliderTickMarkShape(
                  tickMarkRadius: node.properties.tickMarkRadius,
                )
              : null,
          showValueIndicator: showValueIndicator,
          secondaryActiveTrackColor: node.properties.secondaryActiveTrackColor
              ?.toFlutterColor(),
          activeTickMarkColor: node.properties.activeTickMarkColor
              .toFlutterColor(),
          inactiveTickMarkColor: node.properties.inactiveTickMarkColor
              .toFlutterColor(),
          valueIndicatorColor: node.properties.valueIndicatorColor
              .toFlutterColor(),
          valueIndicatorTextStyle: TextStyle(
            color: node.properties.valueIndicatorTextColor.toFlutterColor(),
            fontSize: node.properties.valueIndicatorFontSize,
          ),
          valueIndicatorShape: valueIndicatorShape,
          overlayShape: RoundSliderOverlayShape(
            overlayRadius: node.properties.showThumb
                ? node.properties.overlayRadius
                : 0,
          ),
        ),
        child: Slider(
          value: value.clamp(node.properties.min, node.properties.max),
          onChanged: onChanged,
          autofocus: node.properties.autofocus,
          min: node.properties.min,
          max: node.properties.max,
          divisions: node.properties.isDiscrete
              ? node.properties.divisions
              : null,
          label: showsLabel ? getSliderLabel(node, value) : null,
          secondaryTrackValue: node.properties.secondaryTrackValue?.clamp(
            node.properties.min,
            node.properties.max,
          ),
          padding: node.properties.padding?.flutterEdgeInsets,
        ),
      ),
    );
  }
}
