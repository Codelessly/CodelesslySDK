import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// A form field whose error state, focus and autofocus follow variables.
void main() {
  Observable<VariableData> variable(String name, VariableType type, Object v) =>
      Observable(VariableData(id: name, name: name, type: type, value: v));

  TextFieldNode field({
    String? errorText,
    Map<String, String> variables = const {},
  }) => TextFieldNode.fromJson({
    ...TextFieldNode(
      id: 'field',
      name: 'Field',
      basicBoxLocal: NodeBox(0, 0, 300, 48),
      properties: TextFieldProperties(
        decoration: InputDecorationModel(errorText: errorText),
      ),
    ).toJson(),
    'variables': variables,
  });

  Future<CodelesslyContext> pump(
    WidgetTester tester,
    TextFieldNode node,
    List<Observable<VariableData>> variables,
  ) async {
    final registry = NodeRegistry()..setNodes({node.id: node});
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    final codelesslyContext = CodelesslyContext.empty();
    for (final v in variables) {
      codelesslyContext.variables[v.value.id] = v;
    }
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: codelesslyContext,
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
    return codelesslyContext;
  }

  InputDecoration decoration(WidgetTester tester) =>
      tester.widget<InputDecorator>(find.byType(InputDecorator)).decoration;

  testWidgets('an error text template that resolves empty is no error', (
    tester,
  ) async {
    final noteError = variable('noteError', VariableType.text, '');
    await pump(tester, field(errorText: r'${noteError}'), [noteError]);
    expect(tester.takeException(), isNull);
    expect(decoration(tester).error, isNull);

    noteError.set(noteError.value.copyWith(value: 'Add a note'));
    await tester.pump();
    expect(decoration(tester).error, isNotNull);
    expect(find.text('Add a note'), findsOneWidget);

    noteError.set(noteError.value.copyWith(value: ''));
    await tester.pump();
    expect(decoration(tester).error, isNull);
    expect(find.text('Add a note'), findsNothing);
  });

  testWidgets('a bound errorText follows a map field, null is no error', (
    tester,
  ) async {
    final formErrors = variable('formErrors', VariableType.map, {
      'title': null,
    });
    await pump(
      tester,
      field(variables: {'errorText': r'${formErrors.title}'}),
      [formErrors],
    );
    expect(decoration(tester).error, isNull);

    formErrors.set(
      formErrors.value.copyWith(value: {'title': 'Title is required'}),
    );
    await tester.pump();
    expect(find.text('Title is required'), findsOneWidget);
  });

  testWidgets('a focused variable follows the field focus', (tester) async {
    final focused = variable('titleFocused', VariableType.boolean, false);
    await pump(tester, field(variables: {'focused': 'titleFocused'}), [
      focused,
    ]);
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(focused.value.value, 'true');

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    expect(focused.value.value, 'false');
    expect(tester.takeException(), isNull);
  });

  for (final bool value in [true, false]) {
    testWidgets('a bound autoFocus of $value', (tester) async {
      final editing = variable('editing', VariableType.boolean, !value);
      await pump(tester, field(variables: {'autoFocus': r'${= !editing}'}), [
        editing,
      ]);
      expect(tester.widget<TextField>(find.byType(TextField)).autofocus, value);
      final EditableTextState editable = tester.state(
        find.byType(EditableText),
      );
      expect(editable.widget.focusNode.hasFocus, value);
    });
  }
}
