import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

const InputBorderModel _none = InputBorderModel(
  borderType: BorderTypeEnum.none,
);

TextFieldNode _field({EdgeInsetsModel? contentPadding}) => TextFieldNode(
  id: 'field',
  name: 'Field',
  basicBoxLocal: NodeBox(0, 0, 300, 40),
  properties: TextFieldProperties(
    decoration: InputDecorationModel(
      isCollapsed: true,
      hintText: 'Notes',
      border: _none,
      enabledBorder: _none,
      focusedBorder: _none,
      disabledBorder: _none,
      errorBorder: _none,
      focusedErrorBorder: _none,
      contentPadding: contentPadding,
    ),
  ),
);

Future<void> _pump(WidgetTester tester, TextFieldNode node) async {
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
          body: Align(
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
  await tester.pump();
}

void main() {
  testWidgets('a zero content padding puts the text flush with the field', (
    tester,
  ) async {
    await _pump(tester, _field(contentPadding: EdgeInsetsModel.zero));
    final InputDecoration decoration = tester
        .widget<TextField>(find.byType(TextField))
        .decoration!;
    expect(decoration.contentPadding, EdgeInsets.zero);
    expect(
      tester.getTopLeft(find.byType(EditableText)).dx,
      tester.getTopLeft(find.byType(TextField)).dx,
    );
  });

  testWidgets('without one, the node padding (12 x 16) pads the text', (
    tester,
  ) async {
    await _pump(tester, _field());
    final InputDecoration decoration = tester
        .widget<TextField>(find.byType(TextField))
        .decoration!;
    expect(
      decoration.contentPadding,
      const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
    );
    expect(
      tester.getTopLeft(find.byType(EditableText)).dx -
          tester.getTopLeft(find.byType(TextField)).dx,
      12,
    );
  });

  testWidgets('a custom content padding applies as given', (tester) async {
    await _pump(
      tester,
      _field(contentPadding: const EdgeInsetsModel.only(left: 4, top: 2)),
    );
    expect(
      tester
          .widget<TextField>(find.byType(TextField))
          .decoration!
          .contentPadding,
      const EdgeInsets.only(left: 4, top: 2),
    );
  });
}
