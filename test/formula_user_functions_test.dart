import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

/// Rounds to a step and writes vulgar fractions, as a recipe app shows
/// quantities: 1.5 → 1½.
const String fractionFormula =
    r"${= (v, step) => (max(step, round(v / step) * step) >= 1 ? floor(max(step, round(v / step) * step)) : '') + "
    r"(max(step, round(v / step) * step) % 1 == 0.25 ? '¼' : (max(step, round(v / step) * step) % 1 == 0.5 ? '½' : "
    r"(max(step, round(v / step) * step) % 1 == 0.75 ? '¾' : '')))}";

Object? eval(String expression, Map<String, Object?> values) =>
    FormulaEvaluator.evaluate(expression, (path) => values[path]);

void main() {
  group('user functions', () {
    test('a lambda variable is called like a built-in function', () {
      final Object? fn = eval('(a, b) => a * 10 + b', {});
      expect(fn.toString(), '(a, b) => a * 10 + b');
      expect(eval('combine(4, 2)', {'combine': fn}), 42);
    });

    test('a function stored as its text (a serialized computed value) works', () {
      expect(eval('twice(21)', {'twice': 'x => x * 2'}), 42);
      expect(eval('twice(21)', {'twice': r'${= x => x * 2}'}), 42);
    });

    test('the fraction formatter', () {
      final Object? fraction = eval(
        FormulaEvaluator.exactExpression(fractionFormula)!,
        {},
      );
      String f(num v, num step) =>
          eval('fraction(v, s)', {'fraction': fraction, 'v': v, 's': step})
              .toString();
      expect(f(1.5, 0.5), '1½');
      expect(f(0.1, 0.25), '¼');
      expect(f(2.74, 0.25), '2¾');
      expect(f(3, 0.5), '3');
    });

    test('functions call other functions, list lambdas and read variables', () {
      final Map<String, Object?> values = {
        'rate': 3,
        'scale': eval('v => v * rate', {}),
      };
      values['total'] = eval('items => sum(map(items, i => scale(i)))', {});
      values['items'] = [1, 2, 3];
      expect(eval('total(items)', values), 18);
    });

    test('missing arguments are null and calling a non-function is null', () {
      expect(eval('f(1)', {'f': '(a, b) => coalesce(b, 7) + a'}), 8);
      expect(eval('nope(1)', {}), isNull);
      expect(eval('n(1)', {'n': 5}), isNull);
    });

    test('a user function call reads its variable', () {
      expect(
        FormulaEvaluator.referencedPaths('fmt(qty * scale, units)'),
        containsAll(['fmt', 'qty', 'scale', 'units']),
      );
      expect(FormulaEvaluator.userFunctionCalls('fmt(round(x), 2)'), {'fmt'});
      expect(
        FormulaEvaluator.referencedPaths('(qty, unit) => qty * scale'),
        {'scale'},
      );
    });

    test('unknown functions are reported against the variables in scope', () {
      expect(FormulaEvaluator.errorOf('sun(1)'), 'Unknown function "sun"');
      expect(
        FormulaEvaluator.errorOf('sun(1)', variables: ['fmt']),
        'Unknown function "sun"',
      );
      expect(FormulaEvaluator.errorOf('fmt(1)', variables: ['fmt']), isNull);
    });

    test('computed variables can define and use functions on the canvas', () {
      final Map<String, VariableData> vars = {
        'fraction': VariableData(
          id: 'f',
          name: 'fraction',
          value: fractionFormula,
          type: VariableType.text,
        ),
        'qty': VariableData(
          id: 'q',
          name: 'qty',
          value: '45',
          type: VariableType.decimal,
        ),
        'label': VariableData(
          id: 'l',
          name: 'label',
          value: r"${= fraction(qty / 15, 0.5) + ' tbsp'}",
          type: VariableType.text,
        ),
      };
      final resolved = ComputedVariables.resolveAll(vars);
      expect(resolved['label']!.value, '3 tbsp');
      expect(ComputedVariables.evaluationOrder(vars), ['fraction', 'label']);
    });
  });
}
