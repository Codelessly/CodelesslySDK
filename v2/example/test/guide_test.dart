// The testing chapter of the developer guide, as real tests: a project
// built in memory, shown with CodelesslyWidget and driven through its
// controller. They also check what the guide says about navigation, deep
// links and external components.
import 'dart:async';

import 'package:codelessly_example/snippets.dart';
import 'package:codelessly_sdk_v2/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A project of two screens: `home` (a button that opens `details` with a
/// param, and an external component) and `details` at the path
/// `item/:id`.
PublishBundle twoScreens() => PublishBundle.fromJson({
      'model': {
        'schema': 2,
        'projectId': 'test-project',
        'entryLayoutId': 'home',
        'layoutIDMap': {'start': 'home'},
        'layouts': {
          'home': {
            'canvases': [
              {'id': 'home-canvas', 'name': 'Home'},
            ],
          },
          'details': {
            'canvases': [
              {'id': 'details-canvas', 'name': 'Item details', 'path': 'item/:id'},
            ],
          },
        },
      },
      'layouts': {
        'home': {
          'schema': 2,
          'id': 'home',
          'roots': ['home-canvas'],
          'nodes': {
            'home-canvas': {
              'type': 'canvas',
              'name': 'Home',
              'slots': {'body': 'home-column'},
              'layout': {'width': 390, 'height': 844},
            },
            'home-column': {
              'type': 'column',
              'children': ['open', 'map'],
              'layout': {
                'width': {'fill': 390},
                'height': {'fill': 844},
              },
            },
            'open': {
              'type': 'filledButton',
              'layout': {'width': 160, 'height': 44},
              'props': {'label': 'Open'},
              'actions': [
                {
                  'id': 'r1',
                  'trigger': {'type': 'click'},
                  'actions': [
                    {
                      'type': 'navigate',
                      'to': 'details-canvas',
                      'params': {'id': '42'},
                    },
                  ],
                },
              ],
            },
            'map': {
              'type': 'external',
              'layout': {'width': 200, 'height': 100},
              'props': {'builderId': 'map'},
            },
          },
        },
        'details': {
          'schema': 2,
          'id': 'details',
          'roots': ['details-canvas'],
          'paths': {'details-canvas': 'item/:id'},
          'nodes': {
            'details-canvas': {
              'type': 'canvas',
              'name': 'Item details',
              'slots': {'body': 'label'},
              'layout': {'width': 390, 'height': 844},
            },
            'label': {
              'type': 'text',
              'layout': {
                'width': {'hug': 100},
                'height': {'hug': 20},
              },
              'props': {'text': r'Item ${route.id}'},
            },
          },
        },
      },
    });

/// An instance for tests: no network (fonts aren't fetched).
Codelessly testCodelessly({CodelesslyConfig config = const CodelesslyConfig()}) =>
    Codelessly.fromBundle(twoScreens(), config: config, fonts: const NoFontFetcher());

/// Screens with looping animations never settle: pump a second of frames.
Future<void> frames(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('shows the entry screen, and a layout by id, custom id or canvas id', (tester) async {
    final codelessly = testCodelessly();
    addTearDown(codelessly.dispose);
    final controller = CodelesslyWidgetController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(MaterialApp(home: CodelesslyWidget(codelessly: codelessly, controller: controller)));
    await frames(tester);
    expect(controller.isLoaded, isTrue);
    expect(controller.layout!.id, 'home');
    expect(controller.canvasId, 'home-canvas');

    for (final id in ['details', 'details-canvas']) {
      controller.layoutId = id;
      await frames(tester);
      expect(controller.layout!.id, 'details', reason: id);
    }
    controller.layoutId = 'start'; // A custom id.
    await frames(tester);
    expect(controller.layout!.id, 'home');
  });

  testWidgets('a tap navigates: the next screen reads its params', (tester) async {
    final codelessly = testCodelessly();
    addTearDown(codelessly.dispose);
    final controller = CodelesslyWidgetController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(home: CodelesslyWidget(codelessly: codelessly, controller: controller)));
    await frames(tester);

    // A push completes when its screen is popped (the chain's next action
    // reads the pop's result), so the trigger isn't awaited here.
    unawaited(controller.trigger('open', 'click'));
    await frames(tester);
    expect(codelessly.route.value, const CodelesslyRoute('details', 'details-canvas', {'id': '42'}));

    // Back to the first screen.
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await frames(tester);
    expect(codelessly.route.value!.layoutId, 'home');
  });

  testWidgets('onNavigate handles a navigation first', (tester) async {
    final codelessly = testCodelessly();
    addTearDown(codelessly.dispose);
    final controller = CodelesslyWidgetController();
    addTearDown(controller.dispose);
    final requests = <NavigationRequest>[];
    await tester.pumpWidget(MaterialApp(
      home: CodelesslyWidget(
        codelessly: codelessly,
        controller: controller,
        onNavigate: (context, request) {
          requests.add(request);
          return true;
        },
      ),
    ));
    await frames(tester);
    await controller.trigger('open', 'click');
    await frames(tester);
    expect(requests.single.destinationId, 'details-canvas');
    expect(requests.single.params, {'id': '42'});
    expect(requests.single.type, NavigationType.push);
    expect(codelessly.route.value!.layoutId, 'home', reason: 'handled: the SDK did not navigate');
  });

  testWidgets('a deep link opens a screen by its path, with the path\'s params', (tester) async {
    final codelessly = testCodelessly();
    addTearDown(codelessly.dispose);
    await tester.pumpWidget(MaterialApp(
      onGenerateRoute: CodelesslyWidget.onGenerateRoute(codelessly),
      initialRoute: '/item/7',
    ));
    await frames(tester);
    expect(codelessly.route.value!.layoutId, 'details');
    expect(codelessly.route.value!.params, {'id': '7'});
  });

  testWidgets('initialScreen: a path with a query, or a screen name', (tester) async {
    final codelessly = testCodelessly();
    addTearDown(codelessly.dispose);
    final controller = CodelesslyWidgetController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
      home: CodelesslyWidget(codelessly: codelessly, controller: controller, initialScreen: '/item/9?tab=specs'),
    ));
    await frames(tester);
    expect(controller.layout!.id, 'details');
    expect(controller.read('route.id'), '9');
    expect(controller.read('route.tab'), 'specs');

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(MaterialApp(
      home: CodelesslyWidget(codelessly: codelessly, controller: controller, initialScreen: 'item-details'),
    ));
    await frames(tester);
    expect(controller.layout!.id, 'details');
  });

  testWidgets('external components above the navigator reach every screen', (tester) async {
    final codelessly = testCodelessly();
    addTearDown(codelessly.dispose);
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => ExternalComponents(
        builders: {'map': (context) => const Text('the app\'s map')},
        child: child!,
      ),
      home: CodelesslyWidget(codelessly: codelessly),
    ));
    await frames(tester);
    expect(find.text('the app\'s map'), findsOneWidget);
  });

  testWidgets('a layout that does not exist shows the error builder', (tester) async {
    final codelessly = testCodelessly();
    addTearDown(codelessly.dispose);
    await tester.pumpWidget(MaterialApp(
      home: CodelesslyWidget(
        codelessly: codelessly,
        layoutId: 'nope',
        loadingBuilder: (_) => const Text('loading'),
        errorBuilder: (_, error) => Text('failed: ${error is PublishLoadException}'),
      ),
    ));
    expect(find.text('loading'), findsOneWidget);
    await frames(tester);
    expect(find.text('failed: true'), findsOneWidget);
  });

  testWidgets('sizing: fill takes the box, design keeps the canvas size', (tester) async {
    final codelessly = testCodelessly();
    addTearDown(codelessly.dispose);
    Future<Size> sizeWith(CanvasSizing sizing) async {
      await tester.pumpWidget(MaterialApp(
        home: Center(
          child: SizedBox(
            width: 600,
            height: 500,
            child: Align(
              alignment: Alignment.topLeft,
              child: CodelesslyWidget(codelessly: codelessly, layoutId: 'details', sizing: sizing),
            ),
          ),
        ),
      ));
      await frames(tester);
      return tester.getSize(find.byType(CanvasViewportBox));
    }

    expect(await sizeWith(CanvasSizing.fill), const Size(600, 500));
    expect(await sizeWith(CanvasSizing.design), const Size(390, 500), reason: 'design width, height capped by the box');
    expect(await sizeWith(CanvasSizing.fillWidth), const Size(600, 500));
  });

  testWidgets('static layouts ignore taps', (tester) async {
    final codelessly = testCodelessly(config: const CodelesslyConfig(actions: NoopActionRunner()));
    addTearDown(codelessly.dispose);
    final controller = CodelesslyWidgetController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(home: CodelesslyWidget(codelessly: codelessly, controller: controller)));
    await frames(tester);
    await controller.trigger('open', 'click');
    await frames(tester);
    expect(codelessly.route.value!.layoutId, 'home');
  });

  test('the instance\'s status: empty, loaded, and loaded again after a reset', () async {
    final codelessly = testCodelessly();
    addTearDown(codelessly.dispose);
    expect(codelessly.status, isA<CEmpty>());
    await loadEagerly(codelessly);
    expect(codelessly.status, isA<CLoaded>());
    expect(codelessly.publishModel!.projectId, 'test-project');
    await reload(codelessly);
    expect(codelessly.status, isA<CLoaded>());
  });
}
