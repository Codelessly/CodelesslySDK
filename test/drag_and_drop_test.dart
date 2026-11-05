import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/functions/action_chain.dart';
import 'package:flutter/gestures.dart' show kSecondaryButton;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'feedback_actions_test.dart' show brandRegular, text;

/// A two-column board: each column is a list of `cards` filtered by lane,
/// a drop target that owns its list; each card is draggable. Dropping runs
/// `moveItems` on `cards`. Column b accepts at most 2 cards (a WIP limit).
void main() {
  final VariableData cards = VariableData(
    id: 'cards',
    name: 'cards',
    type: VariableType.list,
    value: [
      {'id': 'c1', 'title': 'One', 'lane': 'a'},
      {'id': 'c2', 'title': 'Two', 'lane': 'a'},
      {'id': 'c3', 'title': 'Three', 'lane': 'a'},
      {'id': 'c4', 'title': 'Four', 'lane': 'b'},
    ],
  );

  Reaction dropMoves() => Reaction(
    name: 'drop',
    trigger: TriggerModel(type: TriggerType.drop),
    action: SetVariableAction(
      variable: cards,
      newValue: r"${= moveItems(cards, result.ids, result.beforeId, object('lane', result.key))}",
    ),
  );

  ({NodeRegistry registry, List<ListViewNode> lists}) build() {
    final Map<String, BaseNode> nodes = {};
    final List<ListViewNode> lists = [];
    for (final lane in ['a', 'b']) {
      final TextNode card =
          text('card_$lane', 'list_$lane', r'${item.title}', brandRegular)
            ..draggable = const DraggableModel(
              group: 'card',
              data: r'${item.id}',
              start: DragStart.press,
              whileDragging: DragSourceStyle.hidden,
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
              reactions: [dropMoves()],
            )
            ..parentID = kRootNode
            ..dropTarget = DropTargetModel(
              accepts: const ['card'],
              key: lane,
              listNodeId: 'list_$lane',
              acceptIf: lane == 'b'
                  ? r"${= count(filter(cards, c => c.lane == 'b' && !contains(drag.ids, c.id))) + drag.count <= 2}"
                  : '',
            );
      nodes[list.id] = list;
      nodes[card.id] = card;
      lists.add(list);
    }
    return (registry: NodeRegistry()..setNodes(nodes), lists: lists);
  }

  Future<CodelesslyContext> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final b = build();
    final manager = PassiveNodeTransformerManager(
      b.registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    final CodelesslyContext codelesslyContext = CodelesslyContext.empty()
      ..variables['cards'] = Observable(cards);
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: codelesslyContext,
        child: MaterialApp(
          home: ActionChainHost(
            child: Align(
              alignment: Alignment.topLeft,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final list in b.lists)
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
    return codelesslyContext;
  }

  List<String> lane(CodelesslyContext c, String lane) => [
    for (final Map card
        in c.variables['cards']!.value.value.typedValue<List>()!.cast<Map>())
      if (card['lane'] == lane) card['id'] as String,
  ];

  testWidgets(
    'a card dragged into the other column lands before the card under the pointer',
    (tester) async {
      final c = await pump(tester);
      expect(find.text('One'), findsOneWidget);
      final Offset start = tester.getCenter(find.text('One'));
      final TestGesture gesture = await tester.startGesture(start);
      await tester.pump();
      // Over column b, above the middle of "Four".
      final Offset four = tester.getRect(find.text('Four')).topCenter;
      for (int i = 1; i <= 10; i++) {
        await gesture.moveTo(
          Offset.lerp(start, four + const Offset(0, 4), i / 10)!,
        );
        await tester.pump();
      }
      final Map<String, Object?> drag = c.dragAndDrop.value;
      expect(drag['active'], isTrue);
      expect(drag['data'], 'c1');
      expect(drag['over'], 'b');
      expect(drag['beforeId'], 'c4');
      expect(drag['index'], 0);
      expect(drag['accepted'], isTrue);
      // The slot opened in column b and "One" collapsed in column a.
      expect(
        find.byKey(const ValueKey('codelessly-drop-slot')),
        findsOneWidget,
      );
      // The card follows the pointer with its text.
      expect(
        find.descendant(
          of: find.byType(IgnorePointer),
          matching: find.text('One', findRichText: true),
        ),
        findsWidgets,
      );

      await gesture.up();
      await tester.pumpAndSettle();
      expect(lane(c, 'a'), ['c2', 'c3']);
      expect(lane(c, 'b'), ['c1', 'c4']);
      expect(c.dragAndDrop.value['active'], isFalse);
      expect(find.byKey(const ValueKey('codelessly-drop-slot')), findsNothing);
    },
  );

  testWidgets('a full column refuses the drop (acceptIf) and nothing moves', (
    tester,
  ) async {
    final c = await pump(tester);
    // Fill column b to its limit of 2 first.
    Future<void> dragTo(String title, Offset to) async {
      final Offset start = tester.getCenter(find.text(title));
      final TestGesture gesture = await tester.startGesture(start);
      await tester.pump();
      for (int i = 1; i <= 10; i++) {
        await gesture.moveTo(Offset.lerp(start, to, i / 10)!);
        await tester.pump();
      }
      await gesture.up();
      await tester.pumpAndSettle();
    }

    await dragTo('One', const Offset(240, 300));
    expect(lane(c, 'b'), ['c4', 'c1']);

    final Offset start = tester.getCenter(find.text('Two'));
    final TestGesture gesture = await tester.startGesture(start);
    await tester.pump();
    for (int i = 1; i <= 10; i++) {
      await gesture.moveTo(Offset.lerp(start, const Offset(240, 300), i / 10)!);
      await tester.pump();
    }
    expect(c.dragAndDrop.value['over'], 'b');
    expect(c.dragAndDrop.value['accepted'], isFalse);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(lane(c, 'a'), ['c2', 'c3']);
    expect(lane(c, 'b'), ['c4', 'c1']);
  });

  testWidgets('drag.x/y and fx/fy give where the dragged node lands', (
    tester,
  ) async {
    final c = await pump(tester);
    // The dragged node's centre is the pointer less the grab's distance
    // from the node's centre. Column b spans x 160..320, y 0..400.
    final Offset start = tester.getCenter(find.text('One'));
    final Rect card = tester.getRect(
      find
          .ancestor(of: find.text('One'), matching: find.byType(DragSourceBox))
          .first,
    );
    final Offset fromCentre = start - card.center;
    final TestGesture gesture = await tester.startGesture(start);
    await tester.pump();
    Offset to = const Offset(240, 300);
    for (int i = 1; i <= 10; i++) {
      await gesture.moveTo(Offset.lerp(start, to, i / 10)!);
      await tester.pump();
    }
    Map<String, Object?> drag = c.dragAndDrop.value;
    Offset centre = to - fromCentre - const Offset(160, 0);
    expect(drag['over'], 'b');
    expect(drag['x'] as double, closeTo(centre.dx, 0.5));
    expect(drag['y'] as double, closeTo(centre.dy, 0.5));
    expect(drag['fx'] as double, closeTo(centre.dx / 160, 0.01));
    expect(drag['fy'] as double, closeTo(centre.dy / 400, 0.01));
    // Moving within the target updates it.
    to = const Offset(250, 100);
    await gesture.moveTo(to);
    await tester.pump();
    drag = c.dragAndDrop.value;
    centre = to - fromCentre - const Offset(160, 0);
    expect(drag['x'] as double, closeTo(centre.dx, 0.5));
    expect(drag['fy'] as double, closeTo(centre.dy / 400, 0.01));
    await gesture.up();
    await tester.pumpAndSettle();
    // The drop keeps where it landed for the drop's actions.
    expect(c.dragAndDrop.value['fy'] as double, closeTo(centre.dy / 400, 0.01));
  });

  testWidgets('reordering within a column', (tester) async {
    final c = await pump(tester);
    final Offset start = tester.getCenter(find.text('Three'));
    final Offset to =
        tester.getRect(find.text('One')).topCenter + const Offset(0, 2);
    final TestGesture gesture = await tester.startGesture(start);
    await tester.pump();
    for (int i = 1; i <= 10; i++) {
      await gesture.moveTo(Offset.lerp(start, to, i / 10)!);
      await tester.pump();
    }
    expect(c.dragAndDrop.value['beforeId'], 'c1');
    await gesture.up();
    await tester.pumpAndSettle();
    expect(lane(c, 'a'), ['c3', 'c1', 'c2']);
  });

  test('moveItems moves records before another and merges changes', () {
    Object? eval(String f, Map<String, Object?> vars) =>
        FormulaEvaluator.evaluate(f, (path) => vars[path]);
    final list = [
      {'id': 'a', 'lane': 'x'},
      {'id': 'b', 'lane': 'x'},
      {'id': 'c', 'lane': 'y'},
    ];
    expect(
      eval("moveItems(list, 'a', 'c', object('lane', 'y'))", {'list': list}),
      [
        {'id': 'b', 'lane': 'x'},
        {'id': 'a', 'lane': 'y'},
        {'id': 'c', 'lane': 'y'},
      ],
    );
    expect(
      eval("moveItems(list, ids, '')", {
        'list': list,
        'ids': ['a', 'b'],
      }),
      [
        {'id': 'c', 'lane': 'y'},
        {'id': 'a', 'lane': 'x'},
        {'id': 'b', 'lane': 'x'},
      ],
    );
    expect(eval("moveItems(list, 'zz', 'a')", {'list': list}), list);
  });

  testWidgets('a right click fires secondaryClick with the pointer position', (
    tester,
  ) async {
    final List<Object?> results = [];
    final manager = PassiveNodeTransformerManager(
      (id) => throw StateError(id),
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    final RectangleNode node = RectangleNode(
      id: 'card',
      name: 'Card',
      basicBoxLocal: NodeBox(0, 0, 100, 60),
      reactions: [
        Reaction(
          name: 'menu',
          trigger: TriggerModel(type: TriggerType.secondaryClick),
          action: CallFunctionAction(name: 'menu'),
        ),
      ],
    );
    final codelesslyContext = CodelesslyContext.empty()
      ..functions = {
        'menu': (context, reference, params) =>
            results.add(ActionChain.current?.result),
      };
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: codelesslyContext,
        child: MaterialApp(
          home: ActionChainHost(
            child: Align(
              alignment: Alignment.topLeft,
              child: Builder(
                builder: (context) => manager.wrapWithReaction(
                  context,
                  node,
                  const SizedBox(width: 100, height: 60),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tapAt(const Offset(30, 20), buttons: kSecondaryButton);
    await tester.pump();
    expect(results, [
      {'x': 30.0, 'y': 20.0},
    ]);
    expect(FunctionsRepository.pointerOf(results.single), const Offset(30, 20));
    expect(FunctionsRepository.pointerOf({'x': 'a'}), isNull);
  });
}
