import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('a focused state that adds a ring keeps the input it wraps', (
    tester,
  ) async {
    final TextFieldNode field = TextFieldNode(
      id: 'field',
      name: 'Field',
      basicBoxLocal: NodeBox(0, 0, 260, 40),
      properties: TextFieldProperties(),
    )..parentID = 'box';
    final RowColumnNode box =
        RowColumnNode(
            id: 'box',
            name: 'Box',
            basicBoxLocal: NodeBox(0, 0, 300, 68),
            rowColumnType: RowColumnType.row,
            children: ['field'],
            fills: [PaintModel.solid(id: 'f', color: ColorRGB.white)],
          )
          ..parentID = kRootNode
          ..transitionMs = 160
          ..interactionStates = {
            InteractionState.focused: {
              'box': {
                'strokes': [
                  PaintModel.solid(id: 's', color: ColorRGB.black).toJson(),
                ],
                'effects': [
                  Effect(
                    id: 'ring',
                    type: EffectType.dropShadow,
                    color: ColorRGBA.black,
                    spread: 4,
                    radius: 0,
                  ).toJson(),
                ],
              },
            },
          };
    final registry = NodeRegistry()..setNodes({box.id: box, field.id: field});
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: CodelesslyContext.empty(),
        child: MaterialApp(
          home: Material(
            child: Align(
              alignment: Alignment.topLeft,
              child: Builder(
                builder: (context) => manager.buildWidgetFromNode(
                  box,
                  context,
                  settings: const WidgetBuildSettings(debugLabel: 'test'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final State before = tester.state(find.byType(EditableText));
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(
      tester.state(find.byType(EditableText)),
      same(before),
      reason: 'the field was rebuilt from scratch when the state switched on',
    );
    final EditableTextState editable = tester.state(find.byType(EditableText));
    expect(editable.widget.focusNode.hasFocus, isTrue);
    tester.testTextInput.enterText('mia');
    await tester.pump();
    expect(editable.textEditingValue.text, 'mia');
  });
}
