// Painters of the input widgets: the signature pad's ink. (The slider draws
// its own parts: render/controls/slider.dart.)
import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter/rendering.dart';

/// Where a signature pad's sign line and its mark sit, for its painter and
/// for an icon mark laid over it.
class SignLineGeometry {
  const SignLineGeometry({
    this.offset,
    this.inset = 20,
    this.markWidth = 16,
    this.markHeight = 16,
    this.markGap = 4,
    this.leadingMark = false,
    this.showMark = true,
  });

  /// From the bottom; null is 24% of the height.
  final double? offset;
  final double inset;

  /// The mark's box.
  final double markWidth, markHeight;
  final double markGap;

  /// The mark is before the line, centered on it; else over its start.
  final bool leadingMark;
  final bool showMark;

  double lineY(Size size) => size.height - (offset ?? size.height * 0.24);

  /// Where the line starts (after a leading mark).
  double lineStart(Size size) => inset + (showMark && leadingMark ? markWidth + markGap : 0);

  double lineEnd(Size size) => size.width - inset;

  /// The line's room: it is drawn only where it has some.
  bool fits(Size size) => size.width > inset * 2 && lineY(size) > 0;

  /// The mark's top-left.
  Offset markOrigin(Size size) {
    final y = lineY(size);
    return leadingMark ? Offset(inset, y - markHeight / 2) : Offset(inset, y - markHeight - markGap);
  }
}

/// The signature pad's sign line, placeholder, caption and ink.
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
    this.placeholderStyle,
    this.placeholderAlignment = Alignment.center,
    this.placeholderOffset = Offset.zero,
    this.signLineWidth = 1,
    this.dashed = false,
    this.dash = 6,
    this.gap = 6,
    this.signLineOffset,
    this.signLineInset = 20,
    this.showMark = true,
    this.markGlyph = true,
    this.markSize = 16,
    this.markColor,
    this.leadingMark = false,
    this.markGap = 4,
    this.caption = '',
    this.captionStyle,
    this.captionGap = 8,
    this.captionAlign = TextAlign.start,
    this.signLineMark = true,
    this.signLineBottom,
    this.placeholderBelowLine = false,
    this.placeholderFontWeight = 600,
    this.placeholderLetterSpacing,
    this.smooth = true,
  });

  /// Curves through the points; false: straight segments between them.
  final bool smooth;

  /// The × at the line's start (with [showMark]: either off hides it).
  final bool signLineMark;

  /// From the bottom; null is [signLineOffset] (else 24% of the height).
  final double? signLineBottom;

  /// The placeholder under the line at its start, not at
  /// [placeholderAlignment].
  final bool placeholderBelowLine;

  /// The default placeholder style's weight and letter spacing (null: 0.12
  /// × the size), where [placeholderStyle] is unset.
  final int placeholderFontWeight;
  final double? placeholderLetterSpacing;

  bool get _mark => showMark && signLineMark;

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

  /// The placeholder's style; null is [placeholderColor] at
  /// [placeholderFontSize], weight 600, spaced 0.12 × the size.
  final TextStyle? placeholderStyle;
  final Alignment placeholderAlignment;
  final Offset placeholderOffset;

  final double signLineWidth;
  final bool dashed;
  final double dash, gap;

  /// From the bottom; null is 24% of the height.
  final double? signLineOffset;
  final double signLineInset;

  /// The line has a mark at its start.
  final bool showMark;

  /// The mark is a painted "×" glyph [markSize] high; else it's an icon of
  /// [markSize] laid over the pad (at [geometry]'s `markOrigin`).
  final bool markGlyph;
  final double markSize;

  /// Null is [signLineColor].
  final Color? markColor;
  final bool leadingMark;
  final double markGap;

  /// Drawn under the line.
  final String caption;
  final TextStyle? captionStyle;
  final double captionGap;
  final TextAlign captionAlign;

  /// The legacy placeholder style.
  static TextStyle defaultPlaceholderStyle(Color color, double fontSize,
          {int fontWeight = 600, double? letterSpacing}) =>
      TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: FontWeight.values[((fontWeight ~/ 100) - 1).clamp(0, 8)],
        letterSpacing: letterSpacing ?? fontSize * 0.12,
      );

  TextPainter _glyph() => TextPainter(
        text: TextSpan(text: '×', style: TextStyle(color: markColor ?? signLineColor, fontSize: markSize, height: 1)),
        textDirection: textDirection,
      )..layout();

  /// The geometry, the "×" glyph measured when it's painted ([markGlyph]);
  /// else a square mark of [markSize] (an icon).
  SignLineGeometry geometry() {
    var w = markSize, h = markSize;
    if (markGlyph && _mark) {
      final g = _glyph();
      w = g.width;
      h = g.height;
      g.dispose();
    }
    return SignLineGeometry(
      offset: signLineBottom ?? signLineOffset,
      inset: signLineInset,
      markWidth: w,
      markHeight: h,
      markGap: markGap,
      leadingMark: leadingMark,
      showMark: _mark,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (showSignLine) _signLine(canvas, size);
    if (caption.isNotEmpty) _caption(canvas, size);
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
      canvas.drawPath(smooth ? smoothPath(stroke) : linePath(stroke), ink);
    }
  }

  /// [points] joined by straight segments.
  static Path linePath(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    return path;
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
    final g = geometry();
    if (!g.fits(size)) return;
    final y = g.lineY(size);
    final start = g.lineStart(size), end = g.lineEnd(size);
    final paint = Paint()
      ..color = signLineColor
      ..strokeWidth = signLineWidth;
    if (signLineWidth > 0 && end > start) {
      if (dashed && dash > 0) {
        for (var x = start; x < end; x += dash + gap) {
          canvas.drawLine(Offset(x, y), Offset(math.min(x + dash, end), y), paint);
        }
      } else {
        canvas.drawLine(Offset(start, y), Offset(end, y), paint);
      }
    }
    if (_mark && markGlyph) {
      final cross = _glyph();
      cross.paint(canvas, g.markOrigin(size));
      cross.dispose();
    }
  }

  void _caption(Canvas canvas, Size size) {
    final g = geometry();
    final width = size.width - g.inset * 2;
    if (width <= 0) return;
    final text = TextPainter(
      text: TextSpan(text: caption, style: captionStyle ?? TextStyle(color: signLineColor, fontSize: 11)),
      textAlign: captionAlign,
      textDirection: textDirection,
      maxLines: 1,
      ellipsis: '…',
    )..layout(minWidth: width, maxWidth: width);
    text.paint(canvas, Offset(g.inset, g.lineY(size) + signLineWidth / 2 + captionGap));
    text.dispose();
  }

  void _placeholder(Canvas canvas, Size size) {
    final text = TextPainter(
      text: TextSpan(
        text: placeholder,
        style: placeholderStyle ??
            defaultPlaceholderStyle(placeholderColor, placeholderFontSize,
                fontWeight: placeholderFontWeight, letterSpacing: placeholderLetterSpacing),
      ),
      textAlign: placeholderBelowLine ? TextAlign.start : TextAlign.center,
      textDirection: textDirection,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: size.width);
    if (placeholderBelowLine) {
      // Its top a little under the line, at the line's start.
      final g = geometry();
      final top = showSignLine ? g.lineY(size) + 5 : size.height - text.height - 8;
      final x = textDirection == TextDirection.rtl ? size.width - g.inset - text.width : g.inset;
      text.paint(canvas, Offset(x, top) + placeholderOffset);
    } else {
      final at = placeholderAlignment.alongOffset(Offset(size.width - text.width, size.height - text.height));
      text.paint(canvas, at + placeholderOffset);
    }
    text.dispose();
  }

  // Strokes grow in place while drawing.
  @override
  bool shouldRepaint(covariant SignaturePainter oldDelegate) => true;
}
