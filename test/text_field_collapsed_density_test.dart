import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

const InputBorderModel _none = InputBorderModel(
  borderType: BorderTypeEnum.none,
);

/// A three-line note field that hugs its height, as on the Stillpoint
/// check-out screen: collapsed decoration, no content padding, 16 px text at
/// 145% line height.
TextFieldNode _note({bool collapsed = true}) => TextFieldNode(
  id: 'note',
  name: 'Note',
  basicBoxLocal: NodeBox(0, 0, 300, 40),
  horizontalFit: SizeFit.fixed,
  verticalFit: SizeFit.shrinkWrap,
  properties: TextFieldProperties(
    maxLines: 3,
    minLines: 3,
    inputStyle: TextProp(
      fontSize: 16,
      lineHeight: const LineHeight.percent(145),
    ),
    decoration: InputDecorationModel(
      isCollapsed: collapsed,
      hintText: 'Optional',
      border: _none,
      enabledBorder: _none,
      focusedBorder: _none,
      disabledBorder: _none,
      errorBorder: _none,
      focusedErrorBorder: _none,
      showCounter: false,
      contentPadding: EdgeInsetsModel.zero,
    ),
  ),
);

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
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
  );
  await tester.pump();
}

void main() {
  // Three lines of 16 px at 145%.
  const double threeLines = 3 * 16 * 1.45;

  testWidgets(
    'a collapsed field that hugs its height keeps all its lines under '
    'compact (desktop) density',
    (tester) async {
      await _pump(tester, _note(), VisualDensity.compact);
      expect(
        tester.getSize(find.byType(TextField)).height,
        moreOrLessEquals(threeLines, epsilon: 1),
      );
      expect(
        tester
            .widget<TextField>(find.byType(TextField))
            .decoration!
            .visualDensity,
        VisualDensity.standard,
      );
    },
  );

  testWidgets('it is the same height under standard density', (tester) async {
    await _pump(tester, _note(), VisualDensity.standard);
    expect(
      tester.getSize(find.byType(TextField)).height,
      moreOrLessEquals(threeLines, epsilon: 1),
    );
  });

  testWidgets('a field that is not collapsed is not shrunk by the theme density either', (
    tester,
  ) async {
    await _pump(tester, _note(collapsed: false), VisualDensity.compact);
    expect(
      tester
          .widget<TextField>(find.byType(TextField))
          .decoration!
          .visualDensity,
      VisualDensity.standard,
    );
  });
}
