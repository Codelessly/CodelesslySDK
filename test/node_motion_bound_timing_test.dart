import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

RectangleNode box(Map<String, String> variables) =>
    RectangleNode(
        id: 'orb',
        name: 'Orb',
        basicBoxLocal: NodeBox(0, 0, 100, 100),
      )
      ..motion = const MotionModel(
        durationMs: 300,
        curve: MotionCurve.easeInOutSine,
      )
      ..variables.addAll(variables);

Future<void> pump(WidgetTester tester, MotionModel motion) => tester.pumpWidget(
  Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: NodeMotion(
        motion: motion,
        animate: true,
        child: const SizedBox(width: 100, height: 100),
      ),
    ),
  ),
);

/// The x scale of the motion's transform; 1 when it draws none (at rest).
double scaleOf(WidgetTester tester) {
  final Finder transforms = find.descendant(
    of: find.byType(NodeMotion),
    matching: find.byType(Transform),
  );
  if (transforms.evaluate().isEmpty) return 1;
  return tester.widget<Transform>(transforms.first).transform.storage[0];
}

void main() {
  test('the transition duration and delay can be bound', () {
    final MotionModel resolved = WidgetNodeTransformerManager.resolveMotion(
      box({
        MotionModel.variableKey('durationMs'): r'${= 7 * 1000}',
        MotionModel.variableKey('delayMs'): r'${= 250}',
      }),
      scopedValues: ScopedValues.empty(),
    )!;
    expect(resolved.durationMs, 7000);
    expect(resolved.delayMs, 250);
    expect(resolved.curve, MotionCurve.easeInOutSine);
  });

  test('bound timings are clamped to whole, non-negative milliseconds', () {
    expect(MotionModel.none.withValue('durationMs', -5).durationMs, 0);
    expect(MotionModel.none.withValue('durationMs', 1234.6).durationMs, 1235);
    expect(MotionModel.none.valueOf('delayMs'), 0);
  });

  testWidgets('a breath: scale eases over the bound phase length', (
    tester,
  ) async {
    // Inhale for 4 s: scale to 1 with a sine ease.
    const MotionModel rest = MotionModel(
      scale: 0.6,
      durationMs: 4000,
      curve: MotionCurve.easeInOutSine,
    );
    await pump(tester, rest);
    await pump(tester, rest.copyWith(scale: 1));
    await tester.pump(const Duration(seconds: 2));
    // Half way through a sine ease is half way between the values.
    expect(scaleOf(tester), closeTo(0.8, 0.01));
    await tester.pump(const Duration(seconds: 2));
    expect(scaleOf(tester), closeTo(1, 0.001));

    // Exhale for 8 s: the new duration applies to the next change.
    await pump(tester, rest.copyWith(scale: 0.6, durationMs: 8000));
    await tester.pump(const Duration(seconds: 2));
    // A quarter of the way through a sine ease: 1 - 0.4 * (1 - cos(pi/4)) / 2.
    expect(scaleOf(tester), closeTo(1 - 0.4 * 0.1464, 0.01));
    await tester.pump(const Duration(seconds: 6));
    expect(scaleOf(tester), closeTo(0.6, 0.001));
  });

  testWidgets('a label un-blurs as it enters', (tester) async {
    const MotionModel label = MotionModel(
      durationMs: 600,
      curve: MotionCurve.linear,
      enterFrom: MotionModel(blur: 8, opacity: 0),
    );
    await pump(tester, label);
    bool blurred() => find
        .descendant(
          of: find.byType(NodeMotion),
          matching: find.byType(ImageFiltered),
        )
        .evaluate()
        .isNotEmpty;

    expect(blurred(), isTrue, reason: 'starts blurred');
    await tester.pump(const Duration(milliseconds: 300));
    expect(blurred(), isTrue, reason: 'half way, still a little blurred');
    await tester.pump(const Duration(milliseconds: 400));
    expect(blurred(), isFalse, reason: 'sharp at rest');
  });

  test('blur is bindable and part of the transform', () {
    final MotionModel m = MotionModel.none.withValue('blur', 4);
    expect(m.blur, 4);
    expect(m.hasTransform, isTrue);
    expect(MotionModel.none.withValue('blur', -3).blur, 0);
    expect(MotionModel.properties, contains('blur'));
    expect(MotionModel.fromJson(m.toJson()).blur, 4);
  });
}
