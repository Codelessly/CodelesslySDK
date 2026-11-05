import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

const InputBorderModel _none = InputBorderModel(borderType: BorderTypeEnum.none);

/// Darkroom's notes fields: four or six lines in a fixed box, collapsed
/// decoration, text starting at the top (textAlignVertical top), as a
/// Flutter TextField with maxLines does.
TextFieldNode _notes(TextAlignVerticalEnum align) => TextFieldNode(
  id: 'notes',
  name: 'Notes',
  basicBoxLocal: NodeBox(0, 0, 300, 120),
  horizontalFit: SizeFit.fixed,
  verticalFit: SizeFit.fixed,
  properties: TextFieldProperties(
    maxLines: 4,
    minLines: 4,
    textAlignVertical: align,
    inputStyle: TextProp(fontSize: 15),
    decoration: InputDecorationModel(
      isCollapsed: true,
      hintText: 'What did you shoot?',
      border: _none,
      enabledBorder: _none,
      focusedBorder: _none,
      showCounter: false,
      contentPadding: EdgeInsetsModel.zero,
    ),
  ),
);

Future<double> _hintTop(WidgetTester tester, TextAlignVerticalEnum align) async {
  final node = _notes(align);
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
            child: SizedBox(
              width: 300,
              height: 120,
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
    ),
  );
  await tester.pump();
  return tester.getTopLeft(find.text('What did you shoot?')).dy;
}

void main() {
  testWidgets('a multi-line collapsed field in a taller box starts at the top', (tester) async {
    expect(await _hintTop(tester, TextAlignVerticalEnum.top), lessThan(4));
  });

  testWidgets('and is centred when asked', (tester) async {
    expect(await _hintTop(tester, TextAlignVerticalEnum.center), greaterThan(20));
  });
}
