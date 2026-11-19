// What a document's formulas may cost: a page whose variables and functions
// are written the plain way (a variable read by twelve others in turn, a
// function whose body writes an argument's expression three times) is worked
// out in the time its size asks, and functions that call each other without
// end stop.
import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

Variable _value(String name, Object? value, [VariableType type = VariableType.list]) => Variable(id: name, name: name, type: type, value: value);
Variable _computed(String name, String formula, [VariableType type = VariableType.map]) =>
    Variable(id: name, name: name, type: type, formula: formula);
Variable _function(String name, List<String> params, String body) => Variable(id: name, name: name, formula: body, parameters: params);

void main() {
  tearDown(() {
    FormulaFunction.deadline = null;
    FormulaFunction.onRunaway = null;
  });

  test('a variable twelve others read in turn, each for every item of a list, is worked out once a change', () {
    // pass12 reads pass11 for each of 40 cells, which reads pass10 for each…
    // worked out per read that is 40 to the 12th evaluations.
    final scope = VariableScope([
      _value('cells', [for (var i = 0; i < 40; i++) {'k': 'c$i', 'raw': i}]),
      _computed('pass0', 'toMap(cells, t => t.k, t => t.raw)'),
      for (var p = 1; p <= 12; p++) _computed('pass$p', 'toMap(cells, t => t.k, t => get(pass${p - 1}, t.k) + 1)'),
    ]);
    final watch = Stopwatch()..start();
    final last = readPath(scope, 'pass12') as Map;
    expect(last['c0'], 12);
    expect(last['c39'], 51);
    expect(watch.elapsed, lessThan(const Duration(seconds: 5)));
  });

  test('a function whose body writes an argument\'s expression three times, nine functions deep, is called once for each argument', () {
    // level9(x) = level8(x) == -1 ? -1 : level8(x) + level8(x): 3 to the 9th
    // calls of level0 without a memory of the calls made.
    var calls = 0;
    final scope = VariableScope([
      _function('level0', ['x'], 'x + 1'),
      for (var l = 1; l <= 14; l++) _function('level$l', ['x'], 'level${l - 1}(x) == -1 ? -1 : level${l - 1}(x) + level${l - 1}(x)'),
    ]);
    FormulaFunction.onRunaway = (_) => calls++;
    final watch = Stopwatch()..start();
    expect(FormulaEvaluator.evaluate('level14(1)', (p) => readPath(scope, p)), 2 * 16384);
    expect(calls, 0, reason: 'not cut off');
    expect(watch.elapsed, lessThan(const Duration(seconds: 5)));
  });

  test('a call that reads something different each time (random, newId, now) is worked out each time', () {
    final scope = VariableScope([
      _function('fresh', ['p'], 'newId(p)'),
    ]);
    final value = FormulaEvaluator.evaluate('[fresh("a"), fresh("a")]', (p) => readPath(scope, p)) as List;
    expect(value[0], isNot(value[1]));
  });

  test('functions that call each other without end stop: nothing, and the function is told', () {
    final told = <String>[];
    final scope = VariableScope([
      // Each call makes two more with another argument, 128 deep.
      _function('grow', ['n'], 'grow(n * 2) + grow(n * 2 + 1)'),
    ]);
    FormulaFunction.onRunaway = told.add;
    final watch = Stopwatch()..start();
    FormulaEvaluator.evaluate('grow(1)', (p) => readPath(scope, p));
    expect(told, ['grow(n * 2) + grow(n * 2 + 1)']);
    expect(watch.elapsed, lessThan(const Duration(seconds: 20)));
  });

  test('past a deadline every function call gives nothing at once', () {
    final scope = VariableScope([
      _function('twice', ['n'], 'n * 2'),
    ]);
    FormulaFunction.deadline = DateTime.now().subtract(const Duration(seconds: 1));
    final value = FormulaEvaluator.evaluate('map(range(2000), i => twice(i))', (p) => readPath(scope, p)) as List;
    expect(value.last, isNull);
    FormulaFunction.deadline = null;
    expect((FormulaEvaluator.evaluate('map(range(3), i => twice(i))', (p) => readPath(scope, p)) as List).last, 4);
  });
}
