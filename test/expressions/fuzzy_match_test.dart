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

  test('letters typed together match across words, and mark each word\x27s part', () {
    final vars = {
      'people': [
        {'name': 'Grace Hopper'},
        {'name': 'Ada Mensah'},
      ],
    };
    expect((eval('fuzzy(people,"adamens",p=>p.name)', vars) as List).map((p) => (p as Map)['name']), ['Ada Mensah']);
    expect(eval('matchRanges("Ada Mensah","adamens")'), [
      [0, 3],
      [4, 8],
    ]);
  });

  test('a tolerance says how many letters a word may be off by; "keep" keeps the list\x27s order', () {
    final vars = {
      'items': [
        {'title': 'Lighthouse keeper'},
        {'title': 'Light on the island'},
        {'title': 'Lantern'},
      ],
    };
    List<Object?> titles(String expression) => [for (final x in eval(expression, vars) as List) (x as Map)['title']];
    // "lentrin" is three letters off "lantern": out of reach of the default
    // (2 for a word of 5 or more), in reach of 3.
    expect(titles('fuzzy(items,"lentrin",x=>x.title)'), isEmpty);
    expect(titles('fuzzy(items,"lentrin",x=>x.title,3)'), ['Lantern']);
    // 0 takes no misspelling.
    expect(titles('fuzzy(items,"ligth",x=>x.title)'), isNotEmpty);
    expect(titles('fuzzy(items,"ligth",x=>x.title,0)'), isEmpty);
    // Best first, unless kept in the list's order; the options in either order.
    expect(titles('fuzzy(items,"light",x=>x.title)'), ['Light on the island', 'Lighthouse keeper']);
    expect(titles('fuzzy(items,"light",x=>x.title,"keep")'), ['Lighthouse keeper', 'Light on the island']);
    expect(titles('fuzzy(items,"lentrin",x=>x.title,"keep",3)'), ['Lantern']);
    // The marks take the same tolerance.
    expect(eval('matchRanges("Lantern","lentrin")'), isEmpty);
    expect(eval('matchRanges("Lantern","lentrin",3)'), [
      [0, 7],
    ]);
  });
}
