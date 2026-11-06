import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

Object? eval(String f, [Map<String, Object?> vars = const {}]) =>
    FormulaEvaluator.evaluate(f, (p) => vars[p]);

void main() {
  test('spline draws Catmull-Rom cubics through the points', () {
    final route = eval('spline(pts)', {
      'pts': [
        {'x': 80, 'y': 320},
        {'x': 270, 'y': 230},
        {'x': 480, 'y': 310},
      ],
    });
    // Control points p1 + (p2 - p0)/6 and p2 - (p3 - p1)/6, ends repeated.
    expect(
      route,
      'M 80 320 C 111.7 305 203.3 231.7 270 230 C 336.7 228.3 445 296.7 480 310',
    );
    expect(eval('spline([[0, 0], [10, 0]])'), 'M 0 0 C 1.7 0 8.3 0 10 0');
    expect(eval('spline([[0, 0]])'), isNull);
  });

  test('pathLength and pathPoint measure by arc length', () {
    expect(eval("pathLength('M 0 0 L 30 40')"), 50);
    final mid = eval("pathPoint('M 0 0 L 100 0 L 100 100', 0.75)") as Map;
    expect(mid['x'], 100);
    expect(mid['y'], 50);
    expect(mid['angle'], 90);
  });

  test('pathPoints spaces points evenly, first to last', () {
    final pts = eval("pathPoints('M 0 0 L 100 0', 5)") as List;
    expect(pts.map((p) => (p as Map)['x']), [0, 25, 50, 75, 100]);
    expect((pts.last as Map)['t'], 1);
    // Usable in lambdas: where a route crosses a band.
    expect(
      eval("findIndex(pathPoints('M 0 0 L 100 0', 11), p => p.x > 42)"),
      5,
    );
  });

  test('bad path data is null, not an error', () {
    expect(eval("pathLength('nonsense')"), isNull);
    expect(eval("pathPoints('', 3)"), isNull);
  });
}
