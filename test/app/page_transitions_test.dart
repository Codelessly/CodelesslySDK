import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:codelessly_api/codelessly_api.dart' show RouteTransition, RouteTransitionPreset;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/internals.dart' show CodelesslyRouteTransitionRoute;
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// The page transitions of the SDK's own ([CodelesslyPageTransitions]): the
// three native ones are held to Flutter's, pixel for pixel, at sampled
// moments of a push and of a pop; then the back swipe, the system's back
// gesture, the platform's choice, and a transition of the animation system.

const _surface = Color(0xFFF7F2FA);

Widget _page(String label, Color color) => ColoredBox(
      color: color,
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(label, textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 40, color: Color(0xFF101010))),
          const SizedBox(height: 20),
          const SizedBox(width: 200, height: 60, child: ColoredBox(color: Color(0xFF2040A0))),
        ]),
      ),
    );

typedef _RouteOf = PageRoute<void> Function(WidgetBuilder builder, {bool fullscreenDialog});

/// Pushes a second screen over the first with [routeOf]'s routes, then pops
/// it, and returns the pictures at each of [moments] (parts of [duration])
/// of both.
Future<List<Uint8List>> _film(
  WidgetTester tester,
  _RouteOf routeOf, {
  required Duration duration,
  required ThemeData theme,
  bool fullscreenDialog = false,
  TextDirection direction = TextDirection.ltr,
  List<double> moments = const [0.05, 0.1, 0.2, 0.3, 0.5, 0.75, 1],
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(400, 600);
  addTearDown(tester.view.reset);
  final navigator = GlobalKey<NavigatorState>();
  final boundary = GlobalKey();
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(Directionality(
    textDirection: direction,
    child: MediaQuery(
      data: const MediaQueryData(size: Size(400, 600)),
      child: Theme(
        data: theme,
        child: RepaintBoundary(
          key: boundary,
          child: ColoredBox(
            color: const Color(0xFF000000),
            child: Navigator(
              key: navigator,
              onGenerateRoute: (_) => routeOf((_) => _page('One', const Color(0xFFFFE0B2))),
            ),
          ),
        ),
      ),
    ),
  ));
  final frames = <Uint8List>[];
  Future<void> shoot() async {
    final render = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await render.toImage();
      frames.add((await image.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List());
      image.dispose();
    });
  }

  Future<void> play() async {
    await tester.pump();
    var at = 0.0;
    for (final m in moments) {
      await tester.pump(duration * (m - at));
      at = m;
      await shoot();
    }
    await tester.pump(const Duration(milliseconds: 50));
    await shoot();
  }

  navigator.currentState!
      .push(routeOf((_) => _page('Two', const Color(0xFFC8E6C9)), fullscreenDialog: fullscreenDialog));
  await play();
  navigator.currentState!.pop();
  await play();
  await tester.pumpWidget(const SizedBox());
  return frames;
}

/// The two films are the same, frame for frame; [within] is how far a
/// color value may be off (of 255).
void _expectSameFilm(List<Uint8List> own, List<Uint8List> flutter, {int within = 0}) {
  expect(own.length, flutter.length);
  for (var f = 0; f < own.length; f++) {
    var count = 0, most = 0;
    for (var i = 0; i < own[f].length; i++) {
      final d = (own[f][i] - flutter[f][i]).abs();
      if (d <= within) continue;
      count++;
      if (d > most) most = d;
    }
    expect(count, 0, reason: 'frame $f: $count values differ, by at most $most of 255');
  }
}

ThemeData _themeWith(PageTransitionsBuilder builder) => ThemeData(
      colorScheme: const ColorScheme.light(surface: _surface),
      pageTransitionsTheme: PageTransitionsTheme(builders: {for (final p in TargetPlatform.values) p: builder}),
    );

_RouteOf _own(CodelesslyPageTransitions transitions) => (builder, {fullscreenDialog = false}) => CodelesslyPageRoute<void>(
      builder: builder,
      fullscreenDialog: fullscreenDialog,
      transitions: transitions,
      fill: () => _surface,
    );

PageRoute<void> _material(WidgetBuilder builder, {bool fullscreenDialog = false}) =>
    MaterialPageRoute<void>(builder: builder, fullscreenDialog: fullscreenDialog);

void main() {
  group('a native transition is Flutter\'s, frame for frame', () {
    testWidgets('Android: fade forwards (what PredictiveBackPageTransitionsBuilder plays)', (tester) async {
      const duration = Duration(milliseconds: 450);
      final flutter = await _film(tester, _material,
          duration: duration, theme: _themeWith(const PredictiveBackPageTransitionsBuilder()));
      final own = await _film(tester, _own(CodelesslyPageTransitions.fadeForwards),
          duration: duration, theme: _themeWith(const PredictiveBackPageTransitionsBuilder()));
      _expectSameFilm(own, flutter);
      expect(CodelesslyPageTransitions.fadeForwards.duration, duration);
    });

    for (final direction in TextDirection.values) {
      testWidgets('iOS and macOS: the slide, ${direction.name}', (tester) async {
        const duration = Duration(milliseconds: 500);
        final theme = _themeWith(const CupertinoPageTransitionsBuilder());
        final flutter = await _film(tester, _material, duration: duration, theme: theme, direction: direction);
        final own = await _film(tester, _own(CodelesslyPageTransitions.cupertino),
            duration: duration, theme: theme, direction: direction);
        _expectSameFilm(own, flutter);
        expect(CodelesslyPageTransitions.cupertino.duration, duration);
      });
    }

    testWidgets('iOS and macOS: a full-screen dialog rises', (tester) async {
      const duration = Duration(milliseconds: 500);
      final theme = _themeWith(const CupertinoPageTransitionsBuilder());
      final flutter = await _film(tester, _material, duration: duration, theme: theme, fullscreenDialog: true);
      final own = await _film(tester, _own(CodelesslyPageTransitions.cupertino),
          duration: duration, theme: theme, fullscreenDialog: true);
      _expectSameFilm(own, flutter);
    });

    testWidgets('Windows and Linux: the zoom', (tester) async {
      const duration = Duration(milliseconds: 300);
      final theme = _themeWith(const ZoomPageTransitionsBuilder());
      final flutter = await _film(tester, _material, duration: duration, theme: theme);
      final own = await _film(tester, _own(CodelesslyPageTransitions.zoom), duration: duration, theme: theme);
      // (One level of a fade's rounding in one frame of the sixteen.)
      _expectSameFilm(own, flutter, within: 1);
      expect(CodelesslyPageTransitions.zoom.duration, duration);
    });
  });

  group('the platform\'s', () {
    for (final (platform, expected) in [
      (TargetPlatform.android, CodelesslyPageTransitions.fadeForwards),
      (TargetPlatform.iOS, CodelesslyPageTransitions.cupertino),
      (TargetPlatform.macOS, CodelesslyPageTransitions.cupertino),
      (TargetPlatform.windows, CodelesslyPageTransitions.zoom),
      (TargetPlatform.linux, CodelesslyPageTransitions.zoom),
    ]) {
      test('${platform.name} takes as long as its native one', () {
        debugDefaultTargetPlatformOverride = platform;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        expect(CodelesslyPageTransitions.platform.duration, expected.duration);
      });
    }
  });

  Future<GlobalKey<NavigatorState>> twoScreens(WidgetTester tester, CodelesslyPageTransitions transitions,
      {TextDirection direction = TextDirection.ltr}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 600);
    addTearDown(tester.view.reset);
    final navigator = GlobalKey<NavigatorState>();
    // A plain widgets app: nothing of Material's above the routes.
    await tester.pumpWidget(WidgetsApp(
      color: const Color(0xFF2196F3),
      navigatorKey: navigator,
      builder: (context, child) => Directionality(textDirection: direction, child: child!),
      onGenerateRoute: (_) => CodelesslyPageRoute<void>(
        transitions: transitions,
        builder: (_) => _page('One', const Color(0xFFFFE0B2)),
      ),
    ));
    navigator.currentState!.push(CodelesslyPageRoute<void>(
      transitions: transitions,
      builder: (_) => _page('Two', const Color(0xFFC8E6C9)),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Two'), findsOneWidget);
    return navigator;
  }

  group('the back swipe (iOS)', () {
    for (final direction in TextDirection.values) {
      testWidgets('from the leading edge follows the finger, and goes back past half way (${direction.name})', (tester) async {
        final navigator = await twoScreens(tester, CodelesslyPageTransitions.cupertino, direction: direction);
        final ltr = direction == TextDirection.ltr;
        final edge = Offset(ltr ? 5 : 395, 300);
        final toward = ltr ? 1.0 : -1.0;
        // Let go before half way: the screen comes back.
        var finger = await tester.startGesture(edge);
        await finger.moveBy(Offset(toward * 30, 0));
        await finger.moveBy(Offset(toward * 100, 0));
        await tester.pump();
        expect(navigator.currentState!.userGestureInProgress, isTrue);
        // Under the finger: the screen has moved as far as the finger since
        // the drag was taken.
        final moved = tester.getTopLeft(find.text('Two')).dx;
        await finger.moveBy(Offset(toward * 40, 0));
        await tester.pump();
        expect(tester.getTopLeft(find.text('Two')).dx - moved, toward * 40);
        await finger.up();
        await tester.pumpAndSettle();
        expect(find.text('Two'), findsOneWidget);
        expect(navigator.currentState!.userGestureInProgress, isFalse);
        // Past half way: back.
        finger = await tester.startGesture(edge);
        await finger.moveBy(Offset(toward * 30, 0));
        await finger.moveBy(Offset(toward * 230, 0));
        await tester.pump();
        await finger.up();
        await tester.pumpAndSettle();
        expect(find.text('Two'), findsNothing);
        expect(find.text('One'), findsOneWidget);
        expect(navigator.currentState!.userGestureInProgress, isFalse);
      });
    }

    testWidgets('a fling goes back from anywhere; a drag that starts off the edge does nothing', (tester) async {
      final navigator = await twoScreens(tester, CodelesslyPageTransitions.cupertino);
      await tester.dragFrom(const Offset(200, 300), const Offset(150, 0));
      await tester.pumpAndSettle();
      expect(find.text('Two'), findsOneWidget);
      await tester.flingFrom(const Offset(5, 300), const Offset(80, 0), 1200);
      await tester.pumpAndSettle();
      expect(find.text('Two'), findsNothing);
      expect(navigator.currentState!.canPop(), isFalse);
    });

    testWidgets('not on the first screen, nor on a full-screen dialog, nor with the other transitions', (tester) async {
      final navigator = await twoScreens(tester, CodelesslyPageTransitions.cupertino);
      navigator.currentState!.push(CodelesslyPageRoute<void>(
        transitions: CodelesslyPageTransitions.cupertino,
        fullscreenDialog: true,
        builder: (_) => _page('Three', const Color(0xFFE1BEE7)),
      ));
      await tester.pumpAndSettle();
      await tester.dragFrom(const Offset(5, 300), const Offset(300, 0));
      await tester.pumpAndSettle();
      expect(find.text('Three'), findsOneWidget);
      navigator.currentState!.popUntil((r) => r.isFirst);
      await tester.pumpAndSettle();
      await tester.dragFrom(const Offset(5, 300), const Offset(300, 0));
      await tester.pumpAndSettle();
      expect(find.text('One'), findsOneWidget);
      await twoScreens(tester, CodelesslyPageTransitions.zoom);
      await tester.dragFrom(const Offset(5, 300), const Offset(300, 0));
      await tester.pumpAndSettle();
      expect(find.text('Two'), findsOneWidget);
    });
  });

  group('the system\'s back gesture (Android)', () {
    Future<void> send(String method, [double progress = 0]) async {
      final message = const StandardMethodCodec().encodeMethodCall(MethodCall(method, <String, Object?>{
        'touchOffset': <double>[5, 300],
        'progress': progress,
        'swipeEdge': 0,
      }));
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage('flutter/backgesture', message, (_) {});
    }

    testWidgets('the screen plays its way out under the finger, then comes back or leaves', (tester) async {
      final navigator = await twoScreens(tester, CodelesslyPageTransitions.fadeForwards);
      final rest = tester.getTopLeft(find.text('Two')).dx;
      await send('startBackGesture');
      await send('updateBackGestureProgress', 1);
      await tester.pump();
      expect(navigator.currentState!.userGestureInProgress, isTrue);
      // Part of the way out, not gone.
      expect(tester.getTopLeft(find.text('Two')).dx, greaterThan(rest));
      expect(find.text('Two'), findsOneWidget);
      await send('cancelBackGesture');
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('Two')).dx, rest);
      expect(navigator.currentState!.userGestureInProgress, isFalse);

      await send('startBackGesture');
      await send('updateBackGestureProgress', 0.6);
      await tester.pump();
      await send('commitBackGesture');
      await tester.pumpAndSettle();
      expect(find.text('Two'), findsNothing);
      expect(find.text('One'), findsOneWidget);
      expect(navigator.currentState!.userGestureInProgress, isFalse);
    });

    testWidgets('the first screen leaves it to the system', (tester) async {
      final navigator = await twoScreens(tester, CodelesslyPageTransitions.fadeForwards);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      await send('startBackGesture');
      await tester.pump();
      expect(navigator.currentState!.userGestureInProgress, isFalse);
      await send('cancelBackGesture');
    });
  });

  group('a transition of the animation system', () {
    testWidgets('a project\'s screens open with it', (tester) async {
      const transitions = CodelesslyPageTransitions.animated(RouteTransition(preset: RouteTransitionPreset.sharedAxisX));
      final route = CodelesslyPageRoute.of<void>(transitions: transitions, builder: (_) => const SizedBox());
      expect(route, isA<CodelesslyRouteTransitionRoute<void>>());
      expect((route as CodelesslyRouteTransitionRoute<void>).transition.preset, RouteTransitionPreset.sharedAxisX);
      expect(route.transitionDuration, transitions.duration);
      // The native ones open in the page route.
      expect(
        CodelesslyPageRoute.of<void>(transitions: CodelesslyPageTransitions.zoom, builder: (_) => const SizedBox()),
        isA<CodelesslyPageRoute<void>>(),
      );
    });

    testWidgets('it plays between two screens, both ways', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(400, 600);
      addTearDown(tester.view.reset);
      final navigator = GlobalKey<NavigatorState>();
      const transitions = CodelesslyPageTransitions.animated(
          RouteTransition(preset: RouteTransitionPreset.sharedAxisX, durationMs: 400));
      PageRoute<void> route(String label) => CodelesslyPageRoute.of<void>(
          transitions: transitions, builder: (_) => _page(label, const Color(0xFFFFFFFF)));
      await tester.pumpWidget(WidgetsApp(
        color: const Color(0xFF2196F3),
        navigatorKey: navigator,
        onGenerateRoute: (_) => route('One'),
      ));
      navigator.currentState!.push(route('Two'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      // Mid way: both screens are there, the new one not yet in its place.
      expect(find.text('One'), findsOneWidget);
      expect(tester.getCenter(find.text('Two')).dx, isNot(200));
      await tester.pumpAndSettle();
      expect(tester.getCenter(find.text('Two')).dx, 200);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('Two'), findsNothing);
      expect(find.text('One'), findsOneWidget);
    });
  });

  // The navigation guide's adapter: a Material app's own theme transitions
  // for a project's screens.
  group('a host\'s own transitions (the guide\'s adapter)', () {
    for (final (name, builder, duration) in <(String, PageTransitionsBuilder, Duration)>[
      ('zoom', const ZoomPageTransitionsBuilder(), const Duration(milliseconds: 300)),
      ('fade forwards', const FadeForwardsPageTransitionsBuilder(), const Duration(milliseconds: 450)),
      ('Cupertino', const CupertinoPageTransitionsBuilder(), const Duration(milliseconds: 500)),
    ]) {
      testWidgets('plays the theme\'s $name as a MaterialPageRoute does', (tester) async {
        final theme = _themeWith(builder);
        final flutter = await _film(tester, _material, duration: duration, theme: theme);
        final own = await _film(tester, _own(_ThemePageTransitions(duration)), duration: duration, theme: theme);
        _expectSameFilm(own, flutter);
      });
    }
  });
}

class _ThemePageTransitions extends CodelesslyPageTransitions {
  const _ThemePageTransitions(this.duration);

  @override
  final Duration duration;

  @override
  Widget buildEntering(PageRoute<Object?> route, BuildContext context, Animation<double> animation, Widget child) =>
      Theme.of(context).pageTransitionsTheme.buildTransitions(route, context, animation, kAlwaysDismissedAnimation, child);

  @override
  Widget buildCovered(BuildContext context, Animation<double> secondaryAnimation, Widget child, {Color? fill}) {
    final theme = Theme.of(context);
    final covered = theme.pageTransitionsTheme.delegatedTransition(theme.platform);
    return covered?.call(context, kAlwaysCompleteAnimation, secondaryAnimation, true, child) ?? child;
  }
}
