import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

Object? _resolve(Map<String, Object?> vars, String path) {
  Object? value = vars;
  for (final part in path.split('.')) {
    value = value is Map ? value[part] : null;
  }
  return value;
}

/// A stand-in for a Firestore Timestamp, which formulas read via `toDate()`.
class _Timestamp {
  final DateTime date;

  const _Timestamp(this.date);

  DateTime toDate() => date;
}

String _iso(DateTime date) => date.toIso8601String();

/// Map building and list editing functions, which let a set variable action
/// store a changed list: e.g. moving one placement of a floor plan.

/// Functions that build and update records (maps) and lists, so actions
/// can change one item of a list variable (indexOf with a predicate, obj,
/// set, setAt, merge, concat, append, take, skip) and format an odometer
/// (thousands, padLeft).

/// Evaluates [expression] with [vars] as its variables.
Object? eval(String expression, [Map<String, Object?> vars = const {}]) =>
    FormulaEvaluator.evaluate(expression, (path) => vars[path]);

/// Functions that build and update records (maps) and lists, so actions
/// can change one item of a list variable (indexOf with a predicate, obj,
/// set, setAt, merge, concat, append, take, skip) and format an odometer
/// (thousands, padLeft).

void recordTests() {
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

  test('obj, set, unset and merge build and change maps', () {
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

  test('append, prepend and concat give new lists', () {
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

  test('updateWhere and removeWhere change the records that match', () {
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

  test('newId makes ids that differ, with a prefix', () {
    final Object? a = eval('newId("crew")');
    final Object? b = eval('newId("crew")');
    expect(a, matches(RegExp(r'^crew_[a-z0-9]{8}$')));
    expect(a, isNot(b));
    expect(eval('newId()'), matches(RegExp(r'^[a-z0-9]{8}$')));
  });

  test('thousands groups digits, and money still shows cents', () {
    expect(eval('thousands(921)'), '921');
    expect(eval('thousands(12500)'), '12,500');
    expect(eval('thousands(-1234567.891, 2)'), '-1,234,567.89');
    expect(eval('thousands("x")'), isNull);
    expect(eval('money(1234.5)'), r'$1,234.50');
    expect(eval('money(-5, "€")'), '-€5.00');
  });

}

void main() {
  {
    {
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

      group('building data', () {
        test('object, merge, set, keys and values', () {
          expect(eval("object('cg', 'zion', 'nights', 2)"), {
            'cg': 'zion',
            'nights': 2,
          });
          expect(eval("merge(first(stops), object('nights', 9))"), {
            'id': 'zion',
            'nights': 9,
            'lat': 37.20,
            'lng': -113.18,
          });
          expect(eval("set(object('a', 1), 'b', 2)"), {'a': 1, 'b': 2});
          expect(eval("keys(object('a', 1, 'b', 2))"), ['a', 'b']);
          expect(eval("values(object('a', 1, 'b', 2))"), [1, 2]);
        });

        test('flatten and compact', () {
          expect(eval('flatten([[1, 2], [3], 4])'), [1, 2, 3, 4]);
          expect(eval("compact([1, null, '', 2])"), [1, 2]);
          expect(
            eval('compact(flatten(map(stops, s => [s.nights > 2 ? s.id : null])))'),
            ['zion', 'moab'],
          );
        });

        test('editing a list gives a new list', () {
          expect(eval("append(tags, 'e')"), ['a', 'b', 'c', 'd', 'e']);
          expect(eval("setAt(tags, 1, 'x')"), ['a', 'x', 'c', 'd']);
          expect(eval("setAt(tags, 9, 'x')"), ['a', 'b', 'c', 'd']);
          expect(eval("insertAt(tags, 0, 'z')"), ['z', 'a', 'b', 'c', 'd']);
          expect(eval('removeAt(tags, -1)'), ['a', 'b', 'c']);
          expect(eval('move(tags, 3, 0)'), ['d', 'a', 'b', 'c']);
          expect(eval('move(tags, 0, 2)'), ['b', 'c', 'a', 'd']);
          expect(vars['tags'], ['a', 'b', 'c', 'd']);
        });

      });

      group('slicing', () {
        test('first, last, take, skip, slice and reverse', () {
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

      });
    }

    {
      final List<Map<String, Object?>> records = [
        {'id': 'a', 'artist': 'Miles Davis', 'year': 1959, 'favorite': false},
        {'id': 'b', 'artist': 'Bill Evans', 'year': 1961, 'favorite': true},
        {'id': 'c', 'artist': 'Miles Davis', 'year': 1970, 'favorite': false},
        {'id': 'd', 'artist': 'Bill Evans', 'year': 1956, 'favorite': false},
      ];
      final List<Map<String, Object?>> tracks = [
        {'title': 'So What', 'length': '9:22'},
        {'title': 'Freddie Freeloader', 'length': '9:46'},
        {'title': 'Blue in Green', 'length': '5:37'},
      ];
      final Map<String, Object?> vars = {
        'records': records,
        'tracks': tracks,
        'selected': 'c',
        'count': 4,
        'genres': ['rock', 'jazz', 'soul'],
        'record': records.first,
      };

      Object? resolve(String path) {
        Object? value = vars;
        for (final part in path.split('.')) {
          value = value is Map ? value[part] : null;
        }
        return value;
      }

      Object? eval(String expression) =>
          FormulaEvaluator.evaluate(expression, resolve);

      group('lists', () {

        test('findIndex gives the position of the first match', () {
          expect(eval('findIndex(records, r => r.id == selected)'), 2);
          expect(eval('findIndex(records, "favorite")'), 1);
          expect(eval('findIndex(records, "artist", "Bill Evans")'), 1);
          expect(eval('findIndex(records, r => r.year > 2000)'), -1);
          expect(eval('findIndex(nothing, r => true)'), -1);
        });

        test('a lambda can take the item\'s index as well', () {
          expect(eval('map(genres, (g, i) => i + 1 + ". " + g)'), [
            '1. rock',
            '2. jazz',
            '3. soul',
          ]);
          expect(eval('filter(genres, (g, i) => i != 1)'), ['rock', 'soul']);
          expect(eval('find(genres, (g, i) => i == 2)'), 'soul');
          expect(eval('any(genres, (g, i) => i > 5)'), isFalse);
          expect(eval('all(genres, (g, i) => i < 3)'), isTrue);
          expect(eval('findIndex(genres, (g, i) => i > 0 && g == "soul")'), 2);
          expect(eval('sum([10, 20, 30], (n, i) => n * i)'), 80);
          expect(eval('count(genres, (g, i) => i < 2)'), 2);
          expect(eval('join(genres, ", ", (g, i) => i)'), '0, 1, 2');
          // Single-parameter lambdas still work.
          expect(eval('map(genres, g => upper(g))'), ['ROCK', 'JAZZ', 'SOUL']);
        });

        test('sortBy takes several keys and directions', () {
          List<Object?> ids(String expression) =>
              (eval(expression) as List).map((r) => (r as Map)['id']).toList();
          expect(ids('sortBy(records, r => r.artist, r => r.year)'), [
            'd',
            'b',
            'a',
            'c',
          ]);
          expect(ids('sortBy(records, "artist", "year", "desc")'), [
            'b',
            'd',
            'c',
            'a',
          ]);
          expect(ids('sortBy(records, "artist", "desc", "year")'), [
            'a',
            'c',
            'd',
            'b',
          ]);
          expect(ids('sortByDesc(records, "year")'), ['c', 'b', 'a', 'd']);
          expect(ids('sortByDesc(records, "artist", "year", "asc")'), [
            'a',
            'c',
            'd',
            'b',
          ]);
          expect(ids('sortBy(records, r => r.year, "desc")'), ['c', 'b', 'a', 'd']);
          expect(eval('sortBy([2, 3, 1], null, "desc")'), [3, 2, 1]);
          expect(eval('sortByDesc([2, 3, 1])'), [3, 2, 1]);
        });
      });

      group('objects', () {
        test('maps and lists can be written directly in a formula', () {
          expect(eval("{id: 'a', n: 1 + 2}"), {'id': 'a', 'n': 3});
          expect(eval("{'full name': 'Bill', \"b\": [1, {c: true}]}"), {
            'full name': 'Bill',
            'b': [
              1,
              {'c': true},
            ],
          });
          expect(eval('{}'), <String, Object?>{});
          expect(eval('{a: count > 2 ? "many" : "few"}.a'), 'many');
          expect(eval('{a: 1}["a"]'), 1);
          expect(eval('length([1, 2, 3])'), 3);
          expect(FormulaEvaluator.errorOf('{a 1}'), isNotNull);
          expect(FormulaEvaluator.referencedPaths('{a: count, b: x.y}'), {
            'count',
            'x.y',
          });
        });

      });
    }

    {
      final DateTime now = DateTime.now();
      final DateTime today = DateTime(now.year, now.month, now.day);
      String day(int offset) => _iso(today.add(Duration(days: offset)));
      String dateOnly(int offset) =>
          day(offset).substring(0, 10); // e.g. 2026-10-21

      final List<Map<String, Object?>> tasks = [
        {'title': 'Buy milk', 'done': false, 'due': dateOnly(0), 'pts': 3},
        {'title': 'Call Mum', 'done': true, 'due': day(-2), 'pts': 1},
        {'title': 'buy stamps', 'done': false, 'due': day(3), 'pts': 2},
        {'title': 'Plan trip', 'done': false, 'pts': 5},
        {'title': null, 'done': false, 'due': _Timestamp(today), 'pts': null},
      ];
      final Map<String, Object?> vars = {
        'tasks': tasks,
        'search': 'BUY',
        'empty': '',
        'tags': ['a', 'b', 'a', 'c', 'b'],
        'cart': [
          {
            'name': 'Tea',
            'price': 2,
            'qty': 4,
            'meta': {'shop': 'x'},
          },
          {
            'name': 'Cake',
            'price': 3.5,
            'qty': 2,
            'meta': {'shop': 'y'},
          },
        ],
        'limit': 2,
        'item': {'name': 'outer'},
      };
      Object? eval(String expression) =>
          FormulaEvaluator.evaluate(expression, (path) => vars[path]);
      List<Object?> titles(String expression) => [
        for (final task in eval(expression)! as List) (task as Map)['title'],
      ];

      group('lambdas', () {
        test('parse in argument position, with or without parentheses', () {
          expect(eval('map([1, 2, 3], n => n * 2)'), [2, 4, 6]);
          expect(eval('map([1, 2, 3], (n) => n + limit)'), [3, 4, 5]);
          expect(FormulaEvaluator.errorOf('count(tasks, t => t.done)'), isNull);
          // A lambda on its own is a user function (stored in a variable).
          expect(FormulaEvaluator.errorOf('x => x'), isNull);
          expect(FormulaEvaluator.errorOf('count(tasks, t =>)'), isNotNull);
        });

        test('read nested fields, indexes and accessors of the parameter', () {
          expect(eval('map(cart, c => c.meta.shop)'), ['x', 'y']);
          expect(eval('map(cart, c => c.name.length)'), [3, 4]);
          expect(eval('map([[1, 2], [3]], l => l[0] + l.length)'), [3, 4]);
          expect(eval('map(cart, c => c.missing.deeper)'), [null, null]);
        });

        test('shadow outer variables and still read the others', () {
          expect(eval('map(cart, item => item.name)'), ['Tea', 'Cake']);
          expect(eval('item'), {'name': 'outer'});
          expect(eval('filter([1, 2, 3], n => n > limit)'), [3]);
        });

        test('nest, with inner lambdas seeing outer parameters', () {
          expect(eval('map([1, 2], a => sum(map([10, 20], b => a * b)))'), [
            30,
            60,
          ]);
        });

        test('an error inside a lambda makes the formula null', () {
          expect(eval('map(tasks, t => nope(t))'), isNull);
        });
      });

      group('filter and where', () {
        test('search titles case-insensitively, skipping null titles', () {
          expect(
            titles('filter(tasks, t => contains(lower(t.title), lower(search)))'),
            ['Buy milk', 'buy stamps'],
          );
          expect(
            eval('count(tasks, t => contains(lower(t.title), lower("zzz")))'),
            0,
          );
          // An empty search keeps every item.
          expect(
            eval('count(tasks, t => contains(lower(t.title), lower(empty)))'),
            5,
          );
        });

        test('field forms match truthy or equal values', () {
          expect(titles('filter(tasks, "done")'), ['Call Mum']);
          expect(titles('where(tasks, "done", true)'), ['Call Mum']);
          expect(titles('where(tasks, t => t.pts >= 3)'), [
            'Buy milk',
            'Plan trip',
          ]);
          expect(eval('filter(cart, "meta.shop", "y")'), [
            (vars['cart']! as List)[1],
          ]);
          expect(eval('filter(tasks, "missing")'), isEmpty);
        });

        test('a missing or non-list list gives an empty list', () {
          expect(eval('filter(nothing, t => true)'), isEmpty);
          expect(eval('filter(search, t => true)'), isEmpty);
          expect(eval('filter(null, "done")'), isEmpty);
        });
      });

      group('count, any, all and find', () {
        test('count', () {
          expect(eval('count(tasks)'), 5);
          expect(eval('count(tasks, t => !t.done)'), 4);
          expect(eval('count(tasks, "done")'), 1);
          expect(eval('count(tasks, "done", false)'), 4);
          expect(eval('count(tasks, "pts", null)'), 1);
          expect(eval('count(nothing, t => true)'), 0);
        });

        test('any and all', () {
          expect(eval('any(tasks, t => t.pts > 4)'), true);
          expect(eval('any(tasks, "done", true)'), true);
          expect(eval('any(tasks, t => t.pts > 9)'), false);
          expect(eval('any([0, "", null])'), false);
          expect(eval('any([], t => true)'), false);
          expect(eval('all(tasks, t => length(t.title) > 0)'), false);
          expect(eval('all(cart, c => c.price > 1)'), true);
          expect(eval('all([], t => false)'), true);
          expect(eval('all([1, true, "x"])'), true);
        });

        test('find returns the first match or null', () {
          expect(eval('find(cart, c => c.price > 3).name'), 'Cake');
          expect(eval('find(cart, "name", "Tea").qty'), 4);
          expect(eval('find(cart, c => c.price > 100)'), isNull);
          expect(eval('find(nothing, c => true)'), isNull);
        });
      });

      group('map, sum, join, sortBy and unique', () {
        test('map and sum with lambdas', () {
          expect(eval('map(cart, c => c.price * c.qty)'), [8, 7]);
          expect(eval('map(cart, "name")'), ['Tea', 'Cake']);
          expect(eval('sum(cart, c => c.price * c.qty)'), 15);
          expect(eval('sum(tasks, "pts")'), 11);
          expect(eval('sum(tasks, t => t.missing)'), 0);
          expect(eval('max(map(cart, c => c.qty))'), 4);
          expect(eval('join(cart, " + ", c => upper(c.name))'), 'TEA + CAKE');
        });

        test('sortBy orders numbers, text and dates, missing keys last', () {
          expect(titles('sortBy(tasks, "pts")'), [
            'Call Mum',
            'buy stamps',
            'Buy milk',
            'Plan trip',
            null,
          ]);
          expect(titles('sortBy(tasks, t => t.pts, "desc")'), [
            'Plan trip',
            'Buy milk',
            'buy stamps',
            'Call Mum',
            null,
          ]);
          // Dates written in different forms sort by moment; no date goes last.
          expect(titles('sortBy(tasks, "due")'), [
            'Call Mum',
            'Buy milk',
            null,
            'buy stamps',
            'Plan trip',
          ]);
          expect(titles('sortBy(tasks, t => lower(t.title))'), [
            'Buy milk',
            'buy stamps',
            'Call Mum',
            'Plan trip',
            null,
          ]);
          expect(eval('sortBy([3, 1, 2])'), [1, 2, 3]);
          expect(eval('sortBy(nothing, "x")'), isEmpty);
          // Ties keep their order.
          expect(eval('map(sortBy(cart, c => 1), "name")'), ['Tea', 'Cake']);
        });

        test('unique keeps the first of each value or key', () {
          expect(eval('unique(tags)'), ['a', 'b', 'c']);
          expect(eval('unique([1, "1", 2])'), [1, 2]);
          expect(titles('unique(tasks, "done")'), ['Buy milk', 'Call Mum']);
          expect(eval('length(unique(tasks, t => t.pts > 2))'), 2);
          expect(eval('unique(nothing)'), isEmpty);
        });
      });

      group('text helpers', () {
        test('trim, startsWith, endsWith, contains, lower and upper', () {
          expect(eval('trim("  hi  ")'), 'hi');
          expect(eval('trim(nothing)'), '');
          expect(eval('startsWith("Buy milk", "Buy")'), true);
          expect(eval('startsWith("Buy milk", "milk")'), false);
          expect(eval('startsWith(nothing, "a")'), false);
          expect(eval('endsWith("a.png", ".png")'), true);
          expect(eval('endsWith(nothing, "")'), false);
          expect(eval('contains("Buy milk", "milk")'), true);
          expect(eval('contains(nothing, "milk")'), false);
          expect(eval('lower(nothing) + upper(nothing)'), '');
        });
      });

      group('dates in comparisons', () {
        test('ISO text from today() and addDays orders by date', () {
          expect(eval('today() < addDays(today(), 1)'), true);
          expect(eval('addDays(today(), -1) < today()'), true);
          expect(eval('addDays(today(), 1) >= today()'), true);
          expect(eval('now() >= today()'), true);
          // Text order alone gets these wrong.
          expect(eval('"2026-10-21" == "2026-10-21T00:00:00.000"'), true);
          expect(
            eval('"2026-10-21T09:00:00Z" < "2026-10-21T10:00:00+00:00"'),
            true,
          );
          expect(
            eval('"2026-10-21T12:00:00+02:00" < "2026-10-21T11:00:00Z"'),
            true,
          );
          expect(eval('"2026-10-21 23:00" < "2026-10-22"'), true);
        });

        test('dates compare with timestamps and epoch milliseconds', () {
          vars['stamp'] = _Timestamp(today);
          vars['millis'] = today.millisecondsSinceEpoch;
          expect(eval('stamp == today()'), true);
          expect(eval('stamp < addDays(today(), 1)'), true);
          expect(eval('millis == today()'), true);
          expect(eval('millis < addDays(today(), 1)'), true);
        });

        test('a missing date is neither before nor after a date', () {
          expect(eval('nothing < today()'), false);
          expect(eval('nothing > today()'), false);
          expect(eval('today() <= nothing'), false);
          expect(eval('nothing == today()'), false);
          expect(eval('nothing != today()'), true);
        });

      });

      group('objects and slices', () {
        test('concat joins lists and range counts', () {
          expect(eval('concat(take(tags, 2), [1], take(tags, 1))'), [
            'a',
            'b',
            1,
            'a',
          ]);
          expect(eval("length(concat(cart, filter(cart, 'qty', 2)))"), 3);
          expect(eval('range(3)'), [0, 1, 2]);
          expect(eval('range(0)'), isEmpty);
        });

        test('obj builds a map from key-value pairs', () {
          expect(eval("obj('cat', 'Mechanical', 'min', 80)"), {
            'cat': 'Mechanical',
            'min': 80,
          });
          expect(
            eval("map(cart, c => obj('name', c.name, 'total', c.price * c.qty))"),
            [
              {'name': 'Tea', 'total': 8},
              {'name': 'Cake', 'total': 7},
            ],
          );
        });

        test('set copies a map with fields changed or added', () {
          expect(eval("set(find(cart, 'name', 'Tea'), 'qty', 5, 'note', 'x')"), {
            'name': 'Tea',
            'price': 2,
            'qty': 5,
            'meta': {'shop': 'x'},
            'note': 'x',
          });
          // The original is unchanged.
          expect((vars['cart']! as List).first, containsPair('qty', 4));
          expect(
            eval(
              "map(cart, c => if(c.name == 'Cake', set(c, 'qty', 0), c))[1].qty",
            ),
            0,
          );
        });

        test('get reads a field or index named by a value', () {
          expect(eval("get(find(cart, 'qty', 2), 'name')"), 'Cake');
          expect(eval('get(tags, limit)'), 'a');
          expect(eval("get(obj('PA', 'Press Line A'), 'PA')"), 'Press Line A');
        });

        test('take and skip slice lists', () {
          expect(eval('take(tags, 2)'), ['a', 'b']);
          expect(eval('skip(tags, 3)'), ['c', 'b']);
          expect(eval('take(tags, 99)').toString(), '[a, b, a, c, b]');
          expect(eval('take(tags, -1)'), isEmpty);
          // A running total: the first n items.
          expect(eval('sum(take(cart, 2), c => c.qty)'), 6);
        });

        test('indexOf finds an item, a match or nothing', () {
          expect(eval("indexOf(tags, 'c')"), 3);
          expect(eval("indexOf(cart, c => c.name == 'Cake')"), 1);
          expect(eval("indexOf(cart, 'name', 'Tea')"), 0);
          expect(eval("indexOf(tags, 'z')"), -1);
        });

        test('split and pad handle clock times', () {
          expect(eval("split('19:42', ':')"), ['19', '42']);
          expect(
            eval(
              "number(split('19:42', ':')[0]) * 60 + number(split('19:42', ':')[1])",
            ),
            1182,
          );
          expect(eval('pad(7)'), '07');
          expect(eval("pad(floor(1182 / 60)) + ':' + pad(1182 % 60)"), '19:42');
          expect(eval("pad(5, 3, ' ')"), '  5');
        });
      });
    }

    {
    }

    {
      final Map<String, Object?> vars = {
        'timeline': [
          {'t': '10:00', 'label': 'Reported'},
          {'t': '10:05', 'label': 'Assigned'},
          {'t': '10:05', 'label': 'Repair started'},
        ],
        'items': [
          {'id': '1a', 'name': 'Tyres'},
          {'id': '1b', 'name': 'Lights'},
          {'id': '1c', 'name': 'Mirrors'},
        ],
        'answers': {'1b': 'fail'},
        'vin': '1FUJGLDR5LLMX4821',
        'zone': 1,
      };
      Object? eval(String expression) =>
          FormulaEvaluator.evaluate(expression, (path) => vars[path]);

      group('reverse', () {
        test('reverse reverses a list', () {
          expect(eval('map(reverse(timeline), e => e.label)'), [
            'Repair started',
            'Assigned',
            'Reported',
          ]);
        });

        test('reverse leaves the list it reads unchanged', () {
          eval('reverse(timeline)');
          expect((vars['timeline']! as List).first, {
            't': '10:00',
            'label': 'Reported',
          });
        });

      });

      group('lambda index', () {
        test('map passes the index as the second parameter', () {
          expect(eval('map(items, (i, n) => n + 1 + ". " + i.name)'), [
            '1. Tyres',
            '2. Lights',
            '3. Mirrors',
          ]);
        });

      });

      group('toMap', () {
        test('toMap builds a map from key and value lambdas', () {
          expect(eval('toMap(items, i => i.id, i => "pass")'), {
            '1a': 'pass',
            '1b': 'pass',
            '1c': 'pass',
          });
        });

        test('toMap keeps the whole item when no value is asked for', () {
          expect(eval('toMap(items, "id")["1b"].name'), 'Lights');
        });

        test('toMap of something that is not a list is empty', () {
          expect(eval('toMap(missing, i => i)'), <String, Object?>{});
        });
      });
    }

    group('editing lists', () {
      {
        final Map<String, Object?> vars = {
          'plan': [
            {'uid': 'a', 'x': 1, 'w': 2},
            {'uid': 'b', 'x': 4, 'w': 2},
            {'uid': 'c', 'x': 5, 'w': 1},
          ],
          'sel': 'b',
          'drag': {'dx': 30, 'dy': -12},
        };
        Object? eval(String e) => FormulaEvaluator.evaluate(e, (p) {
          Object? v = vars;
          for (final part in p.split('.')) {
            v = v is Map ? v[part] : null;
          }
          return v;
        });

        test('insert, remove, replace and move return a changed list', () {
          expect(eval("length(append(plan, obj('uid', 'd')))"), 4);
          expect(eval("map(removeAt(plan, 0), 'uid')"), ['b', 'c']);
          expect(eval("map(setAt(plan, 1, obj('uid', 'z')), 'uid')"), [
            'a',
            'z',
            'c',
          ]);
          expect(eval("map(insertAt(plan, 0, obj('uid', 'z')), 'uid')"), [
            'z',
            'a',
            'b',
            'c',
          ]);
          expect(eval('slice(range(10), 2, 5)'), [2, 3, 4]);
          expect(eval('range(2, 5)'), [2, 3, 4, 5]);
          expect(eval('concat([1, 2], [3], 4)'), [1, 2, 3, 4]);
          expect(eval('reverse([1, 2, 3])'), [3, 2, 1]);
          expect(eval('first(plan).uid + last(plan).uid + at(plan, 1).uid'), 'acb');
          // Out of range edits leave the list as it was.
          expect(eval('length(removeAt(plan, 7))'), 3);
        });

        test('flatMap maps each item to a list and joins the results', () {
          // Items overlap when their [x, x + w) ranges intersect.
          final Object? pairs = eval(
            "flatMap(range(length(plan)), i => map(filter(range(i + 1, length(plan)), j => plan[i].x < plan[j].x + plan[j].w && plan[j].x < plan[i].x + plan[i].w), j => plan[i].uid + '-' + plan[j].uid))",
          );
          expect(pairs, ['b-c']);
        });
      }

      {
        Object? f(String formula, [Map<String, Object?> vars = const {}]) =>
            const Expressions().evaluate('\${= $formula}', ValuesScope(vars));

        test('without removes one item or a list of them', () {
          final vars = {'s': ['g001', 'g002', 'g001']};
          expect(f("without(s, 'g001')", vars), ['g002']);
          expect(f("without(s, ['g002'])", vars), ['g001', 'g001']);
          expect(f('without(s, null)', vars), ['g001', 'g002', 'g001']);
        });
      }
    });

    group('series', () {
      {
        // Half-hourly tide heights, NOAA style.
        final List<Map<String, String>> tides = [
          {'t': '2026-10-22 14:00', 'v': '2.0'},
          {'t': '2026-10-22 14:30', 'v': '1.4'},
          {'t': '2026-10-22 15:00', 'v': '0.8'},
          {'t': '2026-10-22 15:30', 'v': '0.6'},
          {'t': '2026-10-22 16:00', 'v': '1.2'},
          {'t': '2026-10-22 16:30', 'v': '1.8'},
        ];

        group('lists', () {
          test('slice takes a range, and negative positions count from the end', () {
            expect(eval('slice([1, 2, 3, 4], 1, 3)'), [2, 3]);
            expect(eval('slice([1, 2, 3, 4], -2)'), [3, 4]);
            expect(eval('slice([1, 2], 5)'), isEmpty);
          });

          test('range can step dates by minutes', () {
            expect(eval('range("2026-10-22T07:25:00", "2026-10-22T07:40:00", 5)'), [
              '2026-10-22T07:25:00.000',
              '2026-10-22T07:30:00.000',
              '2026-10-22T07:35:00.000',
              '2026-10-22T07:40:00.000',
            ]);
          });

          test('runs groups consecutive items that match', () {
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

          test('minBy and maxBy give the item itself', () {
            expect(eval('minBy(tides, "v")', {'tides': tides}), {
              't': '2026-10-22 15:30',
              'v': '0.6',
            });
            expect(
              eval('maxBy(tides, t => number(t.v)).t', {'tides': tides}),
              '2026-10-22 14:00',
            );
          });

        });

        group('interpolate', () {
          test('interpolate reads a value between two points of a dated series', () {
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

          test('interpolate is null outside the series', () {
            expect(
              eval('interpolate(tides, "t", "v", "2026-10-22T13:00")', {
                'tides': tides,
              }),
              isNull,
            );
          });

          test('interpolate works on a numbered series', () {
            expect(
              eval(
                'interpolate([obj("x", 0, "y", 0), obj("x", 10, "y", 5)], "x", "y", 4)',
              ),
              closeTo(2, 1e-9),
            );
          });
        });
      }

      {
        Object? eval(String e) => FormulaEvaluator.evaluate(e, (path) => null);

        test('groupBy groups items in the order each group first appears', () {
          final Object? groups = FormulaEvaluator.evaluate(
            'groupBy(rows, r => r.date)',
            (path) => path == 'rows'
                ? [
                    {'date': '2026-10-30', 'a': 1},
                    {'date': '2026-10-29', 'a': 2},
                    {'date': '2026-10-30', 'a': 3},
                  ]
                : null,
          );
          expect(groups, [
            {
              'key': '2026-10-30',
              'items': [
                {'date': '2026-10-30', 'a': 1},
                {'date': '2026-10-30', 'a': 3},
              ],
              'count': 2,
            },
            {
              'key': '2026-10-29',
              'items': [
                {'date': '2026-10-29', 'a': 2},
              ],
              'count': 1,
            },
          ]);
          expect(eval('groupBy([1, 2, 3, 4], x => x > 2)'), [
            {
              'key': false,
              'items': [1, 2],
              'count': 2,
            },
            {
              'key': true,
              'items': [3, 4],
              'count': 2,
            },
          ]);
        });
      }
    });

    group('maps', () {
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

      test('set and merge give changed copies', () {
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
        expect(eval('keys(first(units))'), ['id', 'hours', 'status']);
        expect(eval("values(obj('a', 1))"), [1]);
      });

      test('one item of a list is updated with map and set', () {
        final Object? result = eval(
          "map(units, u => if(u.id == unitId, set(u, 'hours', u.hours + 5), u))",
        );
        expect(result, [
          {'id': 'ex1', 'hours': 10.5, 'status': 'Available'},
          {'id': 'ex2', 'hours': 104, 'status': 'On rent'},
        ]);
      });
    
    });
  }

  group('records', () {
    recordTests();
  });
}
