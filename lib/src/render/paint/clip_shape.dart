// A node cut to a shape of its own (a decoration's clipPath and clipCuts):
// the path, the clipper every node box takes, and the shadow and border that
// follow the path (codelessly_api docs/design/26).
import 'dart:ui' as ui;

import 'package:codelessly_api/core.dart' as api;
import 'package:flutter/rendering.dart';

import '../convert.dart';
import 'node_paint.dart';
import 'path_paint.dart' show parseSvgPath;

/// The shape [d] cuts a box of [size] to, or null when it has none: its
/// `clipPath` in its `clipViewBox` mapped by `clipFit` (as a customPaint's
/// view box is; neither: the unit square stretched over the box; `none`
/// without a view box: the box's pixels), else the box's own shape (its
/// corners, a circle); less its `clipCuts`, each in pixels at its point.
Path? clipShapeOf(api.Decoration d, Size size) {
  if (!d.hasClipShape) return null;
  final box = Offset.zero & size;
  Path base;
  if (d.clipPath case final String data) {
    final parsed = parseSvgPath(data);
    if (parsed == null) {
      base = Path()..addRect(box);
    } else {
      final v = d.clipViewBox ?? (d.clipFit == api.BoxFit.none ? null : const [0.0, 0.0, 1.0, 1.0]);
      if (v == null) {
        base = parsed.shift(Offset.zero);
      } else {
        final view = Rect.fromLTWH(v[0], v[1], v[2], v[3]);
        final fitted = applyBoxFit(BoxFit.values.byName(d.clipFit.name), view.size, size);
        final dst = Alignment.center.inscribe(fitted.destination, box);
        final src = Alignment.center.inscribe(fitted.source, Offset.zero & view.size);
        final m = Matrix4.translationValues(dst.left, dst.top, 0)
          ..scaleByDouble(dst.width / src.width, dst.height / src.height, 1, 1)
          ..translateByDouble(-(view.left + src.left), -(view.top + src.top), 0, 1);
        base = parsed.transform(m.storage);
      }
    }
  } else if (d.shape == api.DecorationShape.circle) {
    base = Path()..addOval(Rect.fromCircle(center: box.center, radius: size.shortestSide / 2));
  } else {
    base = Path()..addRRect(d.radius.flutter.toRRect(box));
  }
  if (d.clipCuts.isEmpty) return base;
  final cuts = Path();
  for (final c in d.clipCuts) {
    final at = c.center.flutter.withinRect(box);
    if (c.radius case final double r) cuts.addOval(Rect.fromCircle(center: at, radius: r));
    if (c.d case final String data) {
      if (parseSvgPath(data) case final Path p) cuts.addPath(p, at);
    }
  }
  return Path.combine(PathOperation.difference, base, cuts);
}

/// A decoration's own shape as a clip: what a node box is cut to.
class ShapeClipper extends CustomClipper<Path> {
  const ShapeClipper(this.decoration);
  final api.Decoration decoration;

  @override
  Path getClip(Size size) => clipShapeOf(decoration, size) ?? (Path()..addRect(Offset.zero & size));

  @override
  bool shouldReclip(ShapeClipper oldClipper) => !_sameShape(oldClipper.decoration, decoration);
}

bool _sameShape(api.Decoration a, api.Decoration b) =>
    a.clipPath == b.clipPath &&
    api.listEquals(a.clipViewBox, b.clipViewBox) &&
    a.clipFit == b.clipFit &&
    api.listEquals(a.clipCuts, b.clipCuts) &&
    a.radius == b.radius &&
    a.shape == b.shape;

/// The drop shadows of a node cut to a shape: the shape, blurred and offset
/// (painted outside the cut, under the node).
class ClipShadowPainter extends CustomPainter {
  ClipShadowPainter(this.decoration);
  final api.Decoration decoration;

  @override
  void paint(Canvas canvas, Size size) {
    final path = clipShapeOf(decoration, size);
    if (path == null) return;
    for (final e in decoration.effects) {
      if (!e.visible || e.type != api.EffectType.dropShadow) continue;
      final color = e.color.flutter;
      final blur = e.blurRadius > 0 ? MaskFilter.blur(BlurStyle.normal, Shadow.convertRadiusToSigma(e.blurRadius)) : null;
      final shadow = path.shift(Offset(e.offset.dx, e.offset.dy));
      // Opaque in a layer of the shadow's alpha, so a spread's outline and
      // the shape it grows do not add up where they overlap.
      canvas.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, color.a));
      final opaque = color.withValues(alpha: 1);
      if (e.spreadRadius > 0) {
        // Grown by the spread: the shape's outline as wide on each side (a
        // negative spread is drawn as none).
        canvas.drawPath(
            shadow,
            Paint()
              ..color = opaque
              ..maskFilter = blur
              ..style = PaintingStyle.stroke
              ..strokeWidth = e.spreadRadius * 2);
      }
      canvas.drawPath(shadow, Paint()..color = opaque..maskFilter = blur);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(ClipShadowPainter oldDelegate) => oldDelegate.decoration != decoration;
}

/// The border of a node cut to a shape: along the shape, inside it, as wide
/// as the decoration's stroke width (painted over the content, as a
/// shell's inside border is).
class ClipBorderPainter extends CustomPainter {
  ClipBorderPainter(this.decoration);
  final api.Decoration decoration;

  @override
  void paint(Canvas canvas, Size size) {
    final path = clipShapeOf(decoration, size);
    final w = decoration.strokeWidth;
    if (path == null || w <= 0) return;
    canvas.save();
    canvas.clipPath(path);
    for (final p in decoration.visibleStrokes) {
      canvas.drawPath(
          path,
          RenderNodePaint.paintFor(p, Offset.zero & size)
            ..style = PaintingStyle.stroke
            ..strokeWidth = w * 2
            ..strokeJoin = ui.StrokeJoin.round);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(ClipBorderPainter oldDelegate) => oldDelegate.decoration != decoration;
}
