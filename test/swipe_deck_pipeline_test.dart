import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/functions/action_chain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// A swipeable deck built only from primitives: a stacked list whose item
/// has a dismissing drag, a swipe reaction that drops the top card, and a
/// stamp whose opacity follows `${drag.right}`.
void main() {
  TextNode text(String id, String chars, {Map<String, String>? variables}) =>
      TextNode(
        id: id,
        name: id,
        basicBoxLocal: NodeBox(0, 0, 100, 20),
        data: chars,
        textMixedProps: [StartEndProp(start: 0, end: chars.length, fontSize: 14)],
        variables: variables ?? {},
      )..parentID = 'card';

  ({NodeRegistry registry, ListViewNode list}) build() {
    final FrameNode card = FrameNode(
      id: 'card',
      name: 'Card',
      basicBoxLocal: NodeBox(0, 0, 200, 300),
      children: const ['label', 'stamp'],
      reactions: [
        Reaction(
          trigger: TriggerModel(type: TriggerType.swipeRight),
          action: CallFunctionAction(name: 'good'),
        ),
        Reaction(
          trigger: TriggerModel(type: TriggerType.swipeLeft),
          action: CallFunctionAction(name: 'again'),
        ),
      ],
    )
      ..variables['motion.scale'] = r'${= 1 - index * 0.1}'
      ..parentID = 'deck'
      ..drag = const DragModel(
        release: DragRelease.dismiss,
        directions: [DragDirection.left, DragDirection.right],
        rotateFactor: 15,
      )
      ..motion = const MotionModel(durationMs: 300);
    final ListViewNode list = ListViewNode(
      id: 'deck',
      name: 'Deck',
      basicBoxLocal: NodeBox(0, 0, 400, 400),
      properties: ListViewProperties(stacked: true),
      children: const ['card'],
      variables: {'data': r'${cards}'},
    )..parentID = kRootNode;
    final registry = NodeRegistry()
      ..setNodes({
        list.id: list,
        card.id: card,
        'label': text('label', r'${item.id}'),
        'stamp': text('stamp', 'GOOD', variables: {'opacity': r'${drag.right}'}),
      });
    return (registry: registry, list: list);
  }

  testWidgets('dragging fades the stamp in; a swipe drops the card and the '
      'next one rises as the same widget', (tester) async {
    final t = build();
    final calls = <String>[];
    final Observable<VariableData> cards = Observable(
      VariableData(
        id: 'cards',
        name: 'cards',
        type: VariableType.list,
        value: [
          {'id': 'a'},
          {'id': 'b'},
          {'id': 'c'},
        ],
      ),
    );
    void drop(String name) {
      calls.add(name);
      final List current = cards.value.getValue().typedValue<List>()!;
      cards.set(cards.value.copyWith(value: current.sublist(1)));
    }

    final codelesslyContext = CodelesslyContext.empty()
      ..functions = {
        'good': (context, reference, params) => drop('good'),
        'again': (context, reference, params) => drop('again'),
      }
      ..variables['cards'] = cards;
    final manager = PassiveNodeTransformerManager(
      t.registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: codelesslyContext,
        child: MaterialApp(
          home: ActionChainHost(
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 400,
                height: 400,
                child: Builder(
                  builder: (context) => manager.buildWidgetFromNode(
                    t.list,
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
    expect(find.text('a'), findsOneWidget);

    double stampOpacity() {
      // The stamp of the top card (a), not of the cards behind it.
      final Finder topCard = find.ancestor(
        of: find.text('a'),
        matching: find.byType(NodeDrag),
      );
      final Iterable<Opacity> o = tester.widgetList<Opacity>(
        find.ancestor(
          of: find.descendant(of: topCard, matching: find.text('GOOD')),
          matching: find.byType(Opacity),
        ),
      );
      return o.isEmpty ? 1 : o.first.opacity;
    }

    expect(stampOpacity(), 0);
    final NodeDragState bBefore = tester.state(
      find.ancestor(of: find.text('b'), matching: find.byType(NodeDrag)),
    );

    // Drag the top card halfway to the threshold: the stamp is half in.
    final gesture = await tester.startGesture(tester.getCenter(find.text('a')));
    await gesture.moveBy(const Offset(20, 0));
    await gesture.moveBy(const Offset(35, 0));
    await tester.pump();
    expect(stampOpacity(), greaterThan(0.3));
    expect(stampOpacity(), lessThan(1));
    await gesture.moveBy(const Offset(100, 0));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(calls, ['good']);
    expect(find.text('a'), findsNothing);
    // Card b is now on top, as the same widget it was behind a.
    final NodeDragState bAfter = tester.state(
      find.ancestor(of: find.text('b'), matching: find.byType(NodeDrag)),
    );
    expect(identical(bBefore, bAfter), isTrue);
    expect(bAfter.widget.order, 0);

    // A grade button: fling the top card left from an action.
    await tester.runAsync(() async {});
    final Future<void> flung = NodeDrag.control(
      'card',
      DragCommand.fling,
      DragDirection.left,
    );
    await tester.pumpAndSettle();
    await flung;
    expect(calls, ['good', 'again']);
    expect(find.text('b'), findsNothing);
    expect(find.text('c'), findsOneWidget);
  });
}
