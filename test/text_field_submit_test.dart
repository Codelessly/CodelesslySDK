import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Enter submits a text field once; losing the focus doesn't submit.
void main() {
  testWidgets('Enter runs submitted reactions once, blur does not', (
    tester,
  ) async {
    final List<String> submitted = [];
    final TextFieldNode node = TextFieldNode(
      id: 'field',
      name: 'field',
      basicBoxLocal: NodeBox(0, 0, 300, 48),
      properties: TextFieldProperties(),
      reactions: [
        Reaction(
          action: CallFunctionAction(name: 'search'),
          trigger: TriggerModel(type: TriggerType.submitted),
        ),
      ],
    );
    final registry = NodeRegistry()..setNodes({node.id: node});
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: CodelesslyContext.empty()
          ..functions = {
            'search': (context, reference, params) => submitted.add('search'),
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

    await tester.enterText(find.byType(TextFormField), 'moab');
    await tester.pump();
    expect(submitted, isEmpty, reason: 'typing does not submit');

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(submitted, hasLength(1));

    // The field keeps the focus after Enter; moving it away doesn't submit.
    final EditableText editable = tester.widget(
      find.descendant(
        of: find.byType(TextFormField),
        matching: find.byType(EditableText),
      ),
    );
    expect(editable.focusNode.hasFocus, isTrue);
    await tester.tap(find.byKey(const ValueKey('other')));
    await tester.pump();
    expect(editable.focusNode.hasFocus, isFalse);
    expect(submitted, hasLength(1));

    // Focus and blur without Enter: still nothing.
    await tester.tap(find.byType(TextFormField));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('other')));
    await tester.pump();
    expect(submitted, hasLength(1));
    expect(tester.takeException(), isNull);
  });
}
