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
}
