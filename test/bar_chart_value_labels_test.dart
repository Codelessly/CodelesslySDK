import 'package:codelessly_sdk/src/widgets/indicators_paint.dart' show barValueText;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bar values: decimals and a suffix when given, else whole numbers bare', () {
    expect(barValueText(35.8, 1, '%'), '35.8%');
    expect(barValueText(12, 1, '%'), '12.0%');
    expect(barValueText(12, null, ''), '12');
    expect(barValueText(12.34, null, ''), '12.3');
    expect(barValueText(3.14159, 2, ' pts'), '3.14 pts');
  });
}
