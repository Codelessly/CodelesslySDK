import 'dart:convert';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// A field bound two-way to a part of a map or list variable writes there
/// and keeps the variable's other fields.
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

  VariableData draft() => VariableData(
    id: 'draft',
    name: 'draft',
    type: VariableType.map,
    value: jsonEncode({
      'name': 'Juniper',
      'length': 30,
      'stops': [
        {'name': 'A'},
        {'name': 'B'},
      ],
    }),
  );

  TextFieldNode field(String binding) => TextFieldNode(
    id: 'field',
    name: 'field',
    basicBoxLocal: NodeBox(0, 0, 300, 48),
    properties: TextFieldProperties(),
  )..variables = {'inputValue': binding};

  testWidgets('a text field bound to a map key writes the key', (tester) async {
    final notifier = await pump(tester, field(r'${draft.length}'), draft());
    await tester.enterText(find.byType(TextField), '34');
    await tester.pump();
    expect(notifier.value.getValue(), {
      'name': 'Juniper',
      'length': 34,
      'stops': [
        {'name': 'A'},
        {'name': 'B'},
      ],
    });
  });

  testWidgets('a text field bound to a nested list path writes there', (
    tester,
  ) async {
    final notifier = await pump(
      tester,
      field(r'${draft.stops[1].name}'),
      draft(),
    );
    await tester.enterText(find.byType(TextField), 'Moab');
    await tester.pump();
    final Map value = notifier.value.getValue() as Map;
    expect(value['stops'], [
      {'name': 'A'},
      {'name': 'Moab'},
    ]);
    expect(value['name'], 'Juniper');
    expect(value['length'], 30);
  });

  testWidgets('a slider bound to a map key writes the key', (tester) async {
    final SliderNode slider = SliderNode(
      id: 'slider',
      name: 'slider',
      basicBoxLocal: NodeBox(0, 0, 300, 48),
      value: 30,
      properties: SliderProperties(min: 0, max: 100),
    )..variables = {'value': r'${draft.length}'};
    final notifier = await pump(tester, slider, draft());
    await tester.tap(find.byType(Slider));
    await tester.pump();
    final Map value = notifier.value.getValue() as Map;
    expect(value['name'], 'Juniper');
    expect(value['stops'], hasLength(2));
    expect(value['length'], isA<num>());
    expect(value['length'], closeTo(50, 1));
  });

  test('path keys', () {
    expect(FunctionsRepository.pathKeys('.length'), ['length']);
    expect(FunctionsRepository.pathKeys('.stops[2].name'), [
      'stops',
      2,
      'name',
    ]);
    expect(FunctionsRepository.pathKeys("['a key']"), ['a key']);
    expect(FunctionsRepository.pathKeys('nope'), isNull);
    expect(FunctionsRepository.setAtPath([1, 2], [2], 3), [1, 2, 3]);
    expect(FunctionsRepository.setAtPath([1, 2], [5], 3), isNull);
    expect(FunctionsRepository.setAtPath({'a': 1}, ['b', 'c'], 2), {
      'a': 1,
      'b': {'c': 2},
    });
  });
}
