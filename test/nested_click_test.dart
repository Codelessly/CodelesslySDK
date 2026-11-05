import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/functions/action_chain.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Reaction _set(String name, String value) => Reaction(
  trigger: TriggerModel(type: TriggerType.click),
  action: SetVariableAction(
    variable: VariableData(id: name, name: name),
    newValue: value,
  ),
);

Future<(Observable<VariableData>, Observable<VariableData>)> _pump(
  WidgetTester tester, {
  bool tooltip = false,
  bool hover = false,
  bool cardTaps = true,
}) async {
  final card = Observable(VariableData(id: 'card', name: 'card', value: ''));
  final pencil = Observable(
    VariableData(id: 'pencil', name: 'pencil', value: ''),
  );
  final BaseNode button = RowColumnNode.fromJson({
    'id': 'button',
    'name': 'Edit server',
    'type': 'row',
    'rowColumnType': 'row',
    'basicBoxLocal': [100, 10, 30, 30],
    'children': <String>[],
    'parentID': 'card',
    'fills': [
      {'id': 'f', 'type': 'solid', 'color': '#000000', 'opacity': 0},
    ],
    'reactions': [_set('pencil', 'tapped').toJson()],
    if (tooltip) 'tooltip': 'Edit',
    if (hover)
      'interactionStates': {
        'hovered': {
          'button': {
            'fills': [
              {'type': 'solid', 'color': '#1A4C91'},
            ],
          },
        },
      },
  })..parentID = 'card';
  final BaseNode cardNode = RowColumnNode.fromJson({
    'id': 'card',
    'name': 'card',
    'type': 'column',
    'rowColumnType': 'column',
    'basicBoxLocal': [0, 0, 200, 60],
    'children': ['button'],
    'parentID': kRootNode,
    if (cardTaps) 'reactions': [_set('card', 'tapped').toJson()],
  })..parentID = kRootNode;
  final registry = NodeRegistry()
    ..setNodes({cardNode.id: cardNode, button.id: button});
  final manager = PassiveNodeTransformerManager(
    registry.getNodeByID,
    (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
  );
  final codelesslyContext = CodelesslyContext.empty()
    ..variables['card'] = card
    ..variables['pencil'] = pencil;
  await tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: codelesslyContext,
      child: MaterialApp(
        home: Material(
          child: ActionChainHost(
            child: Align(
              alignment: Alignment.topLeft,
              child: Builder(
                builder: (context) => manager.buildWidgetFromNode(
                  cardNode,
                  context,
                  settings: const WidgetBuildSettings(debugLabel: 'test'),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  return (card, pencil);
}

Future<void> _mouseClick(WidgetTester tester, Offset at) async {
  final TestGesture gesture = await tester.createGesture(
    kind: PointerDeviceKind.mouse,
  );
  await gesture.addPointer(location: Offset.zero);
  await gesture.moveTo(at);
  await tester.pump();
  await gesture.down(at);
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
  await gesture.removePointer();
}

/// A button inside a card that has a tap of its own (an edit button on a
/// server card) runs its own tap, by pointer and by its semantics.
void main() {
  testWidgets('control: a button in a card without its own tap', (
    tester,
  ) async {
    final (card, pencil) = await _pump(tester, cardTaps: false);
    await _mouseClick(tester, const Offset(100, 30));
    expect(pencil.value.value, 'tapped');
  });
  testWidgets('control: the card itself', (tester) async {
    final (card, pencil) = await _pump(tester);
    await _mouseClick(tester, const Offset(20, 55));
    expect(card.value.value, 'tapped');
  });
  for (final (tooltip, hover) in [
    (false, false),
    (true, false),
    (false, true),
    (true, true),
  ]) {
    testWidgets('tap on a button inside a tappable card runs the button '
        '(tooltip $tooltip, hover $hover)', (tester) async {
      final (card, pencil) = await _pump(
        tester,
        tooltip: tooltip,
        hover: hover,
      );
      await _mouseClick(tester, const Offset(100, 30));
      expect(pencil.value.value, 'tapped');
      expect(card.value.value, '');
    });
  }

  testWidgets('a button inside a tappable card keeps its own semantics tap', (
    tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    final (card, pencil) = await _pump(tester);
    final SemanticsNode button = tester.getSemantics(
      find.bySemanticsLabel('Edit server'),
    );
    expect(button.label, 'Edit server');
    tester.binding.pipelineOwner.semanticsOwner!.performAction(
      button.id,
      SemanticsAction.tap,
    );
    await tester.pumpAndSettle();
    expect(pencil.value.value, 'tapped');
    expect(card.value.value, '');
    // The card is still a button of its own.
    final SemanticsNode cardButton = tester.getSemantics(
      find.bySemanticsLabel('card'),
    );
    expect(cardButton.id, isNot(button.id));
    tester.binding.pipelineOwner.semanticsOwner!.performAction(
      cardButton.id,
      SemanticsAction.tap,
    );
    await tester.pumpAndSettle();
    expect(card.value.value, 'tapped');
    handle.dispose();
  });
}
