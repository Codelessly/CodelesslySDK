// Relative times in formulas (timeAgo), day helpers, and the clocks that
// keep what shows them current: a formula is rebuilt as often as its value
// can change (every frame, second or minute), also through the function and
// computed variables it calls, and no clock runs while nothing shows one.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Object? eval(String formula) => FormulaEvaluator.evaluate(formula, (_) => null);

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

void main() {
  // Wednesday 2026-11-11, 15:00 local.
  final now = DateTime(2026, 11, 11, 15);
  setUp(() => FormulaClock.pinned = now);
  tearDown(() => FormulaClock.pinned = null);

  String ago(Duration d, [String args = '']) =>
      eval('timeAgo("${now.subtract(d).toIso8601String()}"$args)') as String;

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
      expect(eval('timeAgo("2026-03-04T09:00:00")'), 'Mar 4');
      expect(eval('timeAgo("2025-03-04T09:00:00")'), 'Mar 4, 2025');
    });

    test('long style', () {
      expect(ago(const Duration(seconds: 5), ', "long"'), 'just now');
      expect(ago(const Duration(minutes: 1), ', "long"'), '1 minute ago');
      expect(ago(const Duration(minutes: 5), ', "long"'), '5 minutes ago');
      expect(ago(const Duration(hours: 1), ', "long"'), '1 hour ago');
      expect(ago(const Duration(hours: 30), ', "long"'), 'Yesterday');
      expect(ago(const Duration(days: 2), ', "long"'), '2 days ago');
      expect(eval('timeAgo("2026-03-04T09:00:00", "long")'), 'March 4');
      expect(eval('formatRelative("2025-03-04T09:00:00", "long")'), 'March 4, 2025');
    });

    test('dates to come', () {
      expect(ago(const Duration(minutes: -5)), 'in 5m');
      expect(ago(const Duration(hours: -2)), 'in 2h');
      expect(ago(const Duration(hours: -30)), 'Tomorrow');
      expect(ago(const Duration(days: -3), ', "long"'), 'in 3 days');
    });

    test('every date form, and null for what is not a date', () {
      final t = now.subtract(const Duration(minutes: 7));
      expect(eval('timeAgo(${t.millisecondsSinceEpoch})'), '7m');
      expect(eval('timeAgo("${t.toUtc().toIso8601String()}")'), '7m');
      final seconds = t.millisecondsSinceEpoch ~/ 1000;
      expect(
        FormulaEvaluator.evaluate('timeAgo(t)', (p) => p == 't' ? {'seconds': seconds, 'nanoseconds': 0} : null),
        '7m',
      );
      expect(eval('timeAgo("soon")'), isNull);
      expect(eval('timeAgo(null)'), isNull);
    });

    test('dates in the locale, words from labels', () {
      expect(eval('timeAgo("2026-03-04T09:00:00", "short", "fr")'), '4 mars');
      expect(eval('timeAgo("2026-03-04T09:00:00", "long", "de")'), '4. März');
      final fr = "{now: \"à l'instant\", minutes: 'il y a {n} min', hours: {one: 'il y a {n} heure', other: 'il y a {n} heures'}, yesterday: 'Hier'}";
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
    expect(eval('isToday("2026-11-11T08:00:00")'), isTrue);
    expect(eval('isToday("2026-11-10T23:59:00")'), isFalse);
    expect(eval('isSameDay("2026-11-10T01:00:00", "2026-11-10T23:00:00")'), isTrue);
    expect(eval('isSameDay("2026-11-10", "2026-11-11")'), isFalse);
    expect(eval('isBefore("2026-11-10", now())'), isTrue);
    expect(eval('isAfter("2026-11-10", now())'), isFalse);
    expect(eval('isBefore(null, now())'), isFalse);
    expect(eval('isPast("2026-11-11T14:59:00")'), isTrue);
    expect(eval('isFuture("2026-11-11T14:59:00")'), isFalse);
    expect(eval('isFuture("2026-11-12")'), isTrue);
    expect(eval('isPast(null)'), isFalse);
    // Comparisons were already date-aware; diffDays counts calendar days.
    expect(eval('"2026-11-10" < now()'), isTrue);
    expect(eval('diffDays("2026-11-01", today())'), 10);
  });

  test('how often a formula changes as time passes', () {
    expect(FormulaEvaluator.clockTick('nowMs() - at'), ClockTick.frame);
    expect(FormulaEvaluator.clockTick('formatDate(now(), "HH:mm:ss")'), ClockTick.second);
    expect(FormulaEvaluator.clockTick('timeAgo(t) + " · " + formatDate(now(), "ss")'), ClockTick.second);
    expect(FormulaEvaluator.clockTick('timeAgo(t)'), ClockTick.minute);
    expect(FormulaEvaluator.clockTick('today()'), ClockTick.minute);
    expect(FormulaEvaluator.clockTick('isToday(t)'), ClockTick.minute);
    expect(FormulaEvaluator.clockTick('filter(cards, c => isFuture(c.expiresAt))'), ClockTick.minute);
    expect(FormulaEvaluator.clockTick('"now()" + t'), isNull);
    expect(FormulaEvaluator.clockTick('nowhere(t)'), isNull);
    expect(Expressions.clockTick(r'${= timeAgo(t)} · ${= now()}'), ClockTick.second);
    expect(Expressions.clockTick(r'${t}'), isNull);
  });

  test('a variable reading the clock brings it, through the functions it calls', () {
    final page = VariableScope([
      const Variable(name: 'ago', formula: 'timeAgo(t)', parameters: ['t']),
    ]);
    final screen = VariableScope([
      const Variable(name: 'sentAt', value: '2026-11-11T14:00:00'),
      const Variable(name: 'label', formula: 'ago(sentAt) + "!"'),
      const Variable(name: 'stamp', formula: 'formatDate(now(), "ss")'),
      const Variable(name: 'plain', formula: 'sentAt + "?"'),
    ], parent: page);
    addTearDown(screen.dispose);
    addTearDown(page.dispose);
    expect(page.clockOf('ago'), ClockTick.minute);
    expect(screen.clockOf('label'), isNull, reason: 'ago is another scope\'s: it answers for itself');
    expect(screen.clockOf('stamp'), ClockTick.second);
    expect(screen.clockOf('plain'), isNull);
    expect(screen.read('label'), '1h!');

    final log = <String>[];
    final watch = watchName(screen, 'label')!;
    void listener() => log.add('tick');
    watch.addListener(listener);
    expect(FormulaClock.minutes.isListened, isTrue);
    FormulaClock.minutes.tick();
    expect(log, ['tick']);
    watch.removeListener(listener);
    expect(FormulaClock.minutes.isListened, isFalse);
    expect(FormulaClock.minutes.isTicking, isFalse);

    // A plain value brings no clock.
    final plain = watchName(screen, 'plain')!;
    plain.addListener(listener);
    expect(FormulaClock.minutes.isListened || FormulaClock.instance.isListened, isFalse);
    plain.removeListener(listener);
  });

  testWidgets('a text calling a function variable that reads the clock follows it, once a minute', (tester) async {
    final app = Codelessly.fromBundle(
      _bundle(
        variables: const [
          Variable(name: 'sentAt', value: '2026-11-11T14:59:30'),
          Variable(name: 'ago', formula: 'timeAgo(t)', parameters: ['t']),
        ],
        text: r'${= ago(sentAt)}',
      ),
      fonts: const NoFontFetcher(),
    );
    addTearDown(app.dispose);
    final controller = CodelesslyWidgetController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(home: CodelesslyWidget(codelessly: app, controller: controller)));
    await tester.pumpAndSettle();
    String shown() => controller.tree!.boxOf('label')!.node!.prop(TextProps.text);
    expect(shown(), 'now');
    expect(FormulaClock.minutes.isTicking, isTrue);
    expect(FormulaClock.instance.isListened, isFalse, reason: 'no second ticks for a value that changes per minute');

    FormulaClock.pinned = now.add(const Duration(minutes: 2));
    await tester.pump(FormulaClock.minuteInterval);
    expect(shown(), '2m');

    FormulaClock.pinned = now.add(const Duration(hours: 5));
    FormulaClock.minutes.tick();
    await tester.pump();
    expect(shown(), '5h');

    await tester.pumpWidget(const SizedBox());
    expect(FormulaClock.minutes.isTicking, isFalse, reason: 'no timer once nothing shows it');
  });

  testWidgets('now() in a text ticks every second', (tester) async {
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
}
