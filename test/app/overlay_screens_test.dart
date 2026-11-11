// An overlay screen (CanvasProps.overlay, listed in the model's
// overlayLayoutIds) is drawn above every screen, outside navigation: it
// persists (same state) while the screens under it change, lets taps
// through its empty parts, can navigate the screens below, and leaves the
// app's current route alone.
import 'dart:async';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

/// A one-canvas layout [id]: a full-screen stack holding a 390×100 button
/// `${id}Button` at the top (or the bottom) that runs [click] when tapped.
PublishLayout _screen(String id, {List<Map<String, Object?>> click = const [], bool overlay = false, bool atBottom = false}) =>
    PublishLayout.fromJson({
      'schema': 2,
      'id': id,
      'roots': ['${id}C'],
      'nodes': {
        '${id}C': {
          'type': 'canvas',
          'name': id,
          'slots': {'body': '${id}Body'},
          'layout': {'width': 390, 'height': 844},
          if (overlay) 'props': {'overlay': true},
          // A screen has a background; the overlay has none, so its empty
          // parts let taps through.
          if (!overlay) 'decoration': {'fills': [{'color': '#FFFFFFFF'}]},
        },
        '${id}Body': {
          'type': 'stack',
          'children': ['${id}Button'],
          'layout': {'width': {'fill': 390}, 'height': {'fill': 844}},
        },
        '${id}Button': {
          'type': 'box',
          'decoration': {'fills': [{'color': '#FF334455'}]},
          'layout': {
            'width': 390,
            'height': 100,
            'x': {'start': 0},
            'y': atBottom ? {'end': 0} : {'start': 0},
          },
          'actions': [
            {'trigger': {'type': 'click'}, 'actions': click},
          ],
        },
      },
    });

PublishBundle _bundle({bool withOverlay = true}) {
  final layouts = {
    for (final l in [
      _screen('home', click: [{'type': 'navigate', 'to': 'detail'}]),
      _screen('detail'),
      _screen('other'),
      _screen('player', overlay: true, atBottom: true, click: [{'type': 'navigate', 'mode': 'replace', 'to': 'other'}]),
    ])
      l.id: l,
  };
  return PublishBundle(
    model: PublishModel(
      projectId: 'p',
      entryLayoutId: 'home',
      layouts: {for (final l in layouts.values) l.id: PublishLayoutInfo.of(l)},
      overlayLayoutIds: [if (withOverlay) 'player'],
    ),
    layouts: layouts,
  );
}

void main() {
  late Codelessly app;

  setUp(() {
    app = Codelessly.fromBundle(_bundle());
  });
  tearDown(() => app.dispose());

  Finder overlayScreens() => find.byType(OverlayScreenScope);

  /// The overlay screen's state: the same object while it persists.
  State overlayState(WidgetTester tester) =>
      tester.state(find.descendant(of: overlayScreens(), matching: find.byType(CodelesslyWidget)));

  NavigatorState navigator(WidgetTester tester) => tester.state<NavigatorState>(find.byType(Navigator));

  Future<CodelesslyWidgetController> pumpApp(WidgetTester tester) async {
    setScreen(tester, const Size(390, 844));
    final controller = CodelesslyWidgetController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(home: CodelesslyWidget(codelessly: app, controller: controller)));
    await settle(tester);
    return controller;
  }

  testWidgets('the overlay is above the screen, without taking its route', (tester) async {
    await pumpApp(tester);
    expect(overlayScreens(), findsOneWidget);
    expect(tester.widget<OverlayScreenScope>(overlayScreens()).layoutId, 'player');
    expect(app.route.value?.layoutId, 'home');
    expect(CodelesslyOverlayHost.shownIn(navigator(tester), app), ['player']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a tap on the overlay\'s empty part reaches the screen below', (tester) async {
    await pumpApp(tester);
    final before = overlayState(tester);
    // Home's button is at the top, under the overlay's empty part.
    await tester.tapAt(const Offset(195, 50));
    await settle(tester);
    expect(app.route.value?.layoutId, 'detail');
    expect(navigator(tester).canPop(), isTrue);
    // Pushed under the overlay, which kept its state.
    expect(overlayScreens(), findsOneWidget);
    expect(identical(overlayState(tester), before), isTrue);
  });

  testWidgets('the overlay persists across push, replace, reset and pop, once', (tester) async {
    final controller = await pumpApp(tester);
    final before = overlayState(tester);
    final navigate = controller.actionContext!.navigate;
    unawaited(navigate({'type': 'navigate', 'to': 'detail'}));
    await settle(tester);
    unawaited(navigate({'type': 'navigate', 'to': 'other'}));
    await settle(tester);
    expect(app.route.value?.layoutId, 'other');
    expect(overlayScreens(), findsOneWidget);
    navigator(tester).pop();
    await settle(tester);
    expect(app.route.value?.layoutId, 'detail');
    unawaited(navigate({'type': 'navigate', 'mode': 'reset', 'to': 'other', 'base': 'home'}));
    await settle(tester);
    expect(app.route.value?.layoutId, 'other');
    expect(overlayScreens(), findsOneWidget);
    expect(identical(overlayState(tester), before), isTrue);
    // Outside every route.
    expect(ModalRoute.of(tester.element(overlayScreens())), isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the overlay\'s buttons navigate the screens below', (tester) async {
    await pumpApp(tester);
    final before = overlayState(tester);
    await tester.tapAt(const Offset(195, 800));
    await settle(tester);
    expect(app.route.value?.layoutId, 'other');
    expect(navigator(tester).canPop(), isFalse, reason: 'replaced');
    expect(find.byType(CodelesslyWidget), findsNWidgets(2), reason: 'the screen and the overlay');
    expect(identical(overlayState(tester), before), isTrue);
  });

  testWidgets('an app on onGenerateRoute shows it; several widgets add it once', (tester) async {
    setScreen(tester, const Size(390, 844));
    await tester.pumpWidget(MaterialApp(onGenerateRoute: CodelesslyWidget.onGenerateRoute(app)));
    await settle(tester);
    expect(overlayScreens(), findsOneWidget);
    expect(app.route.value?.layoutId, 'home');
    await tester.pumpWidget(const SizedBox());

    // Two screens side by side in one navigator: one overlay.
    await tester.pumpWidget(MaterialApp(
      home: Column(children: [
        Expanded(child: CodelesslyWidget(codelessly: app, layoutId: 'home')),
        Expanded(child: CodelesslyWidget(codelessly: app, layoutId: 'detail')),
      ]),
    ));
    await settle(tester);
    expect(overlayScreens(), findsOneWidget);
    expect(find.byType(CodelesslyWidget), findsNWidgets(3));
  });

  testWidgets('shown as the screen itself, the overlay isn\'t drawn over it', (tester) async {
    setScreen(tester, const Size(390, 844));
    await tester.pumpWidget(MaterialApp(home: CodelesslyWidget(codelessly: app, layoutId: 'player')));
    await settle(tester);
    expect(overlayScreens(), findsNothing);
    expect(find.byType(CodelesslyWidget), findsOneWidget);
  });

  testWidgets('a project without overlay screens adds nothing', (tester) async {
    app.dispose();
    app = Codelessly.fromBundle(_bundle(withOverlay: false));
    await pumpApp(tester);
    expect(overlayScreens(), findsNothing);
    expect(find.byType(CodelesslyWidget), findsOneWidget);
  });

  test('the model lists published, enabled overlays', () {
    final model = _bundle().model;
    expect(model.overlays, ['player']);
    expect(model.copyWith(disabledLayouts: ['player']).overlays, isEmpty);
    expect(model.copyWith(overlayLayoutIds: ['gone']).overlays, isEmpty);
  });
}
