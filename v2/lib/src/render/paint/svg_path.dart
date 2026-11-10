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

  /// Samples of the area swept about each focus asked for, as (distance
  /// along the path, area swept so far), for area pacing.
  final Map<Offset, List<(double, double)>> _areas = {};

  static const int _areaSamples = 1440;

  /// The offset from the start and the direction (radians) at [progress]
  /// (0–1) of the length, or with [byArea] of the area a line from [focus]
  /// (in the path's coordinates) sweeps: an orbit's equal areas.
  (Offset, double)? at(double progress, {bool byArea = false, Offset focus = Offset.zero}) {
    if (length <= 0) return null;
    final p = progress.clamp(0.0, 1.0);
    var distance = byArea ? _distanceForArea(p, focus) : p * length;
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

  /// The distance along the path at which a line from [focus] has swept
  /// [share] of the area it sweeps over the whole path.
  double _distanceForArea(double share, Offset focus) {
    final table = _areas.putIfAbsent(focus, () {
      final out = <(double, double)>[(0, 0)];
      Offset? last;
      var swept = 0.0, done = 0.0;
      for (final m in metrics) {
        final n = (_areaSamples * m.length / length).round().clamp(8, 1 << 20);
        for (var i = 0; i <= n; i++) {
          final d = m.length * i / n;
          final point = m.getTangentForOffset(d)?.position;
          if (point == null) continue;
          if (last != null) {
            final a = last - focus, b = point - focus;
            swept += (a.dx * b.dy - a.dy * b.dx).abs() / 2;
          }
          last = point;
          out.add((done + d, swept));
        }
        done += m.length;
      }
      return out;
    });
    final total = table.last.$2;
    if (total <= 0) return share * length;
    final target = share * total;
    var lo = 0, hi = table.length - 1;
    while (hi - lo > 1) {
      final mid = (lo + hi) >> 1;
      if (table[mid].$2 < target) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final (d0, a0) = table[lo];
    final (d1, a1) = table[hi];
    final f = a1 == a0 ? 0.0 : (target - a0) / (a1 - a0);
    return d0 + (d1 - d0) * f;
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
