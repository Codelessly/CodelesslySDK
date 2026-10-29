import 'dart:math' as math;

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

  /// The values the slider's bound `value`, `min` and `max` read, such as a
  /// design canvas's variable defaults. When null they come from [context]
  /// with [variablesOverrides].
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
    final double min =
        PropertyValueDelegate.getPropertyValue<double>(
          node,
          'min',
          scopedValues: scopedValues,
        ) ??
        node.properties.min;
    final double max =
        PropertyValueDelegate.getPropertyValue<double>(
          node,
          'max',
          scopedValues: scopedValues,
        ) ??
        node.properties.max;

    return TransformerSlider(
      node: node,
      settings: settings,
      variablesOverrides: variablesOverrides,
      onChanged: (value) => onChanged(context, value),
      value: value,
      min: min,
      max: max,
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
    this.min,
    this.max,
  });

  final SliderNode node;
  final WidgetBuildSettings settings;
  final List<VariableData> variablesOverrides;
  final ValueChanged<double>? onChanged;
  final double value;

  /// The slider's minimum, when bound; [SliderProperties.min] otherwise.
  final double? min;

  /// The slider's maximum, when bound; [SliderProperties.max] otherwise.
  /// Never less than the minimum.
  final double? max;

  @override
  Widget build(BuildContext context) {
    final double min = this.min ?? node.properties.min;
    final double max = math.max(min, this.max ?? node.properties.max);
    final bool vertical = node.properties.orientation == AxisC.vertical;
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

    // A vertical slider is a horizontal one turned a quarter turn
    // counterclockwise, so min sits at the bottom. RotatedBox turns its
    // layout and hit testing too, so the whole node box drags the thumb.
    final Widget slider = SizedBox(
      width: vertical ? node.basicBoxLocal.height : node.basicBoxLocal.width,
      height: vertical ? node.basicBoxLocal.width : node.basicBoxLocal.height,
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
          thumbShape: switch (node.properties.thumbShape) {
            SliderThumbShapeEnum.circle => StrokedSliderThumbShape(
              enabledThumbRadius: node.properties.showThumb
                  ? node.properties.thumbRadius
                  : 0,
              strokeColor: node.properties.thumbStrokeColor?.toFlutterColor(),
              strokeWidth: node.properties.thumbStrokeWidth,
            ),
            // The slider lays out horizontally and a vertical one is turned
            // a quarter turn, so its thumb's width and height swap.
            SliderThumbShapeEnum.roundedRect ||
            SliderThumbShapeEnum.rectangle => RoundedRectSliderThumbShape(
              size: !node.properties.showThumb
                  ? Size.zero
                  : vertical
                  ? Size(
                      node.properties.thumbHeight,
                      node.properties.thumbWidth,
                    )
                  : Size(
                      node.properties.thumbWidth,
                      node.properties.thumbHeight,
                    ),
              cornerRadius:
                  node.properties.thumbShape == SliderThumbShapeEnum.rectangle
                  ? 0
                  : node.properties.thumbCornerRadius,
              strokeColor: node.properties.thumbStrokeColor?.toFlutterColor(),
              strokeWidth: node.properties.thumbStrokeWidth,
            ),
          },
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
          value: value.clamp(min, max),
          onChanged: onChanged,
          autofocus: node.properties.autofocus,
          min: min,
          max: max,
          divisions: node.properties.isDiscrete
              ? node.properties.divisions
              : null,
          label: showsLabel ? getSliderLabel(node, value) : null,
          secondaryTrackValue: node.properties.secondaryTrackValue?.clamp(
            min,
            max,
          ),
          padding: node.properties.padding?.flutterEdgeInsets,
        ),
      ),
    );

    final TextDirection direction =
        Directionality.maybeOf(context) ?? TextDirection.ltr;
    final TextDirection flipped = direction == TextDirection.ltr
        ? TextDirection.rtl
        : TextDirection.ltr;
    // Vertical runs bottom to top in left to right text, so an inverted
    // vertical slider runs top to bottom.
    final Widget directed = node.properties.inverted
        ? Directionality(textDirection: flipped, child: slider)
        : Directionality(textDirection: direction, child: slider);

    if (!vertical) {
      return node.properties.inverted ? directed : slider;
    }
    return SizedBox(
      width: node.basicBoxLocal.width,
      height: node.basicBoxLocal.height,
      child: RotatedBox(quarterTurns: 3, child: directed),
    );
  }
}

/// A [RoundSliderThumbShape] with an optional stroke drawn inside its edge.
class StrokedSliderThumbShape extends RoundSliderThumbShape {
  /// Creates a [StrokedSliderThumbShape].
  const StrokedSliderThumbShape({
    super.enabledThumbRadius,
    this.strokeColor,
    this.strokeWidth = 0,
  });

  /// Color of the stroke; no stroke when null.
  final Color? strokeColor;

  /// Width of the stroke; no stroke when 0.
  final double strokeWidth;

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    super.paint(
      context,
      center,
      activationAnimation: activationAnimation,
      enableAnimation: enableAnimation,
      isDiscrete: isDiscrete,
      labelPainter: labelPainter,
      parentBox: parentBox,
      sliderTheme: sliderTheme,
      textDirection: textDirection,
      value: value,
      textScaleFactor: textScaleFactor,
      sizeWithOverflow: sizeWithOverflow,
    );
    final Color? color = strokeColor;
    if (color == null || strokeWidth <= 0 || enabledThumbRadius <= 0) return;
    final double width = math.min(strokeWidth, enabledThumbRadius);
    context.canvas.drawCircle(
      center,
      enabledThumbRadius - width / 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..color = color,
    );
  }
}

/// A rounded rectangle slider thumb, like a fader cap, with an optional
/// stroke drawn inside its edge. [size] is in the slider's own (horizontal)
/// layout: its width runs along the track.
class RoundedRectSliderThumbShape extends SliderComponentShape {
  /// Creates a [RoundedRectSliderThumbShape].
  const RoundedRectSliderThumbShape({
    required this.size,
    this.cornerRadius = 0,
    this.strokeColor,
    this.strokeWidth = 0,
    this.elevation = 1,
    this.pressedElevation = 6,
  });

  /// Size of the thumb; along the track, then across it.
  final Size size;

  /// Radius of the thumb's corners, at most half its shorter side.
  final double cornerRadius;

  /// Color of the stroke; no stroke when null.
  final Color? strokeColor;

  /// Width of the stroke; no stroke when 0.
  final double strokeWidth;

  /// Shadow elevation of the thumb at rest.
  final double elevation;

  /// Shadow elevation of the thumb while it is dragged.
  final double pressedElevation;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => size;

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    if (size.isEmpty) return;
    final Canvas canvas = context.canvas;
    final Color color = ColorTween(
      begin: sliderTheme.disabledThumbColor,
      end: sliderTheme.thumbColor,
    ).evaluate(enableAnimation)!;
    final double radius = math.max(
      0,
      math.min(cornerRadius, size.shortestSide / 2),
    );
    final RRect rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: size.width, height: size.height),
      Radius.circular(radius),
    );
    final double shadow = Tween<double>(
      begin: elevation,
      end: pressedElevation,
    ).evaluate(activationAnimation);
    if (shadow > 0 && !debugDisableShadows) {
      canvas.drawShadow(Path()..addRRect(rect), Colors.black, shadow, true);
    }
    canvas.drawRRect(rect, Paint()..color = color);

    final Color? stroke = strokeColor;
    if (stroke == null || strokeWidth <= 0) return;
    final double width = math.min(strokeWidth, size.shortestSide / 2);
    canvas.drawRRect(
      rect.deflate(width / 2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..color = stroke,
    );
  }
}
