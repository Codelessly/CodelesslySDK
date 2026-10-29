import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:codelessly_sdk/src/functions/action_chain.dart';
import 'package:provider/provider.dart';

/// A floor plan drawn from data: a stacked list whose items are placed,
/// sized and rotated by their item's fields, and dragged by drag reactions.
void main() {
  test('Centered stack survives JSON and is off by default', () {
    final props = ListViewProperties(stacked: true);
    expect(ListViewProperties.fromJson(props.toJson()).stacked, isTrue);
    expect(ListViewProperties().toJson().containsKey('stacked'), isFalse);
    expect(props.copyWith().stacked, isTrue);
  });

  testWidgets('Centered stack overlaps with the first item on top', (
    tester,
  ) async {
    final values = ['a', 'b', 'c'];
    final taps = <String>[];
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 200,
            height: 200,
            child: StackedItems(
              itemCount: values.length,
              itemBuilder: (context, index) => GestureDetector(
                onTap: () => taps.add(values[index]),
                child: Container(
                  width: 100,
                  height: 100,
                  color: const Color(0xFF000000),
                  child: Text(values[index]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final Offset a = tester.getTopLeft(find.text('a'));
    expect(tester.getTopLeft(find.text('b')), a);
    expect(tester.getTopLeft(find.text('c')), a);
    expect(
      a,
      tester.getTopLeft(find.byType(StackedItems)) + const Offset(50, 0),
    );
    await tester.tap(find.text('a'));
    expect(taps, ['a']);
  });

  final List<Map<String, Object?>> plan = [
    {'id': 'bed', 'x': 0, 'y': 0, 'w': 6, 'd': 5, 'rot': 0},
    {'id': 'sofa', 'x': 10, 'y': 4.5, 'w': 6, 'd': 3, 'rot': 90},
  ];

  ({NodeRegistry registry, ListViewNode list, RectangleNode item}) build({
    List<Reaction> reactions = const [],
  }) {
    final RectangleNode item = RectangleNode.fromJson({
      ...RectangleNode(
        id: 'item',
        name: 'Plan item',
        basicBoxLocal: NodeBox(0, 0, 20, 20),
        fills: [PaintModel.solid(id: 'f', color: ColorRGB.fromHex('#EBDCC3'))],
        reactions: reactions,
      ).toJson(),
      'variables': {
        'x': r'${= item.x * scale}',
        'y': r'${= item.y * scale}',
        'width': r'${= item.w * scale}',
        'height': r'${= item.d * scale}',
        'rotation': r'${item.rot}',
      },
    });
    final ListViewNode list = ListViewNode(
      id: 'plan',
      name: 'Plan',
      basicBoxLocal: NodeBox(0, 0, 400, 200),
      padding: const EdgeInsetsModel.all(10),
      properties: ListViewProperties(layout: ListLayout.stack),
      children: ['item'],
      variables: {'data': r'${plan}'},
    );
    item.parentID = list.id;
    list.parentID = kRootNode;
    final registry = NodeRegistry()..setNodes({list.id: list, item.id: item});
    return (registry: registry, list: list, item: item);
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
      ..variables['plan'] = Observable(
        VariableData(
          id: 'plan',
          name: 'plan',
          type: VariableType.list,
          value: plan,
        ),
      )
      ..variables['scale'] = Observable(
        VariableData(
          id: 'scale',
          name: 'scale',
          type: VariableType.decimal,
          value: 10.0,
        ),
      );
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: codelesslyContext,
        child: MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 400,
              height: 200,
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

  Finder items() => find.byWidgetPredicate(
    (w) => w is Positioned && '${w.key}'.contains('stacked item'),
  );

  testWidgets('items are placed and sized by their item fields', (
    tester,
  ) async {
    final t = build();
    await pump(tester, t.registry, t.list);

    expect(items(), findsNWidgets(2));
    final List<Positioned> placed = tester
        .widgetList<Positioned>(items())
        .toList();
    expect([placed[0].left, placed[0].top], [0, 0]);
    expect([placed[1].left, placed[1].top], [100, 45]);
    // Inside the list's 10 px padding.
    expect(tester.getTopLeft(items().at(1)), const Offset(110, 55));
    expect(tester.getSize(items().at(0)), const Size(60, 50));
  });

  testWidgets('a bound rotation turns the item', (tester) async {
    final t = build();
    await pump(tester, t.registry, t.list);

    final Iterable<Transform> turned = tester
        .widgetList<Transform>(find.byType(Transform))
        .where((tr) => tr.transform.getRotation().entry(0, 1) != 0);
    // Only the sofa (rot 90) is rotated.
    expect(turned, hasLength(1));
    expect(
      turned.single.transform.getRotation().entry(0, 1),
      closeTo(-1, 1e-9),
    );
  });

  testWidgets('moving an item when its data changes', (tester) async {
    final t = build();
    final codelesslyContext = await pump(tester, t.registry, t.list);

    final Observable<VariableData> v = codelesslyContext.variables['plan']!;
    v.set(
      v.value.copyWith(
        value: [
          {...plan[0], 'x': 4},
          plan[1],
        ],
      ),
    );
    await tester.pump();
    expect(tester.widgetList<Positioned>(items()).first.left, 40);
  });

  testWidgets('drag reactions get deltas in result', (tester) async {
    final List<Map> drags = [];
    final List<Map> ends = [];
    final t = build(
      reactions: [
        Reaction(
          action: CallFunctionAction(name: 'drag'),
          trigger: TriggerModel(type: TriggerType.drag),
        ),
        Reaction(
          action: CallFunctionAction(name: 'end'),
          trigger: TriggerModel(type: TriggerType.dragEnd),
        ),
      ],
    );
    await pump(
      tester,
      t.registry,
      t.list,
      functions: {
        'drag': (context, reference, params) =>
            drags.add(ActionChain.current!.result! as Map),
        'end': (context, reference, params) =>
            ends.add(ActionChain.current!.result! as Map),
      },
    );

    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(items().first),
    );
    await gesture.moveBy(const Offset(30, 0));
    await gesture.moveBy(const Offset(10, 5));
    await gesture.up();
    await tester.pump();

    expect(drags, isNotEmpty);
    expect(drags.last['dx'], 40 - drags.first['dx'] + drags.first['deltaX']);
    expect(drags.last['deltaX'], 10);
    expect(drags.last['deltaY'], 5);
    expect(ends.single['dy'], drags.last['dy']);
  });

  testWidgets('a bound x/y moves a node in a freeform parent', (tester) async {
    final RectangleNode pin = RectangleNode.fromJson({
      ...RectangleNode(
        id: 'pin',
        name: 'Pin',
        basicBoxLocal: NodeBox(20, 20, 10, 10),
      ).toJson(),
      'variables': {'x': r'${= scale * 3}', 'y': r'${= 5}'},
    });
    final FrameNode frame = FrameNode(
      id: 'frame',
      name: 'Map',
      basicBoxLocal: NodeBox(0, 0, 400, 200),
      children: ['pin'],
    );
    pin.parentID = frame.id;
    frame.parentID = kRootNode;
    final registry = NodeRegistry()..setNodes({frame.id: frame, pin.id: pin});
    await pump(tester, registry, frame);

    final Finder translated = find.byWidgetPredicate(
      (w) => w is Transform && w.transform.getTranslation().x != 0,
    );
    expect(translated, findsOneWidget);
    final translation = tester
        .widget<Transform>(translated)
        .transform
        .getTranslation();
    // Design place (20, 20) to bound (30, 5).
    expect([translation.x, translation.y], [10, -15]);
  });

  testWidgets('a bound size sizes a node pinned in a freeform parent', (
    tester,
  ) async {
    final RectangleNode bar = RectangleNode.fromJson({
      ...RectangleNode(
        id: 'bar',
        name: 'Meter fill',
        basicBoxLocal: NodeBox(0, 0, 300, 8),
        positioningMode: PositioningMode.pin,
        edgePins: const EdgePinsModel(
          left: 0,
          top: 0,
          right: null,
          bottom: null,
        ),
      ).toJson(),
      'variables': {'width': r'${= scale * 12}'},
    });
    final FrameNode frame = FrameNode(
      id: 'frame',
      name: 'Meter',
      basicBoxLocal: NodeBox(0, 0, 400, 200),
      children: ['bar'],
    );
    bar.parentID = frame.id;
    frame.parentID = kRootNode;
    final registry = NodeRegistry()..setNodes({frame.id: frame, bar.id: bar});
    await pump(tester, registry, frame);

    final Finder child = find.byWidgetPredicate(
      (w) => w is FreeformChild && '${w.key}'.contains('[bar]'),
    );
    expect(tester.getSize(child), const Size(120, 8));
  });

  testWidgets('a nested list reads its outer item as parent', (tester) async {
    // Homes, each with its own scale and placements.
    final RectangleNode dot = RectangleNode.fromJson({
      ...RectangleNode(
        id: 'dot',
        name: 'Dot',
        basicBoxLocal: NodeBox(0, 0, 4, 4),
      ).toJson(),
      'variables': {
        'x': r'${= item.x * parent.item.scale}',
        'y': r'${= parent.index * 1}',
      },
    });
    final ListViewNode inner = ListViewNode(
      id: 'inner',
      name: 'Inner',
      basicBoxLocal: NodeBox(0, 0, 200, 40),
      properties: ListViewProperties(layout: ListLayout.stack),
      children: ['dot'],
      variables: {'data': r'${item.placements}'},
    );
    final ListViewNode outer = ListViewNode(
      id: 'outer',
      name: 'Outer',
      basicBoxLocal: NodeBox(0, 0, 200, 200),
      properties: ListViewProperties(itemExtent: 40),
      children: ['inner'],
      variables: {'data': r'${homes}'},
    );
    dot.parentID = inner.id;
    inner.parentID = outer.id;
    outer.parentID = kRootNode;
    final registry = NodeRegistry()
      ..setNodes({outer.id: outer, inner.id: inner, dot.id: dot});
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    final CodelesslyContext codelesslyContext = CodelesslyContext.empty()
      ..variables['homes'] = Observable(
        VariableData(
          id: 'homes',
          name: 'homes',
          type: VariableType.list,
          value: [
            {
              'scale': 10,
              'placements': [
                {'x': 1},
                {'x': 2},
              ],
            },
            {
              'scale': 20,
              'placements': [
                {'x': 1},
              ],
            },
          ],
        ),
      );
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: codelesslyContext,
        child: MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 200,
              height: 200,
              child: Builder(
                builder: (context) => manager.buildWidgetFromNode(
                  outer,
                  context,
                  settings: const WidgetBuildSettings(debugLabel: 'test'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final List<Positioned> dots = tester
        .widgetList<Positioned>(items())
        .toList();
    expect(
      [
        for (final d in dots) [d.left, d.top],
      ],
      [
        [10, 0],
        [20, 0],
        [20, 1],
      ],
    );
  });
}
