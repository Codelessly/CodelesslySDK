import 'package:codelessly_sdk_v2/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('textErrorOf finds a formula that does not parse', () {
    expect(FormulaEvaluator.textErrorOf('Hi'), isNull);
    expect(FormulaEvaluator.textErrorOf(r'${= a + 1} items'), isNull);
    expect(FormulaEvaluator.textErrorOf(r'${= sun(1)}'), isNull);
    expect(FormulaEvaluator.textErrorOf(r'${= merge(r, {a: 1})}'), isNull);
    expect(
      FormulaEvaluator.textErrorOf(r'${= a +}'),
      contains("doesn't parse"),
    );
    expect(
      FormulaEvaluator.textErrorOf(r'Total ${= sum(1, 2'),
      contains('not closed at character 7'),
    );
    expect(
      FormulaEvaluator.textErrorOf(r"${= 'it's'}"),
      contains('not closed at character 1'),
    );
  });

  test('a backslash keeps a quote inside quoted text', () {
    expect(FormulaEvaluator.textErrorOf(r"${= 'Won\'t ' + n}"), isNull);
    expect(formulaRegex.hasMatch(r"${= 'Won\'t ' + n}"), isTrue);
    expect(FormulaEvaluator.evaluate(r"'Won\'t ' + n", (_) => 2), "Won't 2");
    expect(FormulaEvaluator.evaluate(r"'a\b'", (_) => null), r'a\b');
  });
}
