import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// A stand-in for a Firestore Timestamp, which formulas read via `toDate()`.
class _Timestamp {
  final DateTime date;

  const _Timestamp(this.date);

  DateTime toDate() => date;
}

String _iso(DateTime date) => date.toIso8601String();

void main() {
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
      expect(FormulaEvaluator.errorOf('x => x'), isNotNull);
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

    test('referenced paths leave out lambda parameters', () {
      expect(
        FormulaEvaluator.referencedPaths(
          'count(tasks, t => contains(lower(t.title), lower(search)) '
          '&& t.pts > limit && t[0])',
        ),
        {'tasks', 'search', 'limit'},
      );
      expect(
        FormulaEvaluator.referencedPathsInText(
          r'${= map(cart, item => item.name)} ${= item.name}',
        ),
        {'cart', 'item.name'},
      );
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

    test('numbers and plain text still compare as before', () {
      expect(eval('2 < 10'), true);
      expect(eval('"2" < "10"'), true);
      expect(eval('"apple" < "banana"'), true);
      expect(eval('nothing < 1'), true);
      expect(eval('"2026" == 2026'), true);
    });

    test('Today, Upcoming, Overdue and due colours', () {
      expect(titles('filter(tasks, t => t.due == today())'), [
        'Buy milk',
        null,
      ]);
      expect(titles('filter(tasks, t => diffDays(today(), t.due) == 0)'), [
        'Buy milk',
        null,
      ]);
      expect(titles('filter(tasks, t => t.due > addDays(today(), 1))'), [
        'buy stamps',
      ]);
      expect(titles('filter(tasks, t => !t.done && t.due < today())'), isEmpty);
      expect(titles('filter(tasks, t => t.due < today())'), ['Call Mum']);
      expect(eval('count(tasks, t => t.due >= today())'), 3);
      expect(
        eval(
          'map(tasks, t => t.due < today() ? "red" : '
          't.due == today() ? "amber" : t.due ? "grey" : "none")',
        ),
        ['amber', 'red', 'grey', 'none', 'amber'],
      );
    });
  });

  test('every new function is documented with an example', () {
    final Map<String, FormulaFunctionDoc> docs = {
      for (final doc in FormulaEvaluator.functionDocs) doc.name: doc,
    };
    for (final name in [
      'filter',
      'where',
      'count',
      'find',
      'any',
      'all',
      'map',
      'sortBy',
      'unique',
      'sum',
      'trim',
      'startsWith',
      'endsWith',
      'contains',
    ]) {
      expect(docs[name]?.signature, startsWith('$name('), reason: name);
      expect(docs[name]!.example, isNotEmpty, reason: name);
    }
    // Every documented example parses.
    for (final doc in FormulaEvaluator.functionDocs) {
      final String example = doc.example.split(' → ').first.split(' (').first;
      expect(
        FormulaEvaluator.errorOf(example.split(' or ').first),
        isNull,
        reason: doc.example,
      );
    }
  });

  testWidgets('lambdas read item and variables through PropertyValueDelegate', (
    tester,
  ) async {
    final List<VariableData> variables = [
      VariableData(
        id: 'search',
        name: 'search',
        type: VariableType.text,
        value: 'milk',
      ),
      VariableData(
        id: 'tasks',
        name: 'tasks',
        type: VariableType.list,
        value: [
          {'title': 'Buy Milk'},
          {'title': 'Walk'},
        ],
      ),
    ];
    late ScopedValues values;
    await tester.pumpWidget(
      IndexedItemProvider(
        item: IndexedItem(0, {'title': 'Walk'}),
        child: Builder(
          builder: (context) {
            values = ScopedValues.of(context, variablesOverrides: variables);
            return const SizedBox();
          },
        ),
      ),
    );
    String sub(String text) => PropertyValueDelegate.substituteVariables(
      text,
      scopedValues: values,
      nullSubstitutionMode: NullSubstitutionMode.emptyString,
    );
    expect(
      sub(r'${= count(tasks, t => contains(lower(t.title), lower(search)))}'),
      '1',
    );
    expect(
      sub(r'${= count(tasks, t => t.title == item.title)} ${item.title}'),
      '1 Walk',
    );
    expect(
      sub(
        r'${= isEmpty(filter(tasks, t => contains(t.title, "zz"))) ? '
        r'"No results for " + search : ""}',
      ),
      'No results for milk',
    );
  });
}
