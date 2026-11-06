import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/functions/action_chain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loop.item stays readable after an action replaces the result', () {
    final ScopedValues scope = ScopedValues.empty();
    Object? read(String path) => PropertyValueDelegate.getVariableValueFromPath<Object>(
      path,
      scopedValues: scope,
    );
    final turn = {'item': 3, 'index': 1};
    ActionChain.run(() {
      expect(read(r'${result.item}'), 3);
      // A set-variable action leaves its value (a list) as the result.
      ActionChain.setResult([1, 2, 3]);
      expect(read(r'${result.item}'), isNull);
      expect(read(r'${loop.item}'), 3);
      expect(read(r'${loop.index}'), 1);
      // A conditional nested in the turn still sees it.
      ActionChain.run(() {
        expect(read(r'${loop.item}'), 3);
        expect(read(r'${= loop.item * 10}'), 30);
      });
    }, result: turn, loop: turn);
  });
}
