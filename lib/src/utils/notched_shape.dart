import 'dart:ui' as ui;

import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';

import 'package:codelessly_api/codelessly_api.dart';

/// The notches cut into [node]'s edges, or none.
List<NotchModel> notchesOf(BaseNode node) =>
    node is CornerMixin ? node.notches : const [];

/// The outline of a box of [size] with rounded corners of [borderRadius] and
/// semicircles of each notch's radius cut out of its edges: the shape of a
/// paper ticket.
Path notchedPath(
  Size size,
  BorderRadius borderRadius,
  List<NotchModel> notches,
) {
  final Path box = Path()..addRRect(borderRadius.toRRect(Offset.zero & size));
  if (notches.isEmpty) return box;
  final Path holes = Path();
  for (final NotchModel notch in notches) {
    if (notch.radius <= 0) continue;
    final double length = notch.edge.isVertical ? size.height : size.width;
    final double at = notch.positionOn(length);
    void hole(Offset center) => holes.addOval(
      Rect.fromCircle(center: center, radius: notch.radius),
    );
    switch (notch.edge) {
      case NotchEdge.left:
        hole(Offset(0, at));
      case NotchEdge.right:
        hole(Offset(size.width, at));
      case NotchEdge.leftRight:
        hole(Offset(0, at));
        hole(Offset(size.width, at));
      case NotchEdge.top:
        hole(Offset(at, 0));
      case NotchEdge.bottom:
        hole(Offset(at, size.height));
      case NotchEdge.topBottom:
        hole(Offset(at, 0));
        hole(Offset(at, size.height));
    }
  }
  return Path.combine(PathOperation.difference, box, holes);
}

/// Clips its child to a notched box.
class NotchedClipper extends CustomClipper<Path> {
  /// Creates a [NotchedClipper].
  const NotchedClipper({required this.borderRadius, required this.notches});

  /// The box's corners.
  final BorderRadius borderRadius;

  /// The notches cut into its edges.
  final List<NotchModel> notches;

  @override
  Path getClip(Size size) => notchedPath(size, borderRadius, notches);

  @override
  bool shouldReclip(NotchedClipper oldClipper) =>
      oldClipper.borderRadius != borderRadius ||
      !const ListEquality<NotchModel>().equals(oldClipper.notches, notches);
}

/// Paints drop shadows that follow a notched box, notches included.
class NotchedShadowPainter extends CustomPainter {
  /// Creates a [NotchedShadowPainter].
  const NotchedShadowPainter({
    required this.shadows,
    required this.borderRadius,
    required this.notches,
  });

  /// The shadows, painted in order.
  final List<BoxShadow> shadows;

  /// The box's corners.
  final BorderRadius borderRadius;

  /// The notches cut into its edges.
  final List<NotchModel> notches;

  @override
  void paint(Canvas canvas, Size size) {
    final Path path = notchedPath(size, borderRadius, notches);
    for (final BoxShadow shadow in shadows) {
      final Paint paint = shadow.toPaint();
      final Path shifted = path.shift(shadow.offset);
      canvas.drawPath(shifted, paint);
      // A spread grows (or, negative, shrinks) the outline evenly; a stroke
      // of twice the spread along it does that for any shape.
      if (shadow.spreadRadius > 0) {
        canvas.drawPath(
          shifted,
          shadow.toPaint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = shadow.spreadRadius * 2
            ..strokeJoin = StrokeJoin.round,
        );
      }
    }
  }

  @override
  bool shouldRepaint(NotchedShadowPainter oldDelegate) =>
      !const ListEquality<BoxShadow>().equals(oldDelegate.shadows, shadows) ||
      oldDelegate.borderRadius != borderRadius ||
      !const ListEquality<NotchModel>().equals(oldDelegate.notches, notches);
}

/// Strokes the outline of a notched box, solid or dashed, inside, centred on
/// or outside the outline as [strokeAlign] says.
class NotchedStrokePainter extends CustomPainter {
  /// Creates a [NotchedStrokePainter].
  const NotchedStrokePainter({
    required this.color,
    required this.strokeWidth,
    required this.borderRadius,
    required this.notches,
    this.strokeAlign = StrokeAlignC.inside,
    this.dashPattern = const [],
    this.strokeCap = StrokeCapEnum.none,
  });

  /// The stroke's colour.
  final Color color;

  /// The stroke's width.
  final double strokeWidth;

  /// The box's corners.
  final BorderRadius borderRadius;

  /// The notches cut into its edges.
  final List<NotchModel> notches;

  /// Where the stroke sits relative to the outline.
  final StrokeAlignC strokeAlign;

  /// Dash and gap lengths, repeating; empty for a solid stroke.
  final List<double> dashPattern;

  /// The ends of each dash.
  final StrokeCapEnum strokeCap;

  @override
  void paint(Canvas canvas, Size size) {
    if (strokeWidth <= 0) return;
    final Path outline = notchedPath(size, borderRadius, notches);
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = switch (strokeCap) {
        StrokeCapEnum.round => StrokeCap.round,
        StrokeCapEnum.square => StrokeCap.square,
        _ => StrokeCap.butt,
      };
    final Path path = dashPattern.isEmpty || dashPattern.every((d) => d <= 0)
        ? outline
        : _dashed(outline, dashPattern);
    canvas.save();
    switch (strokeAlign) {
      case StrokeAlignC.inside:
        // Twice the width, clipped to the inside, leaves the width inside.
        canvas.clipPath(outline);
        paint.strokeWidth = strokeWidth * 2;
      case StrokeAlignC.outside:
        canvas.clipPath(
          Path.combine(
            PathOperation.difference,
            Path()..addRect((Offset.zero & size).inflate(strokeWidth * 2)),
            outline,
          ),
        );
        paint.strokeWidth = strokeWidth * 2;
      case StrokeAlignC.center:
        paint.strokeWidth = strokeWidth;
    }
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  static Path _dashed(Path source, List<double> pattern) {
    final Path out = Path();
    for (final ui.PathMetric metric in source.computeMetrics()) {
      double distance = 0;
      int i = 0;
      bool draw = true;
      while (distance < metric.length) {
        final double len = pattern[i % pattern.length].clamp(0.5, 1e6);
        if (draw) out.addPath(metric.extractPath(distance, distance + len), Offset.zero);
        distance += len;
        draw = !draw;
        i++;
      }
    }
    return out;
  }

  @override
  bool shouldRepaint(NotchedStrokePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.borderRadius != borderRadius ||
      oldDelegate.strokeAlign != strokeAlign ||
      oldDelegate.strokeCap != strokeCap ||
      !const ListEquality<double>().equals(oldDelegate.dashPattern, dashPattern) ||
      !const ListEquality<NotchModel>().equals(oldDelegate.notches, notches);
}
