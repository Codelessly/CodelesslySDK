import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// A child of a fixed width (314 px) in a column whose content box is
// 312 px is clamped to the column, as Flutter's Column clamps a SizedBox:
// 312 px wide at x 0 whatever the cross-axis alignment, with no overflow
// stripes.

Finder _of(String id) =>
    find.byKey(ValueKey('Rectangle Transformer of $id [$id]'));

Future<Rect> _arc(
  WidgetTester tester,
  CrossAxisAlignmentC cross, {
  TextDirection direction = TextDirection.ltr,
  SizeFit arcFit = SizeFit.fixed,
}) async {
  final RowColumnNode column = RowColumnNode(
    id: 'card',
    name: 'card',
    basicBoxLocal: NodeBox(0, 0, 312, 200),
    rowColumnType: RowColumnType.column,
    mainAxisAlignment: MainAxisAlignmentC.start,
    crossAxisAlignment: cross,
    children: const ['arc', 'below'],
  )..parentID = kRootNode;
  final RectangleNode arc = RectangleNode(
    id: 'arc',
    name: 'arc',
    basicBoxLocal: NodeBox(0, 0, 314, 120),
    horizontalFit: arcFit,
  )..parentID = 'card';
  final RectangleNode below = RectangleNode(
    id: 'below',
    name: 'below',
    basicBoxLocal: NodeBox(0, 0, 100, 40),
  )..parentID = 'card';
  final registry = NodeRegistry()
    ..setNodes({
      for (final n in <BaseNode>[column, arc, below]) n.id: n,
    });
  final manager = PassiveNodeTransformerManager(
    registry.getNodeByID,
    (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
  );
  await tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: CodelesslyContext.empty(),
      child: MaterialApp(
        home: Directionality(
          textDirection: direction,
          child: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(20),
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
    ),
  );
  // No overflow report (and so no stripes).
  expect(tester.takeException(), isNull);
  final Rect card = tester.getRect(_of('card'));
  expect(card.width, 312);
  return tester.getRect(_of('arc')).shift(-card.topLeft);
}

void main() {
  testWidgets('centred: a 314 px child of a 312 px column is clamped', (
    tester,
  ) async {
    final Rect arc = await _arc(tester, CrossAxisAlignmentC.center);
    expect(arc.left, 0);
    expect(arc.width, 312);
    // The next child is placed below its 120 px.
    expect(
      tester.getRect(_of('below')).top - tester.getRect(_of('card')).top,
      120,
    );
  });

  testWidgets('at the start: clamped at x 0', (tester) async {
    final Rect arc = await _arc(tester, CrossAxisAlignmentC.start);
    expect(arc.left, 0);
    expect(arc.width, 312);
  });

  testWidgets('at the end: clamped at x 0', (tester) async {
    final Rect arc = await _arc(tester, CrossAxisAlignmentC.end);
    expect(arc.left, 0);
    expect(arc.width, 312);
  });

  testWidgets('right to left: clamped at x 0', (tester) async {
    final Rect arc = await _arc(
      tester,
      CrossAxisAlignmentC.start,
      direction: TextDirection.rtl,
    );
    expect(arc.left, 0);
    expect(arc.width, 312);
  });

  testWidgets('an expanded child still fills the column', (tester) async {
    final Rect arc = await _arc(
      tester,
      CrossAxisAlignmentC.center,
      arcFit: SizeFit.expanded,
    );
    expect(arc.left, 0);
    expect(arc.width, 312);
  });

  testWidgets('stretched, it is as wide as the column', (tester) async {
    final Rect arc = await _arc(tester, CrossAxisAlignmentC.stretch);
    expect(arc.left, 0);
    expect(arc.width, 312);
  });
}
