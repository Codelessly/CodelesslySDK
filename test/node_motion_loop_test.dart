import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pump(WidgetTester tester, MotionModel motion,
        {bool animate = true}) =>
    tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: NodeMotion(
            motion: motion,
            animate: animate,
            child: const SizedBox(width: 100, height: 100),
          ),
        ),
      ),
    );

double opacityOf(WidgetTester tester) {
  final Finder finder = find.byType(Opacity);
  return finder.evaluate().isEmpty
      ? 1
      : tester.widget<Opacity>(finder.first).opacity;
}

double dxOf(WidgetTester tester) {
  final Finder finder = find.descendant(
    of: find.byType(NodeMotion),
    matching: find.byType(Transform),
  );
  if (finder.evaluate().isEmpty) return 0;
  return tester.widget<Transform>(finder.first).transform.getTranslation().x;
}

void main() {
  testWidgets('A back-and-forth loop pulses between rest and its values', (
    tester,
  ) async {
    await pump(
      tester,
      const MotionModel(
        opacity: 0.4,
        durationMs: 1000,
        curve: MotionCurve.linear,
        loop: MotionLoop.reverse,
      ),
    );
    expect(opacityOf(tester), 1);
    await tester.pump(const Duration(milliseconds: 500));
    expect(opacityOf(tester), closeTo(0.7, 0.01));
    await tester.pump(const Duration(milliseconds: 500));
    expect(opacityOf(tester), closeTo(0.4, 0.01));
    await tester.pump(const Duration(milliseconds: 500));
    expect(opacityOf(tester), closeTo(0.7, 0.01));
    await tester.pump(const Duration(milliseconds: 500));
    expect(opacityOf(tester), closeTo(1, 0.01));
    // Still going.
    await tester.pump(const Duration(milliseconds: 250));
    expect(opacityOf(tester), closeTo(0.85, 0.01));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('A restart loop jumps back to rest each time', (tester) async {
    await pump(
      tester,
      const MotionModel(
        translateX: 100,
        durationMs: 1000,
        curve: MotionCurve.linear,
        loop: MotionLoop.restart,
      ),
    );
    await tester.pump(const Duration(milliseconds: 900));
    expect(dxOf(tester), closeTo(90, 0.5));
    await tester.pump(const Duration(milliseconds: 200));
    expect(dxOf(tester), closeTo(10, 0.5));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('An entrance animates in from rest after its delay', (
    tester,
  ) async {
    await pump(
      tester,
      const MotionModel(
        translateX: 120,
        durationMs: 400,
        curve: MotionCurve.linear,
        enter: true,
        delayMs: 200,
      ),
    );
    expect(dxOf(tester), 0);
    await tester.pump(const Duration(milliseconds: 150));
    expect(dxOf(tester), 0, reason: 'still waiting out the delay');
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 200));
    expect(dxOf(tester), closeTo(60, 1));
    await tester.pump(const Duration(milliseconds: 300));
    expect(dxOf(tester), 120);
  });

  testWidgets('A delay holds an ordinary transition back too', (tester) async {
    const MotionModel motion = MotionModel(
      durationMs: 100,
      curve: MotionCurve.linear,
      delayMs: 300,
    );
    await pump(tester, motion);
    await pump(tester, motion.copyWith(translateX: 50));
    await tester.pump(const Duration(milliseconds: 200));
    expect(dxOf(tester), 0);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(dxOf(tester), 50);
  });

  testWidgets('The design canvas shows the values at rest, without looping', (
    tester,
  ) async {
    await pump(
      tester,
      const MotionModel(
        opacity: 0.4,
        durationMs: 1000,
        loop: MotionLoop.reverse,
        enter: true,
      ),
      animate: false,
    );
    expect(opacityOf(tester), closeTo(0.4, 0.001));
    await tester.pump(const Duration(milliseconds: 500));
    expect(opacityOf(tester), closeTo(0.4, 0.001));
  });

  test('loop, enter and delay survive JSON and are omitted at defaults', () {
    const MotionModel motion = MotionModel(
      loop: MotionLoop.reverse,
      enter: true,
      delayMs: 180,
    );
    expect(MotionModel.fromJson(motion.toJson()), motion);
    expect(MotionModel.none.toJson().containsKey('loop'), isFalse);
  });
}
