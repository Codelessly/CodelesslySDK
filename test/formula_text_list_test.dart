import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final Map<String, Object?> vars = {
    'timeline': [
      {'t': '10:00', 'label': 'Reported'},
      {'t': '10:05', 'label': 'Assigned'},
      {'t': '10:05', 'label': 'Repair started'},
    ],
    'items': [
      {'id': '1a', 'name': 'Tyres'},
      {'id': '1b', 'name': 'Lights'},
      {'id': '1c', 'name': 'Mirrors'},
    ],
    'answers': {'1b': 'fail'},
    'vin': '1FUJGLDR5LLMX4821',
    'zone': 1,
  };
  Object? eval(String expression) =>
      FormulaEvaluator.evaluate(expression, (path) => vars[path]);

  group('reverse', () {
    test('reverses a list, keeping equal items in reverse order', () {
      expect(eval('map(reverse(timeline), e => e.label)'), [
        'Repair started',
        'Assigned',
        'Reported',
      ]);
    });

    test('reverses text', () => expect(eval('reverse("abc")'), 'cba'));

    test('does not change the list it reads', () {
      eval('reverse(timeline)');
      expect((vars['timeline']! as List).first, {
        't': '10:00',
        'label': 'Reported',
      });
    });

    test('is null for other values', () => expect(eval('reverse(5)'), isNull));
  });

  group('lambda index', () {
    test('map passes the index as the second parameter', () {
      expect(eval('map(items, (i, n) => n + 1 + ". " + i.name)'), [
        '1. Tyres',
        '2. Lights',
        '3. Mirrors',
      ]);
    });

    test('marks the last item', () {
      expect(eval('map(timeline, (e, i) => i == length(timeline) - 1)'), [
        false,
        false,
        true,
      ]);
    });

    test('filter, find, count, any, all and indexOf get the index', () {
      expect(eval('map(filter(items, (x, i) => i > 0), x => x.id)'), [
        '1b',
        '1c',
      ]);
      expect(eval('find(items, (x, i) => i == 2).name'), 'Mirrors');
      expect(eval('count(items, (x, i) => i % 2 == 0)'), 2);
      expect(eval('any(items, (x, i) => i == 5)'), false);
      expect(eval('all(items, (x, i) => i < 3)'), true);
      expect(eval('indexOf(items, (x, i) => x.id == "1c" && i == 2)'), 2);
    });

    test('a one-parameter lambda still works', () {
      expect(eval('map(items, (x) => x.id)'), ['1a', '1b', '1c']);
    });

    test('the index parameter is not read as a variable', () {
      expect(
        FormulaEvaluator.referencedPaths('map(items, (x, i) => i + zone)'),
        {'items', 'zone'},
      );
    });
  });

  group('substring, left and right', () {
    test('substring takes start and an optional end', () {
      expect(eval('substring("MX4821", 2, 4)'), '48');
      expect(eval('substring("MX4821", 2)'), '4821');
    });

    test('negative indexes count from the end', () {
      expect(eval('substring(vin, -6)'), 'MX4821');
      expect(eval('substring("MX4821", 0, -4)'), 'MX');
    });

    test('indexes past the ends are clamped', () {
      expect(eval('substring("abc", 1, 99)'), 'bc');
      expect(eval('substring("abc", 5)'), '');
      expect(eval('substring("abc", 2, 1)'), '');
      expect(eval('substring(missing, 0, 2)'), '');
    });

    test('left and right', () {
      expect(eval('left(vin, 4)'), '1FUJ');
      expect(eval('right(vin, 6)'), 'MX4821');
      expect(eval('right("ab", 6)'), 'ab');
      expect(eval('left("ab", 0)'), '');
      expect(eval('right("ab", 0)'), '');
      expect(eval('right(1234, 2)'), '34');
    });
  });

  group('toMap', () {
    test('builds a map from key and value lambdas', () {
      expect(eval('toMap(items, i => i.id, i => "pass")'), {
        '1a': 'pass',
        '1b': 'pass',
        '1c': 'pass',
      });
    });

    test('keeps the item when there is no value selector', () {
      expect(eval('toMap(items, "id")["1b"].name'), 'Lights');
    });

    test('marks unanswered items pass and keeps answers (Pass N)', () {
      expect(
        eval(
          'merge(toMap(filter(items, i => !answers[i.id]), i => i.id, '
          'i => "pass"), answers)',
        ),
        {'1a': 'pass', '1c': 'pass', '1b': 'fail'},
      );
    });

    test('lambdas get the index', () {
      expect(eval('toMap(items, (i, n) => n, i => i.name)'), {
        '0': 'Tyres',
        '1': 'Lights',
        '2': 'Mirrors',
      });
    });

    test('is empty for a value that is not a list', () {
      expect(eval('toMap(missing, i => i)'), <String, Object?>{});
    });
  });

  test('the new functions are documented', () {
    final Set<String> documented = {
      for (final doc in FormulaEvaluator.functionDocs) doc.name,
    };
    expect(
      documented,
      containsAll(['reverse', 'substring', 'left', 'right', 'toMap']),
    );
  });
}
