import 'package:codelessly_sdk/src/runtime/expressions/formula.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a function variable whose body is the lambda itself is called', () {
    final f = FormulaFunction(['a', 'b', 't'], '(a, b, t) => a + (b - a) * t', (_) => null);
    expect(f.call([1, 3, 0.5]), 2);
  });

  test('a plain body still works', () {
    final f = FormulaFunction(['a', 'b'], 'a * b', (_) => null);
    expect(f.call([2, 3]), 6);
  });

  test('a lambda with other parameters is returned as is', () {
    final f = FormulaFunction(['a'], '(x, y) => x + y + a', (_) => null);
    expect(f.call([1]), isNot(isA<num>()));
  });

  test('a lambda over other names with as many parameters is returned, not called', () {
    final f = FormulaFunction(['n'], '(m) => n * m', (_) => null);
    expect(f.call([3]), isNot(isA<num>()));
  });
}
