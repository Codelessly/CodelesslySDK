// What SDK 8.x's path painter added beyond plain fills and strokes: shadows
// along a path's outline (utils/path_shadow.dart) and a path split into its
// shapes, for per-shape gradients and colors (PathShapes in
// passive_path_transformer.dart).
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:path_parsing/path_parsing.dart';

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

/// The shapes of a path, each painted on its own by a per-shape gradient or
/// color. Every subpath (from an `M` to the next) is a shape, except one
/// lying inside the bounds of the shape before it (a hole, the counter of
/// an "O"), which joins that shape.
class PathShapes {
  PathShapes._(this.shapes);

  static final Map<(String, Size?, Size), PathShapes?> _cache = {};

  /// [data] split into shapes and scaled from [viewBox] to [size], or null
  /// when it can't be read. Cached by data, view box and size (the last 32).
  static PathShapes? of(String data, Size? viewBox, Size size) {
    final key = (data, viewBox, size);
    if (_cache.containsKey(key)) return _cache[key] = _cache.remove(key);
    if (_cache.length >= 32) _cache.remove(_cache.keys.first);
    return _cache[key] = parse(data, viewBox, size);
  }

  static PathShapes? parse(String data, Size? viewBox, Size size) {
    if (data.trim().isEmpty) return null;
    final proxy = _SubpathProxy();
    try {
      writeSvgPathDataToPath(data, proxy);
    } catch (_) {
      return null;
    }
    final Float64List? scale = viewBox != null && viewBox.width > 0 && viewBox.height > 0
        ? (Matrix4.identity()..scaleByDouble(size.width / viewBox.width, size.height / viewBox.height, 1, 1)).storage
        : null;
    final shapes = <PathShape>[];
    ui.Path? group;
    var groupBounds = Rect.zero;
    void flush() {
      final g = group;
      if (g != null) shapes.add(PathShape(path: g, bounds: groupBounds, local: g.shift(-groupBounds.topLeft)));
    }

    for (final raw in proxy.drawn) {
      final sub = scale == null ? raw : raw.transform(scale);
      final b = sub.getBounds();
      if (group != null &&
          b.left >= groupBounds.left - 0.01 &&
          b.top >= groupBounds.top - 0.01 &&
          b.right <= groupBounds.right + 0.01 &&
          b.bottom <= groupBounds.bottom + 0.01) {
        group.addPath(sub, Offset.zero);
        continue;
      }
      flush();
      group = sub;
      groupBounds = b;
    }
    flush();
    return PathShapes._(shapes);
  }

  /// The shapes in drawing order.
  final List<PathShape> shapes;

  final Map<String, List<(Color?, ui.Path)>> _byColor = {};

  /// The shapes merged into one path per color, shape `i` taking
  /// `colors[i % colors.length]` (null keeps the fill's color).
  List<(Color?, ui.Path)> byColor(List<Color?> colors) {
    if (colors.isEmpty) return const [];
    final key = colors.map((c) => c?.toARGB32()).join(',');
    if (_byColor[key] case final cached?) return cached;
    final paths = <Color?, ui.Path>{};
    for (var i = 0; i < shapes.length; i++) {
      (paths[colors[i % colors.length]] ??= ui.Path()).addPath(shapes[i].path, Offset.zero);
    }
    if (_byColor.length >= 8) _byColor.remove(_byColor.keys.first);
    return _byColor[key] = [for (final e in paths.entries) (e.key, e.value)];
  }

  /// Paints each shape with the paint [paintFor] gives for a box of the
  /// shape's size at the origin, the canvas moved to the shape: one shader
  /// per distinct shape size.
  void paintEach(Canvas canvas, Paint Function(Rect box) paintFor) {
    final paints = <Size, Paint>{};
    for (final shape in shapes) {
      final b = shape.bounds;
      final key = Size((b.width * 100).roundToDouble() / 100, (b.height * 100).roundToDouble() / 100);
      final paint = paints[key] ??= paintFor(Offset.zero & key);
      canvas
        ..save()
        ..translate(b.left, b.top)
        ..drawPath(shape.local, paint)
        ..restore();
    }
  }
}

/// One shape of [PathShapes].
class PathShape {
  const PathShape({required this.path, required this.bounds, required this.local});

  /// The shape where it is drawn.
  final ui.Path path;

  /// [path]'s bounds: the box a per-shape gradient is laid out in.
  final Rect bounds;

  /// [path] moved so [bounds] starts at the origin.
  final ui.Path local;
}

/// Collects each subpath of SVG path data as its own path.
class _SubpathProxy extends PathProxy {
  final List<ui.Path> subpaths = [];
  ui.Path? _current;
  bool _drawn = false, _closed = false;
  double _startX = 0, _startY = 0;

  ui.Path get _path {
    // Drawing on after a `Z` with no `M` starts a new subpath where the
    // closed one started.
    if (_closed || _current == null) moveTo(_startX, _startY);
    _drawn = true;
    return _current!;
  }

  @override
  void moveTo(double x, double y) {
    if (_current == null || _drawn) {
      _current = ui.Path();
      subpaths.add(_current!);
    } else {
      _current = ui.Path();
      subpaths.last = _current!;
    }
    _current!.moveTo(x, y);
    _startX = x;
    _startY = y;
    _drawn = false;
    _closed = false;
  }

  @override
  void lineTo(double x, double y) => _path.lineTo(x, y);

  @override
  void cubicTo(double x1, double y1, double x2, double y2, double x3, double y3) =>
      _path.cubicTo(x1, y1, x2, y2, x3, y3);

  @override
  void close() {
    _current?.close();
    _closed = true;
  }

  /// The subpaths that draw something (not a trailing `M` alone).
  List<ui.Path> get drawn => _current != null && !_drawn ? subpaths.sublist(0, subpaths.length - 1) : subpaths;
}
