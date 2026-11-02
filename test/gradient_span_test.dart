import 'dart:math';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

PaintModel fade(double degrees) => PaintModel(
  id: 'p',
  type: PaintType.gradientLinear,
  gradientTransform: applyGradientRotation(null, degrees),
  gradientStops: const [
    ColorStop(position: 0, color: ColorRGBA.white),
    ColorStop(position: 1, color: ColorRGBA.black),
  ],
);

/// Where the gradient's start (left middle) and end (right middle) land.
(Offset, Offset) ends(double degrees, Rect box) {
  final LinearGradient g = retrieveGradient(fade(degrees))! as LinearGradient;
  final Matrix4 m = g.transform!.transform(box)!;
  Offset at(double x) {
    final Vector3 v = m.transform3(Vector3(x, box.center.dy, 0));
    return Offset(v.x, v.y);
  }

  return (at(box.left), at(box.right));
}

void expectNear(Offset a, Offset b) {
  expect(a.dx, closeTo(b.dx, 1e-6));
  expect(a.dy, closeTo(b.dy, 1e-6));
}

void main() {
  const Rect tall = Rect.fromLTWH(0, 0, 100, 300);

  test('a vertical gradient spans the full height of a tall box', () {
    final (Offset a, Offset b) = ends(90, tall);
    // One end at the top centre, the other at the bottom centre.
    expect({a.dy.round(), b.dy.round()}, {0, 300});
    expect(a.dx, closeTo(50, 1e-6));
    expect(b.dx, closeTo(50, 1e-6));
  });

  test('a horizontal gradient is unchanged', () {
    final (Offset a, Offset b) = ends(0, tall);
    expectNear(a, const Offset(0, 150));
    expectNear(b, const Offset(100, 150));
  });

  test('a diagonal gradient spans the box along its axis', () {
    const Rect square = Rect.fromLTWH(0, 0, 100, 100);
    final (Offset a, Offset b) = ends(45, square);
    // Corner to corner of a square: the run is 100·√2 long.
    expect((b - a).distance, closeTo(100 * sqrt2, 1e-6));
    expectNear((a + b) / 2, square.center);
  });
}
