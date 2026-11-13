// if() is a function like any other: it parses and evaluates inside a
// ternary's branches (a cycle-1 report said it did not; it does).
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('if() inside a ternary parses', () {
    for (final f in [
      "true ? (1 + if(2 == 1, 3, 4)) : 5",
      "true ? if(1 == 1, 'a', 'b') : 'c'",
      "n > 0 ? (n + ' ' + if(n == 1, 'match', 'matches') + ' for ' + q) : 'none'",
    ]) {
      expect(FormulaEvaluator.errorOf(f), isNull, reason: f);
    }
  });
}
