import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

const InputBorderModel outline = InputBorderModel(
  borderType: BorderTypeEnum.outline,
  borderSide: BorderSideModel(
    color: ColorRGBA(r: 0.9, g: 0.894, b: 0.949, a: 1),
    width: 3,
  ),
  cornerRadius: CornerRadius.all(RadiusModel.circular(22)),
);

Future<void> pump(WidgetTester tester, TextFieldNode node) async {
  final registry = NodeRegistry()..setNodes({node.id: node});
  final manager = PassiveNodeTransformerManager(
    registry.getNodeByID,
    (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
  );
  await tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: CodelesslyContext.empty(),
      child: MaterialApp(
        home: Material(
          child: Column(
            children: [
              Builder(
                builder: (context) => manager.buildWidgetFromNode(
                  node,
                  context,
                  settings: const WidgetBuildSettings(debugLabel: 'test'),
                ),
              ),
              const Focus(child: SizedBox(key: Key('elsewhere'))),
            ],
          ),
        ),
      ),
    ),
  );
}

List<BoxShadow> rings(WidgetTester tester) => [
  for (final DecoratedBox box in tester.widgetList<DecoratedBox>(
    find.ancestor(
      of: find.byType(TextField),
      matching: find.byType(DecoratedBox),
    ),
  ))
    if (box.decoration case BoxDecoration(:final List<BoxShadow> boxShadow))
      ...boxShadow,
];

void main() {
  testWidgets('a focus ring shows while the field has focus, keeping it', (
    tester,
  ) async {
    final TextFieldNode node = TextFieldNode(
      id: 'name',
      name: 'Name',
      basicBoxLocal: NodeBox(0, 0, 300, 68),
      properties: TextFieldProperties(
        focusRingColor: const ColorRGBA(r: 0.545, g: 0.424, b: 1, a: 0.25),
        focusRingWidth: 4,
        decoration: InputDecorationModel(
          enabledBorder: outline,
          focusedBorder: outline,
        ),
      ),
    )..parentID = kRootNode;
    await pump(tester, node);
    expect(rings(tester), isEmpty);

    final State before = tester.state(find.byType(EditableText));
    await tester.tap(find.byType(TextField));
    await tester.pump();
    final List<BoxShadow> ring = rings(tester);
    expect(ring, hasLength(1));
    expect(ring.single.spreadRadius, 4);
    expect(ring.single.color.a, closeTo(0.25, 0.01));
    // The ring didn't rebuild the field: it kept its state and its focus.
    final EditableTextState editable = tester.state(find.byType(EditableText));
    expect(editable, same(before));
    expect(editable.widget.focusNode.hasFocus, isTrue);
    tester.testTextInput.enterText('mia');
    await tester.pump();
    expect(editable.textEditingValue.text, 'mia');

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    expect(rings(tester), isEmpty);
  });

  testWidgets('a bound focus ring width switches the ring off', (tester) async {
    final TextFieldNode node =
        TextFieldNode(
            id: 'name',
            name: 'Name',
            basicBoxLocal: NodeBox(0, 0, 300, 68),
            properties: TextFieldProperties(
              focusRingColor: const ColorRGBA(
                r: 0.545,
                g: 0.424,
                b: 1,
                a: 0.25,
              ),
              focusRingWidth: 4,
            ),
          )
          ..parentID = kRootNode
          ..variables['focusRingWidth'] = r'${= 1 > 2 ? 4 : 0}';
    await pump(tester, node);
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(rings(tester), isEmpty);
  });

  testWidgets('a bound border color draws the outline', (tester) async {
    final TextFieldNode node =
        TextFieldNode(
            id: 'name',
            name: 'Name',
            basicBoxLocal: NodeBox(0, 0, 300, 68),
            properties: TextFieldProperties(
              decoration: InputDecorationModel(
                enabledBorder: outline,
                focusedBorder: outline,
              ),
            ),
          )
          ..parentID = kRootNode
          ..variables['decoration.borderColor'] =
              r'${= 1 > 0 ? "#FF5A5F" : "#E6E4F2"}';
    await pump(tester, node);
    final InputDecoration decoration = tester
        .widget<TextField>(find.byType(TextField))
        .decoration!;
    final OutlineInputBorder border =
        decoration.enabledBorder! as OutlineInputBorder;
    expect(border.borderSide.color, const Color(0xFFFF5A5F));
    expect(border.borderSide.width, 3);
  });
}
