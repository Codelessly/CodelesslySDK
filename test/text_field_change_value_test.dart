import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// A field bound to `q` whose "changed" reaction sets `q` from [newValue].
Future<Observable<VariableData>> _pump(
  WidgetTester tester,
  String newValue,
) async {
  final q = Observable(
    VariableData(id: 'q', name: 'q', value: '', type: VariableType.text),
  );
  final node = TextFieldNode(
    id: 'field',
    name: 'Field',
    basicBoxLocal: NodeBox(0, 0, 300, 40),
    properties: TextFieldProperties(),
    reactions: [
      Reaction(
        trigger: TriggerModel(type: TriggerType.changed),
        action: SetVariableAction(
          variable: VariableData(id: 'q', name: 'q', type: VariableType.text),
          newValue: newValue,
        ),
      ),
    ],
  )..variables['inputValue'] = r'${q}';
  final registry = NodeRegistry()..setNodes({node.id: node});
  final manager = PassiveNodeTransformerManager(
    registry.getNodeByID,
    (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
  );
  final codelesslyContext = CodelesslyContext.empty()..variables['q'] = q;
  await tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: codelesslyContext,
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
  await tester.enterText(find.byType(EditableText), 'lemon');
  await tester.pumpAndSettle();
  return q;
}

void main() {
  testWidgets('a changed action reads the typed text as \${value}', (
    tester,
  ) async {
    final q = await _pump(tester, r'${value}');
    expect(q.value.value, 'lemon');
    expect(find.text('lemon'), findsOneWidget);
  });

  testWidgets('so does \${inputValue}, the property it is bound by', (
    tester,
  ) async {
    final q = await _pump(tester, r'${inputValue}');
    expect(q.value.value, 'lemon');
    expect(find.text('lemon'), findsOneWidget);
  });
}
