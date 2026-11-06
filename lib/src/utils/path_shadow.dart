import 'package:codelessly_api/codelessly_api.dart';
import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';

import '../../codelessly_sdk.dart';

/// Paints drop [shadows] that follow [path] (in the canvas' coordinates)
/// instead of a box: the shadow of the fill when [filled], and of a stroke
/// of [strokeWidth] along [stroke] (or [path]) when it is above 0, so an
/// open, stroke-only line casts a line-shaped shadow.
///
/// A shadow's spread grows the silhouette evenly (a stroke of twice the
/// spread along the outline); a negative spread only thins a stroke's
/// shadow, it does not shrink a fill's.
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
  for (final BoxShadow shadow in shadows) {
    final double spread = shadow.spreadRadius;
    final double lineWidth = strokeWidth > 0 ? strokeWidth + spread * 2 : 0;
    // (outline, style, stroke width, whether it is the node's own stroke)
    final List<(Path, PaintingStyle, double, bool)> parts = [
      if (filled) (path, PaintingStyle.fill, 0, false),
      if (filled && spread > 0) (path, PaintingStyle.stroke, spread * 2, false),
      if (lineWidth > 0)
        (stroke ?? path, PaintingStyle.stroke, lineWidth, true),
    ];
    if (parts.isEmpty) continue;
    // Overlapping parts are drawn opaque in a layer of the shadow's
    // opacity, so a translucent shadow doesn't darken where they overlap.
    final bool layered = parts.length > 1 && shadow.color.a < 1;
    final Paint base = shadow.toPaint();
    if (layered) {
      canvas.saveLayer(
        null,
        Paint()..color = Color.fromRGBO(0, 0, 0, shadow.color.a),
      );
      base.color = shadow.color.withValues(alpha: 1);
    }
    for (final (Path part, PaintingStyle style, double width, bool line)
        in parts) {
      final Paint paint = Paint()
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

/// Paints inner [shadows] inside [path]: each is cast by everything outside
/// the path, offset by the shadow's offset, blurred, and clipped to the
/// path. A spread pushes the shadow farther in.
void paintPathInnerShadows(Canvas canvas, Path path, List<BoxShadow> shadows) {
  if (shadows.isEmpty) return;
  final Rect bounds = path.getBounds();
  canvas.save();
  canvas.clipPath(path);
  for (final BoxShadow shadow in shadows) {
    final Path hole = path.shift(shadow.offset);
    final double margin =
        shadow.blurRadius * 3 +
        shadow.offset.distance +
        shadow.spreadRadius.abs() +
        1;
    final Path outside = Path.combine(
      PathOperation.difference,
      Path()..addRect(bounds.inflate(margin)),
      hole,
    );
    final bool layered = shadow.spreadRadius > 0 && shadow.color.a < 1;
    final Paint paint = shadow.toPaint();
    if (layered) {
      canvas.saveLayer(
        null,
        Paint()..color = Color.fromRGBO(0, 0, 0, shadow.color.a),
      );
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
          ..strokeJoin = StrokeJoin.round,
      );
    }
    if (layered) canvas.restore();
  }
  canvas.restore();
}

/// The visible inner shadows of [node], as [BoxShadow]s (a shadow's colour
/// can be bound as `shadow-color-<effect id>`, as a drop shadow's can).
List<BoxShadow> retrieveInnerShadows(BaseNode node, ScopedValues scopedValues) {
  if (node is! DefaultShapeNode) return [];
  return [
    for (final Effect effect in node.effects)
      if (effect.type == EffectType.innerShadow && effect.visible)
        BoxShadow(
          spreadRadius: effect.spread ?? 0,
          offset: Offset(
            effect.offset?.x.toDouble() ?? 0,
            effect.offset?.y.toDouble() ?? 0,
          ),
          blurRadius: effect.radius,
          color:
              (PropertyValueDelegate.getPropertyValue<ColorRGBA>(
                        node,
                        'shadow-color-${effect.id}',
                        scopedValues: scopedValues,
                      ) ??
                      effect.color ??
                      ColorRGBA.black)
                  .toFlutterColor(),
        ),
  ];
}

/// The outline the drop shadows of a rectangle drawn as an SVG path
/// ([RectangleNode.path]) follow: the path's fill when it has fills, and
/// its stroke when it has strokes.
@immutable
class PathShadowShape {
  /// Creates a [PathShadowShape].
  const PathShadowShape({
    required this.data,
    this.filled = true,
    this.strokeWidth = 0,
    this.cap = StrokeCap.butt,
    this.join = StrokeJoin.miter,
  });

  /// The SVG path data, in the node's own coordinates.
  final String data;

  /// Whether the shadow follows the filled path.
  final bool filled;

  /// The width of the stroke whose shadow is cast, or 0 for none.
  final double strokeWidth;

  /// The stroke's caps.
  final StrokeCap cap;

  /// The stroke's corners.
  final StrokeJoin join;

  @override
  bool operator ==(Object other) =>
      other is PathShadowShape &&
      other.data == data &&
      other.filled == filled &&
      other.strokeWidth == strokeWidth &&
      other.cap == cap &&
      other.join == join;

  @override
  int get hashCode => Object.hash(data, filled, strokeWidth, cap, join);
}

/// The [PathShadowShape] of [node] when it is a rectangle drawn as a path,
/// else null.
PathShadowShape? pathShadowShapeOf(BaseNode node) {
  if (node is! RectangleNode || !node.hasPath) return null;
  final bool stroked =
      node.strokeWeight > 0 && node.strokes.any((paint) => paint.visible);
  return PathShadowShape(
    data: node.path!,
    filled: node.fills.any((paint) => paint.visible),
    strokeWidth: stroked ? node.strokeWeight : 0,
    cap: node.strokeCap.flutterStrokeCap,
    join: node.strokeJoin.flutterStrokeJoin,
  );
}

/// Paints drop [shadows] along [shape] (see [paintPathShadows]).
class PathShadowPainter extends CustomPainter {
  /// Creates a [PathShadowPainter].
  const PathShadowPainter({required this.shape, required this.shadows});

  /// The outline the shadows follow.
  final PathShadowShape shape;

  /// The shadows, painted in order.
  final List<BoxShadow> shadows;

  @override
  void paint(Canvas canvas, Size size) {
    final Path? path = parseSvgPath(shape.data);
    if (path == null) return;
    paintPathShadows(
      canvas,
      path,
      shadows,
      filled: shape.filled,
      strokeWidth: shape.strokeWidth,
      cap: shape.cap,
      join: shape.join,
    );
  }

  @override
  bool shouldRepaint(PathShadowPainter oldDelegate) =>
      oldDelegate.shape != shape ||
      !const ListEquality<BoxShadow>().equals(oldDelegate.shadows, shadows);
}
