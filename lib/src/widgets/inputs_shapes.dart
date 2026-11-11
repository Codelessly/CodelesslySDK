// Painters of the input widgets: the slider's thumbs, track and notches
// beyond Flutter's own shapes, and the signature pad's ink.
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Paints a soft, blurred glow of [color] behind another [thumb] shape, like
/// a lit knob: the thumb's outline grown by [spread] and blurred by [blur].
class GlowSliderThumbShape extends SliderComponentShape {
  const GlowSliderThumbShape({
    required this.thumb,
    required this.color,
    this.blur = 8,
    this.spread = 6,
    this.cornerRadius,
  });

  final SliderComponentShape thumb;
  final Color color;
  final double blur;
  final double spread;

  /// Null: a round thumb.
  final double? cornerRadius;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => thumb.getPreferredSize(isEnabled, isDiscrete);

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
    final size = thumb.getPreferredSize(true, isDiscrete);
    if (!size.isEmpty) {
      final paint = Paint()..color = color;
      if (blur > 0) paint.maskFilter = MaskFilter.blur(BlurStyle.normal, blur);
      final grow = math.max(0.0, spread);
      if (cornerRadius == null) {
        context.canvas.drawCircle(center, size.shortestSide / 2 + grow, paint);
      } else {
        final rect = Rect.fromCenter(center: center, width: size.width + grow * 2, height: size.height + grow * 2);
        final radius = math.min(math.max(0.0, cornerRadius!) + grow, rect.shortestSide / 2);
        context.canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)), paint);
      }
    }
    thumb.paint(context, center,
        activationAnimation: activationAnimation,
        enableAnimation: enableAnimation,
        isDiscrete: isDiscrete,
        labelPainter: labelPainter,
        parentBox: parentBox,
        sliderTheme: sliderTheme,
        textDirection: textDirection,
        value: value,
        textScaleFactor: textScaleFactor,
        sizeWithOverflow: sizeWithOverflow);
  }
}

/// A round thumb with an optional ring of [strokeColor].
class StrokedSliderThumbShape extends RoundSliderThumbShape {
  const StrokedSliderThumbShape({super.enabledThumbRadius, this.strokeColor, this.strokeWidth = 0});

  final Color? strokeColor;
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
    super.paint(context, center,
        activationAnimation: activationAnimation,
        enableAnimation: enableAnimation,
        isDiscrete: isDiscrete,
        labelPainter: labelPainter,
        parentBox: parentBox,
        sliderTheme: sliderTheme,
        textDirection: textDirection,
        value: value,
        textScaleFactor: textScaleFactor,
        sizeWithOverflow: sizeWithOverflow);
    final color = strokeColor;
    if (color == null || strokeWidth <= 0 || enabledThumbRadius <= 0) return;
    final width = math.min(strokeWidth, enabledThumbRadius);
    context.canvas.drawCircle(
        center,
        enabledThumbRadius - width / 2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..color = color);
  }
}

/// A rounded-rectangle thumb with a shadow and an optional stroke.
class RoundedRectSliderThumbShape extends SliderComponentShape {
  const RoundedRectSliderThumbShape({required this.size, this.cornerRadius = 0, this.strokeColor, this.strokeWidth = 0});

  final Size size;
  final double cornerRadius;
  final Color? strokeColor;
  final double strokeWidth;

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
    final canvas = context.canvas;
    final color = ColorTween(begin: sliderTheme.disabledThumbColor, end: sliderTheme.thumbColor).evaluate(enableAnimation)!;
    final radius = math.max(0.0, math.min(cornerRadius, size.shortestSide / 2));
    final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: size.width, height: size.height), Radius.circular(radius));
    final shadow = Tween<double>(begin: 1, end: 6).evaluate(activationAnimation);
    if (shadow > 0 && !debugDisableShadows) {
      canvas.drawShadow(Path()..addRRect(rect), Colors.black, shadow, true);
    }
    canvas.drawRRect(rect, Paint()..color = color);
    final stroke = strokeColor;
    if (stroke == null || strokeWidth <= 0) return;
    final width = math.min(strokeWidth, size.shortestSide / 2);
    canvas.drawRRect(
        rect.deflate(width / 2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..color = stroke);
  }
}

/// A rectangular thumb with an optional border and a grip line.
class RectSliderThumbShape extends SliderComponentShape {
  const RectSliderThumbShape({
    required this.width,
    required this.height,
    required this.radius,
    required this.borderColor,
    required this.borderWidth,
    required this.gripColor,
  });

  final double width, height, radius;
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
    final canvas = context.canvas;
    final body = RRect.fromRectAndRadius(Rect.fromCenter(center: center, width: width, height: height), Radius.circular(radius));
    canvas.drawRRect(body, Paint()..color = sliderTheme.thumbColor!);
    if (borderColor.a > 0 && borderWidth > 0) {
      canvas.drawRRect(
          body.deflate(borderWidth / 2),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = borderWidth
            ..color = borderColor);
    }
    if (gripColor.a > 0) {
      canvas.drawRect(Rect.fromCenter(center: center, width: width * 0.43, height: 2), Paint()..color = gripColor);
    }
  }
}

/// A track that can fill from the end, fade its active part in and draw a
/// marker across itself.
class MarkedSliderTrackShape extends SliderTrackShape with BaseSliderTrackShape {
  const MarkedSliderTrackShape({
    required this.fillFromEnd,
    this.activeStartOpacity = 1,
    required this.markerFraction,
    required this.markerColor,
    required this.markerWidth,
    required this.markerHeight,
    required this.radius,
  });

  final bool fillFromEnd;
  final double activeStartOpacity;
  final double? markerFraction;
  final Color markerColor;
  final double markerWidth, markerHeight, radius;

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
    final track = getPreferredRect(
        parentBox: parentBox, offset: offset, sliderTheme: sliderTheme, isEnabled: isEnabled, isDiscrete: isDiscrete);
    final canvas = context.canvas;
    final r = Radius.circular(radius);
    canvas.drawRRect(RRect.fromRectAndRadius(track, r), Paint()..color = sliderTheme.inactiveTrackColor ?? Colors.grey);
    final activeOnRight = fillFromEnd != (textDirection == TextDirection.rtl);
    final active = activeOnRight
        ? Rect.fromLTRB(thumbCenter.dx, track.top, track.right, track.bottom)
        : Rect.fromLTRB(track.left, track.top, thumbCenter.dx, track.bottom);
    if (active.width > 0) {
      final color = sliderTheme.activeTrackColor ?? Colors.black;
      final paint = Paint()..color = color;
      if (activeStartOpacity < 1) {
        final faint = color.withValues(alpha: color.a * activeStartOpacity.clamp(0.0, 1.0));
        paint.shader = LinearGradient(
          begin: activeOnRight ? Alignment.centerRight : Alignment.centerLeft,
          end: activeOnRight ? Alignment.centerLeft : Alignment.centerRight,
          colors: [faint, color],
        ).createShader(active);
      }
      canvas.drawRRect(RRect.fromRectAndRadius(active, r), paint);
    }
    if (markerFraction case final double f) {
      final x = track.left + track.width * f;
      canvas.drawRect(Rect.fromCenter(center: Offset(x, track.center.dy), width: markerWidth, height: markerHeight),
          Paint()..color = markerColor);
    }
  }
}

/// Thin notches under the track, every [every] division (every fifth one
/// longer).
class NotchSliderTickMarkShape extends SliderTickMarkShape {
  const NotchSliderTickMarkShape({required this.divisions, required this.color, this.every = 1});

  final int divisions;
  final Color color;
  final int every;

  @override
  Size getPreferredSize({required SliderThemeData sliderTheme, bool isEnabled = false}) => const Size(1, 1);

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
    final track = (sliderTheme.trackShape ?? const RectangularSliderTrackShape())
        .getPreferredRect(parentBox: parentBox, sliderTheme: sliderTheme);
    final fraction = track.width == 0 ? 0.0 : ((center.dx - track.left) / track.width).clamp(0.0, 1.0);
    final index = (fraction * divisions).round();
    final step = every < 1 ? 1 : every;
    if (index % step != 0) return;
    final major = (index ~/ step) % 5 == 0;
    final top = center.dy + (sliderTheme.trackHeight ?? 4) / 2 + 3;
    context.canvas.drawRect(Rect.fromLTWH(center.dx - 0.5, top, 1, major ? 8 : 5), Paint()..color = color);
  }
}

/// The signature pad's sign line, placeholder and ink.
class SignaturePainter extends CustomPainter {
  SignaturePainter({
    required this.strokes,
    required this.inkColor,
    required this.inkWidth,
    required this.placeholder,
    required this.placeholderColor,
    required this.placeholderFontSize,
    required this.showSignLine,
    required this.signLineColor,
    required this.textDirection,
    this.normalized = false,
  });

  final List<List<Offset>> strokes;
  final Color inkColor;
  final double inkWidth;
  final String placeholder;
  final Color placeholderColor;
  final double placeholderFontSize;
  final bool showSignLine;
  final Color signLineColor;
  final TextDirection textDirection;

  /// Points are fractions of the size.
  final bool normalized;

  @override
  void paint(Canvas canvas, Size size) {
    if (showSignLine) _signLine(canvas, size);
    if (strokes.isEmpty && placeholder.isNotEmpty) _placeholder(canvas, size);
    final ink = Paint()
      ..color = inkColor
      ..strokeWidth = inkWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;
    for (final raw in strokes) {
      if (raw.isEmpty) continue;
      final stroke = normalized ? [for (final p in raw) Offset(p.dx * size.width, p.dy * size.height)] : raw;
      if (stroke.length == 1) {
        canvas.drawCircle(stroke.first, inkWidth / 2, Paint()..color = inkColor);
        continue;
      }
      canvas.drawPath(smoothPath(stroke), ink);
    }
  }

  static Path smoothPath(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    if (points.length == 2) return path..lineTo(points.last.dx, points.last.dy);
    for (var i = 1; i < points.length - 1; i++) {
      final p = points[i];
      final mid = (p + points[i + 1]) / 2;
      path.quadraticBezierTo(p.dx, p.dy, mid.dx, mid.dy);
    }
    return path..lineTo(points.last.dx, points.last.dy);
  }

  void _signLine(Canvas canvas, Size size) {
    const inset = 20.0;
    final y = size.height - size.height * 0.24;
    if (size.width <= inset * 2 || y <= 0) return;
    canvas.drawLine(Offset(inset, y), Offset(size.width - inset, y), Paint()
      ..color = signLineColor
      ..strokeWidth = 1);
    final cross = TextPainter(
      text: TextSpan(text: '×', style: TextStyle(color: signLineColor, fontSize: 16, height: 1)),
      textDirection: textDirection,
    )..layout();
    cross.paint(canvas, Offset(inset, y - cross.height - 4));
    cross.dispose();
  }

  void _placeholder(Canvas canvas, Size size) {
    final text = TextPainter(
      text: TextSpan(
        text: placeholder,
        style: TextStyle(
          color: placeholderColor,
          fontSize: placeholderFontSize,
          fontWeight: FontWeight.w600,
          letterSpacing: placeholderFontSize * 0.12,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: textDirection,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: size.width);
    text.paint(canvas, Offset((size.width - text.width) / 2, (size.height - text.height) / 2));
    text.dispose();
  }

  // Strokes grow in place while drawing.
  @override
  bool shouldRepaint(covariant SignaturePainter oldDelegate) => true;
}

/// A drafting ruler as a slider track: a strip in the inactive track color
/// across the slider's whole width, a baseline with [ticks] ticks (every
/// [majorEvery]th long), and the active color filled from zero (or the
/// minimum) to the value just under the baseline.
class RulerSliderTrackShape extends SliderTrackShape {
  const RulerSliderTrackShape({
    required this.ticks,
    required this.majorEvery,
    required this.tickColor,
    required this.minorTickColor,
    required this.zeroFraction,
  });

  final int ticks, majorEvery;
  final Color tickColor, minorTickColor;

  /// Where zero sits along the track (0 when the range doesn't include it).
  final double zeroFraction;

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final size = parentBox.size;
    return Rect.fromLTWH(offset.dx, offset.dy + size.height / 2 - 1, size.width, 2);
  }

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
    double additionalActiveTrackHeight = 2,
  }) {
    final rect = getPreferredRect(parentBox: parentBox, offset: offset, sliderTheme: sliderTheme);
    final canvas = context.canvas;
    final cy = rect.center.dy;
    final base = cy + 1;
    canvas.drawRect(Rect.fromLTRB(rect.left, cy - 9, rect.right, base), Paint()..color = sliderTheme.inactiveTrackColor ?? const Color(0x00000000));
    final major = Paint()
      ..color = tickColor
      ..strokeWidth = 1;
    final minor = Paint()
      ..color = minorTickColor
      ..strokeWidth = 1;
    canvas.drawLine(Offset(rect.left, base), Offset(rect.right, base), major);
    for (var i = 0; i <= ticks; i++) {
      final x = rect.left + (rect.width - 1) * i / ticks + 0.5;
      final long = i % majorEvery == 0;
      canvas.drawLine(Offset(x, base), Offset(x, base - (long ? 8 : 4)), long ? major : minor);
    }
    final zero = rect.left + rect.width * zeroFraction;
    final a = math.min(zero, thumbCenter.dx), b = math.max(zero, thumbCenter.dx);
    canvas.drawRect(Rect.fromLTRB(a, base + 1, b, base + 4), Paint()..color = sliderTheme.activeTrackColor ?? tickColor);
  }
}

/// A ruler's index as a slider thumb: a 2px hairline down across the
/// track and a triangle under it pointing up, in the thumb color, outlined
/// in [strokeColor].
class PointerSliderThumbShape extends SliderComponentShape {
  const PointerSliderThumbShape({required this.strokeColor});

  final Color strokeColor;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(14, 28);

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
    final canvas = context.canvas;
    final color = sliderTheme.thumbColor ?? strokeColor;
    final x = center.dx, cy = center.dy;
    canvas.drawLine(
        Offset(x, cy - 13),
        Offset(x, cy + 5),
        Paint()
          ..color = color
          ..strokeWidth = 2);
    final triangle = Path()
      ..moveTo(x, cy + 5)
      ..lineTo(x - 7, cy + 14)
      ..lineTo(x + 7, cy + 14)
      ..close();
    canvas.drawPath(triangle, Paint()..color = color);
    canvas.drawPath(
        triangle,
        Paint()
          ..color = strokeColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);
  }
}
