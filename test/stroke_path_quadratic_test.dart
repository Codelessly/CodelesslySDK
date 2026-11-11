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
}
