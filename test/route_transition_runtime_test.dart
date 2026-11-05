import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Composable route transitions (RouteTransition): both screens move, pops
// reverse, reveals clip, modals get barriers, and drags close a route
// interactively with shared elements following the finger.

const Size _screen = Size(400, 800);

Widget _app(GlobalKey<NavigatorState> navigator, Widget home) {
  return MaterialApp(
    navigatorKey: navigator,
    theme: ThemeData(platform: TargetPlatform.android),
    home: home,
  );
}

void _size(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = _screen;
  addTearDown(tester.view.reset);
}

/// A screen filling the view, marked by [key].
Widget _page(Key key, Color color) =>
    SizedBox.expand(key: key, child: ColoredBox(color: color));

/// The opacity painted above [finder] (product of every [Opacity] above it,
/// up to the navigator).
double _opacityOf(WidgetTester tester, Finder finder) {
  double opacity = 1;
  tester.element(finder).visitAncestorElements((element) {
    final Widget w = element.widget;
    if (w is Opacity) opacity *= w.opacity;
    return w is! Navigator;
  });
  return opacity;
}

Future<void> _push(
  WidgetTester tester,
  GlobalKey<NavigatorState> navigator,
  RouteTransition transition, {
  Widget? page,
  bool modal = false,
}) async {
  navigator.currentState!.push(
    CodelesslyRouteTransitionRoute<void>(
      transition: transition,
      modal: modal,
      fallbackBarrierColor: modal ? Colors.black54 : null,
      builder: (_) => page ?? _page(const Key('b'), Colors.blue),
    ),
  );
  // The first frame builds the new screen offstage (to measure heroes).
  await tester.pump();
  await tester.pump();
}

void main() {
  group('sides', () {
    testWidgets('shared axis X: both screens slide and fade at set frames', (
      tester,
    ) async {
      _size(tester);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_app(navigator, _page(const Key('a'), Colors.red)));
      await _push(
        tester,
        navigator,
        const RouteTransition.preset(RouteTransitionPreset.sharedAxisX),
      );
      final Finder a = find.byKey(const Key('a'));
      final Finder b = find.byKey(const Key('b'));

      // Start: the new screen 30 px right and invisible.
      expect(tester.getTopLeft(b).dx, moreOrLessEquals(30, epsilon: 0.5));
      expect(_opacityOf(tester, b), moreOrLessEquals(0, epsilon: 0.01));

      // 90 ms (30%): the old screen has finished fading out and moving
      // 30 px left; the new one is on its way.
      await tester.pump(const Duration(milliseconds: 90));
      expect(_opacityOf(tester, a), moreOrLessEquals(0, epsilon: 0.01));
      expect(tester.getTopLeft(a).dx, moreOrLessEquals(-30, epsilon: 0.5));
      final double bx = tester.getTopLeft(b).dx;
      expect(bx, inExclusiveRange(0, 30));
      expect(_opacityOf(tester, b), inExclusiveRange(0, 1));

      await tester.pumpAndSettle();
      expect(tester.getTopLeft(b), Offset.zero);
      expect(_opacityOf(tester, b), 1);

      // Back: the pop sides play (the popped screen leaves to the right).
      navigator.currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 45));
      expect(tester.getTopLeft(b).dx, greaterThan(0));
      await tester.pump(const Duration(milliseconds: 60));
      // Popped screen gone by 30%; the revealed screen comes from the left.
      expect(_opacityOf(tester, b), moreOrLessEquals(0, epsilon: 0.01));
      expect(tester.getTopLeft(a).dx, lessThan(0));
      await tester.pumpAndSettle();
      expect(b, findsNothing);
      expect(tester.getTopLeft(a), Offset.zero);
    });

    testWidgets('iOS push moves the covered screen a third of the way', (
      tester,
    ) async {
      _size(tester);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_app(navigator, _page(const Key('a'), Colors.red)));
      await _push(
        tester,
        navigator,
        const RouteTransition.preset(RouteTransitionPreset.iosPush),
      );
      final Finder a = find.byKey(const Key('a'));
      final Finder b = find.byKey(const Key('b'));
      expect(tester.getTopLeft(b).dx, moreOrLessEquals(400, epsilon: 0.5));
      await tester.pump(const Duration(milliseconds: 200));
      final double t = Curves.easeOutCubic.transform(0.5);
      expect(
        tester.getTopLeft(b).dx,
        moreOrLessEquals(400 * (1 - t), epsilon: 1),
      );
      expect(
        tester.getTopLeft(a).dx,
        moreOrLessEquals(-400 / 3 * t, epsilon: 1),
      );
      await tester.pumpAndSettle();
      // Once open the covered screen is offstage (the route is opaque).
      expect(find.byKey(const Key('a')), findsNothing);
    });

    testWidgets('a cube turns both screens around their shared edge', (
      tester,
    ) async {
      _size(tester);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_app(navigator, _page(const Key('a'), Colors.red)));
      await _push(
        tester,
        navigator,
        const RouteTransition.preset(RouteTransitionPreset.cube),
      );
      await tester.pump(const Duration(milliseconds: 300));
      // Halfway: each screen is turned 45° in 3D (a transform with
      // perspective) and they meet at the same edge.
      final Finder b = find.byKey(const Key('b'));
      final Transform turn = tester.widget<Transform>(
        find.ancestor(of: b, matching: find.byType(Transform)).first,
      );
      expect(turn.transform.entry(3, 2), isNot(0));
      final double bLeft = tester.getTopLeft(b).dx;
      final double aRight = tester.getTopRight(find.byKey(const Key('a'))).dx;
      expect(bLeft, moreOrLessEquals(aRight, epsilon: 2));
      expect(bLeft, inExclusiveRange(0, 400));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(b), Offset.zero);
    });

    testWidgets('fade through waits for the old screen to fade out', (
      tester,
    ) async {
      _size(tester);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_app(navigator, _page(const Key('a'), Colors.red)));
      await _push(
        tester,
        navigator,
        const RouteTransition.preset(RouteTransitionPreset.fadeThrough),
      );
      final Finder a = find.byKey(const Key('a'));
      final Finder b = find.byKey(const Key('b'));
      await tester.pump(const Duration(milliseconds: 60));
      expect(_opacityOf(tester, a), inExclusiveRange(0, 1));
      expect(_opacityOf(tester, b), moreOrLessEquals(0, epsilon: 0.001));
      await tester.pump(const Duration(milliseconds: 120));
      expect(_opacityOf(tester, a), moreOrLessEquals(0, epsilon: 0.001));
      expect(_opacityOf(tester, b), inExclusiveRange(0, 1));
    });

    testWidgets('a circular reveal grows from the tap point', (tester) async {
      _size(tester);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_app(navigator, _page(const Key('a'), Colors.red)));
      RevealAnchor.track();
      await tester.tapAt(const Offset(100, 700));
      navigator.currentState!.push(
        CodelesslyRouteTransitionRoute<void>(
          transition: const RouteTransition(
            durationMs: 400,
            enter: TransitionSide(
              reveal: TransitionReveal(origin: RevealOrigin.tap),
              curve: MotionCurve.linear,
            ),
          ),
          anchor: RevealAnchor(tap: RevealAnchor.lastTap),
          builder: (_) => _page(const Key('b'), Colors.blue),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final ClipPath clip = tester.widget<ClipPath>(
        find
            .ancestor(of: find.byKey(const Key('b')), matching: find.byType(ClipPath))
            .first,
      );
      final Path path = clip.clipper!.getClip(_screen);
      // A quarter of the way: the circle holds the tap point, not the far
      // corner.
      expect(path.contains(const Offset(100, 700)), isTrue);
      expect(path.contains(const Offset(390, 10)), isFalse);
      await tester.pumpAndSettle();
    });
  });

  group('modals', () {
    testWidgets('a see-through route keeps the screen below and a barrier', (
      tester,
    ) async {
      _size(tester);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_app(navigator, _page(const Key('a'), Colors.red)));
      await _push(
        tester,
        navigator,
        const RouteTransition.preset(RouteTransitionPreset.iosModal),
        modal: true,
        page: const Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(key: Key('b'), width: 400, height: 500),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('a')), findsOneWidget);
      final ModalBarrier barrier = tester.widget<ModalBarrier>(
        find.byType(ModalBarrier).last,
      );
      expect(barrier.color, const Color(0x33000000));
      // The screen behind shrinks back like a card stack.
      final Rect behind = tester.getRect(find.byKey(const Key('a')));
      expect(behind.width, lessThan(400));
    });
  });

  group('interactive', () {
    testWidgets('drag down closes past the distance, springs back before', (
      tester,
    ) async {
      _size(tester);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_app(navigator, _page(const Key('a'), Colors.red)));
      await _push(
        tester,
        navigator,
        const RouteTransition(
          preset: RouteTransitionPreset.coverVertical,
          dismiss: RouteDismiss(direction: DragDirection.down, distance: 0.25),
        ),
      );
      await tester.pumpAndSettle();
      final Finder b = find.byKey(const Key('b'));

      // A short slow drag: the screen follows, then springs back.
      final TestGesture short = await tester.startGesture(const Offset(200, 300));
      await short.moveBy(const Offset(0, 40));
      await short.moveBy(const Offset(0, 40));
      await tester.pump();
      expect(tester.getTopLeft(b).dy, moreOrLessEquals(80, epsilon: 25));
      expect(navigator.currentState!.userGestureInProgress, isTrue);
      await tester.pump(const Duration(milliseconds: 500));
      await short.up();
      await tester.pumpAndSettle();
      expect(b, findsOneWidget);
      expect(tester.getTopLeft(b), Offset.zero);
      expect(navigator.currentState!.userGestureInProgress, isFalse);

      // A long drag closes it.
      final TestGesture long = await tester.startGesture(const Offset(200, 300));
      for (int i = 0; i < 10; i++) {
        await long.moveBy(const Offset(0, 30));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pump(const Duration(milliseconds: 300));
      await long.up();
      await tester.pumpAndSettle();
      expect(b, findsNothing);
      expect(navigator.currentState!.userGestureInProgress, isFalse);
    });

    testWidgets('a fling closes however short', (tester) async {
      _size(tester);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_app(navigator, _page(const Key('a'), Colors.red)));
      await _push(
        tester,
        navigator,
        const RouteTransition(
          preset: RouteTransitionPreset.zoom,
          dismiss: RouteDismiss(direction: DragDirection.down),
        ),
      );
      await tester.pumpAndSettle();
      await tester.fling(
        find.byKey(const Key('b')),
        const Offset(0, 60),
        2000,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('b')), findsNothing);
    });

    testWidgets('swipe back from the left edge drives the pop and a hero '
        'follows the finger', (tester) async {
      _size(tester);
      final navigator = GlobalKey<NavigatorState>();
      final RectangleNode node = RectangleNode(
        id: 'photo',
        name: 'Photo',
        basicBoxLocal: NodeBox(0, 0, 10, 10),
      );
      Widget hero(Key key, double size) => Align(
        alignment: Alignment.topLeft,
        child: NodeHero.wrap(
          node: node,
          tag: 'photo-1',
          child: SizedBox(key: key, width: size, height: size),
        ),
      );
      await tester.pumpWidget(_app(navigator, hero(const Key('small'), 80)));
      await _push(
        tester,
        navigator,
        const RouteTransition.preset(RouteTransitionPreset.iosPush),
        page: ColoredBox(color: Colors.white, child: hero(const Key('big'), 400)),
      );
      await tester.pumpAndSettle();

      final TestGesture swipe = await tester.startGesture(const Offset(5, 400));
      await swipe.moveBy(const Offset(20, 0));
      await swipe.moveBy(const Offset(180, 0));
      await tester.pump();
      expect(navigator.currentState!.userGestureInProgress, isTrue);
      // Halfway back: the shared element flies in the overlay, between its
      // two sizes.
      final Iterable<Element> flying = find
          .byType(NodeHeroChild, skipOffstage: false)
          .evaluate()
          .where((e) => ModalRoute.of(e) == null);
      expect(flying, isNotEmpty);
      final Size inFlight = tester.getSize(
        find.byWidget(flying.first.widget),
      );
      expect(inFlight.width, inExclusiveRange(80, 400));

      await swipe.up();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('big')), findsNothing);
      expect(find.byKey(const Key('small')), findsOneWidget);
    });

    testWidgets('swipe back is off where the platform has none', (
      tester,
    ) async {
      _size(tester);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_app(navigator, _page(const Key('a'), Colors.red)));
      await _push(tester, navigator, const RouteTransition(durationMs: 100));
      await tester.pumpAndSettle();
      expect(find.byType(RouteDragDismiss), findsNothing);
    });
  });

  test('provisional physics: commit rule and spring settle', () {
    expect(
      TransitionPhysics.commits(
        progress: 0.3,
        velocity: 0,
        distance: 0.25,
        flingVelocity: 700,
      ),
      isTrue,
    );
    expect(
      TransitionPhysics.commits(
        progress: 0.1,
        velocity: 900,
        distance: 0.25,
        flingVelocity: 700,
      ),
      isTrue,
    );
    expect(
      TransitionPhysics.commits(
        progress: 0.6,
        velocity: -900,
        distance: 0.25,
        flingVelocity: 700,
      ),
      isFalse,
    );
    final sim = TransitionPhysics.settle(
      const TransitionSpring(),
      from: 0.4,
      to: 1,
      velocity: 0,
    );
    expect(sim.x(2), moreOrLessEquals(1, epsilon: 0.01));
  });
}
