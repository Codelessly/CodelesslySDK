import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'viewport_layout_test.dart' as vp;

double opacityOf(WidgetTester tester) {
  final Finder finder = find.byType(Opacity);
  return finder.evaluate().isEmpty
      ? 1
      : tester.widget<Opacity>(finder.first).opacity;
}

/// A section fading up as the page reaches it.
const MotionModel reveal = MotionModel(
  durationMs: 400,
  revealOnScroll: true,
  enterFrom: MotionModel(translateY: 24, opacity: 0),
);

/// Shows a revealing box below the fold of a 600 tall window.
Future<void> pumpBelowFold(WidgetTester tester, {required bool canvas}) async {
  tester.view.physicalSize = const Size(400, 600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final Widget page = SingleChildScrollView(
    child: Column(
      children: [
        const SizedBox(height: 2000),
        NodeMotion(
          motion: reveal,
          child: const SizedBox(width: 100, height: 100),
        ),
      ],
    ),
  );
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: canvas ? NodeMotionScope(animate: false, child: page) : page,
    ),
  );
  await tester.pump();
}

/// A plan card filling the list's cross axis, with content 80 tall.
List<BaseNode> planCard() => [
  RowColumnNode(
    id: 'plan',
    name: 'plan',
    basicBoxLocal: NodeBox(0, 0, 100, 80),
    rowColumnType: RowColumnType.column,
    horizontalFit: SizeFit.fixed,
    verticalFit: SizeFit.expanded,
    children: ['price'],
  )..parentID = 'plans',
  vp.rect('price', 'plan', width: 100, height: 80),
];

Finder planOf() => vp.rectOf('plan');

void main() {
  group('revealOnScroll on the design canvas', () {
    testWidgets('waits below the fold at runtime', (tester) async {
      await pumpBelowFold(tester, canvas: false);
      expect(opacityOf(tester), 0);
    });

    testWidgets('shows at rest below a NodeMotionScope that turns motion off', (
      tester,
    ) async {
      await pumpBelowFold(tester, canvas: true);
      expect(opacityOf(tester), 1);
      expect(find.byType(Transform), findsNothing);
      expect(find.byType(ViewportVisibility), findsNothing);
    });

    testWidgets('a patched node built by the SDK manager is visible', (
      tester,
    ) async {
      final RectangleNode node = vp.rect('card', kRootNode)
        ..motion = MotionModel.fromJson({
          'revealOnScroll': true,
          'durationMs': 600,
          'enterFrom': {'translateY': 24, 'opacity': 0},
        });
      final registry = NodeRegistry()..setNodes({node.id: node});
      final manager = PassiveNodeTransformerManager(
        registry.getNodeByID,
        (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
      );
      tester.view.physicalSize = const Size(400, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ChangeNotifierProvider<CodelesslyContext>.value(
          value: CodelesslyContext.empty(),
          child: MaterialApp(
            home: NodeMotionScope(
              animate: false,
              // Off screen: a runtime reveal would never play here.
              child: Transform.translate(
                offset: const Offset(0, 5000),
                child: Builder(
                  builder: (context) => manager.buildWidgetFromNode(
                    node,
                    context,
                    settings: const WidgetBuildSettings(debugLabel: 'test'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(opacityOf(tester), 1);
    });
  });

  group('motion curves', () {
    test('step holds, then jumps halfway', () {
      final Curve step = flutterCurveOf(MotionCurve.step);
      expect(step.transform(0), 0);
      expect(step.transform(0.49), 0);
      expect(step.transform(0.51), 1);
      expect(step.transform(1), 1);
    });

    test('easeInOutCubic is Flutter\'s', () {
      expect(flutterCurveOf(MotionCurve.easeInOutCubic), Curves.easeInOutCubic);
    });

    testWidgets('a reverse step loop blinks hard on and off', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: NodeMotion(
              motion: MotionModel(
                durationMs: 500,
                curve: MotionCurve.step,
                loop: MotionLoop.reverse,
                opacity: 0,
              ),
              child: SizedBox(width: 2, height: 20),
            ),
          ),
        ),
      );
      final List<double> seen = [];
      for (int i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        seen.add(opacityOf(tester));
      }
      expect(seen.every((o) => o == 0 || o == 1), isTrue, reason: '$seen');
      expect(seen, containsAll(<double>[0, 1]));
    });
  });

  group('radial gradient centre and radius', () {
    PaintModel radial({AlignmentData? center, double? radius}) =>
        PaintModel.radialGradient(
          id: 'p',
          gradientStops: const [
            ColorStop(color: ColorRGBA.black, position: 0),
            ColorStop(color: ColorRGBA.white, position: 1),
          ],
          gradientCenter: center,
          gradientRadius: radius,
        );

    test('defaults to centred, half the shortest side', () {
      final RadialGradient gradient =
          retrieveGradient(radial()) as RadialGradient;
      expect(gradient.center, Alignment.center);
      expect(gradient.radius, 0.5);
      expect(gradient.transform, isA<GradientRotation>());
    });

    test('takes the centre and a radius of the longest side', () {
      final RadialGradient gradient = retrieveGradient(
        radial(center: const AlignmentData(0.2, 1.4), radius: 0.8),
      ) as RadialGradient;
      expect(gradient.center, const Alignment(0.2, 1.4));
      expect(gradient.radius, 0.8);
      const Rect box = Rect.fromLTWH(0, 0, 400, 200);
      final Matrix4 matrix = gradient.transform!.transform(box)!;
      // The longest side is twice the shortest: the radius doubles about
      // the centre, which stays put.
      expect(matrix.getMaxScaleOnAxis(), closeTo(2, 1e-9));
      final Offset c = const Alignment(0.2, 1.4).withinRect(box);
      final Offset mapped = MatrixUtils.transformPoint(matrix, c);
      expect(mapped.dx, closeTo(c.dx, 1e-9));
      expect(mapped.dy, closeTo(c.dy, 1e-9));
      // 0.8 of the longest side.
      expect(gradient.radius * box.shortestSide * 2, closeTo(0.8 * 400, 1e-9));
    });

    test('a centre alone keeps the default radius', () {
      final RadialGradient gradient = retrieveGradient(
        radial(center: const AlignmentData(-1, -1)),
      ) as RadialGradient;
      expect(gradient.center, Alignment.topLeft);
      expect(gradient.radius, 0.5);
      expect(
        gradient.transform!.transform(const Rect.fromLTWH(0, 0, 400, 200)),
        isNull,
      );
    });
  });

  group('size transition', () {
    Future<StateSetter> pumpBox(
      WidgetTester tester, {
      required ValueNotifier<double> height,
      bool resizeHeight = false,
      bool canvas = false,
    }) async {
      late StateSetter setState;
      final Widget box = StatefulBuilder(
        builder: (context, set) {
          setState = set;
          return Align(
            alignment: Alignment.topLeft,
            child: NodeSizeTransition(
              duration: const Duration(milliseconds: 200),
              curve: Curves.linear,
              resizeHeight: resizeHeight,
              child: SizedBox(
                width: 100,
                height: height.value,
                child: const ColoredBox(color: Colors.blue),
              ),
            ),
          );
        },
      );
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: canvas ? NodeMotionScope(animate: false, child: box) : box,
        ),
      );
      return setState;
    }

    Size boxSize(WidgetTester tester) =>
        tester.getSize(find.byType(NodeSizeTransition));
    Size childSize(WidgetTester tester) =>
        tester.getSize(find.byType(ColoredBox));

    testWidgets('content that appears is revealed over the duration', (
      tester,
    ) async {
      final ValueNotifier<double> height = ValueNotifier(40);
      final StateSetter setState = await pumpBox(tester, height: height);
      expect(boxSize(tester).height, 40);
      setState(() => height.value = 140);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(boxSize(tester).height, closeTo(90, 1));
      // Hugging: the content is at its new size at once, clipped.
      expect(childSize(tester).height, 140);
      await tester.pump(const Duration(milliseconds: 150));
      expect(boxSize(tester).height, 140);
    });

    testWidgets('a set size is laid out at each size in between', (
      tester,
    ) async {
      final ValueNotifier<double> height = ValueNotifier(100);
      final StateSetter setState = await pumpBox(
        tester,
        height: height,
        resizeHeight: true,
      );
      setState(() => height.value = 20);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(boxSize(tester).height, closeTo(60, 1));
      expect(childSize(tester).height, closeTo(60, 1));
      await tester.pumpAndSettle();
      expect(childSize(tester).height, 20);
    });

    testWidgets('the design canvas shows the final size', (tester) async {
      final ValueNotifier<double> height = ValueNotifier(40);
      final StateSetter setState = await pumpBox(
        tester,
        height: height,
        canvas: true,
      );
      setState(() => height.value = 140);
      await tester.pump();
      expect(boxSize(tester).height, 140);
    });

    testWidgets('the manager animates a node with a sizeTransition', (
      tester,
    ) async {
      final RectangleNode node = vp.rect('answer', kRootNode)
        ..sizeTransition = const NodeTransition(durationMillis: 250);
      await vp.pump(tester, const Size(400, 600), vp.Host.loose, node, []);
      final NodeSizeTransition transition = tester.widget(
        find.byType(NodeSizeTransition),
      );
      expect(transition.duration, const Duration(milliseconds: 250));
      expect(transition.resizeWidth, isTrue);
      expect(transition.resizeHeight, isTrue);
    });
  });

  group('stretchItems', () {
    testWidgets('each item of a run is as tall as the tallest', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 250,
              child: Align(
                alignment: Alignment.topLeft,
                child: RunStretchWrap(
                  spacing: 10,
                  runSpacing: 5,
                  children: [
                    SizedBox(key: ValueKey(0), width: 100, height: 30),
                    SizedBox(key: ValueKey(1), width: 100, height: 60),
                    SizedBox(key: ValueKey(2), width: 100, height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      Rect rectOf(int i) => tester.getRect(find.byKey(ValueKey(i)));
      expect(rectOf(0), const Rect.fromLTWH(0, 0, 100, 60));
      expect(rectOf(1), const Rect.fromLTWH(110, 0, 100, 60));
      // Second run, on its own.
      expect(rectOf(2), const Rect.fromLTWH(0, 65, 100, 20));
      expect(tester.getSize(find.byType(RunStretchWrap)), const Size(210, 85));
      final RenderBox wrap = tester.renderObject(find.byType(RunStretchWrap));
      expect(wrap.getMaxIntrinsicHeight(250), 85);
      expect(wrap.getMaxIntrinsicWidth(double.infinity), 320);
    });

    ListViewNode plans({bool wrap = false, bool stretch = true}) =>
        vp.list(
            id: 'plans',
            item: 'plan',
            itemCount: 3,
            width: 600,
            height: 200,
            scrollDirection: AxisC.horizontal,
            horizontalFit: SizeFit.shrinkWrap,
            verticalFit: SizeFit.shrinkWrap,
          )
          ..isScrollable = false
          ..properties.wrap = wrap
          ..properties.hasSeparator = true
          ..properties.separatorSpacing = 12
          ..properties.stretchItems = stretch;

    vp.forEachLayout('a hugging row of plan cards stretches its items', (
      tester,
      screen,
      host,
    ) async {
      await vp.pump(tester, screen, host, plans(), [...planCard()]);
      expect(find.byType(IntrinsicHeight), findsOneWidget);
      final Finder items = vp.rectOf('plan');
      expect(items, findsNWidgets(3));
      for (int i = 0; i < 3; i++) {
        expect(
          tester.getSize(items.at(i)).height,
          tester.getSize(find.byType(PassiveListViewWidget)).height,
        );
      }
    });

    vp.forEachLayout('a wrapping feature grid stretches each run', (
      tester,
      screen,
      host,
    ) async {
      await vp.pump(tester, screen, host, plans(wrap: true), [...planCard()]);
      expect(find.byType(RunStretchWrap), findsOneWidget);
      expect(tester.getSize(vp.rectOf('plan').first).height, 80);
    });

    vp.forEachLayout('a list with a shrink-wrapped cross axis hugs its items', (
      tester,
      screen,
      host,
    ) async {
      await vp.pump(tester, screen, host, plans(stretch: false), [
        vp.rect('plan', 'plans', width: 100, height: 80),
      ]);
      if (host != vp.Host.tight) {
        expect(tester.getSize(find.byType(PassiveListViewWidget)).height, 80);
      }
      expect(tester.getSize(vp.rectOf('plan').first).height, 80);
    });
  });
}
