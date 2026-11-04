// A node's paints that a single BoxDecoration can't express: stacked fills,
// gradients, images, and strokes that are dashed, one-sided or several.
// Painted as one leaf box that fills its parent stack.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:flutter/rendering.dart';

import '../convert.dart';
import 'image_fill.dart';

/// Paints fills and/or strokes of a box decoration, at the size its parent
/// gives it.
class RenderNodePaint extends RenderBox with ImageClient {
  RenderNodePaint({api.Decoration decoration = api.Decoration.none, bool foreground = false})
      : _decoration = decoration,
        _foreground = foreground {
    showImages(decoration.fills.map(imageUrlOf));
  }

  api.Decoration _decoration;
  api.Decoration get decoration => _decoration;
  set decoration(api.Decoration v) {
    if (v == _decoration) return;
    _decoration = v;
    showImages(v.fills.map(imageUrlOf));
    markNeedsPaint();
  }

  /// Paints the foreground fills instead of the fills and strokes.
  bool _foreground;
  set foreground(bool v) {
    if (v == _foreground) return;
    _foreground = v;
    markNeedsPaint();
  }

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest.isFinite ? constraints.biggest : constraints.smallest;

  @override
  bool hitTestSelf(Offset position) => false;

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    final rect = offset & size;
    final rrect = decoration.radius.flutter.toRRect(rect);
    if (_foreground) {
      for (final p in decoration.foregroundFills) {
        _fill(canvas, rrect, p);
      }
      return;
    }
    for (final p in decoration.visibleFills) {
      _fill(canvas, rrect, p);
    }
    final strokes = decoration.visibleStrokes.toList();
    if (strokes.isEmpty) return;
    final w = decoration.strokeWidth;
    // Inside: the stroke's outer edge on the box edge; outside: its inner.
    final inset = switch (decoration.strokeAlign) {
      api.StrokeAlign.inside => w / 2,
      api.StrokeAlign.center => 0.0,
      api.StrokeAlign.outside => -w / 2,
    };
    final path = Path();
    if (decoration.strokeSides == api.StrokeSides.all) {
      path.addRRect(rrect.deflate(inset));
    } else {
      final r = rect.deflate(inset);
      final (a, b) = switch (decoration.strokeSides) {
        api.StrokeSides.left => (r.topLeft, r.bottomLeft),
        api.StrokeSides.top => (r.topLeft, r.topRight),
        api.StrokeSides.right => (r.topRight, r.bottomRight),
        _ => (r.bottomLeft, r.bottomRight),
      };
      path
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy);
    }
    final dashed = decoration.dashPattern.any((d) => d > 0) ? _dash(path, decoration.dashPattern) : path;
    for (final p in strokes) {
      final paint = paintFor(p, rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w
        ..strokeCap = StrokeCap.values.byName(decoration.strokeCap.name);
      canvas.drawPath(dashed, paint);
    }
  }

  void _fill(Canvas canvas, RRect rrect, api.Paint p) {
    if (!p.visible) return;
    if (p.type == api.PaintType.image) {
      // Foreground images aren't drawn (as SDK 8.x).
      if (!_foreground) paintImageFill(canvas, rrect, p, this);
      return;
    }
    canvas.drawRRect(rrect, paintFor(p, rrect.outerRect));
  }

  /// The Flutter paint for a solid or gradient [p] over [rect].
  static Paint paintFor(api.Paint p, Rect rect) {
    final paint = Paint()..blendMode = blendMode(p.blendMode);
    if (!p.isGradient) {
      paint.color = (p.effectiveColor ?? const api.Color(0)).flutter;
      return paint;
    }
    final colors = [for (final s in p.stops) s.color.multiplyOpacity(p.opacity).flutter];
    final stops = [for (final s in p.stops) s.position.clamp(0.0, 1.0)];
    if (colors.length < 2) {
      paint.color = colors.isEmpty ? const Color(0x00000000) : colors.first;
      return paint;
    }
    // The gradient transform maps the box onto the unit square
    // (Figma's convention); its inverse places the gradient's axis.
    final t = p.transform;
    Offset at(double u, double v) {
      if (t == null || t.length != 6) return Offset(rect.left + u * rect.width, rect.top + v * rect.height);
      final det = t[0] * t[4] - t[1] * t[3];
      if (det == 0) return rect.center;
      final x = u - t[2], y = v - t[5];
      final bx = (t[4] * x - t[1] * y) / det, by = (-t[3] * x + t[0] * y) / det;
      return Offset(rect.left + bx * rect.width, rect.top + by * rect.height);
    }

    final tile = TileMode.values.byName(p.tileMode.name);
    paint.shader = switch (p.type) {
      api.PaintType.linear => ui.Gradient.linear(at(0, 0.5), at(1, 0.5), colors, stops, tile),
      api.PaintType.radial || api.PaintType.diamond =>
        ui.Gradient.radial(at(0.5, 0.5), (at(1, 0.5) - at(0.5, 0.5)).distance, colors, stops, tile),
      _ => ui.Gradient.sweep(at(0.5, 0.5), colors, stops, tile, 0, math.pi * 2),
    };
    return paint;
  }

  static Path _dash(Path source, List<double> pattern) {
    final out = Path();
    for (final metric in source.computeMetrics()) {
      var d = 0.0, i = 0, draw = true;
      while (d < metric.length) {
        final len = pattern[i % pattern.length];
        if (draw && len > 0) out.addPath(metric.extractPath(d, d + len), Offset.zero);
        d += len <= 0 ? 1 : len;
        draw = !draw;
        i++;
      }
    }
    return out;
  }
}
