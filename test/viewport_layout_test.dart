import 'dart:math' as math;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/transformers/utils/node_state_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

const List<Size> screens = [Size(390, 844), Size(834, 1194), Size(1440, 900)];

/// Where the node under test is placed.
enum Host {
  /// Directly in the route: tight screen constraints.
  tight,

  /// In a centred Scaffold body: loose, bounded constraints.
  loose,

  /// In a vertical scroll view: an unbounded height, like a list nested in a
  /// scrolling column or list.
  scroll,
}

RectangleNode rect(
  String id,
  String parentID, {
  double width = 100,
  double height = 50,
  SizeFit horizontalFit = SizeFit.fixed,
  SizeFit verticalFit = SizeFit.fixed,
}) => RectangleNode(
  id: id,
  name: id,
  basicBoxLocal: NodeBox(0, 0, width, height),
  horizontalFit: horizontalFit,
  verticalFit: verticalFit,
)..parentID = parentID;

ListViewNode list({
  String id = 'list',
  String parentID = kRootNode,
  String item = 'item',
  int? itemCount = 3,
  double width = 300,
  double height = 400,
  SizeFit horizontalFit = SizeFit.fixed,
  SizeFit verticalFit = SizeFit.fixed,
  AxisC scrollDirection = AxisC.vertical,
  double? itemExtent,
}) => ListViewNode(
  id: id,
  name: id,
  basicBoxLocal: NodeBox(0, 0, width, height),
  horizontalFit: horizontalFit,
  verticalFit: verticalFit,
  scrollDirection: scrollDirection,
  properties: ListViewProperties(itemCount: itemCount, itemExtent: itemExtent),
  children: [item],
)..parentID = parentID;

GridViewNode grid({
  int? itemCount = 8,
  int crossAxisCount = 4,
  double width = 1440,
  double height = 900,
  SizeFit horizontalFit = SizeFit.expanded,
  SizeFit verticalFit = SizeFit.expanded,
}) => GridViewNode(
  id: 'grid',
  name: 'grid',
  basicBoxLocal: NodeBox(0, 0, width, height),
  horizontalFit: horizontalFit,
  verticalFit: verticalFit,
  properties: GridViewProperties(
    itemCount: itemCount,
    gridDelegate: FixedCrossAxisCountGridDelegateProperties(
      crossAxisCount: crossAxisCount,
    ),
  ),
  children: ['item'],
)..parentID = kRootNode;

PageViewNode page({
  SizeFit horizontalFit = SizeFit.shrinkWrap,
  SizeFit verticalFit = SizeFit.shrinkWrap,
}) => PageViewNode(
  id: 'page',
  name: 'page',
  basicBoxLocal: NodeBox(0, 0, 300, 400),
  horizontalFit: horizontalFit,
  verticalFit: verticalFit,
  properties: PageViewProperties(itemCount: 3),
  children: ['item'],
)..parentID = kRootNode;

Finder rectOf(String id) =>
    find.byKey(ValueKey('Rectangle Transformer of $id [$id]'));

/// Builds [root] (with [nodes] in the registry) at [screen] in [host] and
/// fails on any layout error.
Future<void> pump(
  WidgetTester tester,
  Size screen,
  Host host,
  BaseNode root,
  List<BaseNode> nodes, {
  CodelesslyContext? codelesslyContext,
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
  final Widget node = Builder(
    builder: (context) => manager.buildWidgetFromNode(
      root,
      context,
      settings: const WidgetBuildSettings(debugLabel: 'test'),
    ),
  );
  await tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: codelesslyContext ?? CodelesslyContext.empty(),
      child: MaterialApp(
        home: switch (host) {
          Host.tight => node,
          Host.loose => Scaffold(body: Center(child: node)),
          Host.scroll => Scaffold(body: SingleChildScrollView(child: node)),
        },
      ),
    ),
  );
  expect(tester.takeException(), isNull, reason: '$host at $screen');
}

/// Expects the viewport at [size], or at the screen size when the tight
/// host forces it.
void expectSize(WidgetTester tester, Size screen, Host host, Size size) =>
    expect(viewportSize(tester), host == Host.tight ? screen : size);

Size viewportSize(WidgetTester tester) =>
    tester.getSize(find.byType(ViewportNodeBox).first);

/// Expects [finder]'s first box to have an area and to lie on screen
/// horizontally.
void expectVisible(WidgetTester tester, Finder finder, Size screen) {
  final Rect box = tester.getRect(finder.first);
  expect(box.width, greaterThan(0));
  expect(box.height, greaterThan(0));
  expect(box.left, greaterThanOrEqualTo(-0.01));
  expect(box.right, lessThanOrEqualTo(screen.width + 0.01));
}

void forEachLayout(
  String description,
  Future<void> Function(WidgetTester tester, Size screen, Host host) body,
) {
  for (final Size screen in screens) {
    for (final Host host in Host.values) {
      testWidgets(
        '$description (${screen.width.toInt()}, ${host.name})',
        (tester) => body(tester, screen, host),
      );
    }
  }
}

void main() {
  group('ViewportLayout', () {
    BoxConstraints unboundedHeight(double width) =>
        BoxConstraints(maxWidth: width);

    test('expanded fills when bounded, else takes the design size', () {
      final node = list(
        horizontalFit: SizeFit.expanded,
        verticalFit: SizeFit.expanded,
      );
      expect(
        ViewportLayout.resolve(
          node: node,
          scrollDirection: AxisC.vertical,
          canShrinkWrap: true,
          constraints: BoxConstraints.loose(const Size(390, 844)),
        ),
        const ViewportLayout(
          width: double.infinity,
          height: double.infinity,
          shrinkWrap: false,
        ),
      );
      expect(
        ViewportLayout.resolve(
          node: node,
          scrollDirection: AxisC.vertical,
          canShrinkWrap: true,
          constraints: unboundedHeight(390),
        ),
        const ViewportLayout(
          width: double.infinity,
          height: 400,
          shrinkWrap: false,
        ),
      );
    });

    test('shrinkWrap wraps only a known number of items', () {
      final node = list(verticalFit: SizeFit.shrinkWrap);
      for (final constraints in [
        unboundedHeight(390),
        BoxConstraints.loose(const Size(390, 844)),
      ]) {
        expect(
          ViewportLayout.resolve(
            node: node,
            scrollDirection: AxisC.vertical,
            canShrinkWrap: true,
            constraints: constraints,
          ),
          const ViewportLayout(width: 300, height: null, shrinkWrap: true),
        );
        expect(
          ViewportLayout.resolve(
            node: node,
            scrollDirection: AxisC.vertical,
            canShrinkWrap: false,
            constraints: constraints,
          ),
          const ViewportLayout(width: 300, height: 400, shrinkWrap: false),
        );
      }
    });

    test('the cross axis is bounded by the design size when unbounded', () {
      final node = list(
        scrollDirection: AxisC.horizontal,
        horizontalFit: SizeFit.expanded,
        verticalFit: SizeFit.expanded,
      );
      expect(
        ViewportLayout.resolve(
          node: node,
          scrollDirection: AxisC.horizontal,
          canShrinkWrap: true,
          constraints: unboundedHeight(390),
        ),
        const ViewportLayout(
          width: double.infinity,
          height: 400,
          shrinkWrap: false,
        ),
      );
    });
  });

  group('subtreeBlocksIntrinsics', () {
    test('finds a viewport or scroll view below a node', () {
      final row = RowColumnNode(
        id: 'row',
        name: 'row',
        basicBoxLocal: NodeBox(0, 0, 300, 100),
        rowColumnType: RowColumnType.row,
        children: ['col'],
      );
      final col = RowColumnNode(
        id: 'col',
        name: 'col',
        basicBoxLocal: NodeBox(0, 0, 300, 100),
        rowColumnType: RowColumnType.column,
        children: ['inner'],
      );
      final inner = list(id: 'inner', parentID: 'col');
      final leaf = rect('leaf', 'row');
      final nodes = <String, BaseNode>{
        for (final node in [row, col, inner, leaf]) node.id: node,
      };
      BaseNode getNode(String id) => nodes[id]!;

      expect(subtreeBlocksIntrinsics(row, getNode), isTrue);
      expect(subtreeBlocksIntrinsics(inner, getNode), isTrue);
      expect(subtreeBlocksIntrinsics(leaf, getNode), isFalse);
      col.children = ['leaf'];
      expect(subtreeBlocksIntrinsics(row, getNode), isFalse);
      col.isScrollable = true;
      expect(subtreeBlocksIntrinsics(row, getNode), isTrue);
    });
  });

  group('ListView', () {
    forEachLayout('expanded list fills, or takes its design height', (
      tester,
      screen,
      host,
    ) async {
      await pump(
        tester,
        screen,
        host,
        list(horizontalFit: SizeFit.expanded, verticalFit: SizeFit.expanded),
        [rect('item', 'list')],
      );
      final Size size = viewportSize(tester);
      expect(size.width, screen.width);
      expect(size.height, host == Host.scroll ? 400 : screen.height);
      expectVisible(tester, rectOf('item'), screen);
    });

    forEachLayout('shrinkWrap list sizes to its items', (
      tester,
      screen,
      host,
    ) async {
      await pump(tester, screen, host, list(verticalFit: SizeFit.shrinkWrap), [
        rect('item', 'list'),
      ]);
      expectSize(tester, screen, host, const Size(300, 150));
      expect(rectOf('item'), findsNWidgets(3));
    });

    forEachLayout('endless shrinkWrap list takes its design height', (
      tester,
      screen,
      host,
    ) async {
      await pump(
        tester,
        screen,
        host,
        list(itemCount: null, verticalFit: SizeFit.shrinkWrap),
        [rect('item', 'list')],
      );
      expectSize(tester, screen, host, const Size(300, 400));
    });

    forEachLayout('horizontal expanded list is bounded on its cross axis', (
      tester,
      screen,
      host,
    ) async {
      await pump(
        tester,
        screen,
        host,
        list(
          scrollDirection: AxisC.horizontal,
          horizontalFit: SizeFit.expanded,
          verticalFit: SizeFit.expanded,
        ),
        [rect('item', 'list')],
      );
      final Size size = viewportSize(tester);
      expect(size.width, screen.width);
      expect(size.height, host == Host.scroll ? 400 : screen.height);
      expectVisible(tester, rectOf('item'), screen);
    });

    forEachLayout('items keep their own width and design extent', (
      tester,
      screen,
      host,
    ) async {
      await pump(tester, screen, host, list(horizontalFit: SizeFit.expanded), [
        rect('item', 'list', verticalFit: SizeFit.expanded),
      ]);
      final Rect listBox = tester.getRect(find.byType(ViewportNodeBox));
      final Rect item = tester.getRect(rectOf('item').first);
      // Fixed width, centred like the editor; expanded height takes the
      // design height instead of an unbounded one.
      expect(item.size, const Size(100, 50));
      expect(item.center.dx, closeTo(listBox.center.dx, 0.01));
      expect(item.top, listBox.top);
    });

    forEachLayout('expanded item fills the list width', (
      tester,
      screen,
      host,
    ) async {
      await pump(
        tester,
        screen,
        host,
        list(horizontalFit: SizeFit.expanded, itemExtent: 80),
        [rect('item', 'list', horizontalFit: SizeFit.expanded)],
      );
      final Rect item = tester.getRect(rectOf('item').first);
      expect(item.size, Size(screen.width, 80));
    });

    forEachLayout('list nested in a list item lays out', (
      tester,
      screen,
      host,
    ) async {
      await pump(
        tester,
        screen,
        host,
        list(
          horizontalFit: SizeFit.expanded,
          verticalFit: SizeFit.expanded,
          item: 'inner',
        ),
        [
          list(
            id: 'inner',
            parentID: 'list',
            scrollDirection: AxisC.horizontal,
            horizontalFit: SizeFit.expanded,
            verticalFit: SizeFit.expanded,
            itemCount: 5,
            width: 300,
            height: 100,
          ),
          rect('item', 'inner', width: 80, height: 80),
        ],
      );
      final Rect inner = tester.getRect(find.byType(ViewportNodeBox).at(1));
      expect(inner.size, Size(screen.width, 100));
      expectVisible(tester, rectOf('item'), screen);
    });
  });

  group('GridView', () {
    forEachLayout('expanded grid fills, or takes its design height', (
      tester,
      screen,
      host,
    ) async {
      await pump(tester, screen, host, grid(), [
        rect('item', 'grid', width: 360, height: 360),
      ]);
      final Size size = viewportSize(tester);
      expect(size.width, screen.width);
      expect(size.height, host == Host.scroll ? 900 : screen.height);
      expectVisible(tester, rectOf('item'), screen);
    });

    forEachLayout('a fixed cross axis count is kept at every width', (
      tester,
      screen,
      host,
    ) async {
      await pump(tester, screen, host, grid(), [
        rect('item', 'grid', width: 360, height: 360),
      ]);
      final Rect cell = tester.getRect(rectOf('item').first);
      expect(cell.width, closeTo(screen.width / 4, 0.01));
      expect(cell.height, cell.width);
    });

    forEachLayout('cells divide the grid width, not the design box', (
      tester,
      screen,
      host,
    ) async {
      // The grid the build scripts send: a 100 wide design box.
      final GridViewNode node =
          NodeJsonConverter().fromJson({
                  'type': 'gridView',
                  'id': 'grid',
                  'name': 'Vehicle grid',
                  'basicBoxLocal': [0, 0, 100, 100],
                  'horizontalFit': 'expanded',
                  'verticalFit': 'shrinkWrap',
                  'isScrollable': false,
                  'allowedTypes': [],
                  'deniedTypes': ['gridView'],
                  'children': ['item'],
                  'properties': {
                    'itemCount': 4,
                    'gridDelegate': {
                      'type': 'fixedCrossAxisCount',
                      'crossAxisCount': 2,
                      'mainAxisSpacing': 16,
                      'crossAxisSpacing': 16,
                      'mainAxisExtent': 130,
                    },
                  },
                })!
                as GridViewNode
            ..parentID = kRootNode;
      await pump(tester, screen, host, node, [
        rect('item', 'grid', horizontalFit: SizeFit.expanded),
      ]);
      final List<Rect> cells = [
        for (final element in rectOf('item').evaluate())
          tester.getRect(find.byWidget(element.widget)),
      ];
      expect(cells, hasLength(4));
      for (final Rect cell in cells) {
        expect(cell.width, closeTo((screen.width - 16) / 2, 0.01));
        expect(cell.height, 130);
      }
      expect(cells[1].left - cells[0].right, closeTo(16, 0.01));
    });

    forEachLayout('a grid node with rows sized to its items', (
      tester,
      screen,
      host,
    ) async {
      final GridViewNode node = grid(
        crossAxisCount: 2,
        width: 390,
        height: 300,
        verticalFit: SizeFit.shrinkWrap,
        itemCount: 4,
      );
      node.properties.gridDelegate
        ..mainAxisExtent = 130
        ..shrinkWrapRows = true;
      await pump(tester, screen, host, node, [
        rect('item', 'grid', height: 70, horizontalFit: SizeFit.expanded),
      ]);
      final Rect cell = tester.getRect(rectOf('item').first);
      expect(cell.width, closeTo(screen.width / 2, 0.01));
      expect(cell.height, 70);
      if (host != Host.tight) {
        expect(viewportSize(tester), Size(screen.width, 140));
      }
    });

    for (final bool intrinsicRows in [true, false]) {
      testWidgets('rows sized to their content'
          '${intrinsicRows ? ' stretch their cells' : ''}', (tester) async {
        const List<double> heights = [100, 150, 80, 60, 120];
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: SizedBox(
                width: 316,
                child: GridViewBuilder(
                  shrinkWrap: true,
                  itemCount: heights.length,
                  gridDelegate: FixedCrossAxisCountGridDelegateProperties(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 16,
                    mainAxisExtent: 130,
                    shrinkWrapRows: true,
                  ),
                  intrinsicRows: intrinsicRows,
                  scrollDirection: Axis.vertical,
                  reverse: false,
                  clipBehavior: Clip.none,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.manual,
                  itemBuilder: (context, index) =>
                      SizedBox(key: ValueKey(index), height: heights[index]),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        Rect cell(int index) => tester.getRect(find.byKey(ValueKey(index)));
        // Each row is as tall as its tallest item: 150, 80, 120.
        expect(
          tester.getSize(find.byType(GridViewBuilder)).height,
          150 + 10 + 80 + 10 + 120,
        );
        expect(cell(0).width, 150);
        expect(cell(1).left - cell(0).right, 16);
        expect(cell(2).top, cell(0).top + 150 + 10);
        expect(cell(4).top, cell(2).top + 80 + 10);
        expect(cell(0).height, intrinsicRows ? 150 : 100);
        expect(cell(3).height, intrinsicRows ? 80 : 60);
      });
    }

    forEachLayout('shrinkWrap grid sizes to its rows', (
      tester,
      screen,
      host,
    ) async {
      await pump(
        tester,
        screen,
        host,
        grid(
          crossAxisCount: 2,
          width: 390,
          height: 300,
          horizontalFit: SizeFit.fixed,
          verticalFit: SizeFit.shrinkWrap,
          itemCount: 4,
        ),
        [rect('item', 'grid', width: 195, height: 195)],
      );
      // 2 rows of square 195 cells.
      expectSize(tester, screen, host, const Size(390, 390));
    });
  });

  group('PageView', () {
    forEachLayout('wrapping page view takes its design size', (
      tester,
      screen,
      host,
    ) async {
      await pump(tester, screen, host, page(), [
        rect('item', 'page', width: 300, height: 400),
      ]);
      expectSize(tester, screen, host, const Size(300, 400));
      expectVisible(tester, rectOf('item'), screen);
    });

    forEachLayout('expanded page view fills, or takes its design height', (
      tester,
      screen,
      host,
    ) async {
      await pump(
        tester,
        screen,
        host,
        page(horizontalFit: SizeFit.expanded, verticalFit: SizeFit.expanded),
        [rect('item', 'page', width: 300, height: 400)],
      );
      final Size size = viewportSize(tester);
      expect(size.width, screen.width);
      expect(size.height, host == Host.scroll ? 400 : screen.height);
    });
  });

  group('endless lists build a bounded number of items', () {
    int built(WidgetTester tester) =>
        find.byType(IndexedItemProvider, skipOffstage: false).evaluate().length;

    /// The list's main extent as laid out: the screen in the tight host,
    /// else the design height.
    double viewportOf(Size screen, Host host, double design) =>
        host == Host.tight ? screen.height : design;

    test('runLimit covers the viewport and cache at the design extent', () {
      int limit(double estimate) => EndlessList.runLimit(
        viewport: 400,
        cacheExtent: 250,
        estimatedItemExtent: estimate,
      );
      expect(limit(50), 18);
      expect(limit(0), 900);
      expect(limit(0.01), 900);
    });

    test('a list ends only after a full run of items under a pixel', () {
      final extents = ItemExtents();
      for (var i = 0; i < 6; i++) {
        extents.record(i, i == 2 ? 30 : 0);
      }
      expect(EndlessList.endsAt(2, extents, 3), isFalse);
      expect(EndlessList.endsAt(5, extents, 3), isFalse);
      expect(EndlessList.endsAt(6, extents, 3), isTrue);
      expect(EndlessList.endsAt(6, extents, 4), isFalse);
      extents.forget(4);
      expect(EndlessList.endsAt(6, extents, 3), isFalse);
    });

    forEachLayout('zero-height items', (tester, screen, host) async {
      await pump(tester, screen, host, list(itemCount: null), [
        rect('item', 'list', height: 0),
      ]);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final double viewport = viewportOf(screen, host, 400);
      expect(built(tester), greaterThan(0));
      expect(built(tester), lessThanOrEqualTo(viewport + 2 * 250 + 1));
    });

    forEachLayout('items hidden by a visibility formula', (
      tester,
      screen,
      host,
    ) async {
      final codelesslyContext = CodelesslyContext.empty()
        ..nodeValues['item'] = Observable<List<ValueModel>>([
          const BoolValue(name: 'visible', value: false),
        ]);
      await pump(tester, screen, host, list(itemCount: null), [
        rect('item', 'list'),
      ], codelesslyContext: codelesslyContext);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final double viewport = viewportOf(screen, host, 400);
      // A few viewports' worth of the 50 px design extent.
      expect(built(tester), lessThanOrEqualTo((viewport + 500) / 50 + 1));
    });

    forEachLayout('visible items keep scrolling without end', (
      tester,
      screen,
      host,
    ) async {
      await pump(tester, screen, host, list(itemCount: null), [
        rect('item', 'list'),
      ]);
      await tester.pumpAndSettle();
      final double viewport = viewportOf(screen, host, 400);
      // The viewport is covered.
      expect(built(tester) * 50, greaterThanOrEqualTo(viewport));
      // Scroll like a finger does, a little per frame.
      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(find.byType(ListView)),
      );
      for (var i = 0; i < 100; i++) {
        await gesture.moveBy(const Offset(0, -50));
        await tester.pump();
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // 5000 px down, items still fill the viewport.
      final Iterable<int> indices = tester
          .widgetList<IndexedItemProvider>(
            find.byType(IndexedItemProvider, skipOffstage: false),
          )
          .map((provider) => provider.item.index);
      expect(indices.reduce(math.max) * 50, greaterThan(5000 + viewport));
    });

    forEachLayout('grid with zero-height and hidden items', (
      tester,
      screen,
      host,
    ) async {
      final codelesslyContext = CodelesslyContext.empty()
        ..nodeValues['item'] = Observable<List<ValueModel>>([
          const BoolValue(name: 'visible', value: false),
        ]);
      await pump(
        tester,
        screen,
        host,
        grid(itemCount: null, crossAxisCount: 2, width: 390, height: 844),
        [rect('item', 'grid', width: 195, height: 0)],
        codelesslyContext: codelesslyContext,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // Cells keep their delegate size, so only the rows that cover the
      // viewport and cache are built.
      final double viewport = viewportOf(screen, host, 844);
      final double cell = screen.width / (screen.width / 195).floor();
      final int columns = (screen.width / 195).floor();
      expect(
        built(tester),
        lessThanOrEqualTo(((viewport + 500) / cell).ceil() * columns + columns),
      );
    });

    forEachLayout('page view with zero-height and hidden items', (
      tester,
      screen,
      host,
    ) async {
      final codelesslyContext = CodelesslyContext.empty()
        ..nodeValues['item'] = Observable<List<ValueModel>>([
          const BoolValue(name: 'visible', value: false),
        ]);
      final node = page()..properties.itemCount = null;
      await pump(tester, screen, host, node, [
        rect('item', 'page', height: 0),
      ], codelesslyContext: codelesslyContext);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(built(tester), lessThanOrEqualTo(3));
    });

    forEachLayout('long scrolls keep only the viewport and cache built', (
      tester,
      screen,
      host,
    ) async {
      for (final int? count in [null, 1000]) {
        await pump(tester, screen, host, list(itemCount: count), [
          rect('item', 'list'),
        ]);
        await tester.pumpAndSettle();
        final double viewport = viewportOf(screen, host, 400);
        final TestGesture gesture = await tester.startGesture(
          tester.getCenter(find.byType(ListView)),
        );
        for (var i = 0; i < 200; i++) {
          await gesture.moveBy(const Offset(0, -50));
          await tester.pump();
        }
        await gesture.up();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        // 10000 px down: the items on screen and in the 250 px cache on
        // each side, plus one partly covered item at each edge.
        expect(
          built(tester),
          lessThanOrEqualTo((viewport + 2 * 250) / 50 + 2),
          reason: 'itemCount $count',
        );
        expect(
          tester
              .widget<IndexedItemProvider>(
                find.byType(IndexedItemProvider).first,
              )
              .item
              .index,
          greaterThan(150),
        );
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('an item keeps alive once the user changed a node in it', (
      tester,
    ) async {
      final codelesslyContext = CodelesslyContext.empty();
      await tester.pumpWidget(
        MaterialApp(
          home: ListView.builder(
            itemCount: 200,
            itemBuilder: (context, index) => NodeStateProviderWidget(
              key: ValueKey(index),
              node: rect('item', kRootNode),
              codelesslyContext: codelesslyContext,
              child: Builder(
                builder: (context) => SizedBox(
                  height: 50,
                  child: Row(
                    children: [
                      Text('item $index'),
                      TextButton(
                        onPressed: () =>
                            NodeStateProvider.setState(context, 'typed $index'),
                        child: Text('change $index'),
                      ),
                      TextButton(
                        onPressed: () => NodeStateProvider.setState(
                          context,
                          'built $index',
                          byUser: false,
                        ),
                        child: Text('build $index'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('change 1'));
      await tester.tap(find.text('build 2'));
      // Let the ink splashes, which keep their item alive, finish.
      await tester.pumpAndSettle();
      tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position
          .jumpTo(5000);
      await tester.pump();
      expect(tester.takeException(), isNull);
      // The changed item stays (offstage); the others are disposed.
      expect(find.text('item 1', skipOffstage: false), findsOneWidget);
      expect(find.text('item 2', skipOffstage: false), findsNothing);
      expect(find.text('item 0', skipOffstage: false), findsNothing);
      expect(
        tester
            .widget<NodeStateProvider>(
              find.ancestor(
                of: find.text('item 1', skipOffstage: false),
                matching: find.byType(NodeStateProvider, skipOffstage: false),
              ),
            )
            .state,
        'typed 1',
      );
    });

    forEachLayout('a long single-frame jump does not end an endless list', (
      tester,
      screen,
      host,
    ) async {
      await pump(tester, screen, host, list(itemCount: null), [
        rect('item', 'list'),
      ]);
      await tester.pumpAndSettle();
      final ScrollPosition position = tester
          .state<ScrollableState>(find.byType(Scrollable).last)
          .position;
      for (final double jump in [600.0, 1500.0, 4000.0]) {
        final double from = position.pixels;
        position.jumpTo(from + jump);
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(position.pixels, from + jump, reason: 'jump $jump');
        expect(position.maxScrollExtent, greaterThan(position.pixels));
      }
      // Dragging further a long way in one frame still scrolls the list.
      final double from = position.pixels;
      await tester.dragFrom(
        tester.getCenter(find.byType(ListView)),
        const Offset(0, -2000),
      );
      await tester.pump();
      expect(position.pixels, greaterThan(from + 1000));
      expect(position.maxScrollExtent, greaterThan(position.pixels));
      expect(
        built(tester),
        lessThanOrEqualTo((viewportOf(screen, host, 400) + 500) / 50 + 2),
      );
    });

    forEachLayout('list with a zero item extent', (tester, screen, host) async {
      await pump(tester, screen, host, list(itemCount: null, itemExtent: 0), [
        rect('item', 'list', height: 0),
      ]);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(built(tester), lessThanOrEqualTo(2));
    });
  });
}
