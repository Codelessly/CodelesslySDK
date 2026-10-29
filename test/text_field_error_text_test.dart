import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

TextFieldNode _field(String errorText) => TextFieldNode(
  id: 'field',
  name: 'Field',
  basicBoxLocal: NodeBox(0, 0, 300, 60),
  properties: TextFieldProperties(
    decoration: InputDecorationModel(errorText: errorText),
  ),
);

Future<InputDecoration> _pump(WidgetTester tester, TextFieldNode node) async {
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
          body: Center(
            child: Builder(
              builder: (context) => manager.buildWidgetFromNode(
                node,
                context,
                settings: const WidgetBuildSettings(debugLabel: 'test'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  expect(tester.takeException(), isNull);
  return tester.widget<InputDecorator>(find.byType(InputDecorator)).decoration;
}

void main() {
  for (final template in [
    r"${= false ? 'Required' : ''}",
    r"${= false ? 'Required' : '  '}",
    '   ',
  ]) {
    testWidgets('error text "$template" that comes out blank is no error', (
      tester,
    ) async {
      final decoration = await _pump(tester, _field(template));
      expect(decoration.error, isNull);
      expect(decoration.errorText, isNull);
      expect(find.text('Required'), findsNothing);
    });
  }

  testWidgets('error text template with a message is an error', (tester) async {
    final decoration = await _pump(
      tester,
      _field(r"${= true ? 'Required' : ''}"),
    );
    expect(decoration.error, isNotNull);
    expect(find.text('Required'), findsOneWidget);
  });

  testWidgets('plain error text is an error', (tester) async {
    final decoration = await _pump(tester, _field('Required'));
    expect(decoration.error, isNotNull);
    expect(find.text('Required'), findsOneWidget);
  });

  testWidgets('conditional error text shows only when the condition is true', (
    tester,
  ) async {
    final valid = await _pump(
      tester,
      _field(r"${= 1 > 2 ? 'Enter a name' : ''}"),
    );
    expect(valid.error, isNull);
    expect(valid.errorText, isNull);
    final invalid = await _pump(
      tester,
      _field(r"${= 1 < 2 ? 'Enter a name' : ''}"),
    );
    expect(invalid.error, isNotNull);
    expect(find.text('Enter a name'), findsOneWidget);
  });
}
