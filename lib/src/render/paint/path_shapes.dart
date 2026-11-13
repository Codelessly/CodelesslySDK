// What the path painter adds beyond plain fills and strokes: shadows along
// a path's outline, outside and inside it.

import 'package:flutter/rendering.dart';

/// Paints drop [shadows] that follow [path] instead of a box: the shadow of
/// the fill when [filled], and of a stroke of [strokeWidth] along [stroke]
/// (or [path]) when above 0, so an open line casts a line-shaped shadow. A
/// spread grows the silhouette evenly; a negative one only thins a stroke's.
void paintPathShadows(
  Canvas canvas,
  Path path,
  List<BoxShadow> shadows, {
  bool filled = true,
  Path? stroke,
  double strokeWidth = 0,
  StrokeCap cap = StrokeCap.butt,
  StrokeJoin join = StrokeJoin.miter,
}) {
  for (final shadow in shadows) {
    final spread = shadow.spreadRadius;
    final lineWidth = strokeWidth > 0 ? strokeWidth + spread * 2 : 0.0;
    // (outline, style, stroke width, whether it is the node's own stroke)
    final parts = <(Path, PaintingStyle, double, bool)>[
      if (filled) (path, PaintingStyle.fill, 0, false),
      if (filled && spread > 0) (path, PaintingStyle.stroke, spread * 2, false),
      if (lineWidth > 0) (stroke ?? path, PaintingStyle.stroke, lineWidth, true),
    ];
    if (parts.isEmpty) continue;
    // Overlapping parts are drawn opaque in a layer of the shadow's opacity,
    // so a translucent shadow doesn't darken where they overlap.
    final layered = parts.length > 1 && shadow.color.a < 1;
    final base = shadow.toPaint();
    if (layered) {
      canvas.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, shadow.color.a));
      base.color = shadow.color.withValues(alpha: 1);
    }
    for (final (part, style, width, line) in parts) {
      final paint = Paint()
        ..color = base.color
        ..maskFilter = base.maskFilter
        ..style = style;
      if (style == PaintingStyle.stroke) {
        paint
          ..strokeWidth = width
          ..strokeCap = line ? cap : StrokeCap.round
          ..strokeJoin = line ? join : StrokeJoin.round;
      }
      canvas.drawPath(part.shift(shadow.offset), paint);
    }
    if (layered) canvas.restore();
  }
}

/// Paints inner [shadows] inside [path]: each cast by everything outside the
/// path, offset, blurred and clipped to it; a spread pushes it farther in.
void paintPathInnerShadows(Canvas canvas, Path path, List<BoxShadow> shadows) {
  if (shadows.isEmpty) return;
  final bounds = path.getBounds();
  canvas.save();
  canvas.clipPath(path);
  for (final shadow in shadows) {
    final hole = path.shift(shadow.offset);
    final margin = shadow.blurRadius * 3 + shadow.offset.distance + shadow.spreadRadius.abs() + 1;
    final outside = Path.combine(PathOperation.difference, Path()..addRect(bounds.inflate(margin)), hole);
    final layered = shadow.spreadRadius > 0 && shadow.color.a < 1;
    final paint = shadow.toPaint();
    if (layered) {
      canvas.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, shadow.color.a));
      paint.color = shadow.color.withValues(alpha: 1);
    }
    canvas.drawPath(outside, paint);
    if (shadow.spreadRadius > 0) {
      canvas.drawPath(
          hole,
          Paint()
            ..color = paint.color
            ..maskFilter = paint.maskFilter
            ..style = PaintingStyle.stroke
            ..strokeWidth = shadow.spreadRadius * 2
            ..strokeJoin = StrokeJoin.round);
    }
    if (layered) canvas.restore();
  }
  canvas.restore();
}
