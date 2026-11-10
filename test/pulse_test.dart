import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// The opacity the pulse gives the node right now.
double fade(WidgetTester tester) => tester
    .widget<FadeTransition>(
      find.descendant(
        of: find.byType(PulseOpacity),
        matching: find.byType(FadeTransition),
      ),
    )
    .opacity
    .value;

void main() {
  testWidgets('a node with a pulse fades between its faint and full opacity', (
    tester,
  ) async {
    final node = TextNode(
      id: 'bar',
      name: 'Skeleton',
      basicBoxLocal: NodeBox(0, 0, 100, 20),
      data: 'Loading',
      opacity: 0.8,
    )..pulse = const PulseModel(minOpacity: 0.5, durationMillis: 1000);
    final registry = NodeRegistry()..setNodes({node.id: node});
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: CodelesslyContext.empty(),
        child: MaterialApp(
          home: Builder(
            builder: (context) => manager.buildWidgetFromNode(
              node,
              context,
              settings: const WidgetBuildSettings(debugLabel: 'test'),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(PulseOpacity), findsOneWidget);
    expect(fade(tester), closeTo(0.4, 1e-6));
    await tester.pump(const Duration(milliseconds: 1000));
    expect(fade(tester), closeTo(0.8, 1e-6));
    await tester.pump(const Duration(milliseconds: 500));
    expect(fade(tester), allOf(greaterThan(0.4), lessThan(0.8)));
    await tester.pump(const Duration(milliseconds: 500));
    expect(fade(tester), closeTo(0.4, 1e-6));
  });

  testWidgets('a node without a pulse has no fade', (tester) async {
    final node = TextNode(
      id: 'bar',
      name: 'Bar',
      basicBoxLocal: NodeBox(0, 0, 100, 20),
      data: 'Ready',
    );
    final registry = NodeRegistry()..setNodes({node.id: node});
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: CodelesslyContext.empty(),
        child: MaterialApp(
          home: Builder(
            builder: (context) => manager.buildWidgetFromNode(
              node,
              context,
              settings: const WidgetBuildSettings(debugLabel: 'test'),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(PulseOpacity), findsNothing);
  });

  testWidgets('a node hidden by a binding stops its pulse from ticking', (
    tester,
  ) async {
    final node = TextNode(
      id: 'glow',
      name: 'Glow',
      basicBoxLocal: NodeBox(0, 0, 100, 20),
      data: 'Fits',
      variables: {'visible': r'${= 1 > 2}'},
    )..pulse = const PulseModel(minOpacity: 0.5, durationMillis: 1000);
    final registry = NodeRegistry()..setNodes({node.id: node});
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: CodelesslyContext.empty(),
        child: MaterialApp(
          home: Builder(
            builder: (context) => manager.buildWidgetFromNode(
              node,
              context,
              settings: const WidgetBuildSettings(debugLabel: 'test'),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(PulseOpacity, skipOffstage: false), findsOneWidget);
    final Iterable<TickerMode> modes = tester.widgetList<TickerMode>(
      find.ancestor(
        of: find.byType(PulseOpacity, skipOffstage: false),
        matching: find.byType(TickerMode, skipOffstage: false),
      ),
    );
    expect(modes.any((mode) => !mode.enabled), isTrue);
  });

  group('phase', () {
    test('phase and delayMs survive JSON in both modes', () {
      const relative = PulseModel(durationMillis: 600, phase: 0.25);
      expect(PulseModel.fromJson(relative.toJson()), relative);
      const motion = MotionPulseModel(scaleTo: 1.4, delayMs: 160);
      final PulseModel back = PulseModel.fromJson(motion.toJson());
      expect(back, isA<MotionPulseModel>());
      expect(back, motion);
      expect(const PulseModel().toJson().containsKey('phase'), isFalse);
      // A delay is a phase behind: 300 ms of a 1200 ms loop.
      expect(
        const PulseModel(durationMillis: 600, delayMs: 300).startFraction,
        closeTo(0.75, 1e-9),
      );
      expect(const PulseModel(phase: 1.25).startFraction, closeTo(0.25, 1e-9));
    });

    testWidgets(r'three loading dots ripple in sequence by ${index}', (
      tester,
    ) async {
      final RectangleNode dot = RectangleNode.fromJson({
        ...RectangleNode(
          id: 'dot',
          name: 'Dot',
          basicBoxLocal: NodeBox(0, 0, 10, 10),
        ).toJson(),
        'pulse': const PulseModel(minOpacity: 0, durationMillis: 500).toJson(),
        'variables': {'pulsePhase': r'${= index * 0.25}'},
      });
      final ListViewNode dots = ListViewNode(
        id: 'dots',
        name: 'Dots',
        basicBoxLocal: NodeBox(0, 0, 60, 10),
        scrollDirection: AxisC.horizontal,
        properties: ListViewProperties(itemCount: 3),
        children: ['dot'],
      )..parentID = kRootNode;
      dot.parentID = dots.id;
      final registry = NodeRegistry()..setNodes({dots.id: dots, dot.id: dot});
      final manager = PassiveNodeTransformerManager(
        registry.getNodeByID,
        (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
      );
      await tester.pumpWidget(
        ChangeNotifierProvider<CodelesslyContext>.value(
          value: CodelesslyContext.empty(),
          child: MaterialApp(
            home: Builder(
              builder: (context) => manager.buildWidgetFromNode(
                dots,
                context,
                settings: const WidgetBuildSettings(debugLabel: 'test'),
              ),
            ),
          ),
        ),
      );
      List<double> fades() => [
        for (final FadeTransition t in tester.widgetList<FadeTransition>(
          find.descendant(
            of: find.byType(PulseOpacity),
            matching: find.byType(FadeTransition),
          ),
        ))
          t.opacity.value,
      ];
      // A 1000 ms loop: index 0 starts faint, 1 is half-way up (a quarter
      // of the loop on), 2 is at full (half the loop on).
      expect(find.byType(PulseOpacity), findsNWidgets(3));
      List<double> now = fades();
      expect(now[0], closeTo(0, 1e-6));
      expect(now[1], closeTo(0.5, 1e-6));
      expect(now[2], closeTo(1, 1e-6));
      // A quarter loop later each has moved on by a quarter.
      await tester.pump(const Duration(milliseconds: 250));
      now = fades();
      expect(now[0], closeTo(0.5, 1e-6));
      expect(now[1], closeTo(1, 1e-6));
      expect(now[2], closeTo(0.5, 1e-6));
      await tester.pump(const Duration(milliseconds: 250));
      now = fades();
      expect(now[0], closeTo(1, 1e-6));
      expect(now[1], closeTo(0.5, 1e-6));
      expect(now[2], closeTo(0, 1e-6));
    });

    testWidgets('a motion pulse starts at its phase', (tester) async {
      final node =
          RectangleNode(
              id: 'dot',
              name: 'Dot',
              basicBoxLocal: NodeBox(0, 0, 10, 10),
            )
            ..pulse = const MotionPulseModel(
              periodMs: 400,
              scaleFrom: 1,
              scaleTo: 2,
              phase: 0.5,
            )
            ..parentID = kRootNode;
      final registry = NodeRegistry()..setNodes({node.id: node});
      final manager = PassiveNodeTransformerManager(
        registry.getNodeByID,
        (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
      );
      await tester.pumpWidget(
        ChangeNotifierProvider<CodelesslyContext>.value(
          value: CodelesslyContext.empty(),
          child: MaterialApp(
            home: Builder(
              builder: (context) => manager.buildWidgetFromNode(
                node,
                context,
                settings: const WidgetBuildSettings(debugLabel: 'test'),
              ),
            ),
          ),
        ),
      );
      double scale() => tester
          .widget<Transform>(
            find
                .descendant(
                  of: find.byType(NodePulse),
                  matching: find.byType(Transform),
                )
                .first,
          )
          .transform
          .getMaxScaleOnAxis();
      // Half of an 800 ms there-and-back loop: at the far end.
      expect(scale(), closeTo(2, 1e-6));
      await tester.pump(const Duration(milliseconds: 400));
      expect(scale(), closeTo(1, 1e-6));
    });
  });
}
