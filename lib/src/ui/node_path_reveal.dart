import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/widgets.dart';

/// Reads a `strokePath.points` binding: a list of `[x, y]` lists or of maps
/// with `x` and `y`. Unreadable entries are skipped.
List<List<double>> readPathPoints(Object? value) {
  if (value is! List) return const [];
  double? number(Object? v) => switch (v) {
    final num n => n.toDouble(),
    final String s => double.tryParse(s.trim()),
    _ => null,
  };
  return [
    for (final Object? p in value)
      if (p is List && p.length >= 2 && number(p[0]) != null && number(p[1]) != null)
        [number(p[0])!, number(p[1])!]
      else if (p is Map && number(p['x']) != null && number(p['y']) != null)
        [number(p['x'])!, number(p['y'])!],
  ];
}

/// Draws [path] in [child]'s box, behind it or (with
/// [StrokePath.inFront]) over it. [points] override the path's own.
class StrokePathBox extends StatelessWidget {
  /// Creates a [StrokePathBox].
  const StrokePathBox({
    super.key,
    required this.path,
    required this.points,
    required this.child,
  });

  /// The path's settings.
  final StrokePath path;

  /// The points to draw through.
  final List<List<double>> points;

  /// The node's widget.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final StrokePathPainter painter = StrokePathPainter(path, points);
    return CustomPaint(
      painter: path.inFront ? null : painter,
      foregroundPainter: path.inFront ? painter : null,
      child: child,
    );
  }
}

/// Paints a [StrokePath] through [points] in the box it's given.
class StrokePathPainter extends CustomPainter {
  /// Creates a [StrokePathPainter].
  StrokePathPainter(this.path, this.points);

  /// The path's settings.
  final StrokePath path;

  /// The points.
  final List<List<double>> points;

  /// The path through [points] in a box of [size].
  Path pathFor(Size size) {
    Offset at(List<double> p) => Offset(
      path.xUnit == PathUnit.fraction ? p[0] * size.width : p[0],
      path.yUnit == PathUnit.fraction ? p[1] * size.height : p[1],
    );
    final Path out = Path();
    if (points.isEmpty) return out;
    Offset prev = at(points.first);
    out.moveTo(prev.dx, prev.dy);
    for (final List<double> p in points.skip(1)) {
      final Offset next = at(p);
      switch (path.curve) {
        case PathCurve.straight:
          out.lineTo(next.dx, next.dy);
        case PathCurve.vertical:
          final double midY = (prev.dy + next.dy) / 2;
          out.cubicTo(prev.dx, midY, next.dx, midY, next.dx, next.dy);
        case PathCurve.horizontal:
          final double midX = (prev.dx + next.dx) / 2;
          out.cubicTo(midX, prev.dy, midX, next.dy, next.dx, next.dy);
      }
      prev = next;
    }
    return out;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2 || path.width <= 0) return;
    final Paint paint = Paint()
      ..color = _color(path.color)
      ..style = PaintingStyle.stroke
      ..strokeWidth = path.width
      ..strokeCap = switch (path.cap) {
        PathCap.butt => StrokeCap.butt,
        PathCap.round => StrokeCap.round,
        PathCap.square => StrokeCap.square,
      }
      ..strokeJoin = StrokeJoin.round;
    final Path full = pathFor(size);
    final List<double> dash = [
      for (final double d in path.dash)
        if (d > 0) d,
    ];
    if (dash.isEmpty) {
      canvas.drawPath(full, paint);
      return;
    }
    for (final ui.PathMetric metric in full.computeMetrics()) {
      double distance = 0;
      int i = 0;
      while (distance < metric.length) {
        final double length = dash[i % dash.length];
        if (i.isEven) {
          canvas.drawPath(
            metric.extractPath(
              distance,
              math.min(distance + length, metric.length),
            ),
            paint,
          );
        }
        distance += length;
        i++;
      }
    }
  }

  static Color _color(String hex) {
    String h = hex.trim().replaceFirst('#', '');
    if (h.length == 6) h = 'FF$h';
    return Color(int.tryParse(h, radix: 16) ?? 0xFFFFFFFF);
  }

  @override
  bool shouldRepaint(StrokePathPainter oldDelegate) =>
      oldDelegate.path != path ||
      oldDelegate.points.toString() != points.toString();
}

/// Scrolls the scroll views around [child] so it shows (see
/// [RevealModel]): after it first appears when [when] is true, and each time
/// [when] turns true.
class RevealBox extends StatefulWidget {
  /// Creates a [RevealBox].
  const RevealBox({
    super.key,
    required this.reveal,
    required this.when,
    required this.child,
  });

  /// The reveal's settings.
  final RevealModel reveal;

  /// Whether to reveal now.
  final bool when;

  /// The node's widget.
  final Widget child;

  @override
  State<RevealBox> createState() => _RevealBoxState();
}

class _RevealBoxState extends State<RevealBox> {
  @override
  void initState() {
    super.initState();
    if (widget.when) _schedule();
  }

  @override
  void didUpdateWidget(RevealBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.when && !oldWidget.when) _schedule();
  }

  void _schedule() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (widget.reveal.delayMs > 0) {
        await Future<void>.delayed(
          Duration(milliseconds: widget.reveal.delayMs),
        );
      }
      if (!mounted) return;
      Scrollable.ensureVisible(
        context,
        alignment: widget.reveal.alignment.clamp(0, 1),
        duration: Duration(milliseconds: widget.reveal.durationMs),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
