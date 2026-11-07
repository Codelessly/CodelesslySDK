// SVG path data (`M 0 0 C 40 -80 ...`) → a measured Flutter path, for
// motion paths and drag tracks: where a node is at a progress along it.
import 'dart:ui';

/// A parsed path: its metrics and where it starts. Positions are relative
/// to the start, since a node on a path starts where its layout put it.
class MeasuredPath {
  MeasuredPath._(this.metrics, this.start) : length = metrics.fold(0.0, (s, m) => s + m.length);

  final List<PathMetric> metrics;
  final Offset start;
  final double length;

  static final Map<String, MeasuredPath?> _cache = {};

  /// [data] parsed (cached), or null when it draws nothing or doesn't parse.
  static MeasuredPath? of(String data) => _cache.putIfAbsent(data, () {
    if (_cache.length > 256) _cache.clear();
    final parsed = parseSvgPath(data);
    if (parsed == null) return null;
    final metrics = parsed.$1.computeMetrics().toList();
    return metrics.isEmpty ? null : MeasuredPath._(metrics, parsed.$2);
  });

  /// The offset from the start and the direction (radians) at [progress]
  /// (0–1) of the length.
  (Offset, double)? at(double progress) {
    if (length <= 0) return null;
    var distance = progress.clamp(0.0, 1.0) * length;
    for (final m in metrics) {
      if (distance <= m.length || identical(m, metrics.last)) {
        final t = m.getTangentForOffset(distance.clamp(0.0, m.length));
        if (t == null) return null;
        return (t.position - start, -t.angle);
      }
      distance -= m.length;
    }
    return null;
  }
}

/// SVG path data as a [Path] and its first point; null when it doesn't
/// parse.
(Path, Offset)? parseSvgPath(String data) {
  final tokens = RegExp(r'[MmLlHhVvCcSsQqTtAaZz]|[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?').allMatches(data);
  final list = [for (final t in tokens) t.group(0)!];
  final path = Path();
  Offset? first;
  var i = 0;
  var cmd = '';
  var cur = Offset.zero, sub = Offset.zero;
  Offset? lastCtrl;
  var lastCmd = '';
  bool isCmd(String s) => RegExp(r'^[A-Za-z]$').hasMatch(s);
  double num() {
    if (i >= list.length || isCmd(list[i])) throw const FormatException('number expected');
    return double.parse(list[i++]);
  }

  try {
    while (i < list.length) {
      final at = i;
      if (isCmd(list[i])) {
        cmd = list[i++];
      } else if (cmd.isEmpty) {
        return null;
      }
      final rel = cmd == cmd.toLowerCase();
      Offset pt(double x, double y) => rel ? cur + Offset(x, y) : Offset(x, y);
      switch (cmd.toUpperCase()) {
        case 'M':
          cur = pt(num(), num());
          sub = cur;
          first ??= cur;
          path.moveTo(cur.dx, cur.dy);
          // Further pairs are lines.
          cmd = rel ? 'l' : 'L';
          lastCtrl = null;
        case 'L':
          cur = pt(num(), num());
          path.lineTo(cur.dx, cur.dy);
          lastCtrl = null;
        case 'H':
          final x = num();
          cur = Offset(rel ? cur.dx + x : x, cur.dy);
          path.lineTo(cur.dx, cur.dy);
          lastCtrl = null;
        case 'V':
          final y = num();
          cur = Offset(cur.dx, rel ? cur.dy + y : y);
          path.lineTo(cur.dx, cur.dy);
          lastCtrl = null;
        case 'C':
          final c1 = pt(num(), num()), c2 = pt(num(), num()), end = pt(num(), num());
          path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy);
          lastCtrl = c2;
          cur = end;
        case 'S':
          final c1 = lastCtrl != null && 'CS'.contains(lastCmd) ? cur * 2 - lastCtrl : cur;
          final c2 = pt(num(), num()), end = pt(num(), num());
          path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy);
          lastCtrl = c2;
          cur = end;
        case 'Q':
          final c = pt(num(), num()), end = pt(num(), num());
          path.quadraticBezierTo(c.dx, c.dy, end.dx, end.dy);
          lastCtrl = c;
          cur = end;
        case 'T':
          final c = lastCtrl != null && 'QT'.contains(lastCmd) ? cur * 2 - lastCtrl : cur;
          final end = pt(num(), num());
          path.quadraticBezierTo(c.dx, c.dy, end.dx, end.dy);
          lastCtrl = c;
          cur = end;
        case 'A':
          final rx = num(), ry = num(), rotation = num(), large = num() != 0, sweep = num() != 0;
          final end = pt(num(), num());
          path.arcToPoint(
            end,
            radius: Radius.elliptical(rx.abs(), ry.abs()),
            rotation: rotation,
            largeArc: large,
            clockwise: sweep,
          );
          cur = end;
          lastCtrl = null;
        case 'Z':
          path.close();
          cur = sub;
          lastCtrl = null;
        default:
          return null;
      }
      lastCmd = cmd.toUpperCase();
      // A number after Z.
      if (i == at) return null;
    }
  } on FormatException {
    return null;
  }
  return first == null ? null : (path, first);
}
