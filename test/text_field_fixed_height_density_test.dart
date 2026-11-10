import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

const InputBorderModel _outline = InputBorderModel(
  borderType: BorderTypeEnum.outline,
);

/// A one-line code field with an outline border in a fixed-height box, as on
/// the RigWatch pairing screen: 12 px padding around 16 px text.
TextFieldNode _field(double height) => TextFieldNode(
  id: 'code',
  name: 'Code field',
  basicBoxLocal: NodeBox(0, 0, 300, height),
  padding: const EdgeInsetsModel.all(12),
  properties: TextFieldProperties(
    maxLength: 6,
    inputStyle: TextProp(fontSize: 16, lineHeight: const LineHeight.pixels(20)),
    decoration: InputDecorationModel(
      hintText: '000000',
      border: _outline,
      enabledBorder: _outline,
      focusedBorder: _outline,
      disabledBorder: _outline,
      showCounter: false,
    ),
  ),
)..parentID = kRootNode;

Future<void> _pump(
  WidgetTester tester,
  TextFieldNode node,
  VisualDensity density,
) async {
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

/// The height of the box the field's border is drawn around.
double _borderHeight(WidgetTester tester) => tester
    .getSize(
      find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == '_BorderContainer',
      ),
    )
    .height;

void main() {
  // 12 + 20 + 12: the content fills the 44 px box exactly. Desktop's compact
  // density used to take 8 px off the border, leaving a strip of the box's
  // background below it.
  const double height = 44;
  for (final (name, density) in [
    ('compact (desktop)', VisualDensity.compact),
    ('standard', VisualDensity.standard),
  ]) {
    testWidgets(
      'a one-line field that fills a fixed height draws its border at that '
      'height under $name density',
      (tester) async {
        await _pump(tester, _field(height), density);
        expect(tester.takeException(), isNull);
        expect(
          tester.getSize(find.byType(TextField)).height,
          moreOrLessEquals(height),
        );
        expect(_borderHeight(tester), moreOrLessEquals(height));
      },
    );
  }
}
