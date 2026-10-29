import 'dart:math' as math;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';

import '../../../codelessly_sdk.dart';

/// Renderer for the radial gauge. Registration in the manager is owned elsewhere.
class PassiveRadialGaugeTransformer extends NodeWidgetTransformer<GaugeNode> {
  PassiveRadialGaugeTransformer(super.getNode, super.manager);

  @override
  Widget buildWidget(
    GaugeNode node,
    BuildContext context,
    WidgetBuildSettings settings,
  ) => PassiveRadialGaugeWidget(node: node, settings: settings);
}

class PassiveRadialGaugeWidget extends StatelessWidget {
  final GaugeNode node;
  final WidgetBuildSettings settings;
  final List<VariableData> variablesOverrides;
  final ScopedValues? scopedValues;
  final bool? animate;

  const PassiveRadialGaugeWidget({
    super.key,
    required this.node,
    required this.settings,
    this.variablesOverrides = const [],
    this.scopedValues,
    this.animate,
  });

  @override
  Widget build(BuildContext context) {
    final values =
        scopedValues ??
        ScopedValues.of(context, variablesOverrides: variablesOverrides);
    final props = node.properties;
    final value =
        _number(
          PropertyValueDelegate.getPropertyValue<Object>(
            node,
            'value',
            scopedValues: values,
          ),
        ) ??
        node.value;
    return AdaptiveNodeBox(
      node: node,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: props.fraction(value)),
        duration: (animate ?? props.animate)
            ? Duration(milliseconds: props.animationDurationInMillis)
            : Duration.zero,
        curve: Curves.easeOutCubic,
        builder: (context, fraction, _) => CustomPaint(
          size: Size.infinite,
          painter: RadialGaugePainter(props: props, fraction: fraction),
        ),
      ),
    );
  }
}

/// Radial dial, distinct from the arc/bar meter and its limit marker.
class RadialGaugePainter extends CustomPainter {
  final GaugeProperties props;
  final double fraction;

  RadialGaugePainter({required this.props, required this.fraction});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final shortest = math.min(size.width, size.height);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.max(
      0.0,
      shortest / 2 - math.max(props.thickness, props.zoneThickness) / 2 - 8,
    );
    if (radius <= 0) return;
    final start = props.startAngle * math.pi / 180;
    final sweep = props.sweepAngle * math.pi / 180;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final track = props.trackColor.toFlutterColor();
    final value = props.min + (props.max - props.min) * fraction;
    final fill = props.colorFor(value).toFlutterColor();
    final stroke = math.max(0.0, props.thickness);

    void arc(
      Rect bounds,
      double from,
      double length,
      Color color,
      double width,
    ) {
      if (width <= 0 || length <= 0) return;
      canvas.drawArc(
        bounds,
        from,
        length,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..color = color,
      );
    }

    final zoneRadius = radius + stroke / 2 + props.zoneThickness / 2 + 2;
    if (props.zoneThickness > 0 && props.zoneOpacity > 0) {
      final zoneRect = Rect.fromCircle(center: center, radius: zoneRadius);
      for (final zone in props.zones) {
        final from = props.fraction(zone.from);
        final to = props.fraction(zone.to);
        arc(
          zoneRect,
          start + sweep * from,
          sweep * (to - from),
          zone.color.toFlutterColor().withValues(
            alpha: props.zoneOpacity.clamp(0.0, 1.0),
          ),
          props.zoneThickness,
        );
      }
    }

    if (props.segments > 0) {
      final segment = sweep / props.segments;
      final gap = math.max(0.0, props.segmentGap * math.pi / 180);
      final lit = (fraction * props.segments).round();
      for (var i = 0; i < props.segments; i++) {
        arc(
          rect,
          start + segment * i + gap / 2,
          math.max(0.0, segment - gap),
          i < lit ? fill : track,
          stroke,
        );
      }
    } else {
      arc(rect, start, sweep, track, stroke);
      arc(rect, start, sweep * fraction, fill, stroke);
    }

    Offset at(double r, double angle) =>
        center + Offset(math.cos(angle), math.sin(angle)) * r;
    final intervals = props.majorTicks;
    if (intervals > 0) {
      final steps = intervals * (math.max(0, props.minorTicks) + 1);
      for (var i = 0; i <= steps; i++) {
        final angle = start + sweep * i / steps;
        final major = i % (props.minorTicks + 1) == 0;
        canvas.drawLine(
          at(radius - stroke / 2 - 3, angle),
          at(radius - stroke / 2 - (major ? 15 : 9), angle),
          Paint()
            ..color = props.tickColor.toFlutterColor()
            ..strokeWidth = major ? 2 : 1,
        );
      }
    }

    if (props.labelFontSize > 0) {
      for (final label in props.labels) {
        final painter = TextPainter(
          text: TextSpan(
            text: label.toString(),
            style: TextStyle(
              color: props.labelColor.toFlutterColor(),
              fontSize: props.labelFontSize,
              fontFamily: props.labelFontFamily,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final position = at(
          math.max(0, radius - stroke / 2 - 27),
          start + sweep * props.fraction(label),
        );
        painter.paint(
          canvas,
          position - Offset(painter.width / 2, painter.height / 2),
        );
      }
    }

    if (props.showTarget) {
      final angle = start + sweep * props.fraction(props.target);
      canvas.drawLine(
        at(radius + stroke / 2 + 2, angle),
        at(radius + stroke / 2 + 11, angle),
        Paint()
          ..color = props.targetColor.toFlutterColor()
          ..strokeWidth = 3,
      );
    }
    if (props.showNeedle) {
      final angle = start + sweep * fraction;
      final clearance = props.needleClearance.clamp(0.0, 1.0);
      final needle = Paint()
        ..color = props.needleColor.toFlutterColor()
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        at(radius * clearance, angle),
        at(radius - stroke / 2 - 2, angle),
        needle,
      );
    }
  }

  @override
  bool shouldRepaint(RadialGaugePainter old) =>
      old.fraction != fraction || old.props != props;
}

/// Existing arc/bar meter renderer (not the radial dial).
class PassiveGaugeTransformer extends NodeWidgetTransformer<GaugeMeterNode> {
  PassiveGaugeTransformer(super.getNode, super.manager);

  @override
  Widget buildWidget(
    GaugeMeterNode node,
    BuildContext context,
    WidgetBuildSettings settings,
  ) {
    return PassiveGaugeWidget(node: node, settings: settings);
  }
}

/// Renders a [GaugeMeterNode], reading its bindable `value`, `limit`, `color`
/// and `limitColor` from conditions and variables.
class PassiveGaugeWidget extends StatelessWidget {
  final GaugeMeterNode node;
  final WidgetBuildSettings settings;
  final List<VariableData> variablesOverrides;

  /// The values bindings read, when the caller has them, e.g. the editor's
  /// variable defaults on the design canvas. Defaults to the context's.
  final ScopedValues? scopedValues;

  /// Overrides [GaugeMeterProperties.animate], e.g. to hold still in the editor.
  final bool? animate;

  const PassiveGaugeWidget({
    super.key,
    required this.node,
    required this.settings,
    this.variablesOverrides = const [],
    this.scopedValues,
    this.animate,
  });

  @override
  Widget build(BuildContext context) {
    final ScopedValues scopedValues =
        this.scopedValues ??
        ScopedValues.of(context, variablesOverrides: variablesOverrides);
    final GaugeMeterProperties props = node.properties;
    final double value =
        _number(
          PropertyValueDelegate.getPropertyValue<Object>(
            node,
            'value',
            scopedValues: scopedValues,
          ),
        ) ??
        node.value;
    final double? limit =
        _number(
          PropertyValueDelegate.getPropertyValue<Object>(
            node,
            'limit',
            scopedValues: scopedValues,
          ),
        ) ??
        (node.variables['limit'] == null ? node.limit : null);
    final Color color =
        PropertyValueDelegate.getPropertyValue<ColorRGBA>(
          node,
          'color',
          scopedValues: scopedValues,
        )?.toFlutterColor() ??
        props.color.toFlutterColor();
    final Color limitColor =
        PropertyValueDelegate.getPropertyValue<ColorRGBA>(
          node,
          'limitColor',
          scopedValues: scopedValues,
        )?.toFlutterColor() ??
        props.limitColor.toFlutterColor();

    final double range = props.max - props.min;
    double fraction(double v) =>
        range == 0 ? 0 : ((v - props.min) / range).clamp(0.0, 1.0);

    final bool animated = animate ?? props.animate;
    return AdaptiveNodeBox(
      node: node,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: fraction(value)),
        duration: animated
            ? Duration(milliseconds: props.animationDurationInMillis)
            : Duration.zero,
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => CustomPaint(
          size: Size.infinite,
          painter: GaugePainter(
            props: props,
            fraction: v,
            limit: limit == null ? null : fraction(limit),
            color: color,
            limitColor: limitColor,
          ),
        ),
      ),
    );
  }
}

/// Reads a number from a bound value: a number, or text that parses as one.
double? _number(Object? value) => switch (value) {
  num() => value.toDouble(),
  String() => double.tryParse(value.trim()),
  _ => null,
};

/// Paints a [GaugeMeterProperties] gauge filled to [fraction] (0 to 1), with an
/// optional limit marker at [limit] (0 to 1).
class GaugePainter extends CustomPainter {
  final GaugeMeterProperties props;
  final double fraction;
  final double? limit;
  final Color color;
  final Color limitColor;

  GaugePainter({
    required this.props,
    required this.fraction,
    required this.limit,
    required this.color,
    required this.limitColor,
  });

  static double _rad(double degrees) => degrees * math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    switch (props.shape) {
      case GaugeShape.arc:
        _paintArc(canvas, size);
      case GaugeShape.bar:
        _paintBar(canvas, size);
    }
  }

  void _paintArc(Canvas canvas, Size size) {
    final double d = math.min(size.width, size.height * 2);
    final double stroke = props.thickness > 0 ? props.thickness : d * 0.075;
    final Offset center = Offset(size.width / 2, d / 2);
    final double r = d / 2 - stroke / 2 - d * 0.04;
    final Rect rect = Rect.fromCircle(center: center, radius: r);
    final double start = _rad(props.startAngle);
    final double sweep = _rad(props.sweepAngle);
    final Color track = props.trackColor.toFlutterColor();

    if (props.segments > 0) {
      final double seg = sweep / props.segments;
      final double gap = _rad(props.segmentGap);
      final int lit = (fraction * props.segments).round();
      for (int i = 0; i < props.segments; i++) {
        canvas.drawArc(
          rect,
          start + i * seg + gap / 2,
          math.max(0, seg - gap),
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke
            ..color = i < lit ? color : track,
        );
      }
    } else {
      final Paint paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke;
      canvas.drawArc(rect, start, sweep, false, paint..color = track);
      if (fraction > 0) {
        canvas.drawArc(
          rect,
          start,
          sweep * fraction,
          false,
          paint..color = color,
        );
      }
    }

    if (props.ticks > 0) {
      final Paint tick = Paint()..color = props.tickColor.toFlutterColor();
      for (int i = 0; i <= props.ticks; i++) {
        final double a = start + sweep * i / props.ticks;
        final bool major =
            props.majorTickEvery > 0 && i % props.majorTickEvery == 0;
        final double r1 = r - stroke / 2 - d * 0.03;
        final double r2 = r1 - (major ? d * 0.05 : d * 0.025);
        final Offset dir = Offset(math.cos(a), math.sin(a));
        tick.strokeWidth = major ? 2 : 1;
        canvas.drawLine(center + dir * r1, center + dir * r2, tick);
      }
    }

    if (limit != null) {
      final double a = start + sweep * limit!;
      final Offset dir = Offset(math.cos(a), math.sin(a));
      final double outer = r + stroke / 2 + d * 0.035;
      final double inner = r - stroke / 2 - d * 0.005;
      canvas.drawLine(
        center + dir * inner,
        center + dir * outer,
        Paint()
          ..color = limitColor
          ..strokeWidth = props.limitWidth
          ..strokeCap = StrokeCap.square,
      );
    }
  }

  void _paintBar(Canvas canvas, Size size) {
    final bool vertical = size.height > size.width;
    final Radius radius = Radius.circular(props.cornerRadius);
    final RRect well = RRect.fromRectAndRadius(Offset.zero & size, radius);
    final Color background = props.backgroundColor.toFlutterColor();
    if (background.a > 0) canvas.drawRRect(well, Paint()..color = background);

    final double inset = props.inset;
    final Rect inner = Rect.fromLTRB(
      inset,
      inset,
      size.width - inset,
      size.height - inset,
    );
    final double length = vertical ? inner.height : inner.width;
    final Color track = props.trackColor.toFlutterColor();

    // The part of [inner] between fractions [from] and [to] along the bar.
    Rect span(double from, double to) => vertical
        ? Rect.fromLTRB(
            inner.left,
            inner.bottom - length * to,
            inner.right,
            inner.bottom - length * from,
          )
        : Rect.fromLTRB(
            inner.left + length * from,
            inner.top,
            inner.left + length * to,
            inner.bottom,
          );

    Paint fillPaint(Rect rect) {
      final Paint paint = Paint()..color = color;
      if (props.fillStartOpacity < 1) {
        final Color faded = color.withValues(
          alpha: color.a * props.fillStartOpacity,
        );
        paint.shader = LinearGradient(
          begin: vertical ? Alignment.topCenter : Alignment.centerRight,
          end: vertical ? Alignment.bottomCenter : Alignment.centerLeft,
          colors: [color, faded],
        ).createShader(rect);
      }
      return paint;
    }

    if (props.segments > 0) {
      final double gap = props.segmentGap;
      final double seg = (length - gap * (props.segments - 1)) / props.segments;
      final int lit = (fraction * props.segments).round();
      final Radius segRadius = Radius.circular(
        math.min(props.cornerRadius, seg / 2),
      );
      for (int i = 0; i < props.segments; i++) {
        final double from = (i * (seg + gap)) / length;
        final double to = (i * (seg + gap) + seg) / length;
        final Rect rect = span(from, to);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, segRadius),
          Paint()..color = i < lit ? color : track,
        );
      }
    } else {
      if (track.a > 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(inner, radius),
          Paint()..color = track,
        );
      }
      if (fraction > 0) {
        final Rect fill = span(0, fraction);
        canvas.drawRect(fill, fillPaint(fill));
        if (props.edgeWidth > 0) {
          final Rect edge = vertical
              ? Rect.fromLTWH(fill.left, fill.top, fill.width, props.edgeWidth)
              : Rect.fromLTWH(
                  fill.right - props.edgeWidth,
                  fill.top,
                  props.edgeWidth,
                  fill.height,
                );
          canvas.drawRect(
            edge,
            Paint()..color = props.edgeColor.toFlutterColor(),
          );
        }
      }
    }

    // Graduations: full width at major ticks, 35% in from each side at minor.
    if (props.ticks > 1) {
      final Paint tick = Paint()
        ..color = props.tickColor.toFlutterColor()
        ..strokeWidth = 1;
      final double across = vertical ? inner.width : inner.height;
      for (int i = 1; i < props.ticks; i++) {
        final bool major =
            props.majorTickEvery > 0 && i % props.majorTickEvery == 0;
        final double w = major ? across : across * 0.35;
        final double p = length * i / props.ticks;
        if (vertical) {
          final double y = inner.bottom - p;
          canvas.drawLine(
            Offset(inner.left, y),
            Offset(inner.left + w, y),
            tick,
          );
          canvas.drawLine(
            Offset(inner.right - w, y),
            Offset(inner.right, y),
            tick,
          );
        } else {
          final double x = inner.left + p;
          canvas.drawLine(Offset(x, inner.top), Offset(x, inner.top + w), tick);
          canvas.drawLine(
            Offset(x, inner.bottom - w),
            Offset(x, inner.bottom),
            tick,
          );
        }
      }
    }

    if (limit != null) {
      final Paint paint = Paint()
        ..color = limitColor
        ..strokeWidth = props.limitWidth;
      final double p = length * limit!;
      final Offset a = vertical
          ? Offset(inner.left, inner.bottom - p)
          : Offset(inner.left + p, inner.top);
      final Offset b = vertical
          ? Offset(inner.right, inner.bottom - p)
          : Offset(inner.left + p, inner.bottom);
      if (props.limitStyle == GaugeLimitStyle.dashed) {
        const double dash = 5;
        final double total = (b - a).distance;
        final Offset dir = (b - a) / total;
        for (double t = 0; t < total; t += dash * 2) {
          canvas.drawLine(
            a + dir * t,
            a + dir * math.min(t + dash, total),
            paint,
          );
        }
      } else {
        canvas.drawLine(a, b, paint);
      }
      if (props.limitPointer) {
        final Path tri = vertical
            ? (Path()
                ..moveTo(0, a.dy - 5)
                ..lineTo(5, a.dy)
                ..lineTo(0, a.dy + 5)
                ..close())
            : (Path()
                ..moveTo(a.dx - 5, size.height)
                ..lineTo(a.dx, size.height - 5)
                ..lineTo(a.dx + 5, size.height)
                ..close());
        canvas.drawPath(tri, Paint()..color = limitColor);
      }
    }

    final Color border = props.borderColor.toFlutterColor();
    if (border.a > 0) {
      canvas.drawRRect(
        well.deflate(0.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..color = border,
      );
    }
  }

  @override
  bool shouldRepaint(GaugePainter old) =>
      old.fraction != fraction ||
      old.limit != limit ||
      old.color != color ||
      old.limitColor != limitColor ||
      old.props != props;
}
