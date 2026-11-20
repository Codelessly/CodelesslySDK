import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/internals.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/screen.dart' as harness;

// Lifted shared elements (`hero` with `flies: lift`): a node with the tag
// that comes while another is shown flies from that one's place to its own,
// drawn above everything; the one it left keeps its place hidden, and the
// node flies back to it when the one on top goes. And the long press that
// starts it: its own hold, a commit point, a buzz.

const lift = {
  'tag': 'm7',
  'flies': 'lift',
  'flight': {'duration': 300, 'curve': 'linear'},
};

Json box(Json layout, {Json hero = lift}) => {
      'type': 'box',
      'hero': hero,
      'layout': layout,
      'decoration': {
        'fills': [
          {'color': '#FFF1F5F9'},
        ],
        'radius': 12,
      },
    };

Json at(double x, double y, double w, double h) => {'width': w, 'height': h, 'x': {'start': x}, 'y': {'start': y}};

/// A page: a scrolling column of eleven rows, the fourth (`h`, at y 300 when
/// not scrolled) the tagged one.
NodeTree page() => NodeTree(DocumentSource(LayoutDocument.fromJson({
      'schema': 3,
      'roots': ['r'],
      'nodes': {
        'r': {
          'type': 'column',
          'props': {'scrollable': true, 'crossAxisAlignment': 'start'},
          'layout': {'width': 400, 'height': 800},
          'children': ['a', 'b', 'c', 'h', 'd', 'e', 'f', 'g', 'i', 'j', 'k'],
        },
        for (final id in ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'i', 'j', 'k'])
          id: {
            'type': 'box',
            'layout': {'width': 400, 'height': 100},
          },
        'h': box({'width': 200, 'height': 60}),
      },
    })));

/// An overlay's screen: the tagged node centred-ish at (100, 370).
NodeTree overlay() => NodeTree(DocumentSource(LayoutDocument.fromJson({
      'schema': 3,
      'roots': ['r'],
      'nodes': {
        'r': {
          'type': 'stack',
          'children': ['h'],
          'layout': {'width': 400, 'height': 800},
        },
        'h': box(at(100, 370, 200, 60)),
      },
    })));

Widget show(NodeTree tree) => Builder(builder: (context) {
      HeroRoutes.bind(tree, ModalRoute.of(context));
      return Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'r', interactive: true));
    });

/// An overlay over the page: a translucent route with a 150 ms fade.
Route<void> over(NodeTree tree) => PageRouteBuilder<void>(
      opaque: false,
      barrierColor: const Color(0x6604040F),
      transitionDuration: const Duration(milliseconds: 150),
      reverseTransitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (_, _, _) => show(tree),
      transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
    );

RenderHeroMark markOf(NodeTree tree) => HeroMarks.of(tree).single;

void main() {
  Future<(NodeTree, NodeTree, GlobalKey<NavigatorState>)> pump(WidgetTester tester, {bool reducedMotion = false}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.reset);
    final p = page();
    final o = overlay();
    addTearDown(p.dispose);
    addTearDown(o.dispose);
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MediaQuery(
      data: MediaQueryData(size: const Size(400, 800), disableAnimations: reducedMotion),
      child: MaterialApp(navigatorKey: nav, home: show(p)),
    ));
    await tester.pump();
    return (p, o, nav);
  }

  testWidgets('a lifted node flies from its place in the page to its place over it, drawn above, and back', (tester) async {
    final (p, o, nav) = await pump(tester);
    final home = markOf(p);
    expect(home.liftShown, isTrue);
    expect(HeroLifts.flying, isFalse);

    nav.currentState!.push(over(o));
    await tester.pump();
    // The overlay's first frame: its node waits for its flight, the page's
    // still shows.
    expect(markOf(o).liftShown, isFalse);
    await tester.pump();
    expect(HeroLifts.flying, isTrue);
    // t = 0: where it sat in the page.
    final start = HeroLifts.rectOf('m7')!;
    expect(start.left, closeTo(0, 1));
    expect(start.top, closeTo(300, 1));
    expect(start.size, const Size(200, 60));
    // The page's node keeps its place, hidden: a gap.
    expect(home.liftShown, isFalse);
    expect(home.size, const Size(200, 60));
    // It is drawn in the navigator's overlay, above the route and its
    // barrier.
    expect(find.byType(HeroMarkPaint), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 150));
    final mid = HeroLifts.rectOf('m7')!;
    expect(mid.left, closeTo(50, 4));
    expect(mid.top, closeTo(335, 4));

    await tester.pump(const Duration(milliseconds: 200));
    expect(HeroLifts.flying, isFalse);
    expect(find.byType(HeroMarkPaint), findsNothing);
    expect(markOf(o).liftShown, isTrue);
    expect(home.liftShown, isFalse, reason: 'the page keeps a gap while the overlay shows it');

    // Closing the overlay flies it back.
    nav.currentState!.pop();
    await tester.pump();
    await tester.pump();
    expect(HeroLifts.flying, isTrue);
    final back = HeroLifts.rectOf('m7')!;
    expect(back.left, closeTo(100, 2));
    expect(back.top, closeTo(370, 2));
    expect(home.liftShown, isFalse);
    expect(markOf(o).liftShown, isFalse, reason: 'the closing overlay no longer draws it');
    await tester.pump(const Duration(milliseconds: 150));
    final backMid = HeroLifts.rectOf('m7')!;
    expect(backMid.top, closeTo(335, 4));
    await tester.pumpAndSettle();
    expect(HeroLifts.flying, isFalse);
    expect(home.liftShown, isTrue);
    expect(find.byType(HeroMarkPaint), findsNothing);
  });

  testWidgets('the way back follows a page that scrolls under it', (tester) async {
    final (p, o, nav) = await pump(tester);
    nav.currentState!.push(over(o));
    await tester.pumpAndSettle();
    nav.currentState!.pop();
    await tester.pump();
    await tester.pump();
    expect(HeroLifts.flying, isTrue);
    // The page scrolls 100 while it flies: it lands where the row is now.
    RenderObject? scroll;
    void visit(RenderObject o) {
      if (scroll == null && o.runtimeType.toString() == 'RenderDesignScroll') scroll = o;
      o.visitChildren(visit);
    }

    visit(p.boxOf('r')!);
    (scroll! as dynamic).jumpTo(100.0);
    await tester.pump(const Duration(milliseconds: 260));
    await tester.pump(const Duration(milliseconds: 20));
    final late = HeroLifts.rectOf('m7')!;
    expect(late.top, closeTo(200 + (370 - 200) * (20 / 300), 6));
    await tester.pumpAndSettle();
    expect(markOf(p).liftShown, isTrue);
  });

  testWidgets('closing the overlay mid-flight turns the node round from where it is drawn', (tester) async {
    final (p, o, nav) = await pump(tester);
    nav.currentState!.push(over(o));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(HeroLifts.flying, isTrue);
    // The overlay closes 100 ms into the 300 ms flight (at y 323).
    nav.currentState!.pop();
    await tester.pump();
    await tester.pump();
    // It turns round from where it was drawn, not from the overlay's place.
    final turned = HeroLifts.rectOf('m7')!;
    expect(turned.top, closeTo(323, 6));
    await tester.pumpAndSettle();
    expect(HeroLifts.flying, isFalse);
    expect(markOf(p).liftShown, isTrue);
  });

  testWidgets('with reduced motion nothing flies: the overlay shows it at once', (tester) async {
    final (p, o, nav) = await pump(tester, reducedMotion: true);
    nav.currentState!.push(over(o));
    await tester.pump();
    await tester.pump();
    expect(HeroLifts.flying, isFalse);
    await tester.pump();
    expect(markOf(o).liftShown, isTrue);
    expect(markOf(p).liftShown, isFalse);
    await tester.pumpAndSettle();
  });

  group('a long press with its own hold, a commit point and a buzz', () {
    Future<(harness.Screen, List<String>)> holdable(WidgetTester tester, Json trigger) async {
      final buzzes = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'HapticFeedback.vibrate') buzzes.add('${call.arguments}');
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      final s = await harness.show(
          tester,
          harness.counter(actions: [
            harness.reaction('longPress', [harness.add('count')], extra: trigger),
          ]),
          variables: [harness.v('count', 0, VariableType.integer)]);
      return (s, buzzes);
    }

    const keys = {'holdMs': 800, 'commitMs': 400, 'haptic': 'heavy'};

    testWidgets('let go before the commit point: nothing', (tester) async {
      final (s, buzzes) = await holdable(tester, keys);
      final g = await tester.startGesture(s.center('button'));
      await tester.pump(const Duration(milliseconds: 300));
      await g.up();
      await tester.pump(const Duration(milliseconds: 800));
      expect(s['count'], 0);
      expect(buzzes, isEmpty);
    });

    testWidgets('past the commit point it buzzes, and letting go no longer cancels: it fires at 800', (tester) async {
      final (s, buzzes) = await holdable(tester, keys);
      final g = await tester.startGesture(s.center('button'));
      await tester.pump(const Duration(milliseconds: 399));
      expect(buzzes, isEmpty);
      await tester.pump(const Duration(milliseconds: 2));
      expect(buzzes, ['HapticFeedbackType.heavyImpact']);
      await tester.pump(const Duration(milliseconds: 100));
      await g.up();
      await tester.pump(const Duration(milliseconds: 200));
      expect(s['count'], 0, reason: 'not yet: 700 ms');
      await tester.pump(const Duration(milliseconds: 120));
      expect(s['count'], 1);
      expect(buzzes, hasLength(1));
    });

    testWidgets('without a commit point, holdMs is the long press\'s own time', (tester) async {
      final (s, buzzes) = await holdable(tester, {'holdMs': 800, 'haptic': 'medium'});
      final g = await tester.startGesture(s.center('button'));
      await tester.pump(const Duration(milliseconds: 600));
      expect(s['count'], 0, reason: 'past the platform\'s 500 ms, short of its 800');
      await tester.pump(const Duration(milliseconds: 250));
      expect(s['count'], 1);
      expect(buzzes, ['HapticFeedbackType.mediumImpact']);
      await g.up();
    });

    testWidgets('a long press with none of the keys is the platform\'s (500 ms)', (tester) async {
      final (s, buzzes) = await holdable(tester, const {});
      final g = await tester.startGesture(s.center('button'));
      await tester.pump(const Duration(milliseconds: 520));
      expect(s['count'], 1);
      expect(buzzes, isEmpty);
      await g.up();
    });
  });
}
