import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/functions/action_chain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Pins on a floor plan: an overlay list whose items are placed by their
/// `positionX` / `positionY` variables, and a click that reads where it
/// landed through `${event}`.
void main() {
  RectangleNode pin({Map<String, String> variables = const {}}) =>
      RectangleNode.fromJson({
        ...RectangleNode(
          id: 'pin',
          name: 'pin',
          basicBoxLocal: NodeBox(0, 0, 20, 30),
          // The pin's tip (bottom center) sits on the point.
          alignment: AlignmentModel.bottomCenter,
        ).toJson(),
        'variables': variables,
      })..parentID = 'pins';

  ListViewNode pins({bool overlay = true}) => ListViewNode.fromJson({
    ...ListViewNode(
      id: 'pins',
      name: 'pins',
      basicBoxLocal: NodeBox(0, 0, 400, 200),
      properties: ListViewProperties(overlay: overlay),
      children: ['pin'],
    ).toJson(),
    'variables': {'data': r'${points}'},
  })..parentID = kRootNode;

  Observable<VariableData> points(List<Map<String, Object>> value) =>
      Observable(
        VariableData(
          id: 'points',
          name: 'points',
          type: VariableType.list,
          value: value,
        ),
      );

  Future<void> pump(
    WidgetTester tester,
    BaseNode root,
    List<BaseNode> nodes,
    CodelesslyContext codelesslyContext,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final registry = NodeRegistry()
      ..setNodes({
        for (final node in [root, ...nodes]) node.id: node,
      });
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: codelesslyContext,
        child: MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
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
    );
    expect(tester.takeException(), isNull);
  }

  Finder pinBoxes() =>
      find.byKey(const ValueKey('Rectangle Transformer of pin [pin]'));

  testWidgets('an overlay list places each item at its data position', (
    tester,
  ) async {
    final data = points([
      {'x': 0.25, 'y': 0.5},
      {'x': 0.75, 'y': 1.0},
      {'x': 0.0, 'y': 0.2},
    ]);
    await pump(
      tester,
      pins(),
      [
        pin(
          variables: {
            'positionX': r'${item.x}',
            'positionY': r'${item.y}',
          },
        ),
      ],
      CodelesslyContext.empty()..variables['points'] = data,
    );

    final List<Rect> boxes = [
      for (final element in pinBoxes().evaluate())
        tester.getRect(find.byWidget(element.widget)),
    ];
    expect(boxes, hasLength(3));
    // Bottom center of each pin on its point of the 400x200 list.
    expect(boxes[0].bottomCenter, const Offset(100, 100));
    expect(boxes[1].bottomCenter, const Offset(300, 200));
    // Near an edge the pin hangs out instead of being pushed inside.
    expect(boxes[2].bottomCenter, const Offset(0, 40));
    expect(boxes[0].size, const Size(20, 30));

    // New data moves and adds pins.
    data.set(
      data.value.copyWith(
        value: [
          {'x': 0.5, 'y': 0.5},
          {'x': 0.1, 'y': 0.9},
          {'x': 0.9, 'y': 0.1},
          {'x': 0.2, 'y': 0.3},
        ],
      ),
    );
    await tester.pump();
    expect(pinBoxes(), findsNWidgets(4));
    expect(
      tester.getRect(pinBoxes().first).bottomCenter,
      const Offset(200, 100),
    );
  });

  testWidgets('formulas can place items', (tester) async {
    await pump(
      tester,
      pins(),
      [
        pin(
          variables: {
            'positionX': r'${= item.x / 100}',
            'positionY': r'${= 1 - item.y / 100}',
          },
        ),
      ],
      CodelesslyContext.empty()
        ..variables['points'] = points([
          {'x': 50, 'y': 25},
        ]),
    );
    expect(tester.getRect(pinBoxes()).bottomCenter, const Offset(200, 150));
  });

  testWidgets('without position variables items keep their design place', (
    tester,
  ) async {
    await pump(
      tester,
      pins(),
      [pin()],
      CodelesslyContext.empty()
        ..variables['points'] = points([
          {'x': 0.5, 'y': 0.5},
          {'x': 0.1, 'y': 0.1},
        ]),
    );
    final List<Rect> boxes = [
      for (final element in pinBoxes().evaluate())
        tester.getRect(find.byWidget(element.widget)),
    ];
    // Both stacked where alignment bottom center puts them.
    expect(boxes, hasLength(2));
    expect(boxes[0], boxes[1]);
    expect(boxes[0].bottomCenter, const Offset(200, 200));
  });

  testWidgets('a scrolling list ignores position variables', (tester) async {
    await pump(
      tester,
      pins(overlay: false),
      [
        pin(
          variables: {
            'positionX': r'${item.x}',
            'positionY': r'${item.y}',
          },
        ),
      ],
      CodelesslyContext.empty()
        ..variables['points'] = points([
          {'x': 0.5, 'y': 0.5},
          {'x': 0.5, 'y': 0.5},
        ]),
    );
    final List<Rect> boxes = [
      for (final element in pinBoxes().evaluate())
        tester.getRect(find.byWidget(element.widget)),
    ];
    expect(boxes, hasLength(2));
    expect(boxes[1].top, greaterThanOrEqualTo(boxes[0].bottom));
  });

  testWidgets('a frame child binds its position too', (tester) async {
    final FrameNode frame = FrameNode(
      id: 'frame',
      name: 'frame',
      basicBoxLocal: NodeBox(0, 0, 400, 200),
      children: ['dot'],
    )..parentID = kRootNode;
    final RectangleNode dot = RectangleNode.fromJson({
      ...RectangleNode(
        id: 'dot',
        name: 'dot',
        basicBoxLocal: NodeBox(10, 10, 10, 10),
      ).toJson(),
      'variables': {'positionX': r'${spot}', 'positionY': r'${= 0.5}'},
    })..parentID = 'frame';
    final Observable<VariableData> spot = Observable(
      VariableData(
        id: 'spot',
        name: 'spot',
        type: VariableType.decimal,
        value: 0.25,
      ),
    );
    await pump(
      tester,
      frame,
      [dot],
      CodelesslyContext.empty()..variables['spot'] = spot,
    );
    Rect box() => tester.getRect(
      find.byKey(const ValueKey('Rectangle Transformer of dot [dot]')),
    );
    // No alignment: the dot's center sits on the point.
    expect(box().center, const Offset(100, 100));
    spot.set(spot.value.copyWith(value: 0.5));
    await tester.pump();
    expect(box().center, const Offset(200, 100));
  });

  testWidgets('a tap on a frame under an overlay list adds a pin there', (
    tester,
  ) async {
    final FrameNode plan = FrameNode.fromJson({
      ...FrameNode(
        id: 'plan',
        name: 'plan',
        basicBoxLocal: NodeBox(0, 0, 400, 200),
        children: ['pins'],
      ).toJson(),
      'reactions': [
        Reaction(
          name: 'drop',
          trigger: TriggerModel(type: TriggerType.click),
          action: SetVariableAction(
            variable: VariableData(
              id: 'points',
              name: 'points',
              type: VariableType.list,
            ),
            listOperation: ListOperation.add,
            newValue: r'{"x": ${event.x}, "y": ${event.y}}',
          ),
        ).toJson(),
      ],
    })..parentID = kRootNode;
    final ListViewNode list = pins()
      ..parentID = 'plan'
      ..edgePins = const EdgePinsModel(left: 0, top: 0, right: 0, bottom: 0);
    final data = points([
      {'x': 0.5, 'y': 0.5},
    ]);
    await pump(
      tester,
      plan,
      [
        list,
        pin(
          variables: {
            'positionX': r'${item.x}',
            'positionY': r'${item.y}',
          },
        ),
      ],
      CodelesslyContext.empty()..variables['points'] = data,
    );
    expect(pinBoxes(), findsOneWidget);
    await tester.tapAt(const Offset(100, 150));
    await tester.pumpAndSettle();
    expect(data.value.getValue(), [
      {'x': 0.5, 'y': 0.5},
      {'x': 0.25, 'y': 0.75},
    ]);
    expect(pinBoxes(), findsNWidgets(2));
  });

  group('tap event', () {
    test('describes where a tap landed', () {
      expect(
        FunctionsRepository.tapEvent(const Offset(50, 30), const Size(200, 60)),
        {
          'x': 0.25,
          'y': 0.5,
          'localX': 50.0,
          'localY': 30.0,
          'width': 200.0,
          'height': 60.0,
        },
      );
    });

    test('is the chain\'s event variable', () {
      String? read(String path) => ActionChain.run(
        () => PropertyValueDelegate.substituteVariables(
          path,
          scopedValues: ScopedValues.preview(variables: {}),
          nullSubstitutionMode: NullSubstitutionMode.emptyString,
        ),
        event: const {'x': 0.25, 'y': 0.5},
      );
      expect(read(r'${event.x}'), '0.25');
      expect(read(r'${= event.y * 2}'), '1');
      // Outside a chain with an event it is empty.
      expect(
        PropertyValueDelegate.substituteVariables(
          r'${event.x}',
          scopedValues: ScopedValues.preview(variables: {}),
          nullSubstitutionMode: NullSubstitutionMode.emptyString,
        ),
        '',
      );
    });

    testWidgets('a click sets a variable from where it landed', (
      tester,
    ) async {
      final RectangleNode plan = RectangleNode.fromJson({
        ...RectangleNode(
          id: 'plan',
          name: 'plan',
          basicBoxLocal: NodeBox(0, 0, 400, 200),
          reactions: [
            Reaction(
              name: 'place',
              trigger: TriggerModel(type: TriggerType.click),
              action: SetVariableAction(
                variable: VariableData(
                  id: 'spot',
                  name: 'spot',
                  type: VariableType.map,
                ),
                newValue: r'{"x": ${event.x}, "y": ${event.y}}',
              ),
            ),
          ],
        ).toJson(),
      })..parentID = kRootNode;
      final Observable<VariableData> spot = Observable(
        VariableData(id: 'spot', name: 'spot', type: VariableType.map),
      );
      await pump(
        tester,
        plan,
        [],
        CodelesslyContext.empty()..variables['spot'] = spot,
      );
      await tester.tapAt(const Offset(100, 150));
      await tester.pumpAndSettle();
      expect(spot.value.getValue(), {'x': 0.25, 'y': 0.75});
    });
  });
}
