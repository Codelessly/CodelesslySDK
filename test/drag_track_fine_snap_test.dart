import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Darkroom's knobs: detents that click into place, a fine mode (Shift, or
/// press and hold before dragging) with a FINE lamp, knobs that turn inside
/// a scrolling page, and curved sliders whose thumbs jump to a tap on their
/// arc.
void main() {
  late double value;
  late List<bool> fines;
  late List<TrackValues> seen;

  setUp(() {
    value = 20;
    fines = [];
    seen = [];
  });

  /// A [size] node with [track] at (180, 180) in a 400x400 box, optionally
  /// inside a vertical scroll view 2000px tall.
  Widget host(
    DragTrackModel track, {
    bool scroll = false,
    Size size = const Size(40, 40),
  }) {
    final Widget plate = StatefulBuilder(
      builder: (context, setState) => SizedBox(
        width: 400,
        height: scroll ? 2000 : 400,
        child: Stack(
          children: [
            Positioned(
              left: 180,
              top: 180,
              width: size.width,
              height: size.height,
              child: NodeDragTrack(
                track: track,
                value: value,
                onChanged: (v) => setState(() => value = v),
                onFine: fines.add,
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
    );
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 400,
          height: 400,
          child: scroll ? SingleChildScrollView(child: plate) : plate,
        ),
      ),
    );
  }

  // The temperature knob: 16–28°C in 0.5°C detents (16px each), 0.1°C fine
  // steps (10px each), dragged up and down.
  const temp = DragTrackModel(
    shape: DragTrackShape.arc,
    variable: 'temp',
    min: 16,
    max: 28,
    step: 0.5,
    input: DragTrackInput.vertical,
    pixelsPerRange: 24 * 16,
    fineStep: 0.1,
    finePixelsPerRange: 120 * 10,
    fineVariable: 'tempFine',
    defaultValue: 20,
  );

  testWidgets(
    'a vertical knob inside a scroll view turns instead of scrolling',
    (tester) async {
      await tester.pumpWidget(host(temp, scroll: true));
      final ScrollableState scroll = tester.state(find.byType(Scrollable));
      await tester.drag(find.text('cap'), const Offset(0, -64), touchSlopY: 0);
      await tester.pumpAndSettle();
      expect(value, greaterThan(20));
      expect(
        (value * 2).roundToDouble(),
        value * 2,
        reason: 'snapped to 0.5° detents',
      );
      expect(scroll.position.pixels, 0);
    },
  );

  testWidgets(
    'press and hold, then drag: fine steps, the fine variable and track.fine',
    (tester) async {
      await tester.pumpWidget(host(temp));
      final TestGesture g = await tester.startGesture(
        tester.getCenter(find.text('cap')),
      );
      await tester.pump(const Duration(milliseconds: 450));
      expect(fines, [true]);
      expect(seen.last.fine, isTrue);
      for (int i = 0; i < 3; i++) {
        await g.moveBy(const Offset(0, -10));
        await tester.pump();
      }
      // 30px up in fine mode: three 0.1° steps (the first move's slop aside).
      expect(value, closeTo(20.2, 0.11));
      expect(value * 10, closeTo((value * 10).roundToDouble(), 1e-9));
      await g.up();
      await tester.pump();
      expect(fines.last, isFalse);
      expect(seen.last.fine, isFalse);
    },
  );

  testWidgets('Shift turns fine mode on while dragging', (tester) async {
    await tester.pumpWidget(host(temp));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    final TestGesture g = await tester.startGesture(
      tester.getCenter(find.text('cap')),
    );
    await g.moveBy(const Offset(0, -5));
    await g.moveBy(const Offset(0, -20));
    await tester.pump();
    expect(fines.first, isTrue);
    expect(value - 20, lessThan(0.5), reason: 'fine steps, not detents');
    expect(value, greaterThan(20));
    await g.up();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    // Let the double-tap recognizer's timer run out.
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('Shift + wheel steps by the fine step', (tester) async {
    await tester.pumpWidget(host(temp));
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(
      pointer.hover(tester.getCenter(find.text('cap'))),
    );
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, -20)));
    await tester.pump();
    expect(value, 20.5);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, -20)));
    await tester.pump();
    expect(value, closeTo(20.6, 1e-9));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  });

  testWidgets('snapMs animates the knob to a new detent', (tester) async {
    const knob = DragTrackModel(
      shape: DragTrackShape.arc,
      variable: 'temp',
      min: 16,
      max: 28,
      step: 0.5,
      snapMs: 120,
      snapCurve: 'easeOut',
    );
    await tester.pumpWidget(host(knob));
    Matrix4 transformOf() {
      final RenderBox box = tester.renderObject(find.text('cap'));
      return box.getTransformTo(null);
    }

    final Matrix4 before = transformOf();
    value = 28; // Changed elsewhere: turns 135° - 0° ... in 120 ms.
    await tester.pumpWidget(host(knob));
    await tester.pump(const Duration(milliseconds: 40));
    final Matrix4 mid = transformOf();
    await tester.pump(const Duration(milliseconds: 200));
    final Matrix4 after = transformOf();
    expect(mid, isNot(equals(before)));
    expect(mid, isNot(equals(after)));
  });

  testWidgets('tapping a curved slider\'s arc jumps its orbiting thumb there', (
    tester,
  ) async {
    // A thumb orbiting a point 100px below it, -60° to 60°, 15–120 s.
    const every = DragTrackModel(
      shape: DragTrackShape.arc,
      variable: 'every',
      min: 15,
      max: 120,
      step: 15,
      startAngle: -60,
      endAngle: 60,
      pivotX: 0,
      pivotY: 100,
      rotate: false,
      jumpOnTap: true,
    );
    value = 15;
    await tester.pumpWidget(host(every, size: const Size(20, 20)));
    // The pivot is at (190, 290); a tap up and to the right of it, at 45°.
    await tester.tapAt(const Offset(190 + 70.7, 290 - 70.7));
    await tester.pump(const Duration(milliseconds: 400));
    // 45° of -60..60 is 0.875 of the way: 15 + 0.875 * 105 = 106.9 → 105.
    expect(value, 105);
  });
}
