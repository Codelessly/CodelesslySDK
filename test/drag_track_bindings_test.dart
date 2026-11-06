import 'dart:math' as math;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/functions/action_chain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Drag tracks bound to values they can't write: Lamplight's knob shows the
/// selected lamp's brightness (`track.value` over the `lamps` list) and its
/// `changed` reaction writes the lamp back; a list of lamps each turns its
/// own item's value; a playhead's track follows its parent's width.
void main() {
  late CodelesslyContext codelesslyContext;

  VariableData variable(String name, VariableType type, Object value) =>
      VariableData(id: name, name: name, type: type, value: value);

  Future<void> pump(
    WidgetTester tester,
    List<BaseNode> nodes, {
    required bool runtime,
    required List<VariableData> variables,
    double width = 300,
  }) async {
    final registry = NodeRegistry()
      ..setNodes({for (final node in nodes) node.id: node});
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    codelesslyContext = CodelesslyContext.empty().copyWith(
      variables: {for (final v in variables) v.id: Observable(v)},
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
                  width: width,
                  child: Builder(
                    builder: (context) => manager.buildWidgetFromNode(
                      nodes.first,
                      context,
                      settings: WidgetBuildSettings(
                        debugLabel: runtime ? 'runtime' : 'design canvas',
                        isPreview: !runtime,
                        withReactions: runtime,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    // A track measuring its parent rebuilds once laid out.
    await tester.pump();
    expect(tester.takeException(), isNull);
  }

  List<Map<String, Object>> lampsValue() => [
    {'id': 'l1', 'b': 50},
    {'id': 'l2', 'b': 0},
  ];

  Reaction writeLamp(String id) => Reaction(
    trigger: TriggerModel(type: TriggerType.changed),
    action: SetVariableAction(
      variable: VariableData(id: 'lamps', name: 'lamps', type: VariableType.list),
      newValue:
          '\${= updateWhere(lamps, "id", $id, {b: round(result.value)})}',
    ),
  );

  /// The brightness knob: a 300x300 box with a 120px body that turns
  /// from -135° to 135°, bound to the selected lamp's brightness.
  List<BaseNode> knob() => [
    FrameNode(
      id: 'box',
      name: 'Knob',
      basicBoxLocal: NodeBox(0, 0, 300, 300),
      children: ['body'],
    )..parentID = kRootNode,
    FrameNode(
        id: 'body',
        name: 'Knob body',
        basicBoxLocal: NodeBox(90, 90, 120, 120),
        horizontalFit: SizeFit.fixed,
        verticalFit: SizeFit.fixed,
        children: ['dot'],
        reactions: [writeLamp('sel')],
      )
      ..variables = {'track.value': r'${= find(lamps, "id", sel).b}'}
      ..parentID = 'box'
      ..drag = const DragModel(
        track: DragTrackModel(
          shape: DragTrackShape.arc,
          min: 0,
          max: 100,
          step: 1,
          input: DragTrackInput.both,
          pixelsPerRange: 200,
          hitArea: DragTrackHitArea.parent,
        ),
      ),
    TextNode(
      id: 'dot',
      name: 'dot',
      basicBoxLocal: NodeBox(50, 0, 20, 20),
      data: 'P',
      textMixedProps: [StartEndProp(start: 0, end: 1, fontSize: 12)],
    )..parentID = 'body',
  ];

  double rotationOf(WidgetTester tester, [int index = 0]) {
    final RenderBox box = tester.renderObject(
      find.text('P', findRichText: true).at(index),
    );
    final Matrix4 m = box.getTransformTo(null);
    final Offset a = MatrixUtils.transformPoint(m, Offset.zero);
    final Offset b = MatrixUtils.transformPoint(m, const Offset(1, 0));
    return (b - a).direction * 180 / math.pi;
  }

  Object? lamp(String id) =>
      ((codelesslyContext.findVariableByName('lamps')!.value.getValue()!
                  as List)
              .firstWhere((l) => (l as Map)['id'] == id)
          as Map)['b'];

  final List<VariableData> lampVariables = [
    variable('lamps', VariableType.list, lampsValue()),
    variable('sel', VariableType.text, 'l1'),
  ];

  testWidgets('the design canvas draws a value-bound knob at its binding', (
    tester,
  ) async {
    await pump(tester, knob(), runtime: false, variables: lampVariables);
    // 50 of 0..100: upright.
    expect(rotationOf(tester), closeTo(0, 0.5));
  });

  testWidgets(
    'dragging a value-bound knob runs its reactions, which write the lamp',
    (tester) async {
      await pump(tester, knob(), runtime: true, variables: lampVariables);
      expect(rotationOf(tester), closeTo(0, 0.5));
      // From the box's corner, outside the body: up and right by 50 each.
      final gesture = await tester.startGesture(const Offset(15, 285));
      for (int i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(5, -5));
        await tester.pump();
      }
      // dx - dy = 100 of 200: +50.
      expect(lamp('l1'), 100);
      await gesture.up();
      await tester.pumpAndSettle();
      // Settled at the bound value: the top of the arc.
      expect(rotationOf(tester), closeTo(135, 0.5));
      // The lamp changing elsewhere moves the knob.
      final Observable<VariableData> lamps = codelesslyContext
          .findVariableByName('lamps')!;
      lamps.value = lamps.value.copyWith(
        value: [
          {'id': 'l1', 'b': 0},
          {'id': 'l2', 'b': 0},
        ],
      );
      await tester.pump();
      expect(rotationOf(tester), closeTo(-135, 0.5));
    },
  );

  testWidgets('each item of a list turns by its own item value', (
    tester,
  ) async {
    final List<BaseNode> nodes = [
      ListViewNode(
        id: 'list',
        name: 'Lamps',
        basicBoxLocal: NodeBox(0, 0, 300, 240),
        isScrollable: false,
        verticalFit: SizeFit.shrinkWrap,
        properties: ListViewProperties(),
        variables: {'data': r'${lamps}'},
        children: ['row'],
      )..parentID = kRootNode,
      FrameNode(
        id: 'row',
        name: 'Row',
        basicBoxLocal: NodeBox(0, 0, 300, 120),
        children: ['knobBody'],
      )..parentID = 'list',
      FrameNode(
          id: 'knobBody',
          name: 'Knob body',
          basicBoxLocal: NodeBox(90, 0, 120, 120),
          horizontalFit: SizeFit.fixed,
          verticalFit: SizeFit.fixed,
          children: ['dot'],
          reactions: [writeLamp('item.id')],
        )
        ..variables = {'track.value': r'${item.b}'}
        ..parentID = 'row'
        ..drag = const DragModel(
          track: DragTrackModel(
            shape: DragTrackShape.arc,
            min: 0,
            max: 100,
            step: 1,
            input: DragTrackInput.vertical,
            pixelsPerRange: 200,
          ),
        ),
      TextNode(
        id: 'dot',
        name: 'dot',
        basicBoxLocal: NodeBox(50, 0, 20, 20),
        data: 'P',
        textMixedProps: [StartEndProp(start: 0, end: 1, fontSize: 12)],
      )..parentID = 'knobBody',
    ];
    await pump(tester, nodes, runtime: true, variables: lampVariables);
    expect(rotationOf(tester, 0), closeTo(0, 0.5));
    expect(rotationOf(tester, 1), closeTo(-135, 0.5));
    // Turn the second lamp's knob up by a quarter of its range.
    final gesture = await tester.startGesture(const Offset(150, 180));
    for (int i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(0, -5));
      await tester.pump();
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(lamp('l2'), 25);
    expect(lamp('l1'), 50);
    expect(rotationOf(tester, 1), closeTo(-135 + 270 * 0.25, 0.5));
  });

  /// A 14px playhead at the left of a [width] wide body whose track runs
  /// to the body's right edge, bound with `track.x2`.
  List<BaseNode> playhead({required Map<String, String> variables, DragTrackUnits units = DragTrackUnits.pixels, double x2 = 286}) => [
    FrameNode(
      id: 'body',
      name: 'Cascade body',
      basicBoxLocal: NodeBox(0, 0, 300, 100),
      horizontalFit: SizeFit.expanded,
      children: ['head'],
    )..parentID = kRootNode,
    FrameNode(
        id: 'head',
        name: 'Playhead',
        basicBoxLocal: NodeBox(0, 0, 14, 100),
        horizontalFit: SizeFit.fixed,
        verticalFit: SizeFit.fixed,
        children: ['dot'],
      )
      ..variables = variables
      ..parentID = 'body'
      ..drag = DragModel(
        track: DragTrackModel(
          variable: 't',
          min: 0,
          max: 1,
          x2: x2,
          y2: 0,
          units: units,
          jumpOnTap: true,
          hitArea: DragTrackHitArea.parent,
          wheel: false,
        ),
      ),
    TextNode(
      id: 'dot',
      name: 'dot',
      basicBoxLocal: NodeBox(0, 0, 14, 14),
      data: 'P',
      textMixedProps: [StartEndProp(start: 0, end: 1, fontSize: 12)],
    )..parentID = 'head',
  ];

  double headX(WidgetTester tester) =>
      tester.getTopLeft(find.text('P', findRichText: true)).dx;

  testWidgets('the design canvas draws a parent-unit playhead at its value', (
    tester,
  ) async {
    await pump(
      tester,
      playhead(variables: {}, units: DragTrackUnits.parent, x2: 1),
      runtime: false,
      width: 600,
      variables: [variable('t', VariableType.decimal, 0.25)],
    );
    expect(headX(tester), closeTo(150, 1));
  });

  testWidgets('scrubbing a playing playhead pauses the animation', (
    tester,
  ) async {
    await pump(
      tester,
      playhead(variables: {}, units: DragTrackUnits.parent, x2: 1),
      runtime: true,
      width: 600,
      variables: [variable('t', VariableType.decimal, 0)],
    );
    final ValueNotifier<VariableData> t = codelesslyContext
        .findVariableByName('t')!;
    VariableAnimator.play(t, from: 0, to: 1, duration: const Duration(seconds: 2));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(VariableAnimator.isPlaying(t), isTrue);
    await tester.tapAt(const Offset(450, 60));
    await tester.pump();
    expect(VariableAnimator.isPlaying(t), isFalse);
    expect(VariableAnimator.isAnimating(t), isTrue);
    final Object? scrubbed = t.value.getValue();
    await tester.pump(const Duration(seconds: 1));
    expect(t.value.getValue(), scrubbed);
    expect((scrubbed! as num).toDouble(), closeTo(0.75, 0.02));
    VariableAnimator.stop(t);
  });

  for (final (String name, List<BaseNode> Function() nodes) in [
    (
      'a bound x2',
      () => playhead(variables: {'track.x2': r'${= parent.width - 14}'}),
    ),
    (
      'units parent',
      () => playhead(variables: {}, units: DragTrackUnits.parent, x2: 1),
    ),
  ]) {
    testWidgets('a playhead with $name scrubs across a body of any width', (
      tester,
    ) async {
      await pump(
        tester,
        nodes(),
        runtime: true,
        width: 600,
        variables: [variable('t', VariableType.decimal, 0.5)],
      );
      final double span = name == 'units parent' ? 600 : 586;
      expect(headX(tester), closeTo(span * 0.5, 1));
      // Scrub from anywhere across the body: a press at 3/4 jumps there.
      await tester.tapAt(Offset(span * 0.75 + 7, 60));
      await tester.pump(const Duration(seconds: 1));
      final double t =
          codelesslyContext.findVariableByName('t')!.value.getValue()!
              as double;
      expect(t, closeTo(0.75, 0.02));
    });
  }
}
