import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

  Object? eval(String expression) => FormulaEvaluator.evaluate(expression, (path) {
    Object? value = vars;
    for (final part in path.split('.')) {
      value = value is Map ? value[part] : null;
    }
    return value;
  });

  test('obj, set, unset and merge build maps without braces', () {
    expect(eval('obj("company", name, "n", 4)'), {'company': 'Keystone', 'n': 4});
    expect(eval('set(obj("a", 1), "b", 2)'), {'a': 1, 'b': 2});
    expect(eval('unset(obj("a", 1, "b", 2), "a")'), {'b': 2});
    expect(eval('merge(obj("a", 1, "b", 2), obj("b", 3), obj("c", 4))'), {'a': 1, 'b': 3, 'c': 4});
    expect(eval('set(tags, 1, "x")'), ['a', 'x', 'c', 'd']);
    expect(eval('set(tags, 9, "z")'), ['a', 'b', 'c', 'd', 'z']);
  });

  test('append, prepend and concat return new lists', () {
    expect(eval('append(tags, "e", "f")'), ['a', 'b', 'c', 'd', 'e', 'f']);
    expect(eval('prepend(tags, "z")'), ['z', 'a', 'b', 'c', 'd']);
    expect(eval('concat(tags, ["e"], null)'), ['a', 'b', 'c', 'd', 'e']);
    expect(eval('append(null, 1)'), [1]);
    expect(vars['tags'], ['a', 'b', 'c', 'd'], reason: 'arguments are not changed');
  });

  test('updateWhere and removeWhere change matching records', () {
    expect(
      eval('updateWhere(logs, "id", logId, obj("signed", true))'),
      [
        (vars['logs'] as List)[0],
        {...((vars['logs'] as List)[1] as Map), 'signed': true},
      ],
    );
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
    expect(eval('first(tags)'), 'a');
    expect(eval('last(tags)'), 'd');
    expect(eval('first(null)'), isNull);
    expect(eval('range(3)'), [0, 1, 2]);
    expect(eval('range(2, 5)'), [2, 3, 4]);
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
