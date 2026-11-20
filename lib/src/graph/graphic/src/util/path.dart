import 'dart:ui';

import 'package:vector_math/vector_math_64.dart';

import 'transform.dart';

/// Gets control points of a point list.
List<Offset> _getControlPoints(
  List<Offset> points,
  double ratio,
  bool isLoop,
  bool hasConstraint, [
  Rect? constraint,
]) {
  final vectors = points.map((point) => pointToVector(point)).toList();

  final cps = <Offset>[];
  Vector3 prevVector;
  Vector3 nextVector;
  Vector3? min;
  Vector3? max;

  // The real constraint is calculated as:
  // - If constraint is null, is the boundary of points.
  // - If constraint is not null, is the larger one of constraint and boundary of
  // points.
  if (hasConstraint) {
    min = Vector3(double.infinity, double.infinity, 0);
    max = Vector3(double.negativeInfinity, double.negativeInfinity, 0);

    for (var vector in vectors) {
      Vector3.min(min, vector, min);
      Vector3.max(max, vector, max);
    }
    if (constraint != null) {
      Vector3.min(min, pointToVector(constraint.topLeft), min);
      Vector3.max(max, pointToVector(constraint.bottomRight), max);
    }
  }

  final len = points.length;
  for (var i = 0; i < len; i++) {
    final vector = vectors[i];
    if (isLoop) {
      prevVector = vectors[i >= 1 ? i - 1 : len - 1];
      nextVector = vectors[(i + 1) % len];
    } else {
      if (i == 0 || i == len - 1) {
        cps.add(points[i]);
        continue;
      } else {
        prevVector = vectors[i - 1];
        nextVector = vectors[i + 1];
      }
    }

    final v = (nextVector - prevVector) * ratio;
    var d0 = vector.distanceTo(prevVector);
    var d1 = vector.distanceTo(nextVector);

    final sum = d0 + d1;
    if (sum != 0) {
      d0 /= sum;
      d1 /= sum;
    }

    final v1 = v * (-d0);
    final v2 = v * d1;

    final cp0 = vector + v1;
    final cp1 = vector + v2;

    if (hasConstraint) {
      Vector3.max(cp0, min!, cp0);
      Vector3.min(cp0, max!, cp0);
      Vector3.max(cp1, min, cp1);
      Vector3.min(cp1, max, cp1);
    }

    cps.add(vectorToPoint(cp0));
    cps.add(vectorToPoint(cp1));
  }

  if (isLoop) {
    cps.add(cps.removeAt(0));
  }
  return cps;
}

/// Produces a cubic Catmull–Rom spline.
List<List<Offset>> getCubicControls(
  List<Offset> points,
  bool isLoop,
  bool hasConstraint, [
  Rect? constraint,
]) {
  // Alpha is 0.5, as proposed by Yuksel et al.
  // Thus is called a centripetal spline: https://en.wikipedia.org/wiki/Centripetal_Catmull%E2%80%93Rom_spline
  final controlPointList =
      _getControlPoints(points, 0.5, isLoop, hasConstraint, constraint);
  final len = points.length;
  final rst = <List<Offset>>[];

  Offset cp1;
  Offset cp2;
  Offset p;

  for (var i = 0; i < len - 1; i++) {
    cp1 = controlPointList[i * 2];
    cp2 = controlPointList[i * 2 + 1];
    p = points[i + 1];
    rst.add([cp1, cp2, p]);
  }

  if (isLoop) {
    cp1 = controlPointList[len];
    cp2 = controlPointList[len + 1];
    p = points[0];
    rst.add([cp1, cp2, p]);
  }

  return rst;
}

/// Produces a cubic spline through [points] that never passes above or
/// below the values it joins (a monotone cubic, after Fritsch and Carlson):
/// between two points the curve stays between them, so a smooth line shows
/// no peak or dip its data does not have. The points run along x, in either
/// direction.
List<List<Offset>> getMonotoneControls(List<Offset> points) {
  final n = points.length;
  final rst = <List<Offset>>[];
  if (n < 2) return rst;
  final dx = [for (var i = 0; i < n - 1; i++) points[i + 1].dx - points[i].dx];
  final slope = [
    for (var i = 0; i < n - 1; i++) dx[i] == 0 ? 0.0 : (points[i + 1].dy - points[i].dy) / dx[i],
  ];
  final tangent = List<double>.filled(n, 0);
  tangent[0] = slope[0];
  tangent[n - 1] = slope[n - 2];
  for (var i = 1; i < n - 1; i++) {
    final a = slope[i - 1], b = slope[i];
    if (a * b <= 0) continue;
    final h0 = dx[i - 1].abs(), h1 = dx[i].abs();
    final mean = h0 + h1 == 0 ? 0.0 : (a * h1 + b * h0) / (h0 + h1);
    final least = [a.abs(), b.abs(), 0.5 * mean.abs()].reduce((p, q) => p < q ? p : q);
    tangent[i] = (a.sign + b.sign) * least;
  }
  for (var i = 0; i < n - 1; i++) {
    final third = dx[i] / 3;
    rst.add([
      Offset(points[i].dx + third, points[i].dy + tangent[i] * third),
      Offset(points[i + 1].dx - third, points[i + 1].dy - tangent[i + 1] * third),
      points[i + 1],
    ]);
  }
  return rst;
}

/// Produces a stepped polyline.
List<Offset> getSteppedPoints(
  List<Offset> points,
) {
  final rst = <Offset>[];

  if (points.isNotEmpty) {
    rst.add(points[0]);
  }

  for (var i = 1; i < points.length; i++) {
    rst.add(Offset(points[i].dx, points[i - 1].dy));
    rst.add(points[i]);
  }

  return rst;
}
