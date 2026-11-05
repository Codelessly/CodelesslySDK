import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

/// Quoted text reads \n, \t and \r, so a formula can build multi-line text
/// (the lineup to paste into the team chat); regex patterns read as before.
void main() {
  Object? eval(String f) => FormulaEvaluator.evaluate(f, (_) => null);

  test('newline, tab and return escapes', () {
    expect(eval(r"length('a\nb')"), 3);
    expect(eval(r"'XI\n' + 'SUBS'"), 'XI\nSUBS');
    expect(eval(r"split('a\tb', '\t')"), ['a', 'b']);
  });

  test('quotes, doubled backslashes and regex escapes are unchanged', () {
    expect(eval(r"'Won\'t'"), "Won't");
    expect(eval(r"length('a\\nb')"), 5);
    expect(eval(r"regexReplace('a1b22', '\d+', '#')"), 'a#b#');
  });
}
