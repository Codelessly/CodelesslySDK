import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Plan pins: hovering a pin shows its tooltip (`hoverPin` = the pin's
/// item id), leaving it hides the tooltip.
void main() {
  Reaction on(TriggerType type, String value) => Reaction(
    action: SetVariableAction(
      variable: VariableData(id: 'hoverPin', name: 'hoverPin'),
      newValue: value,
    ),
    trigger: TriggerModel(type: type),
  );

  testWidgets('cursorEnter and cursorExit run with the item in scope', (
    tester,
  ) async {
    final RectangleNode pin = RectangleNode(
      id: 'pin',
      name: 'Pin',
      basicBoxLocal: NodeBox(0, 0, 40, 40),
      reactions: [
        on(TriggerType.cursorEnter, r'${item.id}'),
        on(TriggerType.cursorExit, ''),
      ],
    )..parentID = kRootNode;
    final Observable<VariableData> hoverPin = Observable(
      VariableData(id: 'hoverPin', name: 'hoverPin', value: ''),
    );
    final registry = NodeRegistry()..setNodes({pin.id: pin});
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: CodelesslyContext.empty()..variables['hoverPin'] = hoverPin,
        child: MaterialApp(
          home: Center(
            child: IndexedItemProvider(
              item: IndexedItem(3, {'id': '004'}),
              child: Builder(
                builder: (context) => manager.buildWidgetFromNode(
                  pin,
                  context,
                  settings: const WidgetBuildSettings(debugLabel: 'test'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final TestGesture mouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await tester.pump();
    expect(hoverPin.value.value, '');

    await mouse.moveTo(tester.getCenter(find.byType(MouseRegion).last));
    await tester.pumpAndSettle();
    expect(hoverPin.value.value, '004');

    await mouse.moveTo(Offset.zero);
    await tester.pumpAndSettle();
    expect(hoverPin.value.value, '');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a node without hover reactions gets no mouse region', (
    tester,
  ) async {
    final RectangleNode box = RectangleNode(
      id: 'box',
      name: 'Box',
      basicBoxLocal: NodeBox(0, 0, 40, 40),
    )..parentID = kRootNode;
    final registry = NodeRegistry()..setNodes({box.id: box});
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: CodelesslyContext.empty(),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) => manager.buildWidgetFromNode(
              box,
              context,
              settings: const WidgetBuildSettings(debugLabel: 'test'),
            ),
          ),
        ),
      ),
    );
    expect(
      find.byWidgetPredicate((w) => w is MouseRegion && w.onEnter != null),
      findsNothing,
    );
  });
}
