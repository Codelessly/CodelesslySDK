import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

/// Formulas that build and change values: one item of a list updated in
/// place, a new item added at either end.
void main() {
  final Map<String, Object?> vars = {
    'items': [
      {'id': 'a', 'status': 'open', 'n': 1},
      {'id': 'b', 'status': 'review', 'n': 2},
    ],
    'selectedId': 'b',
  };
  Object? eval(String expression) =>
      FormulaEvaluator.evaluate(expression, (path) {
        Object? value = vars;
        for (final part in path.split('.')) {
          value = value is Map ? value[part] : null;
        }
        return value;
      });

  test('one item of a list updated, the original unchanged', () {
    expect(
      eval(
        "map(items, i => i.id == selectedId ? merge(i, object('status', 'closed', 'n', i.n * 10)) : i)",
      ),
      [
        {'id': 'a', 'status': 'open', 'n': 1},
        {'id': 'b', 'status': 'closed', 'n': 20},
      ],
    );
    expect(eval("map(items, i => set(i, 'status', 'done'))"), [
      {'id': 'a', 'status': 'done', 'n': 1},
      {'id': 'b', 'status': 'done', 'n': 2},
    ]);
    expect((vars['items'] as List)[1], {'id': 'b', 'status': 'review', 'n': 2});
  });

  test('append and prepend copy a list with items added', () {
    expect(eval("map(append(items, object('id', 'c')), 'id')"), [
      'a',
      'b',
      'c',
    ]);
    expect(eval("map(prepend(items, object('id', 'z')), 'id')"), [
      'z',
      'a',
      'b',
    ]);
    expect(eval('prepend([3], 1, 2)'), [1, 2, 3]);
    expect(eval('prepend(null, 1)'), [1]);
    expect((vars['items'] as List).length, 2);
  });

  test('every new function is documented', () {
    final Set<String> documented = {
      for (final doc in FormulaEvaluator.functionDocs) doc.name,
    };
    for (final name in ['prepend']) {
      expect(documented, contains(name));
    }
  });
}
