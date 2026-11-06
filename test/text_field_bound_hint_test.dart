import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// `hintText` (and the helper and label texts) bound in a field's variables
/// show their value: a form that says "Last port" for an arrival and "Next
/// port" for a departure. The binding used to be ignored: only a set-value
/// action or the decoration's own text was read.
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

TextFieldNode _field(Map<String, String> variables, {String? hint}) =>
    TextFieldNode(
      id: 'field',
      name: 'Field',
      basicBoxLocal: NodeBox(0, 0, 300, 60),
      properties: TextFieldProperties(
        decoration: InputDecorationModel(hintText: hint),
      ),
    )..variables.addAll(variables);

void main() {
  testWidgets('a bound hint shows its value', (tester) async {
    final d = await _pump(
      tester,
      _field({
        'hintText': r"${= 1 > 2 ? 'Last port' : 'Next port'}",
      }, hint: 'Port'),
    );
    expect(d.hintText, 'Next port');
  });

  testWidgets('a bound helper text shows its value', (tester) async {
    final d = await _pump(
      tester,
      _field({'helperText': r"${= 'Up to ' + 280}"}),
    );
    expect(d.helperText, 'Up to 280');
  });

  testWidgets('without a binding the decoration hint is used', (tester) async {
    final d = await _pump(tester, _field({}, hint: 'Last port'));
    expect(d.hintText, 'Last port');
  });
}
