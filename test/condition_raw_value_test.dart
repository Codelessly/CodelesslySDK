import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('raw values parse the same every time', () {
    final ConditionEvaluator<Object> evaluator = ConditionEvaluator<Object>(
      scopedValues: ScopedValues.preview(variables: const {}),
    );
    Object? parse(String raw) => evaluator.visitRawValuePart(RawValuePart(raw));

    for (int i = 0; i < 2; i++) {
      expect(parse('hello'), 'hello');
      expect(parse('12'), 12);
      expect(parse('true'), true);
      expect(parse('null'), isNull);
      expect(parse(''), isNull);
      expect(parse('{"a": 1}'), {'a': 1});
    }
    // Each caller gets its own list.
    final Object? first = parse('[1, 2]');
    expect(first, [1, 2]);
    expect(identical(parse('[1, 2]'), first), isFalse);
  });
}
