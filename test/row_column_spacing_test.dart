import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// RowColumnNode.spacing becomes the gap between children of the rendered
// Row/Column, taken out of the main axis before flex children share the
// free space. Children a visibility formula hides collapse and get no gaps.

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

/// [node] with a visibility formula that is false.
T hidden<T extends BaseNode>(T node) =>
    node..variables['visible'] = r'${= 1 == 2}';

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
  testWidgets('a child a formula hides gets no gaps', (tester) async {
    final children = [
      rect('a', height: 40),
      hidden(rect('b', height: 60)),
      rect('c', height: 30),
    ];
    final column = flex(
      'column',
      children,
      type: RowColumnType.column,
      spacing: 20,
      width: 50,
      height: 300,
    );
    final rects = await pump(tester, column, children);

    expect(rects['c']!.top, rects['a']!.bottom + 20);
  });

  testWidgets('a hugging column hugs the gaps of its shown children only', (
    tester,
  ) async {
    final children = [
      hidden(rect('a', height: 40)),
      rect('b', height: 60),
      hidden(rect('c', height: 30)),
      rect('d', height: 30),
      hidden(rect('e', height: 30)),
    ];
    final column = flex(
      'column',
      children,
      type: RowColumnType.column,
      spacing: 12,
      width: 50,
      height: 300,
      verticalFit: SizeFit.shrinkWrap,
    );
    final rects = await pump(tester, column, children);

    expect(rects['b']!.top, 0);
    expect(rects['d']!.top, 60 + 12);
    expect(rects['column']!.height, 60 + 12 + 30);
  });

  testWidgets('expanded children share the gaps of the shown ones only', (
    tester,
  ) async {
    final children = [
      rect('a', width: 100, horizontalFit: SizeFit.expanded),
      hidden(rect('b', width: 100, horizontalFit: SizeFit.expanded)),
      rect('c', width: 100, horizontalFit: SizeFit.expanded),
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

    expect(rects['a']!.width, 526);
    expect(rects['c']!.width, 526);
    expect(rects['c']!.left, 546);
  });

  group('RenderCodelesslyFlex', () {
    Widget box(String id, double extent) =>
        SizedBox(key: ValueKey(id), width: extent, height: extent);

    Future<void> pumpFlex(WidgetTester tester, Widget flex) =>
        tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Align(alignment: Alignment.topLeft, child: flex),
          ),
        );

    List<Widget> children() => [
      FlexChildVisibility(collapsed: true, child: box('h0', 0)),
      FlexChildVisibility(collapsed: false, child: box('a', 30)),
      FlexChildVisibility(collapsed: true, child: box('h1', 0)),
      FlexChildVisibility(collapsed: false, child: box('b', 40)),
      FlexChildVisibility(collapsed: true, child: box('h2', 0)),
    ];

    Rect rectOfKey(WidgetTester tester, String id) =>
        tester.getRect(find.byKey(ValueKey(id)));

    testWidgets('right to left, gaps only between shown children', (
      tester,
    ) async {
      await pumpFlex(
        tester,
        CodelesslyFlex(
          direction: Axis.horizontal,
          textDirection: TextDirection.rtl,
          mainAxisSize: MainAxisSize.min,
          spacing: 10,
          children: children(),
        ),
      );
      final Size size = tester.getSize(find.byType(CodelesslyFlex));
      expect(size.width, 30 + 10 + 40);
      expect(rectOfKey(tester, 'a').left, 50);
      expect(rectOfKey(tester, 'b').left, 0);
    });

    testWidgets('intrinsic size counts gaps between shown children only', (
      tester,
    ) async {
      await pumpFlex(
        tester,
        IntrinsicHeight(
          child: CodelesslyFlex(
            direction: Axis.vertical,
            spacing: 10,
            children: children(),
          ),
        ),
      );
      final Size size = tester.getSize(find.byType(CodelesslyFlex));
      expect(size.height, 30 + 10 + 40);
      expect(rectOfKey(tester, 'b').top, 40);
    });

    testWidgets('bottom to top, end aligned', (tester) async {
      await pumpFlex(
        tester,
        SizedBox(
          height: 200,
          child: CodelesslyFlex(
            direction: Axis.vertical,
            verticalDirection: VerticalDirection.up,
            mainAxisAlignment: MainAxisAlignment.end,
            spacing: 10,
            children: children(),
          ),
        ),
      );
      // Up and end-aligned: packed at the top, the last child first.
      expect(rectOfKey(tester, 'b').top, 0);
      expect(rectOfKey(tester, 'a').top, 50);
    });

    testWidgets('showing a child again gives it its gap', (tester) async {
      Widget build(bool collapsed) => CodelesslyFlex(
        direction: Axis.horizontal,
        mainAxisSize: MainAxisSize.min,
        spacing: 10,
        children: [
          FlexChildVisibility(collapsed: false, child: box('a', 30)),
          FlexChildVisibility(collapsed: collapsed, child: box('b', 0)),
        ],
      );
      await pumpFlex(tester, build(true));
      expect(tester.getSize(find.byType(CodelesslyFlex)).width, 30);
      await pumpFlex(tester, build(false));
      expect(tester.getSize(find.byType(CodelesslyFlex)).width, 40);
    });
  });
}
