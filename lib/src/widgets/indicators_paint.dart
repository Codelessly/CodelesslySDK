// Painters of the indicators group: progress bars, gauges, the bar chart and
// barcodes. Each paints one node from its props.
import 'dart:math' as math;

import 'package:barcode/barcode.dart' as bc;
import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_api/codelessly_api.dart'
    show
        ArcFit,
        BarChartProps,
        BarcodeErrorCorrection,
        BarcodeProps,
        BarcodeSymbology,
        CircularProgressIndicatorProps,
        GaugeLimitStyle,
        GaugeMeterProps,
        GaugeShape,
        Node,
        ProgressBarProps,
        ProgressBarShape,
        RadialGaugeProps;
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/painting.dart';
import 'package:flutter/rendering.dart' show CustomPainter;

import '../render/convert.dart';

/// Paints one node; repaints when the node changes.
abstract class NodePainter extends CustomPainter {
  NodePainter(this.n, {super.repaint});

  final Node n;

  T p<T>(api.PropDef<T> def) => n.prop(def);

  @override
  bool shouldRepaint(covariant NodePainter oldDelegate) => oldDelegate.n != n || oldDelegate.runtimeType != runtimeType;
}

double _rad(double degrees) => degrees * math.pi / 180;

// --- circular progress indicator (arc) ----------------------------------------

/// An arc spinner: a track across `sweepAngle` degrees from `startAngle`
/// and, over it, the `value` fraction of that arc (all of it when null).
/// The stroke sits on the bounds as `CircularProgressIndicator`'s does.
class ArcIndicatorPainter extends NodePainter {
  ArcIndicatorPainter(super.n);

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = p(CircularProgressIndicatorProps.strokeWidth);
    final strokeAlign = p(CircularProgressIndicatorProps.strokeAlign);
    final startAngle = p(CircularProgressIndicatorProps.startAngle);
    final sweepAngle = p(CircularProgressIndicatorProps.sweepAngle);
    final value = p(CircularProgressIndicatorProps.value);
    final cap = p(CircularProgressIndicatorProps.strokeCap);
    final color = p(CircularProgressIndicatorProps.color)?.flutter ?? const Color(0xFF000000);
    final track = p(CircularProgressIndicatorProps.backgroundColor)?.flutter ?? const Color(0x00000000);
    final offset = strokeWidth / 2 * -strokeAlign;
    final rect = Offset(offset, offset) & Size(size.width - offset * 2, size.height - offset * 2);
    Paint stroke(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = cap == null ? StrokeCap.butt : StrokeCap.values.byName(cap.name);
    if (track.a > 0) canvas.drawArc(rect, _rad(startAngle), _rad(sweepAngle), false, stroke(track));
    final filled = sweepAngle * (value ?? 1);
    if (filled != 0) canvas.drawArc(rect, _rad(startAngle), _rad(filled), false, stroke(color));
  }
}

// --- progress bar ---------------------------------------------------------------

/// A progress bar: a rounded bar filled along its direction (FAProgressBar:
/// whole percents, upward when vertical), or an arc with bands, ticks and a
/// needle.
class ProgressBarPainter extends NodePainter {
  ProgressBarPainter(super.n);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    if (p(ProgressBarProps.shape) == ProgressBarShape.arc) {
      final max = p(ProgressBarProps.max);
      _paintArc(canvas, size, p(ProgressBarProps.value) / (max <= 0 ? 1 : max));
    } else {
      _paintBar(canvas, size);
    }
  }

  void _paintBar(Canvas canvas, Size size) {
    final radius = p(ProgressBarProps.borderRadius).flutter;
    final box = Offset.zero & size;
    canvas.drawRRect(radius.toRRect(box), Paint()..color = p(ProgressBarProps.backgroundColor).flutter);
    final value = p(ProgressBarProps.value), max = p(ProgressBarProps.max);
    final fraction = value == 0 || max == 0 ? 0.0 : value / max;
    // The filled part is an Expanded with flex (fraction * 100).toInt().
    final percent = (fraction * 100).toInt().clamp(0, 100);
    if (percent == 0) return;
    final Rect fill = p(ProgressBarProps.direction) == api.Axis.vertical
        ? Rect.fromLTRB(0, size.height * (1 - percent / 100), size.width, size.height)
        : Rect.fromLTWH(0, 0, size.width * percent / 100, size.height);
    canvas.drawRRect(radius.toRRect(fill), Paint()..color = p(ProgressBarProps.color).flutter);
  }

  void _paintArc(Canvas canvas, Size size, double progress) {
    final bands = p(ProgressBarProps.bands);
    final progressColor = p(ProgressBarProps.color).flutter;
    final stroke = p(ProgressBarProps.arcStrokeWidth);
    final bandWidth = bands.isEmpty ? 0.0 : stroke / 3;
    final gap = bands.isEmpty ? 0.0 : stroke / 4;
    final start = _rad(p(ProgressBarProps.arcStartAngle));
    final sweep = _rad(p(ProgressBarProps.arcSweepAngle));
    final (:center, :radius) = arcGeometry(size, outer: stroke / 2 + gap + bandWidth);
    final arcRect = Rect.fromCircle(center: center, radius: radius);
    final cap = p(ProgressBarProps.arcRoundCaps) ? StrokeCap.round : StrokeCap.butt;

    canvas.drawArc(
      arcRect,
      start,
      sweep,
      false,
      Paint()
        ..color = p(ProgressBarProps.backgroundColor).flutter
        ..style = PaintingStyle.stroke
        ..strokeCap = cap
        ..strokeWidth = stroke,
    );

    final bandRect = Rect.fromCircle(center: center, radius: radius + stroke / 2 + gap + bandWidth / 2);
    for (final band in bands) {
      final from = band.start.clamp(0, 1).toDouble();
      final to = band.end.clamp(0, 1).toDouble();
      if (to <= from) continue;
      canvas.drawArc(
        bandRect,
        start + sweep * from,
        sweep * (to - from),
        false,
        Paint()
          ..color = band.color.flutter
          ..style = PaintingStyle.stroke
          ..strokeWidth = bandWidth,
      );
    }

    final filled = progress.clamp(0, 1).toDouble();
    if (filled > 0) {
      final fill = sweep * filled;
      final glow = p(ProgressBarProps.arcGlow);
      if (glow > 0) {
        canvas.drawArc(
          arcRect,
          start,
          fill,
          false,
          Paint()
            ..color = progressColor.withValues(alpha: progressColor.a * 0.35)
            ..style = PaintingStyle.stroke
            ..strokeCap = cap
            ..strokeWidth = stroke + glow
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, glow),
        );
      }
      final paint = Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeCap = cap
        ..strokeWidth = stroke;
      final end = p(ProgressBarProps.progressEndColor)?.flutter;
      if (end != null && fill.abs() > 0.001) {
        // A sweep gradient from the start of the arc to the tip of the fill.
        final from = fill >= 0 ? start : start + fill;
        paint.shader = SweepGradient(
          colors: fill >= 0 ? [progressColor, end] : [end, progressColor],
          endAngle: fill.abs(),
          transform: GradientRotation(from),
        ).createShader(arcRect);
      }
      canvas.drawArc(arcRect, start, fill, false, paint);
      if (p(ProgressBarProps.arcHeadDot) && filled < 1) {
        final a = start + fill;
        final tip = center + Offset(math.cos(a), math.sin(a)) * radius;
        canvas.drawCircle(
          tip,
          stroke,
          Paint()
            ..color = progressColor.withValues(alpha: progressColor.a * 0.6)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, stroke),
        );
        canvas.drawCircle(tip, stroke * 0.62, Paint()..color = const Color(0xFFFFFFFF));
      }
    }

    final tickCount = p(ProgressBarProps.tickCount);
    if (tickCount > 1) {
      final tick = Paint()
        ..color = p(ProgressBarProps.tickColor).flutter
        ..strokeWidth = 2;
      for (var i = 1; i < tickCount; i++) {
        final a = start + sweep * i / tickCount;
        final d = Offset(math.cos(a), math.sin(a));
        canvas.drawLine(center + d * (radius - stroke / 2), center + d * (radius + stroke / 2), tick);
      }
    }

    final needle = p(ProgressBarProps.needleColor)?.flutter;
    if (needle != null) {
      final a = start + sweep * progress.clamp(0, 1.06);
      final d = Offset(math.cos(a), math.sin(a));
      final normal = Offset(-d.dy, d.dx);
      final half = math.max(2.0, stroke * 0.3);
      final tip = center + d * (radius + stroke * 0.2);
      final base = center + d * (radius - stroke * 1.9);
      canvas.drawPath(
        Path()
          ..moveTo(tip.dx, tip.dy)
          ..lineTo((base + normal * half).dx, (base + normal * half).dy)
          ..lineTo((base - normal * half).dx, (base - normal * half).dy)
          ..close(),
        Paint()..color = needle,
      );
    }
  }

  /// Where the arc's circle sits in a box of [size]: the largest circle
  /// whose arc fits the box, or with [ArcFit.circle] the whole circle,
  /// centered. [outer] is the room kept outside the circle's line.
  ({Offset center, double radius}) arcGeometry(Size size, {required double outer}) {
    if (p(ProgressBarProps.arcFit) == ArcFit.circle) {
      return (center: size.center(Offset.zero), radius: math.max(0, size.shortestSide / 2 - outer));
    }
    final unit = _arcBounds(_rad(p(ProgressBarProps.arcStartAngle)), _rad(p(ProgressBarProps.arcSweepAngle)));
    final radius = math.max(
      0.0,
      math.min((size.width - 2 * outer) / unit.width, (size.height - 2 * outer) / unit.height),
    );
    return (
      center: Offset(size.width / 2 - unit.center.dx * radius, size.height / 2 - unit.center.dy * radius),
      radius: radius,
    );
  }

  /// Bounds of an arc of a unit circle from [start] sweeping [sweep], with
  /// the center.
  static Rect _arcBounds(double start, double sweep) {
    final points = [Offset.zero];
    void add(double a) => points.add(Offset(math.cos(a), math.sin(a)));
    add(start);
    add(start + sweep);
    for (var k = -8; k <= 8; k++) {
      final a = k * math.pi / 2;
      final inside = sweep >= 0 ? a >= start && a <= start + sweep : a <= start && a >= start + sweep;
      if (inside) add(a);
    }
    double left = 0, top = 0, right = 0, bottom = 0;
    for (final pt in points) {
      left = math.min(left, pt.dx);
      top = math.min(top, pt.dy);
      right = math.max(right, pt.dx);
      bottom = math.max(bottom, pt.dy);
    }
    final rect = Rect.fromLTRB(left, top, right, bottom);
    return rect.width <= 0 || rect.height <= 0 ? const Rect.fromLTRB(-1, -1, 1, 1) : rect;
  }
}

// --- radial gauge ---------------------------------------------------------------

/// A radial dial: zones, segments or a value arc, ticks, labels, a target
/// notch and a needle.
class RadialGaugePainter extends NodePainter {
  RadialGaugePainter(super.n);

  double _fraction(double v) {
    final min = p(RadialGaugeProps.min), max = p(RadialGaugeProps.max);
    return max == min ? 0 : ((v - min) / (max - min)).clamp(0.0, 1.0);
  }

  /// The value arc's color: the zone [value] is in, when coloring by zone.
  Color _colorFor(double value) {
    final zones = p(RadialGaugeProps.zones);
    if (p(RadialGaugeProps.colorByZone)) {
      for (final z in zones) {
        if (value >= z.from && value < z.to) return z.color.flutter;
      }
      if (zones.isNotEmpty && value >= zones.last.to) return zones.last.color.flutter;
    }
    return p(RadialGaugeProps.valueColor).flutter;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final thickness = p(RadialGaugeProps.thickness);
    final zoneThickness = p(RadialGaugeProps.zoneThickness);
    final shortest = math.min(size.width, size.height);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.max(0.0, shortest / 2 - math.max(thickness, zoneThickness) / 2 - 8);
    if (radius <= 0) return;
    final fraction = _fraction(p(RadialGaugeProps.value));
    final start = _rad(p(RadialGaugeProps.startAngle));
    final sweep = _rad(p(RadialGaugeProps.sweepAngle));
    final rect = Rect.fromCircle(center: center, radius: radius);
    final track = p(RadialGaugeProps.trackColor).flutter;
    final min = p(RadialGaugeProps.min), max = p(RadialGaugeProps.max);
    final fill = _colorFor(min + (max - min) * fraction);
    final stroke = math.max(0.0, thickness);

    void arc(Rect bounds, double from, double length, Color color, double width, {bool round = false}) {
      if (width <= 0 || length <= 0) return;
      canvas.drawArc(
        bounds,
        from,
        length,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeCap = round ? StrokeCap.round : StrokeCap.butt
          ..color = color,
      );
    }

    final zoneOpacity = p(RadialGaugeProps.zoneOpacity);
    final zoneRadius = radius + stroke / 2 + zoneThickness / 2 + 2;
    if (zoneThickness > 0 && zoneOpacity > 0) {
      final zoneRect = Rect.fromCircle(center: center, radius: zoneRadius);
      for (final zone in p(RadialGaugeProps.zones)) {
        final from = _fraction(zone.from);
        final to = _fraction(zone.to);
        arc(zoneRect, start + sweep * from, sweep * (to - from),
            zone.color.flutter.withValues(alpha: zoneOpacity.clamp(0.0, 1.0)), zoneThickness);
      }
    }

    final segments = p(RadialGaugeProps.segments);
    if (segments > 0) {
      final segment = sweep / segments;
      final gap = math.max(0.0, _rad(p(RadialGaugeProps.segmentGap)));
      final lit = (fraction * segments).round();
      for (var i = 0; i < segments; i++) {
        arc(rect, start + segment * i + gap / 2, math.max(0.0, segment - gap), i < lit ? fill : track, stroke);
      }
    } else {
      arc(rect, start, sweep, track, stroke);
      arc(rect, start, sweep * fraction, fill, stroke, round: p(RadialGaugeProps.roundCaps));
    }

    Offset at(double r, double angle) => center + Offset(math.cos(angle), math.sin(angle)) * r;
    final intervals = p(RadialGaugeProps.majorTicks);
    final minorTicks = p(RadialGaugeProps.minorTicks);
    if (intervals > 0) {
      final steps = intervals * (math.max(0, minorTicks) + 1);
      for (var i = 0; i <= steps; i++) {
        final angle = start + sweep * i / steps;
        final major = i % (minorTicks + 1) == 0;
        canvas.drawLine(
          at(radius - stroke / 2 - 3, angle),
          at(radius - stroke / 2 - (major ? 15 : 9), angle),
          Paint()
            ..color = p(RadialGaugeProps.tickColor).flutter
            ..strokeWidth = major ? 2 : 1,
        );
      }
    }

    final labelFontSize = p(RadialGaugeProps.labelFontSize);
    if (labelFontSize > 0) {
      for (final label in p(RadialGaugeProps.labels)) {
        final painter = TextPainter(
          text: TextSpan(
            text: _numberText(label),
            style: TextStyle(
              color: p(RadialGaugeProps.labelColor).flutter,
              fontSize: labelFontSize,
              fontFamily: p(RadialGaugeProps.labelFontFamily),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final position = at(math.max(0, radius - stroke / 2 - 27), start + sweep * _fraction(label));
        painter.paint(canvas, position - Offset(painter.width / 2, painter.height / 2));
        painter.dispose();
      }
    }

    if (p(RadialGaugeProps.showTarget)) {
      final angle = start + sweep * _fraction(p(RadialGaugeProps.target));
      canvas.drawLine(
        at(radius + stroke / 2 + 2, angle),
        at(radius + stroke / 2 + 11, angle),
        Paint()
          ..color = p(RadialGaugeProps.targetColor).flutter
          ..strokeWidth = 3,
      );
    }
    if (p(RadialGaugeProps.showNeedle)) {
      final angle = start + sweep * fraction;
      final clearance = p(RadialGaugeProps.needleClearance).clamp(0.0, 1.0);
      canvas.drawLine(
        at(radius * clearance, angle),
        at(radius - stroke / 2 - 2, angle),
        Paint()
          ..color = p(RadialGaugeProps.needleColor).flutter
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
    }
  }
}

/// A number printed as a double label (`60.0`).
String _numberText(double v) => v.toString();

// --- gauge meter ----------------------------------------------------------------

/// A meter filled to its value: an arc (dial) or a bar (tank level, LED
/// meter), with ticks and a limit marker.
class GaugeMeterPainter extends NodePainter {
  GaugeMeterPainter(super.n);

  double _fraction(double v) {
    final min = p(GaugeMeterProps.min), max = p(GaugeMeterProps.max);
    final range = max - min;
    return range == 0 ? 0 : ((v - min) / range).clamp(0.0, 1.0);
  }

  double get fraction => _fraction(p(GaugeMeterProps.value));
  double? get limit => switch (p(GaugeMeterProps.limit)) { final double l => _fraction(l), null => null };
  Color get color => p(GaugeMeterProps.color).flutter;
  Color get limitColor => p(GaugeMeterProps.limitColor).flutter;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    switch (p(GaugeMeterProps.shape)) {
      case GaugeShape.arc:
        _paintArc(canvas, size);
      case GaugeShape.bar:
        _paintBar(canvas, size);
    }
  }

  void _paintArc(Canvas canvas, Size size) {
    final d = math.min(size.width, size.height * 2);
    final thickness = p(GaugeMeterProps.thickness);
    final stroke = thickness > 0 ? thickness : d * 0.075;
    final center = Offset(size.width / 2, d / 2);
    final r = d / 2 - stroke / 2 - d * 0.04;
    final rect = Rect.fromCircle(center: center, radius: r);
    final start = _rad(p(GaugeMeterProps.startAngle));
    final sweep = _rad(p(GaugeMeterProps.sweepAngle));
    final track = p(GaugeMeterProps.trackColor).flutter;
    final fraction = this.fraction;

    final segments = p(GaugeMeterProps.segments);
    if (segments > 0) {
      final seg = sweep / segments;
      final gap = _rad(p(GaugeMeterProps.segmentGap));
      final lit = (fraction * segments).round();
      for (var i = 0; i < segments; i++) {
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
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke;
      canvas.drawArc(rect, start, sweep, false, paint..color = track);
      if (fraction > 0) canvas.drawArc(rect, start, sweep * fraction, false, paint..color = color);
    }

    final ticks = p(GaugeMeterProps.ticks);
    final majorEvery = p(GaugeMeterProps.majorTickEvery);
    if (ticks > 0) {
      final tick = Paint()..color = p(GaugeMeterProps.tickColor).flutter;
      for (var i = 0; i <= ticks; i++) {
        final a = start + sweep * i / ticks;
        final major = majorEvery > 0 && i % majorEvery == 0;
        final r1 = r - stroke / 2 - d * 0.03;
        final r2 = r1 - (major ? d * 0.05 : d * 0.025);
        final dir = Offset(math.cos(a), math.sin(a));
        tick.strokeWidth = major ? 2 : 1;
        canvas.drawLine(center + dir * r1, center + dir * r2, tick);
      }
    }

    final limit = this.limit;
    if (limit != null) {
      final a = start + sweep * limit;
      final dir = Offset(math.cos(a), math.sin(a));
      final outer = r + stroke / 2 + d * 0.035;
      final inner = r - stroke / 2 - d * 0.005;
      canvas.drawLine(
        center + dir * inner,
        center + dir * outer,
        Paint()
          ..color = limitColor
          ..strokeWidth = p(GaugeMeterProps.limitWidth)
          ..strokeCap = StrokeCap.square,
      );
    }
  }

  void _paintBar(Canvas canvas, Size size) {
    final vertical = size.height > size.width;
    final cornerRadius = p(GaugeMeterProps.cornerRadius);
    final radius = Radius.circular(cornerRadius);
    final well = RRect.fromRectAndRadius(Offset.zero & size, radius);
    final background = p(GaugeMeterProps.backgroundColor).flutter;
    if (background.a > 0) canvas.drawRRect(well, Paint()..color = background);

    final inset = p(GaugeMeterProps.inset);
    final inner = Rect.fromLTRB(inset, inset, size.width - inset, size.height - inset);
    final length = vertical ? inner.height : inner.width;
    final track = p(GaugeMeterProps.trackColor).flutter;
    final fraction = this.fraction;

    Rect span(double from, double to) => vertical
        ? Rect.fromLTRB(inner.left, inner.bottom - length * to, inner.right, inner.bottom - length * from)
        : Rect.fromLTRB(inner.left + length * from, inner.top, inner.left + length * to, inner.bottom);

    Paint fillPaint(Rect rect) {
      final paint = Paint()..color = color;
      final startOpacity = p(GaugeMeterProps.fillStartOpacity);
      if (startOpacity < 1) {
        final faded = color.withValues(alpha: color.a * startOpacity);
        paint.shader = LinearGradient(
          begin: vertical ? Alignment.topCenter : Alignment.centerRight,
          end: vertical ? Alignment.bottomCenter : Alignment.centerLeft,
          colors: [color, faded],
        ).createShader(rect);
      }
      return paint;
    }

    final segments = p(GaugeMeterProps.segments);
    if (segments > 0) {
      final gap = p(GaugeMeterProps.segmentGap);
      final seg = (length - gap * (segments - 1)) / segments;
      final lit = (fraction * segments).round();
      final segRadius = Radius.circular(math.min(cornerRadius, seg / 2));
      for (var i = 0; i < segments; i++) {
        final from = (i * (seg + gap)) / length;
        final to = (i * (seg + gap) + seg) / length;
        canvas.drawRRect(RRect.fromRectAndRadius(span(from, to), segRadius), Paint()..color = i < lit ? color : track);
      }
    } else {
      if (track.a > 0) canvas.drawRRect(RRect.fromRectAndRadius(inner, radius), Paint()..color = track);
      if (fraction > 0) {
        final fill = span(0, fraction);
        canvas.drawRect(fill, fillPaint(fill));
        final edgeWidth = p(GaugeMeterProps.edgeWidth);
        if (edgeWidth > 0) {
          final edge = vertical
              ? Rect.fromLTWH(fill.left, fill.top, fill.width, edgeWidth)
              : Rect.fromLTWH(fill.right - edgeWidth, fill.top, edgeWidth, fill.height);
          canvas.drawRect(edge, Paint()..color = p(GaugeMeterProps.edgeColor).flutter);
        }
      }
    }

    // Graduations: full width at major ticks, 35% in from each side at minor.
    final ticks = p(GaugeMeterProps.ticks);
    final majorEvery = p(GaugeMeterProps.majorTickEvery);
    if (ticks > 1) {
      final tick = Paint()
        ..color = p(GaugeMeterProps.tickColor).flutter
        ..strokeWidth = 1;
      final across = vertical ? inner.width : inner.height;
      for (var i = 1; i < ticks; i++) {
        final major = majorEvery > 0 && i % majorEvery == 0;
        final w = major ? across : across * 0.35;
        final at = length * i / ticks;
        if (vertical) {
          final y = inner.bottom - at;
          canvas.drawLine(Offset(inner.left, y), Offset(inner.left + w, y), tick);
          canvas.drawLine(Offset(inner.right - w, y), Offset(inner.right, y), tick);
        } else {
          final x = inner.left + at;
          canvas.drawLine(Offset(x, inner.top), Offset(x, inner.top + w), tick);
          canvas.drawLine(Offset(x, inner.bottom - w), Offset(x, inner.bottom), tick);
        }
      }
    }

    final limit = this.limit;
    if (limit != null) {
      final paint = Paint()
        ..color = limitColor
        ..strokeWidth = p(GaugeMeterProps.limitWidth);
      final at = length * limit;
      final a = vertical ? Offset(inner.left, inner.bottom - at) : Offset(inner.left + at, inner.top);
      final b = vertical ? Offset(inner.right, inner.bottom - at) : Offset(inner.left + at, inner.bottom);
      if (p(GaugeMeterProps.limitStyle) == GaugeLimitStyle.dashed) {
        const dash = 5.0;
        final total = (b - a).distance;
        final dir = (b - a) / total;
        for (double t = 0; t < total; t += dash * 2) {
          canvas.drawLine(a + dir * t, a + dir * math.min(t + dash, total), paint);
        }
      } else {
        canvas.drawLine(a, b, paint);
      }
      if (p(GaugeMeterProps.limitPointer)) {
        final tri = vertical
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

    final border = p(GaugeMeterProps.borderColor).flutter;
    if (border.a > 0) {
      canvas.drawRRect(
        well.deflate(0.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..color = border,
      );
    }
  }
}

// --- bar chart ------------------------------------------------------------------

/// A bar chart: the bars in equal
/// columns over a baseline, grid lines with labels in a right gutter, and a
/// row of labels under the baseline.
class BarChartPainter extends NodePainter {
  BarChartPainter(super.n) : super(repaint: PaintingBinding.instance.systemFonts);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final values = p(BarChartProps.values);
    final labels = p(BarChartProps.labels);
    final highlight = p(BarChartProps.highlight);
    final color = p(BarChartProps.color).flutter;
    final palette = p(BarChartProps.colors);
    var max = p(BarChartProps.max);
    if (max <= 0) max = values.whereType<double>().fold(0, (a, b) => b > a ? b : a);
    final hasLabels = labels.any((l) => l.isNotEmpty);
    final gridLabels = p(BarChartProps.gridLabels);
    final gridLabelWidth = p(BarChartProps.gridLabelWidth);
    final labelsLeft = p(BarChartProps.gridLabelsLeft);
    final right = gridLabels.isNotEmpty && !labelsLeft ? gridLabelWidth : 0.0;
    // With the grid labels on the left, the plot starts after them.
    final plotLeft = gridLabels.isNotEmpty && labelsLeft ? gridLabelWidth : 0.0;
    final fontSize = p(BarChartProps.labelFontSize);
    final labelGap = p(BarChartProps.labelGap);
    final style = textStyle(api.TextStyle(
      fontFamily: p(BarChartProps.labelFontFamily),
      fontWeight: p(BarChartProps.labelFontWeight),
      fontSize: fontSize,
      color: p(BarChartProps.labelColor),
    )).copyWith(height: 1.2);
    final gridStyle = textStyle(api.TextStyle(
      fontFamily: p(BarChartProps.labelFontFamily),
      fontWeight: p(BarChartProps.gridLabelFontWeight) ?? p(BarChartProps.labelFontWeight),
      fontSize: p(BarChartProps.gridLabelFontSize) ?? fontSize,
      color: p(BarChartProps.gridLabelColor) ?? p(BarChartProps.labelColor),
    )).copyWith(height: 1);
    final gridFontSize = p(BarChartProps.gridLabelFontSize) ?? fontSize;
    final labelHeight = hasLabels ? fontSize * 1.2 + labelGap : 0.0;
    final showValues = p(BarChartProps.showValues);
    // Room above the tallest bar for its value.
    final valueRoom = showValues ? fontSize * 1.2 + 4 : 0.0;
    final height = math.max(0.0, size.height - labelHeight - 1);
    final plotHeight = math.max(0.0, height - valueRoom);
    final width = math.max(0.0, size.width - right - plotLeft);
    canvas.save();
    canvas.translate(plotLeft, 0);

    // Grid lines and their labels.
    final gridLines = p(BarChartProps.gridLines);
    final gridPaint = Paint()..color = p(BarChartProps.gridColor).flutter;
    // One label more than the grid lines labels the baseline first.
    final labelsBaseline = gridLabels.length > gridLines;
    for (var g = labelsBaseline ? 0 : 1; g <= gridLines; g++) {
      final bottom = plotHeight * g / gridLines - 0.5;
      if (g > 0) canvas.drawRect(Rect.fromLTWH(0, height - bottom - 1, width, 1), gridPaint);
      final at = labelsBaseline ? g : g - 1;
      if (gridLabels.isNotEmpty && at < gridLabels.length) {
        final tp = TextPainter(
          text: TextSpan(text: gridLabels[at], style: gridStyle),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout(maxWidth: math.max(0, gridLabelWidth - 6));
        final labelBottom = plotHeight * g / gridLines - gridFontSize / 2;
        tp.paint(canvas, Offset(labelsLeft ? -plotLeft : size.width - plotLeft - (gridLabelWidth - 6), height - labelBottom - tp.height));
        tp.dispose();
      }
    }

    // Bars, in equal columns with gaps between.
    final barGap = p(BarChartProps.barGap);
    final count = values.length;
    final column = count == 0 ? 0.0 : math.max(0.0, (width - barGap * (count - 1)) / count);
    final emptyHeight = p(BarChartProps.emptyHeight);
    final barRadius = Radius.circular(p(BarChartProps.barRadius));
    final dimmed = p(BarChartProps.dimmedOpacity);
    final maxBar = p(BarChartProps.maxBarWidth);
    final bar = maxBar == null ? column : math.min(column, maxBar);
    for (var i = 0; i < count; i++) {
      final left = i * (column + barGap) + (column - bar) / 2;
      final value = values[i];
      if (value == null) {
        canvas.drawRect(Rect.fromLTWH(left, height - emptyHeight, bar, emptyHeight),
            Paint()..color = p(BarChartProps.emptyColor).flutter);
        continue;
      }
      final h = max <= 0 ? 0.0 : (plotHeight * (value / max).clamp(0.0, 1.0)).clamp(emptyHeight, height).toDouble();
      final baseColor = i < palette.length ? palette[i].flutter : color;
      final barColor = highlight == null || highlight < 0 || i == highlight
          ? baseColor
          : baseColor.withValues(alpha: baseColor.a * dimmed);
      canvas.drawRRect(
        RRect.fromRectAndCorners(Rect.fromLTWH(left, height - h, bar, h), topLeft: barRadius, topRight: barRadius),
        Paint()..color = barColor,
      );
      if (showValues) {
        final text = barValueText(value, p(BarChartProps.valueDecimals), p(BarChartProps.valueSuffix));
        final tp = TextPainter(
          text: TextSpan(
            text: text,
            style: style.copyWith(
                fontWeight: FontWeight.w600,
                color: i == highlight ? p(BarChartProps.highlightLabelColor).flutter : null),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout();
        tp.paint(canvas, Offset(left + (bar - tp.width) / 2, height - h - tp.height - 2));
        tp.dispose();
      }
    }

    // Baseline.
    canvas.drawRect(Rect.fromLTWH(0, height, width, 1), Paint()..color = p(BarChartProps.baselineColor).flutter);

    // Labels under the bars.
    if (hasLabels) {
      final top = height + 1 + labelGap;
      for (var i = 0; i < count; i++) {
        final text = i < labels.length ? labels[i] : '';
        if (text.isEmpty) continue;
        final spacing = p(BarChartProps.labelLetterSpacing);
        final labelStyle = spacing == 0 ? style : style.copyWith(letterSpacing: spacing);
        final tp = TextPainter(
          text: TextSpan(
            text: text,
            style: i == highlight && p(BarChartProps.highlightLabels)
                ? labelStyle.copyWith(color: p(BarChartProps.highlightLabelColor).flutter)
                : labelStyle,
          ),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
          maxLines: 1,
        )..layout();
        final left = i * (column + barGap);
        tp.paint(canvas, Offset(left + (column - tp.width) / 2, top));
        tp.dispose();
      }
    }
    canvas.restore();
  }
}

/// A bar chart's value label: [decimals] places (null: whole numbers
/// bare, others with one), then [suffix].
@visibleForTesting
String barValueText(double value, int? decimals, String suffix) {
  final number = decimals != null
      ? value.toStringAsFixed(decimals.clamp(0, 6))
      : value == value.roundToDouble() ? value.round().toString() : value.toStringAsFixed(1);
  return number + suffix;
}

// --- barcode --------------------------------------------------------------------

/// A barcode of the node's data: square-module codes (QR, Aztec, Data
/// Matrix) keep their aspect and are centered; PDF417 and 1D codes stretch to
/// fill the box. Data the symbology can't encode paints a placeholder.
class BarcodePainter extends NodePainter {
  BarcodePainter(super.n);

  String get data => p(BarcodeProps.data);
  BarcodeSymbology get symbology => p(BarcodeProps.symbology);
  Color get color => p(BarcodeProps.color).flutter;

  static bc.Barcode barcodeFor(BarcodeSymbology symbology, BarcodeErrorCorrection correction) => switch (symbology) {
        BarcodeSymbology.qrCode => bc.Barcode.qrCode(
            errorCorrectLevel: switch (correction) {
              BarcodeErrorCorrection.low => bc.BarcodeQRCorrectionLevel.low,
              BarcodeErrorCorrection.medium => bc.BarcodeQRCorrectionLevel.medium,
              BarcodeErrorCorrection.quartile => bc.BarcodeQRCorrectionLevel.quartile,
              BarcodeErrorCorrection.high => bc.BarcodeQRCorrectionLevel.high,
            },
          ),
        BarcodeSymbology.pdf417 => bc.Barcode.pdf417(),
        BarcodeSymbology.code128 => bc.Barcode.code128(),
        BarcodeSymbology.aztec => bc.Barcode.aztec(),
        BarcodeSymbology.dataMatrix => bc.Barcode.dataMatrix(),
        BarcodeSymbology.ean13 => bc.Barcode.ean13(),
      };

  late final bc.Barcode _barcode = barcodeFor(symbology, p(BarcodeProps.errorCorrection));
  late final bool _encodable = data.isNotEmpty && _barcode.isValid(data);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final background = p(BarcodeProps.backgroundColor)?.flutter;
    if (background != null) canvas.drawRect(Offset.zero & size, Paint()..color = background);
    final painted = symbology.is2D ? _paint2D(canvas, size) : _paint1D(canvas, size);
    if (!painted) _paintPlaceholder(canvas, size);
  }

  bool _paint2D(Canvas canvas, Size size) {
    if (!_encodable) return false;
    final List<bc.BarcodeBar> bars;
    try {
      bars = _barcode
          .make(data, width: size.width, height: symbology.hasSquareModules ? size.height : 1e6)
          .whereType<bc.BarcodeBar>()
          .toList();
    } catch (_) {
      return false;
    }
    if (bars.isEmpty) return false;
    double top = 0, scaleY = 1;
    if (!symbology.hasSquareModules) {
      top = bars.map((bar) => bar.top).reduce(math.min);
      final bottom = bars.map((bar) => bar.bottom).reduce(math.max);
      if (bottom <= top) return false;
      scaleY = size.height / (bottom - top);
    }
    // One path for every dark run: no anti-aliasing seams between modules.
    final path = Path();
    for (final bar in bars) {
      if (!bar.black) continue;
      path.addRect(Rect.fromLTWH(bar.left, (bar.top - top) * scaleY, bar.width, bar.height * scaleY));
    }
    canvas.drawPath(path, Paint()..color = color);
    return true;
  }

  bool _paint1D(Canvas canvas, Size size) {
    if (!_encodable) return false;
    final withText = p(BarcodeProps.drawText) && size.height >= 24;
    final fontHeight = withText ? (size.height * 0.2).clamp(8.0, 20.0) : 0.0;
    final List<bc.BarcodeElement> elements;
    try {
      elements = _barcode
          .make(data, width: size.width, height: size.height, drawText: withText, fontHeight: withText ? fontHeight : null)
          .toList();
    } catch (_) {
      return false;
    }
    final path = Path();
    for (final element in elements) {
      if (element is bc.BarcodeBar && element.black) {
        path.addRect(Rect.fromLTWH(element.left, element.top, element.width, element.height));
      }
    }
    canvas.drawPath(path, Paint()..color = color);
    for (final element in elements) {
      if (element is bc.BarcodeText) _paintText(canvas, element, fontHeight);
    }
    return true;
  }

  void _paintText(Canvas canvas, bc.BarcodeText element, double fontHeight) {
    final painter = TextPainter(
      text: TextSpan(text: element.text, style: TextStyle(color: color, fontSize: fontHeight, height: 1)),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    // Text wider than its zone (long Code 128 data) shrinks to fit.
    final scale = painter.width > element.width && painter.width > 0 ? element.width / painter.width : 1.0;
    final width = painter.width * scale;
    final height = painter.height * scale;
    final left = switch (element.align) {
      bc.BarcodeTextAlign.left => element.left,
      bc.BarcodeTextAlign.center => element.left + (element.width - width) / 2,
      bc.BarcodeTextAlign.right => element.left + element.width - width,
    };
    final top = element.top + (element.height - height) / 2;
    canvas.save();
    canvas.translate(left, top);
    canvas.scale(scale);
    painter.paint(canvas, Offset.zero);
    canvas.restore();
    painter.dispose();
  }

  /// A light outlined box with a cross: where the code would be.
  void _paintPlaceholder(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(0.5);
    canvas.drawRect(rect, Paint()..color = color.withValues(alpha: 0.06));
    final stroke = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRect(rect, stroke);
    canvas.drawLine(rect.topLeft, rect.bottomRight, stroke);
    canvas.drawLine(rect.topRight, rect.bottomLeft, stroke);
  }
}
