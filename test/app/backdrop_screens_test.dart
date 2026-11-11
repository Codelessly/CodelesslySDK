// A backdrop screen (CanvasProps.backdrop, listed in the model's
// backdropLayoutIds) is drawn once beneath every screen, outside
// navigation: it stays the same widget (state kept, never moved) while
// route transitions move the screens over it, shows through screens whose
// canvas has no fill (also while the platform's page transition plays), and
// leaves the app's current route alone.
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

const _sky = Color(0xFF0A1B6C);

/// A one-canvas layout [id]: a full-screen stack holding a 390×100 box at
/// the top. A backdrop's canvas is filled with [_sky]; a screen's canvas
/// has [fill] (none by default: it shows the backdrop through).
PublishLayout _screen(
  String id, {
  bool backdrop = false,
  String? fill,
  Map<String, String>? boxBind,
  String boxColor = '#FF334455',
}) => PublishLayout.fromJson({
  'schema': 2,
  'id': id,
  'roots': ['${id}C'],
  'nodes': {
    '${id}C': {
      'type': 'canvas',
      'name': id,
      'slots': {'body': '${id}Body'},
      'layout': {'width': 390, 'height': 844},
      if (backdrop) 'props': {'backdrop': true},
      if (backdrop)
        'decoration': {
          'fills': [
            {'color': '#FF0A1B6C'},
          ],
        }
      else if (fill != null)
        'decoration': {
          'fills': [
            {'color': fill},
          ],
        },
    },
    '${id}Body': {
      'type': 'stack',
      'children': ['${id}Box'],
      'layout': {
        'width': {'fill': 390},
        'height': {'fill': 844},
      },
    },
    '${id}Box': {
      'type': 'box',
      'decoration': {
        'fills': [
          {'color': boxColor},
        ],
      },
      'layout': {
        'width': 390,
        'height': 100,
        'x': {'start': 0},
        'y': {'start': 0},
      },
      'bind': ?boxBind,
    },
  },
});

PublishBundle _bundle({bool withBackdrop = true, String? homeFill, bool homeHides = false}) {
  final layouts = {
    for (final l in [
      // A screen keeping its own background for the design board: its box
      // shows only where no backdrop is drawn beneath it.
      _screen(
        'home',
        fill: homeFill,
        boxBind: homeHides ? {'visible': r'${= !screen.backdrop}'} : null,
        boxColor: homeHides ? '#FF55AA33' : '#FF334455',
      ),
      _screen('detail'),
      _screen('sky', backdrop: true),
    ])
      l.id: l,
  };
  return PublishBundle(
    model: PublishModel(
      projectId: 'p',
      entryLayoutId: 'home',
      layouts: {for (final l in layouts.values) l.id: PublishLayoutInfo.of(l)},
      backdropLayoutIds: [if (withBackdrop) 'sky'],
    ),
    layouts: layouts,
  );
}

/// A loader whose model can be republished.
class _LiveLoader extends MemoryPublishLoader implements LivePublishLoader {
  _LiveLoader(super.bundle);

  final StreamController<PublishModel> models = StreamController.broadcast();

  @override
  Stream<PublishModel> watchModel(PublishSource source) => models.stream;
}

void main() {
  late Codelessly app;
  final screenshot = GlobalKey();

  Finder backdrops() => find.byType(BackdropScreenScope);

  /// The backdrop's state: the same object while it persists.
  State backdropState(WidgetTester tester) =>
      tester.state(find.descendant(of: backdrops(), matching: find.byType(CodelesslyWidget)));

  NavigatorState navigator(WidgetTester tester) => tester.state<NavigatorState>(find.byType(Navigator));

  Future<CodelesslyWidgetController> pumpApp(
    WidgetTester tester, {
    PublishBundle? bundle,
    PublishLoader? loader,
    PageTransitionsBuilder? transitions,
  }) async {
    setScreen(tester, const Size(390, 844));
    app = loader != null ? Codelessly(loader: loader) : Codelessly.fromBundle(bundle ?? _bundle());
    addTearDown(app.dispose);
    final controller = CodelesslyWidgetController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      RepaintBoundary(
        key: screenshot,
        child: MaterialApp(
          theme: ThemeData(
            pageTransitionsTheme: transitions == null
                ? const PageTransitionsTheme()
                : PageTransitionsTheme(builders: {for (final p in TargetPlatform.values) p: transitions}),
          ),
          builder: (context, child) => CodelesslyBackdropHost(codelessly: app, child: child!),
          home: CodelesslyWidget(codelessly: app, controller: controller),
        ),
      ),
    );
    await settle(tester);
    return controller;
  }

  /// The color of the app's pixel at [at].
  Future<Color> pixel(WidgetTester tester, Offset at) async {
    final boundary = screenshot.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final bytes = (await tester.runAsync(() async {
      final image = await boundary.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      return data;
    }))!;
    final i = ((at.dy.toInt() * boundary.size.width.toInt()) + at.dx.toInt()) * 4;
    final b = Uint8List.sublistView(bytes);
    return Color.fromARGB(b[i + 3], b[i], b[i + 1], b[i + 2]);
  }

  testWidgets('the backdrop is beneath the navigator, outside every route, without taking the route', (tester) async {
    await pumpApp(tester);
    expect(backdrops(), findsOneWidget);
    expect(tester.widget<BackdropScreenScope>(backdrops()).layoutId, 'sky');
    expect(ModalRoute.of(tester.element(backdrops())), isNull);
    // Beneath the navigator: an earlier child of the same stack.
    final stack = tester.widget<Stack>(find.ancestor(of: backdrops(), matching: find.byType(Stack)).first);
    expect(find.descendant(of: find.byWidget(stack.children.last), matching: find.byType(Navigator)), findsOneWidget);
    expect(find.descendant(of: find.byWidget(stack.children.first), matching: backdrops()), findsOneWidget);
    expect(app.route.value?.layoutId, 'home');
    // It doesn't add overlay screens or draw itself as one.
    expect(find.byType(OverlayScreenScope), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a screen without a fill shows the backdrop through; one with a fill covers it', (tester) async {
    await pumpApp(tester);
    expect(await pixel(tester, const Offset(195, 50)), const Color(0xFF334455), reason: 'the screen\'s box, above');
    expect(await pixel(tester, const Offset(195, 400)), _sky, reason: 'the backdrop, through the screen');
    await tester.pumpWidget(const SizedBox());
    await pumpApp(tester, bundle: _bundle(homeFill: '#FFFFFFFF'));
    expect(await pixel(tester, const Offset(195, 400)), const Color(0xFFFFFFFF));
  });

  testWidgets('the backdrop stays the same element, unmoved, across a push with a route transition and a pop', (
    tester,
  ) async {
    final controller = await pumpApp(tester);
    final element = tester.element(backdrops());
    final state = backdropState(tester);
    final box = tester.renderObject<RenderBox>(backdrops());
    unawaited(controller.actionContext!.navigate({'type': 'navigate', 'to': 'detail', 'routeTransition': 'cube'}));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 60));
      expect(identical(tester.element(backdrops()), element), isTrue);
      expect(box.localToGlobal(Offset.zero), Offset.zero);
      expect(box.size, const Size(390, 844));
    }
    await settle(tester);
    expect(app.route.value?.layoutId, 'detail');
    expect(navigator(tester).canPop(), isTrue);
    expect(identical(backdropState(tester), state), isTrue);
    expect(await pixel(tester, const Offset(195, 400)), _sky);
    navigator(tester).pop();
    await settle(tester);
    expect(app.route.value?.layoutId, 'home');
    expect(identical(tester.element(backdrops()), element), isTrue);
    expect(identical(backdropState(tester), state), isTrue);
    expect(tester.takeException(), isNull);
  });

  for (final (name, builder) in [
    ('zoom', const ZoomPageTransitionsBuilder()),
    ('fade forwards', const FadeForwardsPageTransitionsBuilder()),
    ('predictive back', const PredictiveBackPageTransitionsBuilder()),
  ]) {
    testWidgets('the platform page transition ($name) paints nothing over the backdrop', (tester) async {
      final controller = await pumpApp(tester, transitions: builder);
      final state = backdropState(tester);
      unawaited(controller.actionContext!.navigate({'type': 'navigate', 'to': 'detail'}));
      await tester.pump();
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 40));
        // Below both screens' boxes: only the backdrop is there.
        expect(await pixel(tester, const Offset(195, 600)), _sky, reason: 'frame $i');
      }
      await settle(tester);
      expect(app.route.value?.layoutId, 'detail');
      expect(identical(backdropState(tester), state), isTrue);
    });
  }

  testWidgets('without backdrops, the platform transition is the theme\'s, as before', (tester) async {
    final controller = await pumpApp(
      tester,
      bundle: _bundle(withBackdrop: false),
      transitions: const ZoomPageTransitionsBuilder(),
    );
    expect(backdrops(), findsNothing);
    unawaited(controller.actionContext!.navigate({'type': 'navigate', 'to': 'detail'}));
    await tester.pump();
    // The zoom transition's scrim, fading in over the screen beneath.
    var scrim = 0.0;
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 40));
      final a = (await pixel(tester, const Offset(195, 600))).a;
      if (a > scrim) scrim = a;
    }
    expect(scrim, greaterThan(0.3));
    await settle(tester);
  });

  testWidgets('it follows republishes, keeping the navigator', (tester) async {
    final loader = _LiveLoader(_bundle(withBackdrop: false));
    addTearDown(loader.models.close);
    final controller = await pumpApp(tester, loader: loader);
    expect(backdrops(), findsNothing);
    unawaited(controller.actionContext!.navigate({'type': 'navigate', 'to': 'detail'}));
    await settle(tester);
    final nav = navigator(tester);
    loader.models.add(_bundle().model.copyWith(lastUpdated: DateTime(2030)));
    await settle(tester);
    expect(backdrops(), findsOneWidget);
    expect(identical(navigator(tester), nav), isTrue);
    expect(nav.canPop(), isTrue);
    expect(await pixel(tester, const Offset(195, 400)), _sky);
    loader.models.add(_bundle().model.copyWith(disabledLayouts: ['sky'], lastUpdated: DateTime(2031)));
    await settle(tester);
    expect(backdrops(), findsNothing);
    expect(identical(navigator(tester), nav), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a presenter host as the builder draws the backdrops too', (tester) async {
    setScreen(tester, const Size(390, 844));
    app = Codelessly.fromBundle(_bundle());
    addTearDown(app.dispose);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => CodelesslyPresenterHost(codelessly: app, automations: false, child: child!),
        home: CodelesslyWidget(codelessly: app),
      ),
    );
    await settle(tester);
    expect(backdrops(), findsOneWidget);
    expect(ModalRoute.of(tester.element(backdrops())), isNull);
    expect(app.route.value?.layoutId, 'home');
  });

  test('seeThroughPageTransitions keeps the builders, transparent', () {
    final see = seeThroughPageTransitions(
      const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(allowSnapshotting: false),
          TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
    expect(see.builders[TargetPlatform.android], isA<SeeThroughZoomPageTransitionsBuilder>());
    expect(see.builders[TargetPlatform.iOS], isA<FadeUpwardsPageTransitionsBuilder>());
    expect(
      (see.builders[TargetPlatform.linux]! as FadeForwardsPageTransitionsBuilder).backgroundColor,
      Colors.transparent,
    );
    // A platform without a builder zooms (iOS: Cupertino, left to the default).
    expect(see.builders[TargetPlatform.windows], isA<SeeThroughZoomPageTransitionsBuilder>());
    expect(
      seeThroughPageTransitions(const PageTransitionsTheme(builders: {})).builders.containsKey(TargetPlatform.iOS),
      isFalse,
    );
  });

  test('the model lists published, enabled backdrops; an overlay is not one', () {
    final model = _bundle().model;
    expect(model.backdrops, ['sky']);
    expect(model.copyWith(disabledLayouts: ['sky']).backdrops, isEmpty);
    expect(model.copyWith(backdropLayoutIds: ['gone']).backdrops, isEmpty);
    expect(model.copyWith(overlayLayoutIds: ['sky']).backdrops, isEmpty);
  });

  testWidgets('screen.backdrop: a screen hides its own background where a backdrop is drawn beneath it', (
    tester,
  ) async {
    await pumpApp(tester, bundle: _bundle(homeHides: true));
    // Hidden: what's beneath shows (the backdrop's own box, at the same place).
    expect(await pixel(tester, const Offset(195, 50)), const Color(0xFF334455), reason: 'the box is hidden');
    await tester.pumpWidget(const SizedBox());
    await pumpApp(tester, bundle: _bundle(homeHides: true, withBackdrop: false));
    expect(await pixel(tester, const Offset(195, 50)), const Color(0xFF55AA33), reason: 'no backdrop: its own');
    // A backdrop itself never reads true (it'd hide its own sky).
    await tester.pumpWidget(const SizedBox());
    await pumpApp(tester);
    final inBackdrop = tester.element(find.descendant(of: backdrops(), matching: find.byType(CodelesslyWidget)));
    expect(CodelesslyBackdropHost.showsBackdrop(inBackdrop), isTrue, reason: 'it is inside the host');
    expect(BackdropScreenScope.of(inBackdrop), isTrue, reason: 'so screen.backdrop is false there');
  });
}
