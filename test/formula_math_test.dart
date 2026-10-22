import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final Map<String, Object?> vars = {
    'stops': [
      {'id': 'zion', 'nights': 3, 'lat': 37.20, 'lng': -113.18},
      {'id': 'bryce', 'nights': 2, 'lat': 37.67, 'lng': -112.16},
      {'id': 'moab', 'nights': 4, 'lat': 38.53, 'lng': -109.49},
    ],
    'tags': ['a', 'b', 'c', 'd'],
    'i': 2,
  };
  Object? eval(String expression) =>
      FormulaEvaluator.evaluate(expression, (path) => _resolve(vars, path));

  group('math', () {
    test('roots, powers and trig', () {
      expect(eval('sqrt(16)'), 4);
      expect(eval('pow(2, 10)'), 1024);
      expect(eval('round(sin(pi() / 2), 3)'), 1);
      expect(eval('round(cos(0), 3)'), 1);
      expect(eval('round(degrees(atan2(1, 1)))'), 45);
      expect(eval('round(radians(180), 5)'), 3.14159);
      expect(eval('clamp(12, 0, 10)'), 10);
      expect(eval('clamp(-1, 0, 10)'), 0);
    });

    test('great-circle distance in km and miles', () {
      // Las Vegas to Salt Lake City is about 362 miles as the crow flies.
      expect(
        eval("round(distance(36.17, -115.14, 40.76, -111.89, 'mi'))"),
        inInclusiveRange(355, 370),
      );
      expect(eval('round(distance(0, 0, 0, 1))'), 111);
      expect(eval('distance(1, 2, 1, 2)'), 0);
      expect(eval("distance('x', 0, 0, 0)"), isNull);
    });

    test('distance between list items', () {
      expect(
        eval(
          "round(distance(first(stops).lat, first(stops).lng, "
          "find(stops, 'id', 'bryce').lat, find(stops, 'id', 'bryce').lng, 'mi'))",
        ),
        inInclusiveRange(60, 70),
      );
    });
  });

  group('slicing', () {
    test('first, last, take, skip, slice, reverse', () {
      expect(eval('first(tags)'), 'a');
      expect(eval('last(tags)'), 'd');
      expect(eval('take(tags, 2)'), ['a', 'b']);
      expect(eval('skip(tags, 3)'), ['d']);
      expect(eval('slice(tags, 1, 3)'), ['b', 'c']);
      expect(eval('slice(tags, -2)'), ['c', 'd']);
      expect(eval('slice(tags, 3, 1)'), isEmpty);
      expect(eval('reverse(tags)'), ['d', 'c', 'b', 'a']);
      expect(eval('first([])'), isNull);
    });

    test('nights before a stop: sum of a slice', () {
      expect(eval("sum(slice(stops, 0, i), 'nights')"), 5);
      expect(eval("sum(take(stops, 0), 'nights')"), 0);
    });

    test('range', () {
      expect(eval('range(4)'), [0, 1, 2, 3]);
      expect(eval('range(0, 70, 10)'), [0, 10, 20, 30, 40, 50, 60]);
      expect(eval('range(3, 0)'), [3, 2, 1]);
      expect(eval('range(1, 5, 0)'), isEmpty);
    });

    test('indexOf a value or a predicate', () {
      expect(eval("indexOf(tags, 'c')"), 2);
      expect(eval("indexOf(tags, 'z')"), -1);
      expect(eval("indexOf(stops, s => s.id == 'moab')"), 2);
      expect(eval("indexOf(stops, 'id', 'bryce')"), 1);
    });
  });
}

Object? _resolve(Map<String, Object?> vars, String path) {
  Object? value = vars;
  for (final part in path.split('.')) {
    value = value is Map ? value[part] : null;
  }
  return value;
}
