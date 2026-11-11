// PathCurve.quadratic: after the first point, (control, end) pairs drawn
// with quadraticBezierTo, so a hand-drawn outline matches a painter's
// curves exactly instead of a polyline sampled from them.
import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/src/render/behaviors.dart' show StrokePathPainter;
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

Path _path(List<api.Offset> points) => StrokePathPainter(api.StrokePath(
      points: points,
      xUnit: api.PathUnit.pixels,
      yUnit: api.PathUnit.pixels,
      curve: api.PathCurve.quadratic,
    )).pathFor(const Size(200, 200));

double _length(Path p) => p.computeMetrics().fold(0.0, (l, m) => l + m.length);

void main() {
  test('pairs are a control and an end point', () {
    final got = _path(const [api.Offset(0, 0), api.Offset(50, 100), api.Offset(100, 0), api.Offset(150, -100), api.Offset(200, 0)]);
    final want = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(50, 100, 100, 0)
      ..quadraticBezierTo(150, -100, 200, 0);
    expect(_length(got), closeTo(_length(want), 1e-6));
    // Through (50, 50) at the first curve's middle, not the control point.
    final m = got.computeMetrics().first;
    final mid = m.getTangentForOffset(m.length / 4)!.position;
    expect(mid.dx, closeTo(50, 0.5));
    expect(mid.dy, closeTo(50, 0.5));
  });

  test('an unpaired last point is a straight line to it', () {
    final got = _path(const [api.Offset(0, 0), api.Offset(50, 100), api.Offset(100, 0), api.Offset(100, 40)]);
    final want = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(50, 100, 100, 0)
      ..lineTo(100, 40);
    expect(_length(got), closeTo(_length(want), 1e-6));
  });

  test('round-trips through JSON', () {
    const s = api.StrokePath(points: [api.Offset(0, 0)], curve: api.PathCurve.quadratic);
    expect(api.StrokePath.fromJson(s.toJson())!.curve, api.PathCurve.quadratic);
  });

  test('untilWidth: segments that start past the width are dropped, the last one runs over', () {
    // A painter's `for (x = 0; x <= width; x += 24) quadraticBezierTo(x + 12, .., x + 24, 3)`.
    final pts = <api.Offset>[const api.Offset(0, 3)];
    for (var x = 0.0; x < 500; x += 24) {
      pts.addAll([api.Offset(x + 12, 4), api.Offset(x + 24, 3)]);
    }
    Path of(bool until, double width) => StrokePathPainter(api.StrokePath(
          points: pts,
          xUnit: api.PathUnit.pixels,
          yUnit: api.PathUnit.pixels,
          curve: api.PathCurve.quadratic,
          untilWidth: until,
        )).pathFor(Size(width, 6));
    Path painter(double width) {
      final p = Path()..moveTo(0, 3);
      for (var x = 0.0; x <= width; x += 24) {
        p.quadraticBezierTo(x + 12, 4, x + 24, 3);
      }
      return p;
    }

    for (final w in [100.0, 120.0, 131.5]) {
      expect(_length(of(true, w)), closeTo(_length(painter(w)), 1e-6), reason: 'width $w');
    }
    expect(_length(of(false, 100)), closeTo(_length(painter(503)), 1e-6));
    expect(api.StrokePath.fromJson(const api.StrokePath(untilWidth: true).toJson())!.untilWidth, isTrue);
  });
}
