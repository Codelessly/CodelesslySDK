import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a screen formula over app variables is worked out once per change, not per read', () {
    var calls = 0;
    final app = VariableScope([
      const Variable(name: 'w', type: VariableType.integer, value: 1),
      const Variable(name: 'rows', type: VariableType.list, value: [1, 2, 3]),
    ]);
    final screen = VariableScope([
      const Variable(name: 'scaled', type: VariableType.list, formula: 'map(rows, r => r * w)'),
    ], parent: app);
    final items = [for (var i = 0; i < 3; i++) ValuesScope({'item': i}, screen)];
    FormulaEvaluator.debugOnEvaluate = () => calls++;
    addTearDown(() => FormulaEvaluator.debugOnEvaluate = null);
    for (final item in items) {
      expect(readPath(item, 'scaled'), [1, 2, 3]);
    }
    expect(calls, 1);
    app.set('w', 2);
    for (final item in items) {
      expect(readPath(item, 'scaled'), [2, 4, 6]);
    }
    expect(calls, 2);
  });

  test('a formula reading an item is still worked out per reader', () {
    final app = VariableScope([const Variable(name: 'k', type: VariableType.integer, value: 10)]);
    final screen = VariableScope([
      const Variable(name: 'plus', type: VariableType.integer, formula: 'item + k'),
    ], parent: app);
    expect(readPath(ValuesScope({'item': 1}, screen), 'plus'), 11);
    expect(readPath(ValuesScope({'item': 2}, screen), 'plus'), 12);
  });

  test('a formula over an app computed variable that reads the clock is not cached', () {
    final app = VariableScope([
      const Variable(name: 'tick', type: VariableType.text, formula: 'now()'),
    ]);
    final screen = VariableScope([
      const Variable(name: 'label', type: VariableType.text, formula: "'at ' + tick"),
    ], parent: app);
    expect(readPath(screen, 'label'), startsWith('at '));
    // Not cached: no entry kept for it.
    expect(screen.debugSharedCacheKeys, isNot(contains('label')));
  });
}
