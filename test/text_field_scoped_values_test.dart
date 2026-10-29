import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  // A design canvas shows a form field bound to a variable with the
  // variable's default value.
  testWidgets('a text field shows its bound value from given scoped values', (
    tester,
  ) async {
    final TextFieldNode node = TextFieldNode(
      id: 'name',
      name: 'Name',
      basicBoxLocal: NodeBox(0, 0, 200, 44),
      properties: TextFieldProperties(),
    )..variables['inputValue'] = r'${rigName}';

    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>(
        create: (_) => CodelesslyContext.empty(),
        child: MaterialApp(
          home: Material(
            child: PassiveTextFieldWidget(
              node: node,
              settings: const WidgetBuildSettings(debugLabel: 'test'),
              scopedValues: ScopedValues.preview(
                variables: {
                  'rigName': VariableData(
                    id: 'rigName',
                    name: 'rigName',
                    value: 'Juniper',
                  ),
                },
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Juniper'), findsOneWidget);
  });
}
