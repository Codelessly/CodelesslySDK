import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Hero flights (morph, fade through, arc, container transform), heroes in
// grids and modals, the image-loading placeholder, and the 3D behaviours:
// flip cards, tilt and page motion.

const Size _screen = Size(400, 800);

void _size(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = _screen;
  addTearDown(tester.view.reset);
}

RectangleNode _node(String id, {HeroFlight? flight, double corner = 0}) =>
    RectangleNode(
        id: id,
        name: id,
        basicBoxLocal: NodeBox(0, 0, 10, 10),
        cornerRadius: CornerRadius.all(RadiusModel.circular(corner)),
      )
      ..heroFlight = flight;

/// The shared element drawings flying in the overlay (outside every route).
List<Element> _flying(WidgetTester tester) => find
    .byType(NodeHeroChild, skipOffstage: false)
    .evaluate()
    .where((e) => ModalRoute.of(e) == null)
    .toList();

double _opacityAbove(Element element) {
  double opacity = 1;
  element.visitAncestorElements((e) {
    if (e.widget is Opacity) opacity *= (e.widget as Opacity).opacity;
    return e.widget is! Overlay;
  });
  return opacity;
}

/// Pushes a screen with [hero] at [to] from a screen with [from].
Future<GlobalKey<NavigatorState>> _flight(
  WidgetTester tester, {
  required Widget from,
  required Widget to,
  RouteTransition transition = const RouteTransition(durationMs: 400),
  bool modal = false,
}) async {
  _size(tester);
  final navigator = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    MaterialApp(navigatorKey: navigator, home: Material(child: from)),
  );
  navigator.currentState!.push(
    CodelesslyRouteTransitionRoute<void>(
      transition: transition,
      modal: modal,
      fallbackBarrierColor: modal ? Colors.black54 : null,
      builder: (_) => to,
    ),
  );
  await tester.pump();
  await tester.pump();
  return navigator;
}

Widget _at(Rect rect, Widget child) => Stack(
  children: [Positioned.fromRect(rect: rect, child: child)],
);

void main() {
  group('flights', () {
    testWidgets('morph flies both nodes and cross-fades them', (tester) async {
      await _flight(
        tester,
        from: _at(
          const Rect.fromLTWH(20, 20, 100, 30),
          NodeHero.wrap(
            node: _node('title-a', flight: HeroFlight.morph),
            tag: 'title',
            child: const Text('Mountains', key: Key('small')),
          ),
        ),
        to: _at(
          const Rect.fromLTWH(20, 300, 360, 60),
          NodeHero.wrap(
            node: _node('title-b', flight: HeroFlight.morph),
            tag: 'title',
            child: const Text(
              'Mountains',
              key: Key('large'),
              style: TextStyle(fontSize: 40, color: Colors.purple),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      final List<Element> flying = _flying(tester);
      expect(
        flying.map((e) => (e.widget as NodeHeroChild).node.id).toSet(),
        {'title-a', 'title-b'},
      );
      // Mid-flight (the flight eases with fastOutSlowIn) both are partly
      // visible: one fading out as the other fades in.
      final double total = flying
          .map(_opacityAbove)
          .fold(0.0, (a, b) => a + b);
      for (final Element e in flying) {
        expect(_opacityAbove(e), inExclusiveRange(0, 1));
      }
      expect(total, moreOrLessEquals(1, epsilon: 0.01));
      // Both are fitted to the flight's box, between the two sizes.
      final Rect box = tester.getRect(find.byWidget(flying.first.widget));
      expect(box.width, inExclusiveRange(100, 360));
      expect(box.top, inExclusiveRange(20, 300));
      await tester.pumpAndSettle();
      expect(_flying(tester), isEmpty);
    });

    testWidgets('fade through: the source is gone before the destination '
        'shows', (tester) async {
      await _flight(
        tester,
        from: _at(
          const Rect.fromLTWH(0, 0, 100, 100),
          NodeHero.wrap(
            node: _node('a', flight: HeroFlight.fadeThrough),
            tag: 't',
            child: const ColoredBox(color: Colors.red),
          ),
        ),
        to: _at(
          const Rect.fromLTWH(0, 400, 400, 400),
          NodeHero.wrap(
            node: _node('b'),
            tag: 't',
            child: const ColoredBox(color: Colors.blue),
          ),
        ),
      );
      double opacityOf(String id) => _opacityAbove(
        _flying(
          tester,
        ).firstWhere((e) => (e.widget as NodeHeroChild).node.id == id),
      );
      await tester.pump(const Duration(milliseconds: 100)); // 25%
      expect(opacityOf('a'), inExclusiveRange(0, 1));
      expect(opacityOf('b'), 0);
      await tester.pump(const Duration(milliseconds: 100)); // 50%
      expect(opacityOf('a'), 0);
      expect(opacityOf('b'), inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
    });

    testWidgets('container transform grows the card into the screen with '
        'morphing corners', (tester) async {
      await _flight(
        tester,
        from: _at(
          const Rect.fromLTWH(40, 500, 160, 200),
          NodeHero.wrap(
            node: _node(
              'card',
              flight: HeroFlight.containerTransform,
              corner: 24,
            ),
            tag: 'product-1',
            child: const ColoredBox(color: Colors.orange),
          ),
        ),
        to: NodeHero.wrap(
          node: _node('screen'),
          tag: 'product-1',
          child: const SizedBox.expand(child: ColoredBox(color: Colors.white)),
        ),
        transition: const RouteTransition(durationMs: 400),
      );
      await tester.pump(const Duration(milliseconds: 200));
      final Element shuttle = _flying(tester).first;
      final Rect box = tester.getRect(find.byWidget(shuttle.widget));
      // Between the card and the whole screen, on a straight path (the
      // left edge and the width move together toward the screen's).
      expect(box.left, inExclusiveRange(0, 40));
      expect(box.width, inExclusiveRange(160, 400));
      final double t = (40 - box.left) / 40;
      expect(box.width, moreOrLessEquals(160 + 240 * t, epsilon: 2));
      final ClipRRect clip = shuttle.findAncestorWidgetOfExactType<ClipRRect>()!;
      final double radius = (clip.borderRadius as BorderRadius).topLeft.x;
      expect(radius, inExclusiveRange(0, 24));
      await tester.pumpAndSettle();
    });

    testWidgets('arc flights curve; standard ones keep the app controller', (
      tester,
    ) async {
      final Widget arc = NodeHero.wrap(
        node: _node('a', flight: HeroFlight.arc),
        tag: 'x',
        child: const SizedBox(),
      );
      await tester.pumpWidget(MaterialApp(home: arc));
      final Hero hero = tester.widget<Hero>(find.byType(Hero));
      expect(
        hero.createRectTween!(Rect.zero, const Rect.fromLTWH(0, 0, 1, 1)),
        isA<HeroArcRectTween>(),
      );
      expect(hero.transitionOnUserGestures, isTrue);
      await tester.pumpWidget(
        MaterialApp(
          home: NodeHero.wrap(node: _node('b'), tag: 'y', child: const SizedBox()),
        ),
      );
      expect(tester.widget<Hero>(find.byType(Hero)).createRectTween, isNull);
    });
  });

  group('lists and modals', () {
    testWidgets('a grid cell flies from its own cell, tagged by item id', (
      tester,
    ) async {
      _size(tester);
      final navigator = GlobalKey<NavigatorState>();
      Widget grid() => GridView.count(
        crossAxisCount: 3,
        children: [
          for (int i = 0; i < 12; i++)
            NodeHero.wrap(
              node: _node('cell'),
              tag: 'photo-$i',
              child: ColoredBox(key: Key('cell-$i'), color: Colors.green),
            ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(navigatorKey: navigator, home: Material(child: grid())),
      );
      final Rect cell = tester.getRect(find.byKey(const Key('cell-7')));
      navigator.currentState!.push(
        CodelesslyRouteTransitionRoute<void>(
          transition: const RouteTransition(durationMs: 400),
          builder: (_) => Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 400,
              height: 400,
              child: NodeHero.wrap(
                node: _node('detail'),
                tag: 'photo-7',
                child: const ColoredBox(color: Colors.green),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      final List<Element> flying = _flying(tester);
      expect(flying, hasLength(1));
      // It starts from cell 7, not any other cell.
      final Rect start = tester.getRect(find.byWidget(flying.first.widget));
      expect(start.center.dx, moreOrLessEquals(cell.center.dx, epsilon: 1));
      expect(start.center.dy, moreOrLessEquals(cell.center.dy, epsilon: 1));
      await tester.pump(const Duration(milliseconds: 200));
      final Rect mid = tester.getRect(find.byWidget(_flying(tester).first.widget));
      expect(mid.width, inExclusiveRange(cell.width, 400));
      await tester.pumpAndSettle();

      // Back into the same cell.
      navigator.currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 399));
      final Rect end = tester.getRect(find.byWidget(_flying(tester).first.widget));
      expect(end.center.dx, moreOrLessEquals(cell.center.dx, epsilon: 4));
      await tester.pumpAndSettle();
    });

    testWidgets('a hero flies into a modal sheet and back out', (tester) async {
      final navigator = await _flight(
        tester,
        modal: true,
        transition: const RouteTransition.preset(
          RouteTransitionPreset.coverVertical,
        ),
        from: _at(
          const Rect.fromLTWH(20, 100, 60, 60),
          NodeHero.wrap(
            node: _node('avatar'),
            tag: 'avatar',
            child: const ColoredBox(color: Colors.teal),
          ),
        ),
        to: Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            height: 400,
            child: _at(
              const Rect.fromLTWH(150, 40, 100, 100),
              NodeHero.wrap(
                node: _node('avatar-big'),
                tag: 'avatar',
                child: const ColoredBox(color: Colors.teal),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(_flying(tester), hasLength(1));
      await tester.pumpAndSettle();
      expect(find.byType(ModalBarrier), findsWidgets);
      navigator.currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(_flying(tester), hasLength(1));
      await tester.pumpAndSettle();
      expect(_flying(tester), isEmpty);
    });
  });

  group('dialogs', () {
    testWidgets('a dialog action with a route transition opens a page route '
        'modal (so heroes fly) with its barrier', (tester) async {
      _size(tester);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(navigatorKey: navigator, home: const SizedBox()),
      );
      for (final DialogPresentation p in [
        DialogPresentation.dialog,
        DialogPresentation.bottomSheet,
        DialogPresentation.fullScreen,
      ]) {
        FunctionsRepository.presentCanvas<void>(
          navigator.currentContext!,
          presentation: p,
          barrierColor: const Color(0x80000000),
          routeTransition: const RouteTransition.preset(
            RouteTransitionPreset.coverVertical,
          ),
          builder: (_) => const SizedBox(key: Key('body'), height: 200),
        );
        await tester.pumpAndSettle();
        Route<dynamic>? top;
        navigator.currentState!.popUntil((route) {
          top = route;
          return true;
        });
        expect(top, isA<CodelesslyRouteTransitionRoute<void>>(), reason: '$p');
        expect(top, isA<PageRoute<void>>());
        expect((top! as ModalRoute<void>).barrierColor, const Color(0x80000000));
        expect((top! as ModalRoute<void>).opaque, isFalse);
        expect(find.byKey(const Key('body')), findsOneWidget);
        navigator.currentState!.pop();
        await tester.pumpAndSettle();
      }
    });
  });

  group('image loading', () {
    testWidgets('the source shows under a destination still loading', (
      tester,
    ) async {
      final HeroImageLoads loads = HeroImageLoads();
      bool loaded = false;
      late StateSetter set;
      await tester.pumpWidget(
        HeroImageLoadScope(
          loads: loads,
          child: StatefulBuilder(
            builder: (context, setState) {
              set = setState;
              return HeroImageLoadReporter(
                loaded: loaded,
                child: const SizedBox(),
              );
            },
          ),
        ),
      );
      await tester.pump();
      expect(loads.pending, 1);
      set(() => loaded = true);
      await tester.pump();
      expect(loads.pending, 0);
    });

    testWidgets('in flight, a destination still loading flies over its '
        'source', (tester) async {
      _size(tester);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: _at(
            const Rect.fromLTWH(0, 0, 50, 50),
            NodeHero.wrap(
              node: _node('thumb'),
              tag: 'img',
              child: const ColoredBox(key: Key('thumb'), color: Colors.red),
            ),
          ),
        ),
      );
      navigator.currentState!.push(
        CodelesslyRouteTransitionRoute<void>(
          transition: const RouteTransition(durationMs: 400),
          builder: (_) => _at(
            const Rect.fromLTWH(0, 0, 400, 400),
            NodeHero.wrap(
              node: _node('full'),
              tag: 'img',
              child: const HeroImageLoadReporter(
                loaded: false,
                child: SizedBox.expand(key: Key('full')),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 16));
      // The thumbnail is drawn in the overlay, under the loading image.
      final Iterable<Element> thumbs = find
          .byKey(const Key('thumb'), skipOffstage: false)
          .evaluate()
          .where((e) => ModalRoute.of(e) == null);
      expect(thumbs, isNotEmpty);
      await tester.pumpAndSettle();
    });

    testWidgets('heroPlaceholder keeps the source drawn until loaded', (
      tester,
    ) async {
      _size(tester);
      final navigator = GlobalKey<NavigatorState>();
      final RectangleNode dest = _node('full')
        ..heroPlaceholder = HeroPlaceholder.source;
      final ValueNotifier<bool> loaded = ValueNotifier(false);
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: _at(
            const Rect.fromLTWH(0, 0, 50, 50),
            NodeHero.wrap(
              node: _node('thumb'),
              tag: 'img',
              child: const ColoredBox(key: Key('thumb'), color: Colors.red),
            ),
          ),
        ),
      );
      navigator.currentState!.push(
        CodelesslyRouteTransitionRoute<void>(
          transition: const RouteTransition(durationMs: 200),
          builder: (_) => _at(
            const Rect.fromLTWH(0, 0, 400, 400),
            NodeHero.wrap(
              node: dest,
              tag: 'img',
              child: ValueListenableBuilder<bool>(
                valueListenable: loaded,
                builder: (context, done, _) => HeroImageLoadReporter(
                  loaded: done,
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Landed, still loading: the thumbnail is drawn in the full image's
      // place (once on the screen below, once as the placeholder).
      expect(find.byKey(const Key('thumb'), skipOffstage: false), findsNWidgets(2));
      loaded.value = true;
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('thumb'), skipOffstage: false), findsOneWidget);
    });
  });

  testWidgets('a flying copy reads its screen\'s route parameters', (
    tester,
  ) async {
    late BuildContext inner;
    final ValueNotifier<Widget> overlay = ValueNotifier(const SizedBox());
    await tester.pumpWidget(
      MaterialApp(
        // The copy is built outside the route, as the hero flight builds it.
        builder: (context, navigator) => Stack(
          children: [
            navigator!,
            ValueListenableBuilder<Widget>(
              valueListenable: overlay,
              builder: (context, copy, _) => copy,
            ),
          ],
        ),
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: const RouteSettings(arguments: {'full': 'big.jpg'}),
          builder: (context) {
            inner = context;
            return const SizedBox();
          },
        ),
      ),
    );
    String? read;
    overlay.value = NodeHeroScope.wrap(
      from: inner,
      child: Builder(
        builder: (context) {
          read = PropertyValueDelegate.substituteVariables(
            r'${route.full}',
            scopedValues: ScopedValues.of(context),
            nullSubstitutionMode: NullSubstitutionMode.emptyString,
          );
          return const SizedBox();
        },
      ),
    );
    await tester.pump();
    expect(read, 'big.jpg');
  });

  group('3D', () {
    testWidgets('a flip card turns on tap with perspective, faces hide', (
      tester,
    ) async {
      _size(tester);
      final GlobalKey<NodeFlipState> flipKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 200,
              height: 300,
              child: NodeFlip(
                key: flipKey,
                nodeId: 'card',
                faces: const ['front', 'back'],
                flip: const FlipModel(),
                motion: const MotionModel(perspective: 2, durationMs: 400),
                flipped: false,
                child: Builder(
                  builder: (context) => Stack(
                    fit: StackFit.expand,
                    children: [
                      FlipFaceScope.wrapFace(
                        context,
                        RectangleNode(
                          id: 'front',
                          name: 'front',
                          basicBoxLocal: NodeBox(0, 0, 1, 1),
                        )..parentID = 'card',
                        const ColoredBox(key: Key('front'), color: Colors.red),
                      ),
                      FlipFaceScope.wrapFace(
                        context,
                        RectangleNode(
                          id: 'back',
                          name: 'back',
                          basicBoxLocal: NodeBox(0, 0, 1, 1),
                        )..parentID = 'card',
                        const ColoredBox(key: Key('back'), color: Colors.blue),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      RenderBackface face(String key) => tester.renderObject<RenderBackface>(
        find.ancestor(
          of: find.byKey(Key(key)),
          matching: find.byType(BackfaceHidden),
        ),
      );
      bool shows(String key) {
        final RenderBackface box = face(key);
        return RenderBackface.facesViewer(box.getTransformTo(null), box.size);
      }

      expect(shows('front'), isTrue);
      expect(shows('back'), isFalse);
      await tester.tap(find.byType(NodeFlip));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      // Halfway: edge on, with a perspective transform.
      expect(flipKey.currentState!.progress, moreOrLessEquals(0.5, epsilon: 0.1));
      final Transform turn = tester.widget<Transform>(
        find
            .descendant(
              of: find.byType(NodeFlip),
              matching: find.byType(Transform),
            )
            .first,
      );
      expect(turn.transform.entry(3, 2), isNot(0));
      await tester.pumpAndSettle();
      expect(flipKey.currentState!.flipped, isTrue);
      expect(shows('front'), isFalse);
      expect(shows('back'), isTrue);
    });

    testWidgets('pulling a flip halfway settles on the nearer face', (
      tester,
    ) async {
      _size(tester);
      final GlobalKey<NodeFlipState> flipKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 200,
              height: 300,
              child: NodeFlip(
                key: flipKey,
                nodeId: 'card',
                faces: const [],
                flip: const FlipModel(dragToFlip: true, tapToFlip: false),
                flipped: false,
                child: const ColoredBox(color: Colors.red),
              ),
            ),
          ),
        ),
      );
      // 30% of the width: springs back to the front.
      TestGesture drag = await tester.startGesture(const Offset(250, 400));
      await drag.moveBy(const Offset(-20, 0));
      await drag.moveBy(const Offset(-60, 0));
      await tester.pump();
      expect(flipKey.currentState!.progress, inExclusiveRange(0.2, 0.5));
      await tester.pump(const Duration(milliseconds: 400));
      await drag.up();
      await tester.pumpAndSettle();
      expect(flipKey.currentState!.progress, moreOrLessEquals(0, epsilon: 0.01));
      expect(flipKey.currentState!.flipped, isFalse);
      // 70%: turns over.
      drag = await tester.startGesture(const Offset(250, 400));
      await drag.moveBy(const Offset(-20, 0));
      await drag.moveBy(const Offset(-120, 0));
      await tester.pump(const Duration(milliseconds: 400));
      await drag.up();
      await tester.pumpAndSettle();
      expect(flipKey.currentState!.progress, moreOrLessEquals(1, epsilon: 0.01));
      expect(flipKey.currentState!.flipped, isTrue);
    });

    testWidgets('a flip follows its variable', (tester) async {
      final ValueNotifier<VariableData> variable = ValueNotifier(
        VariableData(
          id: 'showBack',
          name: 'showBack',
          type: VariableType.boolean,
          value: false,
        ),
      );
      final GlobalKey<NodeFlipState> flipKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: NodeFlip(
            key: flipKey,
            nodeId: 'card',
            faces: const [],
            flip: const FlipModel(variable: 'showBack'),
            flipped: false,
            variable: variable,
            child: const SizedBox.expand(),
          ),
        ),
      );
      variable.value = variable.value.copyWith(value: true);
      await tester.pumpAndSettle();
      expect(flipKey.currentState!.flipped, isTrue);
      // A tap writes it back.
      await tester.tap(find.byType(NodeFlip));
      await tester.pumpAndSettle();
      expect('${variable.value.value}', 'false');
      expect(flipKey.currentState!.progress, 0);
    });

    test('page motion is rest on the page, mirrored on the left', () {
      const MotionModel coverflow = MotionModel(
        rotateY: -50,
        scale: 0.8,
        originX: -1,
      );
      expect(pageMotionAt(coverflow, 0).rotateY, 0);
      expect(pageMotionAt(coverflow, 0).scale, 1);
      expect(pageMotionAt(coverflow, 0.5).rotateY, -25);
      expect(pageMotionAt(coverflow, 1).scale, moreOrLessEquals(0.8));
      expect(pageMotionAt(coverflow, -1).rotateY, 50);
      expect(pageMotionAt(coverflow, -1).originX, 1);
      // Clamped at two pages.
      expect(pageMotionAt(coverflow, 5).rotateY, -100);
    });

    testWidgets('a page view item turns by its offset and reads it', (
      tester,
    ) async {
      _size(tester);
      final PageController controller = PageController(viewportFraction: 0.5);
      addTearDown(controller.dispose);
      final Map<int, double> offsets = {};
      await tester.pumpWidget(
        MaterialApp(
          home: PageView.builder(
            controller: controller,
            itemCount: 5,
            itemBuilder: (context, index) => PageMotionItem(
              controller: controller,
              index: index,
              motion: const MotionModel(rotateY: -50, scale: 0.8),
              child: Builder(
                builder: (context) {
                  offsets[index] =
                      MotionValuesScope.of(context)['pageOffset']! as double;
                  return ColoredBox(key: Key('p$index'), color: Colors.grey);
                },
              ),
            ),
          ),
        ),
      );
      expect(offsets[0], 0);
      expect(offsets[1], 1);
      Matrix4 transformOf(int i) => tester
          .widget<Transform>(
            find.ancestor(of: find.byKey(Key('p$i')), matching: find.byType(Transform)).first,
          )
          .transform;
      expect(transformOf(0).isIdentity(), isTrue);
      expect(transformOf(1).isIdentity(), isFalse);
      // Halfway to page 1: both pages are half turned, mirrored.
      controller.jumpTo(controller.position.viewportDimension * 0.25);
      await tester.pump();
      expect(offsets[0], moreOrLessEquals(-0.5, epsilon: 0.01));
      expect(offsets[1], moreOrLessEquals(0.5, epsilon: 0.01));
    });

    testWidgets('tilt follows a hovering mouse and settles back', (
      tester,
    ) async {
      _size(tester);
      final GlobalKey<NodeTiltState> tiltKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 200,
              height: 200,
              child: NodeTilt(
                key: tiltKey,
                tilt: const TiltModel(
                  max: MotionModel(rotateX: 10, rotateY: 20, scale: 1.1),
                ),
                child: const ColoredBox(color: Colors.red),
              ),
            ),
          ),
        ),
      );
      final TestGesture mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await mouse.addPointer(location: const Offset(10, 10));
      // The right edge of the card (x = 1, y = 0).
      await mouse.moveTo(const Offset(299, 400));
      await tester.pumpAndSettle();
      expect(tiltKey.currentState!.position.dx, moreOrLessEquals(1, epsilon: 0.02));
      expect(tiltKey.currentState!.position.dy, moreOrLessEquals(0, epsilon: 0.02));
      await mouse.moveTo(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(tiltKey.currentState!.position, Offset.zero);
      await mouse.removePointer();
    });
  });
}
