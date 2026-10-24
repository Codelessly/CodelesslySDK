import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// A list of [itemCount] 100x40 rectangles wrapping along [scrollDirection].
List<BaseNode> wrapList({
  AxisC scrollDirection = AxisC.horizontal,
  SizeFit horizontalFit = SizeFit.expanded,
  SizeFit verticalFit = SizeFit.shrinkWrap,
  double width = 300,
  double height = 40,
  int itemCount = 5,
  bool stacked = false,
  SizeFit itemHorizontalFit = SizeFit.fixed,
}) => [
  ListViewNode(
    id: 'list',
    name: 'list',
    basicBoxLocal: NodeBox(0, 0, width, height),
    horizontalFit: horizontalFit,
    verticalFit: verticalFit,
    scrollDirection: scrollDirection,
    padding: const EdgeInsetsModel.all(10),
    properties: ListViewProperties(
      itemCount: itemCount,
      wrap: true,
      stacked: stacked,
      wrapSpacing: 8,
      wrapRunSpacing: 6,
      // Separators are not drawn in a wrapping list.
      hasSeparator: true,
      separatorSpacing: 50,
    ),
    children: ['item'],
  )..parentID = kRootNode,
  RectangleNode(
    id: 'item',
    name: 'item',
    basicBoxLocal: NodeBox(0, 0, 100, 40),
    horizontalFit: itemHorizontalFit,
  )..parentID = 'list',
];

Finder items() =>
    find.byKey(const ValueKey('Rectangle Transformer of item [item]'));

Future<void> pump(
  WidgetTester tester,
  List<BaseNode> nodes, {
  Size screen = const Size(390, 844),
  bool inScrollView = false,
  CodelesslyContext? codelesslyContext,
}) async {
  tester.view.physicalSize = screen;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final registry = NodeRegistry()
    ..setNodes({for (final node in nodes) node.id: node});
  final manager = PassiveNodeTransformerManager(
    registry.getNodeByID,
    (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
  );
  final Widget node = Builder(
    builder: (context) => manager.buildWidgetFromNode(
      nodes.first,
      context,
      settings: const WidgetBuildSettings(debugLabel: 'test'),
    ),
  );
  await tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: codelesslyContext ?? CodelesslyContext.empty(),
      child: MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: inScrollView ? SingleChildScrollView(child: node) : node,
          ),
        ),
      ),
    ),
  );
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('a horizontal wrapping list flows onto further lines', (
    tester,
  ) async {
    await pump(tester, wrapList());
    expect(items(), findsNWidgets(5));
    final Offset list = tester.getTopLeft(find.byType(WrapNodeBox));
    final List<Rect> rects = [
      for (int i = 0; i < 5; i++) tester.getRect(items().at(i)).shift(-list),
    ];
    // 390 wide minus 20 of padding fits three 100-wide items with 8 gaps.
    expect(rects.map((r) => r.topLeft), [
      const Offset(10, 10),
      const Offset(118, 10),
      const Offset(226, 10),
      const Offset(10, 56),
      const Offset(118, 56),
    ]);
    // Items keep their own size.
    for (final r in rects) {
      expect(r.size, const Size(100, 40));
    }
    // The list grows with its runs: two lines, a run gap and the padding.
    expect(
      tester.getSize(find.byType(WrapNodeBox)),
      const Size(390, 10 + 40 + 6 + 40 + 10),
    );
  });

  testWidgets('an expanded item takes its design size in a run', (
    tester,
  ) async {
    await pump(tester, wrapList(itemHorizontalFit: SizeFit.expanded));
    expect(tester.getSize(items().first), const Size(100, 40));
    expect(
      tester.getTopLeft(items().at(3)).dy,
      tester.getTopLeft(items().first).dy + 46,
    );
  });

  testWidgets('a wrapping list in a scroll view has no layout errors', (
    tester,
  ) async {
    await pump(tester, wrapList(), inScrollView: true);
    expect(items(), findsNWidgets(5));
    expect(tester.getSize(find.byType(WrapNodeBox)).height, 106);
  });

  testWidgets('a fixed-height wrapping list scrolls its runs', (tester) async {
    await pump(tester, wrapList(verticalFit: SizeFit.fixed, height: 60));
    expect(tester.getSize(find.byType(WrapNodeBox)), const Size(390, 60));
    expect(
      find.descendant(
        of: find.byType(WrappedItems),
        matching: find.byType(SingleChildScrollView),
      ),
      findsOneWidget,
    );
    expect(items(), findsNWidgets(5));
  });

  testWidgets('a vertical wrapping list starts new columns', (tester) async {
    await pump(
      tester,
      wrapList(
        scrollDirection: AxisC.vertical,
        horizontalFit: SizeFit.shrinkWrap,
        verticalFit: SizeFit.fixed,
        height: 120,
      ),
    );
    final Offset list = tester.getTopLeft(find.byType(WrapNodeBox));
    // 100 of height minus padding fits two 40-high items and a gap.
    expect(tester.getTopLeft(items().at(1)) - list, const Offset(10, 58));
    expect(tester.getTopLeft(items().at(2)) - list, const Offset(116, 10));
  });

  testWidgets('a wrapping list shows one item per item of its data', (
    tester,
  ) async {
    final List<BaseNode> nodes = wrapList();
    final ListViewNode list = nodes.first as ListViewNode;
    list.properties.itemCount = null;
    list.variables['data'] = r'${crates}';
    await pump(
      tester,
      nodes,
      codelesslyContext: CodelesslyContext.empty()
        ..variables['crates'] = Observable(
          VariableData(
            id: 'crates',
            name: 'crates',
            type: VariableType.list,
            value: ['a', 'b', 'c', 'd'],
          ),
        ),
    );
    expect(items(), findsNWidgets(4));
    expect(
      tester.getTopLeft(items().at(3)).dy,
      tester.getTopLeft(items().first).dy + 46,
    );
  });

  testWidgets('stacked wins over wrap', (tester) async {
    await pump(tester, wrapList(stacked: true, height: 100));
    expect(find.byType(StackedItems), findsOneWidget);
    expect(find.byType(WrappedItems), findsNothing);
  });

  testWidgets('WrappedItems keeps item order and alignment', (tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 250,
            child: WrappedItems(
              itemCount: 3,
              spacing: 10,
              alignment: WrapAlignment.center,
              itemBuilder: (context, index) =>
                  SizedBox(width: 100, height: 20, child: Text('$index')),
            ),
          ),
        ),
      ),
    );
    // Two items (210) fit a 250 line, centred: 20 on each side.
    expect(tester.getTopLeft(find.text('0')), const Offset(20, 0));
    expect(tester.getTopLeft(find.text('1')), const Offset(130, 0));
    expect(tester.getTopLeft(find.text('2')), const Offset(75, 20));
  });
}
