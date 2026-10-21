import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

/// A stand-in for a Firestore Timestamp, which formulas read via `toDate()`.
class _Timestamp {
  final DateTime date;

  const _Timestamp(this.date);

  DateTime toDate() => date;
}

void main() {
  final Map<String, Object?> vars = {
    'start': '2026-10-21T14:30:00.000',
    'end': '2026-10-21T17:15:00.000',
    'due': '2026-10-26',
    'millis': DateTime(2026, 3, 4, 5, 6).millisecondsSinceEpoch,
    'stamp': _Timestamp(DateTime(2026, 12, 25, 8)),
    'jsonStamp': {
      'seconds': DateTime.utc(2026, 1, 2).millisecondsSinceEpoch ~/ 1000,
      'nanoseconds': 0,
    },
    'empty': '',
  };
  Object? eval(String expression) =>
      FormulaEvaluator.evaluate(expression, (path) => vars[path]);

  group('now and today', () {
    test('now is the current time as ISO 8601 text', () {
      final DateTime before = DateTime.now();
      final DateTime now = DateTime.parse(eval('now()')! as String);
      expect(now.isBefore(before.subtract(const Duration(seconds: 1))), false);
      expect(
        now.isAfter(DateTime.now().add(const Duration(seconds: 1))),
        false,
      );
    });

    test('today is midnight of the current day', () {
      final DateTime now = DateTime.now();
      expect(
        eval('today()'),
        DateTime(now.year, now.month, now.day).toIso8601String(),
      );
      expect(eval('diffDays(today(), now())'), 0);
    });
  });

  group('parseDate', () {
    test('reads ISO text, epoch millis and timestamps', () {
      expect(eval('parseDate("2026-10-21")'), '2026-10-21T00:00:00.000');
      expect(eval('parseDate(millis)'), '2026-03-04T05:06:00.000');
      expect(eval('parseDate(stamp)'), '2026-12-25T08:00:00.000');
      expect(
        eval('parseDate(jsonStamp)'),
        DateTime.utc(2026, 1, 2).toLocal().toIso8601String(),
      );
    });

    test('is null for text that is not a date', () {
      expect(eval('parseDate("soon")'), isNull);
      expect(eval('parseDate(empty)'), isNull);
      expect(eval('parseDate(missing)'), isNull);
    });
  });

  group('formatDate', () {
    test('formats with ICU pattern letters', () {
      expect(
        eval('formatDate(start, "yyyy-MM-dd HH:mm:ss")'),
        '2026-10-21 14:30:00',
      );
      expect(
        eval('formatDate(start, "EEE, MMM d · h:mm a")'),
        'Wed, Oct 21 · 2:30 PM',
      );
      expect(
        eval('formatDate(start, "EEEE d MMMM yy")'),
        'Wednesday 21 October 26',
      );
      expect(
        eval('formatDate("2026-01-05T00:05", "M/d h:mm a")'),
        '1/5 12:05 AM',
      );
    });

    test('keeps quoted text and defaults to yyyy-MM-dd', () {
      expect(eval('formatDate(start, "\'at\' h a, \'\'yy")'), "at 2 PM, '26");
      expect(eval('formatDate(start)'), '2026-10-21');
    });

    test('accepts timestamps and is empty for no date', () {
      expect(eval('formatDate(stamp, "MMM d")'), 'Dec 25');
      expect(eval('formatDate(missing, "MMM d")'), isNull);
      expect(
        FormulaEvaluator.substitute(
          r'Due ${= formatDate(missing, "d")}',
          (_) => null,
        ),
        'Due ',
      );
    });
  });

  group('date arithmetic', () {
    test('adds minutes, hours, days and months', () {
      expect(eval('addMinutes(start, 45)'), '2026-10-21T15:15:00.000');
      expect(eval('addHours(start, -15)'), '2026-10-20T23:30:00.000');
      expect(eval('addDays(start, 11)'), '2026-11-01T14:30:00.000');
      expect(eval('addMonths("2026-01-31", 1)'), '2026-02-28T00:00:00.000');
      expect(eval('addMonths("2028-01-31", 1)'), '2028-02-29T00:00:00.000');
      expect(eval('addMonths("2026-11-15", 3)'), '2027-02-15T00:00:00.000');
      expect(eval('addDays(missing, 1)'), isNull);
    });

    test('keeps UTC dates in UTC', () {
      expect(
        eval('addDays("2026-10-21T10:00:00Z", 1)'),
        '2026-10-22T10:00:00.000Z',
      );
    });

    test('differences between dates', () {
      expect(eval('diffMinutes(start, end)'), 165);
      expect(eval('diffHours(start, end)'), 2);
      expect(eval('diffDays(start, due)'), 5);
      expect(eval('diffDays(due, start)'), -5);
      expect(eval('diffDays("2026-10-21T23:59", "2026-10-22T00:01")'), 1);
      expect(eval('diffDays(start, missing)'), isNull);
    });

    test('results chain and compare', () {
      expect(eval('formatDate(addDays(due, 1), "EEE")'), 'Tue');
      expect(eval('diffDays(start, due) > 3'), isTrue);
      expect(eval('addDays(start, 1) > start'), isTrue);
    });
  });

  group('date parts', () {
    test('reads year, month, day, hour, minute and weekday', () {
      expect(eval('year(start)'), 2026);
      expect(eval('month(start)'), 10);
      expect(eval('day(start)'), 21);
      expect(eval('hour(start)'), 14);
      expect(eval('minute(start)'), 30);
      expect(eval('weekday(start)'), 3);
      expect(eval('weekday(due)'), 1);
      expect(eval('year(missing)'), isNull);
    });
  });

  test('date functions are documented for the editor', () {
    final Set<String> documented = {
      for (final doc in FormulaEvaluator.functionDocs) doc.name,
    };
    expect(
      documented,
      containsAll([
        'now',
        'today',
        'parseDate',
        'formatDate',
        'addMinutes',
        'addHours',
        'addDays',
        'addMonths',
        'diffMinutes',
        'diffHours',
        'diffDays',
        'year',
        'month',
        'day',
        'hour',
        'minute',
        'weekday',
      ]),
    );
    expect(FormulaEvaluator.errorOf('formatDate(now(), "d")'), isNull);
  });
}
