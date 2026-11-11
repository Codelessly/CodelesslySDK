import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

/// A backslash escapes a quote inside quoted text, and a formula that
/// doesn't parse says where it goes wrong instead of showing as text.
void main() {
  Object? eval(String expression) =>
      FormulaEvaluator.evaluate(expression, (path) => path == 'n' ? 3 : null);

  test('a backslash escapes a quote or a backslash in quoted text', () {
    expect(eval(r"'it\'s'"), "it's");
    expect(eval(r'"say \"hi\""'), 'say "hi"');
    expect(eval(r"'a\\b'"), r'a\b');
    // Before any other character it stays, so regexes keep working.
    expect(eval(r"'\d+'"), r'\d+');
    expect(eval(r"matches('42', '^\d+$')"), isTrue);
    expect(eval(r"{'it\'s': 1}"), {"it's": 1});
  });

  test('a formula in text with an escaped quote is found and evaluated', () {
    const String text = r"${= 'Won\'t ' + n} times";
    expect(FormulaEvaluator.substitute(text, (_) => 3), "Won't 3 times");
    expect(FormulaEvaluator.textErrorOf(text), isNull);
    // Whole-text formulas and bindings match it too.
    expect(FormulaEvaluator.exactExpression(r"${= 'it\'s'}"), r" 'it\'s'");
    expect(variableSyntaxIdentifierRegex.hasMatch(r"${= 'it\'s'}"), isTrue);
  });

  test('textErrorOf names the character where a formula goes wrong', () {
    // An unclosed quote: the formula never closes.
    final String? unclosed = FormulaEvaluator.textErrorOf(
      r"Hi ${= 'it's'} there",
    );
    expect(unclosed, contains('at character 4'));
    expect(unclosed, contains('not closed'));

    final String? unknown = FormulaEvaluator.textErrorOf(r'Total: ${= sun(1)}');
    expect(unknown, contains('Unknown function "sun"'));
    expect(unknown, contains('at character 8 is invalid'));

    final String? missing = FormulaEvaluator.textErrorOf(r'${= max(1, 2}');
    expect(missing, contains('at character'));

    expect(FormulaEvaluator.textErrorOf(r'${= n + 1} and ${name}'), isNull);
    // An escaped formula is text.
    expect(FormulaEvaluator.textErrorOf(r"\${= 'oops}"), isNull);
  });
}
