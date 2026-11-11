import 'dart:math' as math;

import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/src/runtime/gestures/physics.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// The physics every gesture shares: springs, friction flings, rubber bands,
/// bounds and velocity-projected snapping.
void main() {
  group('springOf', () {
    test('bounce and duration use withDurationAndBounce', () {
      final spring = springOf(const api.GesturePhysics(bounce: 0.3, duration: 300));
      const double k = 4 * math.pi * math.pi / (0.3 * 0.3);
      expect(spring.stiffness, closeTo(k, 1e-6));
      expect(spring.damping, closeTo(0.7 * 2 * math.sqrt(k), 1e-6));
      // The API's numbers are the same as Flutter's.
      const api.GesturePhysics model = api.GesturePhysics(bounce: 0.3, duration: 300);
      expect(model.effectiveStiffness, closeTo(spring.stiffness, 1e-6));
      expect(model.effectiveDamping, closeTo(spring.damping, 1e-6));
    });

    test('a plain spring keeps its stiffness, damping and mass', () {
      final spring = springOf(
        const api.GesturePhysics(stiffness: 200, damping: 30, mass: 2),
      );
      expect(spring.stiffness, 200);
      expect(spring.damping, 30);
      expect(spring.mass, 2);
    });
  });

  group('rubberBand', () {
    test('passes values inside the range', () {
      expect(rubberBand(50, 0, 100, 0.5), 50);
    });

    test('stretches less and less past an end', () {
      final double a = rubberBand(150, 0, 100, 0.5) - 100;
      final double b = rubberBand(300, 0, 100, 0.5) - 100;
      expect(a, greaterThan(0));
      expect(a, lessThan(50));
      expect(b, greaterThan(a));
      // Each extra pixel pulled moves it less: 50px in gives more per
      // pixel than the next 150px.
      expect((b - a) / 150, lessThan(a / 50));
      expect(rubberBand(-50, 0, 100, 0.5), lessThan(0));
    });

    test('0 stops dead and 1 follows freely', () {
      expect(rubberBand(150, 0, 100, 0), 100);
      expect(rubberBand(150, 0, 100, 1), 150);
    });
  });

  group('boundsRange', () {
    test('contain keeps a small box inside', () {
      // A 100 wide box centered at 50 in a 0..300 view may move 0..200.
      final (lo, hi) = boundsRange(
        bounds: api.GestureBounds.contain,
        center: 50,
        half: 50,
        viewLo: 0,
        viewHi: 300,
      );
      expect(lo, 0);
      expect(hi, 200);
    });

    test('cover keeps a big box covering the view', () {
      // A 600 wide box centered at 150 over a 0..300 view.
      final (lo, hi) = boundsRange(
        bounds: api.GestureBounds.cover,
        center: 150,
        half: 300,
        viewLo: 0,
        viewHi: 300,
      );
      expect(lo, -150);
      expect(hi, 150);
    });

    test('cover centers a box too small to cover', () {
      final (lo, hi) = boundsRange(
        bounds: api.GestureBounds.cover,
        center: 20,
        half: 20,
        viewLo: 0,
        viewHi: 300,
      );
      expect(lo, 130);
      expect(hi, 130);
    });

    test('contain acts like cover when the box is bigger', () {
      final (lo, hi) = boundsRange(
        bounds: api.GestureBounds.contain,
        center: 150,
        half: 300,
        viewLo: 0,
        viewHi: 300,
      );
      expect((lo, hi), (-150, 150));
    });

    test('none is unbounded', () {
      final (lo, hi) = boundsRange(
        bounds: api.GestureBounds.none,
        center: 0,
        half: 1,
        viewLo: 0,
        viewHi: 1,
      );
      expect(lo, double.negativeInfinity);
      expect(hi, double.infinity);
    });
  });

  group('AxisSettleSimulation', () {
    const api.GesturePhysics physics = api.GesturePhysics();

    test('a fling coasts by friction to x − v / ln(drag)', () {
      final sim = AxisSettleSimulation.release(
        physics: physics,
        position: 0,
        velocity: 1000,
      );
      final double expected = -1000 / math.log(physics.frictionDrag);
      expect(sim.finalX, closeTo(expected, 0.5));
      expect(sim.x(0.1), greaterThan(0));
      expect(sim.dx(0.5), lessThan(sim.dx(0.1))); // slowing down
      expect(sim.isDone(30), isTrue);
      expect(sim.x(30), closeTo(expected, 1));
    });

    test('a fling that would leave the range springs back at its end', () {
      final sim = AxisSettleSimulation.release(
        physics: physics,
        position: 0,
        velocity: 3000,
        lo: -100,
        hi: 100,
      );
      double furthest = 0;
      for (double t = 0; t < 3; t += 1 / 120) {
        furthest = math.max(furthest, sim.x(t));
      }
      // It overshoots the end by the spring, then settles on it.
      expect(furthest, greaterThan(100));
      expect(sim.isDone(5), isTrue);
      expect(sim.x(5), closeTo(100, 0.05));
    });

    test('a release past an end springs to it', () {
      final sim = AxisSettleSimulation.release(
        physics: physics,
        position: 160,
        velocity: 0,
        lo: 0,
        hi: 100,
      );
      expect(sim.x(5), closeTo(100, 0.05));
    });

    test('a slow release or no fling stays', () {
      expect(
        AxisSettleSimulation.release(
          physics: physics,
          position: 40,
          velocity: 10,
        ).isDone(0),
        isTrue,
      );
      expect(
        AxisSettleSimulation.release(
          physics: const api.GesturePhysics(fling: false),
          position: 40,
          velocity: 4000,
        ).x(1),
        40,
      );
    });

    test('a spring keeps its release velocity', () {
      final sim = AxisSettleSimulation.spring(
        physics: physics,
        position: 0,
        velocity: 2000,
        target: 0,
      );
      // Thrown away from the target, it first moves on, then returns.
      expect(sim.x(0.02), greaterThan(0));
      expect(sim.x(5), closeTo(0, 0.05));
    });
  });

  group('snapTargetOf', () {
    const api.GesturePhysics sheet = api.GesturePhysics(
      snap: api.GestureSnap(
        points: [api.Offset.zero, api.Offset(0, -280), api.Offset(0, -560)],
      ),
    );

    test('without velocity the nearest point wins', () {
      final target = snapTargetOf(
        physics: sheet,
        position: const Offset(0, -200),
        velocity: Offset.zero,
        axis: api.DragAxis.vertical,
      )!;
      expect(target.index, 1);
      expect(target.offset, const Offset(0, -280));
    });

    test('a flick goes one stop, a hard throw skips to the far one', () {
      final flick = snapTargetOf(
        physics: sheet,
        position: const Offset(0, -20),
        velocity: const Offset(0, -500),
        axis: api.DragAxis.vertical,
      )!;
      expect(flick.index, 1);
      final throwUp = snapTargetOf(
        physics: sheet,
        position: const Offset(0, -20),
        velocity: const Offset(0, -2500),
        axis: api.DragAxis.vertical,
      )!;
      expect(throwUp.index, 2);
      // A throw down from the top goes back to closed.
      final throwDown = snapTargetOf(
        physics: sheet,
        position: const Offset(0, -560),
        velocity: const Offset(0, 3000),
        axis: api.DragAxis.vertical,
      )!;
      expect(throwDown.index, 0);
    });

    test('without projection the release point decides', () {
      final target = snapTargetOf(
        physics: const api.GesturePhysics(
          snap: api.GestureSnap(
            points: [api.Offset.zero, api.Offset(0, -280)],
            projectVelocity: false,
          ),
        ),
        position: const Offset(0, -20),
        velocity: const Offset(0, -5000),
        axis: api.DragAxis.vertical,
      )!;
      expect(target.index, 0);
    });

    test('a grid rounds each axis', () {
      final target = snapTargetOf(
        physics: const api.GesturePhysics(
          fling: false,
          snap: api.GestureSnap(kind: api.SnapKind.grid, gridX: 50, gridY: 40),
        ),
        position: const Offset(73, 18),
        velocity: Offset.zero,
      )!;
      expect(target.offset, const Offset(50, 0));
      expect(target.index, -1);
    });

    test('edges dock to the nearest corner', () {
      final target = snapTargetOf(
        physics: const api.GesturePhysics(
          fling: false,
          snap: api.GestureSnap(kind: api.SnapKind.edges),
        ),
        position: const Offset(250, 20),
        velocity: Offset.zero,
        edges: const Rect.fromLTRB(-10, -10, 290, 590),
      )!;
      expect(target.offset, const Offset(290, -10));
    });

    test('targets are kept inside the range', () {
      final target = snapTargetOf(
        physics: const api.GesturePhysics(
          snap: api.GestureSnap(points: [api.Offset(0, -900)]),
        ),
        position: Offset.zero,
        velocity: Offset.zero,
        range: const Rect.fromLTRB(0, -560, 0, 0),
        axis: api.DragAxis.vertical,
      )!;
      expect(target.offset.dy, -560);
    });

    test('no snap, no target', () {
      expect(
        snapTargetOf(
          physics: const api.GesturePhysics(),
          position: Offset.zero,
          velocity: Offset.zero,
        ),
        isNull,
      );
    });
  });
}
