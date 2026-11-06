import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/functions/action_chain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Lamplight's room cards: a power switch inside a card that opens the lamp
/// when tapped. Tapping the switch toggles it and must not also open the
/// card; tapping elsewhere on the card does. The innermost reactive node
/// wins, whatever wraps the card (a click, an ink well, pointer reactions,
/// a long press, a list item).
void main() {
  late CodelesslyContext codelesslyContext;

  VariableData variable(String name, VariableType type, Object value) =>
      VariableData(id: name, name: name, type: type, value: value);

  Reaction setTo(TriggerType trigger, String name, String value) => Reaction(
    trigger: TriggerModel(type: trigger),
    action: SetVariableAction(
      variable: VariableData(id: name, name: name),
      newValue: value,
    ),
  );

  Object? valueOf(String name) =>
      codelesslyContext.findVariableByName(name)!.value.getValue();

  Future<void> pump(WidgetTester tester, List<BaseNode> nodes) async {
    final registry = NodeRegistry()
      ..setNodes({for (final node in nodes) node.id: node});
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    codelesslyContext = CodelesslyContext.empty().copyWith(
      variables: {
        for (final v in [
          variable('opened', VariableType.text, ''),
          variable('toggled', VariableType.text, ''),
          variable('lamps', VariableType.list, [
            {'id': 'l1'},
          ]),
        ])
          v.id: Observable(v),
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: ChangeNotifierProvider<CodelesslyContext>.value(
            value: codelesslyContext,
            child: ActionChainHost(
              child: Align(
                alignment: Alignment.topLeft,
                child: Builder(
                  builder: (context) => manager.buildWidgetFromNode(
                    nodes.first,
                    context,
                    settings: const WidgetBuildSettings(
                      debugLabel: 'runtime',
                      withReactions: true,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  }

  SwitchNode power(String parent, {bool fillTrack = false}) => SwitchNode(
    id: 'power',
    name: 'Power',
    basicBoxLocal: fillTrack
        ? NodeBox(230, 19, 50, 30)
        : NodeBox(220, 14, 60, 40),
    horizontalFit: SizeFit.fixed,
    verticalFit: SizeFit.fixed,
    value: false,
    properties: SwitchProperties(fillTrack: fillTrack, uniformThumb: fillTrack),
    reactions: [setTo(TriggerType.changed, 'toggled', 'yes')],
  )..parentID = parent;

  FrameNode card({
    List<Reaction>? reactions,
    InkWellModel? inkWell,
    String parent = kRootNode,
  }) =>
      FrameNode(
          id: 'card',
          name: 'Room card',
          basicBoxLocal: NodeBox(0, 0, 300, 68),
          horizontalFit: SizeFit.fixed,
          verticalFit: SizeFit.fixed,
          fills: [PaintModel.solid(id: 'f', color: ColorRGBA.white)],
          reactions:
              reactions ?? [setTo(TriggerType.click, 'opened', 'yes')],
          children: ['power'],
        )
        ..inkWell = inkWell
        ..parentID = parent;

  Future<void> check(WidgetTester tester, {Offset? at}) async {
    // Each part of the switch's track takes the tap: its middle and near
    // its ends.
    if (at != null) {
      await tester.tapAt(at);
    } else {
      await tester.tap(find.byType(Switch));
    }
    await tester.pumpAndSettle();
    expect(valueOf('toggled'), 'yes', reason: 'the switch toggles');
    expect(valueOf('opened'), '', reason: 'the card does not open');
    await tester.tapAt(const Offset(60, 34));
    await tester.pumpAndSettle();
    expect(valueOf('opened'), 'yes', reason: 'the card opens elsewhere');
  }

  testWidgets('a switch in a tappable card takes its own tap', (tester) async {
    await pump(tester, [card(), power('card')]);
    await check(tester);
  });

  testWidgets('with semantics on, the switch and the card are tapped apart', (
    tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await pump(tester, [card(), power('card')]);
    await check(tester);
    semantics.dispose();
  });

  testWidgets('a switch in an ink-well card takes its own tap', (
    tester,
  ) async {
    await pump(tester, [card(inkWell: const InkWellModel()), power('card')]);
    await check(tester);
  });

  testWidgets('a switch in a card with pointer and long-press reactions', (
    tester,
  ) async {
    await pump(tester, [
      card(
        reactions: [
          setTo(TriggerType.click, 'opened', 'yes'),
          setTo(TriggerType.longPress, 'opened', 'held'),
          setTo(TriggerType.pointerUp, 'toggled', r'${toggled}'),
        ],
      ),
      power('card'),
    ]);
    await check(tester);
  });

  for (final Offset at in const [
    Offset(255, 34),
    Offset(234, 34),
    Offset(276, 34),
    Offset(255, 21),
  ]) {
    testWidgets('a track-filling switch in a tappable row takes a tap at $at', (
      tester,
    ) async {
      await pump(tester, [
        RowColumnNode(
          id: 'card',
          name: 'Lamp row',
          basicBoxLocal: NodeBox(0, 0, 300, 68),
          rowColumnType: RowColumnType.row,
          mainAxisAlignment: MainAxisAlignmentC.end,
          crossAxisAlignment: CrossAxisAlignmentC.center,
          padding: const EdgeInsetsModel.only(right: 20),
          reactions: [setTo(TriggerType.click, 'opened', 'yes')],
          children: ['power'],
        )..parentID = kRootNode,
        power('card', fillTrack: true),
      ]);
      await check(tester, at: at);
    });
  }

  testWidgets('a frame switch in a tappable card takes its own tap', (
    tester,
  ) async {
    await pump(tester, [
      card(),
      FrameNode(
        id: 'power',
        name: 'Enabled switch',
        basicBoxLocal: NodeBox(230, 19, 50, 30),
        horizontalFit: SizeFit.fixed,
        verticalFit: SizeFit.fixed,
        fills: [PaintModel.solid(id: 'f', color: ColorRGBA.black)],
        reactions: [setTo(TriggerType.click, 'toggled', 'yes')],
        children: [],
      )..parentID = 'card',
    ]);
    await check(tester, at: const Offset(255, 34));
  });

  testWidgets('a switch in a tappable list item takes its own tap', (
    tester,
  ) async {
    await pump(tester, [
      ListViewNode(
        id: 'list',
        name: 'Rooms',
        basicBoxLocal: NodeBox(0, 0, 300, 68),
        isScrollable: false,
        verticalFit: SizeFit.shrinkWrap,
        properties: ListViewProperties(),
        variables: {'data': r'${lamps}'},
        children: ['card'],
      )..parentID = kRootNode,
      card(parent: 'list'),
      power('card'),
    ]);
    await check(tester);
  });
}
