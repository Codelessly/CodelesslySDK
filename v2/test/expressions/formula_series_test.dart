import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

/// Evaluates [expression] with [vars] as its variables.
Object? eval(String expression, [Map<String, Object?> vars = const {}]) =>
    FormulaEvaluator.evaluate(expression, (path) => vars[path]);

void main() {
  // Half-hourly tide heights, NOAA style.
  final List<Map<String, String>> tides = [
    {'t': '2026-10-22 14:00', 'v': '2.0'},
    {'t': '2026-10-22 14:30', 'v': '1.4'},
    {'t': '2026-10-22 15:00', 'v': '0.8'},
    {'t': '2026-10-22 15:30', 'v': '0.6'},
    {'t': '2026-10-22 16:00', 'v': '1.2'},
    {'t': '2026-10-22 16:30', 'v': '1.8'},
  ];

  group('text', () {
    test('substring clamps and defaults its end', () {
      expect(eval('substring("2026-10-22 02:58", 0, 10)'), '2026-10-22');
      expect(eval('substring("abc", 1)'), 'bc');
      expect(eval('substring("abc", 2, 99)'), 'c');
    });

    test('replace and split', () {
      expect(eval('replace("a-b-c", "-", " ")'), 'a b c');
      expect(eval('split("a,b,c", ",")'), ['a', 'b', 'c']);
    });
  });

  group('lists', () {
    test('slice takes a range, negative from the end', () {
      expect(eval('slice([1, 2, 3, 4], 1, 3)'), [2, 3]);
      expect(eval('slice([1, 2, 3, 4], -2)'), [3, 4]);
      expect(eval('slice([1, 2], 5)'), isEmpty);
    });

    test('range counts numbers through the end', () {
      expect(eval('range(0, 6, 2)'), [0, 2, 4, 6]);
      expect(eval('range(-1, 1)'), [-1, 0, 1]);
      expect(eval('range(3, 1, -1)'), [3, 2, 1]);
      expect(eval('range(0, 1, 0)'), isEmpty);
    });

    test('range steps dates by minutes', () {
      expect(eval('range("2026-10-22T07:25:00", "2026-10-22T07:40:00", 5)'), [
        '2026-10-22T07:25:00.000',
        '2026-10-22T07:30:00.000',
        '2026-10-22T07:35:00.000',
        '2026-10-22T07:40:00.000',
      ]);
    });

    test('runs groups consecutive matches', () {
      final Object? r = eval('runs([1, 3, 4, 0, 5, 6, 7], n => n > 2)');
      expect(r, [
        {
          'first': 3,
          'last': 4,
          'items': [3, 4],
          'count': 2,
        },
        {
          'first': 5,
          'last': 7,
          'items': [5, 6, 7],
          'count': 3,
        },
      ]);
    });

    test('minBy and maxBy return the item', () {
      expect(eval('minBy(tides, "v")', {'tides': tides}), {
        't': '2026-10-22 15:30',
        'v': '0.6',
      });
      expect(
        eval('maxBy(tides, t => number(t.v)).t', {'tides': tides}),
        '2026-10-22 14:00',
      );
    });

    test('obj builds a map', () {
      expect(eval('obj("from", 1, "to", "b")'), {'from': 1, 'to': 'b'});
      expect(eval('map([1, 2], n => obj("x", n * 2))'), [
        {'x': 2},
        {'x': 4},
      ]);
    });
  });

  group('interpolate', () {
    test('reads between two points of a date series', () {
      expect(
        eval('interpolate(tides, "t", "v", "2026-10-22T14:15")', {
          'tides': tides,
        }),
        closeTo(1.7, 1e-9),
      );
      expect(
        eval('interpolate(tides, "t", "v", "2026-10-22 15:30")', {
          'tides': tides,
        }),
        closeTo(0.6, 1e-9),
      );
    });

    test('is null outside the series', () {
      expect(
        eval('interpolate(tides, "t", "v", "2026-10-22T13:00")', {
          'tides': tides,
        }),
        isNull,
      );
    });

    test('works on numbers', () {
      expect(
        eval(
          'interpolate([obj("x", 0, "y", 0), obj("x", 10, "y", 5)], "x", "y", 4)',
        ),
        closeTo(2, 1e-9),
      );
    });
  });

  group('time zones', () {
    test('wallTime keeps the clock time of an offset date-time', () {
      expect(
        eval('wallTime("2026-10-22T07:25:17-07:00")'),
        '2026-10-22T07:25:17.000',
      );
      expect(eval('wallTime("2026-10-22 18:23")'), '2026-10-22T18:23:00.000');
    });

    test('now and today take a UTC offset', () {
      final DateTime utc = DateTime.now().toUtc();
      final DateTime minus7 = DateTime.parse(eval('now("-07:00")')! as String);
      final DateTime expected = utc.subtract(const Duration(hours: 7));
      expect(minus7.isUtc, false);
      expect(
        DateTime.utc(
              minus7.year,
              minus7.month,
              minus7.day,
              minus7.hour,
              minus7.minute,
            )
            .difference(
              DateTime.utc(
                expected.year,
                expected.month,
                expected.day,
                expected.hour,
                expected.minute,
              ),
            )
            .inMinutes
            .abs(),
        lessThanOrEqualTo(1),
      );
      expect(eval('now(5.5)'), isA<String>());
      expect((eval('today(-7)')! as String).endsWith('T00:00:00.000'), true);
    });
  });

  test(
    'a daylight pooling window composes from range, interpolate and runs',
    () {
      // Five-minute steps from "sunrise" to "sunset", kept where the tide is at
      // or below 1.0 ft, as the reference app's pooling windows.
      final Object? windows = eval(
        'filter(runs(map(range("2026-10-22T14:00", "2026-10-22T16:30", 5), '
        's => obj("t", s, "h", interpolate(tides, "t", "v", s))), '
        's => s.h <= 1), r => diffMinutes(r.first.t, r.last.t) >= 20)',
        {'tides': tides},
      );
      expect(windows, hasLength(1));
      final Map window = (windows! as List).single as Map;
      expect((window['first'] as Map)['t'], '2026-10-22T14:50:00.000');
      expect((window['last'] as Map)['t'], '2026-10-22T15:50:00.000');
    },
  );
}
