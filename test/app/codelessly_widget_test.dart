// A migrated real project (rigcheck: screens with mobile, tablet and
// desktop canvases, navigation between them) shown by CodelesslyWidget.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

/// The rigcheck fixture's JSON.
Map<String, Object?> rigcheckJson() =>
    (jsonDecode(utf8.decode(gzip.decode(File('test/fixtures/publish/rigcheck.json.gz').readAsBytesSync()))) as Map)
        .cast<String, Object?>();

void main() {
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

  testWidgets('shows the entry screen, its canvas picked by the width', (tester) async {
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
    // The model's (as the v2 editor publishes them) and a converted v1
    // publish's `app_variables` scope in a layout.
    final legacy = PublishLayout.fromJson({
      ...signIn.toJson(),
      'variables': {
        'app_variables': [
          {'id': 'l', 'name': 'legacy', 'value': 'from v1'},
        ],
      },
    });
    final b = PublishBundle(
      model: bundle.model.copyWith(variables: {
        'v': {'id': 'v', 'name': 'appCount', 'type': 'integer', 'value': 7},
      }),
      layouts: {...bundle.layouts, signIn.id: legacy},
    );
    final codelessly = Codelessly(
      config: const CodelesslyConfig(projectId: 'rigcheck', actions: NavigationActionRunner()),
      loader: MemoryPublishLoader(b),
      fonts: const NoFontFetcher(),
    );
    addTearDown(codelessly.dispose);
    final first = await pumpApp(tester, codelessly, layoutId: signIn.id);
    expect(first.scope!.read('appCount'), 7);
    expect(first.scope!.read('legacy'), 'from v1');
    expect(setVariableIn(first.scope!, 'appCount', 12), isTrue);
    // Another screen reads what this one set.
    final second = await pumpApp(tester, codelessly, layoutId: today.id);
    expect(second.scope!.read('appCount'), 12);
    expect(second.scope!.read('legacy'), 'from v1');
  });

  testWidgets('storage reads what the app keeps on the device, live', (tester) async {
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

  testWidgets('switches canvas when the width crosses a breakpoint', (tester) async {
    ignoreOverflows();
    setScreen(tester, const Size(390, 844));
    final codelessly = codelesslyFor();
    final controller = await pumpApp(tester, codelessly);
    expect(controller.canvasId, canvasNamed(signIn, 'Sign in · M'));
    expect(codelessly.route.value?.canvasId, controller.canvasId);
    // `screen` is the device (SDK 8.x's screenVariableValue).
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

  testWidgets('a tap runs the reaction: a tab replaces the screen', (tester) async {
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

  testWidgets('the sign in button validates, waits and navigates (inside a conditional)', (tester) async {
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

  testWidgets('by default, the runtime runs: bindings and every action', (tester) async {
    expect(const CodelesslyConfig().expressions, isA<Expressions>());
    expect(const CodelesslyConfig().actions, isA<CodelesslyActions>());
    expect(Codelessly(config: const CodelesslyConfig()).services, isA<Services>());
  });

  testWidgets('without an action runner, a tap does nothing', (tester) async {
    ignoreOverflows();
    setScreen(tester, const Size(390, 844));
    final codelessly = codelesslyFor(actions: const NoopActionRunner());
    final controller = await pumpApp(tester, codelessly, layoutId: today.id);
    await tapNode(tester, controller, nodeNamed(today, canvasNamed(today, 'Today · M'), 'Tab Shop'));
    expect(codelessly.route.value?.layoutId, today.id);
  });

  testWidgets('navigates on: Today → Fleet (a tab), and push and pop', (tester) async {
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

  testWidgets('a navigation plays its page transition; a link by id is named at the screen\'s path', (tester) async {
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

  testWidgets('reset clears the history, leaving its base screen beneath', (tester) async {
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

  testWidgets('opens a layout by canvas id, and a screen by its name', (tester) async {
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
  });

  testWidgets('a canvas can be forced; data and params reach the scope', (tester) async {
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

  testWidgets('a variable named like a data key starts at it and follows it (SDK 8.x)', (tester) async {
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

  testWidgets('loading, then an error for a layout that does not exist', (tester) async {
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

  testWidgets('uses the scope or the default instance when given none', (tester) async {
    ignoreOverflows();
    setScreen(tester, const Size(390, 844));
    final scoped = codelesslyFor();
    await tester.pumpWidget(MaterialApp(home: CodelesslyScope(codelessly: scoped, child: const CodelesslyWidget())));
    await settle(tester);
    expect(scoped.route.value?.layoutId, signIn.id);

    final fallback = codelesslyFor();
    Codelessly.setDefault(fallback);
    addTearDown(() => Codelessly.setDefault(null));
    await tester.pumpWidget(MaterialApp(home: CodelesslyWidget(layoutId: today.id)));
    await settle(tester);
    expect(fallback.route.value?.layoutId, today.id);
  });

  testWidgets('an autoScale canvas lays out at its design width, scaled to the screen', (tester) async {
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

  testWidgets('every screen of a second project renders', (tester) async {
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

