// SVG paths: the `path` widget (a vector shape) and a box's `path` prop (a
// box drawn as a shape).
import 'dart:ui' as ui;

import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_api/codelessly_api.dart' show Node, BoxProps, PathProps;
import 'package:flutter/rendering.dart';
import 'package:path_parsing/path_parsing.dart';

import '../convert.dart';
import '../recipe.dart';
import 'image_fill.dart';
import 'node_paint.dart';
import 'path_shapes.dart';

final Map<String, ui.Path?> _parsed = {};

/// SVG path [data] as a path, or null when it's empty or can't be read.
ui.Path? parseSvgPath(String data) {
  if (_parsed.length > 512) _parsed.clear();
  return _parsed.putIfAbsent(data, () {
    if (data.trim().isEmpty) return null;
    try {
      final proxy = _PathProxy();
      writeSvgPathDataToPath(data, proxy);
      return proxy.path;
    } catch (_) {
      return null;
    }
  });
}

class _PathProxy extends PathProxy {
  final ui.Path path = ui.Path();
  @override
  void moveTo(double x, double y) => path.moveTo(x, y);
  @override
  void lineTo(double x, double y) => path.lineTo(x, y);
  @override
  void cubicTo(double x1, double y1, double x2, double y2, double x3, double y3) =>
      path.cubicTo(x1, y1, x2, y2, x3, y3);
  @override
  void close() => path.close();
}

/// The part of [path] from [start] to [end] of its length (fractions), cut
/// into [dashes] (on, off, ...) counted from the start of the whole outline.
ui.Path trimPath(ui.Path path, double start, double end, [List<double> dashes = const []]) {
  final metrics = path.computeMetrics().toList();
  final total = metrics.fold<double>(0, (sum, m) => sum + m.length);
  final from = total * start.clamp(0, 1), to = total * end.clamp(0, 1);
  final out = ui.Path();
  if (to <= from) return out;
  final dashed = dashes.isNotEmpty && dashes.any((d) => d > 0) && dashes.every((d) => d >= 0);
  var offset = 0.0, dash = 0;
  var dashLeft = dashed ? dashes[0] : double.infinity;
  for (final metric in metrics) {
    final a = (from - offset).clamp(0, metric.length).toDouble();
    final b = (to - offset).clamp(0, metric.length).toDouble();
    if (!dashed) {
      if (b > a) out.addPath(metric.extractPath(a, b), Offset.zero);
    } else {
      var d = 0.0;
      while (d < metric.length) {
        final step = dashLeft.clamp(0, metric.length - d).toDouble();
        final s = d.clamp(a, b), e = (d + step).clamp(a, b);
        if (dash.isEven && e > s) out.addPath(metric.extractPath(s, e), Offset.zero);
        d += step;
        dashLeft -= step;
        if (dashLeft <= 0) {
          dash = (dash + 1) % dashes.length;
          dashLeft = dashes[dash] <= 0 ? 0.0001 : dashes[dash];
        }
      }
    }
    offset += metric.length;
  }
  return out;
}

/// [path] in dashes of [length] and gaps of [gap] (the distance carries over from one contour to the next).
ui.Path dashPath(ui.Path path, double length, [double? gap]) {
  gap ??= length;
  final dest = ui.Path();
  var distance = 0.0;
  for (final metric in path.computeMetrics()) {
    var draw = true;
    while (distance < metric.length) {
      if (draw) {
        dest.addPath(metric.extractPath(distance, distance + length), Offset.zero);
        distance += length;
      } else {
        distance += gap;
      }
      draw = !draw;
    }
  }
  return dest;
}

StrokeCap _cap(api.StrokeCap c) => StrokeCap.values.byName(c.name);
StrokeJoin _join(api.StrokeJoin j) => StrokeJoin.values.byName(j.name);

/// Paints a node's SVG path at the size its parent gives it.
class RenderShapePath extends RenderBox with ImageClient {
  Node? _node;
  Node? get node => _node;
  set node(Node? v) {
    if (identical(v, _node)) return;
    _node = v;
    showImages(v == null ? const [] : v.decoration.fills.where((p) => p.visible).map(imageUrlOf));
    markNeedsPaint();
  }

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      constraints.biggest.isFinite ? constraints.biggest : constraints.smallest;

  @override
  bool hitTestSelf(Offset position) => false;

  @override
  void paint(PaintingContext context, Offset offset) {
    final n = _node;
    if (n == null) return;
    final canvas = context.canvas;
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    if (n.type == 'path') {
      _paintVector(canvas, n);
    } else {
      _paintBox(canvas, n);
    }
    canvas.restore();
  }

  /// The `path` widget: its data scaled from
  /// its view box to the size; its drop shadows along the outline (fill and
  /// stroke); its fills in order (solid colors, gradients, images clipped to
  /// the path), each gradient in every shape with `gradientPerSubpath` and
  /// the solid ones colored shape by shape with `subpathColors`; its inner
  /// shadows; its strokes, trimmed and dashed.
  void _paintVector(Canvas canvas, Node n) {
    final data = n.prop(PathProps.data);
    var path = parseSvgPath(data);
    if (path == null) return;
    final box = n.prop(PathProps.viewBox);
    final viewBox = box != null && box[0] > 0 && box[1] > 0 ? Size(box[0], box[1]) : null;
    if (viewBox != null) {
      path = path.transform(
          (Matrix4.identity()..scaleByDouble(size.width / viewBox.width, size.height / viewBox.height, 1, 1)).storage);
    }
    final d = n.decoration;
    final bounds = Offset.zero & size;
    final fills = d.fills.where((p) => p.visible && (p.type != api.PaintType.solid || p.color != null)).toList();
    final strokes = [for (final p in d.visibleStrokes) if (p.type != api.PaintType.image && (p.isGradient || p.color != null)) p];
    final stroked = strokes.isNotEmpty && d.strokeWidth > 0;
    final start = n.prop(PathProps.trimStart), end = n.prop(PathProps.trimEnd);
    final whole = start <= 0 && end >= 1 && d.dashPattern.isEmpty;
    final outline = !stroked || whole ? path : trimPath(path, start, end, d.dashPattern);
    final cap = _cap(d.strokeCap), join = _join(n.prop(PathProps.strokeJoin));
    final filled = d.fills.any((p) => p.visible);
    paintPathShadows(canvas, path, _shadows(d, api.EffectType.dropShadow),
        filled: filled, stroke: outline, strokeWidth: stroked ? d.strokeWidth : 0, cap: cap, join: join);

    PathShapes? shapes() => PathShapes.of(data, viewBox, size);
    final colors = n.prop(PathProps.subpathColors).map((c) => c?.flutter).toList();
    // Blending fills blend with the fills under them, not with what is under
    // the node.
    final blends = fills.any((f) => f.blendMode != api.BlendMode.srcOver);
    if (blends) canvas.saveLayer(null, Paint());
    for (final f in fills) {
      if (f.type == api.PaintType.image) {
        canvas.save();
        canvas.clipPath(path);
        paintImageFill(canvas, RRect.fromRectAndRadius(bounds, Radius.zero), f, this);
        canvas.restore();
      } else if (f.isGradient && f.gradientPerSubpath) {
        shapes()?.paintEach(canvas, (r) => RenderNodePaint.paintFor(f, r));
      } else if (!f.isGradient && colors.isNotEmpty) {
        final base = f.effectiveColor!.flutter;
        for (final (color, part) in shapes()?.byColor(colors) ?? const <(Color?, ui.Path)>[]) {
          canvas.drawPath(
              part,
              Paint()
                ..blendMode = blendMode(f.blendMode)
                ..color = color == null ? base : color.withValues(alpha: color.a * base.a));
        }
      } else {
        canvas.drawPath(path, RenderNodePaint.paintFor(f, bounds));
      }
    }
    if (blends) canvas.restore();
    if (filled) paintPathInnerShadows(canvas, path, _shadows(d, api.EffectType.innerShadow));
    if (!stroked) return;
    Paint strokePaint(api.Paint p, Rect r) => RenderNodePaint.paintFor(p, r)
      ..style = PaintingStyle.stroke
      ..strokeWidth = d.strokeWidth
      ..strokeCap = cap
      ..strokeJoin = join;
    for (final p in strokes) {
      // A trimmed or dashed outline is one line along the whole path, so its
      // gradient spans the box.
      if (p.isGradient && p.gradientPerSubpath && identical(outline, path)) {
        shapes()?.paintEach(canvas, (r) => strokePaint(p, r));
      } else {
        canvas.drawPath(outline, strokePaint(p, bounds));
      }
    }
  }

  /// The visible shadows of [type] in [d], as Flutter's.
  static List<BoxShadow> _shadows(api.Decoration d, api.EffectType type) =>
      [for (final e in d.effects) if (e.visible && e.type == type) boxShadow(e)];

  /// A box drawn as its path (PassiveRectangleWidget with a path): its drop
  /// shadows following the path (its fill and its stroke), its fills (and
  /// foreground fills) clipped to the path, its strokes along it, centered;
  /// no clip.
  void _paintBox(Canvas canvas, Node n) {
    final path = parseSvgPath(n.prop(BoxProps.path));
    final d = n.decoration;
    final rect = Offset.zero & size;
    final rrect = d.radius.flutter.toRRect(rect);
    if (path != null) {
      final stroked = d.strokeWidth > 0 && d.strokes.any((p) => p.visible);
      paintPathShadows(canvas, path, _shadows(d, api.EffectType.dropShadow),
          filled: d.fills.any((p) => p.visible),
          strokeWidth: stroked ? d.strokeWidth : 0,
          cap: _cap(d.strokeCap),
          join: _join(n.prop(BoxProps.strokeJoin)));
    }
    void fills(Iterable<api.Paint> paints, {required bool images}) {
      final visible = paints.where((p) => p.visible).toList();
      if (visible.isEmpty) return;
      canvas.save();
      canvas.clipPath(path ?? ui.Path());
      for (final p in visible) {
        if (p.type == api.PaintType.image) {
          if (images) paintImageFill(canvas, rrect, p, this);
        } else {
          canvas.drawRRect(rrect, RenderNodePaint.paintFor(p, rect));
        }
      }
      canvas.restore();
    }

    fills(d.fills, images: true);
    if (path != null && d.strokeWidth > 0) {
      final dashes = d.dashPattern.where((v) => v > 0).toList();
      final outline = dashes.isEmpty ? path : dashPath(path, dashes.first, dashes.length > 1 ? dashes[1] : null);
      for (final p in d.visibleStrokes) {
        final Color? color = p.isGradient
            ? (p.stops.isEmpty ? null : p.stops.first.color.multiplyOpacity(p.opacity).flutter)
            : p.effectiveColor?.flutter;
        if (color == null) continue;
        canvas.drawPath(
            outline,
            Paint()
              ..style = PaintingStyle.stroke
              ..color = color
              ..strokeWidth = d.strokeWidth
              ..strokeCap = _cap(d.strokeCap)
              ..strokeJoin = _join(n.prop(BoxProps.strokeJoin))
              ..strokeMiterLimit = n.prop(BoxProps.strokeMiterLimit));
      }
    }
    fills(d.foregroundFills, images: false);
  }
}

/// A `path` widget: SizedBox(design size) → the painted path.
void buildPath(NodeBuilder b, Node n, List<RenderBox> chain) {
  final c = BoxConstraints.tightFor(width: n.layout.width.value, height: n.layout.height.value);
  chain.add(b.obtain<RenderConstrainedBox>('pathSized', () => RenderConstrainedBox(additionalConstraints: c))
    ..additionalConstraints = c);
  chain.add(b.obtain<RenderShapePath>('shape', RenderShapePath.new)..node = n);
}

/// A box with a path: the shell's fit box → the painted path.
void buildBoxPath(NodeBuilder b, Node n, List<RenderBox> chain) {
  chain.add(b.fitBox('shellFit', n.layout.width.fit, n.layout.height.fit, Size(n.layout.width.value, n.layout.height.value)));
  chain.add(b.obtain<RenderShapePath>('shape', RenderShapePath.new)..node = n);
}
