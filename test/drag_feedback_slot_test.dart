import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/functions/action_chain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'feedback_actions_test.dart' show brandRegular, text;

/// Two lists of songs (the Mixtape sides): a card is held by its centre
/// (feedbackAnchor), the slot is the slot node at its own size (slotSize),
/// and list b, which is full, opens no slot (slotWhenRefused: false).
void main() {
  final VariableData cards = VariableData(
    id: 'cards',
    name: 'cards',
    type: VariableType.list,
    value: [
      {'id': 'c1', 'title': 'One', 'lane': 'a'},
      {'id': 'c2', 'title': 'Two', 'lane': 'a'},
      {'id': 'c4', 'title': 'Four', 'lane': 'b'},
    ],
  );

  Future<CodelesslyContext> pump(
    WidgetTester tester, {
    bool label = false,
  }) async {
    tester.view.physicalSize = const Size(400, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final Map<String, BaseNode> nodes = {};
    final List<ListViewNode> lists = [];
    final FrameNode slot = FrameNode(
      id: 'slotLine',
      name: 'Insert line',
      basicBoxLocal: NodeBox(0, 0, 160, 6),
      children: [],
    )..parentID = kRootNode;
    nodes[slot.id] = slot;
    final FrameNode labelNode = FrameNode(
      id: 'dragLabel',
      name: 'Drag label',
      basicBoxLocal: NodeBox(0, 0, 100, 30),
      children: [],
    )..parentID = kRootNode;
    nodes[labelNode.id] = labelNode;
    for (final lane in ['a', 'b']) {
      final TextNode card =
          text('card_$lane', 'list_$lane', r'${item.title}', brandRegular)
            ..draggable = DraggableModel(
              group: 'card',
              data: r'${item.id}',
              start: DragStart.press,
              feedbackAnchor: FeedbackAnchor.center,
              feedbackNodeId: label ? 'dragLabel' : '',
            );
      final ListViewNode list =
          ListViewNode(
              id: 'list_$lane',
              name: 'Lane $lane',
              basicBoxLocal: NodeBox(0, 0, 160, 400),
              properties: ListViewProperties(),
              children: [card.id],
              variables: {
                'data': "\${= filter(cards, c => c.lane == '$lane')}",
              },
            )
            ..parentID = kRootNode
            ..dropTarget = DropTargetModel(
              accepts: const ['card'],
              key: lane,
              listNodeId: 'list_$lane',
              slot: DropSlot.node,
              slotNodeId: 'slotLine',
              slotSize: DropSlotSize.node,
              slotWhenRefused: false,
              acceptIf: lane == 'b' ? r'${= false}' : '',
            );
      nodes[list.id] = list;
      nodes[card.id] = card;
      lists.add(list);
    }
    final NodeRegistry registry = NodeRegistry()..setNodes(nodes);
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    final CodelesslyContext c = CodelesslyContext.empty()
      ..variables['cards'] = Observable(cards);
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: c,
        child: MaterialApp(
          home: ActionChainHost(
            child: Align(
              alignment: Alignment.topLeft,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final list in lists)
                    SizedBox(
                      width: 160,
                      height: 400,
                      child: Builder(
                        builder: (context) => manager.buildWidgetFromNode(
                          list,
                          context,
                          settings: const WidgetBuildSettings(
                            debugLabel: 'test',
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return c;
  }

  Future<TestGesture> dragTo(
    WidgetTester tester,
    String title,
    Offset to,
  ) async {
    final Offset start = tester.getCenter(find.text(title));
    final TestGesture gesture = await tester.startGesture(start);
    await tester.pump();
    // Out past the touch slop first, then to the target.
    const Offset away = Offset(80, 300);
    for (int i = 1; i <= 10; i++) {
      await gesture.moveTo(Offset.lerp(start, away, i / 10)!);
      await tester.pump();
    }
    for (int i = 1; i <= 10; i++) {
      await gesture.moveTo(Offset.lerp(away, to, i / 10)!);
      await tester.pump();
    }
    return gesture;
  }

  Finder feedbackText(String title) => find.descendant(
    of: find.byType(IgnorePointer),
    matching: find.text(title, findRichText: true),
  );

  testWidgets('a centre-anchored copy is held by its middle', (tester) async {
    await pump(tester);
    // Grab "Two" near its left edge, then move: the copy centres on the
    // pointer instead of keeping the grab offset.
    final Rect two = tester.getRect(find.text('Two'));
    final Offset grab = two.centerLeft + const Offset(4, 0);
    final TestGesture gesture = await tester.startGesture(grab);
    await tester.pump();
    const Offset to = Offset(80, 200);
    for (int i = 1; i <= 10; i++) {
      await gesture.moveTo(Offset.lerp(grab, to, i / 10)!);
      await tester.pump();
    }
    final Finder copy = find.ancestor(
      of: feedbackText('Two').last,
      matching: find.byType(FractionalTranslation),
    );
    expect(copy, findsOneWidget);
    final Rect r = tester.getRect(
      find.descendant(of: copy, matching: find.byType(Opacity)).first,
    );
    expect((r.center - to).distance, lessThan(1.5));
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('the slot is the slot node at its own height', (tester) async {
    final c = await pump(tester);
    final Offset two = tester.getRect(find.text('Two')).topCenter;
    final TestGesture gesture = await dragTo(
      tester,
      'One',
      two + const Offset(0, 4),
    );
    expect(c.dragAndDrop.value['over'], 'a');
    final Finder slot = find.byKey(const ValueKey('codelessly-drop-slot'));
    expect(slot, findsOneWidget);
    expect(tester.getSize(slot).height, 6);
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('a refusing target opens no slot', (tester) async {
    final c = await pump(tester);
    final Offset four = tester.getRect(find.text('Four')).topCenter;
    final TestGesture gesture = await dragTo(
      tester,
      'One',
      four + const Offset(0, 4),
    );
    expect(c.dragAndDrop.value['over'], 'b');
    expect(c.dragAndDrop.value['accepted'], isFalse);
    final Finder slot = find.byKey(const ValueKey('codelessly-drop-slot'));
    if (slot.evaluate().isNotEmpty) {
      expect(tester.getSize(slot).height, 0);
    }
    await gesture.up();
    await tester.pumpAndSettle();
  });

  test('the new fields round-trip through JSON and default off', () {
    const d = DraggableModel(feedbackAnchor: FeedbackAnchor.center);
    expect(
      DraggableModel.fromJson(d.toJson()).feedbackAnchor,
      FeedbackAnchor.center,
    );
    expect(
      const DraggableModel().toJson().containsKey('feedbackAnchor'),
      isFalse,
    );
    const t = DropTargetModel(
      slotSize: DropSlotSize.node,
      slotWhenRefused: false,
    );
    final back = DropTargetModel.fromJson(t.toJson());
    expect(back.slotSize, DropSlotSize.node);
    expect(back.slotWhenRefused, isFalse);
    expect(const DropTargetModel().toJson().containsKey('slotSize'), isFalse);
  });

  testWidgets('a slot after the last item adds no empty item', (tester) async {
    await pump(tester);
    // Below "Two", the last card of list a: the slot goes at the end.
    final Offset below = tester.getRect(find.text('Two')).bottomCenter;
    final TestGesture gesture = await dragTo(
      tester,
      'Four',
      below + const Offset(0, 30),
    );
    final Finder slot = find.byKey(const ValueKey('codelessly-drop-slot'));
    expect(slot, findsOneWidget);
    // One, Two and the dragged Four's ghost: no extra card built for the slot.
    expect(
      find
          .byType(Flex)
          .evaluate()
          .where(
            (e) =>
                (e.widget as Flex).children.length == 2 &&
                (e.widget as Flex).children.first is KeyedSubtree,
          ),
      isEmpty,
    );
    expect(find.text('One'), findsWidgets);
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('a feedback node keeps its own fixed size', (tester) async {
    await pump(tester, label: true);
    final TestGesture gesture = await dragTo(
      tester,
      'Two',
      const Offset(80, 200),
    );
    // The copy in the overlay is the centring FractionalTranslation.
    final Finder copy = find.byWidgetPredicate(
      (w) =>
          w is FractionalTranslation &&
          w.translation == const Offset(-0.5, -0.5),
    );
    expect(copy, findsOneWidget);
    final Iterable<Size> sizes = find
        .descendant(of: copy, matching: find.byType(SizedBox))
        .evaluate()
        .map((e) => (e.renderObject! as RenderBox).size);
    expect(sizes, contains(const Size(100, 30)));
    await gesture.up();
    await tester.pumpAndSettle();
  });
}
