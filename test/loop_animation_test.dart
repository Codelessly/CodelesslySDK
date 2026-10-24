import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// The pulsing halo behind a selected walkaround marker: 58 px, growing
/// from 38 px (scale 0.655) while fading from 35% to nothing every 1.4 s.
RectangleNode halo({Map<String, String> variables = const {}}) {
  final RectangleNode node = RectangleNode.fromJson({
    ...RectangleNode(
      id: 'halo',
      name: 'Halo',
      basicBoxLocal: NodeBox(0, 0, 58, 58),
      fills: [PaintModel.solid(id: 'fill', color: ColorRGB.fromHex('#FFC20E'))],
    ).toJson(),
    'loopAnimation': {
      'type': 'pulse',
      'durationMs': 1400,
      'scaleFrom': 0.655,
      'scaleTo': 1.0,
      'opacityFrom': 0.35,
      'opacityTo': 0.0,
    },
    'variables': variables,
  });
  return node..parentID = kRootNode;
}

Future<void> pumpNode(
  WidgetTester tester,
  BaseNode node, {
  CodelesslyContext? codelesslyContext,
  bool tickers = true,
}) async {
  final registry = NodeRegistry()..setNodes({node.id: node});
  final manager = PassiveNodeTransformerManager(
    registry.getNodeByID,
    (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
  );
  await tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: codelesslyContext ?? CodelesslyContext.empty(),
      child: MaterialApp(
        home: TickerMode(
          enabled: tickers,
          child: Align(
            alignment: Alignment.topLeft,
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
}

/// Finds the transitions [LoopAnimationBox] builds, not the route's.
Finder inBox(Type type) => find.descendant(
  of: find.byType(LoopAnimationBox),
  matching: find.byType(type),
);

double scaleOf(WidgetTester tester) =>
    tester.widget<ScaleTransition>(inBox(ScaleTransition)).scale.value;

double opacityOf(WidgetTester tester) =>
    tester.widget<FadeTransition>(inBox(FadeTransition)).opacity.value;

Observable<VariableData> variable(String name, Object? value) =>
    Observable(VariableData(id: name, name: name, value: value));

void main() {
  group('Loop animation', () {
    testWidgets('a pulse grows and fades, then starts over', (tester) async {
      await pumpNode(tester, halo());

      expect(scaleOf(tester), closeTo(0.655, 1e-6));
      expect(opacityOf(tester), closeTo(0.35, 1e-6));

      await tester.pump(const Duration(milliseconds: 700));
      expect(scaleOf(tester), closeTo(0.8275, 1e-3));
      expect(opacityOf(tester), closeTo(0.175, 1e-3));

      await tester.pump(const Duration(milliseconds: 650));
      expect(scaleOf(tester), greaterThan(0.95));
      expect(opacityOf(tester), lessThan(0.02));

      // It repeats from the start rather than running back.
      await tester.pump(const Duration(milliseconds: 100));
      expect(scaleOf(tester), lessThan(0.7));
      expect(opacityOf(tester), greaterThan(0.3));

      // The layout size is the design size: the scale is paint only.
      expect(tester.getSize(inBox(ScaleTransition)), const Size(58, 58));
    });

    testWidgets('a reversing fade breathes back and forth', (tester) async {
      final RectangleNode node = halo()
        ..loopAnimation = const LoopAnimation(
          type: LoopAnimationType.fade,
          durationMs: 900,
          reverse: true,
          opacityFrom: 0.45,
          opacityTo: 1,
        );
      await pumpNode(tester, node);
      expect(inBox(ScaleTransition), findsNothing);

      expect(opacityOf(tester), closeTo(0.45, 1e-6));
      await tester.pump(const Duration(milliseconds: 900));
      expect(opacityOf(tester), closeTo(1, 1e-6));
      await tester.pump(const Duration(milliseconds: 450));
      expect(opacityOf(tester), closeTo(0.725, 1e-3));
      await tester.pump(const Duration(milliseconds: 450));
      expect(opacityOf(tester), closeTo(0.45, 1e-6));
    });

    testWidgets('a spin turns continuously after its delay', (tester) async {
      final RectangleNode node = halo()
        ..loopAnimation = const LoopAnimation(
          type: LoopAnimationType.spin,
          durationMs: 1000,
          delayMs: 200,
        );
      await pumpNode(tester, node);
      double turns() => tester
          .widget<RotationTransition>(inBox(RotationTransition))
          .turns
          .value;

      await tester.pump(const Duration(milliseconds: 200));
      expect(turns(), 0);
      await tester.pump(const Duration(milliseconds: 250));
      expect(turns(), closeTo(0.25, 1e-3));
    });

    testWidgets('a disabled animation leaves the node as designed', (
      tester,
    ) async {
      final RectangleNode node = halo();
      node.loopAnimation = node.loopAnimation!.copyWith(enabled: false);
      await pumpNode(tester, node);

      await tester.pump(const Duration(milliseconds: 700));
      expect(scaleOf(tester), 1);
      expect(opacityOf(tester), 1);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('a bound variable turns the animation on and off', (
      tester,
    ) async {
      final Observable<VariableData> selected = variable('selected', false);
      final CodelesslyContext codelesslyContext = CodelesslyContext.empty()
        ..variables['selected'] = selected;
      await pumpNode(
        tester,
        halo(variables: {'loopAnimationEnabled': r'${selected}'}),
        codelesslyContext: codelesslyContext,
      );

      await tester.pump(const Duration(milliseconds: 700));
      expect(scaleOf(tester), 1);
      expect(tester.hasRunningAnimations, isFalse);

      selected.set(selected.value.copyWith(value: true));
      await tester.pump();
      expect(scaleOf(tester), closeTo(0.655, 1e-6));
      await tester.pump(const Duration(milliseconds: 700));
      expect(scaleOf(tester), closeTo(0.8275, 1e-3));

      selected.set(selected.value.copyWith(value: false));
      await tester.pump();
      expect(scaleOf(tester), 1);
      expect(opacityOf(tester), 1);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('it holds still at its start under a disabled TickerMode', (
      tester,
    ) async {
      await pumpNode(tester, halo(), tickers: false);

      await tester.pump(const Duration(milliseconds: 700));
      expect(scaleOf(tester), closeTo(0.655, 1e-6));
      expect(opacityOf(tester), closeTo(0.35, 1e-6));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });

  group('Cursor triggers', () {
    Reaction on(TriggerType type, String value) => Reaction(
      trigger: TriggerModel(type: type),
      action: SetVariableAction(
        variable: VariableData(id: 'hoveredId', name: 'hoveredId'),
        newValue: value,
      ),
    );

    testWidgets('cursor enter and exit run their reactions', (tester) async {
      final Observable<VariableData> hoveredId = variable('hoveredId', '');
      final CodelesslyContext codelesslyContext = CodelesslyContext.empty()
        ..variables['hoveredId'] = hoveredId;
      final RectangleNode card = RectangleNode(
        id: 'card',
        name: 'Card',
        basicBoxLocal: NodeBox(0, 0, 200, 80),
        reactions: [
          on(TriggerType.cursorEnter, 'truck-7'),
          on(TriggerType.cursorExit, ''),
        ],
      )..parentID = kRootNode;
      await pumpNode(tester, card, codelesslyContext: codelesslyContext);

      final TestGesture mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: const Offset(400, 400));
      await tester.pump();
      expect(hoveredId.value.value, '');

      await mouse.moveTo(const Offset(100, 40));
      await tester.pumpAndSettle();
      expect(hoveredId.value.value, 'truck-7');

      // Moving within the card doesn't fire again.
      hoveredId.set(hoveredId.value.copyWith(value: 'other'));
      await mouse.moveTo(const Offset(120, 50));
      await tester.pumpAndSettle();
      expect(hoveredId.value.value, 'other');

      await mouse.moveTo(const Offset(400, 400));
      await tester.pumpAndSettle();
      expect(hoveredId.value.value, '');
    });

    testWidgets('a hover region still lets taps through to click reactions', (
      tester,
    ) async {
      final Observable<VariableData> hoveredId = variable('hoveredId', '');
      final CodelesslyContext codelesslyContext = CodelesslyContext.empty()
        ..variables['hoveredId'] = hoveredId;
      final RectangleNode card = RectangleNode(
        id: 'card',
        name: 'Card',
        basicBoxLocal: NodeBox(0, 0, 200, 80),
        reactions: [
          on(TriggerType.cursorEnter, 'hover'),
          on(TriggerType.click, 'clicked'),
        ],
      )..parentID = kRootNode;
      await pumpNode(tester, card, codelesslyContext: codelesslyContext);

      await tester.tapAt(const Offset(100, 40));
      await tester.pumpAndSettle();
      expect(hoveredId.value.value, 'clicked');
      expect(find.byType(MouseRegion), findsWidgets);
    });

    testWidgets('nodes without cursor reactions get no extra region', (
      tester,
    ) async {
      final RectangleNode plain = RectangleNode(
        id: 'plain',
        name: 'Plain',
        basicBoxLocal: NodeBox(0, 0, 200, 80),
      )..parentID = kRootNode;
      await pumpNode(tester, plain);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is MouseRegion && widget.onEnter != null,
        ),
        findsNothing,
      );
    });
  });
}
