import 'dart:async';

import 'package:codelessly_api/codelessly_api.dart' show RouteTransition, RouteTransitionPreset;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/internals.dart' show CodelesslyRouteTransitionRoute;
import 'package:flutter/gestures.dart' show kPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

// Screens, a dialog's words and a reorderable list in a host app that is
// not a Material app (a plain WidgetsApp), and in one that is: a project's
// screens open in routes of the SDK's own, with its page transition; the
// host's words reach a dialog's barrier; a reorderable list reorders.

Json _text(String text, {String? bind}) => {
      'type': 'text',
      'layout': {'width': {'hug': 60}, 'height': {'hug': 20}},
      if (bind != null) 'bind': {'props.text': bind},
      'props': {
        'text': text,
        'style': {'fontSize': 13, 'color': '#FF14181F'},
      },
    };

Json _button(Json action) => {
      'type': 'box',
      'layout': {'width': 100, 'height': 40},
      'actions': [
        {
          'trigger': {'type': 'click'},
          'actions': [action],
        },
      ],
    };

Codelessly _app({CodelesslyConfig config = const CodelesslyConfig()}) {
  final home = PublishLayout.fromJson({
    'schema': 3,
    'id': 'home',
    'roots': ['h'],
    'variables': {
      'h': [
        {'id': 'v1', 'name': 'songs', 'type': 'list', 'value': [for (var i = 0; i < 4; i++) {'id': 's$i'}]},
      ],
    },
    'nodes': {
      'h': {'type': 'canvas', 'slots': {'body': 'col'}, 'layout': {'width': 390, 'height': 844}},
      'col': {
        'type': 'column',
        'children': ['next', 'ask', 'songs'],
        'layout': {'width': {'fill': 390}, 'height': {'fill': 844}},
        'props': {'spacing': 12},
      },
      'next': _button({'type': 'navigate', 'to': 'd'}),
      'ask': _button({'type': 'openModal', 'to': 'd'}),
      'songs': {
        'type': 'listView',
        'props': {
          'reorder': {'start': 'press', 'apply': 'variable'},
        },
        'layout': {'width': {'fill': 390}, 'height': 300},
        'bind': {'data': r'${songs}'},
        'children': ['row'],
      },
      'row': {
        'type': 'row',
        'children': ['rowText'],
        'layout': {'width': {'fill': 390}, 'height': 50},
        'decoration': {
          'fills': [
            {'color': '#FFF1F3F5'},
          ],
        },
      },
      'rowText': _text('Row', bind: r'${item.id}'),
    },
  });
  final details = PublishLayout.fromJson({
    'schema': 3,
    'id': 'details',
    'roots': ['d'],
    'nodes': {
      'd': {'type': 'canvas', 'slots': {'body': 'dtext'}, 'layout': {'width': 390, 'height': 844}},
      'dtext': _text('Details'),
    },
  });
  return Codelessly.fromBundle(
    PublishBundle(
      model: PublishModel(
        projectId: 'p',
        entryLayoutId: 'home',
        layouts: {'home': PublishLayoutInfo.of(home), 'details': PublishLayoutInfo.of(details)},
      ),
      layouts: {'home': home, 'details': details},
    ),
    config: config,
  );
}

class _Routes extends NavigatorObserver {
  final List<Route<dynamic>> pushed = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => pushed.add(route);
}

/// A plain widgets app and a Material app, each giving the project's
/// screens to its navigator.
final Map<String, Widget Function(Codelessly app, NavigatorObserver routes, CodelesslyWidgetController controller)>
    hosts = {
  'WidgetsApp': (app, routes, controller) => WidgetsApp(
        color: const Color(0xFF2196F3),
        navigatorObservers: [routes],
        onGenerateRoute: _routesOf(app, controller),
      ),
  'MaterialApp': (app, routes, controller) =>
      MaterialApp(navigatorObservers: [routes], onGenerateRoute: _routesOf(app, controller)),
};

/// The project's screens as [CodelesslyWidget.onGenerateRoute] gives them,
/// the first with [controller] (the test presses its nodes).
RouteFactory _routesOf(Codelessly app, CodelesslyWidgetController controller) {
  final routes = CodelesslyWidget.onGenerateRoute(app);
  return (settings) => settings.name == '/' || settings.name == null
      ? CodelesslyPageRoute.of<void>(
          codelessly: app,
          settings: settings,
          builder: (_) => CodelesslyWidget(codelessly: app, controller: controller),
        )
      : routes(settings);
}

void main() {
  for (final MapEntry(key: name, value: host) in hosts.entries) {
    group('under a $name', () {
      late CodelesslyWidgetController controller;

      Future<_Routes> show(WidgetTester tester, Codelessly app) async {
        setScreen(tester, const Size(390, 844));
        addTearDown(app.dispose);
        final routes = _Routes();
        controller = CodelesslyWidgetController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(host(app, routes, controller));
        await settle(tester);
        expect(tester.takeException(), isNull);
        return routes;
      }

      CodelesslyWidgetController controllerOf(WidgetTester tester) => controller;

      testWidgets('a screen opens in a route of the SDK\'s own, with the platform\'s transition, and goes back',
          (tester) async {
        final routes = await show(tester, _app());
        expect(routes.pushed.single, isA<CodelesslyPageRoute<void>>());
        expect(routes.pushed.single, isNot(isA<MaterialPageRoute<dynamic>>()));
        unawaited(controllerOf(tester).trigger('next', 'click'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 200));
        // Mid way (the test's platform is Android: fade forwards, 450 ms).
        expect(tester.takeException(), isNull);
        expect(routes.pushed, hasLength(2));
        expect((routes.pushed.last as ModalRoute<dynamic>).animation!.value, inExclusiveRange(0, 1));
        await settle(tester);
        expect(routes.pushed, hasLength(2));
        final route = routes.pushed.last;
        expect(route, isA<CodelesslyPageRoute<dynamic>>());
        expect((route as CodelesslyPageRoute<dynamic>).transitions, CodelesslyPageTransitions.platform);
        expect(route.transitionDuration, const Duration(milliseconds: 450));
        route.navigator!.pop();
        await settle(tester);
        expect(tester.takeException(), isNull);
        expect(find.byType(NodeView), findsOneWidget);
      });

      testWidgets('a project\'s page transition can be any of the animation system\'s', (tester) async {
        const transitions =
            CodelesslyPageTransitions.animated(RouteTransition(preset: RouteTransitionPreset.fadeThrough));
        final routes = await show(tester, _app(config: const CodelesslyConfig(pageTransitions: transitions)));
        unawaited(controllerOf(tester).trigger('next', 'click'));
        await settle(tester);
        expect(tester.takeException(), isNull);
        final route = routes.pushed.last;
        expect(route, isA<CodelesslyRouteTransitionRoute<dynamic>>());
        expect((route as CodelesslyRouteTransitionRoute<dynamic>).transition.preset, RouteTransitionPreset.fadeThrough);
        route.navigator!.pop();
        await settle(tester);
        expect(tester.takeException(), isNull);
      });

      testWidgets('a native transition can be chosen by name on any platform', (tester) async {
        final routes = await show(
            tester, _app(config: const CodelesslyConfig(pageTransitions: CodelesslyPageTransitions.cupertino)));
        unawaited(controllerOf(tester).trigger('next', 'click'));
        await settle(tester);
        expect(routes.pushed.last.runtimeType.toString(), contains('CodelesslyPageRoute'));
        expect((routes.pushed.last as CodelesslyPageRoute<dynamic>).transitionDuration,
            const Duration(milliseconds: 500));
      });

      testWidgets('a dialog\'s barrier is called what the host says', (tester) async {
        final routes = await show(
            tester, _app(config: const CodelesslyConfig(labels: CodelesslyLabels(dismiss: 'Fermer'))));
        unawaited(controllerOf(tester).trigger('ask', 'click'));
        await settle(tester);
        expect(tester.takeException(), isNull);
        final dialog = routes.pushed.last as ModalRoute<dynamic>;
        expect(dialog, isA<RawDialogRoute<dynamic>>());
        expect(dialog.barrierLabel, 'Fermer');
        expect(dialog.transitionDuration, const Duration(milliseconds: 150));
      });

      testWidgets('a reorderable list reorders', (tester) async {
        await show(tester, _app());
        final controller = controllerOf(tester);
        List<String> order() => [for (final s in controller.read('songs') as List) (s as Map)['id'] as String];
        final list = controller.tree!.boxOf('songs')!;
        final first = list.localToGlobal(const Offset(195, 25));
        final drag = await tester.startGesture(first);
        await tester.pump(kPressTimeout);
        await drag.moveBy(const Offset(0, 20));
        await tester.pump();
        await drag.moveBy(const Offset(0, 110));
        await tester.pump();
        await drag.up();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(order().indexOf('s0'), greaterThan(1));
        expect(order().where((id) => id != 's0'), ['s1', 's2', 's3']);
      });
    });
  }
}
