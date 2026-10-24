import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// A column of [a wrapping chip row, a fixed 40 px box, a text] at 390 wide:
/// the row takes its laid out runs' height and nothing gets extra space,
/// whatever height the row has stored (one run or all of them).
void main() {
  const double chipWidth = 150, chipHeight = 36, gap = 8, columnGap = 12;
  // 2 chips of 150 per run in 390: 3 runs, 3 * 36 + 2 * 8 tall.
  const double runsHeight = 3 * chipHeight + 2 * gap;

  Future<Map<String, Rect>> pump(
    WidgetTester tester, {
    required double storedRowHeight,
    required SizeFit rowVerticalFit,
    double designWidth = 390,
    CrossAxisAlignmentC columnCross = CrossAxisAlignmentC.start,
    CrossAxisAlignmentC rowCross = CrossAxisAlignmentC.start,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final chips = [
      for (int i = 0; i < 6; i++)
        RectangleNode(
          id: 'c$i',
          name: 'c$i',
          basicBoxLocal: NodeBox(0, 0, chipWidth, chipHeight),
        )..parentID = 'chips',
    ];
    final RowColumnNode row = RowColumnNode(
      id: 'chips',
      name: 'chips',
      basicBoxLocal: NodeBox(0, 0, designWidth, storedRowHeight),
      children: [for (final chip in chips) chip.id],
      rowColumnType: RowColumnType.row,
      horizontalFit: SizeFit.expanded,
      verticalFit: rowVerticalFit,
      mainAxisAlignment: MainAxisAlignmentC.start,
      crossAxisAlignment: rowCross,
      spacing: gap,
      wrap: true,
      runSpacing: gap,
    )..parentID = 'col';
    final RectangleNode ruler = RectangleNode(
      id: 'ruler',
      name: 'ruler',
      basicBoxLocal: NodeBox(0, 0, designWidth, 40),
      horizontalFit: SizeFit.expanded,
    )..parentID = 'col';
    const String characters = 'Length ruler';
    final TextNode text = TextNode(
      id: 'text',
      name: 'text',
      basicBoxLocal: NodeBox(0, 0, 200, 20),
      characters: characters,
      textMixedProps: [
        StartEndProp(start: 0, end: characters.length, fontSize: 16),
      ],
    )..parentID = 'col';
    final RowColumnNode column = RowColumnNode(
      id: 'col',
      name: 'col',
      basicBoxLocal: NodeBox(
        0,
        0,
        designWidth,
        storedRowHeight + 40 + 20 + 2 * columnGap,
      ),
      children: ['chips', 'ruler', 'text'],
      rowColumnType: RowColumnType.column,
      horizontalFit: SizeFit.expanded,
      verticalFit: SizeFit.shrinkWrap,
      mainAxisAlignment: MainAxisAlignmentC.start,
      crossAxisAlignment: columnCross,
      spacing: columnGap,
    )..parentID = kRootNode;

    final nodes = <BaseNode>[column, row, ...chips, ruler, text];
    final registry = NodeRegistry()
      ..setNodes({for (final node in nodes) node.id: node});
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
                  column,
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
    Rect rectOf(String id) {
      final Finder byKey = find.byKey(
        ValueKey('Rectangle Transformer of $id [$id]'),
      );
      if (byKey.evaluate().isNotEmpty) return tester.getRect(byKey.first);
      return tester.getRect(find.text(characters));
    }

    return {
      'col': tester.getRect(
        find.byKey(const ValueKey('Rectangle Transformer of col [col]')),
      ),
      'chips': tester.getRect(find.byType(CodelesslyWrap)),
      'c5': rectOf('c5'),
      'ruler': rectOf('ruler'),
      'text': rectOf('text'),
    };
  }

  void expectStacked(Map<String, Rect> r) {
    expect(r['chips']!.top, 0);
    expect(r['chips']!.height, runsHeight);
    expect(r['c5']!.top, 2 * (chipHeight + gap));
    expect(r['ruler']!.top, runsHeight + columnGap);
    expect(r['ruler']!.height, 40);
    expect(r['text']!.top, r['ruler']!.bottom + columnGap);
    expect(r['col']!.height, closeTo(r['text']!.bottom, 1));
  }

  for (final cross in [
    CrossAxisAlignmentC.stretch,
    CrossAxisAlignmentC.center,
  ]) {
    testWidgets('in a column with cross $cross, a row with cross center', (
      tester,
    ) async {
      expectStacked(
        await pump(
          tester,
          storedRowHeight: chipHeight,
          rowVerticalFit: SizeFit.shrinkWrap,
          columnCross: cross,
          rowCross: CrossAxisAlignmentC.center,
        ),
      );
    });
  }

  for (final fit in [SizeFit.shrinkWrap]) {
    for (final stored in [chipHeight, runsHeight]) {
      for (final designWidth in [390.0, 1000.0]) {
        testWidgets('a $fit wrap row storing $stored px, designed at '
            '$designWidth', (tester) async {
          expectStacked(
            await pump(
              tester,
              storedRowHeight: stored,
              rowVerticalFit: fit,
              designWidth: designWidth,
            ),
          );
        });
      }
    }
  }
}
