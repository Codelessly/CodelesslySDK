import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('pointer down and up fire their reactions, and taps still work', (
    tester,
  ) async {
    Reaction call(String name, TriggerType type) => Reaction(
      action: CallFunctionAction(name: name),
      trigger: TriggerModel(type: type),
    );
    final RectangleNode button = RectangleNode(
      id: 'hold',
      name: 'Hold',
      basicBoxLocal: NodeBox(0, 0, 200, 48),
      reactions: [
        call('down', TriggerType.pointerDown),
        call('up', TriggerType.pointerUp),
        call('tap', TriggerType.click),
      ],
    )..parentID = kRootNode;
    final List<String> calls = [];
    final CodelesslyContext codelesslyContext = CodelesslyContext.empty()
      ..functions = {
        for (final name in ['down', 'up', 'tap'])
          name: (context, reference, params) => calls.add(name),
      };
    final registry = NodeRegistry()..setNodes({button.id: button});
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

    final TestGesture gesture = await tester.startGesture(
      const Offset(100, 24),
    );
    await tester.pump();
    expect(calls, ['down']);
    await tester.pump(const Duration(milliseconds: 1500));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(calls.take(2), ['down', 'up']);

    calls.clear();
    await tester.tapAt(const Offset(100, 24));
    await tester.pumpAndSettle();
    expect(calls, containsAll(['down', 'up', 'tap']));
  });
}
