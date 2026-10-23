import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
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
      ..parentID = 'button'
      ..variables['flex'] = flex;

/// A 400 wide hold-to-sign button: its `fill` bar grows with `${hold}`.
Future<void> pumpButton(WidgetTester tester) async {
  final RowColumnNode button = RowColumnNode(
    id: 'button',
    name: 'button',
    basicBoxLocal: NodeBox(0, 0, 400, 40),
    children: const ['fill', 'rest'],
    rowColumnType: RowColumnType.row,
    reactions: [
      Reaction(
        action: ShowToastAction(message: 'Log signed', duration: 1000),
        trigger: TriggerModel(type: TriggerType.hold, duration: 1000),
      ),
    ],
  )..parentID = kRootNode;
  final nodes = [
    button,
    bar('fill', r'${= round(hold * 1000)}'),
    bar('rest', r'${= 1000 - round(hold * 1000)}'),
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
                button,
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

double fillWidth(WidgetTester tester) => tester
    .getSize(find.byKey(const ValueKey('Rectangle Transformer of fill [fill]')))
    .width;

void main() {
  test('the hold trigger round-trips its duration', () {
    final trigger = TriggerModel(type: TriggerType.hold, duration: 800);
    expect(trigger.toJson(), {'type': 'hold', 'duration': 800});
    expect(TriggerModel.fromJson(trigger.toJson()), trigger);
    expect(
      TriggerModel.fromJson({'type': 'hold'}).duration,
      kDefaultHoldDuration,
    );
  });

  testWidgets('holding fills, releasing drains, and a full hold confirms', (
    tester,
  ) async {
    await pumpButton(tester);
    expect(fillWidth(tester), 0);

    final gesture = await tester.startGesture(const Offset(200, 20));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(fillWidth(tester), closeTo(200, 2));

    // Let go halfway: it drains back and nothing fires.
    await gesture.up();
    await tester.pumpAndSettle();
    expect(fillWidth(tester), 0);
    expect(find.text('Log signed'), findsNothing);

    // Moving off while holding cancels too, like a scroll would.
    final drag = await tester.startGesture(const Offset(200, 20));
    await tester.pump(const Duration(milliseconds: 300));
    await drag.moveBy(const Offset(0, 60));
    await tester.pumpAndSettle();
    expect(fillWidth(tester), 0);
    await drag.up();

    final hold = await tester.startGesture(const Offset(200, 20));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1050));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Log signed'), findsOneWidget);
    expect(fillWidth(tester), 0);
    await hold.up();
    await tester.pumpAndSettle(const Duration(seconds: 2));
  });
}
