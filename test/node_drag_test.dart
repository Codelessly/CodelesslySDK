import 'dart:math' as math;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The gesture primitive behind swipe cards: a node that follows the
/// pointer, tilts, shares its drag as `drag`, and springs back or flies off.
void main() {
  const swipeCard = DragModel(
    release: DragRelease.dismiss,
    directions: [DragDirection.left, DragDirection.right, DragDirection.up],
    rotateFactor: 15,
    originY: 1.6,
    distanceThreshold: 0.35,
    resistance: 0.7,
  );

  late List<DragDirection> dismissed;
  late List<Map<String, dynamic>> ends;
  late List<DragValues> seen;

  Widget card({
    DragModel drag = swipeCard,
    bool Function()? isEnabled,
    String id = 'card',
    Key? key,
  }) => Directionality(
    textDirection: TextDirection.ltr,
    child: MediaQuery(
      data: const MediaQueryData(size: Size(800, 600)),
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 200,
          height: 300,
          child: NodeDrag(
            key: key,
            nodeId: id,
            drag: drag,
            isEnabled: isEnabled,
            onDismissed: (d) => dismissed.add(d),
            onEnd: ends.add,
            child: Builder(
              builder: (context) {
                seen.add(DragScope.maybeOf(context)!);
                return const SizedBox.expand(child: Text('front'));
              },
            ),
          ),
        ),
      ),
    ),
  );

  setUp(() {
    dismissed = [];
    ends = [];
    seen = [];
  });

  Matrix4? transformOf(WidgetTester tester) {
    final transforms = tester.widgetList<Transform>(
      find.ancestor(of: find.text('front'), matching: find.byType(Transform)),
    );
    return transforms.isEmpty ? null : transforms.first.transform;
  }

  testWidgets('follows the pointer, tilts and shares its progress', (
    tester,
  ) async {
    await tester.pumpWidget(card());
    final gesture = await tester.startGesture(const Offset(100, 150));
    await gesture.moveBy(const Offset(20, 0));
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();
    final Matrix4 m = transformOf(tester)!;
    // Moved right by 60 (minus the slop the pan recognizer eats first).
    expect(m.getTranslation().x, greaterThan(30));
    // Tilted clockwise: 15° per card width.
    final double angle = math.atan2(m.storage[1], m.storage[0]) * 180 / math.pi;
    expect(angle, closeTo(m.getTranslation().x / 200 * 15, 0.01));
    final DragValues values = seen.last;
    expect(values.dragging, isTrue);
    expect(values.right, greaterThan(0));
    expect(values.right, lessThan(1));
    expect(values.left, 0);
    expect(values.direction, 'right');
    expect(values.toMap()['dx'], values.offset.dx);
    await gesture.up();
  });

  testWidgets('springs back when let go short of the threshold', (
    tester,
  ) async {
    await tester.pumpWidget(card());
    await tester.timedDrag(
      find.text('front'),
      const Offset(40, 0),
      const Duration(milliseconds: 600),
    );
    await tester.pumpAndSettle();
    expect(dismissed, isEmpty);
    expect(ends.single['dismissed'], isFalse);
    expect(seen.last.offset, Offset.zero);
    expect(seen.last.dragging, isFalse);
  });

  testWidgets('flies off past the threshold and reports the direction', (
    tester,
  ) async {
    await tester.pumpWidget(card());
    await tester.timedDrag(
      find.text('front'),
      const Offset(-120, 0),
      const Duration(milliseconds: 800),
    );
    await tester.pumpAndSettle();
    expect(dismissed, [DragDirection.left]);
    expect(ends.single['direction'], 'left');
    // Still mounted: comes back to rest for its next content.
    expect(seen.last.offset, Offset.zero);
  });

  testWidgets('a fast fling dismisses even when short', (tester) async {
    await tester.pumpWidget(card());
    await tester.fling(find.text('front'), const Offset(0, -50), 1500);
    await tester.pumpAndSettle();
    expect(dismissed, [DragDirection.up]);
  });

  testWidgets('directions that cannot dismiss resist and spring back', (
    tester,
  ) async {
    await tester.pumpWidget(card());
    final gesture = await tester.startGesture(const Offset(100, 150));
    for (int i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(0, 30));
    }
    await tester.pump();
    // 300px pulled down, held back by the rubber band.
    expect(seen.last.offset.dy, greaterThan(0));
    expect(seen.last.offset.dy, lessThan(120 * 0.3 + 1));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(dismissed, isEmpty);
    expect(seen.last.offset, Offset.zero);
  });

  testWidgets('a disabled drag does not move', (tester) async {
    await tester.pumpWidget(
      card(drag: swipeCard.copyWith(shakeWhenDisabled: true), isEnabled: () => false),
    );
    await tester.timedDrag(
      find.text('front'),
      const Offset(-150, 0),
      const Duration(milliseconds: 400),
    );
    await tester.pumpAndSettle();
    expect(dismissed, isEmpty);
    expect(seen.last.offset, Offset.zero);
  });

  testWidgets('actions fling, return and reset the enabled instance', (
    tester,
  ) async {
    await tester.pumpWidget(card(id: 'deck'));
    final Future<void> flung = NodeDrag.control(
      'deck',
      DragCommand.fling,
      DragDirection.right,
    );
    await tester.pumpAndSettle();
    await flung;
    expect(dismissed, [DragDirection.right]);

    final Future<void> back = NodeDrag.control(
      'deck',
      DragCommand.returnFrom,
      DragDirection.left,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    // Starts off-screen on the left and glides in.
    expect(seen.last.offset.dx, lessThan(-200));
    await tester.pumpAndSettle();
    await back;
    expect(seen.last.offset, Offset.zero);
  });

  testWidgets('a returning card built in the next frame starts off-screen', (
    tester,
  ) async {
    await tester.pumpWidget(const SizedBox());
    final Future<void> back = NodeDrag.control(
      'undo',
      DragCommand.returnFrom,
      DragDirection.up,
    );
    await tester.pumpWidget(card(id: 'undo'));
    expect(seen.first.offset.dy, lessThan(-300));
    await tester.pumpAndSettle();
    await back;
    expect(seen.last.offset, Offset.zero);
  });

  test('stays on release when asked to', () {
    expect(
      const DragModel(release: DragRelease.stay).canDismiss(DragDirection.left),
      isFalse,
    );
  });
}
