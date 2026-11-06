import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

/// A design canvas works out computed variables with a time budget and
/// keeps each result while what it reads stays the same, so a heavy
/// formula (a honeycomb drawn cell by cell) can't freeze the editor.
void main() {
  // Sorting a long list by a function of each item: slow enough to blow a
  // tiny budget.
  const String heavy =
      r"${= map(range(40), i => length(sortBy(range(400), j => slowKey(j, i))))}";

  Map<String, VariableData> variables({int n = 3}) => {
    'n': VariableData(id: 'n', name: 'n', type: VariableType.integer, value: n),
    'slowKey': VariableData(
      id: 'slowKey',
      name: 'slowKey',
      formula: 'sin(j * 12.9898 + i) * 43758.5453 % 1',
      parameters: const ['j', 'i'],
    ),
    'heavy': VariableData(
      id: 'heavy',
      name: 'heavy',
      type: VariableType.list,
      value: heavy,
    ),
    'double': VariableData(
      id: 'double',
      name: 'double',
      type: VariableType.integer,
      value: r'${= n * 2}',
    ),
  };

  test('a formula past its budget ends quickly and is marked slow', () {
    final cache = ComputedPreviewCache();
    final Stopwatch clock = Stopwatch()..start();
    final resolved = ComputedVariables.resolveAll(
      variables(),
      cache: cache,
      budget: const Duration(milliseconds: 5),
    );
    expect(clock.elapsedMilliseconds, lessThan(1000));
    expect(resolved['heavy']!.value, '');
    expect(cache.slow, {'heavy'});
    // Others still work.
    expect(resolved['double']!.value, '6');
  });

  test('without a budget the same formula works out in full', () {
    final resolved = ComputedVariables.resolveAll(variables());
    expect(resolved['heavy']!.value, startsWith('[400,400'));
  });

  test('a result is reused while what it reads is unchanged', () {
    final cache = ComputedPreviewCache();
    final first = ComputedVariables.resolveAll(variables(), cache: cache);
    final again = ComputedVariables.resolveAll(variables(), cache: cache);
    expect(identical(first['heavy'], again['heavy']), isTrue);
    expect(identical(first['double'], again['double']), isTrue);
    // n changed: double is worked out again; heavy doesn't read n.
    final changed = ComputedVariables.resolveAll(variables(n: 5), cache: cache);
    expect(changed['double']!.value, '10');
    expect(identical(first['heavy'], changed['heavy']), isTrue);
  });

  test('a budget inside a budget keeps the outer limit', () {
    final outer = FormulaEvaluator.withinBudget(
      const Duration(seconds: 5),
      () => FormulaEvaluator.withinBudget(
        const Duration(microseconds: 1),
        () => FormulaEvaluator.evaluate('length(range(3))', (_) => null),
      ),
    );
    expect(outer.result.result, 3);
    expect(outer.exceeded, isFalse);
  });
}
