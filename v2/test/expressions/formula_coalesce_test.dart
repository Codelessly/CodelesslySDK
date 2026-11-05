import 'package:codelessly_sdk_v2/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

Object? eval(String expr, [Map<String, Object?> values = const {}]) =>
    FormulaEvaluator.evaluate(expr, (String path) => values[path]);

void main() {
  test('coalesce answers the first value that is set', () {
    expect(eval("coalesce(null, 'a', 'b')"), 'a');
    expect(eval("coalesce('', 'b')"), 'b');
    expect(eval('coalesce(0, 5)'), 0);
  });

  // A draft badge read `coalesce(at(drafts, id).text, '') != ''`: with no
  // draft, coalesce answered null, so the badge showed on every row.
  test('coalesce falls back to its last value when none is set', () {
    expect(eval("coalesce(null, '')"), '');
    expect(eval("coalesce(at(drafts, '4921').text, '') != ''", {
      'drafts': <String, Object?>{},
    }), isFalse);
    expect(eval("coalesce(at(drafts, '4921').text, '') != ''", {
      'drafts': <String, Object?>{'4921': {'text': 'Hi'}},
    }), isTrue);
    expect(eval('coalesce(null, null)'), isNull);
  });

  test('at reads a map by key', () {
    final Map<String, Object?> values = {
      'drafts': <String, Object?>{'4921': 'a'},
      'id': 4921,
    };
    expect(eval("at(drafts, '4921')", values), 'a');
    expect(eval('at(drafts, id)', values), 'a');
    expect(eval("at(drafts, '1')", values), isNull);
    expect(eval('at(list, 1)', {'list': ['x', 'y']}), 'y');
  });

  // Tag dots take one of 8 colors from their name, as the reference's
  // tagColor sums the name's code units.
  test('codeUnits hashes a name into a color index', () {
    expect(eval("codeUnits('ab')"), <int>[97, 98]);
    expect(eval("sum(codeUnits('bug')) % 8"), (98 + 117 + 103) % 8);
    expect(eval("codeUnits('')"), isEmpty);
  });
}
