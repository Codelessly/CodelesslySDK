import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Shared elements: a node with a `hero` flies between two screens that
// both show its tag while the navigation plays, on the
// app shell's routes.

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

// Heroes whose tag comes from data: a card's avatar in a list item
// (`avatar-${item.id}`) flies to a profile header whose tag is a variable
// read from the route.

const fill = {
  'fills': [
    {'color': '#FF3366FF'},
  ],
};

NodeTree tree(Map<String, Object?> nodes, List<Variable> variables) {
  final scope = VariableScope(variables);
  return NodeTree(
    DocumentSource(LayoutDocument.fromJson({'roots': ['r'], 'nodes': nodes})),
    binder: NodeBinder(scope: scope, logic: const LayoutLogic()),
  );
}

/// A screen that builds its tree a couple of frames after its route opens,
/// as a screen loading its layout does.
class Late extends StatefulWidget {
  const Late(this.tree, {super.key});
  final NodeTree tree;
  @override
  State<Late> createState() => _LateState();
}

class _LateState extends State<Late> {
  int frames = 0;
  @override
  Widget build(BuildContext context) {
    if (frames < 2) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => frames++);
      });
      return const SizedBox.expand();
    }
    return show(widget.tree);
  }
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

  testWidgets('opening a screen flies a shared node to its new place, and going back flies it home',
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

  testWidgets('nodes with different tags, or no tag, do not fly', (tester) async {
    final (_, b, nav) = await pump(tester, 'card', 'other');
    nav.currentState!.push(CodelesslyPageRoute<void>(builder: (_) => show(b)));
    await tester.pump();
    await tester.pump();
    expect(HeroFlights.flying, isFalse);
    await tester.pumpAndSettle();
    final (_, c, navB) = await pump(tester, '', '');
    navB.currentState!.push(CodelesslyPageRoute<void>(builder: (_) => show(c)));
    await tester.pump();
    await tester.pump();
    expect(HeroFlights.flying, isFalse);
    await tester.pumpAndSettle();
  });

  testWidgets('heroes that fly in place do not fly between screens', (tester) async {
    final inPlace = {'tag': 'card', 'flies': 'inPlace'};
    final (a, b, nav) = await pump(tester, inPlace, inPlace);
    expect(HeroMarks.of(a), isEmpty);
    nav.currentState!.push(CodelesslyPageRoute<void>(builder: (_) => show(b)));
    await tester.pump();
    await tester.pump();
    expect(HeroFlights.flying, isFalse);
    await tester.pumpAndSettle();
  });

  testWidgets('custom screen transitions fly shared nodes too, and the design canvas marks none', (tester) async {
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

  group('bound tags', () {
    testWidgets('a list item with a bound tag flies to the screen whose tag is a variable', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(400, 800);
      addTearDown(tester.view.reset);
      final wall = tree({
        'r': {'type': 'column', 'children': ['cards'], 'layout': {'width': 400, 'height': 800}},
        'cards': {
          'type': 'listView',
          'children': ['av'],
          'layout': {'width': {'fill': 400}, 'height': {'hug': 10}},
          'props': {'scrollable': false},
          'bind': {'data': r'${kudos}'},
        },
        'av': {
          'type': 'box',
          'layout': {'width': 24, 'height': 24},
          'decoration': fill,
          'hero': {'tag': 'x'},
          'bind': {'hero.tag': r'avatar-${item.id}'},
        },
      }, [
        const Variable(name: 'kudos', type: VariableType.list, value: [
          {'id': 'k1'},
          {'id': 'k2'},
        ]),
      ]);
      final profile = tree({
        'r': {'type': 'stack', 'children': ['big'], 'layout': {'width': 400, 'height': 800}},
        'big': {
          'type': 'box',
          'layout': at(20, 100, 96, 96),
          'decoration': fill,
          'hero': {'tag': 'x'},
          'bind': {'hero.tag': r'${heroTag}'},
        },
      }, [const Variable(name: 'heroTag', type: VariableType.text, value: 'avatar-k2')]);
      addTearDown(wall.dispose);
      addTearDown(profile.dispose);
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(navigatorKey: nav, home: show(wall)));
      await tester.pump();
      nav.currentState!.push(CodelesslyRouteTransitionRoute<void>(
        transition: const RouteTransition(preset: RouteTransitionPreset.fadeThrough),
        builder: (_) => show(profile),
      ));
      await tester.pump();
      await tester.pump();
      expect(HeroFlights.flying, isTrue);
      final shuttle = find.byType(HeroMarkPaint);
      expect(shuttle, findsWidgets);
      // From the second card's 24 px avatar (y 24).
      expect(tester.getRect(shuttle.last).top, closeTo(24, 2));
      expect(tester.getRect(shuttle.last).width, closeTo(24, 2));
      await tester.pumpAndSettle();
      expect(HeroFlights.flying, isFalse);
    });
  });
}
