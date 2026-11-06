import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/functions/action_chain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Map pins: a stacked list's items, each a fixed slot bigger than the
/// clickable pin it holds. The slot's empty area lets taps through to the
/// pin of a neighbour beneath it, and to the map under the list.
void main() {
  Reaction tap(String value) => Reaction(
    trigger: TriggerModel(type: TriggerType.click),
    action: SetVariableAction(
      variable: VariableData(id: 'last', name: 'last'),
      newValue: value,
    ),
  );

  Future<Observable<VariableData>> pump(
    WidgetTester tester, {
    List<Reaction> slotReactions = const [],
    List<PaintModel> slotFills = const [],
  }) async {
    final FrameNode map = FrameNode(
      id: 'map',
      name: 'Map',
      basicBoxLocal: NodeBox(0, 0, 400, 200),
      children: const ['pins'],
      reactions: [tap('map')],
    )..parentID = kRootNode;
    final ListViewNode pins = ListViewNode(
      id: 'pins',
      name: 'Pins',
      basicBoxLocal: NodeBox(0, 0, 400, 200),
      properties: ListViewProperties(layout: ListLayout.stack),
      children: const ['slot'],
      variables: {'data': r'${pinData}'},
    )..parentID = 'map';
    // A 130 x 75 slot holding a 40 x 40 pin at its top centre.
    final RowColumnNode slot = RowColumnNode.fromJson({
      ...RowColumnNode(
        id: 'slot',
        name: 'Slot',
        basicBoxLocal: NodeBox(0, 0, 130, 75),
        children: const ['pin'],
        rowColumnType: RowColumnType.column,
        horizontalFit: SizeFit.fixed,
        verticalFit: SizeFit.fixed,
        crossAxisAlignment: CrossAxisAlignmentC.center,
        fills: slotFills,
        reactions: slotReactions,
      ).toJson(),
      'variables': {'x': r'${item.x}', 'y': r'${item.y}'},
    })..parentID = 'pins';
    final RowColumnNode pin = RowColumnNode.fromJson({
      ...RowColumnNode(
        id: 'pin',
        name: 'Pin',
        basicBoxLocal: NodeBox(45, 0, 40, 40),
        children: const ['dot'],
        rowColumnType: RowColumnType.column,
        horizontalFit: SizeFit.fixed,
        verticalFit: SizeFit.fixed,
        reactions: [tap(r'${item.id}')],
      ).toJson(),
    })..parentID = 'slot';
    final RectangleNode dot = RectangleNode(
      id: 'dot',
      name: 'Dot',
      basicBoxLocal: NodeBox(45, 0, 20, 20),
      fills: [PaintModel.solid(id: 'f', color: ColorRGB.fromHex('#3A6FC4'))],
    )..parentID = 'pin';
    final registry = NodeRegistry()
      ..setNodes({
        for (final BaseNode node in [map, pins, slot, pin, dot]) node.id: node,
      });
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    final Observable<VariableData> last = Observable(
      VariableData(id: 'last', name: 'last'),
    );
    final codelesslyContext = CodelesslyContext.empty()
      ..variables['last'] = last
      ..variables['pinData'] = Observable(
        VariableData(
          id: 'pinData',
          name: 'pinData',
          type: VariableType.list,
          // b is painted over a; its slot covers a's pin partly.
          value: [
            {'id': 'a', 'x': 0, 'y': 0},
            {'id': 'b', 'x': 60, 'y': 20},
          ],
        ),
      );
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: codelesslyContext,
        child: MaterialApp(
          home: Material(
            child: ActionChainHost(
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 400,
                  height: 200,
                  child: Builder(
                    builder: (context) => manager.buildWidgetFromNode(
                      map,
                      context,
                      settings: const WidgetBuildSettings(debugLabel: 'test'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return last;
  }

  Future<Object?> tapAt(
    WidgetTester tester,
    Observable<VariableData> last,
    Offset at,
  ) async {
    last.set(last.value.copyWith(value: null));
    await tester.tapAt(at);
    await tester.pumpAndSettle();
    return last.value.value;
  }

  testWidgets('an empty slot area lets taps through to what is beneath', (
    tester,
  ) async {
    final last = await pump(tester);
    // a's pin: 45..85 x 0..40; b's slot: 60..190 x 20..95, its pin
    // 105..145 x 20..60.
    expect(await tapAt(tester, last, const Offset(50, 10)), 'a');
    // Under b's empty slot area.
    expect(await tapAt(tester, last, const Offset(75, 30)), 'a');
    expect(await tapAt(tester, last, const Offset(125, 40)), 'b');
    // b's empty slot area over the map.
    expect(await tapAt(tester, last, const Offset(170, 85)), 'map');
    expect(await tapAt(tester, last, const Offset(300, 150)), 'map');
  });

  testWidgets('a slot with its own click takes taps on its whole box', (
    tester,
  ) async {
    final last = await pump(tester, slotReactions: [tap('slot')]);
    expect(await tapAt(tester, last, const Offset(125, 40)), 'b');
    expect(await tapAt(tester, last, const Offset(75, 30)), 'slot');
    expect(await tapAt(tester, last, const Offset(170, 85)), 'slot');
  });

  testWidgets('a filled slot takes taps on its whole box', (tester) async {
    final last = await pump(
      tester,
      slotFills: [
        PaintModel.solid(id: 'f', color: ColorRGB.fromHex('#FFFFFF')),
      ],
    );
    // b's filled slot covers a's pin.
    expect(await tapAt(tester, last, const Offset(75, 30)), isNot('a'));
    expect(await tapAt(tester, last, const Offset(170, 85)), isNot('map'));
  });
}
