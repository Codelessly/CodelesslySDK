import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// A pulse that runs only in some states: `motion.loop` bound per state.

const MotionModel pulse = MotionModel(
  opacity: 0.4,
  durationMs: 1000,
  curve: MotionCurve.linear,
  loop: MotionLoop.reverse,
);

RectangleNode dot(String loopBinding, {MotionModel? motion = pulse}) =>
    RectangleNode(id: 'dot', name: 'Dot', basicBoxLocal: NodeBox(0, 0, 10, 10))
      ..motion = motion
      ..variables[MotionModel.variableKey(MotionModel.loopProperty)] =
          loopBinding;

MotionModel? resolve(RectangleNode node, {bool animate = true}) =>
    WidgetNodeTransformerManager.resolveMotion(
      node,
      scopedValues: ScopedValues.empty(),
      animate: animate,
    );

double opacityOf(WidgetTester tester) {
  final Finder finder = find.byType(Opacity);
  return finder.evaluate().isEmpty
      ? 1
      : tester.widget<Opacity>(finder.first).opacity;
}

Future<void> pump(WidgetTester tester, MotionModel motion) => tester.pumpWidget(
  Directionality(
    textDirection: TextDirection.ltr,
    child: NodeMotion(motion: motion, child: const SizedBox(width: 10)),
  ),
);

void main() {
  test('A bound loop switches the loop on and off', () {
    expect(
      resolve(dot(r"${= true ? 'reverse' : 'none'}"))!.loop,
      MotionLoop.reverse,
    );
    final MotionModel off = resolve(dot(r"${= false ? 'reverse' : 'none'}"))!;
    expect(off.loop, MotionLoop.none);
    // Off, the node rests instead of holding the loop's far end.
    expect(off.opacity, 1);
    expect(off.hasTransform, isFalse);
    expect(off.durationMs, 1000);
    expect(resolve(dot('restart'))!.loop, MotionLoop.restart);
  });

  test('true and false keep the saved loop or turn it off', () {
    expect(resolve(dot(r'${= 1 > 0}'))!.loop, MotionLoop.reverse);
    expect(resolve(dot(r'${= 1 < 0}'))!.loop, MotionLoop.none);
    expect(
      resolve(
        dot('true', motion: const MotionModel(scale: 1.2, durationMs: 500)),
      )!.loop,
      MotionLoop.reverse,
      reason: 'on without a saved loop pulses back and forth',
    );
    expect(
      WidgetNodeTransformerManager.motionLoopOf(
        'restart',
        saved: MotionLoop.reverse,
      ),
      MotionLoop.restart,
    );
    expect(
      WidgetNodeTransformerManager.motionLoopOf(
        'sideways',
        saved: MotionLoop.reverse,
      ),
      isNull,
    );
  });

  test('The design canvas ignores the binding', () {
    final MotionModel canvas = resolve(dot('none'), animate: false)!;
    expect(canvas, pulse);
  });

  testWidgets('Switching the bound loop off eases back to rest; on pulses', (
    tester,
  ) async {
    await pump(tester, resolve(dot('reverse'))!);
    await tester.pump(const Duration(milliseconds: 500));
    expect(opacityOf(tester), closeTo(0.7, 0.01));

    await pump(tester, resolve(dot('none'))!);
    await tester.pump(const Duration(milliseconds: 1100));
    expect(opacityOf(tester), 1);
    await tester.pump(const Duration(milliseconds: 500));
    expect(opacityOf(tester), 1, reason: 'stays at rest');

    await pump(tester, resolve(dot('reverse'))!);
    await tester.pump(const Duration(milliseconds: 500));
    expect(opacityOf(tester), closeTo(0.7, 0.01));
    await tester.pumpWidget(const SizedBox());
  });
}
