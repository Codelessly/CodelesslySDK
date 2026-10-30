import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Focus Field puts the cursor in a text field, e.g. back in a form's first
/// field after "Save & add another", and Unfocus takes it away.
void main() {
  testWidgets('focuses a text field by id, and unfocuses', (tester) async {
    final TextFieldNode field = TextFieldNode(
      id: 'front',
      name: 'Front',
      basicBoxLocal: NodeBox(0, 0, 300, 50),
      properties: TextFieldProperties(),
    )..parentID = kRootNode;
    final NodeRegistry registry = NodeRegistry()..setNodes({field.id: field});
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    late BuildContext context;
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: CodelesslyContext.empty(),
        child: MaterialApp(
          home: Material(
            child: Builder(
              builder: (c) {
                context = c;
                return manager.buildWidgetFromNode(
                  field,
                  c,
                  settings: const WidgetBuildSettings(debugLabel: 'test'),
                );
              },
            ),
          ),
        ),
      ),
    );
    expect(TextFieldFocus.of('front'), isNotNull);
    expect(TextFieldFocus.of('front')!.hasFocus, isFalse);

    FunctionsRepository.performAction(
      context,
      FocusFieldAction(nodeId: 'front'),
    );
    await tester.pump();
    expect(TextFieldFocus.of('front')!.hasFocus, isTrue);

    FunctionsRepository.performAction(context, FocusFieldAction(unfocus: true));
    await tester.pump();
    expect(TextFieldFocus.of('front')!.hasFocus, isFalse);
  });
}
