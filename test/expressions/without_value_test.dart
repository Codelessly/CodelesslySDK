import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const e = Expressions();
  final scope = VariableScope([
    const Variable(name: 'by', type: VariableType.list, value: ['maya', 'jonah', 'lena']),
  ]);

  test('without takes a single value out, as well as a list of them', () {
    expect(e.evaluate(r"${= without(by, 'maya')}", scope), ['jonah', 'lena']);
    expect(e.evaluate(r"${= without(by, ['maya', 'lena'])}", scope), ['jonah']);
    expect(e.evaluate(r"${= without(by, 'nobody')}", scope), ['maya', 'jonah', 'lena']);
  });
}
