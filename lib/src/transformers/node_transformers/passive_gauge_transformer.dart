import 'dart:math' as math;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../codelessly_sdk.dart';

class PassiveGaugeTransformer extends NodeWidgetTransformer<GaugeNode> {
  PassiveGaugeTransformer(super.getNode, super.manager);

  @override
  Widget buildWidget(
    GaugeNode node,
    BuildContext context,
    WidgetBuildSettings settings,
  ) => PassiveGaugeWidget(node: node, settings: settings);
}

/// Renders a [GaugeNode]: resolves the bound value and paints the dial,
/// animating value changes when the node asks for it.
class PassiveGaugeWidget extends StatelessWidget {
  final GaugeNode node;
  final WidgetBuildSettings settings;
  final List<VariableData> variablesOverrides;

  /// Overrides [GaugeProperties.animate], e.g. off on the editor canvas.
  final bool? animate;

  const PassiveGaugeWidget({
    super.key,
    required this.node,
    required this.settings,
    this.variablesOverrides = const [],
    this.animate,
  });

  void onTap(BuildContext context) =>
      FunctionsRepository.triggerAction(context, node: node, TriggerType.click);

  @override
  Widget build(BuildContext context) {
    final ScopedValues scopedValues = ScopedValues.of(
      context,
      variablesOverrides: variablesOverrides,
    );
    final double value =
        PropertyValueDelegate.getPropertyValue<double>(
          node,
          'value',
          scopedValues: scopedValues,
        ) ??
        node.value;
    final GaugeProperties props = node.properties;
    final bool shouldAnimate = animate ?? props.animate;

    Widget dial = TweenAnimationBuilder<double>(
      tween: Tween(end: value),
      duration: shouldAnimate
          ? Duration(milliseconds: props.animationDurationInMillis)
          : Duration.zero,
      curve: Curves.easeOutCubic,
      builder: (context, animated, _) => CustomPaint(
        painter: GaugePainter(props: props, value: animated),
        child: const SizedBox.expand(),
      ),
    );
    if (node.reactions.isNotEmpty && !settings.isPreview) {
      dial = MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(onTap: () => onTap(context), child: dial),
      );
    }
    return AdaptiveNodeBox(node: node, child: dial);
  }
}

/// A text style for chart and gauge labels in [family] (a Google Font when
/// it is one).
TextStyle chartLabelStyle({
  required String? family,
  required double size,
  required Color color,
  FontWeight weight = FontWeight.w500,
}) {
  if (family != null && GoogleFonts.asMap().containsKey(family)) {
    return GoogleFonts.getFont(
      family,
      fontSize: size,
      color: color,
      fontWeight: weight,
    );
  }
  return TextStyle(
    fontFamily: family,
    fontSize: size,
    color: color,
    fontWeight: weight,
  );
}

/// Paints a [GaugeProperties] dial at [value]. The dial is centered
/// horizontally and sized so the whole arc fits the box.
class GaugePainter extends CustomPainter {
  GaugePainter({required this.props, required this.value})
    // Repaint when a Google Font used by the labels finishes loading.
    : super(repaint: PaintingBinding.instance.systemFonts);

  final GaugeProperties props;
  final double value;

  static double _rad(double deg) => deg * math.pi / 180;

  /// The arc's radius and center for [size]: the largest circle whose arc
  /// (with zone bands and notch) fits, centered horizontally and placed at
  /// the top.
  ({double radius, Offset center}) layout(Size size) {
    final double start = _rad(props.startAngle);
    final double sweep = _rad(props.sweepAngle);
    // Bounds of the unit arc, sampled.
    double minX = 0, maxX = 0, minY = 0, maxY = 0;
    for (int i = 0; i <= 64; i++) {
      final double a = start + sweep * i / 64;
      minX = math.min(minX, math.cos(a));
      maxX = math.max(maxX, math.cos(a));
      minY = math.min(minY, math.sin(a));
      maxY = math.max(maxY, math.sin(a));
    }
    // The hub is always inside.
    final double unitW = maxX - minX, unitH = maxY - minY;
    final double radius = math.max(
      1,
      math.min(size.width / unitW, size.height / unitH),
    );
    // Centered horizontally, at the top, so readouts placed over the dial
    // line up whatever the box's height.
    final double usedW = unitW * radius;
    final Offset center = Offset(
      (size.width - usedW) / 2 - minX * radius,
      -minY * radius,
    );
    return (radius: radius, center: center);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final (:radius, :center) = layout(size);
    final double start = _rad(props.startAngle);
    final double sweep = _rad(props.sweepAngle);
    double angleOf(double v) => start + sweep * props.fraction(v);

    final double zoneW = props.zoneThickness;
    final double outer = radius - 1;
    final double arcR = outer - zoneW - 2 - props.thickness / 2;

    // Zone bands.
    if (zoneW > 0) {
      for (final GaugeZone zone in props.zones) {
        final double a0 = angleOf(zone.from), a1 = angleOf(zone.to);
        if (a1 <= a0) continue;
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: outer - zoneW / 2),
          a0 + 0.01,
          a1 - a0 - 0.02,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = zoneW
            ..color = zone.color.toFlutterColor().withValues(
              alpha: props.zoneOpacity,
            ),
        );
      }
    }

    // Track with hairlines on both sides.
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: arcR),
      start,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = props.thickness * 1.25
        ..color = props.trackColor.toFlutterColor(),
    );
    final Paint hairline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = props.tickColor.toFlutterColor().withValues(alpha: 0.18);
    for (final double r in [
      arcR + props.thickness * 0.625,
      arcR - props.thickness * 0.625,
    ]) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r),
        start,
        sweep,
        false,
        hairline,
      );
    }

    // Value arc.
    final double fraction = props.fraction(value);
    final Paint valuePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = props.thickness
      ..color = props.colorFor(value).toFlutterColor();
    if (props.segments <= 0) {
      if (fraction > 0) {
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: arcR),
          start,
          sweep * fraction,
          false,
          valuePaint,
        );
      }
    } else {
      final double block = sweep / props.segments;
      final double gap = math.min(_rad(props.segmentGap), block * 0.5);
      final double filled = fraction * props.segments;
      for (int i = 0; i < props.segments; i++) {
        final double part = (filled - i).clamp(0.0, 1.0);
        if (part <= 0) break;
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: arcR),
          start + block * i + gap / 2,
          (block - gap) * part,
          false,
          valuePaint,
        );
      }
    }

    // Ticks.
    if (props.majorTicks > 0) {
      final int perMajor = math.max(0, props.minorTicks) + 1;
      final int count = props.majorTicks * perMajor;
      final Color tickColor = props.tickColor.toFlutterColor();
      for (int i = 0; i <= count; i++) {
        final bool major = i % perMajor == 0;
        final double a = start + sweep * i / count;
        final Offset dir = Offset(math.cos(a), math.sin(a));
        final double inner = arcR - props.thickness * (major ? 1.35 : 1.0);
        final double outerTick = arcR - props.thickness * 0.72;
        canvas.drawLine(
          center + dir * inner,
          center + dir * outerTick,
          Paint()
            ..color = major ? tickColor : tickColor.withValues(alpha: 0.45)
            ..strokeWidth = major ? 1.5 : 1,
        );
      }
    }

    // Labels.
    if (props.labels.isNotEmpty) {
      final TextStyle style = chartLabelStyle(
        family: props.labelFontFamily,
        size: props.labelFontSize,
        color: props.labelColor.toFlutterColor(),
      );
      for (final double v in props.labels) {
        final double a = angleOf(v);
        final Offset p =
            center +
            Offset(math.cos(a), math.sin(a)) *
                (arcR - props.thickness * 1.35 - props.labelFontSize);
        final TextPainter tp = TextPainter(
          text: TextSpan(text: _label(v), style: style),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
      }
    }

    // Target notch.
    if (props.showTarget) {
      final double a = angleOf(props.target);
      final Offset dir = Offset(math.cos(a), math.sin(a));
      final Offset perp = Offset(-dir.dy, dir.dx) * (zoneW + 3) * 0.75;
      final Offset tip = center + dir * (outer + 1);
      final Offset base = center + dir * (arcR + props.thickness * 0.4);
      canvas.drawPath(
        Path()
          ..moveTo(base.dx, base.dy)
          ..lineTo(tip.dx + perp.dx, tip.dy + perp.dy)
          ..lineTo(tip.dx - perp.dx, tip.dy - perp.dy)
          ..close(),
        Paint()..color = props.targetColor.toFlutterColor(),
      );
    }

    // Needle.
    if (props.showNeedle) {
      final double a = start + sweep * fraction;
      final Offset dir = Offset(math.cos(a), math.sin(a));
      final double hub = radius * 0.07;
      final Offset side = Offset(-dir.dy, dir.dx) * hub * 0.45;
      final Offset tail = center - dir * hub * 1.4;
      final Offset tip = center + dir * (arcR - props.thickness * 0.2);
      final Path needle = Path()
        ..moveTo(tail.dx + side.dx, tail.dy + side.dy)
        ..lineTo(tip.dx, tip.dy)
        ..lineTo(tail.dx - side.dx, tail.dy - side.dy)
        ..close();
      canvas.save();
      if (props.needleClearance > 0) {
        canvas.clipPath(
          Path()
            ..fillType = PathFillType.evenOdd
            ..addRect(Offset.zero & size)
            ..addOval(
              Rect.fromCircle(
                center: center,
                radius: radius * props.needleClearance,
              ),
            ),
        );
      }
      canvas.drawPath(
        needle,
        Paint()..color = props.needleColor.toFlutterColor(),
      );
      canvas.restore();
    }
  }

  static String _label(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  @override
  bool shouldRepaint(GaugePainter oldDelegate) =>
      oldDelegate.value != value || oldDelegate.props != props;
}
