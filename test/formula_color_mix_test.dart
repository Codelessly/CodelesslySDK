import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Object? eval(String expression, [Map<String, Object?> vars = const {}]) =>
      FormulaEvaluator.evaluate(expression, (path) => vars[path]);

  test('mix blends two colors to #AARRGGBB', () {
    expect(eval("mix('#000000', '#FFFFFF', 0.5)"), '#FF808080');
    expect(eval("mix('#FF4D4F', '#1677FF', 0)"), '#FFFF4D4F');
    expect(eval("mix('#FF4D4F', '#1677FF', 1)"), '#FF1677FF');
    expect(eval("lerpColor('#FF4D4F', '#1677FF', 0.25)"), '#FFC5587B');
  });

  test('mix blends alpha, reads #RGB and clamps t', () {
    expect(eval("mix('#00000000', '#80000000', 1)"), '#80000000');
    expect(eval("mix('#00000000', '#FF000000', 0.5)"), '#80000000');
    expect(eval("mix('#FFF', '#000', 2)"), '#FF000000');
    expect(eval("mix('#FFF', '#000', -1)"), '#FFFFFFFF');
  });

  test('t can come from a variable', () {
    expect(
      eval("mix('#0B1F33', '#F4EFE6', past ? 0.6 : 0)", {'past': true}),
      '#FF979C9E',
    );
  });

  test('not a color gives null', () {
    expect(eval("mix('ink', '#000000', 0.5)"), isNull);
  });
}
