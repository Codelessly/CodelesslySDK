import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

RectangleNode bar(String id, String flex) =>
    RectangleNode(
        id: id,
        name: id,
        basicBoxLocal: NodeBox(0, 0, 10, 40),
        horizontalFit: SizeFit.expanded,
      )
      ..parentID = 'tile'
      ..variables['flex'] = flex;

/// A 300 wide tappable tile whose `a` bar takes 2/3 of it when hovered.
Future<void> pumpTile(WidgetTester tester, {bool tappable = true}) async {
  final RowColumnNode tile = RowColumnNode(
    id: 'tile',
    name: 'tile',
    basicBoxLocal: NodeBox(0, 0, 300, 40),
    children: const ['a', 'b'],
    rowColumnType: RowColumnType.row,
    reactions: [
      if (tappable)
        Reaction(
          action: ShowToastAction(message: 'Opened'),
          trigger: TriggerModel(type: TriggerType.click),
        ),
    ],
  )
    ..parentID = kRootNode
    ..variables['opacity'] = r'${= if(hovered, 0.5, 1)}';
  final nodes = [
    tile,
    bar('a', r'${= if(hovered, 2, 1)}'),
    bar('b', r'${= 1}'),
  ];
  final registry = NodeRegistry()..setNodes({for (final n in nodes) n.id: n});
  final manager = PassiveNodeTransformerManager(
    registry.getNodeByID,
    (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
  );
  await tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: CodelesslyContext.empty(),
      child: MaterialApp(
        home: Material(
          child: Align(
            alignment: Alignment.topLeft,
            child: Builder(
              builder: (context) => manager.buildWidgetFromNode(
                tile,
                context,
                settings: const WidgetBuildSettings(debugLabel: 'test'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

double barWidth(WidgetTester tester) => tester
    .getSize(find.byKey(const ValueKey('Rectangle Transformer of a [a]')))
    .width;

void main() {
  testWidgets('nodes inside a tappable node read whether it is hovered', (
    tester,
  ) async {
    await pumpTile(tester);
    expect(barWidth(tester), closeTo(150, 0.5));

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(500, 500));
    await mouse.moveTo(const Offset(100, 20));
    await tester.pump();
    expect(barWidth(tester), closeTo(200, 0.5));
    // The tile's own properties see it too: a hover border or fill.
    expect(
      tester
          .widgetList<Opacity>(find.byType(Opacity))
          .any((o) => o.opacity == 0.5),
      isTrue,
    );

    await mouse.moveTo(const Offset(500, 500));
    await tester.pump();
    expect(barWidth(tester), closeTo(150, 0.5));
    await mouse.removePointer();
  });

  testWidgets('outside a tappable node hovered is false', (tester) async {
    await pumpTile(tester, tappable: false);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(100, 20));
    await tester.pump();
    expect(barWidth(tester), closeTo(150, 0.5));
    await mouse.removePointer();
  });
}
