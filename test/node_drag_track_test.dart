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

  testWidgets(
    'a knob inside a draggable and a scroll view turns instead of dragging or scrolling',
    (tester) async {
      value = 50;
      const knob = DragTrackModel(
        variable: 'gain',
        shape: DragTrackShape.arc,
        min: 0,
        max: 100,
        step: 1,
        startAngle: -150,
        endAngle: 150,
        input: DragTrackInput.vertical,
        pixelsPerRange: 160,
      );
      bool dragStarted = false;
      final ScrollController scroll = ScrollController();
      addTearDown(scroll.dispose);
      for (final PointerDeviceKind kind in [
        PointerDeviceKind.mouse,
        PointerDeviceKind.touch,
      ]) {
        value = 50;
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: MediaQuery(
              data: const MediaQueryData(),
              child: Overlay(
                initialEntries: [
                  OverlayEntry(
                    builder: (context) => SingleChildScrollView(
                      controller: scroll,
                      child: SizedBox(
                        height: 2000,
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Draggable<String>(
                            data: 'pedal',
                            onDragStarted: () => dragStarted = true,
                            feedback: const SizedBox(width: 10, height: 10),
                            child: SizedBox(
                              width: 200,
                              height: 200,
                              child: Center(
                                child: SizedBox(
                                  width: 40,
                                  height: 40,
                                  child: StatefulBuilder(
                                    builder: (context, setState) =>
                                        NodeDragTrack(
                                          track: knob,
                                          value: value,
                                          onChanged: (v) =>
                                              setState(() => value = v),
                                          onEnd: ends.add,
                                          child: const SizedBox.expand(),
                                        ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        final gesture = await tester.startGesture(
          const Offset(100, 100),
          kind: kind,
        );
        for (int i = 0; i < 8; i++) {
          await gesture.moveBy(const Offset(0, -5));
          await tester.pump();
        }
        await gesture.up();
        await tester.pump(const Duration(seconds: 1));
        // 40px up of 160px for the whole range: a quarter more, less the
        // slop it took to claim the pointer.
        expect(value, greaterThan(60), reason: '$kind');
        expect(dragStarted, isFalse, reason: '$kind');
        expect(scroll.offset, 0, reason: '$kind');
      }
    },
  );

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

  testWidgets('tapping round a dial jumps its needle to that angle', (
    tester,
  ) async {
    // A month dial: January at the top, December at 330 degrees.
    value = 1;
    const dial = DragTrackModel(
      shape: DragTrackShape.arc,
      variable: 'month',
      min: 1,
      max: 12,
      step: 1,
      startAngle: 0,
      endAngle: 330,
      pivotY: 100,
      rotate: true,
      jumpOnTap: true,
    );
    await tester.pumpWidget(
      plate(dial, size: const Size(20, 20), at: const Offset(190, 90)),
    );
    // Rest centre (200, 100), pivot (200, 200): tap east of the pivot, at
    // 90 degrees, which is April.
    await tester.tapAt(const Offset(300, 200));
    await tester.pump();
    expect(value, 4);
    expect(
      tester.getCenter(find.text('cap')),
      offsetMoreOrLessEquals(const Offset(300, 200), epsilon: 1),
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

  testWidgets('a relative line is measured in the node\'s own size', (
    tester,
  ) async {
    // A full-width transparent thumb (300 wide) whose track runs one width
    // to the right: it scrubs across whatever width it is laid out at.
    const scrubber = DragTrackModel(
      variable: 'minute',
      min: 0,
      max: 1440,
      step: 5,
      x2: 1,
      y2: 0,
      relative: true,
      jumpOnTap: true,
    );
    value = 720;
    await tester.pumpWidget(
      plate(scrubber, size: const Size(300, 20), at: const Offset(0, 300)),
    );
    // Rest centre (150, 310), moved half of its 300px width.
    expect(tester.getCenter(find.text('cap')), const Offset(300, 310));
    value = 0;
    await tester.pumpWidget(
      plate(scrubber, size: const Size(300, 20), at: const Offset(0, 300)),
    );
    // Tapped 200px right of the rest centre, off the node: two thirds.
    await tester.tapAt(const Offset(350, 310));
    await tester.pump();
    expect(value, 960);
    // Let the double-tap recognizer's timer run out.
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('tapping round an orbiting dial jumps the knob there', (
    tester,
  ) async {
    // A 24-hour dial: the knob rests at the top, a full turn is 1440.
    const dial = DragTrackModel(
      shape: DragTrackShape.arc,
      variable: 'minute',
      min: 0,
      max: 1440,
      step: 5,
      startAngle: 0,
      endAngle: 360,
      pivotY: 100,
      jumpOnTap: true,
    );
    value = 0;
    await tester.pumpWidget(
      plate(dial, size: const Size(20, 20), at: const Offset(190, 90)),
    );
    // Pivot (200, 200): tapping straight right of it is a quarter turn,
    // straight left three quarters.
    await tester.tapAt(const Offset(300, 200));
    await tester.pump();
    expect(value, 360);
    await tester.pump(const Duration(seconds: 1));
    await tester.tapAt(const Offset(100, 200));
    await tester.pump();
    expect(value, 1080);
    await tester.pump(const Duration(seconds: 1));
  });

  test('a partial arc takes taps outside it to the nearer end', () {
    final g = DragTrackGeometry(
      const DragTrackModel(
        shape: DragTrackShape.arc,
        variable: 'v',
        startAngle: -135,
        endAngle: 135,
      ),
    );
    expect(
      g.progressAtAngle(g.angleOf(const Offset(0, -10)))!,
      closeTo(0.5, 1e-9),
    );
    expect(
      g.progressAtAngle(g.angleOf(const Offset(10, 0)))!,
      closeTo(225 / 270, 1e-9),
    );
    // Straight down is in the 90° gap; just left of it is nearer the start.
    expect(g.progressAtAngle(g.angleOf(const Offset(-1, 10)))!, 0);
    expect(g.progressAtAngle(g.angleOf(const Offset(1, 10)))!, 1);
  });

  testWidgets('a relative line is posed by its size on the design canvas', (
    tester,
  ) async {
    const scrubber = DragTrackModel(
      variable: 'minute',
      min: 0,
      max: 1440,
      x2: 1,
      y2: 0,
      relative: true,
    );
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              width: 300,
              height: 20,
              child: TrackPose(
                track: scrubber,
                progress: 0.25,
                child: SizedBox.expand(child: Text('thumb')),
              ),
            ),
          ],
        ),
      ),
    );
    // A quarter of its 300px width to the right of its rest centre.
    expect(tester.getCenter(find.text('thumb')), const Offset(225, 10));
  });

  testWidgets('a relative scrub area maps a tap to that fraction across', (
    tester,
  ) async {
    // A 300-wide scrub area on a track from half a width left to half a
    // width right of its centre: its centre (where a knob sits) is at the
    // value's fraction across, and a tap 3/4 across jumps to 3/4.
    const scrubber = DragTrackModel(
      variable: 'minute',
      min: 0,
      max: 1440,
      step: 5,
      x1: -0.5,
      x2: 0.5,
      y2: 0,
      relative: true,
      jumpOnTap: true,
    );
    value = 360;
    await tester.pumpWidget(
      plate(scrubber, size: const Size(300, 20), at: const Offset(0, 300)),
    );
    expect(tester.getCenter(find.text('cap')), const Offset(75, 310));
    await tester.tapAt(const Offset(225, 310));
    await tester.pump();
    expect(value, 1080);
    expect(tester.getCenter(find.text('cap')), const Offset(225, 310));
    await tester.pump(const Duration(seconds: 1));
  });
}

double _sin(double r) => math.sin(r);
double _cos(double r) => math.cos(r);
