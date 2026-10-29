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

  /// The values the slider's bindings read, such as design canvas defaults.
  /// When null, bindings use the build context and [variablesOverrides].
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

  void onChangeEnd(BuildContext context, double internalValue) {
    FunctionsRepository.triggerAction(
      context,
      node: node,
      TriggerType.changeEnd,
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
    final Object? marker = PropertyValueDelegate.getPropertyValue<Object>(
      node,
      'markerValue',
      scopedValues: scopedValues,
    );
    final ColorRGBA? activeTrackColor =
        PropertyValueDelegate.getPropertyValue<ColorRGBA>(
          node,
          'activeTrackColor',
          scopedValues: scopedValues,
        );

    return TransformerSlider(
      node: node,
      settings: settings,
      variablesOverrides: variablesOverrides,
      onChanged: (value) => onChanged(context, value),
      onChangeEnd: (value) => onChangeEnd(context, value),
      value: value,
      min: min,
      max: max,
      markerValue: switch (marker) {
        num() => marker.toDouble(),
        String() => double.tryParse(marker),
        _ => node.variables['markerValue'] == null ? node.markerValue : null,
      },
      activeTrackColor: activeTrackColor?.toFlutterColor(),
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
    this.onChangeEnd,
    this.markerValue,
    this.activeTrackColor,
    this.variablesOverrides = const [],
    this.min,
    this.max,
  });

  final SliderNode node;
  final WidgetBuildSettings settings;
  final List<VariableData> variablesOverrides;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;
  final double value;

  /// The slider's minimum, when bound; [SliderProperties.min] otherwise.
  final double? min;

  /// The slider's maximum, when bound; [SliderProperties.max] otherwise.
  final double? max;

  /// Where to draw [SliderProperties.markerColor]'s marker, if anywhere.
  final double? markerValue;

  /// Overrides [SliderProperties.activeTrackColor] (from a binding).
  final Color? activeTrackColor;

  /// [v] kept within the selectable part of the effective track.
  double _selectable(double v, double min, double max) {
    final SliderProperties p = node.properties;
    final double lo = (p.selectableMin ?? min).clamp(min, max);
    final double hi = (p.selectableMax ?? max).clamp(lo, max);
    return v.clamp(lo, hi);
  }

  @override
  Widget build(BuildContext context) {
    final SliderProperties p = node.properties;
    final double min = this.min ?? p.min;
    final double max = math.max(min, this.max ?? p.max);
    final bool vertical = p.orientation == AxisC.vertical;
    final double range = max - min;
    final double? markerFraction = markerValue == null || range == 0
        ? null
        : ((markerValue! - min) / range).clamp(0.0, 1.0);
    final SliderTrackShape baseTrackShape = switch (p.trackShape) {
      SliderTrackShapeEnum.rectangle => const RectangularSliderTrackShape(),
      SliderTrackShapeEnum.roundedRectangle =>
        const RoundedRectSliderTrackShape(),
      SliderTrackShapeEnum.gapped => const GappedSliderTrackShape(),
    };
    // Filling from the end or drawing a marker needs our own track painter;
    // otherwise the Material shapes stay as they were.
    final SliderTrackShape trackShape = p.fillFromEnd || markerFraction != null
        ? IndustrialSliderTrackShape(
            fillFromEnd: p.fillFromEnd,
            markerFraction: markerFraction,
            markerColor: p.markerColor.toFlutterColor(),
            markerWidth: p.markerWidth,
            markerHeight: p.markerHeight,
            radius: p.trackShape == SliderTrackShapeEnum.rectangle
                ? 0
                : (p.trackHeight / 2),
          )
        : baseTrackShape;
    // Preserve the existing stroked/rounded PR79 thumbs. The industrial
    // rectangle adds its optional border and grip without changing the
    // historically serialized roundedRect style.
    final SliderComponentShape thumbShape =
        p.thumbShape == SliderThumbShapeEnum.rectangle
        ? RectSliderThumbShape(
            width: !p.showThumb
                ? 0
                : vertical
                ? p.thumbHeight
                : p.thumbWidth,
            height: !p.showThumb
                ? 0
                : vertical
                ? p.thumbWidth
                : p.thumbHeight,
            radius: p.thumbCornerRadius,
            borderColor:
                p.thumbBorderColor?.toFlutterColor() ?? Colors.transparent,
            borderWidth: p.thumbBorderWidth,
            gripColor: p.thumbGripColor?.toFlutterColor() ?? Colors.transparent,
          )
        : p.thumbShape == SliderThumbShapeEnum.roundedRect
        ? RoundedRectSliderThumbShape(
            size: !p.showThumb
                ? Size.zero
                : vertical
                ? Size(p.thumbHeight, p.thumbWidth)
                : Size(p.thumbWidth, p.thumbHeight),
            cornerRadius: p.thumbCornerRadius,
            strokeColor: p.thumbStrokeColor?.toFlutterColor(),
            strokeWidth: p.thumbStrokeWidth,
          )
        : StrokedSliderThumbShape(
            enabledThumbRadius: p.showThumb ? p.thumbRadius : 0,
            strokeColor: p.thumbStrokeColor?.toFlutterColor(),
            strokeWidth: p.thumbStrokeWidth,
          );

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
          activeTrackColor:
              activeTrackColor ??
              node.properties.activeTrackColor.toFlutterColor(),
          inactiveTrackColor: node.properties.inactiveTrackColor
              .toFlutterColor(),
          thumbColor: node.properties.thumbColor.toFlutterColor(),
          thumbShape: thumbShape,
          trackShape: trackShape,
          // GappedSliderTrackShape requires a gap; 6 is the Material 3
          // (2024) default.
          trackGap: node.properties.trackShape == SliderTrackShapeEnum.gapped
              ? 6
              : null,
          tickMarkShape: !node.properties.isDiscrete
              ? null
              : node.properties.tickMarkStyle == SliderTickMarkStyle.notch
              ? NotchSliderTickMarkShape(
                  divisions: node.properties.divisions ?? 0,
                  every: node.properties.notchEvery,
                  color: node.properties.inactiveTickMarkColor.toFlutterColor(),
                )
              : RoundSliderTickMarkShape(
                  tickMarkRadius: node.properties.tickMarkRadius,
                ),
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
          value: _selectable(value.clamp(min, max), min, max),
          onChanged: onChanged == null
              ? null
              : (v) {
                  final double kept = _selectable(v, min, max);
                  if (kept != value) onChanged!(kept);
                },
          onChangeEnd: onChangeEnd == null
              ? null
              : (v) => onChangeEnd!(_selectable(v, min, max)),
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

/// A slider track that can fill from the thumb to the end and draw a thin
/// marker at [markerFraction] of its length.
class IndustrialSliderTrackShape extends SliderTrackShape
    with BaseSliderTrackShape {
  const IndustrialSliderTrackShape({
    required this.fillFromEnd,
    required this.markerFraction,
    required this.markerColor,
    required this.markerWidth,
    required this.markerHeight,
    required this.radius,
  });

  final bool fillFromEnd;
  final double? markerFraction;
  final Color markerColor;
  final double markerWidth;
  final double markerHeight;
  final double radius;

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
  }) {
    final Rect track = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    final Canvas canvas = context.canvas;
    final Radius r = Radius.circular(radius);
    canvas.drawRRect(
      RRect.fromRectAndRadius(track, r),
      Paint()..color = sliderTheme.inactiveTrackColor ?? Colors.grey,
    );
    final Rect active = fillFromEnd
        ? Rect.fromLTRB(thumbCenter.dx, track.top, track.right, track.bottom)
        : Rect.fromLTRB(track.left, track.top, thumbCenter.dx, track.bottom);
    if (active.width > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(active, r),
        Paint()..color = sliderTheme.activeTrackColor ?? Colors.black,
      );
    }
    if (markerFraction != null) {
      final double x = track.left + track.width * markerFraction!;
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(x, track.center.dy),
          width: markerWidth,
          height: markerHeight,
        ),
        Paint()..color = markerColor,
      );
    }
  }
}

/// A rounded-rectangle thumb, like a fader knob, with an optional border
/// and a short grip line across it.
class RectSliderThumbShape extends SliderComponentShape {
  const RectSliderThumbShape({
    required this.width,
    required this.height,
    required this.radius,
    required this.borderColor,
    required this.borderWidth,
    required this.gripColor,
  });

  final double width;
  final double height;
  final double radius;
  final Color borderColor;
  final double borderWidth;
  final Color gripColor;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => Size(width, height);

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
    if (width <= 0 || height <= 0) return;
    final Canvas canvas = context.canvas;
    final RRect body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: width, height: height),
      Radius.circular(radius),
    );
    canvas.drawRRect(body, Paint()..color = sliderTheme.thumbColor!);
    if (borderColor.a > 0 && borderWidth > 0) {
      canvas.drawRRect(
        body.deflate(borderWidth / 2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = borderWidth
          ..color = borderColor,
      );
    }
    if (gripColor.a > 0) {
      canvas.drawRect(
        Rect.fromCenter(center: center, width: width * 0.43, height: 2),
        Paint()..color = gripColor,
      );
    }
  }
}

/// Division marks as short lines under the track; every fifth is longer.
class NotchSliderTickMarkShape extends SliderTickMarkShape {
  const NotchSliderTickMarkShape({
    required this.divisions,
    required this.color,
    this.every = 1,
  });

  final int divisions;
  final Color color;

  /// Only every this many divisions gets a notch.
  final int every;

  @override
  Size getPreferredSize({
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
  }) => const Size(1, 1);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    bool isEnabled = false,
  }) {
    final Rect track =
        (sliderTheme.trackShape ?? const RectangularSliderTrackShape())
            .getPreferredRect(parentBox: parentBox, sliderTheme: sliderTheme);
    final double fraction = track.width == 0
        ? 0
        : ((center.dx - track.left) / track.width).clamp(0.0, 1.0);
    final int index = (fraction * divisions).round();
    final int step = every < 1 ? 1 : every;
    if (index % step != 0) return;
    final bool major = (index ~/ step) % 5 == 0;
    final double top = center.dy + (sliderTheme.trackHeight ?? 4) / 2 + 3;
    context.canvas.drawRect(
      Rect.fromLTWH(center.dx - 0.5, top, 1, major ? 8 : 5),
      Paint()..color = color,
    );
  }
}
