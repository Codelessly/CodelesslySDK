import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('Modal renders only trigger in the closed scene', (tester) async {
    final modal = ModalNode(
      id: 'modal',
      name: 'Modal',
      basicBoxLocal: NodeBox(0, 0, 120, 40),
      trigger: 'trigger',
      content: 'content',
    );
    final trigger = FilledButtonNode(
      id: 'trigger',
      name: 'Trigger',
      basicBoxLocal: NodeBox(0, 0, 120, 40),
      properties: ButtonProperties(
        label: 'Open',
        buttonType: ButtonTypeEnum.filled,
      ),
      reactions: [
        Reaction(
          action: ShowDialogAction(destinationId: 'content'),
          trigger: TriggerModel(type: TriggerType.click),
        ),
      ],
    );
    final content = CanvasNode(
      id: 'content',
      name: 'Content',
      basicBoxLocal: NodeBox(0, 0, 200, 100),
      children: const [],
      properties: CanvasProperties(
        bodyId: 'body',
        safeArea: const SafeAreaModel.all(false),
      ),
    );
    final registry = NodeRegistry()
      ..setNodes({modal.id: modal, trigger.id: trigger, content.id: content});
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: CodelesslyContext.empty(),
        child: MaterialApp(
          home: Builder(
            builder: (context) => manager.buildWidgetFromNode(
              modal,
              context,
              settings: const WidgetBuildSettings(debugLabel: 'modal'),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.text('Open'), findsOneWidget);
    expect(find.byType(Scaffold), findsNothing);
  });
}
