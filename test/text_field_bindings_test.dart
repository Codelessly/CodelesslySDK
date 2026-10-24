import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

TextFieldNode field({
  Map<String, String> variables = const {},
  bool obscureText = false,
  BoxConstraintsModel prefixIconConstraints = const BoxConstraintsModel(),
}) => TextFieldNode(
  id: 'field',
  name: 'Field',
  basicBoxLocal: NodeBox(0, 0, 300, 48),
  properties: TextFieldProperties(
    obscureText: obscureText,
    decoration: InputDecorationModel(
      prefixIconConstraints: prefixIconConstraints,
    ),
  ),
)..variables.addAll(variables);

Future<TextField> pump(WidgetTester tester, TextFieldNode node) async {
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
  return tester.widget<TextField>(find.byType(TextField));
}

void main() {
  testWidgets('obscureText follows its binding (a show-password toggle)', (
    WidgetTester tester,
  ) async {
    expect(
      (await pump(
        tester,
        field(variables: {'obscureText': r'${= 2 > 1}'}),
      )).obscureText,
      isTrue,
    );
    expect(
      (await pump(
        tester,
        field(obscureText: true, variables: {'obscureText': r'${= 1 > 2}'}),
      )).obscureText,
      isFalse,
    );
  });

  testWidgets('a one-line field with a set height stays one line and fills '
      'its height', (WidgetTester tester) async {
    final TextField built = await pump(tester, field(obscureText: true));
    expect(built.maxLines, 1);
    expect(built.expands, isFalse);
    expect(built.obscureText, isTrue);
    expect(tester.getSize(find.byType(InputDecorator)).height, 48);
  });

  testWidgets('enabled and readOnly follow their bindings', (
    WidgetTester tester,
  ) async {
    final TextField built = await pump(
      tester,
      field(variables: {'enabled': r'${= 1 > 2}', 'readOnly': r'${= 2 > 1}'}),
    );
    expect(built.enabled, isFalse);
    expect(built.readOnly, isTrue);
  });

  testWidgets('prefix icon constraints apply when set', (
    WidgetTester tester,
  ) async {
    expect(
      (await pump(tester, field())).decoration?.prefixIconConstraints,
      isNull,
    );
    expect(
      (await pump(
        tester,
        field(
          prefixIconConstraints: const BoxConstraintsModel(
            minWidth: 40,
            minHeight: 0,
          ),
        ),
      )).decoration?.prefixIconConstraints?.minWidth,
      40,
    );
  });
}
