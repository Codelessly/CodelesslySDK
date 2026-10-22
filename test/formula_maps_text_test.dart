import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final Map<String, Object?> vars = {
    'units': [
      {'id': 'ex1', 'hours': 10.5, 'status': 'Available'},
      {'id': 'ex2', 'hours': 99.0, 'status': 'On rent'},
    ],
    'meter': 2481.6,
    'unitId': 'ex2',
    'start': '2026-10-01',
  };
  Object? eval(String expression) =>
      FormulaEvaluator.evaluate(expression, (path) => vars[path]);

  group('maps', () {
    test('obj builds a map from key, value pairs', () {
      expect(eval("obj('id', 'ex9', 'hours', 1 + 2)"), {
        'id': 'ex9',
        'hours': 3,
      });
      expect(eval('obj()'), <String, Object?>{});
    });

    test('set and merge return changed copies', () {
      expect(eval("set(first(units), 'hours', 12)"), {
        'id': 'ex1',
        'hours': 12,
        'status': 'Available',
      });
      expect((vars['units']! as List).first, containsPair('hours', 10.5));
      expect(
        eval("merge(first(units), obj('status', 'Down'))")! as Map,
        containsPair('status', 'Down'),
      );
      expect(eval("keys(first(units))"), ['id', 'hours', 'status']);
      expect(eval("values(obj('a', 1))"), [1]);
    });

    test('update one item of a list with map + set', () {
      final Object? result = eval(
        "map(units, u => if(u.id == unitId, set(u, 'hours', u.hours + 5), u))",
      );
      expect(result, [
        {'id': 'ex1', 'hours': 10.5, 'status': 'Available'},
        {'id': 'ex2', 'hours': 104, 'status': 'On rent'},
      ]);
    });
  });

  group('lists', () {
    test('range counts up to, not including, the end', () {
      expect(eval('range(4)'), [0, 1, 2, 3]);
      expect(eval('range(2, 5)'), [2, 3, 4]);
      expect(eval('range(0, 10, 3)'), [0, 3, 6, 9]);
      expect(eval('range(3, 0)'), [3, 2, 1]);
      expect(eval('range(0)'), isEmpty);
    });

    test('a month calendar from range and dates', () {
      // October 2026 starts on a Thursday (weekday 4): three blank cells.
      final Object? cells = eval(
        "map(range(weekday(start) - 1 + daysInMonth(start)), i => if(i < weekday(start) - 1, '', addDays(start, i - weekday(start) + 1)))",
      );
      final List list = cells! as List;
      expect(list.length, 3 + 31);
      expect(list.take(3), ['', '', '']);
      expect((list[3] as String).substring(0, 10), '2026-10-01');
      expect((list.last as String).substring(0, 10), '2026-10-31');
    });

    test('slice, first, last, concat, indexOf', () {
      expect(eval('slice(range(10), 2, 4)'), [2, 3]);
      expect(eval('slice(range(5), -2)'), [3, 4]);
      expect(eval('first(units).id'), 'ex1');
      expect(eval('last(units).id'), 'ex2');
      expect(eval('concat(range(2), [9], 7)'), [0, 1, 9, 7]);
      expect(eval("indexOf(units, u => u.id == 'ex2')"), 1);
      expect(eval("indexOf(units, 'id', 'nope')"), -1);
      expect(eval('indexOf([5, 6], 6)'), 1);
    });
  });

  group('text', () {
    test('padLeft, padRight, substring, split, replace', () {
      expect(eval("padLeft(floor(meter), 5, '0')"), '02481');
      expect(eval("padRight('ab', 4, '.')"), 'ab..');
      expect(eval("substring('EX-102', 3)"), '102');
      expect(eval("substring('EX-102', 0, 2)"), 'EX');
      expect(eval("split(padLeft(floor(meter), 5, '0'))"), [
        '0',
        '2',
        '4',
        '8',
        '1',
      ]);
      expect(eval("split('a,b', ',')"), ['a', 'b']);
      expect(eval("replace('1,402.3', ',', '')"), '1402.3');
    });

    test('coalesce picks the first value that is set', () {
      expect(eval("coalesce(missing, '', 'fallback')"), 'fallback');
      expect(eval('coalesce(meter, 1)'), 2481.6);
    });
  });

  test('daysInMonth', () {
    expect(eval("daysInMonth('2026-02-10')"), 28);
    expect(eval("daysInMonth('2028-02-10')"), 29);
    expect(eval('daysInMonth(start)'), 31);
  });
}
