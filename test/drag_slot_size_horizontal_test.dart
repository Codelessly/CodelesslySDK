import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/functions/action_chain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'feedback_actions_test.dart' show brandRegular, text;

/// A bench of five shirts in a horizontal list (Lineup): the slot is a thin
/// gold bar at its own size (slotSize: node), as tall as the cards.
void main() {
  final VariableData bench = VariableData(
    id: 'bench',
    name: 'bench',
    type: VariableType.list,
    value: ['One', 'Two', 'Three', 'Four', 'Five'],
  );

  Future<void> pump(WidgetTester tester, {bool hiddenSlot = false}) async {
    tester.view.physicalSize = const Size(500, 300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final RowColumnNode slot = RowColumnNode(
      id: 'gap',
      name: 'Bench gap',
      basicBoxLocal: NodeBox(0, 0, 4, 80),
      horizontalFit: SizeFit.fixed,
      verticalFit: SizeFit.fixed,
      rowColumnType: RowColumnType.row,
      mainAxisAlignment: MainAxisAlignmentC.start,
      crossAxisAlignment: CrossAxisAlignmentC.center,
      children: [],
    )
      ..parentID = kRootNode
      ..variables.addAll({if (hiddenSlot) 'visible': r'${= false}'});
    final FrameNode card = FrameNode(
      id: 'card',
      name: 'Card',
      basicBoxLocal: NodeBox(0, 0, 60, 80),
      horizontalFit: SizeFit.fixed,
      verticalFit: SizeFit.fixed,
      children: ['label'],
    )
      ..parentID = 'bench'
      ..draggable = DraggableModel(
        group: 'player',
        data: r'${item}',
        start: DragStart.press,
      );
    final TextNode label = text('label', 'card', r'${item}', brandRegular);
    final ListViewNode list = ListViewNode(
      id: 'bench',
      name: 'Bench',
      basicBoxLocal: NodeBox(0, 0, 400, 80),
      scrollDirection: AxisC.horizontal,
      properties: ListViewProperties(),
      children: [card.id],
      variables: {'data': r'${bench}'},
    )
      ..parentID = kRootNode
      ..dropTarget = const DropTargetModel(
        accepts: ['player'],
        key: 'bench',
        listNodeId: 'bench',
        slot: DropSlot.node,
        slotNodeId: 'gap',
        slotSize: DropSlotSize.node,
      );
    final NodeRegistry registry = NodeRegistry()
      ..setNodes({slot.id: slot, card.id: card, label.id: label, list.id: list});
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    final CodelesslyContext c = CodelesslyContext.empty()
      ..variables['bench'] = Observable(bench);
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: c,
        child: MaterialApp(
          home: ActionChainHost(
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 400,
                height: 80,
                child: Builder(
                  builder: (context) => manager.buildWidgetFromNode(
                    list,
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
    await tester.pump();
  }

  for (final bool hidden in [false, true]) {
    testWidgets('a thin slot opens between shirts and the others stay '
        '(slot node ${hidden ? 'hidden' : 'shown'})', (tester) async {
      await pump(tester, hiddenSlot: hidden);
      final Offset start = tester.getCenter(find.text('One'));
      final Offset to = tester.getRect(find.text('Four')).centerLeft + const Offset(4, 0);
      final TestGesture gesture = await tester.startGesture(start);
      await tester.pump();
      for (int i = 1; i <= 12; i++) {
        await gesture.moveTo(Offset.lerp(start, to, i / 12)!);
        await tester.pump();
      }
      final Finder slot = find.byKey(const ValueKey('codelessly-drop-slot'));
      expect(slot, findsOneWidget);
      final Rect s = tester.getRect(slot);
      expect(s.width, 4);
      for (final String t in ['Two', 'Three', 'Four', 'Five']) {
        final Rect r = tester.getRect(find.text(t).first);
        expect(r.left, lessThan(400), reason: '$t stays in the bench');
      }
      // Right after Three (the dragged One leaves a ghost in its place).
      expect(s.left, closeTo(180, 0.5));
      await gesture.up();
      await tester.pumpAndSettle();
    });
  }
}
