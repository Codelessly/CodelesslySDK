import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Drag tracks and reorder handles through the node pipeline: a knob cap
/// node drawn at its variable's value on the design canvas and dragged at
/// runtime, and a data list whose rows move by their handle.
void main() {
  late CodelesslyContext codelesslyContext;

  VariableData variable(String name, VariableType type, Object value) =>
      VariableData(id: name, name: name, type: type, value: value);

  Future<void> pump(
    WidgetTester tester,
    List<BaseNode> nodes, {
    required bool runtime,
    required List<VariableData> variables,
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
            child: Align(
              alignment: Alignment.topLeft,
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
    );
    expect(tester.takeException(), isNull);
  }

  List<BaseNode> knob() => [
    FrameNode(
      id: 'plate',
      name: 'plate',
      basicBoxLocal: NodeBox(0, 0, 300, 300),
      children: ['cap'],
    )..parentID = kRootNode,
    FrameNode(
        id: 'cap',
        name: 'cap',
        basicBoxLocal: NodeBox(90, 90, 120, 120),
        horizontalFit: SizeFit.fixed,
        verticalFit: SizeFit.fixed,
        children: ['pointer'],
      )
      ..parentID = 'plate'
      ..drag = const DragModel(
        track: DragTrackModel(
          shape: DragTrackShape.arc,
          variable: 'bpm',
          min: 30,
          max: 250,
          step: 1,
          defaultValue: 120,
        ),
      ),
    TextNode(
      id: 'pointer',
      name: 'pointer',
      basicBoxLocal: NodeBox(50, 0, 20, 20),
      data: 'P',
      textMixedProps: [StartEndProp(start: 0, end: 1, fontSize: 12)],
    )..parentID = 'cap',
  ];

  double rotationOf(WidgetTester tester) {
    final RenderBox box = tester.renderObject(
      find.text('P', findRichText: true),
    );
    final Matrix4 m = box.getTransformTo(null);
    final Offset a = MatrixUtils.transformPoint(m, Offset.zero);
    final Offset b = MatrixUtils.transformPoint(m, const Offset(1, 0));
    return (b - a).direction * 180 / 3.141592653589793;
  }

  testWidgets('the design canvas draws a knob at its value', (tester) async {
    await pump(
      tester,
      knob(),
      runtime: false,
      variables: [variable('bpm', VariableType.integer, 250)],
    );
    expect(rotationOf(tester), closeTo(135, 0.5));
  });

  testWidgets('at runtime dragging the knob writes its variable', (
    tester,
  ) async {
    await pump(
      tester,
      knob(),
      runtime: true,
      variables: [variable('bpm', VariableType.integer, 140)],
    );
    expect(rotationOf(tester), closeTo(0, 0.5));
    // Drag from the left of the cap's centre (150, 150) round to the top.
    final gesture = await tester.startGesture(const Offset(110, 150));
    for (double a = -90; a <= 0; a += 10) {
      final double r = a * 3.141592653589793 / 180;
      await gesture.moveTo(Offset(150 + 40 * _sin(r), 150 - 40 * _cos(r)));
    }
    await gesture.up();
    await tester.pump(const Duration(seconds: 1));
    final Object? bpm = codelesslyContext
        .findVariableByName('bpm')!
        .value
        .getValue();
    // A quarter turn of the 270° sweep: +73 BPM.
    expect(bpm, inInclusiveRange(205, 216));
    expect(rotationOf(tester), greaterThan(60));
  });

  List<BaseNode> songs() => [
    ListViewNode(
      id: 'list',
      name: 'list',
      basicBoxLocal: NodeBox(0, 0, 300, 180),
      isScrollable: false,
      verticalFit: SizeFit.shrinkWrap,
      properties: ListViewProperties(),
      variables: {'data': r'${songs}'},
      children: ['row'],
    )..parentID = kRootNode,
    RowColumnNode(
      id: 'row',
      name: 'row',
      basicBoxLocal: NodeBox(0, 0, 300, 60),
      rowColumnType: RowColumnType.row,
      children: ['handle', 'title'],
    )..parentID = 'list',
    FrameNode(
        id: 'handle',
        name: 'handle',
        basicBoxLocal: NodeBox(0, 0, 40, 60),
        horizontalFit: SizeFit.fixed,
        verticalFit: SizeFit.fixed,
        reactions: [
          Reaction(
            name: 'Store the new order',
            trigger: TriggerModel(type: TriggerType.reorder),
            action: SetVariableAction(
              variable: VariableData(
                id: 'songs',
                name: 'songs',
                type: VariableType.list,
              ),
              newValue: r'${= move(songs, result.from, result.to)}',
            ),
          ),
        ],
        children: [],
      )
      ..parentID = 'row'
      ..drag = const DragModel(reorder: true),
    TextNode(
      id: 'title',
      name: 'title',
      basicBoxLocal: NodeBox(40, 0, 200, 24),
      data: r'${item.title}',
      textMixedProps: [StartEndProp(start: 0, end: 13, fontSize: 16)],
    )..parentID = 'row',
  ];

  testWidgets('a row dragged by its handle moves and the order is stored', (
    tester,
  ) async {
    await pump(
      tester,
      songs(),
      runtime: true,
      variables: [
        variable('songs', VariableType.list, [
          {'id': 'a', 'title': 'Superstition'},
          {'id': 'b', 'title': 'Take Five'},
          {'id': 'c', 'title': 'Money'},
        ]),
      ],
    );
    expect(find.text('Take Five', findRichText: true), findsOne);
    // Drag the first row's handle below the third row.
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(ReorderableDragStartListener).first),
    );
    await tester.pump(const Duration(milliseconds: 50));
    for (int i = 0; i < 20; i++) {
      await gesture.moveBy(const Offset(0, 10));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();
    final List titles = [
      for (final s
          in codelesslyContext.findVariableByName('songs')!.value.getValue()!
              as List)
        (s as Map)['title'],
    ];
    expect(titles, ['Take Five', 'Money', 'Superstition']);
  });
}

double _sin(double r) => r == 0 ? 0 : Offset.fromDirection(r).dy;
double _cos(double r) => Offset.fromDirection(r).dx;
