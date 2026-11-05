import 'dart:math' as math;

import 'package:codelessly_sdk_v2/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bare pi is the constant', () {
    expect(FormulaEvaluator.evaluate('pi', (_) => null), math.pi);
    expect(
      FormulaEvaluator.evaluate('sin(pi / 2)', (_) => null),
      closeTo(1, 1e-9),
    );
    expect(FormulaEvaluator.evaluate('pi()', (_) => null), math.pi);
  });

  test('a variable named pi still wins', () {
    expect(FormulaEvaluator.evaluate('pi', (p) => p == 'pi' ? 3 : null), 3);
  });
}
