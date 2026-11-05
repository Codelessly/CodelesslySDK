import 'dart:math' as math;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/functions/action_chain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Gestures through the node pipeline: nodes with a transform gesture, drag
/// physics, drag tracks and pinch reactions, built by the transformer
/// manager as at runtime, reading and writing real variables and running
/// reactions with `${result}`.
void main() {
  late CodelesslyContext codelessly;
  late Map<String, List<Map>> results;

  VariableData variable(String name, VariableType type, Object value) =>
      VariableData(id: name, name: name, type: type, value: value);

  /// A variable's value; numbers are stored as text.
  Object? valueOf(String name) {
    final Object? value = codelessly.variables[name]!.value.value;
    return value is String ? num.tryParse(value) ?? value : value;
  }

  void setVariable(String name, Object value) {
    final Observable<VariableData> v = codelessly.variables[name]!;
    v.set(v.value.copyWith(value: value));
  }

  Reaction capture(TriggerType type, String name) => Reaction(
    action: CallFunctionAction(name: name),
    trigger: TriggerModel(type: type),
  );

  Future<void> pump(
    WidgetTester tester,
    List<BaseNode> nodes, {
    List<VariableData> variables = const [],
  }) async {
    results = {};
    final registry = NodeRegistry()
      ..setNodes({for (final node in nodes) node.id: node});
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    CodelesslyFunction record(String name) =>
        (context, reference, params) => (results[name] ??= []).add(
          Map.of(ActionChain.current!.result! as Map),
        );
    codelessly = CodelesslyContext.empty()
      ..functions = {
        for (final name in ['end', 'changed', 'pinch', 'drag', 'tap'])
          name: record(name),
      };
    for (final VariableData v in variables) {
      codelessly.variables[v.id] = Observable(v);
    }
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: codelessly,
        child: MaterialApp(
          home: Material(
            child: Align(
              alignment: Alignment.topLeft,
              child: Builder(
                builder: (context) => manager.buildWidgetFromNode(
                  nodes.first,
                  context,
                  settings: const WidgetBuildSettings(debugLabel: 'runtime'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  }

  FrameNode board(List<String> children, {double size = 400}) => FrameNode(
    id: 'board',
    name: 'board',
    basicBoxLocal: NodeBox(0, 0, size, size),
    children: children,
  )..parentID = kRootNode;

  FrameNode box(
    String id,
    NodeBox at, {
    List<String> children = const [],
    List<Reaction> reactions = const [],
  }) => FrameNode(
    id: id,
    name: id,
    basicBoxLocal: at,
    horizontalFit: SizeFit.fixed,
    verticalFit: SizeFit.fixed,
    children: children,
    fills: [PaintModel.solid(id: 'f$id', color: ColorRGB.fromHex('#3260C8'))],
    reactions: reactions,
  )..parentID = 'board';

  TextNode label(String id, String parent, String data) => TextNode(
    id: id,
    name: id,
    basicBoxLocal: NodeBox(0, 0, 80, 20),
    data: data,
    textMixedProps: [StartEndProp(start: 0, end: data.length, fontSize: 12)],
  )..parentID = parent;

  TransformPose poseOf(WidgetTester tester, [int index = 0]) => tester
      .state<NodeTransformGestureState>(
        find.byType(NodeTransformGesture).at(index),
      )
      .pose;

  Future<void> pinch(
    WidgetTester tester,
    Offset center,
    double from,
    double to, {
    double turnDegrees = 0,
  }) async {
    Offset at(double r, double degrees, bool first) {
      final double a = degrees * math.pi / 180 + (first ? math.pi : 0);
      return center + Offset(math.cos(a), math.sin(a)) * r;
    }

    final TestGesture g1 = await tester.startGesture(
      at(from, 0, true),
      pointer: 11,
    );
    final TestGesture g2 = await tester.startGesture(
      at(from, 0, false),
      pointer: 12,
    );
    for (int i = 1; i <= 12; i++) {
      final double t = i / 12;
      final double r = from + (to - from) * t;
      await g1.moveTo(at(r, turnDegrees * t, true));
      await g2.moveTo(at(r, turnDegrees * t, false));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g1.up();
    await g2.up();
  }

  group('transform gesture', () {
    List<BaseNode> photo({
      TransformGestureModel model = const TransformGestureModel(
        bounds: GestureBounds.none,
        scaleVariable: 'zoom',
        xVariable: 'panX',
        yVariable: 'panY',
      ),
      NodeBox? at,
    }) => [
      board(['photo']),
      box(
        'photo',
        at ?? NodeBox(100, 100, 200, 200),
        children: ['zoomLabel'],
        reactions: [
          capture(TriggerType.changeEnd, 'end'),
          capture(TriggerType.changed, 'changed'),
        ],
      )..transformGesture = model,
      label('zoomLabel', 'photo', r'${transform.scale}'),
    ];

    final List<VariableData> pose = [
      variable('zoom', VariableType.decimal, 1),
      variable('panX', VariableType.decimal, 0),
      variable('panY', VariableType.decimal, 0),
    ];

    testWidgets('a pinch writes the zoom variable and runs changed and '
        'changeEnd with the pose; the node reads transform.scale', (
      tester,
    ) async {
      await pump(tester, photo(), variables: pose);
      expect(find.byType(NodeTransformGesture), findsOneWidget);
      await pinch(tester, const Offset(200, 200), 30, 60);
      await tester.pumpAndSettle();
      expect(valueOf('zoom'), closeTo(2, 0.02));
      expect(results['changed'], isNotEmpty);
      expect(
        results['changed']!.last.keys,
        containsAll(['x', 'scale', 'gesture']),
      );
      expect(results['end']!.last['scale'], closeTo(2, 0.02));
      expect(results['changed']!.any((r) => r['pointerCount'] == 2), isTrue);
      final num zoom = valueOf('zoom')! as num;
      final String shown = zoom == zoom.roundToDouble()
          ? '${zoom.round()}'
          : '$zoom';
      expect(find.text(shown, findRichText: true), findsOneWidget);
    });

    testWidgets('a zoom slider writes only the scale: the node zooms into '
        'the middle of its parent and writes the offset back', (tester) async {
      // Laid out at the top left; the board's middle is (200, 200).
      await pump(tester, photo(at: NodeBox(0, 0, 200, 200)), variables: pose);
      setVariable('zoom', 2);
      await tester.pumpAndSettle();
      expect(poseOf(tester).scale, closeTo(2, 0.001));
      // The node's centre (100, 100) moves away from (200, 200) to (0, 0).
      expect(poseOf(tester).x, closeTo(-100, 0.1));
      expect(valueOf('panX'), closeTo(-100, 0.1));
      expect(valueOf('panY'), closeTo(-100, 0.1));
      expect(results['end']!.last['gesture'], 'variable');
    });

    testWidgets('a node with only zoomable: true zooms its content', (
      tester,
    ) async {
      final List<BaseNode> nodes = [
        board(['photo']),
        box('photo', NodeBox(100, 100, 200, 200))..zoomable = true,
      ];
      await pump(tester, nodes);
      expect(find.byType(ZoomableBox), findsNothing);
      final NodeTransformGesture gesture = tester.widget(
        find.byType(NodeTransformGesture),
      );
      expect(gesture.model, TransformGestureModel.zoomable);
      await tester.tapAt(const Offset(200, 200));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(const Offset(200, 200));
      await tester.pumpAndSettle();
      expect(poseOf(tester).scale, closeTo(2.5, 0.01));
    });

    testWidgets('a bound transform.x from data places the node', (
      tester,
    ) async {
      final List<BaseNode> nodes = photo(
        model: const TransformGestureModel(bounds: GestureBounds.none),
      );
      nodes[1].variables['transform.x'] = r'${offset}';
      await pump(
        tester,
        nodes,
        variables: [variable('offset', VariableType.decimal, 40)],
      );
      expect(poseOf(tester).x, 40);
    });

    testWidgets('handles follow a selection variable and a tap selects', (
      tester,
    ) async {
      final List<BaseNode> nodes = [
        board(['a', 'b']),
        box('a', NodeBox(20, 20, 100, 100))
          ..transformGesture = const TransformGestureModel(
            doubleTapScale: 0,
            handles: TransformHandlesModel(selectionVariable: 'selected'),
          ),
        box('b', NodeBox(220, 220, 100, 100))
          ..transformGesture = const TransformGestureModel(
            doubleTapScale: 0,
            handles: TransformHandlesModel(selectionVariable: 'selected'),
          ),
      ];
      await pump(
        tester,
        nodes,
        variables: [variable('selected', VariableType.text, 'a')],
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey('transform-handle-rotate')),
        findsOneWidget,
      );
      expect(
        tester.getCenter(find.byKey(const ValueKey('transform-handle-rotate'))),
        const Offset(70, -8),
      );
      await tester.tapAt(const Offset(270, 270));
      await tester.pump();
      await tester.pump();
      expect(valueOf('selected'), 'b');
      expect(
        tester.getCenter(find.byKey(const ValueKey('transform-handle-rotate'))),
        const Offset(270, 192),
      );
    });
  });

  testWidgets('pinch reactions read rotation and the pointer count', (
    tester,
  ) async {
    await pump(tester, [
      board(['pad']),
      box(
        'pad',
        NodeBox(100, 100, 200, 200),
        reactions: [capture(TriggerType.pinch, 'pinch')],
      ),
    ]);
    await pinch(tester, const Offset(200, 200), 40, 40, turnDegrees: 30);
    await tester.pumpAndSettle();
    final List<Map> pinches = results['pinch']!;
    expect(pinches.last['pointerCount'], 2);
    expect(pinches.last['totalRotation'], closeTo(30, 1));
    final double sum = pinches.fold(
      0.0,
      (a, r) => a + (r['rotation'] as num).toDouble(),
    );
    expect(sum, closeTo(30, 1));
  });

  group('multi-touch', () {
    testWidgets('two pucks drag at the same time, each its own way', (
      tester,
    ) async {
      DragModel puck(String name) => DragModel(
        release: DragRelease.stay,
        xVariable: '${name}X',
        yVariable: '${name}Y',
        physics: const PhysicsModel(fling: false),
      );
      await pump(
        tester,
        [
          board(['p1', 'p2']),
          box('p1', NodeBox(50, 150, 80, 80))..drag = puck('a'),
          box('p2', NodeBox(270, 150, 80, 80))..drag = puck('b'),
        ],
        variables: [
          for (final n in ['aX', 'aY', 'bX', 'bY'])
            variable(n, VariableType.decimal, 0),
        ],
      );
      final TestGesture left = await tester.startGesture(
        const Offset(90, 190),
        pointer: 21,
      );
      final TestGesture right = await tester.startGesture(
        const Offset(310, 190),
        pointer: 22,
      );
      for (int i = 0; i < 10; i++) {
        await left.moveBy(const Offset(0, -8));
        await right.moveBy(const Offset(0, 8));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await left.up();
      await right.up();
      await tester.pumpAndSettle();
      expect(valueOf('aY'), closeTo(-80, 0.5));
      expect(valueOf('bY'), closeTo(80, 0.5));
      expect(valueOf('aX'), 0);
      expect(valueOf('bX'), 0);
    });

    testWidgets('two sliders move at the same time', (tester) async {
      DragModel slider(String name) => DragModel(
        track: DragTrackModel(variable: name, min: 0, max: 100, x2: 200, y2: 0),
      );
      await pump(
        tester,
        [
          board(['s1', 's2']),
          box('s1', NodeBox(20, 80, 40, 40))..drag = slider('left'),
          box('s2', NodeBox(20, 280, 40, 40))..drag = slider('right'),
        ],
        variables: [
          variable('left', VariableType.decimal, 0),
          variable('right', VariableType.decimal, 0),
        ],
      );
      final TestGesture a = await tester.startGesture(
        const Offset(40, 100),
        pointer: 31,
      );
      final TestGesture b = await tester.startGesture(
        const Offset(40, 300),
        pointer: 32,
      );
      for (int i = 0; i < 10; i++) {
        await a.moveBy(const Offset(10, 0));
        await b.moveBy(const Offset(15, 0));
        await tester.pump(const Duration(milliseconds: 16));
        // Both move while both fingers are down.
        if (i == 9) {
          expect(valueOf('left'), closeTo(50, 1));
          expect(valueOf('right'), closeTo(75, 1));
        }
      }
      await a.up();
      await b.up();
      await tester.pump();
    });

    testWidgets('two stickers are moved by two fingers at once', (
      tester,
    ) async {
      const TransformGestureModel sticker = TransformGestureModel(
        bounds: GestureBounds.none,
        doubleTapScale: 0,
        physics: PhysicsModel(fling: false),
      );
      await pump(tester, [
        board(['a', 'b']),
        box('a', NodeBox(20, 20, 100, 100))..transformGesture = sticker,
        box('b', NodeBox(220, 220, 100, 100))..transformGesture = sticker,
      ]);
      final TestGesture g1 = await tester.startGesture(
        const Offset(70, 70),
        pointer: 41,
      );
      final TestGesture g2 = await tester.startGesture(
        const Offset(270, 270),
        pointer: 42,
      );
      for (int i = 0; i < 10; i++) {
        await g1.moveBy(const Offset(6, 0));
        await g2.moveBy(const Offset(0, -6));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await g1.up();
      await g2.up();
      await tester.pumpAndSettle();
      expect(poseOf(tester, 0).x, closeTo(60, 0.5));
      expect(poseOf(tester, 0).y, 0);
      expect(poseOf(tester, 1).y, closeTo(-60, 0.5));
      expect(poseOf(tester, 1).x, 0);
    });
  });
}
