import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

TextNode _text(String id, String chars, double size) => TextNode(
  id: id,
  name: id,
  basicBoxLocal: NodeBox(0, 0, 60, size * 1.2),
  data: chars,
  horizontalFit: SizeFit.shrinkWrap,
  verticalFit: SizeFit.shrinkWrap,
  textMixedProps: [StartEndProp(start: 0, end: chars.length, fontSize: size)],
)..parentID = 'row';

void main() {
  testWidgets('a baseline row lines its texts up on their baselines', (
    tester,
  ) async {
    final big = _text('big', '3', 40);
    final small = _text('small', 'WAITING', 13);
    final row = RowColumnNode(
      id: 'row',
      name: 'Stat',
      basicBoxLocal: NodeBox(0, 0, 160, 48),
      children: const ['big', 'small'],
      rowColumnType: RowColumnType.row,
      horizontalFit: SizeFit.shrinkWrap,
      verticalFit: SizeFit.shrinkWrap,
      crossAxisAlignment: CrossAxisAlignmentC.baseline,
    )..parentID = kRootNode;
    final registry = NodeRegistry()
      ..setNodes({
        for (final n in <BaseNode>[row, big, small]) n.id: n,
      });
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: CodelesslyContext.empty(),
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (context) => manager.buildWidgetFromNode(
                  row,
                  context,
                  settings: const WidgetBuildSettings(debugLabel: 'test'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    double baselineOf(String text) {
      final RenderBox box = tester.renderObject(find.text(text));
      // Reading a baseline outside layout is only allowed while checking.
      RenderObject.debugCheckingIntrinsics = true;
      try {
        return box.localToGlobal(Offset.zero).dy +
            box.getDistanceToBaseline(TextBaseline.alphabetic)!;
      } finally {
        RenderObject.debugCheckingIntrinsics = false;
      }
    }

    expect(baselineOf('3'), closeTo(baselineOf('WAITING'), 0.5));
  });
}
