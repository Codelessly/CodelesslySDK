import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// A field bound to part of a map or list variable (`${draft.title}`)
/// sets that part when the user types, keeping the rest of the variable.
void main() {
  test('variablePathKeys and setAtPath', () {
    expect(variablePathKeys('.title'), ['title']);
    expect(variablePathKeys('[2].name'), [2, 'name']);
    expect(setAtPath({'a': 1, 'b': 2}, ['a'], 9), {'a': 9, 'b': 2});
    expect(
      setAtPath(
        [
          {'n': 'x'},
          {'n': 'y'},
        ],
        [1, 'n'],
        'z',
      ),
      [
        {'n': 'x'},
        {'n': 'z'},
      ],
    );
    expect(setAtPath(<Object>[], [3], 'z'), isNull);
  });

  testWidgets('typing into a field bound to draft.title sets only title', (
    tester,
  ) async {
    final Observable<VariableData> draft = Observable(
      VariableData(
        id: 'draft',
        name: 'draft',
        type: VariableType.map,
        value: {'title': 'Ship', 'desc': 'Keep me'},
      ),
    );
    final TextFieldNode node = TextFieldNode(
      id: 'field',
      name: 'Field',
      basicBoxLocal: NodeBox(0, 0, 300, 48),
      properties: TextFieldProperties(),
    )..variables['inputValue'] = r'${draft.title}';
    final registry = NodeRegistry()..setNodes({node.id: node});
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: CodelesslyContext.empty()..variables['draft'] = draft,
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
    expect(find.text('Ship'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Ship it');
    await tester.pump();
    expect(draft.value.getValue(), {'title': 'Ship it', 'desc': 'Keep me'});
  });
}
