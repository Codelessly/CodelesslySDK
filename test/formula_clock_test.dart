import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the frame clock ticks each frame only while listened to', (
    tester,
  ) async {
    int ticks = 0;
    void listener() => ticks++;
    expect(FrameClock.instance.isTicking, isFalse);
    FrameClock.instance.addListener(listener);
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    expect(ticks, greaterThanOrEqualTo(3));
    FrameClock.instance.removeListener(listener);
    final int stopped = ticks;
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    expect(ticks, stopped);
    expect(FrameClock.instance.isTicking, isFalse);
  });

  test('nowMs() reads the frame clock, now() the second clock', () {
    expect(FormulaEvaluator.readsFrameClock('hit * (nowMs() - at)'), isTrue);
    expect(FormulaEvaluator.readsClock('hit * (nowMs() - at)'), isFalse);
    expect(FormulaEvaluator.readsFrameClock('now()'), isFalse);
    expect(FormulaEvaluator.readsFrameClock("'nowMs()'"), isFalse);
  });

  tearDown(() => FormulaClock.pinned = null);

  String eval(String formula) => FormulaEvaluator.stringify(
    FormulaEvaluator.evaluate(formula, (path) => null),
  );

  test('a pinned clock is what now() and today() read', () {
    FormulaClock.pinned = DateTime.parse('2026-10-22T13:20:00-07:00');
    expect(
      eval("formatDate(now('-07:00'), 'EEE, MMM d · h:mm a')"),
      'Thu, Oct 22 · 1:20 PM',
    );
    expect(eval("formatDate(today('-07:00'), 'yyyy-MM-dd')"), '2026-10-22');
    expect(eval("formatDate(now('Z'), 'HH:mm')"), '20:20');
  });

  test('without a pin, now() is the device clock', () {
    final String year = '${DateTime.now().year}';
    expect(eval("formatDate(now(), 'yyyy')"), year);
  });

  test('nowMs() is the clock in milliseconds, for timing taps', () {
    FormulaClock.pinned = DateTime.fromMillisecondsSinceEpoch(1793356053036);
    expect(eval('nowMs()'), '1793356053036');
    expect(eval('round(60000 / (nowMs() - 1793356052536))'), '120');
  });
}
