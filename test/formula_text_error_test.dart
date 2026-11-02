import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('textErrorOf finds a formula that does not parse', () {
    expect(FormulaEvaluator.textErrorOf('Hi'), isNull);
    expect(FormulaEvaluator.textErrorOf(r'${= a + 1} items'), isNull);
    expect(FormulaEvaluator.textErrorOf(r'${= sun(1)}'), isNull);
    expect(FormulaEvaluator.textErrorOf(r'${= a +}'), contains("doesn't parse"));
    expect(FormulaEvaluator.textErrorOf(r'${= (a + 1}'), isNotNull);
  });
}
