// Formula functions for curves: draw a smooth path through points, and
// measure or sample SVG path data by arc length. They let a screen build a
// motion path from variables (a route through draggable pins) and work out
// where along it things happen (a gust, a star, a crash), without code.
//
//   spline(points)        SVG path data through the points (Catmull-Rom)
//   pathPoints(path, n)   n points equally spaced along the path
//   pathPoint(path, t)    the point a fraction t (0..1) of the way along
//   pathLength(path)      its length
//
// Points are maps {x, y} or two-number lists [x, y]. Sampled points are maps
// {x, y, angle, t}: angle is the direction of travel in degrees clockwise
// from east (as a node's rotation), t the fraction of the way along.
import 'dart:math' as math;

import 'package:path_parsing/path_parsing.dart';

/// Reads a point from `{x, y}` or `[x, y]`; null when it isn't one.
math.Point<double>? formulaPoint(Object? value) {
  double? n(Object? v) => switch (v) {
    num n => n.toDouble(),
    String s => double.tryParse(s.trim()),
    _ => null,
  };
  return switch (value) {
    Map m when n(m['x']) != null && n(m['y']) != null =>
      math.Point(n(m['x'])!, n(m['y'])!),
    List l when l.length >= 2 && n(l[0]) != null && n(l[1]) != null =>
      math.Point(n(l[0])!, n(l[1])!),
    _ => null,
  };
}

String _fmt(double v) {
  final String s = v.toStringAsFixed(1);
  return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
}

/// SVG path data for a Catmull-Rom spline through [points]: one cubic Bézier
/// per gap, with control points `p1 + (p2 - p0) / 6` and `p2 - (p3 - p1) / 6`
/// (the end points stand in for their missing neighbours). Two points give
/// a straight line. Null with fewer than two points.
String? splinePath(List<Object?> points) {
  final List<math.Point<double>> p = [
    for (final Object? v in points)
      if (formulaPoint(v) case final math.Point<double> q) q,
  ];
  if (p.length < 2) return null;
  final StringBuffer b = StringBuffer('M ${_fmt(p[0].x)} ${_fmt(p[0].y)}');
  for (int i = 0; i < p.length - 1; i++) {
    final math.Point<double> p0 = i == 0 ? p[0] : p[i - 1];
    final math.Point<double> p1 = p[i], p2 = p[i + 1];
    final math.Point<double> p3 = i + 2 < p.length ? p[i + 2] : p[i + 1];
    final math.Point<double> c1 = p1 + (p2 - p0) * (1 / 6);
    final math.Point<double> c2 = p2 - (p3 - p1) * (1 / 6);
    b.write(
      ' C ${_fmt(c1.x)} ${_fmt(c1.y)} ${_fmt(c2.x)} ${_fmt(c2.y)} '
      '${_fmt(p2.x)} ${_fmt(p2.y)}',
    );
  }
  return b.toString();
}

/// A path flattened into short straight pieces, with the running length.
class _Flat {
  final List<math.Point<double>> points;
  final List<double> lengths;
  const _Flat(this.points, this.lengths);
  double get total => lengths.isEmpty ? 0 : lengths.last;
}

class _Flattener extends PathProxy {
  final List<math.Point<double>> points = [];
  math.Point<double> _at = const math.Point(0, 0);
  math.Point<double>? _start;

  void _add(math.Point<double> p) {
    points.add(p);
    _at = p;
  }

  @override
  void moveTo(double x, double y) {
    // Sub-paths are joined: a motion path is one line to follow.
    _start ??= math.Point(x, y);
    _add(math.Point(x, y));
  }

  @override
  void lineTo(double x, double y) => _add(math.Point(x, y));

  @override
  void cubicTo(double x1, double y1, double x2, double y2, double x3, double y3) {
    final math.Point<double> p0 = _at;
    const int steps = 32;
    for (int i = 1; i <= steps; i++) {
      final double t = i / steps, u = 1 - t;
      _add(math.Point(
        u * u * u * p0.x + 3 * u * u * t * x1 + 3 * u * t * t * x2 + t * t * t * x3,
        u * u * u * p0.y + 3 * u * u * t * y1 + 3 * u * t * t * y2 + t * t * t * y3,
      ));
    }
  }

  @override
  void close() {
    if (_start != null) _add(_start!);
  }
}

final Map<String, _Flat?> _flatCache = {};

_Flat? _flatten(String data) {
  if (_flatCache.length > 64) _flatCache.clear();
  return _flatCache.putIfAbsent(data, () {
    try {
      final _Flattener f = _Flattener();
      writeSvgPathDataToPath(data, f);
      if (f.points.length < 2) return null;
      final List<double> lengths = [0];
      for (int i = 1; i < f.points.length; i++) {
        lengths.add(lengths.last + f.points[i].distanceTo(f.points[i - 1]));
      }
      return _Flat(f.points, lengths);
    } catch (_) {
      return null;
    }
  });
}

double _round(double v) => (v * 100).roundToDouble() / 100;

/// The point [t] (0 to 1, by arc length) of the way along [flat].
Map<String, Object?> _pointAt(_Flat flat, double t) {
  final double target = flat.total * t.clamp(0.0, 1.0);
  final List<double> l = flat.lengths;
  int lo = 1, hi = l.length - 1;
  while (lo < hi) {
    final int mid = (lo + hi) >> 1;
    if (l[mid] < target) {
      lo = mid + 1;
    } else {
      hi = mid;
    }
  }
  final int j = lo.clamp(1, l.length - 1);
  final double seg = l[j] - l[j - 1];
  final double f = seg == 0 ? 0 : ((target - l[j - 1]) / seg).clamp(0.0, 1.0);
  final math.Point<double> a = flat.points[j - 1], b = flat.points[j];
  // Direction: the nearest piece that actually goes somewhere.
  int k = j;
  while (k < flat.points.length - 1 && flat.points[k] == flat.points[k - 1]) {
    k++;
  }
  final math.Point<double> d = flat.points[k] - flat.points[k - 1];
  return {
    'x': _round(a.x + (b.x - a.x) * f),
    'y': _round(a.y + (b.y - a.y) * f),
    'angle': _round(math.atan2(d.y, d.x) * 180 / math.pi),
    't': _round(t * 1000) / 1000,
  };
}

/// The length of SVG path [data], or null when it can't be read.
double? pathLength(String data) {
  final _Flat? f = _flatten(data);
  return f == null ? null : _round(f.total);
}

/// The point a fraction [t] of the way along SVG path [data].
Map<String, Object?>? pathPoint(String data, double t) {
  final _Flat? f = _flatten(data);
  return f == null ? null : _pointAt(f, t);
}

/// [count] points equally spaced along SVG path [data], first to last.
List<Map<String, Object?>>? pathPoints(String data, int count) {
  final _Flat? f = _flatten(data);
  if (f == null || count < 1) return null;
  final int n = count.clamp(1, 2000);
  return [for (int i = 0; i < n; i++) _pointAt(f, n == 1 ? 0 : i / (n - 1))];
}
