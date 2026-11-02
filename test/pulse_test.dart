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
}
