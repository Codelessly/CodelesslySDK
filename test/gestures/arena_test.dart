import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The gesture arena rules of docs/gestures_api.md §3: which gesture wins
/// when a drag, swipe, pan or pinch sits inside a ListView or a PageView.
void main() {
  Widget app(Widget child) => MaterialApp(
    home: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: 400, height: 600, child: child),
    ),
  );

  Widget block(Color color) => ColoredBox(color: color);

  /// A vertical list of 300px tall rows, the second one being [special].
  Widget list(ScrollController controller, Widget special) => ListView(
    controller: controller,
    children: [
      SizedBox(height: 300, child: block(Colors.amber)),
      SizedBox(height: 300, child: special),
      for (int i = 0; i < 4; i++)
        SizedBox(height: 300, child: block(Colors.teal)),
    ],
  );

  Offset dragOffset(WidgetTester tester) =>
      tester.state<NodeDragState>(find.byType(NodeDrag)).values.offset;

  TransformPose poseOf(WidgetTester tester) => tester
      .state<NodeTransformGestureState>(find.byType(NodeTransformGesture))
      .pose;

  group('inside a vertical ListView', () {
    testWidgets('rule 1: a horizontal drag keeps sideways moves, the list '
        'keeps vertical ones', (tester) async {
      final ScrollController controller = ScrollController();
      await tester.pumpWidget(
        app(
          list(
            controller,
            NodeDrag(
              nodeId: 'card',
              drag: const DragModel(
                axis: DragAxis.horizontal,
                release: DragRelease.stay,
              ),
              child: block(Colors.red),
            ),
          ),
        ),
      );
      // Sideways on the card: the card moves, the list doesn't.
      await tester.dragFrom(const Offset(200, 400), const Offset(-120, 0));
      await tester.pumpAndSettle();
      expect(dragOffset(tester).dx, closeTo(-120, 1));
      expect(controller.offset, 0);

      // Up on the card: the list scrolls, the card doesn't move.
      await tester.dragFrom(const Offset(200, 400), const Offset(0, -150));
      await tester.pumpAndSettle();
      expect(controller.offset, greaterThan(100));
      expect(dragOffset(tester).dy, 0);
      expect(dragOffset(tester).dx, closeTo(-120, 1));
    });

    testWidgets('rule 1: a free drag loses mostly-vertical moves to the list', (
      tester,
    ) async {
      final ScrollController controller = ScrollController();
      await tester.pumpWidget(
        app(
          list(
            controller,
            NodeDrag(
              nodeId: 'free',
              drag: const DragModel(release: DragRelease.stay),
              child: block(Colors.red),
            ),
          ),
        ),
      );
      await tester.dragFrom(const Offset(200, 400), const Offset(10, -150));
      await tester.pumpAndSettle();
      expect(controller.offset, greaterThan(100));
      expect(dragOffset(tester), Offset.zero);
    });

    testWidgets('rule 2: a vertical sheet drag on the same axis as the list '
        'wins on the sheet', (tester) async {
      final ScrollController controller = ScrollController();
      await tester.pumpWidget(
        app(
          list(
            controller,
            NodeDrag(
              nodeId: 'sheet',
              drag: const DragModel(
                axis: DragAxis.vertical,
                release: DragRelease.stay,
                physics: PhysicsModel(fling: false),
              ),
              child: block(Colors.red),
            ),
          ),
        ),
      );
      await tester.dragFrom(const Offset(200, 400), const Offset(0, -100));
      await tester.pumpAndSettle();
      expect(dragOffset(tester).dy, closeTo(-100, 1));
      expect(controller.offset, 0);
      // A drag that starts off the sheet still scrolls the list.
      await tester.dragFrom(const Offset(200, 150), const Offset(0, -100));
      await tester.pumpAndSettle();
      expect(controller.offset, greaterThan(50));
    });

    testWidgets('rule 4: two fingers pinch a photo; the list stays', (
      tester,
    ) async {
      final ScrollController controller = ScrollController();
      await tester.pumpWidget(
        app(
          list(
            controller,
            NodeTransformGesture(
              model: const TransformGestureModel(
                target: TransformTarget.content,
                pan: TransformPan.whenZoomed,
              ),
              child: block(Colors.red),
            ),
          ),
        ),
      );
      final TestGesture a = await tester.startGesture(
        const Offset(170, 450),
        pointer: 1,
      );
      final TestGesture b = await tester.startGesture(
        const Offset(230, 450),
        pointer: 2,
      );
      for (int i = 0; i < 10; i++) {
        await a.moveBy(const Offset(-6, 0));
        await b.moveBy(const Offset(6, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await a.up();
      await b.up();
      await tester.pumpAndSettle();
      expect(poseOf(tester).scale, greaterThan(1.5));
      expect(controller.offset, 0);
    });

    testWidgets('rule 3: a photo at rest lets one finger scroll the list', (
      tester,
    ) async {
      final ScrollController controller = ScrollController();
      await tester.pumpWidget(
        app(
          list(
            controller,
            NodeTransformGesture(
              model: const TransformGestureModel(
                target: TransformTarget.content,
                pan: TransformPan.whenZoomed,
              ),
              child: block(Colors.red),
            ),
          ),
        ),
      );
      await tester.dragFrom(const Offset(200, 450), const Offset(0, -150));
      await tester.pumpAndSettle();
      expect(controller.offset, greaterThan(100));
      expect(poseOf(tester), TransformPose.identity);
    });

    testWidgets('rule 9: a plain wheel scrolls the list past a photo; '
        'ctrl + wheel zooms it instead', (tester) async {
      final ScrollController controller = ScrollController();
      await tester.pumpWidget(
        app(
          list(
            controller,
            NodeTransformGesture(
              model: const TransformGestureModel(
                target: TransformTarget.content,
              ),
              child: block(Colors.red),
            ),
          ),
        ),
      );
      final TestPointer mouse = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(mouse.hover(const Offset(200, 450)));
      await tester.sendEventToBinding(mouse.scroll(const Offset(0, 60)));
      await tester.pumpAndSettle();
      expect(controller.offset, 60);
      expect(poseOf(tester).scale, 1);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendEventToBinding(mouse.scroll(const Offset(0, -60)));
      await tester.pumpAndSettle();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      expect(controller.offset, 60);
      expect(poseOf(tester).scale, greaterThan(1));
    });
  });

  group('inside a PageView', () {
    Widget pager(PageController controller, Widget first) => PageView(
      controller: controller,
      children: [first, block(Colors.blue), block(Colors.green)],
    );

    testWidgets('rule 3: a photo at rest lets the swipe turn the page; '
        'zoomed in, the photo pans instead', (tester) async {
      final PageController controller = PageController();
      await tester.pumpWidget(
        app(
          pager(
            controller,
            NodeTransformGesture(
              model: const TransformGestureModel(
                target: TransformTarget.content,
                pan: TransformPan.whenZoomed,
                doubleTapScale: 2,
              ),
              child: block(Colors.red),
            ),
          ),
        ),
      );
      // Zoom in first, then drag: the photo pans, the page stays.
      await tester.tapAt(const Offset(200, 300));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(const Offset(200, 300));
      await tester.pumpAndSettle();
      expect(poseOf(tester).scale, closeTo(2, 0.01));
      await tester.dragFrom(const Offset(200, 300), const Offset(-120, 0));
      await tester.pumpAndSettle();
      expect(controller.page, 0);
      expect(poseOf(tester).x, lessThan(-50));

      // Back to rest: now the same swipe turns the page.
      await tester.tapAt(const Offset(200, 300));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(const Offset(200, 300));
      await tester.pumpAndSettle();
      expect(poseOf(tester).scale, closeTo(1, 0.01));
      await tester.dragFrom(const Offset(300, 300), const Offset(-250, 0));
      await tester.pumpAndSettle();
      expect(controller.page, 1);
    });

    testWidgets('rule 2: a swipe card on the page wins its own swipes', (
      tester,
    ) async {
      final PageController controller = PageController();
      await tester.pumpWidget(
        app(
          pager(
            controller,
            Center(
              child: SizedBox(
                width: 200,
                height: 200,
                child: NodeDrag(
                  nodeId: 'card',
                  drag: const DragModel(
                    axis: DragAxis.horizontal,
                    release: DragRelease.stay,
                  ),
                  child: block(Colors.red),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.dragFrom(const Offset(200, 300), const Offset(-80, 0));
      await tester.pumpAndSettle();
      expect(dragOffset(tester).dx, closeTo(-80, 1));
      expect(controller.page, 0);
      // Off the card the page turns.
      await tester.dragFrom(const Offset(380, 50), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(controller.page, 1);
    });
  });
}
