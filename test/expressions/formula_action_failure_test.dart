// A formula an action works out that fails is told to
// FormulaEvaluator.onActionFailure (the render command's formula_failed),
// with the action's type; a binding's formula outside an action stays quiet.
import 'dart:async';

import 'package:codelessly_sdk/src/runtime/expressions/formula.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => FormulaEvaluator.onActionFailure = null);

  test('in an action: the expression, the action and why', () {
    final told = <(String, String, String)>[];
    FormulaEvaluator.onActionFailure = (e, a, why) => told.add((e, a, why));
    runZoned(() => FormulaEvaluator.evaluate('nosuch(sel)', (_) => null), zoneValues: {#codelesslyAction: 'setVariable'});
    runZoned(() => FormulaEvaluator.evaluate('1 +', (_) => null), zoneValues: {#codelesslyAction: 'setVariable'});
    expect(told.map((t) => (t.$1, t.$2)), [('nosuch(sel)', 'setVariable'), ('1 +', 'setVariable')]);
    expect(told.first.$3, contains('nosuch'));
  });

  test('outside an action nothing is told, and the formula still gives null', () {
    final told = <String>[];
    FormulaEvaluator.onActionFailure = (e, a, why) => told.add(e);
    expect(FormulaEvaluator.evaluate('nosuch(sel)', (_) => null), isNull);
    expect(told, isEmpty);
  });
}
