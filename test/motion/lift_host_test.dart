// A lifted shared element (`hero` with `flies: lift`) of a screen under a
// CodelesslyViewHost flies in the host's overlay, out and back, inside the
// host's box: also when the box is drawn at half size.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _lift = {
  'tag': 'm7',
  'flies': 'lift',
  'flight': {'duration': 300, 'curve': 'linear'},
};

NodeTree _tree(Json layout, {required bool scrolls}) => NodeTree(DocumentSource(LayoutDocument.fromJson({
      'schema': 3,
      'roots': ['r'],
      'nodes': {
        'r': {
          'type': 'stack',
          'children': ['h'],
          'layout': {'width': 400, 'height': 800},
        },
        'h': {
          'type': 'box',
          'hero': _lift,
          'layout': layout,
          'decoration': {
            'fills': [
              {'color': '#FFF1F5F9'},
            ],
          },
        },
      },
    })));

Json _at(double x, double y) => {'width': 200, 'height': 60, 'x': {'start': x}, 'y': {'start': y}};

/// A screen as the app shell shows it: its tree bound to the route it is in
/// and to the host it is under.
Widget _screen(NodeTree tree) => Builder(builder: (context) {
      HeroRoutes.bind(tree, ModalRoute.of(context), host: () => context.mounted ? CodelesslyViewHost.navigatorOf(context) : null);
      return Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'r', interactive: true));
    });

Route<void> _over(NodeTree tree) => PageRouteBuilder<void>(
      opaque: false,
      transitionDuration: const Duration(milliseconds: 150),
      reverseTransitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (_, _, _) => _screen(tree),
      transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
    );

Rect _rect(RenderBox o) => MatrixUtils.transformRect(o.getTransformTo(null), Offset.zero & o.size);

OverlayState _overlayOf(WidgetTester tester, RenderObject o) {
  final overlays = {
    for (final s in tester.stateList<OverlayState>(find.byType(Overlay, skipOffstage: false))) s.context.findRenderObject()!: s,
  };
  for (RenderObject? p = o; p != null; p = p.parent) {
    if (overlays[p] case final OverlayState s) return s;
  }
  throw StateError('in no overlay');
}

void main() {
  for (final scale in [1.0, 0.5]) {
    testWidgets('under a host drawn at $scale, a lifted node flies out and back in the host\'s overlay, inside its box', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1440, 900);
      addTearDown(tester.view.reset);
      final page = _tree(_at(0, 300), scrolls: false);
      final over = _tree(_at(100, 370), scrolls: false);
      addTearDown(page.dispose);
      addTearDown(over.dispose);
      final box = const Offset(100, 20) & (const Size(400, 800) * scale);
      await tester.pumpWidget(WidgetsApp(
        color: const Color(0xFFFFFFFF),
        pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder builder) =>
            PageRouteBuilder<T>(settings: settings, pageBuilder: (context, _, _) => builder(context)),
        home: Stack(children: [
          Positioned(
            left: 100,
            top: 20,
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 400,
                height: 800,
                child: MediaQuery(
                  data: const MediaQueryData(size: Size(400, 800)),
                  child: CodelesslyViewHost(child: _screen(page)),
                ),
              ),
            ),
          ),
        ]),
      ));
      await tester.pump();
      final NavigatorState host = CodelesslyViewHost.navigatorOf(tester.element(find.byType(NodeView)))!;
      expect(_rect(host.overlay!.context.findRenderObject()! as RenderBox), box);

      Future<void> flying(Offset from, Offset to) async {
        expect(HeroLifts.flying, isTrue);
        final drawn = tester.renderObject<RenderBox>(find.byType(HeroMarkPaint));
        expect(_overlayOf(tester, drawn), same(host.overlay), reason: 'drawn in the host\'s overlay');
        // Where it starts, in the box's own coordinates at its scale.
        final start = _rect(drawn);
        expect(start.topLeft.dx, closeTo(box.left + from.dx * scale, 2));
        expect(start.topLeft.dy, closeTo(box.top + from.dy * scale, 2));
        expect(start.size.width, closeTo(200 * scale, 0.01));
        await tester.pump(const Duration(milliseconds: 150));
        final mid = _rect(tester.renderObject<RenderBox>(find.byType(HeroMarkPaint)));
        final middle = Offset.lerp(from, to, 0.5)! * scale + box.topLeft;
        expect((mid.topLeft - middle).distance, lessThan(4));
        expect(box.contains(mid.topLeft) && box.contains(mid.bottomRight), isTrue, reason: '$mid in $box');
        await tester.pump(const Duration(milliseconds: 200));
        expect(HeroLifts.flying, isFalse);
      }

      host.push(_over(over));
      await tester.pump();
      await tester.pump();
      await flying(const Offset(0, 300), const Offset(100, 370));

      host.pop();
      await tester.pump();
      await tester.pump();
      await flying(const Offset(100, 370), const Offset(0, 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    });
  }
}
