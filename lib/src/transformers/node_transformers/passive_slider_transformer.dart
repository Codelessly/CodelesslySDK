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

/// A design-time slider: it shows what its bindings give (value, min, max,
/// marker, track color), as the runtime does, and can be dragged without
/// running any actions. A drag holds until the bound value changes.
class _PreviewSliderWidgetState extends State<PreviewSliderWidget> {
  double? dragged;
  Object? draggedFrom;

  @override
  Widget build(BuildContext context) {
    final Object? bound = widget.node.variables['value'] == null
        ? widget.node.value
        : PropertyValueDelegate.getPropertyValue<double>(
            widget.node,
            'value',
            scopedValues: ScopedValues.of(context),
          );
    if (dragged != null && bound != draggedFrom) dragged = null;
    return PassiveSliderWidget(
      node: widget.node,
      settings: widget.settings,
      valueOverride: dragged,
      onPreviewChanged: (value) => setState(() {
        dragged = value;
        draggedFrom = bound;
      }),
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

  /// Shown instead of the bound value (a design-time drag).
  final double? valueOverride;

  /// When set, a drag calls this instead of updating state and running
  /// actions: the design canvas's slider.
  final ValueChanged<double>? onPreviewChanged;

  const PassiveSliderWidget({
    super.key,
    required this.node,
    required this.settings,
    this.variablesOverrides = const [],
    this.scopedValues,
    this.valueOverride,
    this.onPreviewChanged,
  });

  void onChanged(BuildContext context, double internalValue) {
    if (onPreviewChanged case final ValueChanged<double> preview) {
      preview(internalValue);
      return;
    }
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
        valueOverride ??
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
    // Colours and the track fade are bindable through node.variables (and
    // settable by actions); each falls back to the node's own property.
    ColorRGBA? color(String property) =>
        PropertyValueDelegate.getPropertyValue<ColorRGBA>(
          node,
          property,
          scopedValues: scopedValues,
        );
    final ColorRGBA? activeTrackColor = color('activeTrackColor');
    final ColorRGBA? inactiveTrackColor = color('inactiveTrackColor');
    final ColorRGBA? thumbColor = color('thumbColor');
    final ColorRGBA? thumbGlowColor = color('thumbGlowColor');
    final double? activeTrackStartOpacity =
        PropertyValueDelegate.getPropertyValue<double>(
          node,
          'activeTrackStartOpacity',
          scopedValues: scopedValues,
        );

    return TransformerSlider(
      node: node,
      settings: settings,
      variablesOverrides: variablesOverrides,
      onChanged: (value) => onChanged(context, value),
      onChangeEnd: onPreviewChanged == null
          ? (value) => onChangeEnd(context, value)
          : null,
      value: value,
      min: min,
      max: max,
      markerValue: switch (marker) {
        num() => marker.toDouble(),
        String() => double.tryParse(marker),
        _ => node.variables['markerValue'] == null ? node.markerValue : null,
      },
      activeTrackColor: activeTrackColor?.toFlutterColor(),
      inactiveTrackColor: inactiveTrackColor?.toFlutterColor(),
      thumbColor: thumbColor?.toFlutterColor(),
      thumbGlowColor: thumbGlowColor?.toFlutterColor(),
      activeTrackStartOpacity: activeTrackStartOpacity,
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
    this.inactiveTrackColor,
    this.thumbColor,
    this.thumbGlowColor,
    this.activeTrackStartOpacity,
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

  /// Overrides [SliderProperties.inactiveTrackColor] (from a binding).
  final Color? inactiveTrackColor;

  /// Overrides [SliderProperties.thumbColor] (from a binding).
  final Color? thumbColor;

  /// Overrides [SliderProperties.thumbGlowColor] (from a binding).
  final Color? thumbGlowColor;

  /// Overrides [SliderProperties.activeTrackStartOpacity] (from a binding).
  final double? activeTrackStartOpacity;

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
    final double startOpacity =
        (activeTrackStartOpacity ?? p.activeTrackStartOpacity).clamp(0.0, 1.0);
    // Filling from the end, drawing a marker or fading the active track in
    // needs our own track painter; otherwise the Material shapes stay as
    // they were.
    final SliderTrackShape trackShape =
        p.fillFromEnd || markerFraction != null || startOpacity < 1
        ? IndustrialSliderTrackShape(
            fillFromEnd: p.fillFromEnd,
            activeStartOpacity: startOpacity,
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
    final SliderComponentShape baseThumbShape =
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
    // A soft glow behind the thumb, when it has a visible colour.
    final Color? glow = thumbGlowColor ?? p.thumbGlowColor?.toFlutterColor();
    final SliderComponentShape thumbShape =
        p.showThumb && glow != null && glow.a > 0
        ? GlowSliderThumbShape(
            thumb: baseThumbShape,
            color: glow,
            blur: p.thumbGlowBlur,
            spread: p.thumbGlowSpread,
            cornerRadius: p.thumbShape == SliderThumbShapeEnum.circle
                ? null
                : p.thumbCornerRadius,
          )
        : baseThumbShape;

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
          overlayColor: !node.properties.showThumb
              ? Colors.transparent
              : thumbColor != null &&
                    node.properties.deriveOverlayColorFromThumb
              ? thumbColor!.withValues(alpha: kSliderDefaultOverlayOpacity)
              : node.properties.overlayColor.toFlutterColor(),
          activeTrackColor:
              activeTrackColor ??
              node.properties.activeTrackColor.toFlutterColor(),
          inactiveTrackColor:
              inactiveTrackColor ??
              node.properties.inactiveTrackColor.toFlutterColor(),
          thumbColor: thumbColor ?? node.properties.thumbColor.toFlutterColor(),
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

/// Paints a soft, blurred glow of [color] behind another [thumb] shape, like
/// a lit knob. The glow is the thumb's outline grown by [spread] and blurred
/// by [blur] (a sigma); it does not change the thumb's size.
class GlowSliderThumbShape extends SliderComponentShape {
  /// Creates a [GlowSliderThumbShape].
  const GlowSliderThumbShape({
    required this.thumb,
    required this.color,
    this.blur = kSliderDefaultThumbGlowBlur,
    this.spread = kSliderDefaultThumbGlowSpread,
    this.cornerRadius,
  });

  /// The thumb drawn over the glow.
  final SliderComponentShape thumb;

  /// Color of the glow.
  final Color color;

  /// Blur sigma of the glow; a hard edge when 0.
  final double blur;

  /// How far the glow reaches past the thumb's edge, before blur.
  final double spread;

  /// Corner radius of a rectangular [thumb]; null for a round one.
  final double? cornerRadius;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      thumb.getPreferredSize(isEnabled, isDiscrete);

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
    final Size size = thumb.getPreferredSize(true, isDiscrete);
    if (!size.isEmpty) {
      final Paint paint = Paint()..color = color;
      if (blur > 0) paint.maskFilter = MaskFilter.blur(BlurStyle.normal, blur);
      final double grow = math.max(0, spread);
      if (cornerRadius == null) {
        context.canvas.drawCircle(center, size.shortestSide / 2 + grow, paint);
      } else {
        final Rect rect = Rect.fromCenter(
          center: center,
          width: size.width + grow * 2,
          height: size.height + grow * 2,
        );
        final double radius = math.min(
          math.max(0, cornerRadius!) + grow,
          rect.shortestSide / 2,
        );
        context.canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(radius)),
          paint,
        );
      }
    }
    thumb.paint(
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

/// A slider track that can fill from the thumb to the end, fade its active
/// part in from [activeStartOpacity] and draw a thin marker at
/// [markerFraction] of its length.
class IndustrialSliderTrackShape extends SliderTrackShape
    with BaseSliderTrackShape {
  const IndustrialSliderTrackShape({
    required this.fillFromEnd,
    this.activeStartOpacity = 1,
    required this.markerFraction,
    required this.markerColor,
    required this.markerWidth,
    required this.markerHeight,
    required this.radius,
  });

  final bool fillFromEnd;

  /// Opacity of the active track at its far end from the thumb, fading in to
  /// the full active colour at the thumb. 1 paints it solid.
  final double activeStartOpacity;

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
    // The track starts at the right in right-to-left (an inverted slider).
    final bool activeOnRight =
        fillFromEnd != (textDirection == TextDirection.rtl);
    final Rect active = activeOnRight
        ? Rect.fromLTRB(thumbCenter.dx, track.top, track.right, track.bottom)
        : Rect.fromLTRB(track.left, track.top, thumbCenter.dx, track.bottom);
    if (active.width > 0) {
      final Color color = sliderTheme.activeTrackColor ?? Colors.black;
      final Paint paint = Paint()..color = color;
      if (activeStartOpacity < 1) {
        // Faint at the far end, full at the thumb.
        final Color faint = color.withValues(
          alpha: color.a * activeStartOpacity.clamp(0.0, 1.0),
        );
        paint.shader = LinearGradient(
          begin: activeOnRight ? Alignment.centerRight : Alignment.centerLeft,
          end: activeOnRight ? Alignment.centerLeft : Alignment.centerRight,
          colors: <Color>[faint, color],
        ).createShader(active);
      }
      canvas.drawRRect(RRect.fromRectAndRadius(active, r), paint);
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
