import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// Apiary's text wells are containers whose border adds to their padding
// (Flutter's BoxDecoration): a 1.2 px border, 1.8 when focused or in error,
// so the well grows 1.2 px when it shows an error. An InputDecorator draws
// its outline over the content padding, so the field kept one height and
// came out a pixel short in every error state.

InputBorderModel _outline(double width) => InputBorderModel(
  borderType: BorderTypeEnum.outline,
  borderSide: BorderSideModel(width: width),
  cornerRadius: const CornerRadius.all(RadiusModel.circular(10)),
);

TextFieldNode _well({required bool includesBorder, bool error = false}) {
  final TextProp style = TextProp(
    fontSize: 16,
    lineHeight: LineHeight(value: 135, unit: LineHeightUnitEnum.percent),
  );
  return TextFieldNode(
    id: 'field',
    name: 'Field',
    basicBoxLocal: NodeBox(0, 0, 300, 44),
    horizontalFit: SizeFit.expanded,
    verticalFit: SizeFit.shrinkWrap,
    properties: TextFieldProperties(
      inputStyle: style,
      decoration: InputDecorationModel(
        hintText: 'Hint',
        hintStyle: style,
        isDense: true,
        filled: true,
        showCounter: false,
        border: _outline(1.2),
        enabledBorder: _outline(1.2),
        disabledBorder: _outline(1.2),
        focusedBorder: _outline(1.8),
        errorBorder: _outline(1.8),
        focusedErrorBorder: _outline(1.8),
        paddingIncludesBorder: includesBorder,
        contentPadding: EdgeInsetsModel.symmetric(horizontal: 12, vertical: 11),
      ),
    ),
  )
    ..parentID = kRootNode
    ..variables.addAll({if (error) 'error': r'${= true}'});
}

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
            child: SizedBox(
              width: 300,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Builder(
                    builder: (context) => manager.buildWidgetFromNode(
                      node,
                      context,
                      settings: const WidgetBuildSettings(debugLabel: 'test'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

double _height(WidgetTester tester) =>
    tester.getSize(find.byType(TextField)).height;

double _textHeight(WidgetTester tester) =>
    tester.getSize(find.byType(EditableText)).height;

double _textTop(WidgetTester tester) =>
    tester.getTopLeft(find.byType(EditableText)).dy -
    tester.getTopLeft(find.byType(TextField)).dy;

void main() {
  testWidgets('the border adds to the padding', (tester) async {
    await _pump(tester, _well(includesBorder: true));
    expect(tester.takeException(), isNull);
    expect(_height(tester), moreOrLessEquals(2 * 12.2 + _textHeight(tester)));
    expect(_textTop(tester), moreOrLessEquals(12.2));
  });

  testWidgets('a thicker error border makes the field taller', (tester) async {
    await _pump(tester, _well(includesBorder: true, error: true));
    expect(tester.takeException(), isNull);
    expect(_height(tester), moreOrLessEquals(2 * 12.8 + _textHeight(tester)));
  });

  testWidgets('focus thickens the border and grows the field', (tester) async {
    await _pump(tester, _well(includesBorder: true));
    final double before = _height(tester);
    await tester.tap(find.byType(EditableText));
    await tester.pump();
    expect(_height(tester), moreOrLessEquals(before + 1.2));
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    expect(_height(tester), moreOrLessEquals(before));
  });

  testWidgets('without it the border sits over the padding', (tester) async {
    await _pump(tester, _well(includesBorder: false, error: true));
    expect(_height(tester), moreOrLessEquals(2 * 11 + _textHeight(tester)));
  });

  test('an underline only adds below', () {
    final InputDecorationModel d = InputDecorationModel(
      enabledBorder: InputBorderModel(
        borderType: BorderTypeEnum.underline,
        borderSide: BorderSideModel(width: 2),
      ),
      paddingIncludesBorder: true,
    );
    expect(
      PassiveTextFieldWidget.paddingWithBorder(
        const EdgeInsets.all(10),
        d,
        error: false,
        focused: false,
      ),
      const EdgeInsets.fromLTRB(10, 10, 10, 12),
    );
  });

  test('the flag round-trips through JSON and is left out when false', () {
    final InputDecorationModel on = InputDecorationModel(
      paddingIncludesBorder: true,
    );
    expect(on.toJson()['paddingIncludesBorder'], isTrue);
    expect(
      InputDecorationModel.fromJson(on.toJson()).paddingIncludesBorder,
      isTrue,
    );
    expect(
      InputDecorationModel().toJson().containsKey('paddingIncludesBorder'),
      isFalse,
    );
  });
}
