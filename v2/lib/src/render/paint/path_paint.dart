// SVG paths: the `path` widget (a vector shape) and a box's `path` prop (a
// box drawn as a shape), painted as SDK 8.x's PathNodePainter and
// PassiveRectangleWidget did.
import 'dart:ui' as ui;

import 'package:codelessly_api_v2/codelessly_api.dart' as api;
import 'package:codelessly_api_v2/codelessly_api.dart' show Node, BoxProps, PathProps;
import 'package:flutter/rendering.dart';
import 'package:path_parsing/path_parsing.dart';

import '../convert.dart';
import '../recipe.dart';
import 'image_fill.dart';
import 'node_paint.dart';

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

/// [path] in dashes of [length] and gaps of [gap] (SDK 8.x's `dashPath`:
/// the distance carries over from one contour to the next).
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
    showImages(v?.type == 'box' ? v!.decoration.fills.map(imageUrlOf) : const []);
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

  /// The `path` widget (PathNodePainter): its data scaled from its view box
  /// to the size, filled with its solid fills and stroked with its solid
  /// strokes, trimmed and dashed.
  void _paintVector(Canvas canvas, Node n) {
    var path = parseSvgPath(n.prop(PathProps.data));
    if (path == null) return;
    final box = n.prop(PathProps.viewBox);
    if (box != null && box[0] > 0 && box[1] > 0) {
      path = path.transform((Matrix4.identity()..scaleByDouble(size.width / box[0], size.height / box[1], 1, 1)).storage);
    }
    final d = n.decoration;
    for (final p in d.visibleFills) {
      if (p.type != api.PaintType.solid || p.color == null) continue;
      canvas.drawPath(path, Paint()..color = p.effectiveColor!.flutter);
    }
    final strokes = [for (final p in d.visibleStrokes) if (p.type == api.PaintType.solid && p.color != null) p];
    if (strokes.isEmpty) return;
    final start = n.prop(PathProps.trimStart), end = n.prop(PathProps.trimEnd);
    final whole = start <= 0 && end >= 1 && d.dashPattern.isEmpty;
    final outline = whole ? path : trimPath(path, start, end, d.dashPattern);
    for (final p in strokes) {
      canvas.drawPath(
          outline,
          Paint()
            ..color = p.effectiveColor!.flutter
            ..style = PaintingStyle.stroke
            ..strokeWidth = d.strokeWidth
            ..strokeCap = _cap(d.strokeCap)
            ..strokeJoin = _join(n.prop(PathProps.strokeJoin)));
    }
  }

  /// A box drawn as its path (PassiveRectangleWidget with a path): its
  /// fills (and foreground fills) clipped to the path, its strokes along
  /// it, centered; no shadows, no clip.
  void _paintBox(Canvas canvas, Node n) {
    final path = parseSvgPath(n.prop(BoxProps.path));
    final d = n.decoration;
    final rect = Offset.zero & size;
    final rrect = d.radius.flutter.toRRect(rect);
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
