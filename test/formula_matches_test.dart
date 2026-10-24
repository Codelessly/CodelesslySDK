import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Object? eval(String expression, [Map<String, Object?> vars = const {}]) =>
      FormulaEvaluator.evaluate(expression, (path) => vars[path]);

  test('matches tests text against a regular expression', () {
    const String email = "'^[^@ ]+@[^@ ]+[.][^@ .]+\$'";
    expect(eval('matches(e, $email)', {'e': 'dana@gradeline.co'}), isTrue);
    expect(eval('matches(e, $email)', {'e': 'dana@gradeline'}), isFalse);
    expect(eval('matches(e, $email)', {'e': 'dana @x.co'}), isFalse);
    expect(eval("matches('EX-102', '^[A-Z]{2}-[0-9]+\$')"), isTrue);
  });

  test('matches is false for a missing value or a broken pattern', () {
    expect(eval("matches(missing, '.*')"), isFalse);
    expect(eval("matches('abc', '([')"), isFalse);
  });

  test('matches reads numbers as text', () {
    expect(eval("matches(n, '^[0-9]+[.][0-9]\$')", {'n': 12.5}), isTrue);
  });
}
