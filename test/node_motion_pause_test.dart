import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'node_motion_test.dart' show box, pumpMotion, transformOf;

/// A badge circling its hive along a looping motion path stops in place
/// while `motion.paused` holds and carries on from there.
void main() {
  const orbit = MotionModel(
    path: 'M0 0 L400 0',
    pathProgress: 1,
    loop: MotionLoop.restart,
    durationMs: 4000,
    curve: MotionCurve.linear,
  );

  double x(WidgetTester tester) => transformOf(tester)!.getTranslation().x;

  testWidgets('a paused loop holds where it is and resumes from there', (
    tester,
  ) async {
    await pumpMotion(tester, orbit);
    await tester.pump(const Duration(milliseconds: 1000));
    expect(x(tester), closeTo(100, 2));

    await pumpMotion(tester, orbit.copyWith(paused: true));
    await tester.pump(const Duration(milliseconds: 1500));
    expect(x(tester), closeTo(100, 2));
    await tester.pump(const Duration(milliseconds: 1500));
    expect(x(tester), closeTo(100, 2));

    await pumpMotion(tester, orbit);
    await tester.pump(const Duration(milliseconds: 1000));
    expect(x(tester), closeTo(200, 2));
    // Still looping: past the end it starts again.
    await tester.pump(const Duration(milliseconds: 2500));
    expect(x(tester), closeTo(50, 2));
  });

  testWidgets('a paused transition holds and finishes after', (tester) async {
    const start = MotionModel(durationMs: 400, curve: MotionCurve.linear);
    await pumpMotion(tester, start);
    await pumpMotion(tester, start.copyWith(translateY: 100));
    await tester.pump(const Duration(milliseconds: 200));
    await pumpMotion(tester, start.copyWith(translateY: 100, paused: true));
    await tester.pump(const Duration(milliseconds: 600));
    expect(transformOf(tester)!.getTranslation().y, closeTo(50, 1.5));
    await pumpMotion(tester, start.copyWith(translateY: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(transformOf(tester)!.getTranslation().y, closeTo(75, 1.5));
    await tester.pump(const Duration(milliseconds: 150));
    expect(transformOf(tester)!.getTranslation().y, closeTo(100, 0.01));
  });

  test('motion.paused binds from a formula and round-trips', () {
    final node = box(
      motion: orbit,
      variables: {
        MotionModel.variableKey(MotionModel.pausedProperty): r'${= 1 < 2}',
      },
    );
    final resolved = WidgetNodeTransformerManager.resolveMotion(
      node,
      scopedValues: ScopedValues.empty(),
    )!;
    expect(resolved.paused, isTrue);
    // The design canvas never animates, so it ignores the binding.
    expect(
      WidgetNodeTransformerManager.resolveMotion(
        node,
        scopedValues: ScopedValues.empty(),
        animate: false,
      )!.paused,
      isFalse,
    );
    final json = box(motion: orbit.copyWith(paused: true)).toJson();
    expect(json['motion']['paused'], isTrue);
    expect(RectangleNode.fromJson(json).motion!.paused, isTrue);
    expect(
      box(motion: orbit).toJson()['motion'].containsKey('paused'),
      isFalse,
    );
  });
}
