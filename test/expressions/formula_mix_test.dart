import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

Object? eval(String expr) => FormulaEvaluator.evaluate(expr, (_) => null);

void main() {
  test('mix moves a color toward another', () {
    expect(eval("mix('#000000', '#FFFFFF', 0.5)"), '#808080');
    expect(eval("mix('#7C6CF2', '#FFFFFF', 0)"), '#7C6CF2');
    expect(eval("mix('#7C6CF2', '#FFFFFF', 1)"), '#FFFFFF');
    expect(eval("mix('#7C6CF2', '#FFFFFF', 0.35)"), '#AA9FF7');
  });

  test('mix keeps alpha when it is not opaque, and rejects bad colors', () {
    expect(eval("mix('#00000000', '#FF000000', 0.5)"), '#80000000');
    expect(eval("mix('red', '#FFFFFF', 0.5)"), isNull);
  });
}
