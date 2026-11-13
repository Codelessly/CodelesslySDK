import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'present_support.dart';
import 'support.dart';

// A real project (rigcheck: screens with mobile, tablet and
// desktop canvases, navigation between them) shown by CodelesslyWidget.



/// The rigcheck fixture's JSON.
Map<String, Object?> rigcheckJson() =>
    (jsonDecode(utf8.decode(gzip.decode(File('test/fixtures/publish/rigcheck.json.gz').readAsBytesSync()))) as Map)
        .cast<String, Object?>();

// A canvas's body slot runs its own click reactions, whatever its type: a
// plain box as the body is clickable like a stack.

// A multi-step flow (onboarding, a survey) from existing primitives only: a
// variance whose current variant is bound to a step variable, next and back
// buttons that set it (next branching on an answer), and a progress bar
// bound to it. The guide's recipe (17-presenting-and-automations.md).


Json box(String id, {double x = 0, double y = 0, double w = 100, double h = 40, List<Json> onClick = const []}) => {
      'type': 'box',
      'layout': {'width': w, 'height': h, 'x': {'start': x}, 'y': {'start': y}},
      'decoration': {
        'fills': [
          {'color': '#FF888888'},
        ],
      },
      if (onClick.isNotEmpty)
        'actions': [
          {'trigger': {'type': 'click'}, 'actions': onClick},
        ],
    };

PublishLayout flow() => screen(
      'flow',
      width: 400,
      height: 800,
      variables: [
        const Variable(name: 'step', type: VariableType.integer, value: 0),
        const Variable(name: 'role', value: ''),
      ],
      children: ['progress', 'steps', 'next', 'back', 'pickPro'],
      extraNodes: {
        'progress': {
          'type': 'progressBar',
          'layout': {'width': 400, 'height': 4, 'x': {'start': 0}, 'y': {'start': 0}},
          'props': {'max': 1},
          'bind': {'props.value': r'${= (step + 1) / 3}'},
        },
        'steps': {
          'type': 'variance',
          'layout': {'width': 400, 'height': 600, 'x': {'start': 0}, 'y': {'start': 10}},
          'props': {
            'current': 'step0',
            'variants': [
              for (var i = 0; i < 3; i++)
                {
                  'id': 'step$i',
                  'name': 'Step $i',
                  'children': ['page$i'],
                },
            ],
          },
          'bind': {'props.current': r'step${step}'},
        },
        for (var i = 0; i < 3; i++) 'page$i': box('page$i', w: 400, h: 600),
        // Next: a pro user skips the middle step.
        'next': box('next', x: 280, y: 700, onClick: [
          {
            'type': 'if',
            'condition': {'left': r'${role}', 'op': 'equalsTo', 'right': 'pro'},
            'then': [
              {'type': 'setVariable', 'variable': 'step', 'value': r'${= min(step + 2, 2)}'},
            ],
            'else': [
              {'type': 'setVariable', 'variable': 'step', 'value': r'${= min(step + 1, 2)}'},
            ],
          },
        ]),
        'back': box('back', x: 20, y: 700, onClick: [
          {'type': 'setVariable', 'variable': 'step', 'value': r'${= max(step - 1, 0)}'},
        ]),
        'pickPro': box('pickPro', x: 150, y: 750, onClick: [
          {'type': 'setVariable', 'variable': 'role', 'value': 'pro'},
        ]),
      },
    );

void main() {
  {
    final bundle = fixture('rigcheck');
    final signIn = layoutWithCanvas(bundle, 'Sign in · M');
    final today = layoutWithCanvas(bundle, 'Today · M');

    Codelessly codelesslyFor({ActionRunner actions = const NavigationActionRunner(), PublishCache? cache, PublishLoader? loader}) =>
        Codelessly(
          config: CodelesslyConfig(projectId: 'rigcheck', actions: actions),
          loader: loader ?? MemoryPublishLoader(bundle),
          cache: cache,
          fonts: const NoFontFetcher(),
        );

    Future<CodelesslyWidgetController> pumpApp(WidgetTester tester, Codelessly codelessly, {String? layoutId, String? initialScreen}) async {
      final controller = CodelesslyWidgetController(layoutId: layoutId);
      addTearDown(controller.dispose);
      // A fresh app (a new home doesn't replace a navigator's routes).
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        home: CodelesslyWidget(codelessly: codelessly, controller: controller, initialScreen: initialScreen),
      ));
      await settle(tester);
      return controller;
    }

    testWidgets('the app shows its entry screen, on the canvas for the width', (tester) async {
      ignoreOverflows();
      for (final (width, canvas) in [(390.0, 'Sign in · M'), (834.0, 'Sign in · T'), (1440.0, 'Sign in · D')]) {
        setScreen(tester, Size(width, 900));
        final controller = await pumpApp(tester, codelesslyFor());
        expect(controller.layout!.id, bundle.model.entryLayoutId);
        expect(controller.canvasId, canvasNamed(signIn, canvas), reason: '$width');
        final view = tester.renderObject<RenderBox>(find.byType(NodeView));
        expect(view.size, Size(width, 900), reason: 'a responsive canvas fills the screen');
        expect(controller.tree!.boxOf(controller.canvasId!)!.rectIn(view), Offset.zero & Size(width, 900));
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('app variables are shared by every screen', (tester) async {
      ignoreOverflows();
      setScreen(tester, const Size(390, 844));
      // The model's (as the editor publishes them) and a layout's
      // `app_variables` scope.
      final scoped = PublishLayout.fromJson({
        ...signIn.toJson(),
        'variables': {
          'app_variables': [
            {'id': 'l', 'name': 'scoped', 'value': 'from the layout'},
          ],
        },
      });
      final b = PublishBundle(
        model: bundle.model.copyWith(variables: {
          'v': {'id': 'v', 'name': 'appCount', 'type': 'integer', 'value': 7},
        }),
        layouts: {...bundle.layouts, signIn.id: scoped},
      );
      final codelessly = Codelessly(
        config: const CodelesslyConfig(projectId: 'rigcheck', actions: NavigationActionRunner()),
        loader: MemoryPublishLoader(b),
        fonts: const NoFontFetcher(),
      );
      addTearDown(codelessly.dispose);
      final first = await pumpApp(tester, codelessly, layoutId: signIn.id);
      expect(first.scope!.read('appCount'), 7);
      expect(first.scope!.read('scoped'), 'from the layout');
      expect(setVariableIn(first.scope!, 'appCount', 12), isTrue);
      // Another screen reads what this one set.
      final second = await pumpApp(tester, codelessly, layoutId: today.id);
      expect(second.scope!.read('appCount'), 12);
      expect(second.scope!.read('scoped'), 'from the layout');
    });

    testWidgets('a screen reads what the app stores on the device, as it changes', (tester) async {
      ignoreOverflows();
      setScreen(tester, const Size(390, 844));
      final storage = MemoryLocalStorage();
      await storage.put('stationId', 'pillar');
      final codelessly = Codelessly(
        config: CodelesslyConfig(projectId: 'rigcheck', actions: const NavigationActionRunner(), services: Services(storage: storage)),
        loader: MemoryPublishLoader(bundle),
        fonts: const NoFontFetcher(),
      );
      addTearDown(codelessly.dispose);
      final controller = await pumpApp(tester, codelessly, layoutId: signIn.id);
      expect(controller.scope!.read('storage.stationId'), 'pillar');
      await storage.put('stationId', 'moss');
      expect(controller.scope!.read('storage.stationId'), 'moss');
    });

    testWidgets('the screen switches canvas when the width crosses a breakpoint', (tester) async {
      ignoreOverflows();
      setScreen(tester, const Size(390, 844));
      final codelessly = codelesslyFor();
      final controller = await pumpApp(tester, codelessly);
      expect(controller.canvasId, canvasNamed(signIn, 'Sign in · M'));
      expect(codelessly.route.value?.canvasId, controller.canvasId);
      // `screen` is the device.
      Object? screen(String key) => (controller.scope!.read('screen') as Map?)?[key];
      expect(screen('isMobile'), isTrue);
      expect(screen('width'), 390);
      expect(screen('orientation'), 'portrait');
      tester.view.physicalSize = const Size(1280, 800);
      await settle(tester);
      expect(screen('breakpoint'), 'desktop');
      expect(screen('isLandscape'), isTrue);
      expect(controller.canvasId, canvasNamed(signIn, 'Sign in · D'));
      expect(codelessly.route.value?.canvasId, controller.canvasId);
      // The same tree: the mobile canvas's boxes are let go.
      expect(controller.tree!.boxOf(canvasNamed(signIn, 'Sign in · D'))!.attached, isTrue);
    });

    testWidgets('a tap on a tab replaces the screen', (tester) async {
      ignoreOverflows();
      setScreen(tester, const Size(390, 844));
      final codelessly = codelesslyFor();
      final shop = layoutWithCanvas(bundle, 'Shop · M');
      final controller = await pumpApp(tester, codelessly, layoutId: today.id);
      await tapNode(tester, controller, nodeNamed(today, canvasNamed(today, 'Today · M'), 'Tab Shop'));
      expect(codelessly.route.value?.layoutId, shop.id);
      expect(codelessly.route.value?.canvasId, canvasNamed(shop, 'Shop · M'));
      // Replaced: nothing to go back to.
      expect(find.byType(CodelesslyWidget), findsOneWidget);
      expect(tester.state<NavigatorState>(find.byType(Navigator)).canPop(), isFalse);
    });

    testWidgets('a sign-in button validates, waits and then navigates', (tester) async {
      ignoreOverflows();
      setScreen(tester, const Size(390, 844));
      final codelessly = codelesslyFor(actions: const CodelesslyActions());
      final controller = await pumpApp(tester, codelessly);
      expect(controller.layout!.id, signIn.id);
      final button = nodeNamed(signIn, canvasNamed(signIn, 'Sign in · M'), 'Sign in button');
      await tapNode(tester, controller, button);
      // The demo's slow network: a delay before the next screen.
      await tester.pump(const Duration(seconds: 4));
      await settle(tester);
      expect(codelessly.route.value?.layoutId, today.id);
      expect(tester.state<NavigatorState>(find.byType(Navigator)).canPop(), isFalse);
    });

    testWidgets('by default bindings and every action work', (tester) async {
      expect(const CodelesslyConfig().expressions, isA<Expressions>());
      expect(const CodelesslyConfig().actions, isA<CodelesslyActions>());
      expect(Codelessly(config: const CodelesslyConfig()).services, isA<Services>());
    });

    testWidgets('navigation goes on from screen to screen: a tab, a push and a pop', (tester) async {
      ignoreOverflows();
      setScreen(tester, const Size(390, 844));
      final codelessly = codelesslyFor();
      final fleet = layoutWithCanvas(bundle, 'Fleet · M');
      final controller = await pumpApp(tester, codelessly, layoutId: today.id);
      await tapNode(tester, controller, nodeNamed(today, canvasNamed(today, 'Today · M'), 'Tab Fleet'));
      expect(codelessly.route.value?.layoutId, fleet.id);

      // A push leaves the screen beneath; pop goes back to it.
      final home = await pumpApp(tester, codelessly, layoutId: today.id);
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      unawaited(home.actionContext!.navigate({'type': 'navigate', 'to': canvasNamed(fleet, 'Fleet · M')}));
      await settle(tester);
      expect(codelessly.route.value?.layoutId, fleet.id);
      expect(navigator.canPop(), isTrue);
      await home.actionContext!.navigate({'type': 'navigate', 'mode': 'pop'});
      await settle(tester);
      expect(navigator.canPop(), isFalse);
      expect(find.byType(CodelesslyWidget), findsOneWidget);
    });

    testWidgets('a screen opens already drawn: navigation loads it first', (tester) async {
      ignoreOverflows();
      setScreen(tester, const Size(390, 844));
      final codelessly = codelesslyFor();
      final fleet = layoutWithCanvas(bundle, 'Fleet · M');
      final home = await pumpApp(tester, codelessly, layoutId: today.id);
      expect(codelessly.layout(fleet.id), isNull, reason: 'not loaded yet');
      unawaited(home.actionContext!.navigate({'type': 'navigate', 'to': canvasNamed(fleet, 'Fleet · M')}));
      // Frame by frame until the push: the new screen is never a loading one.
      for (var i = 0; i < 60 && find.byType(CodelesslyWidget).evaluate().length < 2; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(find.byType(CodelesslyLoadingScreen), findsNothing, reason: 'frame $i');
      }
      expect(find.byType(CodelesslyWidget), findsNWidgets(2));
      expect(find.byType(CodelesslyLoadingScreen), findsNothing);
      await settle(tester);

      // A widget for a layout already loaded draws it in its first frame.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(MaterialApp(home: CodelesslyWidget(codelessly: codelessly, layoutId: fleet.id)));
      expect(find.byType(CodelesslyLoadingScreen), findsNothing);
      expect(find.byType(NodeView), findsOneWidget);
    });

    testWidgets('a navigation plays its page transition, and a link by id shows the screen\'s path', (tester) async {
      ignoreOverflows();
      setScreen(tester, const Size(390, 844));
      final codelessly = codelesslyFor();
      final fleet = layoutWithCanvas(bundle, 'Fleet · M');
      final home = await pumpApp(tester, codelessly, layoutId: today.id);
      unawaited(home.actionContext!.navigate({
        'type': 'navigate', 'to': fleet.id, 'transition': 'fade', 'transitionMs': 400, //
      }));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      final route = ModalRoute.of(tester.element(find.byType(CodelesslyWidget).last))!;
      expect(route, isA<CodelesslyPageTransitionRoute<void>>());
      expect((route as CodelesslyPageTransitionRoute).transitionDuration, const Duration(milliseconds: 400));
      expect(route.animation!.value, closeTo(0.5, 0.05));
      expect(find.byType(FadeTransition), findsWidgets);
      await settle(tester);
      expect(codelessly.route.value?.layoutId, fleet.id);
      // The platform's on the web is none.
      expect(webTransition(PageTransition.platform, isWeb: true), PageTransition.none);
      expect(webTransition(PageTransition.platform, isWeb: false), PageTransition.platform);

      // onGenerateRoute names a link by id at the screen's path.
      final model = codelessly.publishModel!;
      final factory = CodelesslyWidget.onGenerateRoute(codelessly);
      final entry = model.resolveLayoutId(model.entryLayoutId!)!;
      final entryCanvas = model.layouts[entry]!.canvases.first.id;
      expect(factory(RouteSettings(name: '/$entryCanvas'))!.settings.name, '/');
    });

    testWidgets('a reset clears the history and leaves the base screen beneath', (tester) async {
      ignoreOverflows();
      setScreen(tester, const Size(390, 844));
      final codelessly = codelesslyFor();
      final home = await pumpApp(tester, codelessly, layoutId: today.id);
      final fleet = layoutWithCanvas(bundle, 'Fleet · M');
      final shop = layoutWithCanvas(bundle, 'Shop · M');
      final navigate = home.actionContext!.navigate;
      unawaited(navigate({'type': 'navigate', 'to': fleet.id}));
      unawaited(navigate({'type': 'navigate', 'to': shop.id}));
      await settle(tester);
      await navigate({
        'type': 'navigate', 'mode': 'reset', 'to': shop.id, 'base': signIn.id, //
      });
      await settle(tester);
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      expect(codelessly.route.value?.layoutId, shop.id);
      navigator.pop();
      await settle(tester);
      expect(codelessly.route.value?.layoutId, signIn.id);
      expect(navigator.canPop(), isFalse);
    });

    testWidgets('the app can open on a canvas by id or on a screen by name', (tester) async {
      ignoreOverflows();
      setScreen(tester, const Size(1440, 900));
      final byCanvas = await pumpApp(tester, codelesslyFor(), layoutId: canvasNamed(today, 'Today · T'));
      expect(byCanvas.layout!.id, today.id);
      // The breakpoint still picks the canvas.
      expect(byCanvas.canvasId, canvasNamed(today, 'Today · D'));
      await tester.pumpWidget(const SizedBox());
      final byName = await pumpApp(tester, codelesslyFor(), initialScreen: '/vehicle-·-d');
      expect(byName.error, isNull);
      expect(byName.layout!.id, layoutWithCanvas(bundle, 'Vehicle · M').id);
      await tester.pumpWidget(const SizedBox());
      final unknown = await pumpApp(tester, codelesslyFor(), initialScreen: 'kraken');
      expect(unknown.layout!.id, bundle.model.entryLayoutId);
      // The root with a query: the entry screen, opened with its params.
      final rootQuery = await pumpApp(tester, codelesslyFor(), initialScreen: '/?state=empty');
      expect(rootQuery.layout!.id, bundle.model.entryLayoutId);
      expect(rootQuery.read('route.state'), 'empty');
      // A link's escapes are read once (`%3A` is `:`), and what a typed
      // location holds raw still works.
      await tester.pumpWidget(const SizedBox());
      final encoded = await pumpApp(tester, codelesslyFor(), initialScreen: '/?state=moss%3A1%3Asun%2Cowl%3A2');
      expect(encoded.read('route.state'), 'moss:1:sun,owl:2');
      await tester.pumpWidget(const SizedBox());
      final raw = await pumpApp(tester, codelesslyFor(), initialScreen: '/?state=moss:1 sun,100%');
      expect(raw.read('route.state'), 'moss:1 sun,100%');
    });

    testWidgets("a link's parameters set the app variables of the same name", (tester) async {
      ignoreOverflows();
      setScreen(tester, const Size(390, 844));
      final b = PublishBundle(
        model: bundle.model.copyWith(variables: {
          'a': {'id': 'a', 'name': 'loadState', 'type': 'text', 'value': 'ready'},
          'b': {'id': 'b', 'name': 'queue', 'type': 'list', 'value': ['x']},
          'c': {'id': 'c', 'name': 'open', 'type': 'boolean', 'value': false},
          'd': {'id': 'd', 'name': 'untouched', 'type': 'integer', 'value': 3},
        }),
        layouts: bundle.layouts,
      );
      Codelessly app() => Codelessly(
            config: const CodelesslyConfig(projectId: 'rigcheck', actions: NavigationActionRunner()),
            loader: MemoryPublishLoader(b),
            fonts: const NoFontFetcher(),
          );
      final linked = app();
      addTearDown(linked.dispose);
      final c = await pumpApp(tester, linked, initialScreen: '/?loadState=error&queue=%5B%5D&open=true&other=1');
      expect(c.scope!.read('loadState'), 'error');
      expect(c.scope!.read('queue'), isEmpty);
      expect(c.scope!.read('open'), isTrue);
      expect(c.scope!.read('untouched'), 3);
      expect(c.read('route.other'), '1');
      // Opened by id, not by a link: the defaults.
      await tester.pumpWidget(const SizedBox());
      final plain = app();
      addTearDown(plain.dispose);
      final d = await pumpApp(tester, plain, layoutId: bundle.model.entryLayoutId);
      expect(d.scope!.read('loadState'), 'ready');
    });

    testWidgets('a canvas can be forced, and data and parameters given to the widget can be read by the screen', (tester) async {
      ignoreOverflows();
      setScreen(tester, const Size(390, 844));
      final codelessly = codelesslyFor()..setData('user', {'name': 'Ada'});
      final controller = CodelesslyWidgetController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(MaterialApp(
        home: CodelesslyWidget(
          codelessly: codelessly,
          controller: controller,
          layoutId: today.id,
          canvasId: canvasNamed(today, 'Today · D'),
          params: const {'unit': 'D-1042'},
        ),
      ));
      await settle(tester);
      expect(controller.canvasId, canvasNamed(today, 'Today · D'));
      expect(controller.read('route.unit'), 'D-1042');
      expect(controller.read('data.user.name'), 'Ada');
      controller.setVariable('count', 3);
      expect(controller.read('count'), 3);
    });

    testWidgets('a variable named like a data key starts at that value and follows it', (tester) async {
      ignoreOverflows();
      setScreen(tester, const Size(390, 844));
      final canvasId = canvasNamed(today, 'Today · D');
      // Today's layout with an integer variable `count` on the canvas.
      final json = rigcheckJson();
      final layouts = (json['layouts'] as Map).cast<String, Object?>();
      layouts[today.id] = {
        ...(layouts[today.id] as Map).cast<String, Object?>(),
        'variables': {
          canvasId: [
            {'id': 'v_count', 'name': 'count', 'type': 'integer', 'value': 0},
          ],
        },
      };
      final withVariable = decodeBundle(utf8.encode(jsonEncode(json)));
      final controller = CodelesslyWidgetController();
      addTearDown(controller.dispose);
      Widget app(int value) => MaterialApp(
            home: CodelesslyWidget(
              codelessly: codelesslyFor(loader: MemoryPublishLoader(withVariable)),
              controller: controller,
              layoutId: today.id,
              canvasId: canvasId,
              data: {'count': value},
            ),
          );
      await tester.pumpWidget(app(41));
      await settle(tester);
      expect(controller.read('count'), 41);
      expect(controller.read('data.count'), 41);
      await tester.pumpWidget(app(42));
      await settle(tester);
      expect(controller.read('count'), 42);
      // Changed on the screen: a data refresh leaves it.
      controller.setVariable('count', 7);
      await tester.pumpWidget(app(43));
      await settle(tester);
      expect(controller.read('count'), 7);
    });

    testWidgets('the app shows loading, then an error for a layout that does not exist', (tester) async {
      setScreen(tester, const Size(390, 844));
      final codelessly = codelesslyFor();
      await tester.pumpWidget(MaterialApp(home: CodelesslyWidget(codelessly: codelessly, layoutId: 'nope')));
      expect(find.byType(CodelesslyLoadingScreen), findsOneWidget);
      await settle(tester);
      expect(find.byType(CodelesslyErrorScreen), findsOneWidget);
      await tester.pumpWidget(MaterialApp(
        home: CodelesslyWidget(
          codelessly: codelessly,
          layoutId: 'nope',
          errorBuilder: (_, e) => Text('failed: ${e is PublishLoadException}'),
        ),
      ));
      await settle(tester);
      expect(find.text('failed: true'), findsOneWidget);
    });

    testWidgets('an auto-scaling screen lays out at its design width, scaled to the device', (tester) async {
      ignoreOverflows();
      setScreen(tester, const Size(780, 1000));
      final account = layoutWithCanvas(bundle, 'Account');
      final canvasId = account.canvasIds.single;
      final canvas = account.document[canvasId]!;
      final scaled = account.copyWith(
        document: account.document.copyWith(nodes: {
          ...account.document.nodes,
          canvasId: canvas.copyWith(props: canvas.props.set(CanvasProps.scaleMode, ScaleMode.autoScale)),
        }),
      );
      final b = PublishBundle(model: bundle.model, layouts: {...bundle.layouts, account.id: scaled});
      final codelessly = Codelessly.fromBundle(b, fonts: const NoFontFetcher());
      final controller = CodelesslyWidgetController(layoutId: account.id);
      addTearDown(controller.dispose);
      await tester.pumpWidget(MaterialApp(home: CodelesslyWidget(codelessly: codelessly, controller: controller)));
      await settle(tester);
      final view = tester.renderObject<RenderBox>(find.byType(NodeView));
      // 420 wide by design: laid out at 420, shown 780 wide.
      expect(view.size.width, 420);
      final shown = MatrixUtils.transformRect(view.getTransformTo(null), Offset.zero & view.size);
      expect(shown.width, closeTo(780, 0.01));
      expect(shown.top, 0);
    });

    testWidgets('every screen of a second sample project renders', (tester) async {
      ignoreOverflows();
      final linewatch = fixture('linewatch');
      final codelessly = Codelessly.fromBundle(linewatch, fonts: const NoFontFetcher());
      for (final layout in linewatch.layouts.values) {
        final canvas = layout.document[layout.canvasIds.single]!;
        setScreen(tester, Size(canvas.layout.width.value, canvas.layout.height.value));
        debugPrint('LAYOUT ${canvas.name}');
        final controller = CodelesslyWidgetController(layoutId: layout.id);
        await tester.pumpWidget(MaterialApp(home: CodelesslyWidget(codelessly: codelessly, controller: controller)));
        await settle(tester);
        expect(controller.error, isNull, reason: canvas.name);
        expect(controller.canvasId, canvas.id);
        expect(controller.tree!.length, greaterThan(5), reason: canvas.name);
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      }
    });
  }

  group('a screen\'s body', () {
    for (final bodyType in ['stack', 'box']) {
      for (final size in ['fill', 'fixed']) {
        testWidgets('a $bodyType used as a screen\'s body ($size size) runs its click reactions', (tester) async {
          final layout = PublishLayout.fromJson({
            'schema': 2,
            'id': 'home',
            'roots': ['c'],
            'nodes': {
              'c': {
                'type': 'canvas',
                'slots': {'body': 'b'},
                'layout': {'width': 400, 'height': 600},
              },
              'b': {
                'type': bodyType,
                'layout': size == 'fill'
                    ? {'width': {'fill': 400}, 'height': {'fill': 600}}
                    : {'width': 400, 'height': 600},
                'decoration': {
                  'fills': [
                    {'type': 'solid', 'color': '#FF336699'},
                  ],
                },
                'actions': [
                  {
                    'trigger': {'type': 'click'},
                    'actions': [
                      {'type': 'setVariable', 'variable': 'taps', 'op': 'add', 'value': '1'},
                    ],
                  },
                ],
              },
            },
            'variables': {
              'c': [const Variable(name: 'taps', type: VariableType.integer, value: 0).toJson()],
            },
          });
          final app = Codelessly.fromBundle(
            PublishBundle(
              model: PublishModel(projectId: 'p', entryLayoutId: 'home', layouts: {'home': PublishLayoutInfo.of(layout)}),
              layouts: {'home': layout},
            ),
            config: CodelesslyConfig(services: Services(analytics: const NoAnalytics())),
            fonts: const NoFontFetcher(),
          );
          final controller = CodelesslyWidgetController();
          addTearDown(controller.dispose);
          await tester.pumpWidget(MaterialApp(home: CodelesslyWidget(codelessly: app, layoutId: 'home', controller: controller)));
          await tester.pumpAndSettle();
          await tester.tapAt(const Offset(200, 300));
          await tester.pumpAndSettle();
          expect(controller.read('taps'), 1);
          await tester.pumpWidget(const SizedBox());
          app.dispose();
        });
      }
    }
  });

  group('a multi-step flow', () {
    testWidgets('a step variable drives which step shows, the progress and a branching next', (tester) async {
      setSize(tester);
      final codelessly = Codelessly.fromBundle(bundleOf([flow()]), fonts: const NoFontFetcher());
      addTearDown(codelessly.dispose);
      final controller = CodelesslyWidgetController(layoutId: 'flow');
      addTearDown(controller.dispose);
      await tester.pumpWidget(MaterialApp(home: CodelesslyWidget(codelessly: codelessly, controller: controller)));
      await settle(tester);

      String current() => controller.node('steps')!.props.get(VarianceProps.current);
      double progress() => controller.node('progress')!.props.get(ProgressBarProps.value);

      expect(current(), 'step0');
      expect(progress(), closeTo(1 / 3, 1e-9));
      await controller.trigger('next', 'click');
      await settle(tester);
      expect(current(), 'step1');
      expect(progress(), closeTo(2 / 3, 1e-9));
      await controller.trigger('back', 'click');
      await controller.trigger('pickPro', 'click');
      await controller.trigger('next', 'click');
      await settle(tester);
      expect(controller.read('step'), 2);
      expect(current(), 'step2');
      expect(progress(), closeTo(1, 1e-9));
    });
  });
}
