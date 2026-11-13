// A node's paints that a single BoxDecoration can't express: stacked fills,
// gradients, images, and strokes that are dashed, one-sided or several.
// Painted as one leaf box that fills its parent stack.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:codelessly_api/core.dart' as api;
import 'package:flutter/rendering.dart';

import '../convert.dart';
import 'image_fill.dart';

/// Paints fills and/or strokes of a box decoration, at the size its parent
/// gives it.
class RenderNodePaint extends RenderBox with ImageClient {
  RenderNodePaint({api.Decoration decoration = api.Decoration.none, this._foreground = false})
      : _decoration = decoration {
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

  /// The node clips itself to its shape, anti-aliased: the fills paint the
  /// whole box and the clip rounds them, once (as a ClipRRect around a
  /// filled box). Rounded again here, their edge would be anti-aliased
  /// twice and come out fainter at a fractional position.
  bool _clipped = false;
  set clipped(bool v) {
    if (v == _clipped) return;
    _clipped = v;
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
    // A circle: the box's shortest side across, in its middle.
    final rrect = decoration.shape == api.DecorationShape.circle
        ? RRect.fromRectAndRadius(Rect.fromCircle(center: rect.center, radius: rect.shortestSide / 2), Radius.circular(rect.shortestSide / 2))
        : decoration.radius.flutter.toRRect(rect);
    var fillShape = _clipped ? RRect.fromRectAndRadius(rect, Radius.zero) : rrect;
    // Solid, undashed rules on some sides of a square box paint as
    // Flutter's Border(bottom: ...) does: each side a filled band the box's
    // whole length, the fill tucked under an opaque one by half its inset.
    final ruled = _ruledSides();
    if (ruled != null && !_foreground) {
      final (sides, w, inset) = ruled;
      // Only under an opaque rule, as Flutter's BoxDecoration does.
      final opaque = decoration.visibleStrokes.every((p) => (p.effectiveColor?.flutter.a ?? 0) >= 1);
      final tuck = opaque ? inset / 2 : 0.0;
      fillShape = RRect.fromLTRBR(
        fillShape.left + (sides.contains('left') ? tuck : 0),
        fillShape.top + (sides.contains('top') ? tuck : 0),
        fillShape.right - (sides.contains('right') ? tuck : 0),
        fillShape.bottom - (sides.contains('bottom') ? tuck : 0),
        Radius.zero,
      );
    }
    if (_foreground) {
      for (final p in decoration.foregroundFills) {
        _fill(canvas, fillShape, p);
      }
      return;
    }
    for (final p in decoration.visibleFills) {
      _fill(canvas, fillShape, p);
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
    if (ruled != null) {
      final (sides, w, inset) = ruled;
      // The band's inner edge `inset` in from the box edge (inside: the
      // whole width in; centre: half; outside: none), `w` wide.
      final bands = [
        if (sides.contains('top')) Rect.fromLTRB(rect.left, rect.top + inset - w, rect.right, rect.top + inset),
        if (sides.contains('right')) Rect.fromLTRB(rect.right - inset, rect.top, rect.right - inset + w, rect.bottom),
        if (sides.contains('bottom')) Rect.fromLTRB(rect.left, rect.bottom - inset, rect.right, rect.bottom - inset + w),
        if (sides.contains('left')) Rect.fromLTRB(rect.left + inset - w, rect.top, rect.left + inset, rect.bottom),
      ];
      for (final p in strokes) {
        final paint = paintFor(p, rect)..style = PaintingStyle.fill;
        for (final band in bands) {
          canvas.drawRect(band, paint);
        }
      }
      return;
    }
    final circle = decoration.shape == api.DecorationShape.circle;
    if (circle && decoration.dashPattern.every((d) => d <= 0) && decoration.strokeSides == api.StrokeSides.all) {
      // A circle's stroke as a circle (drawn as an oval, like drawCircle).
      for (final p in strokes) {
        canvas.drawRRect(
          rrect.deflate(inset),
          paintFor(p, rect)
            ..style = PaintingStyle.stroke
            ..strokeWidth = w,
        );
      }
      return;
    }
    final path = Path();
    if (decoration.strokeSides == api.StrokeSides.all) {
      path.addRRect(rrect.deflate(inset));
    } else {
      // Each side runs the box's whole length, inset only across itself,
      // as Flutter's Border(bottom: ...) paints it (deflating the whole
      // rect cut half a stroke off each end).
      final sides = decoration.strokeSides.sides;
      final top = rect.top + inset, bottom = rect.bottom - inset;
      final left = rect.left + inset, right = rect.right - inset;
      final lines = [
        if (sides.contains('top')) (Offset(rect.left, top), Offset(rect.right, top)),
        if (sides.contains('right')) (Offset(right, rect.top), Offset(right, rect.bottom)),
        if (sides.contains('bottom')) (Offset(rect.left, bottom), Offset(rect.right, bottom)),
        if (sides.contains('left')) (Offset(left, rect.top), Offset(left, rect.bottom)),
      ];
      for (final (a, b) in lines) {
        path
          ..moveTo(a.dx, a.dy)
          ..lineTo(b.dx, b.dy);
      }
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

  /// The sides a square box rules with solid, undashed strokes, the
  /// stroke width and its inset (Flutter's BorderSide.strokeInset: the
  /// whole width inside, half centred, none outside); null otherwise.
  (List<String>, double, double)? _ruledSides() {
    final d = decoration;
    if (d.strokeSides == api.StrokeSides.all || !d.radius.isZero || d.shape == api.DecorationShape.circle ||
        d.dashPattern.any((v) => v > 0)) {
      return null;
    }
    final strokes = d.visibleStrokes.toList();
    if (strokes.isEmpty || d.strokeWidth <= 0 || strokes.any((p) => p.type != api.PaintType.solid)) return null;
    final w = d.strokeWidth;
    final inset = switch (d.strokeAlign) {
      api.StrokeAlign.inside => w,
      api.StrokeAlign.center => w / 2,
      api.StrokeAlign.outside => 0.0,
    };
    return (d.strokeSides.sides.toList(), w, inset);
  }

  void _fill(Canvas canvas, RRect rrect, api.Paint p) {
    if (!p.visible) return;
    if (p.type == api.PaintType.image) {
      // Foreground images aren't drawn.
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
      // A radius given as a share of the shortest side (Flutter's
      // RadialGradient), centered where the transform puts the center (the
      // box's without one); else the transform's: to the box's edge.
      api.PaintType.radial when p.radius != null =>
        ui.Gradient.radial(at(0.5, 0.5), p.radius! * rect.shortestSide, colors, stops, tile),
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
