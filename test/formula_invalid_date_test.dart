import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

/// Text naming an impossible day ("2013-02-30") is not read as a date, so it
/// never equals the day it would roll over to.
void main() {
  Object? eval(String f) => FormulaEvaluator.evaluate(f, (_) => null);

  test('impossible days are not dates', () {
    expect(eval("'2013-03-02' == '2013-02-30'"), isFalse);
    expect(eval("day('2013-02-30')"), isNull);
    expect(eval("'2026-10-21' == '2026-10-21T00:00'"), isTrue, reason: 'real dates still compare as dates');
    expect(eval("day('2013-02-28')"), 28);
    expect(eval("year('2026-11-05T10:30:00Z')"), 2026);
  });
}
