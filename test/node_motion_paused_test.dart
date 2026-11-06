import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pump(WidgetTester tester, MotionModel motion) => tester.pumpWidget(
  Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: NodeMotion(
        motion: motion,
        child: const SizedBox(key: Key('chair'), width: 10, height: 10),
      ),
    ),
  ),
);

double x(WidgetTester tester) =>
    tester.getTopLeft(find.byKey(const Key('chair'))).dx;

// A chair riding a 100 px cable once a second.
const MotionModel ride = MotionModel(
  translateX: 100,
  durationMs: 1000,
  curve: MotionCurve.linear,
  loop: MotionLoop.restart,
);

void main() {
  testWidgets('a paused loop stops where it is and carries on from there', (
    tester,
  ) async {
    await pump(tester, ride);
    await tester.pump(const Duration(milliseconds: 400));
    expect(x(tester), closeTo(40, 1));

    // On hold: the chair stays put, it doesn't ease back to rest.
    await pump(tester, ride.copyWith(paused: true));
    await tester.pump(const Duration(milliseconds: 500));
    expect(x(tester), closeTo(40, 1));

    // Reopened: it rides on from 40.
    await pump(tester, ride);
    await tester.pump(const Duration(milliseconds: 200));
    expect(x(tester), closeTo(60, 1));
  });

  testWidgets('a loop that starts paused waits at its start', (tester) async {
    await pump(tester, ride.copyWith(paused: true));
    await tester.pump(const Duration(milliseconds: 600));
    expect(x(tester), closeTo(0, 0.01));
    await pump(tester, ride);
    await tester.pump(const Duration(milliseconds: 300));
    expect(x(tester), closeTo(30, 1));
  });

  testWidgets('a loop built where tickers are off starts once they run', (
    tester,
  ) async {
    // A page body kept alive but hidden while it loads: no tickers yet.
    Future<void> show(bool enabled, MotionModel motion) => tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: TickerMode(
          enabled: enabled,
          child: Align(
            alignment: Alignment.topLeft,
            child: NodeMotion(
              motion: motion,
              child: const SizedBox(key: Key('chair'), width: 10, height: 10),
            ),
          ),
        ),
      ),
    );
    final MotionModel held = ride.copyWith(paused: true, phase: 0.25);
    await show(false, held);
    // Shown: a held chair sits a quarter of the way round, not at the start.
    await show(true, held);
    await tester.pump(const Duration(milliseconds: 300));
    expect(x(tester), closeTo(25, 1));
    // Resumed: it rides on from there.
    await show(true, ride.copyWith(phase: 0.25));
    await tester.pump(const Duration(milliseconds: 200));
    expect(x(tester), closeTo(45, 1));
  });

  test('paused round-trips through JSON and is left out when false', () {
    final MotionModel paused = ride.copyWith(paused: true);
    expect(MotionModel.fromJson(paused.toJson()).paused, isTrue);
    expect(ride.toJson().containsKey('paused'), isFalse);
  });

  test('motion.paused binds to a formula', () {
    RectangleNode chair(String formula) =>
        RectangleNode(
            id: 'chair',
            name: 'chair',
            basicBoxLocal: NodeBox(0, 0, 10, 10),
          )
          ..motion = ride
          ..variables.addAll({
            MotionModel.variableKey(MotionModel.pausedProperty): formula,
          });
    MotionModel? resolve(String formula) =>
        WidgetNodeTransformerManager.resolveMotion(
          chair(formula),
          scopedValues: ScopedValues.empty(),
        );
    expect(resolve(r"${= 'hold' == 'hold'}")!.paused, isTrue);
    expect(resolve(r"${= 'open' == 'hold'}")!.paused, isFalse);
    expect(resolve('on')!.paused, isTrue);
  });

  testWidgets('a loop with a phase starts that far through its cycle', (
    tester,
  ) async {
    await pump(tester, ride.copyWith(phase: 0.25));
    await tester.pump(const Duration(milliseconds: 100));
    expect(x(tester), closeTo(35, 1));
    // Round the loop: 0.25 + 0.85 -> 0.10 of the way along.
    await tester.pump(const Duration(milliseconds: 750));
    expect(x(tester), closeTo(10, 1));
  });

  test('motion.phase binds as a setting and keeps only the fraction', () {
    expect(ride.withSetting('phase', '1.375').phase, 0.375);
    expect(MotionModel.settings, contains('phase'));
  });
}
