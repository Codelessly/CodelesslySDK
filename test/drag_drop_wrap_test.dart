import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/functions/action_chain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'feedback_actions_test.dart' show brandRegular;

/// Drops into a wrapping list (a pedalboard, a grid of cards) land in
/// reading order: line by line, then along the line.
void main() {
  group('dropLandsBefore', () {
    const Rect item = Rect.fromLTWH(100, 100, 50, 50);

    test('a plain list compares one axis', () {
      expect(
        dropLandsBefore(const Offset(500, 110), item, axis: Axis.vertical),
        isTrue,
      );
      expect(
        dropLandsBefore(const Offset(0, 140), item, axis: Axis.vertical),
        isFalse,
      );
      expect(
        dropLandsBefore(const Offset(110, 500), item, axis: Axis.horizontal),
        isTrue,
      );
    });

    test('a wrapping row list reads left to right, top to bottom', () {
      bool before(double x, double y) => dropLandsBefore(
        Offset(x, y),
        item,
        axis: Axis.horizontal,
        wraps: true,
      );
      expect(before(400, 90), isTrue); // a line above, however far right
      expect(before(110, 140), isTrue); // its line, left of its centre
      expect(before(140, 120), isFalse); // its line, right of its centre
      expect(before(0, 160), isFalse); // a line below, however far left
    });

    test('a wrapping column list reads top to bottom, left to right', () {
      bool before(double x, double y) =>
          dropLandsBefore(Offset(x, y), item, axis: Axis.vertical, wraps: true);
      expect(before(90, 400), isTrue);
      expect(before(140, 110), isTrue);
      expect(before(120, 140), isFalse);
      expect(before(160, 0), isFalse);
    });
  });

  testWidgets(
    'a drag onto the second line of a wrapping list lands before the item under the pointer',
    (tester) async {
      final VariableData cards = VariableData(
        id: 'cards',
        name: 'cards',
        type: VariableType.list,
        value: [
          for (final id in ['a', 'b', 'c', 'd', 'e', 'f'])
            {'id': id, 'title': id.toUpperCase()},
        ],
      );
      final TextNode card =
          TextNode(
              id: 'card',
              name: 'card',
              basicBoxLocal: NodeBox(0, 0, 50, 50),
              data: r'${item.title}',
              textMixedProps: [
                StartEndProp(
                  start: 0,
                  end: 13,
                  fontSize: 16,
                  fontName: brandRegular,
                ),
              ],
            )
            ..parentID = 'board'
            ..draggable = const DraggableModel(
              group: 'card',
              data: r'${item.id}',
              start: DragStart.press,
              whileDragging: DragSourceStyle.hidden,
            );
      final ListViewNode board =
          ListViewNode(
              id: 'board',
              name: 'Board',
              basicBoxLocal: NodeBox(0, 0, 160, 120),
              scrollDirection: AxisC.horizontal,
              properties: ListViewProperties(wrap: true),
              children: [card.id],
              variables: {'data': r'${cards}'},
              reactions: [
                Reaction(
                  name: 'drop',
                  trigger: TriggerModel(type: TriggerType.drop),
                  action: SetVariableAction(
                    variable: cards,
                    newValue:
                        r'${= moveItems(cards, result.ids, result.beforeId)}',
                  ),
                ),
              ],
            )
            ..parentID = kRootNode
            ..dropTarget = const DropTargetModel(
              accepts: ['card'],
              listNodeId: 'board',
            );
      final registry = NodeRegistry()
        ..setNodes({board.id: board, card.id: card});
      tester.view.physicalSize = const Size(400, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
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
                child: SizedBox(
                  width: 160,
                  height: 120,
                  child: Builder(
                    builder: (context) => manager.buildWidgetFromNode(
                      board,
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
      List<String> order() => [
        for (final Map m
            in c.variables['cards']!.value.value
                .typedValue<List>()!
                .cast<Map>())
          m['id'] as String,
      ];
      // Three a line: A B C over D E F. D sits right below A.
      final Rect d = tester.getRect(find.text('D'));
      expect(
        d.top,
        greaterThanOrEqualTo(tester.getRect(find.text('A')).bottom),
      );
      // Pick up B and hold it just left of D's centre, on D's line.
      final Offset start = tester.getCenter(find.text('B'));
      final Offset to = Offset(d.left + 5, d.center.dy);
      final TestGesture gesture = await tester.startGesture(start);
      await tester.pump();
      for (int i = 1; i <= 10; i++) {
        await gesture.moveTo(Offset.lerp(start, to, i / 10)!);
        await tester.pump();
      }
      expect(c.dragAndDrop.value['beforeId'], 'd');
      // B collapses (hidden while dragged) and the slot is a cell of its own
      // in reading order: A C [slot] on the first line, D E F on the next.
      final Rect slot = tester.getRect(
        find.byKey(const ValueKey('codelessly-drop-slot')),
      );
      expect(slot.size, const Size(50, 50));
      expect(slot.topLeft, const Offset(100, 0));
      expect(tester.getRect(find.text('C')).topLeft, const Offset(50, 0));
      expect(tester.getRect(find.text('D')).topLeft, d.topLeft);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(order(), ['a', 'c', 'b', 'd', 'e', 'f']);
    },
  );

  test('a drag carries the size of what follows the pointer', () {
    expect(draggedSize(const Size(268, 72)), const Size(268, 72));
    expect(
      draggedSize(const Size(268, 72), feedbackSize: const Size(150, 230)),
      const Size(150, 230),
    );
    expect(
      draggedSize(const Size(63, 97), feedbackScale: 2),
      const Size(126, 194),
    );
  });

  testWidgets(
    'a hidden feedback node shows while dragged, its own hidden parts stay hidden, and the slot takes its size',
    (tester) async {
      final VariableData cards = VariableData(
        id: 'cards',
        name: 'cards',
        type: VariableType.list,
        value: [
          {'id': 'a', 'title': 'A'},
        ],
      );
      TextNode label(
        String id,
        String parent,
        String chars, {
        bool hidden = false,
      }) => TextNode(
        id: id,
        name: id,
        basicBoxLocal: NodeBox(0, 0, 60, 20),
        data: chars,
        textMixedProps: [
          StartEndProp(
            start: 0,
            end: chars.length,
            fontSize: 12,
            fontName: brandRegular,
          ),
        ],
        variables: hidden ? {'visible': r'${= false}'} : {},
      )..parentID = parent;
      // A wide row in the source list; its feedback is a hidden 60x80 card
      // whose "front" shows and whose "back" stays hidden.
      final FrameNode row =
          FrameNode(
              id: 'row',
              name: 'row',
              basicBoxLocal: NodeBox(0, 0, 200, 30),
              children: ['rowLabel', 'feedback'],
            )
            ..parentID = 'source'
            ..draggable = const DraggableModel(
              group: 'card',
              data: 'z',
              start: DragStart.press,
              feedbackNodeId: 'feedback',
            );
      final FrameNode feedback =
          FrameNode(
              id: 'feedback',
              name: 'feedback',
              basicBoxLocal: NodeBox(0, 0, 60, 80),
              children: ['front', 'back'],
            )
            ..parentID = 'row'
            ..variables['visible'] = r'${= false}';
      final ListViewNode source = ListViewNode(
        id: 'source',
        name: 'source',
        basicBoxLocal: NodeBox(0, 0, 200, 30),
        properties: ListViewProperties(itemCount: 1),
        children: ['row'],
      )..parentID = 'root';
      final ListViewNode board =
          ListViewNode(
              id: 'board',
              name: 'board',
              basicBoxLocal: NodeBox(0, 200, 300, 100),
              scrollDirection: AxisC.horizontal,
              properties: ListViewProperties(wrap: true),
              children: ['card'],
              variables: {'data': r'${cards}'},
            )
            ..parentID = 'root'
            ..dropTarget = const DropTargetModel(
              accepts: ['card'],
              listNodeId: 'board',
            );
      final TextNode card = label('card', 'board', r'${item.title}');
      final FrameNode root = FrameNode(
        id: 'root',
        name: 'root',
        basicBoxLocal: NodeBox(0, 0, 400, 400),
        children: ['source', 'board'],
      )..parentID = kRootNode;
      final registry = NodeRegistry()
        ..setNodes({
          for (final n in <BaseNode>[
            root,
            source,
            row,
            label('rowLabel', 'row', 'Row'),
            feedback,
            label('front', 'feedback', 'Front'),
            label('back', 'feedback', 'Back', hidden: true),
            board,
            card,
          ])
            n.id: n,
        });
      tester.view.physicalSize = const Size(400, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
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
                child: SizedBox(
                  width: 400,
                  height: 400,
                  child: Builder(
                    builder: (context) => manager.buildWidgetFromNode(
                      root,
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
      expect(find.text('Front', findRichText: true), findsNothing);
      final Offset start = tester.getCenter(
        find.text('Row', findRichText: true),
      );
      final TestGesture gesture = await tester.startGesture(start);
      await tester.pump();
      final Offset to = tester.getCenter(find.text('A', findRichText: true));
      for (int i = 1; i <= 10; i++) {
        await gesture.moveTo(Offset.lerp(start, to, i / 10)!);
        await tester.pump();
      }
      expect(find.text('Front', findRichText: true), findsOneWidget);
      expect(find.text('Back', findRichText: true), findsNothing);
      expect(c.dragAndDrop.value['width'], 60);
      expect(c.dragAndDrop.value['height'], 80);
      expect(
        tester.getSize(find.byKey(const ValueKey('codelessly-drop-slot'))),
        const Size(60, 80),
      );
      await gesture.up();
      await tester.pumpAndSettle();
    },
  );
}
