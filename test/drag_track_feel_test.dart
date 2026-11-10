import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// How a drag track feels: magnetic step detents, rubber-banding past the
/// ends, gliding to a new value, and the release velocity a deck flings
/// with.
void main() {
  late double value;
  late List<(double, double, double)> releases;
  late void Function(double) setValue;

  // A 200px horizontal throw, 0 to 4 in steps of 1: 50px a step.
  const track = DragTrackModel(
    variable: 'v',
    min: 0,
    max: 4,
    step: 1,
    x2: 200,
    y2: 0,
  );

  Widget plate(DragTrackModel track) => Directionality(
    textDirection: TextDirection.ltr,
    child: StatefulBuilder(
      builder: (context, setState) {
        setValue = (v) => setState(() => value = v);
        return Stack(
          children: [
            Positioned(
              left: 100,
              top: 100,
              width: 20,
              height: 20,
              child: NodeDragTrack(
                track: track,
                value: value,
                onChanged: (v) => setState(() => value = v),
                onRelease: (v, start, velocity) =>
                    releases.add((v, start, velocity)),
                child: const SizedBox.expand(child: Text('cap')),
              ),
            ),
          ],
        );
      },
    ),
  );

  double capX(WidgetTester tester) =>
      tester.getCenter(find.text('cap')).dx - 110;

  setUp(() {
    value = 0;
    releases = [];
  });

  testWidgets('without a detent the node jumps from step to step', (
    tester,
  ) async {
    await tester.pumpWidget(plate(track));
    final g = await tester.startGesture(const Offset(110, 110));
    await g.moveBy(const Offset(20, 0));
    await g.moveBy(const Offset(50, 0));
    await tester.pump();
    expect(value, 1);
    expect(capX(tester), closeTo(50, 0.01));
    await g.up();
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a detent lets the node lean past its step, then settles', (
    tester,
  ) async {
    await tester.pumpWidget(
      plate(
        track.copyWith(
          detent: 0.35,
          settleMs: 200,
          settleCurve: MotionCurve.linear,
        ),
      ),
    );
    final g = await tester.startGesture(const Offset(110, 110));
    await g.moveBy(const Offset(20, 0));
    await g.moveBy(const Offset(50, 0));
    await tester.pump();
    // 70px along: value 1 (50px), drawn 35% of the 20px past it.
    expect(value, 1);
    expect(capX(tester), closeTo(57, 0.01));
    await g.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(capX(tester), closeTo(53.5, 0.1));
    await tester.pump(const Duration(milliseconds: 150));
    expect(capX(tester), closeTo(50, 0.01));
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('overscroll stretches past an end and springs back', (
    tester,
  ) async {
    await tester.pumpWidget(
      plate(track.copyWith(step: 0, overscroll: 0.35, settleMs: 200)),
    );
    final g = await tester.startGesture(const Offset(110, 110));
    await g.moveBy(const Offset(-20, 0));
    await g.moveBy(const Offset(-40, 0));
    await tester.pump();
    // 60px before the start: the value stays at 0, the node 21px out.
    expect(value, 0);
    expect(capX(tester), closeTo(-21, 0.01));
    // Back the other way it follows again from the stretch.
    await g.moveBy(const Offset(80, 0));
    await tester.pump();
    expect(value, closeTo(0.4, 1e-6));
    await g.moveBy(const Offset(-80, 0));
    await tester.pump();
    await g.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // Gliding back (ease out: most of the way already).
    expect(capX(tester), inExclusiveRange(-21, 0));
    await tester.pump(const Duration(milliseconds: 400));
    expect(capX(tester), closeTo(0, 0.01));
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a value set from outside glides there', (tester) async {
    await tester.pumpWidget(
      plate(track.copyWith(settleMs: 200, settleCurve: MotionCurve.linear)),
    );
    setValue(4);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(capX(tester), closeTo(100, 0.5));
    await tester.pump(const Duration(milliseconds: 150));
    expect(capX(tester), closeTo(200, 0.01));
    // Without settleMs it jumps.
    await tester.pumpWidget(plate(track));
    setValue(1);
    await tester.pump();
    expect(capX(tester), closeTo(50, 0.01));
  });

  testWidgets('letting go reports the start value and the velocity', (
    tester,
  ) async {
    await tester.pumpWidget(plate(track.copyWith(step: 0)));
    // Flung right at 1000 px/s: 20 values per second on a 200px/4 throw.
    await tester.fling(find.text('cap'), const Offset(60, 0), 1000);
    await tester.pump(const Duration(seconds: 1));
    expect(releases, hasLength(1));
    final (v, start, velocity) = releases.single;
    expect(start, 0);
    expect(v, greaterThan(0.5));
    expect(velocity, closeTo(20, 2));
  });
}
