import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

InputBorderModel _outline(double width) => InputBorderModel(
  borderType: BorderTypeEnum.outline,
  borderSide: BorderSideModel(width: width),
  cornerRadius: const CornerRadius.all(RadiusModel.circular(10)),
);

/// An outlined, dense, filled well that hugs its height, as Apiary's
/// generator writes it: 16 px text at a 1.35 line height, padded 12 x
/// [vertical], [lines] lines.
TextFieldNode _well({
  required double vertical,
  int lines = 1,
  double lineHeight = 135,
}) {
  final TextProp style = TextProp(
    fontSize: 16,
    lineHeight: LineHeight(value: lineHeight, unit: LineHeightUnitEnum.percent),
  );
  return TextFieldNode(
    id: 'field',
    name: 'Field',
    basicBoxLocal: NodeBox(0, 0, 300, 44),
    horizontalFit: SizeFit.expanded,
    verticalFit: SizeFit.shrinkWrap,
    properties: TextFieldProperties(
      inputStyle: style,
      maxLines: lines,
      minLines: lines > 1 ? lines : null,
      textAlignVertical: lines > 1
          ? TextAlignVerticalEnum.top
          : TextAlignVerticalEnum.center,
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
        contentPadding: EdgeInsetsModel.symmetric(
          horizontal: 12,
          vertical: vertical,
        ),
      ),
    ),
  )..parentID = kRootNode;
}

Future<void> _pump(
  WidgetTester tester,
  TextFieldNode node, {
  VisualDensity? density,
}) async {
  final registry = NodeRegistry()..setNodes({node.id: node});
  final manager = PassiveNodeTransformerManager(
    registry.getNodeByID,
    (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
  );
  await tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: CodelesslyContext.empty(),
      child: MaterialApp(
        theme: ThemeData(visualDensity: density),
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

/// The height of the text's lines (the test font snaps 21.6 to 22).
double _textHeight(WidgetTester tester) =>
    tester.getSize(find.byType(EditableText)).height;

void main() {
  // The desktop default (compact) used to take 8 px off every field, on the
  // published web app and on the design canvas alike.
  for (final (name, density) in [
    ('compact (desktop)', VisualDensity.compact),
    ('standard', VisualDensity.standard),
    ('comfortable', VisualDensity.comfortable),
  ]) {
    testWidgets('a hugging one-line field is padding + one line tall '
        'under $name density', (tester) async {
      await _pump(tester, _well(vertical: 11), density: density);
      expect(tester.takeException(), isNull);
      expect(_textHeight(tester), closeTo(16 * 1.35, 0.5));
      expect(_height(tester), moreOrLessEquals(11 + _textHeight(tester) + 11));
      expect(_height(tester), closeTo(43.6, 0.5));
    });

    testWidgets('a hugging 3-line field is padding + three lines tall '
        'under $name density', (tester) async {
      await _pump(tester, _well(vertical: 10, lines: 3), density: density);
      expect(tester.takeException(), isNull);
      expect(_textHeight(tester), closeTo(3 * 16 * 1.35, 1.5));
      expect(_height(tester), moreOrLessEquals(10 + _textHeight(tester) + 10));
      expect(_height(tester), closeTo(84.8, 1.5));
    });
  }

  testWidgets('every platform measures a hugging field the same', (
    tester,
  ) async {
    await _pump(tester, _well(vertical: 11));
    expect(_height(tester), closeTo(43.6, 0.5));
  }, variant: TargetPlatformVariant.all());

  testWidgets('the line height sets a hugging field\'s height', (tester) async {
    await _pump(tester, _well(vertical: 11, lineHeight: 200));
    expect(_textHeight(tester), closeTo(32, 0.5));
    expect(_height(tester), closeTo(11 + 32 + 11, 0.5));

    await _pump(tester, _well(vertical: 10, lines: 3, lineHeight: 200));
    expect(_height(tester), closeTo(10 + 3 * 32 + 10, 1.5));
  });

  testWidgets('an outline border is drawn inside the content padding, as in '
      'Flutter: a 46 px well needs 12.2 px padding with a 1.2 px border', (
    tester,
  ) async {
    await _pump(tester, _well(vertical: 12.2), density: VisualDensity.compact);
    expect(_height(tester), closeTo(12.2 + 21.6 + 12.2, 0.5));
  });
}
