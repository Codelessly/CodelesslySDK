import 'package:codelessly_sdk/src/widgets/indicators_charts.dart' show gridLabelText;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the unit can go on the top y label only', () {
    expect([for (var k = 0; k <= 5; k++) gridLabelText(k * 10.0, k, 5, '', '%', topOnly: true)],
        ['0', '10', '20', '30', '40', '50%']);
    expect(gridLabelText(10, 1, 5, '', '%'), '10%');
  });
}
