import 'dart:math' as math;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// [NodeTransformGesture] on its own: a 200×200 box laid out at (100, 100)
/// in a 400×400 parent, so global and parent coordinates are the same.
void main() {
  late List<Map<String, dynamic>> changes;
  late List<Map<String, dynamic>> ends;
  late List<TransformPose> poses;

  Future<void> pump(
    WidgetTester tester,
    TransformGestureModel model, {
    Map<String, double> given = const {},
    bool selected = true,
    VoidCallback? onSelect,
  }) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 400,
            height: 400,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 100,
                  top: 100,
                  width: 200,
                  height: 200,
                  child: NodeTransformGesture(
                    model: model,
                    given: given,
                    selected: selected,
                    onSelect: onSelect,
                    onPose: poses.add,
                    onChanged: changes.add,
                    onEnd: ends.add,
                    child: const ColoredBox(color: Color(0xFF3366FF)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    // Handles are placed once the node's size is known.
    await tester.pump();
  }

  setUp(() {
    changes = [];
    ends = [];
    poses = [];
  });

  TransformPose poseOf(WidgetTester tester) => tester
      .state<NodeTransformGestureState>(find.byType(NodeTransformGesture))
      .pose;

  /// Moves two fingers from (a1, a2) to (b1, b2) in [steps], then lifts
  /// them unless [lift] is false.
  Future<(TestGesture, TestGesture)> twoFingers(
    WidgetTester tester,
    Offset a1,
    Offset a2,
    Offset b1,
    Offset b2, {
    int steps = 12,
    bool lift = true,
  }) async {
    final TestGesture g1 = await tester.startGesture(a1, pointer: 1);
    final TestGesture g2 = await tester.startGesture(a2, pointer: 2);
    await tester.pump();
    for (int i = 1; i <= steps; i++) {
      final double t = i / steps;
      await g1.moveTo(Offset.lerp(a1, b1, t)!);
      await g2.moveTo(Offset.lerp(a2, b2, t)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    if (lift) {
      await g1.up();
      await g2.up();
    }
    return (g1, g2);
  }

  testWidgets('a pinch zooms around the point between the fingers', (
    tester,
  ) async {
    await pump(tester, const TransformGestureModel(bounds: GestureBounds.none));
    // Spread from 50 to 100 apart around (150, 150): 2× there.
    await twoFingers(
      tester,
      const Offset(125, 150),
      const Offset(175, 150),
      const Offset(100, 150),
      const Offset(200, 150),
    );
    await tester.pumpAndSettle();
    final TransformPose pose = poseOf(tester);
    expect(pose.scale, closeTo(2, 0.02));
    // The point under the fingers stays put: (150, 150) is 50px up-left of
    // the centre, so at 2× the centre moves 50px down-right. (The fingers
    // move one event at a time, so the focal point wobbles by half a step,
    // about 1px, which the zoom doubles.)
    expect(pose.x, closeTo(50, 2.5));
    expect(pose.y, closeTo(50, 2.5));
    expect(changes.last['gesture'], anyOf('pinch', 'fling'));
    expect(changes.any((c) => c['pointerCount'] == 2), isTrue);
    expect(ends, isNotEmpty);
    expect(poses.last.scale, closeTo(2, 0.02));
  });

  testWidgets('past maxScale the zoom rubber-bands and springs back', (
    tester,
  ) async {
    await pump(
      tester,
      const TransformGestureModel(maxScale: 2, bounds: GestureBounds.none),
    );
    final (g1, g2) = await twoFingers(
      tester,
      const Offset(180, 200),
      const Offset(220, 200),
      const Offset(80, 200),
      const Offset(320, 200),
      lift: false,
    );
    // 6× asked, held back short of it but past 2.
    final double held = poseOf(tester).scale;
    expect(held, greaterThan(2));
    expect(held, lessThan(6));
    await g1.up();
    await g2.up();
    await tester.pumpAndSettle();
    expect(poseOf(tester).scale, closeTo(2, 0.01));
  });

  testWidgets('a double tap zooms to the tapped point, another zooms out', (
    tester,
  ) async {
    await pump(
      tester,
      const TransformGestureModel(
        target: TransformTarget.content,
        pan: TransformPan.whenZoomed,
      ),
    );
    Future<void> doubleTap(Offset at) async {
      await tester.tapAt(at);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(at);
      await tester.pumpAndSettle();
    }

    await doubleTap(const Offset(200, 200));
    expect(poseOf(tester).scale, closeTo(2.5, 0.01));
    expect(poseOf(tester).x, closeTo(0, 0.5));
    expect(changes.any((c) => c['gesture'] == 'doubleTap'), isTrue);
    await doubleTap(const Offset(200, 200));
    expect(poseOf(tester).scale, closeTo(1, 0.01));
  });

  testWidgets('cover bounds: a zoomed photo pans to its edge and no further', (
    tester,
  ) async {
    await pump(
      tester,
      const TransformGestureModel(
        target: TransformTarget.content,
        pan: TransformPan.whenZoomed,
        doubleTapScale: 2,
      ),
    );
    // At rest one finger doesn't pan.
    await tester.dragFrom(const Offset(200, 200), const Offset(80, 0));
    await tester.pumpAndSettle();
    expect(poseOf(tester).x, 0);

    // Zoom 2× in the middle, then pull far right.
    await tester.tapAt(const Offset(200, 200));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(const Offset(200, 200));
    await tester.pumpAndSettle();
    final TestGesture g = await tester.startGesture(const Offset(150, 200));
    for (int i = 0; i < 20; i++) {
      await g.moveBy(const Offset(15, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    // 300px asked; the edge is 100px away: held back past it.
    final double held = poseOf(tester).x;
    expect(held, greaterThan(100));
    expect(held, lessThan(300));
    await g.up();
    await tester.pumpAndSettle();
    expect(poseOf(tester).x, closeTo(100, 0.1));
    expect(poseOf(tester).y, closeTo(0, 0.1));
  });

  testWidgets('contain keeps a sticker inside its parent', (tester) async {
    await pump(
      tester,
      const TransformGestureModel(
        bounds: GestureBounds.contain,
        physics: PhysicsModel(fling: false),
      ),
    );
    await tester.dragFrom(const Offset(200, 200), const Offset(-250, 0));
    await tester.pumpAndSettle();
    // The box's left edge stops at the parent's: 100px from where it was.
    expect(poseOf(tester).x, closeTo(-100, 0.1));
  });

  testWidgets('a release flings on by friction and slows to a stop', (
    tester,
  ) async {
    await pump(tester, const TransformGestureModel(bounds: GestureBounds.none));
    await tester.flingFrom(const Offset(200, 200), const Offset(100, 0), 1500);
    await tester.pump();
    final double released = poseOf(tester).x;
    await tester.pump(const Duration(milliseconds: 100));
    final double a = poseOf(tester).x;
    await tester.pump(const Duration(milliseconds: 100));
    final double b = poseOf(tester).x;
    expect(a, greaterThan(released));
    expect(b - a, lessThan(a - released)); // slowing down
    await tester.pumpAndSettle();
    expect(poseOf(tester).x, greaterThan(200));
    expect(ends.last['gesture'], 'fling');
  });

  testWidgets('ctrl + wheel zooms around the pointer; a plain wheel does not', (
    tester,
  ) async {
    await pump(tester, const TransformGestureModel(bounds: GestureBounds.none));
    final TestPointer mouse = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(mouse.hover(const Offset(200, 200)));
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, -100)));
    await tester.pump();
    expect(poseOf(tester).scale, 1);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, -100)));
    await tester.pump();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(poseOf(tester).scale, closeTo(math.exp(100 / 300), 0.001));
    // Around the pointer, which was at the centre: no shift.
    expect(poseOf(tester).x, closeTo(0, 0.01));
    await tester.pump(const Duration(milliseconds: 300));
    expect(ends.last['gesture'], 'wheel');
  });

  testWidgets('wheel: zoom zooms without a modifier, pan pans', (tester) async {
    await pump(
      tester,
      const TransformGestureModel(
        bounds: GestureBounds.none,
        wheel: WheelZoom.pan,
      ),
    );
    final TestPointer mouse = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(mouse.hover(const Offset(200, 200)));
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, 40)));
    await tester.pump();
    expect(poseOf(tester).y, -40);
    expect(poseOf(tester).scale, 1);
  });

  testWidgets('two fingers rotate and the rotation snaps on release', (
    tester,
  ) async {
    await pump(
      tester,
      const TransformGestureModel(
        rotate: true,
        zoom: false,
        bounds: GestureBounds.none,
        rotationSnap: 15,
      ),
    );
    const Offset c = Offset(200, 200);
    Offset at(double degrees, double r) {
      final double a = degrees * math.pi / 180;
      return c + Offset(math.cos(a), math.sin(a)) * r;
    }

    final (g1, g2) = await twoFingers(
      tester,
      at(180, 60),
      at(0, 60),
      at(220, 60),
      at(40, 60),
      lift: false,
    );
    expect(poseOf(tester).rotation, closeTo(40, 1.5));
    expect(poseOf(tester).scale, 1); // zoom is off
    await g1.up();
    await g2.up();
    await tester.pumpAndSettle();
    expect(poseOf(tester).rotation, closeTo(45, 0.05));
  });

  testWidgets('a given pose springs the node there; a scale alone zooms the '
      'middle of the viewport', (tester) async {
    const TransformGestureModel model = TransformGestureModel(
      bounds: GestureBounds.none,
    );
    await pump(tester, model, given: const {'x': 0, 'y': 0, 'scale': 1});
    // A zoom slider writes only the scale.
    await pump(tester, model, given: const {'x': 0, 'y': 0, 'scale': 2});
    await tester.pumpAndSettle();
    final TransformPose pose = poseOf(tester);
    expect(pose.scale, closeTo(2, 0.001));
    // The parent's centre (200, 200) is the node's centre: no shift.
    expect(pose.x, closeTo(0, 0.1));
    expect(changes.any((c) => c['gesture'] == 'variable'), isTrue);

    // A given position moves it.
    await pump(tester, model, given: const {'x': 30, 'y': -20, 'scale': 2});
    await tester.pumpAndSettle();
    expect(poseOf(tester).x, closeTo(30, 0.05));
    expect(poseOf(tester).y, closeTo(-20, 0.05));
  });

  testWidgets('the node reads its pose as transform', (tester) async {
    TransformValues? seen;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: NodeTransformGesture(
          model: const TransformGestureModel(),
          given: const {'scale': 1.5, 'rotation': 10},
          child: Builder(
            builder: (context) {
              seen = TransformScope.maybeOf(context);
              return const SizedBox(width: 50, height: 50);
            },
          ),
        ),
      ),
    );
    expect(seen!.pose.scale, 1.5);
    expect(seen!.toMap()['rotation'], 10);
    expect(seen!.toMap()['active'], isFalse);
  });

  group('handles', () {
    const TransformGestureModel sticker = TransformGestureModel(
      bounds: GestureBounds.none,
      handles: TransformHandlesModel(snapAngle: 15, minWidth: 100),
    );

    Future<void> dragHandle(WidgetTester tester, String name, Offset to) async {
      final Offset from = tester.getCenter(
        find.byKey(ValueKey('transform-handle-$name')),
      );
      final TestGesture g = await tester.startGesture(from);
      for (int i = 1; i <= 10; i++) {
        await g.moveTo(Offset.lerp(from, to, i / 10)!);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await g.up();
      await tester.pumpAndSettle();
    }

    testWidgets('a corner scales, keeping the aspect', (tester) async {
      await pump(tester, sticker);
      expect(
        tester.getCenter(find.byKey(const ValueKey('transform-handle-br'))),
        const Offset(300, 300),
      );
      await dragHandle(tester, 'br', const Offset(380, 380));
      expect(poseOf(tester).scale, closeTo(1.8, 0.02));
      expect(poseOf(tester).scaleX, 1);
      // The handle follows, outside the node's laid out box, and still
      // takes the pointer there.
      expect(
        tester.getCenter(find.byKey(const ValueKey('transform-handle-br'))),
        offsetMoreOrLessEquals(const Offset(380, 380), epsilon: 2),
      );
      await dragHandle(tester, 'br', const Offset(350, 350));
      expect(poseOf(tester).scale, closeTo(1.5, 0.02));
      expect(ends.last['gesture'], 'handle');
    });

    testWidgets('the minimum size holds', (tester) async {
      await pump(tester, sticker);
      await dragHandle(tester, 'br', const Offset(210, 210));
      // 100px wide at least: half its 200px.
      expect(poseOf(tester).scale, closeTo(0.5, 0.01));
    });

    testWidgets('the knob rotates in 15° steps', (tester) async {
      await pump(tester, sticker);
      expect(
        tester.getCenter(find.byKey(const ValueKey('transform-handle-rotate'))),
        const Offset(200, 72),
      );
      // Straight right of the centre is 90°.
      await dragHandle(tester, 'rotate', const Offset(320, 200));
      expect(poseOf(tester).rotation, closeTo(90, 0.01));
      // 11° above that snaps to 75°.
      await dragHandle(tester, 'rotate', const Offset(320, 177));
      expect(poseOf(tester).rotation, closeTo(75, 0.01));
    });

    testWidgets('edges stretch one axis when the aspect is free', (
      tester,
    ) async {
      await pump(
        tester,
        const TransformGestureModel(
          bounds: GestureBounds.none,
          handles: TransformHandlesModel(edges: true, aspectLock: false),
        ),
      );
      await dragHandle(tester, 'r', const Offset(350, 200));
      expect(poseOf(tester).scaleX, closeTo(1.5, 0.02));
      expect(poseOf(tester).scaleY, 1);
      expect(poseOf(tester).scale, 1);
    });

    testWidgets('handles show only while selected; a tap selects', (
      tester,
    ) async {
      int selects = 0;
      await pump(tester, sticker, selected: false, onSelect: () => selects++);
      expect(find.byKey(const ValueKey('transform-handle-br')), findsNothing);
      await tester.tapAt(const Offset(200, 200));
      // A single tap waits out the double tap zoom's timeout.
      await tester.pump(kDoubleTapTimeout);
      expect(selects, 1);
      await pump(tester, sticker, selected: true);
      expect(find.byKey(const ValueKey('transform-handle-br')), findsOneWidget);
    });

    testWidgets('a moved sticker is grabbed where it is drawn', (tester) async {
      await pump(
        tester,
        const TransformGestureModel(
          bounds: GestureBounds.none,
          physics: PhysicsModel(fling: false),
        ),
        given: const {'x': 150},
      );
      // Now drawn at 250..450, outside its laid out box (100..300).
      await tester.dragFrom(const Offset(380, 200), const Offset(0, 60));
      await tester.pumpAndSettle();
      expect(poseOf(tester).y, closeTo(60, 0.5));
    });
  });
}
