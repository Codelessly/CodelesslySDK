import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final Map<String, Object?> vars = {
    'sites': [
      {'id': 'A1', 'status': 'occupied'},
      {'id': 'A2', 'status': 'vacant'},
      {'id': 'A3', 'status': 'vacant'},
    ],
    'pick': 'A2',
    'start': '2026-07-17T20:12:00.000',
  };
  Object? eval(String expression) =>
      FormulaEvaluator.evaluate(expression, (path) => vars[path]);

  group('records', () {
    test('object builds a map; set and merge copy one', () {
      expect(eval("object('id', 'C1', 'nights', 2)"), {
        'id': 'C1',
        'nights': 2,
      });
      expect(eval("set(first(sites), 'status', 'vacant')"), {
        'id': 'A1',
        'status': 'vacant',
      });
      expect(eval("merge(first(sites), object('note', 'x'))"), {
        'id': 'A1',
        'status': 'occupied',
        'note': 'x',
      });
      expect(eval("set(null, 'a', 1)"), {'a': 1});
      // The variable itself is untouched.
      expect((vars['sites'] as List).first, {'id': 'A1', 'status': 'occupied'});
    });

    test('map with set updates one item of a list', () {
      expect(
        eval(
          "map(sites, s => s.id == pick ? set(s, 'status', 'occupied') : s)",
        ),
        [
          {'id': 'A1', 'status': 'occupied'},
          {'id': 'A2', 'status': 'occupied'},
          {'id': 'A3', 'status': 'vacant'},
        ],
      );
    });
  });

  group('list helpers', () {
    test('findIndex, first, last, take, skip, reverse', () {
      expect(eval('findIndex(sites, s => s.id == pick)'), 1);
      expect(eval("findIndex(sites, 'status', 'gone')"), -1);
      expect(eval('first(sites).id'), 'A1');
      expect(eval('last(sites).id'), 'A3');
      expect(eval('first([])'), isNull);
      expect(eval('map(take(sites, 2), s => s.id)'), ['A1', 'A2']);
      expect(eval('map(skip(sites, 2), s => s.id)'), ['A3']);
      expect(eval('take(sites, -1)'), isEmpty);
      expect(eval('reverse([1, 2, 3])'), [3, 2, 1]);
    });

    test('concat and range', () {
      expect(eval('concat([1], [2, 3], 4)'), [1, 2, 3, 4]);
      expect(eval('range(3)'), [0, 1, 2]);
      expect(eval('range(8, 11)'), [8, 9, 10]);
    });
  });

  group('text helpers', () {
    test('padLeft, replace, substring, split', () {
      expect(eval('padLeft(7, 2)'), '07');
      expect(eval("padLeft('A', 3, '-')"), '--A');
      expect(eval("replace('A-7', '-', '')"), 'A7');
      expect(eval("substring('Ticket', 0, 3)"), 'Tic');
      expect(eval("substring('Ticket', 4)"), 'et');
      expect(eval("substring('Ab', 5)"), '');
      expect(eval("split('12', '')"), ['1', '2']);
      expect(eval("split('a,b')"), ['a', 'b']);
    });
  });

  group('seconds and durations', () {
    test('addSeconds and diffSeconds', () {
      expect(eval('addSeconds(start, 90)'), '2026-07-17T20:13:30.000');
      expect(eval("diffSeconds(start, '2026-07-17T20:16:00')"), 240);
    });

    test('formatDuration patterns', () {
      expect(eval("formatDuration(6480, 'h:mm:ss')"), '1:48:00');
      expect(eval("formatDuration(240, 'mm:ss')"), '04:00');
      expect(eval("formatDuration(6480, 'mm:ss')"), '108:00');
      expect(eval("formatDuration(72, 'm:ss')"), '1:12');
      expect(eval('formatDuration(6480)'), '1h 48m');
      expect(eval('formatDuration(7200)'), '2h');
      expect(eval("formatDuration(1500, 'compact')"), '25m');
      expect(eval('formatDuration(40)'), '40s');
      expect(eval('formatDuration(-72, "m:ss")'), '1:12');
    });
  });

  group('readsClock', () {
    test('spots now() and today() outside quotes', () {
      expect(FormulaEvaluator.readsClock('diffSeconds(now(), x)'), isTrue);
      expect(FormulaEvaluator.readsClock('today ()'), isTrue);
      expect(FormulaEvaluator.readsClock("'now()' + x"), isFalse);
      expect(FormulaEvaluator.readsClock('nowhere + know'), isFalse);
      expect(
        FormulaEvaluator.textReadsClock(
          r'Ends in ${= formatDuration(diffSeconds(now(), end))}',
        ),
        isTrue,
      );
      expect(FormulaEvaluator.textReadsClock(r'${= a + 1} now()'), isFalse);
    });
  });

  test('FormulaClock ticks only while listened to', () async {
    FormulaClock.interval = const Duration(milliseconds: 10);
    int ticks = 0;
    void listener() => ticks++;
    expect(FormulaClock.instance.isTicking, isFalse);
    FormulaClock.instance.addListener(listener);
    expect(FormulaClock.instance.isTicking, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 55));
    FormulaClock.instance.removeListener(listener);
    expect(FormulaClock.instance.isTicking, isFalse);
    expect(ticks, greaterThanOrEqualTo(3));
    FormulaClock.interval = const Duration(seconds: 1);
  });
}
