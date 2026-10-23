import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Future<InputDecoration> _decorationFor(
  WidgetTester tester,
  String errorText,
) async {
  final TextFieldNode node = TextFieldNode(
    id: 'field',
    name: 'Field',
    basicBoxLocal: NodeBox(0, 0, 300, 56),
    properties: TextFieldProperties(
      decoration: InputDecorationModel(errorText: errorText),
    ),
  );
  final registry = NodeRegistry()..setNodes({node.id: node});
  final manager = PassiveNodeTransformerManager(
    registry.getNodeByID,
    (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
  );
  await tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: CodelesslyContext.empty(),
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => manager.buildWidgetFromNode(
              node,
              context,
              settings: const WidgetBuildSettings(debugLabel: 'test'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return tester.widget<TextField>(find.byType(TextField)).decoration!;
}

void main() {
  testWidgets('an error text from a formula shows only when it has text', (
    tester,
  ) async {
    final InputDecoration valid = await _decorationFor(
      tester,
      r"${= 1 > 2 ? 'Enter a name' : ''}",
    );
    expect(valid.error, isNull);
    expect(valid.errorText, isNull);

    final InputDecoration invalid = await _decorationFor(
      tester,
      r"${= 1 < 2 ? 'Enter a name' : ''}",
    );
    expect(invalid.error, isNotNull);
    expect(find.text('Enter a name'), findsOneWidget);
  });
}
