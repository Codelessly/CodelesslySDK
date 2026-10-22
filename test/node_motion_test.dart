import 'dart:math' as math;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
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

Matrix4? transformOf(WidgetTester tester) {
  final finder = find.descendant(
    of: find.byType(NodeMotion),
    matching: find.byType(Transform),
  );
  if (finder.evaluate().isEmpty) return null;
  return tester.widget<Transform>(finder.first).transform;
}

Future<void> pumpMotion(
  WidgetTester tester,
  MotionModel motion, {
  bool animate = true,
}) => tester.pumpWidget(
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

void main() {
  test('Motion round-trips through a node and omits defaults', () {
    const motion = MotionModel(rotateX: 30, durationMs: 400, spin: 0.555);
    final json = box(motion: motion).toJson();
    expect(json['motion'], {'rotateX': 30.0, 'durationMs': 400, 'spin': 0.555});
    final restored = RectangleNode.fromJson(json);
    expect(restored.motion, motion);
    expect(box().toJson().containsKey('motion'), isFalse);
  });

  test('Bound motion values come from variables and formulas', () {
    final node = box(
      motion: const MotionModel(rotateX: 5),
      variables: {
        MotionModel.variableKey('rotateX'): r'${= 2 * 30}',
        MotionModel.variableKey('translateY'): r'${= 1 > 2 ? 0 : -12}',
        MotionModel.variableKey('spin'): r'${= true ? 0.75 : 0}',
      },
    );
    final resolved = WidgetNodeTransformerManager.resolveMotion(
      node,
      scopedValues: ScopedValues.empty(),
    )!;
    expect(resolved.rotateX, 60);
    expect(resolved.translateY, -12);
    expect(resolved.spin, 0.75);
  });

  test('A node with only bound values still moves', () {
    final node = box(
      variables: {MotionModel.variableKey('scale'): r'${= 0.5}'},
    );
    final resolved = WidgetNodeTransformerManager.resolveMotion(
      node,
      scopedValues: ScopedValues.empty(),
    );
    expect(resolved?.scale, 0.5);
  });

  testWidgets('Changing a value animates to it over the duration', (
    tester,
  ) async {
    const start = MotionModel(durationMs: 400, curve: MotionCurve.linear);
    await pumpMotion(tester, start);
    expect(transformOf(tester), isNull);

    await pumpMotion(tester, start.copyWith(translateY: 100));
    await tester.pump(const Duration(milliseconds: 200));
    expect(transformOf(tester)!.getTranslation().y, closeTo(50, 1));
    await tester.pump(const Duration(milliseconds: 250));
    expect(transformOf(tester)!.getTranslation().y, closeTo(100, 0.01));
  });

  testWidgets('A change mid-transition continues from where it is', (
    tester,
  ) async {
    const start = MotionModel(durationMs: 400, curve: MotionCurve.linear);
    await pumpMotion(tester, start);
    await pumpMotion(tester, start.copyWith(translateX: 100));
    await tester.pump(const Duration(milliseconds: 200));
    await pumpMotion(tester, start.copyWith(translateX: 0));
    await tester.pump(const Duration(milliseconds: 1));
    expect(transformOf(tester)!.getTranslation().x, closeTo(50, 1.5));
  });

  testWidgets('Without a duration, or on the design canvas, values jump', (
    tester,
  ) async {
    await pumpMotion(tester, const MotionModel());
    await pumpMotion(tester, const MotionModel(translateX: 40));
    expect(transformOf(tester)!.getTranslation().x, 40);

    await pumpMotion(
      tester,
      const MotionModel(durationMs: 500),
      animate: false,
    );
    await pumpMotion(
      tester,
      const MotionModel(durationMs: 500, translateX: 80),
      animate: false,
    );
    expect(transformOf(tester)!.getTranslation().x, 80);
  });

  testWidgets('Spin ramps up, turns, and winds down when stopped', (
    tester,
  ) async {
    double angle() {
      final m = transformOf(tester);
      if (m == null) return 0;
      return math.atan2(m.entry(1, 0), m.entry(0, 0));
    }

    await pumpMotion(tester, const MotionModel(spin: 1, spinRampMs: 1000));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    final early = angle();
    // Still ramping: far slower than a full turn per second.
    expect(early.abs(), lessThan(0.1));

    for (var i = 0; i < 120; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(angle(), isNot(closeTo(early, 0.01)));

    await pumpMotion(tester, const MotionModel(spin: 0, spinRampMs: 300));
    for (var i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final stopped = angle();
    await tester.pump(const Duration(milliseconds: 100));
    expect(angle(), stopped);
  });

  testWidgets('The design canvas never spins', (tester) async {
    await pumpMotion(tester, const MotionModel(spin: 1), animate: false);
    await tester.pump(const Duration(milliseconds: 500));
    expect(transformOf(tester), isNull);
  });

  test('Tilts get perspective, flat transforms don\'t', () {
    expect(motionMatrix(const MotionModel(rotateX: 20)).entry(3, 2), isNot(0));
    expect(motionMatrix(const MotionModel(translateX: 20)).entry(3, 2), 0);
    expect(
      motionMatrix(const MotionModel(rotateX: 20, perspective: 0)).entry(3, 2),
      0,
    );
  });

  testWidgets('Opacity animates, and a faded-out node takes no taps', (
    tester,
  ) async {
    var taps = 0;
    Future<void> pump(double opacity) => tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: NodeMotion(
            motion: MotionModel(
              opacity: opacity,
              durationMs: 200,
              curve: MotionCurve.linear,
            ),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => taps++,
              child: const SizedBox(width: 100, height: 100),
            ),
          ),
        ),
      ),
    );
    await pump(1);
    await pump(0);
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      tester.widget<Opacity>(find.byType(Opacity)).opacity,
      closeTo(0.5, 0.05),
    );
    await tester.pump(const Duration(milliseconds: 150));
    await tester.tapAt(tester.getCenter(find.byType(NodeMotion)));
    expect(taps, 0);
    await pump(1);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tapAt(tester.getCenter(find.byType(NodeMotion)));
    expect(taps, 1);
  });
}
