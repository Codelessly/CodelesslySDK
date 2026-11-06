import 'dart:ui' as ui;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:path_parsing/path_parsing.dart';

import '../../../codelessly_sdk.dart';

/// Draws a [PathNode]: its SVG path scaled from its view box to the node's
/// size, filled with its fills (solid colours, linear, radial and sweep
/// gradients and images, in order, with their opacity and blend modes) and
/// outlined with its strokes (weight, cap, dashes), trimmed to
/// [PathNode.trimStart]..[PathNode.trimEnd] of its length. Its drop shadows
/// follow the path's outline (the fill and the stroke) and its inner
/// shadows are painted inside the filled path. `pathData`, `trimStart` and
/// `trimEnd` can be bound; a bound trim eases to new values over the node's
/// [BaseNode.transitionMs].
class PassivePathTransformer extends NodeWidgetTransformer<PathNode> {
  PassivePathTransformer(super.getNode, super.manager);

  @override
  Widget buildWidget(
    PathNode node,
    BuildContext context,
    WidgetBuildSettings settings,
  ) {
    // On the design canvas (no reactions) bindings read the editor's preview
    // values, as the node's bound `stroke` and `fill` do (see
    // `PassiveNodeTransformerManager.applyStyleOverrides`), so a
    // `stroke-paint-<id>` or `pathData` binding previews the same way.
    final ScopedValues scope =
        (settings.withReactions
            ? null
            : VariablePreview.scopeOf(node, context: context)) ??
        ScopedValues.of(context);
    T? bound<T extends Object>(String property) =>
        node.variables.containsKey(property)
        ? PropertyValueDelegate.getPropertyValue<T>(
            node,
            property,
            scopedValues: scope,
          )
        : null;
    double number(String property, double fallback) {
      final Object? value = bound<Object>(property);
      final double? n = switch (value) {
        num v => v.toDouble(),
        String s => double.tryParse(s.trim()),
        _ => null,
      };
      return (n == null || !n.isFinite ? fallback : n).clamp(0, 1).toDouble();
    }

    final String data = bound<Object>('pathData')?.toString() ?? node.pathData;
    final double start = number('trimStart', node.trimStart);
    final double end = number('trimEnd', node.trimEnd);
    final Size? viewBox =
        node.viewBoxWidth != null && node.viewBoxHeight != null
        ? Size(node.viewBoxWidth!, node.viewBoxHeight!)
        : null;
    final List<PaintModel> visibleFills = [
      for (final PaintModel paint in node.fills)
        if (paint.visible) paint,
    ];
    // Image fills are built as widgets (they load), so with one the fills
    // are laid out as the other shapes lay theirs out, clipped to the path,
    // between the shadows and the strokes.
    final bool imageFills = visibleFills.any(
      (paint) => paint.type == PaintType.image,
    );
    final List<PathFill> fills = imageFills
        ? const []
        : [
            for (final PaintModel paint in visibleFills)
              ?PathFill.of(node, paint, 'fill-${paint.id}', scope),
          ];
    final List<PathFill> strokes = [
      for (final PaintModel paint in node.strokes)
        if (paint.visible)
          ?PathFill.of(node, paint, 'stroke-paint-${paint.id}', scope),
    ];
    final List<BoxShadow> shadows = retrieveBoxShadow(node, scope);
    final List<BoxShadow> innerShadows = retrieveInnerShadows(node, scope);

    PathNodePainter painter(Offset trim, PathNodeLayer layer) =>
        PathNodePainter(
          data: data,
          viewBox: viewBox,
          fills: fills,
          strokes: strokes,
          shadows: shadows,
          innerShadows: innerShadows,
          filled: visibleFills.isNotEmpty,
          layer: layer,
          strokeWeight: node.strokeWeight,
          cap: switch (node.strokeCap) {
            StrokeCapEnum.round => StrokeCap.round,
            StrokeCapEnum.square => StrokeCap.square,
            _ => StrokeCap.butt,
          },
          join: switch (node.strokeJoin) {
            StrokeJoinEnum.miter => StrokeJoin.miter,
            StrokeJoinEnum.bevel => StrokeJoin.bevel,
            StrokeJoinEnum.round => StrokeJoin.round,
          },
          dashes: node.dashPattern,
          trimStart: trim.dx,
          trimEnd: trim.dy,
        );

    return SizedBox(
      width: node.basicBoxLocal.width,
      height: node.basicBoxLocal.height,
      child: TweenAnimationBuilder<Offset>(
        tween: Tween(end: Offset(start, end)),
        duration: Duration(
          milliseconds: settings.isPreview ? 0 : node.transitionMs,
        ),
        curve: Curves.easeInOut,
        builder: (context, trim, _) => !imageFills
            ? CustomPaint(painter: painter(trim, PathNodeLayer.all))
            : CustomPaint(
                painter: painter(trim, PathNodeLayer.below),
                foregroundPainter: painter(trim, PathNodeLayer.above),
                child: ClipPath(
                  clipper: PathNodeClipper(data: data, viewBox: viewBox),
                  child: Stack(
                    fit: StackFit.expand,
                    children: buildFills(
                      node,
                      useInk: false,
                      obscureImages: settings.obscureImages,
                      settings: settings,
                      scopedValues: scope,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

/// A solid colour or a gradient that fills or strokes a [PathNodePainter]'s
/// path, with its blend mode.
@immutable
class PathFill {
  /// A fill of one [color].
  const PathFill.color(Color this.color, {this.blendMode = BlendMode.srcOver})
    : gradient = null;

  /// A fill of [gradient], laid out in the node's box.
  const PathFill.gradient(
    Gradient this.gradient, {
    this.blendMode = BlendMode.srcOver,
  }) : color = null;

  /// The fill [paint] of [node] gives (a solid can be bound as [property]),
  /// or null for one a path can't paint (an image, an emoji, a diamond
  /// gradient).
  static PathFill? of(
    BaseNode node,
    PaintModel paint,
    String property,
    ScopedValues scopedValues,
  ) {
    final BlendMode blendMode = paint.blendMode.flutterBlendMode;
    switch (paint.type) {
      case PaintType.solid:
        final PaintModel? bound =
            PropertyValueDelegate.getPropertyValue<PaintModel>(
              node,
              property,
              scopedValues: scopedValues,
            );
        final Color? color = (bound ?? paint).toFlutterColor();
        return color == null
            ? null
            : PathFill.color(color, blendMode: blendMode);
      case PaintType.gradientLinear:
      case PaintType.gradientRadial:
      case PaintType.gradientAngular:
      case PaintType.gradientDiamond:
        final Gradient? gradient = retrieveGradient(paint);
        return gradient == null
            ? null
            : PathFill.gradient(gradient, blendMode: blendMode);
      case PaintType.image:
      case PaintType.emoji:
        return null;
    }
  }

  /// The colour, for a solid fill.
  final Color? color;

  /// The gradient, for a gradient fill.
  final Gradient? gradient;

  /// How the fill blends with what is painted under it.
  final BlendMode blendMode;

  /// A paint of this fill for a node whose box is [bounds].
  Paint toPaint(Rect bounds) {
    final Paint paint = Paint()..blendMode = blendMode;
    if (gradient case final Gradient gradient) {
      paint.shader = gradient.createShader(bounds);
    } else {
      paint.color = color!;
    }
    return paint;
  }

  @override
  bool operator ==(Object other) =>
      other is PathFill &&
      other.color == color &&
      other.gradient == gradient &&
      other.blendMode == blendMode;

  @override
  int get hashCode => Object.hash(color, gradient, blendMode);
}

/// What part of a path node a [PathNodePainter] paints.
enum PathNodeLayer {
  /// Everything.
  all,

  /// The drop shadows and the fills.
  below,

  /// The inner shadows and the strokes.
  above,
}

/// Clips to a path node's path, scaled from its view box.
class PathNodeClipper extends CustomClipper<ui.Path> {
  /// Creates a [PathNodeClipper].
  const PathNodeClipper({required this.data, this.viewBox});

  /// The SVG path data.
  final String data;

  /// The box the path's coordinates are in, or null for logical pixels.
  final Size? viewBox;

  @override
  ui.Path getClip(Size size) =>
      PathNodePainter.shape(data, viewBox, size) ?? ui.Path();

  @override
  bool shouldReclip(PathNodeClipper oldClipper) =>
      oldClipper.data != data || oldClipper.viewBox != viewBox;
}

/// Paints SVG path [data] (see [PassivePathTransformer]).
class PathNodePainter extends CustomPainter {
  /// Creates a [PathNodePainter].
  PathNodePainter({
    required this.data,
    this.viewBox,
    this.fills = const [],
    this.strokes = const [],
    this.shadows = const [],
    this.innerShadows = const [],
    bool? filled,
    this.layer = PathNodeLayer.all,
    this.strokeWeight = 2,
    this.cap = StrokeCap.round,
    this.join = StrokeJoin.round,
    this.dashes = const [],
    this.trimStart = 0,
    this.trimEnd = 1,
  }) : filled = filled ?? fills.isNotEmpty;

  final String data;
  final Size? viewBox;

  /// The fills, painted in order (the first at the bottom).
  final List<PathFill> fills;

  /// The strokes, painted in order over the fills.
  final List<PathFill> strokes;

  /// Drop shadows, cast by the filled path (when [filled]) and the stroke.
  final List<BoxShadow> shadows;

  /// Inner shadows, painted inside the filled path over the fills.
  final List<BoxShadow> innerShadows;

  /// Whether the path is filled (it has fills, maybe painted by others):
  /// its drop and inner shadows follow the fill, not only the stroke.
  final bool filled;

  /// What this painter paints.
  final PathNodeLayer layer;

  final double strokeWeight;
  final StrokeCap cap;
  final StrokeJoin join;
  final List<double> dashes;
  final double trimStart;
  final double trimEnd;

  static final Map<String, ui.Path?> _cache = {};

  /// [data] as a path scaled from [viewBox] to [size], or null when it
  /// can't be read.
  static ui.Path? shape(String data, Size? viewBox, Size size) {
    final ui.Path? path = parse(data);
    if (path == null) return null;
    if (viewBox case final Size box when box.width > 0 && box.height > 0) {
      return path.transform(
        (Matrix4.identity()..scaleByDouble(
              size.width / box.width,
              size.height / box.height,
              1,
              1,
            ))
            .storage,
      );
    }
    return path;
  }

  /// [data] as a path, or null when it can't be read.
  static ui.Path? parse(String data) => _cache.putIfAbsent(data, () {
    if (data.trim().isEmpty) return null;
    try {
      final _Proxy proxy = _Proxy();
      writeSvgPathDataToPath(data, proxy);
      return proxy.path;
    } catch (_) {
      return null;
    }
  });

  /// The part of [path] from [start] to [end] of its length (fractions), cut
  /// into dashes of [dashes] (on, off, on, ...) when given.
  static ui.Path trim(
    ui.Path path,
    double start,
    double end, [
    List<double> dashes = const [],
  ]) {
    final List<ui.PathMetric> metrics = path.computeMetrics().toList();
    final double total = metrics.fold(0, (sum, m) => sum + m.length);
    final double from = total * start.clamp(0, 1);
    final double to = total * end.clamp(0, 1);
    final ui.Path out = ui.Path();
    if (to <= from) return out;
    final bool dashed =
        dashes.isNotEmpty &&
        dashes.any((d) => d > 0) &&
        dashes.every((d) => d >= 0);
    double offset = 0;
    int dash = 0;
    double dashLeft = dashed ? dashes[0] : double.infinity;
    for (final ui.PathMetric metric in metrics) {
      final double a = (from - offset).clamp(0, metric.length);
      final double b = (to - offset).clamp(0, metric.length);
      if (!dashed) {
        if (b > a) out.addPath(metric.extractPath(a, b), Offset.zero);
      } else {
        // Walk the dash pattern from the start of the whole outline, so
        // dashes stay put while it trims.
        double d = 0;
        while (d < metric.length) {
          final double step = dashLeft.clamp(0, metric.length - d).toDouble();
          final bool on = dash.isEven;
          final double s = (d).clamp(a, b), e = (d + step).clamp(a, b);
          if (on && e > s) out.addPath(metric.extractPath(s, e), Offset.zero);
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

  @override
  void paint(Canvas canvas, Size size) {
    final ui.Path? path = shape(data, viewBox, size);
    if (path == null) return;
    final bool stroked = strokes.isNotEmpty && strokeWeight > 0;
    final bool whole = trimStart <= 0 && trimEnd >= 1 && dashes.isEmpty;
    final ui.Path outline = !stroked || whole
        ? path
        : trim(path, trimStart, trimEnd, dashes);
    final Rect bounds = Offset.zero & size;
    if (layer != PathNodeLayer.above) {
      paintPathShadows(
        canvas,
        path,
        shadows,
        filled: filled,
        stroke: outline,
        strokeWidth: stroked ? strokeWeight : 0,
        cap: cap,
        join: join,
      );
      // Blending fills blend with the fills under them, not with what is
      // painted under the node.
      final bool blends = fills.any((f) => f.blendMode != BlendMode.srcOver);
      if (blends) canvas.saveLayer(null, Paint());
      for (final PathFill fill in fills) {
        canvas.drawPath(path, fill.toPaint(bounds));
      }
      if (blends) canvas.restore();
    }
    if (layer == PathNodeLayer.below) return;
    if (filled) paintPathInnerShadows(canvas, path, innerShadows);
    if (!stroked) return;
    for (final PathFill stroke in strokes) {
      canvas.drawPath(
        outline,
        stroke.toPaint(bounds)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWeight
          ..strokeCap = cap
          ..strokeJoin = join,
      );
    }
  }

  @override
  bool shouldRepaint(PathNodePainter old) =>
      old.data != data ||
      old.viewBox != viewBox ||
      !const ListEquality<PathFill>().equals(old.fills, fills) ||
      !const ListEquality<PathFill>().equals(old.strokes, strokes) ||
      !const ListEquality<BoxShadow>().equals(old.shadows, shadows) ||
      !const ListEquality<BoxShadow>().equals(old.innerShadows, innerShadows) ||
      old.filled != filled ||
      old.layer != layer ||
      old.strokeWeight != strokeWeight ||
      old.join != join ||
      old.cap != cap ||
      old.trimStart != trimStart ||
      old.trimEnd != trimEnd ||
      old.dashes.join(',') != dashes.join(',');
}

class _Proxy extends PathProxy {
  final ui.Path path = ui.Path();

  @override
  void moveTo(double x, double y) => path.moveTo(x, y);

  @override
  void lineTo(double x, double y) => path.lineTo(x, y);

  @override
  void cubicTo(
    double x1,
    double y1,
    double x2,
    double y2,
    double x3,
    double y3,
  ) => path.cubicTo(x1, y1, x2, y2, x3, y3);

  @override
  void close() => path.close();
}
