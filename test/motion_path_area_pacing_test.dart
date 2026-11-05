import 'dart:math' as math;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/src/ui/node_motion.dart';
import 'package:flutter_test/flutter_test.dart';

/// An orbit of semi-major axis [a] and eccentricity [e] around a focus at
/// the origin, perihelion on +x, drawn counter-clockwise on screen (y down),
/// starting with "M0 0" so the node rests on the focus.
String orbit(double a, double e) {
  final double b = a * math.sqrt(1 - e * e);
  final double q = a * (1 - e), big = a * (1 + e);
  return 'M0 0 M$q 0 A$a $b 0 0 0 ${-big} 0 A$a $b 0 0 0 $q 0';
}

/// Where Kepler's laws put the body at mean anomaly [m] (radians), in the
/// same screen coordinates.
Offset kepler(double a, double e, double m) {
  double ecc = m;
  for (int k = 0; k < 30; k++) {
    ecc -= (ecc - e * math.sin(ecc) - m) / (1 - e * math.cos(ecc));
  }
  return Offset(a * (math.cos(ecc) - e), -a * math.sqrt(1 - e * e) * math.sin(ecc));
}

void main() {
  test('area pacing follows Kepler\'s second law on an eccentric orbit', () {
    const double a = 200, e = 0.6;
    final String path = orbit(a, e);
    for (final double share in [0.0, 0.05, 0.1, 0.25, 0.5, 0.7, 0.9, 0.99]) {
      final (Offset at, _) = pointOnMotionPath(path, share, pacing: MotionPathPacing.area)!;
      final Offset want = kepler(a, e, share * 2 * math.pi);
      expect((at - want).distance, lessThan(1.0), reason: 'share $share: $at vs $want');
    }
  });

  test('length pacing differs from area pacing near perihelion', () {
    final String path = orbit(200, 0.6);
    final (Offset byLength, _) = pointOnMotionPath(path, 0.1)!;
    final (Offset byArea, _) = pointOnMotionPath(path, 0.1, pacing: MotionPathPacing.area)!;
    // Near the Sun a planet covers far more of its path in a tenth of its
    // year than an even-speed node does.
    expect((byArea - byLength).distance, greaterThan(20));
  });

  test('a focus away from the origin', () {
    // The same orbit drawn around a focus at (300, 300).
    const double a = 150, e = 0.3;
    final double b = a * math.sqrt(1 - e * e);
    final double q = a * (1 - e), big = a * (1 + e);
    final String path = 'M${300 + q} 300 A$a $b 0 0 0 ${300 - big} 300 A$a $b 0 0 0 ${300 + q} 300';
    final (Offset at, _) = pointOnMotionPath(path, 0.3, pacing: MotionPathPacing.area, focus: const Offset(300, 300))!;
    // Positions are relative to the path's first point.
    final Offset want = kepler(a, e, 0.3 * 2 * math.pi) - Offset(q, 0);
    expect((at - want).distance, lessThan(1.0));
  });

  test('wrapping progress reads modulo 1', () {
    expect(wrapPathProgress(1.25), closeTo(0.25, 1e-9));
    expect(wrapPathProgress(-0.25), closeTo(0.75, 1e-9));
    expect(wrapPathProgress(1), 1);
    expect(wrapPathProgress(0.4), 0.4);
  });

  test('pacing, focus and wrap survive JSON', () {
    const m = MotionModel(path: 'M0 0 L10 0', pathPacing: MotionPathPacing.area, pathFocusX: 4, pathFocusY: -2, pathWrap: true);
    final back = MotionModel.fromJson(m.toJson());
    expect(back, m);
    expect(MotionModel.fromJson(const MotionModel(path: 'M0 0 L1 0').toJson()).pathPacing, MotionPathPacing.length);
  });
}
