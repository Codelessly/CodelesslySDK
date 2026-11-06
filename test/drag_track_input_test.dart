import 'dart:math' as math;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Track input like Lamplight's controls: the colour-temperature arc takes
/// the pointer anywhere along the arc, the brightness knob turns from
/// anywhere in its box by dx − dy, toggles 100 / 50 on a double tap, and
/// both step with the wheel and the arrow keys.
void main() {
  late double value;
  late List<double> changes;
  late List<double> ends;

  /// A 300x300 [plate] (the knob's box) whose [size] node sits at [at].
  Widget plate(
    DragTrackModel track, {
    Size size = const Size(60, 60),
    Offset at = const Offset(120, 120),
  }) {
    final GlobalKey plateKey = GlobalKey();
    return Directionality(
      textDirection: TextDirection.ltr,
      child: StatefulBuilder(
        builder: (context, setState) => Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              width: 300,
              height: 300,
              child: Stack(
                key: plateKey,
                children: [
                  Positioned(
                    left: at.dx,
                    top: at.dy,
                    width: size.width,
                    height: size.height,
                    child: NodeDragTrack(
                      track: track,
                      value: value,
                      hitAreaBox: () =>
                          plateKey.currentContext?.findRenderObject()
                              as RenderBox?,
                      onChanged: (v) {
                        changes.add(v);
                        setState(() => value = v);
                      },
                      onEnd: ends.add,
                      child: const SizedBox.expand(child: Text('cap')),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  setUp(() {
    changes = [];
    ends = [];
  });

  /// The handle's centre, given that it orbits (150, 150) with radius 120.
  Offset onArc(double degrees) {
    final double r = degrees * math.pi / 180;
    return Offset(150 + 120 * math.sin(r), 150 - 120 * math.cos(r));
  }

  // The kelvin arc: a handle resting at the top of a 240° arc of radius
  // 120 (its pivot 120 below it), stepped by 100 K.
  const kelvin = DragTrackModel(
    shape: DragTrackShape.arc,
    min: 2200,
    max: 6500,
    step: 100,
    startAngle: -120,
    endAngle: 120,
    pivotY: 120,
    rotate: false,
    jumpOnTap: true,
    hitArea: DragTrackHitArea.parent,
    keyStep: 100,
  );

  testWidgets('pressing anywhere along an arc jumps the handle there', (
    tester,
  ) async {
    value = 2200;
    // The handle rests at the top (angle 0): its centre (150, 30).
    await tester.pumpWidget(plate(kelvin, size: const Size(30, 30), at: const Offset(135, 15)));
    expect(tester.getCenter(find.text('cap')), offsetMoreOrLessEquals(onArc(-120), epsilon: 0.5));
    // Press at 3 o'clock on the arc, far from the handle: +90° of 240°.
    final gesture = await tester.startGesture(onArc(90));
    await tester.pump();
    expect(value, 2200 + ((210 / 240) * 4300 / 100).round() * 100);
    // At 6000 K, the 100 K step nearest the press (5962 K).
    expect(
      tester.getCenter(find.text('cap')),
      offsetMoreOrLessEquals(onArc(-120 + 240 * 3800 / 4300), epsilon: 0.5),
    );
    // Then drag round to the top: follows the pointer's angle.
    for (double a = 80; a >= 0; a -= 10) {
      await gesture.moveTo(onArc(a));
    }
    await tester.pump();
    // Halfway: 4350 K, snapped to the nearest 100 K step.
    expect(value, 4400);
    // Past the bottom gap the value clamps to the nearer end.
    await gesture.moveTo(const Offset(160, 290));
    await tester.pump();
    expect(value, 6500);
    await gesture.up();
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('arrow keys step a focused track', (tester) async {
    value = 4000;
    await tester.pumpWidget(plate(kelvin, size: const Size(30, 30), at: const Offset(135, 15)));
    // Pressing the track focuses it.
    await tester.tapAt(tester.getCenter(find.text('cap')));
    await tester.pump(const Duration(seconds: 1));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(value, 4100);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(value, 3900);
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pump();
    expect(value, 6500);
    expect(ends.last, 6500);
  });

  // The brightness knob: turns in place by dx − dy, 220px for the range.
  const knob = DragTrackModel(
    shape: DragTrackShape.arc,
    min: 0,
    max: 100,
    step: 1,
    input: DragTrackInput.both,
    pixelsPerRange: 220,
    hitArea: DragTrackHitArea.parent,
    wheelStep: 2,
    doubleTapValues: [100, 50],
  );

  testWidgets('a knob turns by dx - dy from anywhere in its box', (
    tester,
  ) async {
    value = 40;
    await tester.pumpWidget(plate(knob));
    // From the tick ring's corner, well outside the 60px body.
    final gesture = await tester.startGesture(const Offset(20, 280));
    await gesture.moveBy(const Offset(30, 0));
    await gesture.moveBy(const Offset(25, -55));
    await tester.pump();
    // 55 + 55 = 110 px of 220: half the range on top of the slop.
    expect(value, inInclusiveRange(85, 95));
    await gesture.up();
    await tester.pump(const Duration(seconds: 1));
    expect(ends.last, value);
  });

  testWidgets('outside the parent the knob does not take the pointer', (
    tester,
  ) async {
    value = 40;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          children: [
            Positioned(left: 0, top: 0, width: 400, height: 400, child: plate(knob)),
          ],
        ),
      ),
    );
    final gesture = await tester.startGesture(const Offset(350, 350));
    await gesture.moveBy(const Offset(40, -80));
    await tester.pump();
    expect(value, 40);
    await gesture.up();
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('without hitArea parent the box around the knob is not hit', (
    tester,
  ) async {
    value = 40;
    await tester.pumpWidget(plate(knob.copyWith(hitArea: DragTrackHitArea.self)));
    final gesture = await tester.startGesture(const Offset(20, 280));
    await gesture.moveBy(const Offset(40, -80));
    await tester.pump();
    expect(value, 40);
    await gesture.up();
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('double tap toggles between its values', (tester) async {
    value = 37;
    await tester.pumpWidget(plate(knob));
    Future<void> doubleTap() async {
      await tester.tapAt(const Offset(40, 40));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(const Offset(40, 40));
      await tester.pump(const Duration(milliseconds: 400));
    }

    await doubleTap();
    expect(value, 100);
    await doubleTap();
    expect(value, 50);
    await doubleTap();
    expect(value, 100);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('the wheel moves by wheelStep', (tester) async {
    value = 40;
    await tester.pumpWidget(plate(knob));
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointer.hover(const Offset(150, 150)));
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, -20)));
    await tester.pump();
    expect(value, 42);
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, 20)));
    await tester.pump();
    expect(value, 40);
  });

  test('double tap targets and JSON of the new fields', () {
    expect(knob.doubleTapTarget(37), 100);
    expect(knob.doubleTapTarget(100), 50);
    expect(knob.doubleTapTarget(50), 100);
    const reset = DragTrackModel(defaultValue: 0.5);
    expect(reset.doubleTapTarget(0.2), 0.5);
    expect(const DragTrackModel().doubleTapTarget(0.2), isNull);
    expect(knob.effectiveWheelStep, 2);
    expect(const DragTrackModel(min: 0, max: 200).effectiveWheelStep, 2);
    expect(DragTrackModel.fromJson(knob.toJson()), knob);
    expect(DragTrackModel.fromJson(kelvin.toJson()), kelvin);
  });

  test('a parent-unit track scales its line and path to the parent', () {
    const line = DragTrackModel(x2: 1, y2: 0, units: DragTrackUnits.parent);
    final DragTrackModel px = resolveDragTrack(
      line,
      parentSize: const Size(320, 40),
    );
    expect(px.x2, 320);
    final DragTrackGeometry geometry = DragTrackGeometry(px);
    expect(geometry.offsetAt(0.5), const Offset(160, 0));

    const path = DragTrackModel(
      shape: DragTrackShape.path,
      path: 'M0 0 L1 0',
      units: DragTrackUnits.parent,
    );
    final DragTrackGeometry scaled = DragTrackGeometry(
      path,
      scale: trackPathScale(path, const Size(200, 100)),
    );
    expect(scaled.offsetAt(1).dx, closeTo(200, 0.5));
    expect(scaled.nearest(const Offset(50, 3)), closeTo(0.25, 0.01));
  });

  test('bound geometry replaces the saved fields', () {
    const t = DragTrackModel(x2: 100, y2: 0, startAngle: -90);
    final DragTrackModel bound = resolveDragTrack(
      t,
      bound: {'x2': 240.0, 'startAngle': '-120', 'path': 'M0 0 L10 0'},
    );
    expect(bound.x2, 240);
    expect(bound.startAngle, -120);
    expect(bound.path, 'M0 0 L10 0');
    expect(bound.y2, 0);
  });
}
