import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Object? eval(String e) => FormulaEvaluator.evaluate(e, (path) => null);

  test('parseDate reads dates as people type them', () {
    for (final String typed in [
      '2026-10-03',
      '10/03/2026',
      '10/3/2026',
      'Oct 3, 2026',
      'October 3 2026',
      'oct. 3 2026',
      '3 Oct 2026',
    ]) {
      expect(
        eval('formatDate(parseDate("$typed"), "yyyy-MM-dd")'),
        '2026-10-03',
        reason: typed,
      );
    }
  });

  test('impossible or garbled dates are null', () {
    for (final String typed in [
      'Feb 30, 2026',
      '13/01/2026',
      'Octo 40 2026',
      'yesterday',
      'Ma 3, 2026',
    ]) {
      expect(eval('parseDate("$typed")'), isNull, reason: typed);
    }
  });

  test('indexOf finds text inside text', () {
    expect(eval('indexOf("Dining Out", "Out")'), 7);
    expect(eval('indexOf("Dining", "x")'), -1);
  });

  test('groupBy groups in order of first appearance', () {
    final Object? groups = FormulaEvaluator.evaluate(
      'groupBy(rows, r => r.date)',
      (path) => path == 'rows'
          ? [
              {'date': '2026-10-30', 'a': 1},
              {'date': '2026-10-29', 'a': 2},
              {'date': '2026-10-30', 'a': 3},
            ]
          : null,
    );
    expect(groups, [
      {
        'key': '2026-10-30',
        'items': [
          {'date': '2026-10-30', 'a': 1},
          {'date': '2026-10-30', 'a': 3},
        ],
        'count': 2,
      },
      {
        'key': '2026-10-29',
        'items': [
          {'date': '2026-10-29', 'a': 2},
        ],
        'count': 1,
      },
    ]);
    expect(eval('groupBy([1, 2, 3, 4], x => x > 2)'), [
      {
        'key': false,
        'items': [1, 2],
        'count': 2,
      },
      {
        'key': true,
        'items': [3, 4],
        'count': 2,
      },
    ]);
  });
}
