// Custom route transitions (SDK 8.x's ui/route_transition.dart): the sides'
// timing, the route a navigate or open modal action opens, closing it.
import 'dart:async';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a side\'s amount follows its interval and curve; entering starts at its values', () {
    const side = TransitionSide(delayMs: 100, durationMs: 200, curve: AnimationCurve.linear);
    expect(sideAmountAt(side, 0, totalMs: 400, entering: true), 1);
    expect(sideAmountAt(side, 0.5, totalMs: 400, entering: true), closeTo(0.5, 1e-9));
    expect(sideAmountAt(side, 1, totalMs: 400, entering: true), 0);
    expect(sideAmountAt(side, 0.5, totalMs: 400, entering: false), closeTo(0.5, 1e-9));
    expect(TransitionPhysics.commits(progress: 0.1, velocity: 900, distance: 0.25, flingVelocity: 700), isTrue);
    expect(TransitionPhysics.commits(progress: 0.3, velocity: 0, distance: 0.25, flingVelocity: 700), isTrue);
    expect(TransitionPhysics.commits(progress: 0.1, velocity: 0, distance: 0.25, flingVelocity: 700), isFalse);
  });

  testWidgets('a side view moves, fades and reveals by its amount', (tester) async {
    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: TransitionSideView(
        side: TransitionSide(
          motion: Motion(shiftX: 1, opacity: 0, rotateY: 90),
          reveal: TransitionReveal(origin: RevealOrigin.center),
        ),
        amount: 0.5,
        child: SizedBox.expand(),
      ),
    ));
    expect(tester.widget<FractionalTranslation>(find.byType(FractionalTranslation)).translation, const Offset(0.5, 0));
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 0.5);
    expect(find.byType(Transform), findsOneWidget);
    expect(find.byType(ClipPath), findsOneWidget);
    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: TransitionSideView(side: TransitionSide(motion: Motion(opacity: 0)), amount: 0, child: SizedBox.expand()),
    ));
    expect(find.byType(Opacity), findsNothing);
  });

  testWidgets('a route plays its preset: the new screen slides in, the old one moves aside', (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(navigatorKey: navigator, home: const Text('home')));
    final route = CodelesslyRouteTransitionRoute<void>(
      transition: const RouteTransition(preset: RouteTransitionPreset.iosPush),
      builder: (_) => const Text('next'),
    );
    expect(route.transitionDuration, const Duration(milliseconds: 400));
    expect(route.opaque, isTrue);
    unawaited(navigator.currentState!.push(route));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    final shifts = tester.widgetList<FractionalTranslation>(find.byType(FractionalTranslation)).map((f) => f.translation.dx).toList();
    expect(shifts.any((dx) => dx > 0 && dx < 1), isTrue, reason: 'the new screen on its way in: $shifts');
    expect(shifts.any((dx) => dx < 0 && dx > -1 / 3), isTrue, reason: 'the old screen moving aside: $shifts');
    await tester.pumpAndSettle();
    expect(find.text('next'), findsOneWidget);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('next'), findsNothing);
  });

  testWidgets('a modal with a transition is see-through, closes with a close modal action, and gives its result', (tester) async {
    late BuildContext home;
    late BuildContext inModal;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
      home = c;
      return const Text('home');
    })));
    final ui = NavigatorActionUi(
      context: () => home,
      modal: (destination, params) => Builder(builder: (c) {
        inModal = c;
        return Text('modal $destination');
      }),
    );
    Object? result;
    unawaited(ui
        .openModal(const OpenModalAction(to: 'd', routeTransition: RouteTransition(preset: RouteTransitionPreset.zoom)))
        .then((r) => result = r));
    await tester.pumpAndSettle();
    expect(find.text('modal d'), findsOneWidget);
    expect(find.text('home'), findsOneWidget, reason: 'the screen behind still shows');
    expect(ModalRoute.of(inModal), isA<CodelesslyRouteTransitionRoute>());
    final close = NavigatorActionUi(context: () => inModal);
    expect(close.closeModal({'ok': true}), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('modal d'), findsNothing);
    expect(result, {'ok': true});
  });

  testWidgets('a navigate action with a route transition opens its screen in one', (tester) async {
    Json layout(String id, {List<Json> actions = const []}) => {
          'schema': 2,
          'id': id,
          'roots': ['$id-c'],
          'nodes': {
            '$id-c': {
              'type': 'canvas',
              'name': id,
              'slots': {'body': '$id-b'},
              'layout': {'width': 400, 'height': 600},
              'actions': actions,
            },
            '$id-b': {'type': 'stack', 'layout': {'width': {'fill': 400}, 'height': {'fill': 600}}},
          },
        };
    final bundle = PublishBundle.fromJson({
      'schema': 2,
      'model': {
        'projectId': 'p',
        'entryLayoutId': 'home',
        'layouts': {
          'home': {
            'canvases': [
              {'id': 'home-c', 'name': 'home'},
            ],
          },
          'next': {
            'canvases': [
              {'id': 'next-c', 'name': 'next'},
            ],
          },
        },
      },
      'layouts': {
        'home': layout('home', actions: [
          {
            'trigger': {'type': 'click'},
            'actions': [
              {'type': 'navigate', 'to': 'next', 'routeTransition': 'cube'},
            ],
          },
        ]),
        'next': layout('next'),
      },
    });
    final codelessly = Codelessly(
      config: const CodelesslyConfig(projectId: 'p'),
      loader: MemoryPublishLoader(bundle),
      fonts: const NoFontFetcher(),
    );
    final controller = CodelesslyWidgetController();
    addTearDown(controller.dispose);
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(navigatorKey: navigator, home: CodelesslyWidget(codelessly: codelessly, controller: controller)));
    await tester.pumpAndSettle();
    unawaited(controller.trigger('home-c', 'click'));
    await tester.pump();
    await tester.pump();
    Route<Object?>? top;
    navigator.currentState!.popUntil((r) {
      top = r;
      return true;
    });
    expect(top, isA<CodelesslyRouteTransitionRoute>());
    expect((top! as CodelesslyRouteTransitionRoute).transitionDuration, const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(codelessly.route.value?.layoutId, 'next');
  });
}
