import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final Map<String, Object?> vars = {
    'bookings': [
      {'id': 'b1', 'status': 'confirmed'},
      {'id': 'b2', 'status': 'cancelled'},
      {'id': 'b3', 'status': 'confirmed'},
    ],
    'id': 'b3',
    'secondsLeft': 2832,
  };
  Object? eval(String expression) =>
      FormulaEvaluator.evaluate(expression, (path) => vars[path]);

  test('indexOf finds an item by lambda, field or value', () {
    expect(eval('indexOf(bookings, b => b.id == id)'), 2);
    expect(eval("indexOf(bookings, 'status', 'cancelled')"), 1);
    expect(eval("indexOf(bookings, b => b.id == 'zz')"), -1);
    expect(eval('indexOf([3, 5, 8], n => n > 4)'), 1);
    expect(eval("indexOf('LK-7K3Q', '-')"), 2);
  });

  test('slice takes part of a list or text', () {
    expect(eval('slice([1, 2, 3, 4, 5], 0, 3)'), [1, 2, 3]);
    expect(eval('slice([1, 2, 3, 4, 5], 3)'), [4, 5]);
    expect(eval('slice([1, 2, 3, 4, 5], -2)'), [4, 5]);
    expect(eval('slice([1, 2], 1, 10)'), [2]);
    expect(eval('slice([1, 2], 5)'), <Object?>[]);
    expect(eval("slice('Vault 13', 0, 5)"), 'Vault');
  });

  test('reverse flips a list or text', () {
    expect(eval('reverse([1, 2, 3])'), [3, 2, 1]);
    expect(eval("reverse('abc')"), 'cba');
  });

  test('range counts up or down', () {
    expect(eval('range(3)'), [0, 1, 2]);
    expect(eval('range(1, 6)'), [1, 2, 3, 4, 5]);
    expect(eval('range(0, 10, 5)'), [0, 5]);
    expect(eval('range(3, 0)'), [3, 2, 1]);
    expect(eval('range(0, 5, -1)'), <Object?>[]);
    expect(eval('length(range(0, 1000000))'), 10000);
  });

  test('pad zero-pads clocks', () {
    expect(eval('pad(5, 2)'), '05');
    expect(eval('pad(12, 2)'), '12');
    expect(eval('pad(-5, 3)'), '-05');
    expect(eval("pad('7', 3, ' ')"), '  7');
    expect(
      eval("pad(floor(secondsLeft / 60), 2) + ':' + pad(secondsLeft % 60, 2)"),
      '47:12',
    );
  });
}
