import 'dart:ui' as ui;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/widgets.dart';
import 'package:path_parsing/path_parsing.dart';

import '../../../codelessly_sdk.dart';

/// Draws a [PathNode]: its SVG path scaled from its view box to the node's
/// size, filled with its solid fills and outlined with its strokes (weight,
/// cap, dashes), trimmed to [PathNode.trimStart]..[PathNode.trimEnd] of its
/// length. `pathData`, `trimStart` and `trimEnd` can be bound; a bound trim
/// eases to new values over the node's [BaseNode.transitionMs].
class PassivePathTransformer extends NodeWidgetTransformer<PathNode> {
  PassivePathTransformer(super.getNode, super.manager);

  @override
  Widget buildWidget(
    PathNode node,
    BuildContext context,
    WidgetBuildSettings settings,
  ) {
    final ScopedValues scope = ScopedValues.of(context);
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
    return SizedBox(
      width: node.basicBoxLocal.width,
      height: node.basicBoxLocal.height,
      child: TweenAnimationBuilder<Offset>(
        tween: Tween(end: Offset(start, end)),
        duration: Duration(
          milliseconds: settings.isPreview ? 0 : node.transitionMs,
        ),
        curve: Curves.easeInOut,
        builder: (context, trim, _) => CustomPaint(
          painter: PathNodePainter(
            data: data,
            viewBox: node.viewBoxWidth != null && node.viewBoxHeight != null
                ? Size(node.viewBoxWidth!, node.viewBoxHeight!)
                : null,
            fills: [
              for (final PaintModel paint in node.fills)
                if (paint.visible && paint.toFlutterColor() != null)
                  paint.toFlutterColor()!,
            ],
            strokes: [
              for (final PaintModel paint in node.strokes)
                if (paint.visible && paint.toFlutterColor() != null)
                  paint.toFlutterColor()!,
            ],
            strokeWeight: node.strokeWeight,
            cap: switch (node.strokeCap) {
              StrokeCapEnum.round => StrokeCap.round,
              StrokeCapEnum.square => StrokeCap.square,
              _ => StrokeCap.butt,
            },
            dashes: node.dashPattern,
            trimStart: trim.dx,
            trimEnd: trim.dy,
          ),
        ),
      ),
    );
  }
}

/// Paints SVG path [data] (see [PassivePathTransformer]).
class PathNodePainter extends CustomPainter {
  /// Creates a [PathNodePainter].
  PathNodePainter({
    required this.data,
    this.viewBox,
    this.fills = const [],
    this.strokes = const [],
    this.strokeWeight = 2,
    this.cap = StrokeCap.round,
    this.dashes = const [],
    this.trimStart = 0,
    this.trimEnd = 1,
  });

  final String data;
  final Size? viewBox;
  final List<Color> fills;
  final List<Color> strokes;
  final double strokeWeight;
  final StrokeCap cap;
  final List<double> dashes;
  final double trimStart;
  final double trimEnd;

  static final Map<String, ui.Path?> _cache = {};

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
    ui.Path? path = parse(data);
    if (path == null) return;
    if (viewBox case final Size box when box.width > 0 && box.height > 0) {
      path = path.transform(
        (Matrix4.identity()..scaleByDouble(
              size.width / box.width,
              size.height / box.height,
              1,
              1,
            ))
            .storage,
      );
    }
    for (final Color color in fills) {
      canvas.drawPath(path, Paint()..color = color);
    }
    if (strokes.isEmpty || strokeWeight <= 0) return;
    final bool whole = trimStart <= 0 && trimEnd >= 1 && dashes.isEmpty;
    final ui.Path outline = whole
        ? path
        : trim(path, trimStart, trimEnd, dashes);
    for (final Color color in strokes) {
      canvas.drawPath(
        outline,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWeight
          ..strokeCap = cap
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  @override
  bool shouldRepaint(PathNodePainter old) =>
      old.data != data ||
      old.viewBox != viewBox ||
      !_sameColors(old.fills, fills) ||
      !_sameColors(old.strokes, strokes) ||
      old.strokeWeight != strokeWeight ||
      old.cap != cap ||
      old.trimStart != trimStart ||
      old.trimEnd != trimEnd ||
      old.dashes.join(',') != dashes.join(',');

  static bool _sameColors(List<Color> a, List<Color> b) =>
      a.length == b.length &&
      [for (int i = 0; i < a.length; i++) a[i] == b[i]].every((same) => same);
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
