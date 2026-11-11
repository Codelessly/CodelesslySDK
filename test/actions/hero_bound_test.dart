// Heroes whose tag comes from data: a card's avatar in a list item
// (`avatar-${item.id}`) flies to a profile header whose tag is a variable
// read from the route.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> at(double x, double y, double w, double h) =>
    {'width': w, 'height': h, 'x': {'start': x}, 'y': {'start': y}};

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

Widget show(NodeTree tree) => Builder(builder: (context) {
      HeroRoutes.bind(tree, ModalRoute.of(context));
      return Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'r', interactive: true));
    });

void main() {
  testWidgets('a list item\'s hero with a bound tag flies to a screen whose tag is a variable', (tester) async {
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

  testWidgets('a screen that builds its tree a frame or two late still gets its hero', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.reset);
    Map<String, Object?> one(Map<String, Object?> layout) => {
          'r': {'type': 'stack', 'children': ['h'], 'layout': {'width': 400, 'height': 800}},
          'h': {'type': 'box', 'layout': layout, 'decoration': fill, 'hero': {'tag': 'avatar'}},
        };
    final a = tree(one(at(20, 20, 24, 24)), const []);
    final b = tree(one(at(20, 100, 96, 96)), const []);
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(navigatorKey: nav, home: show(a)));
    await tester.pump();
    nav.currentState!.push(CodelesslyRouteTransitionRoute<void>(
      transition: const RouteTransition(preset: RouteTransitionPreset.fadeThrough),
      builder: (_) => Late(b),
    ));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(HeroFlights.flying, isTrue);
    await tester.pumpAndSettle();
    expect(HeroFlights.flying, isFalse);
  });
}
