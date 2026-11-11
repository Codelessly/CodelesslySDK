// Quoted text in a formula: \n is a line break and \t a tab (a person's
// shifts on lines of their own, Rota's export); \' keeps a quote; other
// backslashes stay as written, so regular expressions keep working.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

Object? _eval(String expression, [Map<String, Object?> vars = const {}]) =>
    FormulaEvaluator.evaluate(expression, (path) => vars[path]);

void main() {
  test('\\n and \\t in quoted text', () {
    expect(_eval(r"join(lines, '\n')", {'lines': ['Mon Open', 'Tue Bar']}), 'Mon Open\nTue Bar');
    expect(_eval(r'"a\tb"'), 'a\tb');
    expect(_eval(r"'Won\'t'"), "Won't");
  });

  test('other backslashes are kept for regular expressions', () {
    expect(_eval(r"matches('A12', '\d+')"), isTrue);
    expect(_eval(r"'C:\path'"), r'C:\path');
  });
}
