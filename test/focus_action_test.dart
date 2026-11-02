import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// A Focus action moves the keyboard focus to a text field by its node,
/// e.g. pressing `/` jumps to search, and takes it away again.
void main() {
  testWidgets('a Focus action focuses and unfocuses a text field', (
    tester,
  ) async {
    TextFieldNode field(String id) => TextFieldNode(
      id: id,
      name: id,
      basicBoxLocal: NodeBox(0, 0, 200, 44),
      properties: TextFieldProperties(),
      initialText: 'MOB',
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>(
        create: (_) => CodelesslyContext.empty(),
        child: MaterialApp(
          home: Material(
            child: Column(
              children: [
                for (final String id in ['search', 'title'])
                  PassiveTextFieldWidget(
                    node: field(id),
                    settings: const WidgetBuildSettings(debugLabel: 'test'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    EditableText editable(int i) =>
        tester.widgetList<EditableText>(find.byType(EditableText)).elementAt(i);

    await FunctionsRepository.runFocus(
      FocusAction(nodeId: 'search', selectAll: true),
    );
    await tester.pump();
    expect(editable(0).focusNode.hasFocus, isTrue);
    expect(editable(1).focusNode.hasFocus, isFalse);
    expect(editable(0).controller.selection.extentOffset, 3);

    await FunctionsRepository.runFocus(FocusAction(nodeId: 'title'));
    await tester.pump();
    expect(editable(1).focusNode.hasFocus, isTrue);

    await FunctionsRepository.runFocus(FocusAction(unfocus: true));
    await tester.pump();
    expect(editable(0).focusNode.hasFocus, isFalse);
    expect(editable(1).focusNode.hasFocus, isFalse);

    // The action survives a round trip through JSON.
    final ActionModel action = ActionModel.fromJson(
      FocusAction(nodeId: 'search', selectAll: true).toJson(),
    );
    expect(action, FocusAction(nodeId: 'search', selectAll: true));
  });
}
