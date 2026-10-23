import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// RowColumnNode.spacing becomes the gap between children of the rendered
// Row/Column, taken out of the main axis before flex children share the
// free space.

RectangleNode rect(
  String id, {
  double width = 50,
  double height = 50,
  SizeFit horizontalFit = SizeFit.fixed,
  SizeFit verticalFit = SizeFit.fixed,
}) => RectangleNode(
  id: id,
  name: id,
  basicBoxLocal: NodeBox(0, 0, width, height),
  horizontalFit: horizontalFit,
  verticalFit: verticalFit,
);

RowColumnNode flex(
  String id,
  List<BaseNode> children, {
  required RowColumnType type,
  required double spacing,
  double width = 300,
  double height = 300,
  SizeFit horizontalFit = SizeFit.fixed,
  SizeFit verticalFit = SizeFit.fixed,
  bool isScrollable = false,
}) {
  for (final child in children) {
    child.parentID = id;
  }
  return RowColumnNode(
    id: id,
    name: id,
    basicBoxLocal: NodeBox(0, 0, width, height),
    children: [for (final child in children) child.id],
    rowColumnType: type,
    horizontalFit: horizontalFit,
    verticalFit: verticalFit,
    isScrollable: isScrollable,
    mainAxisAlignment: MainAxisAlignmentC.start,
    crossAxisAlignment: CrossAxisAlignmentC.start,
    spacing: spacing,
  )..parentID = kRootNode;
}

Finder rectOf(String id) =>
    find.byKey(ValueKey('Rectangle Transformer of $id [$id]'));

/// Pumps [root] at [screen] and returns each node's global rect.
Future<Map<String, Rect>> pump(
  WidgetTester tester,
  BaseNode root,
  List<BaseNode> nodes, {
  Size screen = const Size(1440, 900),
}) async {
  tester.view.physicalSize = screen;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final registry = NodeRegistry()
    ..setNodes({
      for (final node in [root, ...nodes]) node.id: node,
    });
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
                root,
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
  return {
    for (final node in [root, ...nodes])
      if (rectOf(node.id).evaluate().isNotEmpty)
        node.id: tester.getRect(rectOf(node.id)),
  };
}

void main() {
  testWidgets('expanded children share the room left after spacing', (
    tester,
  ) async {
    final children = [
      for (final id in ['a', 'b', 'c'])
        rect(id, width: 100, horizontalFit: SizeFit.expanded),
    ];
    final row = flex(
      'row',
      children,
      type: RowColumnType.row,
      spacing: 20,
      width: 1072,
      height: 50,
    );
    final rects = await pump(tester, row, children);

    expect(rects['row']!.width, 1072);
    for (final id in ['a', 'b', 'c']) {
      expect(rects[id]!.width, 344, reason: id);
    }
    expect(rects['a']!.left, 0);
    expect(rects['b']!.left, 364);
    expect(rects['c']!.left, 728);
  });

  testWidgets('a hugging column is as tall as its children plus gaps', (
    tester,
  ) async {
    final children = [
      rect('a', height: 40),
      rect('b', height: 60),
      rect('c', height: 30),
    ];
    final column = flex(
      'column',
      children,
      type: RowColumnType.column,
      spacing: 12,
      width: 50,
      height: 154,
      verticalFit: SizeFit.shrinkWrap,
    );
    final rects = await pump(tester, column, children);

    expect(rects['column']!.height, 40 + 60 + 30 + 2 * 12);
    expect(rects['b']!.top, 52);
    expect(rects['c']!.top, 124);
  });

  testWidgets('a scrollable row keeps its spacing', (tester) async {
    final children = [
      for (final id in ['a', 'b', 'c', 'd']) rect(id, width: 200),
    ];
    final row = flex(
      'row',
      children,
      type: RowColumnType.row,
      spacing: 16,
      width: 400,
      height: 50,
      isScrollable: true,
    );
    final rects = await pump(tester, row, children);

    expect(rects['b']!.left - rects['a']!.right, 16);
    expect(rects['c']!.left - rects['b']!.right, 16);
  });

  testWidgets('zero spacing leaves children adjacent', (tester) async {
    final children = [rect('a'), rect('b')];
    final row = flex(
      'row',
      children,
      type: RowColumnType.row,
      spacing: 0,
      width: 300,
      height: 50,
    );
    final rects = await pump(tester, row, children);

    expect(rects['b']!.left, rects['a']!.right);
  });
}
