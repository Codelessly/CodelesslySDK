// Shared elements: a node with a `hero` flies between two screens that
// both show its tag while the navigation plays (SDK 8.x's NodeHero), on the
// app shell's routes.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> at(double x, double y, double w, double h) =>
    {'width': w, 'height': h, 'x': {'start': x}, 'y': {'start': y}};

NodeTree screen(Map<String, Object?> hero, Map<String, Object?> layout, {Map<String, Object?> extra = const {}}) =>
    NodeTree(DocumentSource(LayoutDocument.fromJson({
      'roots': ['r'],
      'nodes': {
        'r': {
          'type': 'stack',
          'children': ['h'],
          'layout': {'width': 400, 'height': 800},
        },
        'h': {
          'type': 'box',
          'hero': hero,
          'layout': layout,
          'decoration': {
            'fills': [
              {'color': '#FF3366FF'},
            ],
            'radius': 12,
          },
          ...extra,
        },
      },
    })));

Widget show(NodeTree tree) => Builder(builder: (context) {
      HeroRoutes.bind(tree, ModalRoute.of(context));
      return Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'r', interactive: true));
    });

Rect? shuttleRect(WidgetTester tester) {
  final f = find.byType(HeroMarkPaint);
  if (f.evaluate().isEmpty) return null;
  return tester.getRect(f.last);
}

void main() {
  setUp(() {
    // The flights read the overlay at full screen.
  });

  Future<(NodeTree, NodeTree, GlobalKey<NavigatorState>)> pump(WidgetTester tester, Object heroA, Object heroB,
      {Map<String, Object?>? layoutB}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.reset);
    final a = screen(heroA is String ? {'tag': heroA} : heroA as Map<String, Object?>, at(20, 20, 100, 100));
    final b = screen(heroB is String ? {'tag': heroB} : heroB as Map<String, Object?>, layoutB ?? at(0, 300, 400, 200));
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(navigatorKey: nav, home: show(a)));
    await tester.pump();
    return (a, b, nav);
  }

  testWidgets('a push flies the node from its place below to its place on top, and a pop flies it back',
      (tester) async {
    final (a, b, nav) = await pump(tester, 'card', 'card');
    nav.currentState!.push(CodelesslyPageRoute<void>(builder: (_) => show(b)));
    await tester.pump();
    await tester.pump();
    expect(HeroFlights.flying, isTrue);
    // Both ends hide while the drawing flies.
    final marks = [a, b].map((t) => HeroMarks.of(t).single).toList();
    expect(marks.every((m) => m.flying), isTrue);
    expect(shuttleRect(tester), isNotNull);
    final start = shuttleRect(tester)!;
    expect(start.left, closeTo(20, 2));
    expect(start.width, closeTo(100, 2));
    await tester.pump(const Duration(milliseconds: 150));
    final mid = shuttleRect(tester)!;
    expect(mid.width, greaterThan(110));
    expect(mid.width, lessThan(390));
    await tester.pumpAndSettle();
    expect(HeroFlights.flying, isFalse);
    expect(find.byType(HeroMarkPaint), findsNothing);
    expect(marks.every((m) => m.attached && !m.flying), isTrue);

    nav.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(HeroFlights.flying, isTrue);
    final back = shuttleRect(tester)!;
    expect(back.width, lessThan(400));
    await tester.pumpAndSettle();
    expect(HeroFlights.flying, isFalse);
  });

  testWidgets('different tags, or an empty one, don\'t fly', (tester) async {
    final (_, b, nav) = await pump(tester, 'card', 'other');
    nav.currentState!.push(CodelesslyPageRoute<void>(builder: (_) => show(b)));
    await tester.pump();
    await tester.pump();
    expect(HeroFlights.flying, isFalse);
    await tester.pumpAndSettle();
    final (_, c, nav2) = await pump(tester, '', '');
    nav2.currentState!.push(CodelesslyPageRoute<void>(builder: (_) => show(c)));
    await tester.pump();
    await tester.pump();
    expect(HeroFlights.flying, isFalse);
    await tester.pumpAndSettle();
  });

  testWidgets('an arc flight bows off the straight line, turns and glows', (tester) async {
    final (_, b, nav) = await pump(tester, {'tag': 'p', 'flight': 'arc'}, {'tag': 'p', 'flight': 'arc'});
    nav.currentState!.push(CodelesslyPageRoute<void>(builder: (_) => show(b)));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(HeroFlights.flying, isTrue);
    expect(find.ancestor(of: find.byType(HeroMarkPaint), matching: find.byType(Transform)), findsWidgets);
    final glow = tester.widget<DecoratedBox>(
        find.ancestor(of: find.byType(HeroMarkPaint), matching: find.byType(DecoratedBox)).first);
    expect((glow.decoration as BoxDecoration).shape, BoxShape.circle);
    // The path: off the line between the two centres.
    final tween = HeroArcRectTween(begin: const Rect.fromLTWH(0, 0, 10, 10), end: const Rect.fromLTWH(100, 0, 10, 10));
    expect(tween.lerp(0.5)!.center.dy, isNot(closeTo(5, 1)));
    await tester.pumpAndSettle();
  });

  testWidgets('morph and container transform cross-fade both drawings; the more specific flight wins',
      (tester) async {
    final (_, b, nav) = await pump(tester, 'm', {'tag': 'm', 'flight': 'containerTransform'});
    nav.currentState!.push(CodelesslyPageRoute<void>(builder: (_) => show(b)));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.byType(HeroMarkPaint), findsNWidgets(2));
    expect(find.ancestor(of: find.byType(HeroMarkPaint), matching: find.byType(ColoredBox)), findsWidgets);
    // The corners turn from one end's into the other's (both 12 here: no clip).
    await tester.pumpAndSettle();
    expect(HeroFlights.flying, isFalse);
  });

  testWidgets('route transitions fly heroes too; a design canvas has no hero marks', (tester) async {
    final (_, b, nav) = await pump(tester, 'card', 'card');
    nav.currentState!.push(CodelesslyRouteTransitionRoute<void>(
      transition: const RouteTransition(preset: RouteTransitionPreset.fadeThrough),
      builder: (_) => show(b),
    ));
    await tester.pump();
    await tester.pump();
    expect(HeroFlights.flying, isTrue);
    await tester.pumpAndSettle();
    expect(HeroFlights.flying, isFalse);

    final canvas = screen({'tag': 'card'}, at(0, 0, 50, 50));
    addTearDown(canvas.dispose);
    await tester.pumpWidget(MaterialApp(home: NodeView(tree: canvas, rootId: 'r')));
    expect(HeroMarks.of(canvas), isEmpty);
  });
}
