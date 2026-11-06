import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/functions/action_chain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'feedback_actions_test.dart' show brandRegular, text;

/// A 40×40 draggable pin at the top left and a 200×100 drop target (a map)
/// at (100, 200); the map's drop records `${result}`.
void main() {
  Future<({CodelesslyContext context, List<Object?> drops})> pump(
    WidgetTester tester, {
    DraggableModel draggable = const DraggableModel(
      group: 'pin',
      start: DragStart.press,
    ),
    Map<String, BaseNode> extra = const {},
    Map<String, dynamic>? routeParams,
    IndexedItem? item,
    double pinSize = 40,
  }) async {
    tester.view.physicalSize = const Size(400, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final List<Object?> drops = [];
    final RectangleNode pin =
        RectangleNode(
            id: 'pin',
            name: 'Pin',
            basicBoxLocal: NodeBox(0, 0, pinSize, pinSize),
          )
          ..parentID = kRootNode
          ..draggable = draggable;
    final RectangleNode map =
        RectangleNode(
            id: 'map',
            name: 'Map',
            basicBoxLocal: NodeBox(0, 0, 200, 100),
            reactions: [
              Reaction(
                name: 'drop',
                trigger: TriggerModel(type: TriggerType.drop),
                action: CallFunctionAction(name: 'dropped'),
              ),
            ],
          )
          ..parentID = kRootNode
          ..dropTarget = const DropTargetModel(accepts: ['pin'], key: 'map');
    final NodeRegistry registry = NodeRegistry()
      ..setNodes({'pin': pin, 'map': map, ...extra});
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    final CodelesslyContext c = CodelesslyContext.empty()
      ..functions = {
        'dropped': (context, reference, params) =>
            drops.add(ActionChain.current?.result),
      };
    Widget built(BaseNode node, double w, double h) => SizedBox(
      width: w,
      height: h,
      child: Builder(
        builder: (context) => manager.buildWidgetFromNode(
          node,
          context,
          settings: const WidgetBuildSettings(debugLabel: 'test'),
        ),
      ),
    );
    Widget source = built(pin, pinSize, pinSize);
    if (item != null) source = IndexedItemProvider(item: item, child: source);
    Widget home = ActionChainHost(
      child: Stack(
        children: [
          Positioned(left: 0, top: 0, child: source),
          Positioned(left: 100, top: 200, child: built(map, 200, 100)),
        ],
      ),
    );
    if (routeParams != null) {
      home = RouteParamsScope(params: routeParams, child: home);
    }
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: c,
        child: MaterialApp(home: home),
      ),
    );
    return (context: c, drops: drops);
  }

  Future<TestGesture> dragTo(
    WidgetTester tester,
    Offset start,
    Offset to,
  ) async {
    final TestGesture gesture = await tester.startGesture(start);
    await tester.pump();
    for (int i = 1; i <= 10; i++) {
      await gesture.moveTo(Offset.lerp(start, to, i / 10)!);
      await tester.pump();
    }
    return gesture;
  }

  testWidgets('a centre-anchored feedback holds its centre under the pointer '
      'and the drop lands at the pointer', (tester) async {
    final r = await pump(
      tester,
      draggable: const DraggableModel(
        group: 'pin',
        start: DragStart.press,
        feedbackAnchor: FeedbackAnchor.center,
        feedbackRotation: 0,
      ),
    );
    // Grabbed off centre, near the pin's top left corner.
    const Offset to = Offset(160, 230);
    final TestGesture gesture = await dragTo(tester, const Offset(5, 5), to);
    // The copy following the pointer is centred on it.
    final Finder copy = find.byWidgetPredicate(
      (widget) =>
          widget is DecoratedBox &&
          widget.decoration is BoxDecoration &&
          (widget.decoration as BoxDecoration).boxShadow?.isNotEmpty == true,
    );
    expect(tester.getCenter(copy), to);
    final Map<String, Object?> drag = r.context.dragAndDrop.value;
    expect(drag['over'], 'map');
    expect(drag['x'] as double, closeTo(60, 0.01));
    expect(drag['y'] as double, closeTo(30, 0.01));
    await gesture.up();
    await tester.pumpAndSettle();
    final Map result = r.drops.single! as Map;
    expect(result['x'] as double, closeTo(60, 0.01));
    expect(result['y'] as double, closeTo(30, 0.01));
    expect(result['fx'] as double, closeTo(0.3, 0.001));
    expect(result['fy'] as double, closeTo(0.3, 0.001));
  });

  testWidgets('the grab anchor keeps where the node was picked up', (
    tester,
  ) async {
    final r = await pump(tester);
    // Grabbed 15 left and 15 above the pin's centre: its centre lands 15
    // right and below the pointer.
    final TestGesture gesture = await dragTo(
      tester,
      const Offset(5, 5),
      const Offset(160, 230),
    );
    await gesture.up();
    await tester.pumpAndSettle();
    final Map result = r.drops.single! as Map;
    expect(result['x'] as double, closeTo(75, 0.01));
    expect(result['y'] as double, closeTo(45, 0.01));
  });

  testWidgets('a feedback node is built by id though it is shown nowhere, '
      'with the source\'s list item and route', (tester) async {
    final FrameNode holder =
        FrameNode(
            id: 'holder',
            name: 'Holder',
            basicBoxLocal: NodeBox(0, 0, 1, 1),
            children: ['fb'],
          )
          ..parentID = kRootNode
          ..visible = false;
    final TextNode fb = text(
      'fb',
      'holder',
      r'${item.title} at ${route.place}',
      brandRegular,
    )..visible = false;
    final r = await pump(
      tester,
      draggable: const DraggableModel(
        group: 'pin',
        start: DragStart.press,
        feedbackNodeId: 'fb',
        feedbackAnchor: FeedbackAnchor.center,
      ),
      extra: {'holder': holder, 'fb': fb},
      routeParams: {'place': 'Orchard'},
      item: IndexedItem(0, {'title': 'Hive 1'}),
    );
    // Neither the holder nor the feedback node is on screen.
    expect(find.text('Hive 1 at Orchard', findRichText: true), findsNothing);
    const Offset to = Offset(200, 250);
    final TestGesture gesture = await dragTo(tester, const Offset(20, 20), to);
    final Finder shown = find.text('Hive 1 at Orchard', findRichText: true);
    expect(shown, findsWidgets);
    // Centred on the pointer, though wider than the pin.
    final Rect rect = tester.getRect(
      find.byWidgetPredicate(
        (widget) =>
            widget is DecoratedBox &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).boxShadow?.isNotEmpty == true,
      ),
    );
    expect((rect.center - to).distance, lessThan(0.01));
    await gesture.up();
    await tester.pumpAndSettle();
    expect((r.drops.single! as Map)['fx'] as double, closeTo(0.5, 0.001));
  });

  testWidgets('a centred feedback node smaller than the dragged node is '
      'centred on the pointer too', (tester) async {
    final FrameNode holder =
        FrameNode(
            id: 'holder',
            name: 'Holder',
            basicBoxLocal: NodeBox(0, 0, 40, 46),
            children: ['token'],
          )
          ..parentID = kRootNode
          ..visible = false;
    final RectangleNode token = RectangleNode(
      id: 'token',
      name: 'Token',
      basicBoxLocal: NodeBox(0, 0, 40, 46),
      fills: [
        PaintModel.solid(id: 't', color: const ColorRGB(r: 1, g: 0, b: 0)),
      ],
    )..parentID = 'holder';
    await pump(
      tester,
      pinSize: 88,
      draggable: const DraggableModel(
        group: 'pin',
        start: DragStart.press,
        feedbackNodeId: 'token',
        feedbackAnchor: FeedbackAnchor.center,
        feedbackRotation: 0,
      ),
      extra: {'holder': holder, 'token': token},
    );
    const Offset to = Offset(200, 250);
    // Grabbed near the 88×88 node's top left corner.
    final TestGesture gesture = await dragTo(tester, const Offset(6, 6), to);
    final Rect rect = tester.getRect(
      find.byWidgetPredicate(
        (widget) =>
            widget is DecoratedBox &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).boxShadow?.isNotEmpty == true,
      ),
    );
    expect(rect.size, const Size(40, 46));
    expect((rect.center - to).distance, lessThan(0.01));
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('a feedback node that does not exist draws nothing', (
    tester,
  ) async {
    await pump(
      tester,
      draggable: const DraggableModel(
        group: 'pin',
        start: DragStart.press,
        feedbackNodeId: 'missing',
      ),
    );
    final TestGesture gesture = await dragTo(
      tester,
      const Offset(20, 20),
      const Offset(200, 250),
    );
    expect(tester.takeException(), isNull);
    await gesture.up();
    await tester.pumpAndSettle();
  });

  group('click results', () {
    Future<List<Object?>> pumpTappable(
      WidgetTester tester,
      List<TriggerType> types,
    ) async {
      final List<Object?> results = [];
      final manager = PassiveNodeTransformerManager(
        (id) => throw StateError(id),
        (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
      );
      final RectangleNode node = RectangleNode(
        id: 'map',
        name: 'Map',
        basicBoxLocal: NodeBox(0, 0, 200, 100),
        reactions: [
          for (final type in types)
            Reaction(
              name: type.name,
              trigger: TriggerModel(type: type),
              action: CallFunctionAction(name: 'record'),
            ),
        ],
      );
      final c = CodelesslyContext.empty()
        ..functions = {
          'record': (context, reference, params) =>
              results.add(ActionChain.current?.result),
        };
      await tester.pumpWidget(
        ChangeNotifierProvider<CodelesslyContext>.value(
          value: c,
          child: MaterialApp(
            home: ActionChainHost(
              child: Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 10, top: 20),
                  child: Builder(
                    builder: (context) => manager.wrapWithReaction(
                      context,
                      node,
                      const SizedBox(width: 200, height: 100),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      return results;
    }

    testWidgets('a click gives fx, fy, width and height', (tester) async {
      final results = await pumpTappable(tester, [TriggerType.click]);
      await tester.tapAt(const Offset(60, 45));
      await tester.pump();
      final Map result = results.single! as Map;
      const Map<String, double> expected = {
        'x': 50.0,
        'y': 25.0,
        'globalX': 60.0,
        'globalY': 45.0,
        'fx': 0.25,
        'fy': 0.25,
        'width': 200.0,
        'height': 100.0,
      };
      expected.forEach((key, value) => expect(result[key], value, reason: key));
    });

    testWidgets('a long press gives where it landed', (tester) async {
      final results = await pumpTappable(tester, [TriggerType.longPress]);
      await tester.longPressAt(const Offset(160, 70));
      await tester.pump();
      final Map result = results.single! as Map;
      expect(result['fx'], 0.75);
      expect(result['fy'], 0.5);
      expect(result['width'], 200.0);
    });

    testWidgets('pointer down gives fx and fy', (tester) async {
      final results = await pumpTappable(tester, [TriggerType.pointerDown]);
      await tester.tapAt(const Offset(110, 70));
      await tester.pump();
      final Map result = results.single! as Map;
      expect(result['x'], 100.0);
      expect(result['fx'], 0.5);
      expect(result['fy'], 0.5);
      expect(result['height'], 100.0);
      expect(result['button'], 'primary');
    });
  });
}
