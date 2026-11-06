import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

/// A lambda written in place can be called at once, and a function a value
/// holds can be called: `(k => k == 'x' ? 1 : 2)(s.kind)`.
void main() {
  final Map<String, Object?> vars = {
    's': {'kind': 'treatment'},
    'pick': r"${= (a, b) => a + b}",
    'fns': [r"${= x => x * 10}"],
  };
  Object? eval(String expression) =>
      FormulaEvaluator.evaluate(expression, (path) {
        Object? v = vars;
        for (final p in path.split('.')) {
          v = v is Map ? v[p] : null;
        }
        return v;
      });

  test('an immediately invoked lambda', () {
    expect(eval("(k => k == 'treatment' ? 1 : 2)(s.kind)"), 1);
    expect(eval('((a, b) => a * b)(3, 4)'), 12);
    expect(eval('(() => 7)()'), 7);
  });

  test('a function held in a value', () {
    expect(eval('pick(2, 3)'), 5);
    expect(eval('(x => y => x + y)(2)(5)'), 7);
  });

  test('calling a non-function is null, not a crash', () {
    expect(eval('(1 + 2)(3)'), isNull);
  });
}
