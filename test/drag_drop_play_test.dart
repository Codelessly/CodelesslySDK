import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/functions/action_chain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Reaction call(String name, TriggerType type) => Reaction(
  name: name,
  action: CallFunctionAction(name: name),
  trigger: TriggerModel(type: type),
);

RectangleNode box(
  String id, {
  List<Reaction> reactions = const [],
  DraggableModel? draggable,
  DropTargetModel? dropTarget,
  Map<String, String>? variables,
  List<EffectAnimation> effects = const [],
  ParticleEmitter? particles,
  String flightKey = '',
  MotionModel? motion,
}) =>
    RectangleNode(
        id: id,
        name: id,
        basicBoxLocal: NodeBox(0, 0, 100, 100),
        reactions: reactions,
      )
      ..parentID = kRootNode
      ..variables.addAll(variables ?? const {})
      ..draggable = draggable
      ..dropTarget = dropTarget
      ..effectAnimations = effects
      ..particles = particles
      ..flightKey = flightKey
      ..motion = motion;

void main() {
  late List<String> calls;
  late Map<String, Object?> seen;
  late CodelesslyContext codelesslyContext;

  setUp(() {
    calls = [];
    seen = {};
    FlightRegistry.reset();
    codelesslyContext = CodelesslyContext.empty()
      ..functions = {
        for (final name in [
          'start',
          'completed',
          'canceled',
          'enter',
          'exit',
          'dropped',
          'rejected',
        ])
          name: (context, reference, params) {
            calls.add(name);
            final ScopedValues values = ActionChain.scopedValuesOf(context);
            seen[name] = PropertyValueDelegate.getVariableValueFromPath<Object>(
              'drop',
              scopedValues: values,
            );
          },
      };
  });

  Future<void> pumpNodes(
    WidgetTester tester,
    List<BaseNode> nodes, {
    Map<String, Object?> data = const {},
  }) async {
    final registry = NodeRegistry()..setNodes({for (final n in nodes) n.id: n});
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: codelesslyContext,
        child: MaterialApp(
          home: Material(
            child: Align(
              alignment: Alignment.topLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final node in nodes)
                    SizedBox(
                      width: 100,
                      height: 100,
                      child: Builder(
                        builder: (context) => manager.buildWidgetFromNode(
                          node,
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
  }

  RectangleNode tile(String letter) => box(
    'tile',
    draggable: DraggableModel(data: letter, group: 'letters'),
    reactions: [
      call('start', TriggerType.dragStart),
      call('completed', TriggerType.dragCompleted),
      call('canceled', TriggerType.dragCanceled),
    ],
  );

  RectangleNode slot() => box(
    'slot',
    dropTarget: const DropTargetModel(
      groups: ['letters'],
      acceptIf: r"${= drop.data == 'A'}",
    ),
    reactions: [
      call('enter', TriggerType.dragEnter),
      call('exit', TriggerType.dragExit),
      call('dropped', TriggerType.drop),
      call('rejected', TriggerType.dropRejected),
    ],
  );

  testWidgets('a right drop runs drop with its data and offset', (
    tester,
  ) async {
    await pumpNodes(tester, [tile('A'), slot()]);
    final TestGesture gesture = await tester.startGesture(const Offset(50, 50));
    await gesture.moveBy(const Offset(0, 20));
    await tester.pump();
    await gesture.moveBy(const Offset(10, 75));
    await tester.pump();
    expect(calls, containsAllInOrder(['start', 'enter']));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(calls, containsAllInOrder(['dropped', 'completed']));
    expect(calls, isNot(contains('rejected')));
    final Map drop = seen['dropped'] as Map;
    expect(drop['data'], 'A');
    expect(drop['accepts'], isTrue);
    // The copy was let go 10 px right and 5 px below the slot's top left.
    expect(drop['dx'], closeTo(10, 0.01));
    expect(drop['dy'], closeTo(-5, 0.01));
  });

  testWidgets('a wrong drop is rejected and the tile springs back', (
    tester,
  ) async {
    await pumpNodes(tester, [tile('B'), slot()]);
    final TestGesture gesture = await tester.startGesture(const Offset(50, 50));
    await gesture.moveBy(const Offset(0, 20));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 80));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(calls, containsAllInOrder(['rejected', 'canceled']));
    expect(calls, isNot(contains('dropped')));
    expect((seen['rejected'] as Map)['data'], 'B');

    // Springing back: drawn below its place, then settles in it.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    final Finder moved = find.byWidgetPredicate(
      (w) => w is Transform && w.transform.getTranslation().y > 1,
    );
    expect(moved, findsWidgets);
    await tester.pumpAndSettle();
    expect(moved, findsNothing);
  });

  testWidgets('a full target takes nothing', (tester) async {
    final RectangleNode full = slot()
      ..dropTarget = const DropTargetModel(fullIf: 'true');
    await pumpNodes(tester, [tile('A'), full]);
    final TestGesture gesture = await tester.startGesture(const Offset(50, 50));
    await gesture.moveBy(const Offset(0, 20));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 80));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(calls, isNot(contains('enter')));
    expect(calls, isNot(contains('dropped')));
    expect(calls, contains('canceled'));
  });

  testWidgets('an effect replays when its play key changes', (tester) async {
    RectangleNode shaker(String key) => box(
      'shaker',
      effects: [EffectAnimation.preset(EffectAnimationType.shake)],
      variables: {EffectAnimation.playKeyVariable('shake'): '\${= $key}'},
    );
    Finder shaken() => find.byWidgetPredicate(
      (w) => w is Transform && w.transform.getTranslation().x.abs() > 0.5,
    );
    await pumpNodes(tester, [shaker('0')]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(shaken(), findsNothing, reason: 'no shake on first build');

    await pumpNodes(tester, [shaker('1')]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(shaken(), findsWidgets);
    await tester.pumpAndSettle();
    expect(shaken(), findsNothing);
  });

  testWidgets('play animation action plays an effect and waits for it', (
    tester,
  ) async {
    await pumpNodes(tester, [
      box('pop', effects: [EffectAnimation.preset(EffectAnimationType.pop)]),
    ]);
    bool done = false;
    NodePlayRegistry.play('pop', 'pop').then((_) => done = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(
      find.byWidgetPredicate(
        (w) => w is Transform && w.transform.getMaxScaleOnAxis() > 1.05,
      ),
      findsWidgets,
    );
    expect(done, isFalse);
    await tester.pumpAndSettle();
    expect(done, isTrue);
  });

  testWidgets('particles fire on their play key and clear away', (
    tester,
  ) async {
    RectangleNode confetti(String key) => box(
      'confetti',
      particles: const ParticleEmitter(count: 30, lifetimeMs: 800),
      variables: {ParticleEmitter.playKeyVariable: '\${= $key}'},
    );
    await pumpNodes(tester, [confetti('0')]);
    await pumpNodes(tester, [confetti('1')]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('a spring motion overshoots and settles', (tester) async {
    RectangleNode mover(double x) => box(
      'mover',
      motion: const MotionModel(curve: MotionCurve.spring, springDamping: 10),
      variables: {'motion.translateX': '\${= $x}'},
    );
    await pumpNodes(tester, [mover(0)]);
    await pumpNodes(tester, [mover(100)]);
    double peak = 0;
    for (int i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      for (final Transform t in tester.widgetList<Transform>(
        find.byType(Transform),
      )) {
        peak = peak > t.transform.getTranslation().x
            ? peak
            : t.transform.getTranslation().x;
      }
    }
    expect(peak, greaterThan(102), reason: 'a loose spring overshoots');
    await tester.pumpAndSettle();
    final double rest = tester
        .widgetList<Transform>(find.byType(Transform))
        .map((t) => t.transform.getTranslation().x)
        .reduce((a, b) => a > b ? a : b);
    expect(rest, closeTo(100, 0.5));
  });

  testWidgets('a node flies in from where its flight key was', (tester) async {
    // The tile shows first; then it hides and the slot's tile (same key)
    // appears below it, flying in from the tile's place.
    final RectangleNode from = box('a', flightKey: 'tile-1');
    final RectangleNode to = box('b', flightKey: 'tile-1');
    await pumpNodes(tester, [from, box('gap')]);
    await pumpNodes(tester, [box('gap2'), to]);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    final Iterable<double> ys = tester
        .widgetList<Transform>(find.byType(Transform))
        .map((t) => t.transform.getTranslation().y);
    expect(ys.any((y) => y < -50), isTrue, reason: 'starts 100 px up');
    await tester.pumpAndSettle();
    expect(
      tester
          .widgetList<Transform>(find.byType(Transform))
          .every((t) => t.transform.getTranslation().y.abs() < 0.5),
      isTrue,
    );
  });

  testWidgets('bob and sway loops move the node', (tester) async {
    await pumpNodes(tester, [
      box('bob')
        ..loopAnimation = LoopAnimation.preset(
          LoopAnimationType.bob,
        ).copyWith(distance: 20),
    ]);
    await tester.pump(const Duration(milliseconds: 800));
    expect(
      find.byWidgetPredicate(
        (w) => w is Transform && w.transform.getTranslation().y < -15,
      ),
      findsOneWidget,
    );
  });
}
