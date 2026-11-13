import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Functions that build and update records (maps) and lists, so actions
/// can change one item of a list variable (indexOf with a predicate, obj,
/// set, setAt, merge, concat, append, take, skip) and format an odometer
/// (thousands, padLeft).

/// Evaluates [expression] with [vars] as its variables.
Object? eval(String expression, [Map<String, Object?> vars = const {}]) =>
    FormulaEvaluator.evaluate(expression, (path) => vars[path]);

/// A stand-in for a Firestore Timestamp, which formulas read via `toDate()`.
class _Timestamp {
  final DateTime date;

  const _Timestamp(this.date);

  DateTime toDate() => date;
}

// Relative times in formulas (timeAgo), day helpers, and the clocks that
// keep what shows them current: a formula is rebuilt as often as its value
// can change (every frame, second or minute), also through the function and
// computed variables it calls, and no clock runs while nothing shows one.

Object? evalNow(String formula) => FormulaEvaluator.evaluate(formula, (_) => null);

PublishBundle _bundle({required List<Variable> variables, required String text}) {
  final layout = PublishLayout.fromJson({
    'schema': 2,
    'id': 'home',
    'roots': ['canvas'],
    'variables': {
      'canvas': [for (final v in variables) v.toJson()],
    },
    'nodes': {
      'canvas': {
        'type': 'canvas',
        'slots': {'body': 'body'},
        'layout': {'width': 390, 'height': 844},
      },
      'body': {
        'type': 'stack',
        'layout': {
          'width': {'fill': 390},
          'height': {'fill': 844},
        },
        'children': ['label'],
      },
      'label': {
        'type': 'text',
        'props': {'text': text},
        'layout': {'width': 200, 'height': 20},
      },
    },
  });
  return PublishBundle(
    model: PublishModel(projectId: 'time', entryLayoutId: 'home', layouts: {'home': PublishLayoutInfo.of(layout)}),
    layouts: {'home': layout},
  );
}

/// Functions that build and update records (maps) and lists, so actions
/// can change one item of a list variable (indexOf with a predicate, obj,
/// set, setAt, merge, concat, append, take, skip) and format an odometer
/// (thousands, padLeft).

void secondsAndDurationTests() {
  final Map<String, Object?> vars = {
    'sites': [
      {'id': 'A1', 'status': 'occupied'},
      {'id': 'A2', 'status': 'vacant'},
      {'id': 'A3', 'status': 'vacant'},
    ],
    'pick': 'A2',
    'start': '2026-07-17T20:12:00.000',
  };
  Object? eval(String expression) =>
      FormulaEvaluator.evaluate(expression, (path) => vars[path]);

  group('seconds and durations', () {
    test('addSeconds and diffSeconds', () {
      expect(eval('addSeconds(start, 90)'), '2026-07-17T20:13:30.000');
      expect(eval("diffSeconds(start, '2026-07-17T20:16:00')"), 240);
      expect(eval('second(addSeconds(start, 75))'), 15);
    });

    test('formatDuration follows its pattern', () {
      expect(eval("formatDuration(6480, 'h:mm:ss')"), '1:48:00');
      expect(eval("formatDuration(240, 'mm:ss')"), '04:00');
      expect(eval("formatDuration(6480, 'mm:ss')"), '108:00');
      expect(eval("formatDuration(72, 'm:ss')"), '1:12');
      expect(eval('formatDuration(6480)'), '1h 48m');
      expect(eval('formatDuration(7200)'), '2h');
      expect(eval("formatDuration(1500, 'compact')"), '25m');
      expect(eval('formatDuration(40)'), '40s');
      expect(eval('formatDuration(-72, "m:ss")'), '1:12');
    });
  });

}

void main() {
  {
    {
      final List<Map<String, Object?>> records = [
        {'id': 'a', 'artist': 'Miles Davis', 'year': 1959, 'favorite': false},
        {'id': 'b', 'artist': 'Bill Evans', 'year': 1961, 'favorite': true},
        {'id': 'c', 'artist': 'Miles Davis', 'year': 1970, 'favorite': false},
        {'id': 'd', 'artist': 'Bill Evans', 'year': 1956, 'favorite': false},
      ];
      final List<Map<String, Object?>> tracks = [
        {'title': 'So What', 'length': '9:22'},
        {'title': 'Freddie Freeloader', 'length': '9:46'},
        {'title': 'Blue in Green', 'length': '5:37'},
      ];
      final Map<String, Object?> vars = {
        'records': records,
        'tracks': tracks,
        'selected': 'c',
        'count': 4,
        'genres': ['rock', 'jazz', 'soul'],
        'record': records.first,
      };

      Object? resolve(String path) {
        Object? value = vars;
        for (final part in path.split('.')) {
          value = value is Map ? value[part] : null;
        }
        return value;
      }

      Object? eval(String expression) =>
          FormulaEvaluator.evaluate(expression, resolve);

      group('durations', () {
        test('seconds reads m:ss and h:mm:ss', () {
          expect(eval('seconds("3:45")'), 225);
          expect(eval('seconds("0:07")'), 7);
          expect(eval('seconds("1:02:05")'), 3725);
          expect(eval('seconds("75:00")'), 4500);
          expect(eval('seconds("225")'), 225);
          expect(eval('seconds(90)'), 90);
        });

        test('seconds is null for text that is not a time', () {
          expect(eval('seconds("3:75")'), isNull);
          expect(eval('seconds("3:5")'), isNull);
          expect(eval('seconds("abc")'), isNull);
          expect(eval('seconds("")'), isNull);
          expect(eval('seconds("1:2:3:4")'), isNull);
          expect(eval('seconds(null)'), isNull);
        });

        test('duration writes m:ss and h:mm:ss', () {
          expect(eval('duration(225)'), '3:45');
          expect(eval('duration(5)'), '0:05');
          expect(eval('duration(3600)'), '1:00:00');
          expect(eval('duration(3725)'), '1:02:05');
          expect(eval('duration(224.6)'), '3:45');
          expect(eval('duration("3:45")'), '3:45');
          expect(eval('duration(null)'), isNull);
          expect(eval('duration("x")'), isNull);
        });

      });
    }

    {
    }

    {
      final Map<String, Object?> vars = {
        'units': [
          {'id': 'ex1', 'hours': 10.5, 'status': 'Available'},
          {'id': 'ex2', 'hours': 99.0, 'status': 'On rent'},
        ],
        'meter': 2481.6,
        'unitId': 'ex2',
        'start': '2026-10-01',
      };
      Object? eval(String expression) =>
          FormulaEvaluator.evaluate(expression, (path) => vars[path]);

      test('daysInMonth knows each month\'s length', () {
        expect(eval("daysInMonth('2026-02-10')"), 28);
        expect(eval("daysInMonth('2028-02-10')"), 29);
        expect(eval('daysInMonth(start)'), 31);
      });
    }

    {
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
    }

    group('time zones', () {
      // Half-hourly tide heights, NOAA style.
      test('wallTime keeps the clock time of a date with an offset', () {
        expect(
          eval('wallTime("2026-10-22T07:25:17-07:00")'),
          '2026-10-22T07:25:17.000',
        );
        expect(eval('wallTime("2026-10-22 18:23")'), '2026-10-22T18:23:00.000');
      });

      test('now and today take a UTC offset', () {
        final DateTime utc = DateTime.now().toUtc();
        final DateTime minus7 = DateTime.parse(eval('now("-07:00")')! as String);
        final DateTime expected = utc.subtract(const Duration(hours: 7));
        expect(minus7.isUtc, false);
        expect(
          DateTime.utc(
                minus7.year,
                minus7.month,
                minus7.day,
                minus7.hour,
                minus7.minute,
              )
              .difference(
                DateTime.utc(
                  expected.year,
                  expected.month,
                  expected.day,
                  expected.hour,
                  expected.minute,
                ),
              )
              .inMinutes
              .abs(),
          lessThanOrEqualTo(1),
        );
        expect(eval('now(5.5)'), isA<String>());
        expect((eval('today(-7)')! as String).endsWith('T00:00:00.000'), true);
      });
    
    });

    group('dates as people type them', () {
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

      test('an impossible or garbled date is null', () {
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
    });

    group('time that passes', () {
      // Wednesday 2026-11-11, 15:00 local.
      final now = DateTime(2026, 11, 11, 15);
      setUp(() => FormulaClock.pinned = now);
      tearDown(() => FormulaClock.pinned = null);

      String ago(Duration d, [String args = '']) =>
          evalNow('timeAgo("${now.subtract(d).toIso8601String()}"$args)') as String;

      group('timeAgo', () {
        test('short style', () {
          expect(ago(const Duration(seconds: 20)), 'now');
          expect(ago(const Duration(minutes: 2)), '2m');
          expect(ago(const Duration(minutes: 59)), '59m');
          expect(ago(const Duration(hours: 3)), '3h');
          expect(ago(const Duration(hours: 23)), '23h');
          // Yesterday on the calendar, a day or more ago.
          expect(ago(const Duration(hours: 30)), 'Yesterday');
          expect(ago(const Duration(days: 3)), '3d');
          expect(ago(const Duration(days: 6)), '6d');
          expect(evalNow('timeAgo("2026-03-04T09:00:00")'), 'Mar 4');
          expect(evalNow('timeAgo("2025-03-04T09:00:00")'), 'Mar 4, 2025');
        });

        test('long style', () {
          expect(ago(const Duration(seconds: 5), ', "long"'), 'just now');
          expect(ago(const Duration(minutes: 1), ', "long"'), '1 minute ago');
          expect(ago(const Duration(minutes: 5), ', "long"'), '5 minutes ago');
          expect(ago(const Duration(hours: 1), ', "long"'), '1 hour ago');
          expect(ago(const Duration(hours: 30), ', "long"'), 'Yesterday');
          expect(ago(const Duration(days: 2), ', "long"'), '2 days ago');
          expect(evalNow('timeAgo("2026-03-04T09:00:00", "long")'), 'March 4');
          expect(evalNow('formatRelative("2025-03-04T09:00:00", "long")'), 'March 4, 2025');
        });

        test('dates to come', () {
          expect(ago(const Duration(minutes: -5)), 'in 5m');
          expect(ago(const Duration(hours: -2)), 'in 2h');
          expect(ago(const Duration(hours: -30)), 'Tomorrow');
          expect(ago(const Duration(days: -3), ', "long"'), 'in 3 days');
        });

        test('every date form, and null for what is not a date', () {
          final t = now.subtract(const Duration(minutes: 7));
          expect(evalNow('timeAgo(${t.millisecondsSinceEpoch})'), '7m');
          expect(evalNow('timeAgo("${t.toUtc().toIso8601String()}")'), '7m');
          final seconds = t.millisecondsSinceEpoch ~/ 1000;
          expect(
            FormulaEvaluator.evaluate('timeAgo(t)', (p) => p == 't' ? {'seconds': seconds, 'nanoseconds': 0} : null),
            '7m',
          );
          expect(evalNow('timeAgo("soon")'), isNull);
          expect(evalNow('timeAgo(null)'), isNull);
        });

        test('dates in the locale, words from labels', () {
          expect(evalNow('timeAgo("2026-03-04T09:00:00", "short", "fr")'), '4 mars');
          expect(evalNow('timeAgo("2026-03-04T09:00:00", "long", "de")'), '4. März');
          const fr = "{now: \"à l'instant\", minutes: 'il y a {n} min', hours: {one: 'il y a {n} heure', other: 'il y a {n} heures'}, yesterday: 'Hier'}";
          expect(ago(const Duration(seconds: 1), ', "short", "fr", $fr'), "à l'instant");
          expect(ago(const Duration(minutes: 4), ', "short", "fr", $fr'), 'il y a 4 min');
          expect(ago(const Duration(hours: 1), ', "short", "fr", $fr'), 'il y a 1 heure');
          expect(ago(const Duration(hours: 5), ', "short", "fr", $fr'), 'il y a 5 heures');
          expect(ago(const Duration(hours: 30), ', "short", "fr", $fr'), 'Hier');
          // Labels in place of the style; digits in the locale's.
          expect(ago(const Duration(minutes: 3), ', {minutes: "{n} min"}'), '3 min');
          expect(ago(const Duration(minutes: 3), ', "short", "ar_EG"'), '٣m');
        });
      });

      test('day helpers', () {
        expect(evalNow('isToday("2026-11-11T08:00:00")'), isTrue);
        expect(evalNow('isToday("2026-11-10T23:59:00")'), isFalse);
        expect(evalNow('isSameDay("2026-11-10T01:00:00", "2026-11-10T23:00:00")'), isTrue);
        expect(evalNow('isSameDay("2026-11-10", "2026-11-11")'), isFalse);
        expect(evalNow('isBefore("2026-11-10", now())'), isTrue);
        expect(evalNow('isAfter("2026-11-10", now())'), isFalse);
        expect(evalNow('isBefore(null, now())'), isFalse);
        expect(evalNow('isPast("2026-11-11T14:59:00")'), isTrue);
        expect(evalNow('isFuture("2026-11-11T14:59:00")'), isFalse);
        expect(evalNow('isFuture("2026-11-12")'), isTrue);
        expect(evalNow('isPast(null)'), isFalse);
        // Comparisons were already date-aware; diffDays counts calendar days.
        expect(evalNow('"2026-11-10" < now()'), isTrue);
        expect(evalNow('diffDays("2026-11-01", today())'), 10);
      });

      testWidgets('a text showing now() updates every second', (tester) async {
        final app = Codelessly.fromBundle(
          _bundle(variables: const [], text: r'${= formatDate(now(), "HH:mm:ss")}'),
          fonts: const NoFontFetcher(),
        );
        addTearDown(app.dispose);
        final controller = CodelesslyWidgetController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(MaterialApp(home: CodelesslyWidget(codelessly: app, controller: controller)));
        await tester.pumpAndSettle();
        String shown() => controller.tree!.boxOf('label')!.node!.prop(TextProps.text);
        expect(shown(), '15:00:00');
        expect(FormulaClock.instance.isTicking, isTrue);
        FormulaClock.pinned = now.add(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        expect(shown(), '15:00:01');
        await tester.pumpWidget(const SizedBox());
        expect(FormulaClock.instance.isTicking, isFalse);
      });
    });

    group('the clock', () {
      tearDown(() => FormulaClock.pinned = null);

      String eval(String formula) => FormulaEvaluator.stringify(
        FormulaEvaluator.evaluate(formula, (path) => null),
      );

      test('now() and today() read a pinned clock when one is set', () {
        FormulaClock.pinned = DateTime.parse('2026-10-22T13:20:00-07:00');
        expect(
          eval("formatDate(now('-07:00'), 'EEE, MMM d · h:mm a')"),
          'Thu, Oct 22 · 1:20 PM',
        );
        expect(eval("formatDate(today('-07:00'), 'yyyy-MM-dd')"), '2026-10-22');
        expect(eval("formatDate(now('Z'), 'HH:mm')"), '20:20');
      });

      test('without a pinned clock now() is the device\'s time', () {
        final String year = '${DateTime.now().year}';
        expect(eval("formatDate(now(), 'yyyy')"), year);
      });
    });
  }

  group('seconds and durations', () {
    secondsAndDurationTests();
  });

  group('the clock', () {
    tearDown(() => FormulaClock.pinned = null);

    String eval(String formula) => FormulaEvaluator.stringify(
      FormulaEvaluator.evaluate(formula, (path) => null),
    );

    test('nowMs() is the time in milliseconds, for timing taps', () {
      FormulaClock.pinned = DateTime.fromMillisecondsSinceEpoch(1793356053036);
      expect(eval('nowMs()'), '1793356053036');
      expect(eval('round(60000 / (nowMs() - 1793356052536))'), '120');
    });
  });
}
