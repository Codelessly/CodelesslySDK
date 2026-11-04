import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

/// Functions that build and update records (maps) and lists, so actions
/// can change one item of a list variable (indexOf with a predicate, obj,
/// set, setAt, merge, concat, append, take, skip) and format an odometer
/// (thousands, padLeft).
void main() {
  final Map<String, Object?> vars = {
    'defects': [
      {'id': 'DF-1', 'status': 'open', 'timeline': []},
      {
        'id': 'DF-2',
        'status': 'repaired',
        'timeline': ['a'],
      },
    ],
    'id': 'DF-2',
    'user': {'id': 'u1', 'name': 'Luis'},
    'answers': {'1a': 'pass'},
  };
  Object? eval(String expression) => FormulaEvaluator.evaluate(
    expression,
    (path) => path
        .split('.')
        .fold<Object?>(vars, (value, key) => value is Map ? value[key] : null),
  );

  test('indexOf finds by lambda, field and value, or plain value', () {
    expect(eval('indexOf(defects, d => d.id == id)'), 1);
    expect(eval('indexOf(defects, "status", "open")'), 0);
    expect(eval('indexOf(["a", "b"], "b")'), 1);
    expect(eval('indexOf(defects, d => d.id == "nope")'), -1);
    expect(eval('indexOf(null, d => true)'), -1);
  });

  test('obj builds a map from key/value pairs', () {
    expect(eval('obj("t", 3, "by", user.name)'), {'t': 3, 'by': 'Luis'});
    expect(eval('obj()'), <String, Object?>{});
  });

  test('set copies a map, and setAt a list, with one entry changed', () {
    expect(eval('set(answers, "1b", "fail")'), {'1a': 'pass', '1b': 'fail'});
    expect(vars['answers'], {
      '1a': 'pass',
    }, reason: 'the original is unchanged');
    expect(eval('setAt([1, 2, 3], 1, 9)'), [1, 9, 3]);
    final Object? updated = eval(
      'setAt(defects, indexOf(defects, d => d.id == id), '
      'set(find(defects, d => d.id == id), "status", "verified"))',
    );
    expect((updated! as List)[1], {
      'id': 'DF-2',
      'status': 'verified',
      'timeline': ['a'],
    });
  });

  test('merge, concat and append combine records and lists', () {
    expect(eval('merge(user, obj("role", "mechanic"))'), {
      'id': 'u1',
      'name': 'Luis',
      'role': 'mechanic',
    });
    expect(eval('concat([1], [2, 3], 4)'), [1, 2, 3, 4]);
    expect(eval('append([1], 2, 3)'), [1, 2, 3]);
    expect(eval('append(null, 1)'), [1]);
  });

  test('take and skip slice lists', () {
    expect(eval('take([1, 2, 3], 2)'), [1, 2]);
    expect(eval('skip([1, 2, 3], 2)'), [3]);
  });

  test('thousands groups an odometer and padLeft pads', () {
    expect(eval('thousands(412908)'), '412,908');
    expect(eval('thousands(12)'), '12');
    expect(eval('padLeft(7, 2, "0")'), '07');
  });
  group('incoming record helpers', incomingRecordTests);
  group('PR 82 records and duration helpers', incomingPr82RecordTests);
}

void incomingRecordTests() {
  final Map<String, Object?> vars = {
    'logId': 'l2',
    'crewId': 'c2',
    'logs': [
      {
        'id': 'l1',
        'crew': [
          {'id': 'c1', 'n': 3},
        ],
      },
      {
        'id': 'l2',
        'crew': [
          {'id': 'c1', 'n': 2},
          {'id': 'c2', 'n': 5},
        ],
      },
    ],
    'tags': ['a', 'b', 'c', 'd'],
    'name': 'Keystone',
  };

  Object? eval(String expression) =>
      FormulaEvaluator.evaluate(expression, (path) {
        Object? value = vars;
        for (final part in path.split('.')) {
          value = value is Map ? value[part] : null;
        }
        return value;
      });

  test('obj, set, unset and merge build maps without braces', () {
    expect(eval('obj("company", name, "n", 4)'), {
      'company': 'Keystone',
      'n': 4,
    });
    expect(eval('set(obj("a", 1), "b", 2)'), {'a': 1, 'b': 2});
    expect(eval('unset(obj("a", 1, "b", 2), "a")'), {'b': 2});
    expect(eval('merge(obj("a", 1, "b", 2), obj("b", 3), obj("c", 4))'), {
      'a': 1,
      'b': 3,
      'c': 4,
    });
    expect(eval('set(tags, 1, "x")'), ['a', 'x', 'c', 'd']);
    expect(eval('set(tags, 9, "z")'), ['a', 'b', 'c', 'd']);
  });

  test('append, prepend and concat return new lists', () {
    expect(eval('append(tags, "e", "f")'), ['a', 'b', 'c', 'd', 'e', 'f']);
    expect(eval('prepend(tags, "z")'), ['z', 'a', 'b', 'c', 'd']);
    expect(eval('concat(tags, ["e"], null)'), ['a', 'b', 'c', 'd', 'e']);
    expect(eval('append(null, 1)'), [1]);
    expect(vars['tags'], [
      'a',
      'b',
      'c',
      'd',
    ], reason: 'arguments are not changed');
  });

  test('updateWhere and removeWhere change matching records', () {
    expect(eval('updateWhere(logs, "id", logId, obj("signed", true))'), [
      (vars['logs'] as List)[0],
      {...((vars['logs'] as List)[1] as Map), 'signed': true},
    ]);
    // A nested update: one crew entry inside one log.
    final Object? result = eval(
      'updateWhere(logs, l => l.id == logId, l => set(l, "crew", '
      'updateWhere(l.crew, c => c.id == crewId, c => set(c, "n", c.n + 1))))',
    );
    expect(((result as List)[1] as Map)['crew'], [
      {'id': 'c1', 'n': 2},
      {'id': 'c2', 'n': 6},
    ]);
    expect((result[0] as Map)['crew'], [
      {'id': 'c1', 'n': 3},
    ]);
    expect(eval('length(removeWhere(logs, "id", "l1"))'), 1);
    expect(eval('removeWhere(tags, t => t == "b" || t == "c")'), ['a', 'd']);
  });

  test('findIndex, indexOf, slice, take, skip, first, last, range', () {
    expect(eval('findIndex(logs, "id", "l2")'), 1);
    expect(eval('findIndex(logs, l => l.id == "nope")'), -1);
    expect(eval('indexOf(tags, "c")'), 2);
    expect(eval('indexOf("hardhat", "hat")'), 4);
    expect(eval('slice(tags, 1, 3)'), ['b', 'c']);
    expect(eval('slice(tags, -2)'), ['c', 'd']);
    expect(eval('slice("Thursday", 0, 3)'), 'Thu');
    expect(eval('take(tags, 2)'), ['a', 'b']);
    expect(eval('take(tags, 10)'), ['a', 'b', 'c', 'd']);
    expect(eval('skip(tags, 3)'), ['d']);
    expect(eval('reverse(tags)'), ['d', 'c', 'b', 'a']);
    expect(eval('reverse("abc")'), 'cba');
    expect(eval('first(tags)'), 'a');
    expect(eval('last(tags)'), 'd');
    expect(eval('first(null)'), isNull);
    expect(eval('range(3)'), [0, 1, 2]);
    expect(eval('range(2, 5)'), [2, 3, 4, 5]);
  });

  test('newId makes distinct prefixed ids', () {
    final Object? a = eval('newId("crew")');
    final Object? b = eval('newId("crew")');
    expect(a, matches(RegExp(r'^crew_[a-z0-9]{8}$')));
    expect(a, isNot(b));
    expect(eval('newId()'), matches(RegExp(r'^[a-z0-9]{8}$')));
  });

  test('thousands groups digits; money still shows cents', () {
    expect(eval('thousands(921)'), '921');
    expect(eval('thousands(12500)'), '12,500');
    expect(eval('thousands(-1234567.891, 2)'), '-1,234,567.89');
    expect(eval('thousands("x")'), isNull);
    expect(eval('money(1234.5)'), r'$1,234.50');
    expect(eval('money(-5, "€")'), '-€5.00');
  });

  test('every function is documented', () {
    expect(
      FormulaEvaluator.functions.toSet(),
      FormulaEvaluator.functionDocs.map((d) => d.name).toSet(),
    );
  });
}

void incomingPr82RecordTests() {
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
      expect(eval('range(8, 11)'), [8, 9, 10, 11]);
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
      expect(eval("split('a,b')"), ['a', ',', 'b']);
    });
  });

  group('seconds and durations', () {
    test('addSeconds and diffSeconds', () {
      expect(eval('addSeconds(start, 90)'), '2026-07-17T20:13:30.000');
      expect(eval("diffSeconds(start, '2026-07-17T20:16:00')"), 240);
      expect(eval('second(addSeconds(start, 75))'), 15);
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
