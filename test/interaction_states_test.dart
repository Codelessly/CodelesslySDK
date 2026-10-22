import 'dart:ui';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

const Color white = Color(0xFFFFFFFF);
const Color red = Color(0xFFFF0000);
const Color blue = Color(0xFF0000FF);
const Color grey = Color(0xFF808080);
const Color green = Color(0xFF00FF00);

Map<String, dynamic> fillPatch(String hex) => {
  'fills': [PaintModel.solid(id: 'f', color: ColorRGB.fromHex(hex)).toJson()],
};

/// A 200x100 card holding a 20x20 dot, with a tap action.
({FrameNode card, RectangleNode dot}) cardWithDot() {
  final RectangleNode dot = RectangleNode(
    id: 'dot',
    name: 'Dot',
    basicBoxLocal: NodeBox(0, 0, 20, 20),
    fills: [PaintModel.solid(id: 'd', color: ColorRGB.fromHex('#FFFFFF'))],
  )..parentID = 'card';
  final FrameNode card = FrameNode(
    id: 'card',
    name: 'Card',
    basicBoxLocal: NodeBox(0, 0, 200, 100),
    children: ['dot'],
    fills: [PaintModel.solid(id: 'c', color: ColorRGB.fromHex('#FFFFFF'))],
    reactions: [
      Reaction(
        action: CallFunctionAction(name: 'tap'),
        trigger: TriggerModel(type: TriggerType.click),
      ),
    ],
  )..parentID = kRootNode;
  return (card: card, dot: dot);
}

class Harness {
  final CodelesslyContext codelesslyContext;
  final List<String> taps = [];

  Harness() : codelesslyContext = CodelesslyContext.empty();

  Future<void> pump(
    WidgetTester tester,
    List<BaseNode> nodes, {
    BaseNode? root,
    WidgetBuildSettings settings = const WidgetBuildSettings(
      debugLabel: 'test',
    ),
  }) async {
    final registry = NodeRegistry()..setNodes({for (final n in nodes) n.id: n});
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    codelesslyContext.functions = {
      'tap': (context, reference, params) => taps.add('tap'),
    };
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: codelesslyContext,
        child: MaterialApp(
          home: Material(
            child: Align(
              alignment: Alignment.topLeft,
              child: Builder(
                builder: (context) => manager.buildWidgetFromNode(
                  root ?? nodes.first,
                  context,
                  settings: settings,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The colour of the box [width] wide, from its decoration.
Color? colorOf(WidgetTester tester, double width) {
  for (final Element element
      in find
          .byWidgetPredicate(
            (w) =>
                (w is DecoratedBox && w.decoration is BoxDecoration) ||
                (w is Ink && w.decoration is BoxDecoration) ||
                (w is Container && w.decoration is BoxDecoration),
          )
          .evaluate()) {
    final Size? size = element.size;
    if (size == null || size.width != width) continue;
    final Widget w = element.widget;
    final Decoration? decoration = switch (w) {
      final DecoratedBox box => box.decoration,
      final Ink ink => ink.decoration,
      final Container container => container.decoration,
      _ => null,
    };
    final Color? color = (decoration as BoxDecoration?)?.color;
    if (color != null) return color;
  }
  return null;
}

void main() {
  testWidgets('hover and pressed apply their overrides, pressed wins', (
    tester,
  ) async {
    final (:card, :dot) = cardWithDot();
    card.interactionStates = {
      InteractionState.hovered: {'card': fillPatch('#FF0000')},
      InteractionState.pressed: {
        'card': fillPatch('#0000FF'),
        'dot': fillPatch('#00FF00'),
      },
    };
    final harness = Harness();
    await harness.pump(tester, [card, dot]);

    expect(colorOf(tester, 200), white);
    expect(colorOf(tester, 20), white);

    final TestGesture mouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    await mouse.addPointer(location: const Offset(500, 500));
    await mouse.moveTo(const Offset(150, 50));
    await tester.pump();
    expect(colorOf(tester, 200), red);
    expect(colorOf(tester, 20), white);

    await mouse.down(const Offset(150, 50));
    await tester.pump();
    expect(colorOf(tester, 200), blue);
    expect(colorOf(tester, 20), green);

    await mouse.up();
    await tester.pumpAndSettle();
    expect(colorOf(tester, 200), red);
    expect(harness.taps, ['tap']);

    await mouse.moveTo(const Offset(500, 500));
    await tester.pump();
    expect(colorOf(tester, 200), white);
    // The node itself never changes.
    expect(card.fills.first.color, ColorRGB.fromHex('#FFFFFF'));
  });

  testWidgets('selected and disabled follow bound variables; disabled runs '
      'no actions', (tester) async {
    final (:card, :dot) = cardWithDot();
    card.interactionStates = {
      InteractionState.selected: {'card': fillPatch('#FF0000')},
      InteractionState.disabled: {'card': fillPatch('#808080')},
    };
    card.variables = {'selected': 'isSelected', 'disabled': 'isDisabled'};
    final harness = Harness();
    final Observable<VariableData> selected = Observable(
      VariableData(
        id: 's',
        name: 'isSelected',
        type: VariableType.boolean,
        value: false,
      ),
    );
    final Observable<VariableData> disabled = Observable(
      VariableData(
        id: 'd',
        name: 'isDisabled',
        type: VariableType.boolean,
        value: false,
      ),
    );
    harness.codelesslyContext.variables
      ..['s'] = selected
      ..['d'] = disabled;
    await harness.pump(tester, [card, dot]);
    expect(colorOf(tester, 200), white);

    selected.set(selected.value.copyWith(value: true));
    await tester.pump();
    expect(colorOf(tester, 200), red);

    // Disabled comes after selected, so it wins.
    disabled.set(disabled.value.copyWith(value: true));
    await tester.pump();
    expect(colorOf(tester, 200), grey);

    await tester.tapAt(const Offset(150, 50));
    await tester.pumpAndSettle();
    expect(harness.taps, isEmpty);

    disabled.set(disabled.value.copyWith(value: false));
    await tester.pump();
    await tester.tapAt(const Offset(150, 50));
    await tester.pumpAndSettle();
    expect(harness.taps, ['tap']);
  });

  testWidgets('focused follows focus of an input inside the node', (
    tester,
  ) async {
    final (:card, dot: _) = cardWithDot();
    card.interactionStates = {
      InteractionState.focused: {'card': fillPatch('#FF0000')},
    };
    Map<String, dynamic>? patch;
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: CodelesslyContext.empty(),
        child: MaterialApp(
          home: Material(
            child: InteractionStatesBox(
              node: card,
              builder: (context) {
                patch = PropertyOverrideScope.patchFor(context, 'card');
                return const TextField();
              },
            ),
          ),
        ),
      ),
    );
    expect(patch, isNull);

    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(patch, fillPatch('#FF0000'));

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    expect(patch, isNull);
  });

  testWidgets('the design canvas shows the node without its states', (
    tester,
  ) async {
    final (:card, :dot) = cardWithDot();
    card.interactionStates = {
      InteractionState.hovered: {'card': fillPatch('#FF0000')},
    };
    await Harness().pump(
      tester,
      [card, dot],
      settings: const WidgetBuildSettings(debugLabel: 'test', isPreview: true),
    );
    expect(find.byType(InteractionStatesBox), findsNothing);
  });

  group('property-override variants', () {
    VarianceNode states(String current) => VarianceNode(
      id: 'states',
      name: 'States',
      basicBoxLocal: NodeBox(0, 0, 200, 100),
      currentVariantId: current,
      variants: [
        Variant(id: 'default', name: 'Default', children: ['card']),
        Variant(
          id: 'wide',
          name: 'Wide',
          children: [],
          overrides: {
            'card': fillPatch('#FF0000'),
            'dot': fillPatch('#0000FF'),
          },
        ),
      ],
    )..parentID = kRootNode;

    for (final Size screen in const [
      Size(390, 844),
      Size(834, 1194),
      Size(1440, 900),
    ]) {
      testWidgets('show the default children with the overrides at '
          '${screen.width.toInt()}', (tester) async {
        tester.view.physicalSize = screen;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final (:card, :dot) = cardWithDot();
        card.parentID = 'states';
        final VarianceNode node = states('wide');
        await Harness().pump(tester, [node, card, dot]);
        expect(tester.takeException(), isNull);
        expect(colorOf(tester, 200), red);
        expect(colorOf(tester, 20), blue);
        // The nodes themselves are unchanged.
        expect(card.fills.first.color, ColorRGB.fromHex('#FFFFFF'));

        node.currentVariantId = 'default';
        await Harness().pump(tester, [node, card, dot]);
        expect(colorOf(tester, 200), white);
        expect(colorOf(tester, 20), white);
      });
    }

    testWidgets('a bound variable picks the override variant by id', (
      tester,
    ) async {
      final (:card, :dot) = cardWithDot();
      card.parentID = 'states';
      final VarianceNode node = states('default')
        ..variables = {'currentVariantId': 'mode'};
      final harness = Harness();
      final Observable<VariableData> mode = Observable(
        VariableData(
          id: 'm',
          name: 'mode',
          type: VariableType.text,
          value: 'default',
        ),
      );
      harness.codelesslyContext.variables['m'] = mode;
      await harness.pump(tester, [node, card, dot]);
      expect(colorOf(tester, 200), white);

      mode.set(mode.value.copyWith(value: 'wide'));
      await tester.pump();
      expect(colorOf(tester, 200), red);
    });

    testWidgets('an interaction state inside an override variant layers on '
        'top of it', (tester) async {
      final (:card, :dot) = cardWithDot();
      card.parentID = 'states';
      card.interactionStates = {
        InteractionState.hovered: {'dot': fillPatch('#00FF00')},
      };
      await Harness().pump(tester, [states('wide'), card, dot]);
      expect(colorOf(tester, 20), blue);

      final TestGesture mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await mouse.addPointer(location: const Offset(150, 50));
      await mouse.moveTo(const Offset(151, 50));
      await tester.pump();
      expect(colorOf(tester, 20), green);
      expect(colorOf(tester, 200), red);
    });
  });
}
