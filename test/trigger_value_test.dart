import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// A setVariable action run by a widget's changed trigger reads the widget's
/// new value as the predefined `${value}` (also inside formulas).
void main() {
  Future<Observable<VariableData>> pump(
    WidgetTester tester,
    BaseNode node,
    VariableData variable,
  ) async {
    final Observable<VariableData> notifier = Observable(variable);
    final CodelesslyContext codelesslyContext = CodelesslyContext.empty()
      ..variables[variable.id] = notifier;
    final registry = NodeRegistry()..setNodes({node.id: node});
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
    return notifier;
  }

  List<Reaction> setOnChange(VariableData variable, String newValue) => [
    Reaction(
      action: SetVariableAction(variable: variable, newValue: newValue),
      trigger: TriggerModel(type: TriggerType.changed),
    ),
  ];

  testWidgets('a slider passes its value', (tester) async {
    final VariableData length = VariableData(
      id: 'length',
      name: 'length',
      type: VariableType.decimal,
      value: 0,
    );
    final notifier = await pump(
      tester,
      SliderNode(
        id: 'slider',
        name: 'slider',
        basicBoxLocal: NodeBox(0, 0, 300, 48),
        value: 10,
        properties: SliderProperties(min: 0, max: 100),
        reactions: setOnChange(length, r'${= round(value) * 2}'),
      ),
      length,
    );
    await tester.tap(find.byType(Slider));
    await tester.pumpAndSettle();
    expect(notifier.value.getValue(), closeTo(100, 2));
  });

  testWidgets('a switch passes its value', (tester) async {
    final VariableData on = VariableData(
      id: 'on',
      name: 'on',
      type: VariableType.boolean,
      value: false,
    );
    final notifier = await pump(
      tester,
      SwitchNode(
        id: 'switch',
        name: 'switch',
        basicBoxLocal: NodeBox(0, 0, 60, 40),
        properties: SwitchProperties(),
        reactions: setOnChange(on, r'${value}'),
      ),
      on,
    );
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(notifier.value.getValue(), true);
  });

  testWidgets('a text field passes its text', (tester) async {
    final VariableData query = VariableData(
      id: 'query',
      name: 'query',
      type: VariableType.text,
      value: '',
    );
    final notifier = await pump(
      tester,
      TextFieldNode(
        id: 'field',
        name: 'field',
        basicBoxLocal: NodeBox(0, 0, 300, 48),
        properties: TextFieldProperties(),
        reactions: setOnChange(query, r'${= upper(value)}'),
      ),
      query,
    );
    await tester.enterText(find.byType(TextField), 'moab');
    await tester.pump();
    expect(notifier.value.getValue(), 'MOAB');
  });
}
