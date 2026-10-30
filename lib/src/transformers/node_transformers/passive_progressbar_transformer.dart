import 'dart:math' as math;

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
    WidgetBuildSettings settings = const WidgetBuildSettings(
      debugLabel: 'buildPreview',
    ),
  }) {
    final previewNode = ProgressBarNode(
      properties: properties ?? node?.properties ?? ProgressBarProperties(),
      id: '',
      name: 'ProgressBar',
      basicBoxLocal: NodeBox(
        0,
        0,
        width ?? kProgressBarDefaultWidth,
        height ?? kProgressBarDefaultHeight,
      ),
      retainedOuterBoxLocal: NodeBox(
        0,
        0,
        width ?? kProgressBarDefaultWidth,
        height ?? kProgressBarDefaultHeight,
      ),
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
    FunctionsRepository.setPropertyValue(
      context,
      node: node,
      property: 'currentValue',
      value: value,
    );

    FunctionsRepository.triggerAction(
      context,
      node: node,
      TriggerType.changed,
      value: value,
    );
  }
}

class PassiveProgressBarWidget extends StatelessWidget {
  final ProgressBarNode node;
  final WidgetBuildSettings settings;
  final List<VariableData> variablesOverrides;
  final bool? animate;
  final ValueChanged<double>? onChanged;

  /// The values bindings read instead of the build context's, such as the
  /// variable defaults a design canvas shows.
  final ScopedValues? scopedValues;

  const PassiveProgressBarWidget({
    super.key,
    required this.node,
    required this.settings,
    this.variablesOverrides = const [],
    this.animate,
    this.onChanged,
    this.scopedValues,
  });

  @override
  Widget build(BuildContext context) {
    final ScopedValues scopedValues =
        this.scopedValues ??
        ScopedValues.of(context, variablesOverrides: variablesOverrides);
    final double currentValue =
        PropertyValueDelegate.getPropertyValue<double>(
          node,
          'currentValue',
          scopedValues: scopedValues,
        ) ??
        node.currentValue;

    final Color progressColor =
        PropertyValueDelegate.getPropertyValue<ColorRGBA>(
          node,
          'progressColor',
          scopedValues: scopedValues,
        )?.toFlutterColor() ??
        node.properties.progressColor.toFlutterColor();

    if (node.properties.shape == ProgressBarShape.arc) {
      final ProgressBarProperties properties = boundArcProperties(
        node,
        scopedValues,
      );
      final double maxValue = properties.maxValue <= 0
          ? 1
          : properties.maxValue;
      return AdaptiveNodeBox(
        node: node,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: currentValue / maxValue),
          duration: (animate ?? node.properties.animate)
              ? Duration(
                  milliseconds: node.properties.animationDurationInMillis,
                )
              : Duration.zero,
          curve: Curves.easeOutCubic,
          builder: (context, progress, _) => CustomPaint(
            size: Size.infinite,
            painter: ArcProgressPainter(
              progress: progress,
              properties: properties,
              progressColor: progressColor,
            ),
          ),
        ),
      );
    }

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

/// [node]'s arc properties with the values its variables bind (see
/// [ProgressBarProperties.bindableKeys]): angles, thickness, max and colors,
/// so one arc per item of a data list can make up a segmented ring.
ProgressBarProperties boundArcProperties(
  ProgressBarNode node,
  ScopedValues scopedValues,
) {
  final ProgressBarProperties p = node.properties;
  if (!node.variables.keys.any(ProgressBarProperties.bindableKeys.contains)) {
    return p;
  }
  double? number(String key) {
    if (!node.variables.containsKey(key)) return null;
    final Object? v = PropertyValueDelegate.getPropertyValue<Object>(
      node,
      key,
      scopedValues: scopedValues,
    );
    final double? d = switch (v) {
      num n => n.toDouble(),
      String s => double.tryParse(s.trim()),
      _ => null,
    };
    return d != null && d.isFinite ? d : null;
  }

  ColorRGBA? color(String key) => node.variables.containsKey(key)
      ? PropertyValueDelegate.getPropertyValue<ColorRGBA>(
          node,
          key,
          scopedValues: scopedValues,
        )
      : null;

  return p.copyWith(
    maxValue: number('maxValue'),
    arcStartAngle: number('arcStartAngle'),
    arcSweepAngle: number('arcSweepAngle'),
    arcStrokeWidth: number('arcStrokeWidth'),
    backgroundColor: color('backgroundColor'),
    progressEndColor: color('progressEndColor'),
  );
}

/// Paints an arc progress bar: a track, colored zone bands just outside it,
/// the progress arc, tick marks and an optional needle. [progress] is the
/// value as a fraction of the max; over 1 fills the arc and pushes the needle
/// a little past its end.
class ArcProgressPainter extends CustomPainter {
  ArcProgressPainter({
    required this.progress,
    required this.properties,
    required this.progressColor,
  });

  final double progress;
  final ProgressBarProperties properties;
  final Color progressColor;

  static double _rad(double degrees) => degrees * math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final double stroke = properties.arcStrokeWidth;
    final double bandWidth = properties.bands.isEmpty ? 0 : stroke / 3;
    final double gap = properties.bands.isEmpty ? 0 : stroke / 4;
    final double start = _rad(properties.arcStartAngle);
    final double sweep = _rad(properties.arcSweepAngle);

    final (:Offset center, :double radius) = arcGeometry(
      size,
      properties,
      outer: stroke / 2 + gap + bandWidth,
    );
    final Rect arcRect = Rect.fromCircle(center: center, radius: radius);
    final StrokeCap cap = properties.arcRoundCaps
        ? StrokeCap.round
        : StrokeCap.butt;

    canvas.drawArc(
      arcRect,
      start,
      sweep,
      false,
      Paint()
        ..color = properties.backgroundColor.toFlutterColor()
        ..style = PaintingStyle.stroke
        ..strokeCap = cap
        ..strokeWidth = stroke,
    );

    final Rect bandRect = Rect.fromCircle(
      center: center,
      radius: radius + stroke / 2 + gap + bandWidth / 2,
    );
    for (final ProgressBand band in properties.bands) {
      final double from = band.start.clamp(0, 1).toDouble();
      final double to = band.end.clamp(0, 1).toDouble();
      if (to <= from) continue;
      canvas.drawArc(
        bandRect,
        start + sweep * from,
        sweep * (to - from),
        false,
        Paint()
          ..color = band.color.toFlutterColor()
          ..style = PaintingStyle.stroke
          ..strokeWidth = bandWidth,
      );
    }

    final double filled = progress.clamp(0, 1).toDouble();
    if (filled > 0) {
      final double fill = sweep * filled;
      if (properties.arcGlow > 0) {
        canvas.drawArc(
          arcRect,
          start,
          fill,
          false,
          Paint()
            ..color = progressColor.withValues(alpha: progressColor.a * 0.35)
            ..style = PaintingStyle.stroke
            ..strokeCap = cap
            ..strokeWidth = stroke + properties.arcGlow
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, properties.arcGlow),
        );
      }
      final Paint paint = Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeCap = cap
        ..strokeWidth = stroke;
      final ColorRGBA? end = properties.progressEndColor;
      if (end != null && fill.abs() > 0.001) {
        // A sweep gradient from the start of the arc to the tip of the fill.
        final double from = fill >= 0 ? start : start + fill;
        paint.shader = SweepGradient(
          colors: fill >= 0
              ? [progressColor, end.toFlutterColor()]
              : [end.toFlutterColor(), progressColor],
          endAngle: fill.abs(),
          transform: GradientRotation(from),
        ).createShader(arcRect);
      }
      canvas.drawArc(arcRect, start, fill, false, paint);
      if (properties.arcHeadDot && filled < 1) {
        final double a = start + fill;
        final Offset tip = center + Offset(math.cos(a), math.sin(a)) * radius;
        canvas.drawCircle(
          tip,
          stroke,
          Paint()
            ..color = progressColor.withValues(alpha: progressColor.a * 0.6)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, stroke),
        );
        canvas.drawCircle(
          tip,
          stroke * 0.62,
          Paint()..color = const Color(0xFFFFFFFF),
        );
      }
    }

    if (properties.tickCount > 1) {
      final Paint tick = Paint()
        ..color = properties.tickColor.toFlutterColor()
        ..strokeWidth = 2;
      for (int i = 1; i < properties.tickCount; i++) {
        final double a = start + sweep * i / properties.tickCount;
        final Offset d = Offset(math.cos(a), math.sin(a));
        canvas.drawLine(
          center + d * (radius - stroke / 2),
          center + d * (radius + stroke / 2),
          tick,
        );
      }
    }

    final ColorRGBA? needle = properties.needleColor;
    if (needle != null) {
      final double a = start + sweep * progress.clamp(0, 1.06);
      final Offset d = Offset(math.cos(a), math.sin(a));
      final Offset normal = Offset(-d.dy, d.dx);
      final double half = math.max(2, stroke * 0.3);
      final Offset tip = center + d * (radius + stroke * 0.2);
      final Offset base = center + d * (radius - stroke * 1.9);
      canvas.drawPath(
        Path()
          ..moveTo(tip.dx, tip.dy)
          ..lineTo((base + normal * half).dx, (base + normal * half).dy)
          ..lineTo((base - normal * half).dx, (base - normal * half).dy)
          ..close(),
        Paint()..color = needle.toFlutterColor(),
      );
    }
  }

  /// Where the arc's circle sits in a box of [size]: the largest circle whose
  /// arc fits the box, or with [ArcFit.circle] the whole circle, centred, so
  /// arcs of any length share one ring. [outer] is the room kept outside the
  /// circle's line (half the stroke, plus bands).
  static ({Offset center, double radius}) arcGeometry(
    Size size,
    ProgressBarProperties properties, {
    double? outer,
  }) {
    final double room = outer ?? properties.arcStrokeWidth / 2;
    if (properties.arcFit == ArcFit.circle) {
      return (
        center: size.center(Offset.zero),
        radius: math.max(0, size.shortestSide / 2 - room),
      );
    }
    final Rect unit = _arcBounds(
      _rad(properties.arcStartAngle),
      _rad(properties.arcSweepAngle),
    );
    final double radius = math.max(
      0,
      math.min(
        (size.width - 2 * room) / unit.width,
        (size.height - 2 * room) / unit.height,
      ),
    );
    return (
      center: Offset(
        size.width / 2 - unit.center.dx * radius,
        size.height / 2 - unit.center.dy * radius,
      ),
      radius: radius,
    );
  }

  /// Bounds of an arc of a unit circle from [start] sweeping [sweep], plus
  /// the center, so the arc can be fitted to a box.
  static Rect _arcBounds(double start, double sweep) {
    final List<Offset> points = [Offset.zero];
    void add(double a) => points.add(Offset(math.cos(a), math.sin(a)));
    add(start);
    add(start + sweep);
    // Each axis extreme the arc passes through.
    for (int k = -8; k <= 8; k++) {
      final double a = k * math.pi / 2;
      final bool inside = sweep >= 0
          ? a >= start && a <= start + sweep
          : a <= start && a >= start + sweep;
      if (inside) add(a);
    }
    double left = 0, top = 0, right = 0, bottom = 0;
    for (final Offset p in points) {
      left = math.min(left, p.dx);
      top = math.min(top, p.dy);
      right = math.max(right, p.dx);
      bottom = math.max(bottom, p.dy);
    }
    final Rect rect = Rect.fromLTRB(left, top, right, bottom);
    return rect.width <= 0 || rect.height <= 0
        ? const Rect.fromLTRB(-1, -1, 1, 1)
        : rect;
  }

  @override
  bool shouldRepaint(ArcProgressPainter old) =>
      old.progress != progress ||
      old.properties != properties ||
      old.progressColor != progressColor;
}
