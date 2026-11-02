import 'dart:math' as math;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/functions/action_chain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// A swipeable card deck, as a builder makes it: a stacked list keyed by its
/// items' ids and painted front card last, its cards scaled and raised by
/// their depth with motion, the front card following the finger; and a
/// progress fill sized as a fraction of its track.
void main() {
  const List<Map<String, Object?>> passes = [
    {'id': 'a'},
    {'id': 'b'},
    {'id': 'c'},
    {'id': 'd'},
  ];
  const String depth = '((index - front + 4) % 4)';

  Observable<VariableData> variable(String name, VariableType type, value) =>
      Observable(VariableData(id: name, name: name, type: type, value: value));

  ({NodeRegistry registry, ListViewNode deck, RectangleNode card}) build({
    Map<String, String> listVariables = const {},
    bool reversePaintOrder = false,
    DragModel? drag,
    List<Reaction> reactions = const [],
  }) {
    final RectangleNode card = RectangleNode.fromJson({
      ...RectangleNode(
        id: 'card',
        name: 'Card',
        basicBoxLocal: NodeBox(0, 0, 200, 120),
        fills: [PaintModel.solid(id: 'f', color: ColorRGB.fromHex('#13294B'))],
        reactions: reactions,
      ).toJson(),
      'motion': const MotionModel(
        originY: -1,
        durationMs: 400,
        curve: MotionCurve.linear,
      ).toJson(),
      'drag': ?drag?.toJson(),
      'variables': {
        'motion.scale': '\${= 1 - 0.055 * $depth}',
        'motion.translateY': '\${= 0 - 11.2 * $depth}',
        'drag.enabled': '\${= $depth == 0}',
      },
    });
    final ListViewNode deck = ListViewNode(
      id: 'deck',
      name: 'Deck',
      basicBoxLocal: NodeBox(0, 0, 200, 160),
      properties: ListViewProperties(
        stacked: true,
        reversePaintOrder: reversePaintOrder,
      ),
      children: ['card'],
      variables: {'data': r'${passes}', ...listVariables},
    );
    card.parentID = deck.id;
    deck.parentID = kRootNode;
    final registry = NodeRegistry()..setNodes({deck.id: deck, card.id: card});
    return (registry: registry, deck: deck, card: card);
  }

  Future<CodelesslyContext> pump(
    WidgetTester tester,
    NodeRegistry registry,
    BaseNode root, {
    Map<String, CodelesslyFunction> functions = const {},
  }) async {
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    final CodelesslyContext codelesslyContext = CodelesslyContext.empty()
      ..functions = functions
      ..variables['passes'] = variable('passes', VariableType.list, passes)
      ..variables['front'] = variable('front', VariableType.integer, 0)
      ..variables['deckDrag'] = variable('deckDrag', VariableType.decimal, 0)
      ..variables['progress'] = variable(
        'progress',
        VariableType.decimal,
        0.25,
      );
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: codelesslyContext,
        child: MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 400,
              height: 300,
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
    );
    return codelesslyContext;
  }

  void setFront(CodelesslyContext context, int front) {
    final Observable<VariableData> v = context.variables['front']!;
    v.set(v.value.copyWith(value: front));
  }

  /// The ids of the cards from the bottom of the deck to the top.
  List<String> paintOrder(WidgetTester tester) {
    final Stack stack = tester.widget<Stack>(
      find
          .descendant(
            of: find.byType(StackedItems),
            matching: find.byType(Stack),
          )
          .first,
    );
    return [
      for (final Widget child in stack.children)
        switch (child.key) {
          ValueKey(value: (_, (_, final String id))) => id,
          final Key? key => '$key',
        },
    ];
  }

  /// The stateful body under a [NodeMotion], which holds its animation.
  final Finder motionBody = find.byWidgetPredicate(
    (w) => w is StatefulWidget && '${w.runtimeType}' == '_NodeMotionBody',
  );

  Finder cardKeyed(String id) => find.byKey(listItemKey(('item', id))).first;

  /// The scale the card [id] is drawn at by its motion.
  double scaleOf(WidgetTester tester, String id) {
    final Finder motion = find.descendant(
      of: cardKeyed(id),
      matching: find.byType(NodeMotion),
    );
    final Iterable<Transform> transforms = tester.widgetList<Transform>(
      find.descendant(of: motion, matching: find.byType(Transform)),
    );
    if (transforms.isEmpty) return 1;
    return transforms.first.transform.entry(0, 0);
  }

  group('keyed list items and paint order', () {
    testWidgets('a stacked list draws the first item on top by default', (
      tester,
    ) async {
      final t = build(listVariables: {'itemKey': r'${item.id}'});
      await pump(tester, t.registry, t.deck);
      expect(paintOrder(tester), ['d', 'c', 'b', 'a']);
    });

    testWidgets('reverse paint order draws the last item on top', (
      tester,
    ) async {
      final t = build(
        listVariables: {'itemKey': r'${item.id}'},
        reversePaintOrder: true,
      );
      await pump(tester, t.registry, t.deck);
      expect(paintOrder(tester), ['a', 'b', 'c', 'd']);
    });

    testWidgets('a bound z index puts the front card on top as the deck '
        'wraps, keeping each card and animating it to its new depth', (
      tester,
    ) async {
      final t = build(
        listVariables: {
          'itemKey': r'${item.id}',
          'itemZIndex': '\${= 0 - $depth}',
        },
      );
      final CodelesslyContext context = await pump(tester, t.registry, t.deck);
      await tester.pumpAndSettle();
      expect(paintOrder(tester), ['d', 'c', 'b', 'a']);
      expect(scaleOf(tester, 'a'), closeTo(1, 1e-6));
      expect(scaleOf(tester, 'b'), closeTo(0.945, 1e-6));
      final State motionOfA = tester.state(
        find.descendant(of: cardKeyed('a'), matching: motionBody),
      );

      // The front card goes to the back; the first item now paints under
      // the others although it is first in the list.
      setFront(context, 1);
      await tester.pump();
      expect(paintOrder(tester), ['a', 'd', 'c', 'b']);
      // Same card, same state: its motion slides it back over 400ms.
      expect(
        tester.state(
          find.descendant(of: cardKeyed('a'), matching: motionBody),
        ),
        same(motionOfA),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(scaleOf(tester, 'a'), closeTo(1 - 0.055 * 1.5, 1e-3));
      expect(scaleOf(tester, 'b'), closeTo(1 - 0.055 * 0.5, 1e-3));
      await tester.pumpAndSettle();
      expect(scaleOf(tester, 'a'), closeTo(1 - 0.055 * 3, 1e-6));
      expect(scaleOf(tester, 'b'), closeTo(1, 1e-6));
    });

    testWidgets('a data reorder keeps keyed items', (tester) async {
      final t = build(listVariables: {'itemKey': r'${item.id}'});
      final CodelesslyContext context = await pump(tester, t.registry, t.deck);
      final State before = tester.state(
        find.descendant(of: cardKeyed('c'), matching: motionBody),
      );
      final Observable<VariableData> v = context.variables['passes']!;
      v.set(v.value.copyWith(value: [passes[2], passes[0], passes[1]]));
      await tester.pump();
      expect(paintOrder(tester), ['b', 'a', 'c']);
      expect(
        tester.state(
          find.descendant(of: cardKeyed('c'), matching: motionBody),
        ),
        same(before),
      );
    });

    test('repeated or missing keys fall back to the index', () {
      final ListViewNode list = ListViewNode(
        id: 'l',
        name: 'l',
        basicBoxLocal: NodeBox(0, 0, 10, 10),
        properties: ListViewProperties(stacked: true),
        children: const [],
        variables: {'itemKey': r'${item.id}'},
      );
      final List<Map> values = [
        {'id': 'x'},
        {'id': 'x'},
        {'name': 'no id'},
        {'id': 'y'},
      ];
      final ListItemArrangement arrangement = ListItemArrangement.of(
        list,
        count: values.length,
        values: (index) => values[index],
        scope: ScopedValues.empty(),
        firstOnTop: true,
      );
      expect(
        [for (int i = 0; i < 4; i++) arrangement.keyOf(i)],
        [('index', 0), ('index', 1), ('index', 2), ('item', 'y')],
      );
      expect(arrangement.paintOrder, [3, 2, 1, 0]);
    });
  });

  group('drag follow', () {
    // The card drag Meridian's deck uses, in the unified drag model.
    const DragModel cardDrag = DragModel(
      axis: DragAxis.horizontal,
      release: DragRelease.dismiss,
      rotateFactor: 9,
      originY: -1,
      distanceThreshold: 0.28,
      velocityThreshold: 700,
      snapBackMs: 260,
      snapCurve: MotionCurve.easeOutBack,
      flyOutMs: 240,
      flyOutDistance: 1.25,
      xVariable: 'deckDrag',
    );

    Finder frontCard() => cardKeyed('a');

    /// The drag of [frontCard], which the finger grabs.
    Finder grab() =>
        find.descendant(of: frontCard(), matching: find.byType(NodeDrag)).first;

    /// The transform the drag draws the front card with, if any.
    Transform? followTransform(WidgetTester tester) {
      final Finder drag = grab();
      final Iterable<Widget> transforms = tester.widgetList(
        find.descendant(
          of: drag,
          matching: find.byWidgetPredicate(
            (w) => w is Transform && w.child is DragScope,
          ),
        ),
      );
      return transforms.firstOrNull as Transform?;
    }

    double deckDrag(CodelesslyContext context) =>
        double.parse('${context.variables['deckDrag']!.value.value}');

    testWidgets('the front card follows the finger, tilts, reports the '
        'drag and springs back when let go short', (tester) async {
      final List<Map> ends = [];
      final t = build(
        listVariables: {
          'itemKey': r'${item.id}',
          'itemZIndex': '\${= 0 - $depth}',
        },
        drag: cardDrag,
        reactions: [
          Reaction(
            action: CallFunctionAction(name: 'end'),
            trigger: TriggerModel(type: TriggerType.dragEnd),
          ),
        ],
      );
      final CodelesslyContext context = await pump(
        tester,
        t.registry,
        t.deck,
        functions: {
          'end': (context, reference, params) =>
              ends.add(ActionChain.current!.result! as Map),
        },
      );
      await tester.pumpAndSettle();

      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(grab()),
      );
      await gesture.moveBy(const Offset(-20, 0));
      await gesture.moveBy(const Offset(-20, 3));
      await tester.pump();
      await tester.pump();
      final Transform follow = followTransform(tester)!;
      final double dx = follow.transform.getTranslation().x;
      expect(dx, lessThan(-15));
      // A horizontal drag doesn't move the card up or down.
      expect(follow.transform.getTranslation().y, 0);
      expect(deckDrag(context), closeTo(dx, 0.01));
      // Tilted by 9° per card width dragged.
      expect(
        follow.transform.getRotation().entry(1, 0),
        closeTo(math.sin(9 * dx / 200 * math.pi / 180), 1e-3),
      );

      // Let go slowly, short of the threshold.
      await tester.pump(const Duration(seconds: 1));
      await gesture.up();
      await tester.pump();
      expect(ends.single['dismissed'], isFalse);
      expect(ends.single['direction'], '');
      expect(ends.single['dx'], closeTo(dx, 1e-6));
      await tester.pump(const Duration(milliseconds: 100));
      final double back = followTransform(tester)!.transform.getTranslation().x;
      expect(back, greaterThan(dx));
      await tester.pumpAndSettle();
      expect(followTransform(tester), isNull);
      expect(deckDrag(context), 0);
    });

    testWidgets('a fling past the threshold flies the card off its own '
        'width, then the swipe actions send it to the back', (tester) async {
      final List<Map> ends = [];
      final List<Map> swipes = [];
      late CodelesslyContext context;
      final t = build(
        listVariables: {
          'itemKey': r'${item.id}',
          'itemZIndex': '\${= 0 - $depth}',
        },
        drag: cardDrag,
        reactions: [
          Reaction(
            action: CallFunctionAction(name: 'end'),
            trigger: TriggerModel(type: TriggerType.dragEnd),
          ),
          Reaction(
            action: CallFunctionAction(name: 'swiped'),
            trigger: TriggerModel(type: TriggerType.swipeLeft),
          ),
        ],
      );
      context = await pump(
        tester,
        t.registry,
        t.deck,
        functions: {
          'end': (_, reference, params) =>
              ends.add(ActionChain.current!.result! as Map),
          'swiped': (_, reference, params) {
            swipes.add(ActionChain.current!.result! as Map);
            setFront(context, 1);
          },
        },
      );
      await tester.pumpAndSettle();

      await tester.fling(grab(), const Offset(-90, 0), 1500);
      await tester.pump();
      // Let go: the drag end reports the dismissal at once.
      expect(ends.single['dismissed'], isTrue);
      expect(ends.single['direction'], 'left');
      expect(ends.single['velocityX'], lessThan(-700));
      // Flying off: the swipe actions wait for it to land.
      expect(swipes, isEmpty);
      await tester.pump(const Duration(milliseconds: 120));
      final double flying = followTransform(tester)!.transform
          .getTranslation()
          .x;
      expect(flying, lessThan(-90));
      await tester.pump(const Duration(milliseconds: 200));
      expect(swipes.single['direction'], 'left');
      await tester.pumpAndSettle();
      expect(paintOrder(tester), ['a', 'd', 'c', 'b']);
      // Back to rest at the back of the deck; the card behind took over.
      expect(followTransform(tester), isNull);
      expect(scaleOf(tester, 'a'), closeTo(1 - 0.055 * 3, 1e-6));
      expect(NodeDrag.instanceOf('card')!.widget.order, 1);
    });

    testWidgets('a card that only reports the drag stays put', (tester) async {
      final t = build(
        listVariables: {'itemKey': r'${item.id}'},
        drag: cardDrag.copyWith(follow: false),
      );
      final CodelesslyContext context = await pump(tester, t.registry, t.deck);
      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(grab()),
      );
      await gesture.moveBy(const Offset(-20, 0));
      await gesture.moveBy(const Offset(-30, 0));
      await tester.pump();
      await tester.pump();
      expect(followTransform(tester), isNull);
      expect(deckDrag(context), lessThan(-15));
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('a vertical drag on a horizontal card is held back', (
      tester,
    ) async {
      final t = build(
        listVariables: {'itemKey': r'${item.id}'},
        drag: cardDrag.copyWith(resistance: 1),
      );
      await pump(tester, t.registry, t.deck);
      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(grab()),
      );
      await gesture.moveBy(const Offset(0, 40));
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump();
      final Transform? follow = followTransform(tester);
      expect(follow?.transform.getTranslation().y ?? 0, 0);
      await gesture.up();
      await tester.pumpAndSettle();
    });
  });

  group('fractional size', () {
    ({NodeRegistry registry, FrameNode track}) progressBar(
      Map<String, Object?> fill,
    ) {
      final RectangleNode bar = RectangleNode.fromJson({
        ...RectangleNode(
          id: 'fill',
          name: 'Fill',
          basicBoxLocal: NodeBox(0, 0, 10, 6),
          positioningMode: PositioningMode.pin,
          edgePins: const EdgePinsModel(
            left: 0,
            top: 0,
            right: null,
            bottom: null,
          ),
        ).toJson(),
        ...fill,
      });
      final FrameNode track = FrameNode(
        id: 'track',
        name: 'Track',
        basicBoxLocal: NodeBox(0, 0, 300, 6),
        children: ['fill'],
      );
      bar.parentID = track.id;
      track.parentID = kRootNode;
      return (
        registry: NodeRegistry()..setNodes({track.id: track, bar.id: bar}),
        track: track,
      );
    }

    Finder fillBox() => find.byWidgetPredicate(
      (w) => w is FreeformChild && '${w.key}'.contains('[fill]'),
    );

    testWidgets('a bound width factor sizes the fill by its track', (
      tester,
    ) async {
      final p = progressBar({
        'variables': {'widthFactor': r'${progress}'},
      });
      final CodelesslyContext context = await pump(tester, p.registry, p.track);
      // The track fills the 400 px wide host at runtime.
      expect(tester.getSize(fillBox()), const Size(100, 6));
      final Observable<VariableData> v = context.variables['progress']!;
      v.set(v.value.copyWith(value: 0.6));
      await tester.pump();
      expect(tester.getSize(fillBox()), const Size(240, 6));
    });

    testWidgets('a fixed width and height factor size the node', (
      tester,
    ) async {
      final p = progressBar({'widthFactor': 0.5, 'heightFactor': 0.5});
      await pump(tester, p.registry, p.track);
      expect(tester.getSize(fillBox()), const Size(200, 150));
    });

    testWidgets('a bound width wins over the factor', (tester) async {
      final p = progressBar({
        'widthFactor': 0.5,
        'variables': {'width': r'${= 42}'},
      });
      await pump(tester, p.registry, p.track);
      expect(tester.getSize(fillBox()).width, 42);
    });
  });
}
