import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Object? eval(String expression, [Map<String, Object?> vars = const {}]) =>
      FormulaEvaluator.evaluate(expression, (path) => vars[path]);

  test('regexReplace replaces every match of a pattern', () {
    expect(eval("regexReplace('WILLOW PHARMACY 044', ' [0-9]+\$', '')"),
        'WILLOW PHARMACY');
    expect(eval("regexReplace('A #12 B #7', '#[0-9]+', 'n')"), 'A n B n');
  });

  test('regexReplace inserts numbered and named groups', () {
    expect(eval("regexReplace('2026-10-30', '([0-9]+)-([0-9]+)-([0-9]+)', '\$3/\$2/\$1')"),
        '30/10/2026');
    expect(eval("regexReplace('SQ *KESTREL', '^SQ [*](?<name>.+)', '\${name}')"),
        'KESTREL');
    expect(eval("regexReplace('5', '(5)', '\$\$\$1')"), r'$5');
  });

  test('regexReplace leaves the text alone for a broken or empty pattern', () {
    expect(eval("regexReplace('abc', '([', 'x')"), 'abc');
    expect(eval("regexReplace('abc', '', 'x')"), 'abc');
  });

  test('replace stays literal', () {
    expect(eval("replace('A #12', '#[0-9]+', '')"), 'A #12');
  });

  test('titleCase capitalises each word', () {
    expect(eval("titleCase('SQ *KESTREL FLOWERS')"), 'Sq *Kestrel Flowers');
    expect(eval("titleCase('o’neil cafe-bar')"), 'O’neil Cafe-Bar');
    expect(eval('titleCase(t)', {'t': 'whole foods #102'}), 'Whole Foods #102');
  });
}
