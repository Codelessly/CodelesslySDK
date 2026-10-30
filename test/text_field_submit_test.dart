import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Enter submits a text field ("Submitted"); clicking elsewhere only ends
/// the editing ("Editing Complete"), so it doesn't submit a form.
void main() {
  testWidgets('Enter submits, losing focus completes the editing', (
    tester,
  ) async {
    final List<String> fired = [];
    Reaction record(TriggerType type) => Reaction(
      trigger: TriggerModel(type: type),
      action: CallFunctionAction(name: type.name),
    );
    final TextFieldNode node = TextFieldNode(
      id: 'title',
      name: 'Title',
      basicBoxLocal: NodeBox(0, 0, 200, 44),
      properties: TextFieldProperties(),
      reactions: [
        record(TriggerType.submitted),
        record(TriggerType.editingComplete),
      ],
    );
    final manager = PassiveNodeTransformerManager(
      (id) => throw StateError(id),
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: CodelesslyContext.empty()
          ..functions = {
            for (final String name in ['submitted', 'editingComplete'])
              name: (context, reference, params) => fired.add(name),
          },
        child: MaterialApp(
          home: Material(
            child: Column(
              children: [
                Builder(
                  builder: (context) => manager.buildWidgetFromNode(
                    node,
                    context,
                    settings: const WidgetBuildSettings(debugLabel: 'test'),
                  ),
                ),
                const TextField(key: ValueKey('other')),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(TextField).first);
    await tester.enterText(find.byType(TextField).first, 'Ship it');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(fired, ['submitted']);

    await tester.tap(find.byKey(const ValueKey('other')));
    await tester.pumpAndSettle();
    expect(fired, ['submitted', 'editingComplete']);
  });
}
