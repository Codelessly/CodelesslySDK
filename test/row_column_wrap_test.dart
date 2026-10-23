import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// A row/column with `wrap` on lays its children out like Flutter's Wrap:
// spacing within runs, runSpacing between them. Children a visibility
// formula hides take no space and no gaps.

RectangleNode chip(
  String id, {
  double width = 100,
  double height = 50,
  SizeFit horizontalFit = SizeFit.fixed,
}) => RectangleNode(
  id: id,
  name: id,
  basicBoxLocal: NodeBox(0, 0, width, height),
  horizontalFit: horizontalFit,
);

RowColumnNode wrapNode(
  String id,
  List<BaseNode> children, {
  RowColumnType type = RowColumnType.row,
  double spacing = 8,
  double runSpacing = 8,
  double width = 330,
  double height = 300,
  SizeFit horizontalFit = SizeFit.fixed,
  SizeFit verticalFit = SizeFit.shrinkWrap,
  MainAxisAlignmentC mainAxisAlignment = MainAxisAlignmentC.start,
  CrossAxisAlignmentC crossAxisAlignment = CrossAxisAlignmentC.start,
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
    mainAxisAlignment: mainAxisAlignment,
    crossAxisAlignment: crossAxisAlignment,
    spacing: spacing,
    wrap: true,
    runSpacing: runSpacing,
  )..parentID = kRootNode;
}

T hidden<T extends BaseNode>(T node) =>
    node..variables['visible'] = r'${= 1 == 2}';

Finder rectOf(String id) =>
    find.byKey(ValueKey('Rectangle Transformer of $id [$id]'));

/// Pumps [root] and returns each child's rect relative to the wrap.
Future<Map<String, Rect>> pump(
  WidgetTester tester,
  BaseNode root,
  List<BaseNode> nodes,
) async {
  tester.view.physicalSize = const Size(1440, 900);
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
  final Offset origin = tester.getTopLeft(find.byType(CodelesslyWrap));
  return {
    'wrap': tester.getRect(find.byType(CodelesslyWrap)),
    for (final node in nodes)
      if (rectOf(node.id).evaluate().isNotEmpty)
        node.id: tester.getRect(rectOf(node.id)).shift(-origin),
  };
}

void main() {
  testWidgets('5 chips of 100 with spacing 8 in a 330 row: 3 then 2, and '
      'the row hugs both runs', (tester) async {
    final chips = [for (int i = 0; i < 5; i++) chip('c$i')];
    final rects = await pump(tester, wrapNode('row', chips), chips);

    expect(rects['c0']!.topLeft, const Offset(0, 0));
    expect(rects['c1']!.topLeft, const Offset(108, 0));
    expect(rects['c2']!.topLeft, const Offset(216, 0));
    expect(rects['c3']!.topLeft, const Offset(0, 58));
    expect(rects['c4']!.topLeft, const Offset(108, 58));
    // A fixed 330 wide row, as tall as its two runs and the gap between.
    expect(rects['wrap']!.size, const Size(330, 108));
  });

  testWidgets('a chip a formula hides takes no space and no gap', (
    tester,
  ) async {
    final chips = [for (int i = 0; i < 5; i++) chip('c$i')];
    hidden(chips[1]);
    final rects = await pump(tester, wrapNode('row', chips), chips);

    expect(rects['c0']!.left, 0);
    expect(rects['c2']!.topLeft, const Offset(108, 0));
    expect(rects['c3']!.topLeft, const Offset(216, 0));
    expect(rects['c4']!.topLeft, const Offset(0, 58));
    expect(rects['wrap']!.height, 108);
  });

  testWidgets('alignments place children in runs and runs in the row', (
    tester,
  ) async {
    final chips = [for (int i = 0; i < 5; i++) chip('c$i')];
    final rects = await pump(
      tester,
      wrapNode(
        'row',
        chips,
        height: 200,
        verticalFit: SizeFit.fixed,
        mainAxisAlignment: MainAxisAlignmentC.center,
        crossAxisAlignment: CrossAxisAlignmentC.center,
      ),
      chips,
    );
    // Runs of 316 and 208 centered in 330; 108 of runs centered in 200.
    expect(rects['c0']!.topLeft, const Offset(7, 46));
    expect(rects['c3']!.topLeft, const Offset(61, 104));
    expect(rects['wrap']!.size, const Size(330, 200));
  });

  testWidgets('an expanded chip keeps its design width in a wrap', (
    tester,
  ) async {
    final chips = [
      chip('c0'),
      chip('c1', width: 120, horizontalFit: SizeFit.expanded),
      chip('c2'),
    ];
    final rects = await pump(tester, wrapNode('row', chips), chips);
    expect(rects['c1']!.width, 120);
    expect(rects['c1']!.topLeft, const Offset(108, 0));
    expect(rects['c2']!.topLeft, const Offset(0, 58));
  });

  testWidgets('a wrapping column wraps vertically and hugs its runs', (
    tester,
  ) async {
    final chips = [for (int i = 0; i < 5; i++) chip('c$i', width: 50)];
    final rects = await pump(
      tester,
      wrapNode(
        'col',
        chips,
        type: RowColumnType.column,
        height: 130,
        horizontalFit: SizeFit.shrinkWrap,
        verticalFit: SizeFit.fixed,
      ),
      chips,
    );
    expect(rects['c1']!.topLeft, const Offset(0, 58));
    expect(rects['c2']!.topLeft, const Offset(58, 0));
    expect(rects['c4']!.topLeft, const Offset(116, 0));
    expect(rects['wrap']!.size, const Size(166, 130));
  });

  testWidgets('a scrollable wrapping row scrolls through its runs', (
    tester,
  ) async {
    final chips = [for (int i = 0; i < 5; i++) chip('c$i')];
    final rects = await pump(
      tester,
      wrapNode(
        'row',
        chips,
        height: 80,
        verticalFit: SizeFit.fixed,
        isScrollable: true,
      ),
      chips,
    );
    final scroll = tester.widget<SingleChildScrollView>(
      find.byType(SingleChildScrollView),
    );
    expect(scroll.scrollDirection, Axis.vertical);
    expect(rects['wrap']!.size, const Size(330, 108));
    expect(rects['c3']!.topLeft, const Offset(0, 58));
    expect(
      tester.getSize(find.byType(SingleChildScrollView)),
      const Size(330, 80),
    );
  });

  group('RenderCodelesslyWrap', () {
    Widget box(double width, {bool collapsed = false}) => FlexChildVisibility(
      collapsed: collapsed,
      child: SizedBox(width: collapsed ? 0 : width, height: 50),
    );

    testWidgets('right to left and its intrinsic height', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.rtl,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 330,
              child: CodelesslyWrap(
                spacing: 8,
                runSpacing: 10,
                children: [
                  box(100),
                  box(100, collapsed: true),
                  box(100),
                  box(100),
                  box(100),
                ],
              ),
            ),
          ),
        ),
      );
      final RenderCodelesslyWrap render = tester.renderObject(
        find.byType(CodelesslyWrap),
      );
      expect(render.size, const Size(330, 110));
      expect(render.getMinIntrinsicHeight(330), 110);
      expect(render.getMaxIntrinsicWidth(double.infinity), 4 * 100 + 3 * 8);
      expect(
        render.getDryLayout(const BoxConstraints(maxWidth: 1000)),
        const Size(424, 50),
      );
      final List<Offset> offsets = [
        for (final element in find.byType(SizedBox).evaluate().skip(1))
          (tester
              .renderObject<RenderBox>(find.byWidget(element.widget))
              .localToGlobal(Offset.zero)),
      ];
      // First child at the right edge, the collapsed one takes no space.
      expect(offsets[0], const Offset(230, 0));
      expect(offsets[2], const Offset(122, 0));
      expect(offsets[3], const Offset(14, 0));
      expect(offsets[4], const Offset(230, 60));
    });
  });
}
