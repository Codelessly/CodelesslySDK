import 'dart:math' as math;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

RectangleNode box({
  MotionModel? motion,
  Map<String, String> variables = const {},
}) =>
    RectangleNode(
        id: 'box',
        name: 'Box',
        basicBoxLocal: NodeBox(0, 0, 100, 100),
      )
      ..motion = motion
      ..variables.addAll(variables);

Future<void> pump(WidgetTester tester, MotionModel motion) => tester.pumpWidget(
  Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: NodeMotion(
        motion: motion,
        child: const SizedBox(width: 100, height: 100),
      ),
    ),
  ),
);

Matrix4? transformOf(WidgetTester tester) {
  final Finder finder = find.descendant(
    of: find.byType(NodeMotion),
    matching: find.byType(Transform),
  );
  if (finder.evaluate().isEmpty) return null;
  return tester.widget<Transform>(finder.first).transform;
}

double scaleOf(WidgetTester tester) =>
    transformOf(tester)?.getMaxScaleOnAxis() ?? 1;

/// A counter that bumps to 1.25 and back each time its value changes.
MotionModel counter(String value) => MotionModel(
  durationMs: 400,
  keyframes: const [MotionKeyframe(t: 0.5, scale: 1.25)],
  pulseKey: value,
);

void main() {
  testWidgets('A pulse plays the keyframes once when its key changes', (
    tester,
  ) async {
    await pump(tester, counter('1'));
    expect(transformOf(tester), isNull, reason: 'nothing plays at first');

    await pump(tester, counter('2'));
    await tester.pump(const Duration(milliseconds: 100));
    final double rising = scaleOf(tester);
    expect(rising, greaterThan(1));
    await tester.pump(const Duration(milliseconds: 100));
    expect(scaleOf(tester), closeTo(1.25, 0.01));
    await tester.pump(const Duration(milliseconds: 100));
    expect(scaleOf(tester), closeTo(rising, 0.01));
    await tester.pump(const Duration(milliseconds: 150));
    expect(transformOf(tester), isNull, reason: 'back at rest');

    // The same key plays nothing.
    await pump(tester, counter('2'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(transformOf(tester), isNull);

    // And it plays again on the next change.
    await pump(tester, counter('3'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(scaleOf(tester), closeTo(1.25, 0.01));
  });

  testWidgets('Keyframes shape a value change: a flip that swells mid-way', (
    tester,
  ) async {
    MotionModel flip(double rotateY) => MotionModel(
      rotateY: rotateY,
      perspective: 0,
      durationMs: 400,
      curve: MotionCurve.linear,
      keyframes: const [MotionKeyframe(t: 0.5, scale: 1.1)],
    );
    await pump(tester, flip(0));
    await pump(tester, flip(180));
    await tester.pump(const Duration(milliseconds: 200));
    final Matrix4 mid = transformOf(tester)!;
    // Halfway through the turn (90°) and at the keyframe's scale.
    expect(mid.getMaxScaleOnAxis(), closeTo(1.1, 0.01));
    expect(mid.entry(0, 0), closeTo(0, 0.01));
    await tester.pump(const Duration(milliseconds: 250));
    final Matrix4 end = transformOf(tester)!;
    expect(end.getMaxScaleOnAxis(), closeTo(1, 0.001));
    expect(end.entry(0, 0), closeTo(-1, 0.001));
  });

  testWidgets('A star flies along its path from pathProgress 0, '
      'its scale rising and falling', (tester) async {
    final MotionModel star = MotionModel.fromJson({
      'path': 'M0 0 L200 0',
      'pathProgress': 1,
      'durationMs': 400,
      'curve': 'linear',
      'enterFrom': {'pathProgress': 0},
      'keyframes': [
        {'t': 0.5, 'scale': 1.6},
      ],
    });
    await pump(tester, star);
    expect(transformOf(tester)!.getTranslation().x, closeTo(0, 0.5));
    await tester.pump(const Duration(milliseconds: 100));
    final double quarter = scaleOf(tester);
    expect(quarter, closeTo(1 + 0.6 * math.sin(math.pi / 4), 0.1));
    await tester.pump(const Duration(milliseconds: 100));
    expect(transformOf(tester)!.getTranslation().x, closeTo(100, 1));
    expect(scaleOf(tester), closeTo(1.6, 0.01));
    await tester.pump(const Duration(milliseconds: 250));
    expect(transformOf(tester)!.getTranslation().x, closeTo(200, 0.5));
    expect(scaleOf(tester), closeTo(1, 0.001));
  });

  testWidgets('A bound duration and curve apply to the transition they '
      'start', (tester) async {
    // Opens slowly with a linear curve, closes quickly.
    MotionModel sheet(bool open) => MotionModel(
      translateY: open ? 0 : 100,
      durationMs: open ? 400 : 100,
      curve: open ? MotionCurve.linear : MotionCurve.easeIn,
    );
    await pump(tester, sheet(false));
    await pump(tester, sheet(true));
    await tester.pump(const Duration(milliseconds: 200));
    expect(transformOf(tester)!.getTranslation().y, closeTo(50, 0.5));
    await tester.pump(const Duration(milliseconds: 250));
    await pump(tester, sheet(false));
    await tester.pump(const Duration(milliseconds: 120));
    expect(transformOf(tester)!.getTranslation().y, closeTo(100, 0.01));
  });

  testWidgets('A curve changed mid-transition does not jump it', (
    tester,
  ) async {
    const MotionModel rest = MotionModel(
      durationMs: 400,
      curve: MotionCurve.linear,
    );
    await pump(tester, rest);
    await pump(tester, rest.copyWith(translateX: 100));
    await tester.pump(const Duration(milliseconds: 200));
    expect(transformOf(tester)!.getTranslation().x, closeTo(50, 0.5));
    await pump(
      tester,
      rest.copyWith(translateX: 100, curve: MotionCurve.easeIn),
    );
    expect(transformOf(tester)!.getTranslation().x, closeTo(50, 0.5));
    await tester.pump(const Duration(milliseconds: 100));
    expect(transformOf(tester)!.getTranslation().x, closeTo(75, 0.5));
  });

  test('Duration, delay, curve and pulse key bind to variables', () {
    final RectangleNode node = box(
      motion: const MotionModel(
        durationMs: 200,
        keyframes: [MotionKeyframe(t: 0.5, scale: 1.25)],
      ),
      variables: {
        MotionModel.variableKey('durationMs'): r'${= true ? 380 : 160}',
        MotionModel.variableKey('delayMs'): r'${= 40}',
        MotionModel.variableKey('curve'):
            r"${= false ? 'easeIn' : 'elasticOut'}",
        MotionModel.variableKey(MotionModel.pulseKeyProperty): r'${= 2 + 3}',
      },
    );
    final MotionModel resolved = WidgetNodeTransformerManager.resolveMotion(
      node,
      scopedValues: ScopedValues.empty(),
    )!;
    expect(resolved.durationMs, 380);
    expect(resolved.delayMs, 40);
    expect(resolved.curve, MotionCurve.elasticOut);
    expect(resolved.pulseKey, '5');
    expect(resolved.keyframes, node.motion!.keyframes);
  });

  test('A curve binding naming no curve keeps the node curve', () {
    final RectangleNode node = box(
      motion: const MotionModel(curve: MotionCurve.spring),
      variables: {MotionModel.variableKey('curve'): r"${= 'wobbly'}"},
    );
    expect(
      WidgetNodeTransformerManager.resolveMotion(
        node,
        scopedValues: ScopedValues.empty(),
      )!.curve,
      MotionCurve.spring,
    );
  });
}
