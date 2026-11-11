import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Object? f(String formula, [Map<String, Object?> vars = const {}]) =>
      const Expressions().evaluate('\${= $formula}', ValuesScope(vars));

  test('without takes a list or one item', () {
    final vars = {'s': ['g001', 'g002', 'g001']};
    expect(f("without(s, 'g001')", vars), ['g002']);
    expect(f("without(s, ['g002'])", vars), ['g001', 'g001']);
    expect(f('without(s, null)', vars), ['g001', 'g002', 'g001']);
  });
}
