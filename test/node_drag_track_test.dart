import 'dart:math' as math;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Drag tracks turn any styled node into a value control: a fader cap on a
/// line, a knob on an arc, a handle on a path. The node is drawn at its
/// value and dragging it writes new values.
void main() {
  late double value;
  late List<double> changes;
  late List<double> ends;
  late List<TrackValues> seen;

  /// A 400x400 faceplate with a [size] node laid out at [at] (top left).
  Widget plate(
    DragTrackModel track, {
    Size size = const Size(40, 22),
    Offset at = const Offset(180, 300),
  }) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: StatefulBuilder(
        builder: (context, setState) => Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              width: 400,
              height: 400,
              child: Stack(
                children: [
                  Positioned(
                    left: at.dx,
                    top: at.dy,
                    width: size.width,
                    height: size.height,
                    child: NodeDragTrack(
                      track: track,
                      value: value,
                      onChanged: (v) {
                        changes.add(v);
                        setState(() => value = v);
                      },
                      onEnd: ends.add,
                      child: Builder(
                        builder: (context) {
                          seen.add(TrackScope.maybeOf(context)!);
                          return const SizedBox.expand(child: Text('cap'));
                        },
                      ),
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
    seen = [];
  });

  // A fader: the cap rests at the bottom of a 250px throw, -48 to +6 dB.
  const fader = DragTrackModel(
    variable: 'accent',
    min: -48,
    max: 6,
    step: 0.5,
    defaultValue: 0,
    y2: -250,
    jumpOnTap: true,
  );

  testWidgets('a line track draws the node at its value', (tester) async {
    value = -21; // halfway
    await tester.pumpWidget(plate(fader));
    // Laid out centred at (200, 311); halfway up the 250px throw.
    expect(tester.getCenter(find.text('cap')), const Offset(200, 186));
    expect(seen.last.progress, closeTo(0.5, 1e-9));
    expect(seen.last.value, -21);
    // Let the double-tap recognizer's timer run out.
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('dragging along a line writes snapped values', (tester) async {
    value = -48;
    await tester.pumpWidget(plate(fader));
    final gesture = await tester.startGesture(const Offset(200, 311));
    await gesture.moveBy(const Offset(0, -20));
    await gesture.moveBy(const Offset(0, -105));
    await tester.pump();
    // Followed the pointer 125px up: halfway (pan slop doesn't matter,
    // the node keeps the point it was grabbed by).
    expect(value, -21);
    expect(changes.every((v) => (v * 2).roundToDouble() == v * 2), isTrue);
    expect(seen.last.dragging, isTrue);
    await gesture.up();
    await tester.pump();
    expect(ends.last, -21);
    expect(seen.last.dragging, isFalse);
    expect(tester.getCenter(find.text('cap')).dy, closeTo(186, 0.01));
    // Let the double-tap recognizer's timer run out.
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('sideways movement off a line still follows its nearest point', (
    tester,
  ) async {
    value = -48;
    await tester.pumpWidget(plate(fader));
    final gesture = await tester.startGesture(const Offset(200, 311));
    await gesture.moveBy(const Offset(60, -30));
    await gesture.moveBy(const Offset(40, -220));
    await tester.pump();
    expect(value, 6); // past the top: clamped to max
    await gesture.up();
    // Let the double-tap recognizer's timer run out.
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('tapping the track off the node jumps the node there', (
    tester,
  ) async {
    value = -48;
    await tester.pumpWidget(plate(fader));
    // 50px below the top of the throw, outside the node's own box.
    await tester.tapAt(const Offset(200, 111));
    await tester.pump();
    expect(value, closeTo(6 - 54 * 50 / 250, 0.5));
    expect(tester.getCenter(find.text('cap')).dy, closeTo(111, 2));
    // Let the double-tap recognizer's timer run out.
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('without jumpOnTap the track off the node is not hit', (
    tester,
  ) async {
    value = -48;
    await tester.pumpWidget(plate(fader.copyWith(jumpOnTap: false)));
    await tester.tapAt(const Offset(200, 111));
    await tester.pump();
    expect(changes, isEmpty);
    // Let the double-tap recognizer's timer run out.
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('double tap resets to the default and the wheel steps', (
    tester,
  ) async {
    value = -30;
    await tester.pumpWidget(plate(fader));
    await tester.tapAt(Offset(200, tester.getCenter(find.text('cap')).dy));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(Offset(200, tester.getCenter(find.text('cap')).dy));
    await tester.pump(const Duration(milliseconds: 400));
    expect(value, 0);
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(
      pointer.hover(tester.getCenter(find.text('cap'))),
    );
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, -20)));
    await tester.pump();
    expect(value, 0.5);
    // Let the double-tap recognizer's timer run out.
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a changed value from elsewhere moves the node', (tester) async {
    value = -48;
    await tester.pumpWidget(plate(fader));
    expect(tester.getCenter(find.text('cap')).dy, 311);
    value = 6;
    await tester.pumpWidget(plate(fader));
    expect(tester.getCenter(find.text('cap')).dy, 61);
    // Let the double-tap recognizer's timer run out.
    await tester.pump(const Duration(seconds: 1));
  });

  // A tempo knob: a 120px cap turning -135..135 degrees for 30..250 BPM.
  const knob = DragTrackModel(
    shape: DragTrackShape.arc,
    variable: 'bpm',
    min: 30,
    max: 250,
    step: 1,
    defaultValue: 120,
  );

  Matrix4 transformOfCap(WidgetTester tester) {
    final RenderBox box = tester.renderObject(find.text('cap'));
    return box.getTransformTo(null);
  }

  testWidgets('an arc track rotates the node to its value', (tester) async {
    value = 140; // halfway: pointing straight up
    await tester.pumpWidget(
      plate(knob, size: const Size(120, 120), at: const Offset(140, 140)),
    );
    // Top-left corner of an unrotated cap stays put.
    expect(transformOfCap(tester).getTranslation().x, closeTo(140, 0.01));
    value = 250; // +135 degrees
    await tester.pumpWidget(
      plate(knob, size: const Size(120, 120), at: const Offset(140, 140)),
    );
    final Offset topLeft = MatrixUtils.transformPoint(
      transformOfCap(tester),
      Offset.zero,
    );
    // The top-left corner swung around the centre (200, 200).
    expect((topLeft - const Offset(200, 200)).distance, closeTo(84.85, 0.1));
    expect(topLeft.dx, greaterThan(200));
    // Let the double-tap recognizer's timer run out.
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('dragging around an arc turns it by the pointer angle', (
    tester,
  ) async {
    value = 30;
    await tester.pumpWidget(
      plate(knob, size: const Size(120, 120), at: const Offset(140, 140)),
    );
    // Start left of centre (-90 degrees) and go round to the top (0).
    final gesture = await tester.startGesture(const Offset(150, 200));
    for (double a = -90; a <= 0; a += 10) {
      final double r = a * 3.14159265 / 180;
      await gesture.moveTo(Offset(200 + 50 * _sin(r), 200 - 50 * _cos(r)));
    }
    await tester.pump();
    await gesture.up();
    // 90 of the 270 degrees, minus the pan slop eaten before the start.
    expect(value, inInclusiveRange(95, 104));
    // Let the double-tap recognizer's timer run out.
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('vertical input turns a knob by dragging up', (tester) async {
    value = 30;
    await tester.pumpWidget(
      plate(
        knob.copyWith(input: DragTrackInput.vertical, pixelsPerRange: 220),
        size: const Size(120, 120),
        at: const Offset(140, 140),
      ),
    );
    final gesture = await tester.startGesture(const Offset(200, 230));
    await gesture.moveBy(const Offset(0, -30));
    await gesture.moveBy(const Offset(0, -50));
    await tester.pump();
    await gesture.up();
    // 1 BPM per pixel; the first 30px include the pan slop.
    expect(value, inInclusiveRange(30 + 50, 30 + 80));
    // Let the double-tap recognizer's timer run out.
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a stepped arc snaps to its detents', (tester) async {
    value = 0;
    const selector = DragTrackModel(
      shape: DragTrackShape.arc,
      variable: 'voice',
      min: 0,
      max: 4,
      step: 1,
    );
    await tester.pumpWidget(
      plate(selector, size: const Size(100, 100), at: const Offset(150, 150)),
    );
    final gesture = await tester.startGesture(const Offset(150, 200));
    for (double a = -90; a <= 30; a += 10) {
      final double r = a * 3.14159265 / 180;
      await gesture.moveTo(Offset(200 + 45 * _sin(r), 200 - 45 * _cos(r)));
    }
    await gesture.up();
    await tester.pump();
    expect(changes.every((v) => v == v.roundToDouble()), isTrue);
    expect(value, 2); // 120 of 270 degrees: 1.8 detents, snapped to 2
    // Let the double-tap recognizer's timer run out.
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('an orbiting arc moves the node round its pivot', (tester) async {
    value = 1;
    const ring = DragTrackModel(
      shape: DragTrackShape.arc,
      variable: 'p',
      startAngle: 0,
      endAngle: 90,
      pivotY: 100,
      rotate: false,
    );
    await tester.pumpWidget(
      plate(ring, size: const Size(20, 20), at: const Offset(190, 90)),
    );
    // Rest centre (200, 100); pivot (200, 200); turned 90 degrees clockwise.
    expect(
      tester.getCenter(find.text('cap')),
      offsetMoreOrLessEquals(const Offset(300, 200)),
    );
    // Let the double-tap recognizer's timer run out.
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a path track follows the curve and its nearest point', (
    tester,
  ) async {
    value = 0;
    const path = DragTrackModel(
      shape: DragTrackShape.path,
      variable: 'p',
      path: 'M0 0 L100 0 L100 100',
    );
    await tester.pumpWidget(
      plate(path, size: const Size(20, 20), at: const Offset(90, 90)),
    );
    expect(tester.getCenter(find.text('cap')), const Offset(100, 100));
    final gesture = await tester.startGesture(const Offset(100, 100));
    await gesture.moveBy(const Offset(30, 0));
    await gesture.moveTo(const Offset(205, 150));
    await tester.pump();
    await gesture.up();
    // Nearest point is (200, 150): 150 of the 200px path.
    expect(value, closeTo(0.75, 0.01));
    expect(
      tester.getCenter(find.text('cap')),
      offsetMoreOrLessEquals(const Offset(200, 150), epsilon: 1),
    );
    // Let the double-tap recognizer's timer run out.
    await tester.pump(const Duration(seconds: 1));
  });
}

double _sin(double r) => math.sin(r);
double _cos(double r) => math.cos(r);
