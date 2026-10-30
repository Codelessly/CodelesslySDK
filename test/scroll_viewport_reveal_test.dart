import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/functions/action_chain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Reaction call(TriggerType type, String function, {double? fraction}) =>
    Reaction(
      trigger: TriggerModel(
        type: type,
        visibleFraction: fraction ?? kDefaultVisibleFraction,
      ),
      action: CallFunctionAction(name: function),
    );

RectangleNode rect(
  String id, {
  List<Reaction> reactions = const [],
  MotionModel? motion,
  Map<String, String> variables = const {},
}) =>
    RectangleNode(
        id: id,
        name: id,
        basicBoxLocal: NodeBox(0, 0, 300, 400),
        reactions: reactions,
      )
      ..parentID = kRootNode
      ..variables = Map.of(variables)
      ..motion = motion;

/// The calls made to the layout's functions, by name.
final List<String> calls = [];

/// Shows [header] (if any) above a scrolling page of [sections], each 400
/// tall, in a 800x600 window.
Future<ScrollController> pumpPage(
  WidgetTester tester,
  List<BaseNode> sections, {
  BaseNode? header,
  List<BaseNode> others = const [],
}) async {
  tester.view.physicalSize = const Size(800, 600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  calls.clear();
  final registry = NodeRegistry()
    ..setNodes({
      for (final node in [?header, ...sections, ...others]) node.id: node,
    });
  final manager = PassiveNodeTransformerManager(
    registry.getNodeByID,
    (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
  );
  final codelesslyContext = CodelesslyContext.empty()
    ..functions = {
      for (final name in [
        'enterA',
        'exitA',
        'enterB',
        'exitB',
        'fullB',
        'enterC',
        'exitC',
      ])
        name: (context, reference, params) => calls.add(name),
    };
  final ScrollController controller = ScrollController();
  addTearDown(controller.dispose);
  Widget build(BuildContext context, BaseNode node) =>
      manager.buildWidgetFromNode(
        node,
        context,
        settings: const WidgetBuildSettings(debugLabel: 'test'),
      );
  await tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: codelesslyContext,
      child: MaterialApp(
        home: Material(
          child: ActionChainHost(
            child: Builder(
              builder: (context) => Stack(
                children: [
                  SingleChildScrollView(
                    controller: controller,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final node in sections)
                          SizedBox(
                            height: 400,
                            child: Align(
                              alignment: Alignment.topLeft,
                              child: build(context, node),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (header != null)
                    Positioned(
                      top: 0,
                      left: 0,
                      child: SizedBox(
                        width: 300,
                        height: 64,
                        child: build(context, header),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return controller;
}

RectangleNode navLink(String target, {int durationMs = 600}) => RectangleNode(
  id: 'nav',
  name: 'nav',
  basicBoxLocal: NodeBox(0, 0, 300, 64),
  reactions: [
    Reaction(
      trigger: TriggerModel(type: TriggerType.click),
      action: ScrollToAction(
        nodeId: target,
        offset: 64,
        durationMs: durationMs,
        curve: MotionCurve.linear,
      ),
    ),
  ],
)..parentID = kRootNode;

void main() {
  group('Scroll to', () {
    testWidgets('scrolls the page so the node sits under the header', (
      tester,
    ) async {
      final controller = await pumpPage(tester, [
        rect('a'),
        rect('b'),
        rect('c'),
        rect('d'),
      ], header: navLink('c'));
      await tester.tapAt(const Offset(20, 20));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      // Half way there, linearly.
      expect(controller.offset, closeTo((800 - 64) / 2, 2));
      await tester.pumpAndSettle();
      expect(controller.offset, 800 - 64);
    });

    testWidgets('clamps to the end of the page', (tester) async {
      final controller = await pumpPage(tester, [
        rect('a'),
        rect('b'),
        rect('c'),
        rect('d'),
      ], header: navLink('d', durationMs: 0));
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      // 4 sections of 400 in a 600 tall window scroll at most 1000.
      expect(controller.offset, 1000);
    });

    testWidgets('does nothing for a node that is not shown', (tester) async {
      final controller = await pumpPage(tester, [
        rect('a'),
        rect('b'),
      ], header: navLink('missing'));
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      expect(controller.offset, 0);
    });

    testWidgets('scrolls a scrollable inside the page, then the page', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final target = rect('inner');
      final registry = NodeRegistry()..setNodes({target.id: target});
      final manager = PassiveNodeTransformerManager(
        registry.getNodeByID,
        (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
      );
      final outer = ScrollController();
      final inner = ScrollController();
      addTearDown(outer.dispose);
      addTearDown(inner.dispose);
      late BuildContext actionContext;
      await tester.pumpWidget(
        ChangeNotifierProvider<CodelesslyContext>.value(
          value: CodelesslyContext.empty(),
          child: MaterialApp(
            home: Material(
              child: Builder(
                builder: (context) {
                  actionContext = context;
                  return SingleChildScrollView(
                    controller: outer,
                    child: Column(
                      children: [
                        const SizedBox(height: 900),
                        SizedBox(
                          height: 300,
                          child: SingleChildScrollView(
                            controller: inner,
                            child: Column(
                              children: [
                                const SizedBox(height: 700),
                                SizedBox(
                                  height: 400,
                                  child: manager.buildWidgetFromNode(
                                    target,
                                    context,
                                    settings: const WidgetBuildSettings(
                                      debugLabel: 'test',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 900),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      final result = FunctionsRepository.scrollToNode(
        actionContext,
        ScrollToAction(nodeId: 'inner', durationMs: 200),
      );
      await tester.pumpAndSettle();
      expect(await result, isTrue);
      expect(inner.offset, 700);
      expect(outer.offset, 900);
    });
  });

  group('Viewport triggers', () {
    testWidgets('fire on the first frame for nodes in view, then on scroll', (
      tester,
    ) async {
      final controller = await pumpPage(tester, [
        rect(
          'a',
          reactions: [
            call(TriggerType.enterViewport, 'enterA'),
            call(TriggerType.exitViewport, 'exitA'),
          ],
        ),
        rect(
          'b',
          reactions: [
            call(TriggerType.enterViewport, 'enterB'),
            call(TriggerType.enterViewport, 'fullB', fraction: 1),
          ],
        ),
        rect(
          'c',
          reactions: [
            call(TriggerType.enterViewport, 'enterC'),
            call(TriggerType.exitViewport, 'exitC'),
          ],
        ),
      ]);
      await tester.pump();
      // a fills the top, half of b shows, c is below the fold.
      expect(calls, unorderedEquals(['enterA', 'enterB']));

      calls.clear();
      controller.jumpTo(200);
      await tester.pump();
      await tester.pump();
      // b is now wholly in view; a still shows its bottom half.
      expect(calls, ['fullB']);

      calls.clear();
      controller.jumpTo(600);
      await tester.pump();
      await tester.pump();
      expect(calls, unorderedEquals(['exitA', 'enterC']));

      calls.clear();
      controller.jumpTo(0);
      await tester.pump();
      await tester.pump();
      expect(calls, unorderedEquals(['enterA', 'exitC']));
    });

    testWidgets('re-measure when the window resizes', (tester) async {
      await pumpPage(tester, [
        rect('a'),
        rect('b'),
        rect(
          'c',
          reactions: [
            call(TriggerType.enterViewport, 'enterC', fraction: 0),
            call(TriggerType.exitViewport, 'exitC', fraction: 0),
          ],
        ),
      ]);
      expect(calls, isEmpty);
      tester.view.physicalSize = const Size(800, 1000);
      await tester.pump();
      await tester.pump();
      expect(calls, ['enterC']);
    });

    test('the visible fraction threshold', () {
      expect(meetsVisibleFraction(0.01, 0), isTrue);
      expect(meetsVisibleFraction(0, 0), isFalse);
      expect(meetsVisibleFraction(0.15, 0.15), isTrue);
      expect(meetsVisibleFraction(0.1, 0.15), isFalse);
      expect(meetsVisibleFraction(1, 1), isTrue);
    });
  });

  group('Scroll reveal', () {
    double opacityOf(WidgetTester tester, String id) {
      final Finder opacity = find.descendant(
        of: find.byType(NodeMotion),
        matching: find.byType(Opacity),
      );
      final Finder mine = find.descendant(
        of: find.byWidgetPredicate(
          (w) => w is NodeStateProviderWidget && w.node.id == id,
        ),
        matching: opacity,
      );
      if (mine.evaluate().isEmpty) return 1;
      return tester.widget<Opacity>(mine.first).opacity;
    }

    MotionModel reveal({int delayMs = 0}) => MotionModel(
      revealOnScroll: true,
      durationMs: 300,
      curve: MotionCurve.linear,
      delayMs: delayMs,
      enterFrom: const MotionModel(translateY: 40, opacity: 0),
    );

    testWidgets('holds a node out of view, then plays once it scrolls in', (
      tester,
    ) async {
      final controller = await pumpPage(tester, [
        rect('a', motion: reveal()),
        rect('b'),
        rect('c', motion: reveal()),
      ]);
      await tester.pump();
      // a is in view and plays at once; c waits below the fold.
      await tester.pump(const Duration(milliseconds: 350));
      expect(opacityOf(tester, 'a'), 1);
      expect(opacityOf(tester, 'c'), 0);
      await tester.pump(const Duration(seconds: 2));
      expect(opacityOf(tester, 'c'), 0);

      controller.jumpTo(500);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(opacityOf(tester, 'c'), closeTo(0.5, 0.05));
      await tester.pump(const Duration(milliseconds: 200));
      expect(opacityOf(tester, 'c'), 1);

      // It plays once: scrolling away and back doesn't hide it again.
      controller.jumpTo(0);
      await tester.pump();
      controller.jumpTo(500);
      await tester.pump();
      await tester.pump();
      expect(opacityOf(tester, 'c'), 1);
    });

    testWidgets('a bound delay staggers the entrance', (tester) async {
      await pumpPage(tester, [
        rect(
          'a',
          motion: reveal(),
          variables: {'motion.delayMs': r'${= 2 * 100}'},
        ),
      ]);
      await tester.pump();
      Future<void> pumpFor(int ms) async {
        for (int t = 0; t < ms; t += 50) {
          await tester.pump(const Duration(milliseconds: 50));
        }
      }

      await pumpFor(150);
      expect(opacityOf(tester, 'a'), 0);
      await pumpFor(200);
      expect(opacityOf(tester, 'a'), closeTo(0.5, 0.05));
      await pumpFor(200);
      expect(opacityOf(tester, 'a'), 1);
    });

    testWidgets('reveals can be turned off for screenshots', (tester) async {
      NodeMotion.revealsEnabled = false;
      addTearDown(() => NodeMotion.revealsEnabled = true);
      await pumpPage(tester, [
        rect('a'),
        rect('b'),
        rect('c', motion: reveal()),
      ]);
      await tester.pump();
      expect(opacityOf(tester, 'c'), 1);
    });

    testWidgets('the canvas shows the node at rest', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: NodeMotion(
            motion: reveal(),
            animate: false,
            child: const SizedBox(width: 10, height: 10),
          ),
        ),
      );
      expect(find.byType(Opacity), findsNothing);
      expect(find.byType(ViewportVisibility), findsNothing);
    });
  });
}
