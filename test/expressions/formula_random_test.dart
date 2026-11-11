import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Object? f(String formula, [Map<String, Object?> vars = const {}]) =>
      const Expressions().evaluate('\${= $formula}', ValuesScope(vars));

  test('random and pick stay in range', () {
    for (var i = 0; i < 200; i++) {
      final r = f('random()') as num;
      expect(r >= 0 && r < 1, isTrue);
      expect(f('random(5)'), inInclusiveRange(0, 4));
      expect(f('random(3, 6)'), inInclusiveRange(3, 6));
      expect(f('pick(xs)', {'xs': ['a', 'b', 'c']}), isIn(['a', 'b', 'c']));
    }
    expect(f('random(0)'), 0);
    expect(f('pick(xs)', {'xs': []}), isNull);
    // Over many draws every value turns up.
    expect({for (var i = 0; i < 200; i++) f('random(3)')}, {0, 1, 2});
  });
}
