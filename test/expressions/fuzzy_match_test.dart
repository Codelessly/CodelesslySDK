import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

Object? eval(String expression, [Map<String, Object?> vars = const {}]) =>
    FormulaEvaluator.evaluate(expression, (path) => vars[path]);

void main() {
  test(
    'fuzzy search ranks exact, prefix and near spelling with stable ties',
    () {
      final vars = {
        'items': [
          {'title': 'The keeper of the light'},
          {'title': 'Lighthouse keeper'},
          {'title': 'Light on the island'},
          {'title': 'Platform seventeen'},
        ],
      };
      expect(
        (eval('fuzzy(items,"light",x=>x.title)', vars) as List).map(
          (x) => x['title'],
        ),
        ['The keeper of the light', 'Light on the island', 'Lighthouse keeper'],
      );
      expect(
        (eval('fuzzy(items,"ligth",x=>x.title)', vars) as List),
        isNotEmpty,
      );
      expect(eval('fuzzy(items,"",x=>x.title)', vars), vars['items']);
      expect(eval('fuzzy(items,"zzzz",x=>x.title)', vars), isEmpty);
    },
  );

  test('ranges and runs mark the visible match and explain ranking', () {
    expect(eval('matchRanges("The light keeper","light")'), [
      [4, 9],
    ]);
    expect(eval('matchRuns("The light keeper","light")'), [
      {
        'start': 4,
        'end': 9,
        'style': {'fontWeight': 700, 'decoration': 'underline'},
      },
    ]);
    expect(eval('matchReason("The light keeper","light")'), 'Exact phrase');
    expect(eval('matchReason("The light keeper","ligth")'), 'Close spelling');
    expect(eval('matchRuns("The light keeper","")'), isEmpty);
  });
}
