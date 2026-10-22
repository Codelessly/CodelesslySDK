import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

/// Functions that build and update records (maps) and lists, so actions
/// can change one item of a list variable: findIndex, obj, set, merge,
/// concat, append, take, skip, group, pad.
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

  test('findIndex finds by lambda, field and value, or plain value', () {
    expect(eval('findIndex(defects, d => d.id == id)'), 1);
    expect(eval('findIndex(defects, "status", "open")'), 0);
    expect(eval('indexOf(["a", "b"], "b")'), 1);
    expect(eval('findIndex(defects, d => d.id == "nope")'), -1);
    expect(eval('findIndex(null, d => true)'), -1);
  });

  test('obj builds a map from key/value pairs', () {
    expect(eval('obj("t", 3, "by", user.name)'), {'t': 3, 'by': 'Luis'});
    expect(eval('obj()'), <String, Object?>{});
  });

  test('set copies a map or list with one key or index changed', () {
    expect(eval('set(answers, "1b", "fail")'), {'1a': 'pass', '1b': 'fail'});
    expect(vars['answers'], {
      '1a': 'pass',
    }, reason: 'the original is unchanged');
    expect(eval('set([1, 2, 3], 1, 9)'), [1, 9, 3]);
    expect(eval('set([1, 2], 2, 3)'), [1, 2, 3]);
    final Object? updated = eval(
      'set(defects, findIndex(defects, d => d.id == id), '
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

  test('group adds thousands separators and pad left-pads', () {
    expect(eval('group(412908)'), '412,908');
    expect(eval('group(-1234.5)'), '-1,234.5');
    expect(eval('group(12)'), '12');
    expect(eval('pad(7, 2)'), '07');
    expect(eval('pad("5", 3, " ")'), '  5');
  });
}
