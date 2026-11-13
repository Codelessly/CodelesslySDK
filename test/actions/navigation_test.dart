import 'dart:async';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Custom route transitions: the sides'
// timing, the route a navigate or open modal action opens, closing it.

void main() {
  group('screen transitions', () {
    testWidgets('a screen opens with its transition: the new one slides in and the old one moves aside', (tester) async {
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

    testWidgets('a bottom sheet with a radius rounds its top corners and hugs a short screen', (tester) async {
      late BuildContext home;
      await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
        home = c;
        return const Text('home');
      })));
      const panelKey = ValueKey('short-sheet');
      final ui = NavigatorActionUi(
        context: () => home,
        modal: (_, params) => const SizedBox(key: panelKey, height: 200, width: double.infinity),
      );
      unawaited(ui.openModal(const OpenModalAction(to: 'sheet', presentation: ModalPresentation.bottomSheet, sheetRadius: 24)));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      final clip = tester.widget<ClipRRect>(find.byKey(const ValueKey('Codelessly bottom sheet')));
      expect(clip.borderRadius, const BorderRadius.vertical(top: Radius.circular(24)));
      expect(tester.getSize(find.byKey(panelKey)).height, 200);
      expect(tester.getBottomLeft(find.byKey(panelKey)).dy, 600);
    });

    testWidgets('a modal with a transition shows the screen beneath, closes with a close action and gives its result', (tester) async {
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

    testWidgets('a navigate action with a transition opens its screen with it', (tester) async {
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
  });
}
