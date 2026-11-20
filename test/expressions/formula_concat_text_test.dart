import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

// concat of texts and no list is the text they make, as a spreadsheet's
// CONCAT (`text={concat("It doesn't look like ", plan, " is in network")}`
// drew an empty line: it gave a list); with a list among them it is still
// the list of them all.

Object? eval(String expr, [Map<String, Object?> values = const {}]) =>
    FormulaEvaluator.evaluate(expr, (String path) => values[path]);

void main() {
  test('texts and values: the text they make', () {
    expect(eval('concat("It is ", plan, " now")', {'plan': 'Aetna'}), 'It is Aetna now');
    expect(eval('concat("n=", n)', {'n': 3}), 'n=3');
    expect(eval('concat("a", missing, "b")'), 'ab');
  });

  test('a list among them, or no text: the list', () {
    expect(eval('concat([1, 2], [3], 4)'), [1, 2, 3, 4]);
    expect(eval('concat(["a"], "b")'), ['a', 'b']);
    expect(eval('concat(1, 2)'), [1, 2]);
  });
}
