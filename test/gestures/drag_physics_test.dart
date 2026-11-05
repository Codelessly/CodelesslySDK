import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// [NodeDrag] with [DragModel.physics]: flings, springs, snap points,
/// bounds and overscroll. A 100×100 node laid out at (150, 450) in a
/// 400×600 parent.
void main() {
  late List<Map<String, dynamic>> ends;

  Future<void> pump(WidgetTester tester, DragModel drag) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 400,
            height: 600,
            child: Stack(
              children: [
                Positioned(
                  left: 150,
                  top: 450,
                  width: 100,
                  height: 100,
                  child: NodeDrag(
                    nodeId: 'n',
                    drag: drag,
                    onEnd: ends.add,
                    child: const ColoredBox(color: Color(0xFF00AA66)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  setUp(() => ends = []);

  Offset offsetOf(WidgetTester tester) =>
      tester.state<NodeDragState>(find.byType(NodeDrag)).values.offset;

  const DragModel sheet = DragModel(
    axis: DragAxis.vertical,
    release: DragRelease.stay,
    minY: -400,
    maxY: 0,
    physics: PhysicsModel(
      snap: SnapModel(
        points: [SnapPoint(), SnapPoint(y: -200), SnapPoint(y: -400)],
      ),
    ),
  );

  group('bottom sheet with three snap points', () {
    testWidgets('a slow drag settles on the nearest stop', (tester) async {
      await pump(tester, sheet);
      final TestGesture g = await tester.startGesture(const Offset(200, 500));
      for (int i = 0; i < 15; i++) {
        await g.moveBy(const Offset(0, -10));
        await tester.pump(const Duration(milliseconds: 100));
      }
      await g.up();
      expect(ends.single['snapIndex'], 1);
      expect(ends.single['targetY'], -200);
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        tester.state<NodeDragState>(find.byType(NodeDrag)).values.settling,
        isTrue,
      );
      await tester.pumpAndSettle();
      expect(offsetOf(tester).dy, closeTo(-200, 0.01));
      expect(offsetOf(tester).dx, 0);
    });

    testWidgets('velocity picks the stop: a flick one, a throw two', (
      tester,
    ) async {
      await pump(tester, sheet);
      // A friction fling at 400px/s coasts about 200px: one stop, though
      // the finger only went 80px.
      await tester.flingFrom(const Offset(200, 500), const Offset(0, -80), 400);
      await tester.pumpAndSettle();
      expect((ends.last['velocityY'] as double).abs(), greaterThan(300));
      expect(ends.last['snapIndex'], 1);
      expect(offsetOf(tester).dy, closeTo(-200, 0.01));

      // Grabbed where it is drawn now, 200px up.
      await tester.flingFrom(
        const Offset(200, 300),
        const Offset(0, 100),
        3000,
      );
      await tester.pumpAndSettle();
      expect(ends.last['snapIndex'], 0);

      await tester.flingFrom(
        const Offset(200, 500),
        const Offset(0, -100),
        3000,
      );
      await tester.pumpAndSettle();
      expect(ends.last['snapIndex'], 2);
      expect(offsetOf(tester).dy, closeTo(-400, 0.01));
    });

    testWidgets('past its limits the sheet stretches like a rubber band', (
      tester,
    ) async {
      await pump(tester, sheet);
      final TestGesture g = await tester.startGesture(const Offset(200, 500));
      for (int i = 0; i < 10; i++) {
        await g.moveBy(const Offset(0, 20));
        await tester.pump(const Duration(milliseconds: 16));
      }
      final double held = offsetOf(tester).dy;
      // Pulled 200px down past its closed stop: it gives, but not all.
      expect(held, greaterThan(0));
      expect(held, lessThan(150));
      await g.up();
      await tester.pumpAndSettle();
      expect(offsetOf(tester).dy, closeTo(0, 0.01));
    });

    testWidgets('a vertical drag ignores sideways moves', (tester) async {
      await pump(tester, sheet);
      await tester.dragFrom(const Offset(200, 500), const Offset(80, -150));
      await tester.pumpAndSettle();
      expect(offsetOf(tester).dx, 0);
    });
  });

  testWidgets('a puck flings by friction and stops at its parent\'s edge', (
    tester,
  ) async {
    await pump(
      tester,
      const DragModel(
        release: DragRelease.stay,
        bounds: GestureBounds.contain,
        physics: PhysicsModel(friction: 0.6, overscroll: 0),
      ),
    );
    await tester.flingFrom(const Offset(200, 500), const Offset(-60, 0), 2000);
    expect(ends.single['velocityX'] as double, lessThan(-1000));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    final double early = offsetOf(tester).dx;
    expect(early, lessThan(-60)); // kept going
    await tester.pumpAndSettle();
    // The left edge of the parent is 150px from where it rests.
    expect(offsetOf(tester).dx, closeTo(-150, 0.01));
  });

  testWidgets('a fling inside its bounds coasts to where friction stops it', (
    tester,
  ) async {
    const PhysicsModel physics = PhysicsModel(friction: 0.9);
    await pump(
      tester,
      const DragModel(release: DragRelease.stay, physics: physics),
    );
    await tester.flingFrom(const Offset(200, 500), const Offset(20, 0), 500);
    final double released = ends.single['dx'] as double;
    final double velocity = ends.single['velocityX'] as double;
    await tester.pumpAndSettle();
    expect(
      offsetOf(tester).dx,
      closeTo(physics.projectFling(released, velocity), 1),
    );
    expect(ends.single['targetX'], closeTo(offsetOf(tester).dx, 1));
  });

  testWidgets('snap back with physics springs home with the release speed', (
    tester,
  ) async {
    await pump(
      tester,
      const DragModel(physics: PhysicsModel(bounce: 0.4, durationMs: 500)),
    );
    await tester.flingFrom(const Offset(200, 500), const Offset(60, 0), 1500);
    double furthest = 0;
    for (int i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      final double dx = offsetOf(tester).dx;
      if (dx < furthest) furthest = dx;
    }
    // A bouncy spring overshoots rest on the way back.
    expect(furthest, lessThan(0));
    await tester.pumpAndSettle();
    expect(offsetOf(tester), Offset.zero);
  });

  testWidgets('without physics a drag still snaps back on its curve', (
    tester,
  ) async {
    await pump(tester, const DragModel(snapBackMs: 300));
    await tester.dragFrom(const Offset(200, 500), const Offset(80, 0));
    await tester.pump(const Duration(milliseconds: 150));
    expect(offsetOf(tester).dx, greaterThan(0));
    await tester.pumpAndSettle();
    expect(offsetOf(tester).dx, closeTo(0, 0.01));
    expect(ends.single.containsKey('snapIndex'), isFalse);
  });
}
