import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// Layouts with flex children, scroll views and fixed content wider than the
// screen, pumped at phone, tablet and desktop sizes in a tight host (the
// screen), a loose host (centered in a Scaffold) and an unbounded host (a
// vertical scroll view).

RectangleNode rect(
  String id,
  String parent, {
  double width = 50,
  double height = 50,
  SizeFit horizontalFit = SizeFit.fixed,
  SizeFit verticalFit = SizeFit.fixed,
  bool visible = true,
  int flex = 1,
}) => RectangleNode(
  id: id,
  name: id,
  basicBoxLocal: NodeBox(0, 0, width, height),
  horizontalFit: horizontalFit,
  verticalFit: verticalFit,
  visible: visible,
  flex: flex,
)..parentID = parent;

RowColumnNode flex(
  String id,
  String parent,
  List<BaseNode> children, {
  required RowColumnType type,
  double width = 300,
  double height = 300,
  SizeFit horizontalFit = SizeFit.fixed,
  SizeFit verticalFit = SizeFit.fixed,
  bool isScrollable = false,
  MainAxisAlignmentC mainAxisAlignment = MainAxisAlignmentC.start,
  CrossAxisAlignmentC crossAxisAlignment = CrossAxisAlignmentC.start,
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
  )..parentID = parent;
}

SpacerNode spacer(String id, {double width = 20, double height = 20}) =>
    SpacerNode(
      id: id,
      name: id,
      basicBoxLocal: NodeBox(0, 0, width, height),
      horizontalFit: SizeFit.expanded,
      verticalFit: SizeFit.expanded,
    );

Finder rectOf(String id) =>
    find.byKey(ValueKey('Rectangle Transformer of $id [$id]'));

enum Host { tight, loose, unbounded }

const List<Size> screens = [Size(390, 844), Size(834, 1194), Size(1440, 900)];

/// Every node in the tree under [root], [root] included.
List<BaseNode> collect(BaseNode root, Map<String, BaseNode> byId) => [
  root,
  for (final id in root.childrenOrEmpty) ...collect(byId[id]!, byId),
];

/// Pumps [root] (whose descendants are [nodes]) at [screen] in [host] and
/// returns each node's size. Fails on any Flutter error.
Future<Map<String, Size>> pump(
  WidgetTester tester,
  BaseNode root,
  List<BaseNode> nodes, {
  required Size screen,
  required Host host,
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
  Widget built(BuildContext context) => manager.buildWidgetFromNode(
    root,
    context,
    settings: const WidgetBuildSettings(debugLabel: 'test'),
  );
  final Widget body = Builder(builder: built);
  await tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: codelesslyContext ?? CodelesslyContext.empty(),
      child: MaterialApp(
        home: switch (host) {
          Host.tight => Material(child: body),
          Host.loose => Scaffold(body: Center(child: body)),
          Host.unbounded => Scaffold(body: SingleChildScrollView(child: body)),
        },
      ),
    ),
  );
  final Object? error = tester.takeException();
  expect(error, isNull, reason: '$host at $screen: $error');
  return {
    for (final node in [root, ...nodes])
      if (rectOf(node.id).evaluate().isNotEmpty)
        node.id: tester.getSize(rectOf(node.id)),
  };
}

/// Runs [check] for every screen size and host.
Future<void> everywhere(
  WidgetTester tester,
  BaseNode root,
  List<BaseNode> nodes,
  void Function(Map<String, Size> sizes, Size screen, Host host) check,
) async {
  for (final Size screen in screens) {
    for (final Host host in Host.values) {
      final sizes = await pump(tester, root, nodes, screen: screen, host: host);
      check(sizes, screen, host);
    }
  }
}

void main() {
  testWidgets('a shrinkWrap row with an expanded child inside a row (E1, A7)', (
    tester,
  ) async {
    final a = rect('a', '', width: 80, horizontalFit: SizeFit.expanded);
    final b = rect('b', '');
    final inner = flex(
      'inner',
      '',
      [a, b],
      type: RowColumnType.row,
      width: 130,
      height: 50,
      horizontalFit: SizeFit.shrinkWrap,
      verticalFit: SizeFit.shrinkWrap,
    );
    final c = rect('c', '');
    final outer = flex(
      'outer',
      kRootNode,
      [inner, c],
      type: RowColumnType.row,
      width: 390,
      height: 100,
      horizontalFit: SizeFit.expanded,
    );
    await everywhere(tester, outer, [inner, a, b, c], (sizes, screen, host) {
      // There is no free space to fill in a hugging row: the expanded child
      // keeps the size the editor gave it.
      expect(sizes['a'], const Size(80, 50), reason: '$host $screen');
      expect(sizes['inner'], const Size(130, 50), reason: '$host $screen');
    });
  });

  testWidgets(
    'expanded children and flex spacers in a scrollable column (A1, B8)',
    (tester) async {
      final top = rect('top', '', width: 100, height: 100);
      final grow = rect(
        'grow',
        '',
        width: 100,
        height: 200,
        verticalFit: SizeFit.expanded,
      );
      final gap = spacer('gap', height: 40);
      final bottom = rect('bottom', '', width: 100, height: 100);
      final column = flex(
        'column',
        kRootNode,
        [top, grow, gap, bottom],
        type: RowColumnType.column,
        width: 300,
        height: 600,
        isScrollable: true,
      );
      await everywhere(tester, column, [top, grow, gap, bottom], (
        sizes,
        screen,
        host,
      ) {
        // A tight host makes the column the screen; elsewhere it keeps its
        // design size.
        final double height = sizes['column']!.height;
        expect(height, host == Host.tight ? screen.height : 600);
        // The viewport is longer than the content, so the expanded child and
        // the spacer share what is left of it, half each (the editor's
        // max(viewport, content)).
        // The Flex inside a rectangle stretched by a tight host keeps the
        // design size, as before.
        expect(sizes['grow']!.height, (600 - 200) / 2, reason: '$host');
      });
    },
  );

  testWidgets('expanded children in a scrollable column longer than it', (
    tester,
  ) async {
    final top = rect('top', '', width: 100, height: 500);
    final grow = rect(
      'grow',
      '',
      width: 100,
      height: 120,
      verticalFit: SizeFit.expanded,
    );
    final column = flex(
      'column',
      kRootNode,
      [top, grow],
      type: RowColumnType.column,
      width: 300,
      height: 400,
      isScrollable: true,
    );
    await everywhere(tester, column, [top, grow], (sizes, screen, host) {
      // The content scrolls, so the expanded child keeps its design size.
      expect(sizes['grow']!.height, 120, reason: '$host $screen');
    });
  });

  testWidgets('expanded column as the root in every host (A4, A6)', (
    tester,
  ) async {
    final a = rect('a', '', width: 100, verticalFit: SizeFit.expanded);
    final column = flex(
      'column',
      kRootNode,
      [a],
      type: RowColumnType.column,
      width: 320,
      height: 500,
      horizontalFit: SizeFit.expanded,
      verticalFit: SizeFit.expanded,
    );
    await everywhere(tester, column, [a], (sizes, screen, host) {
      final Size size = sizes['column']!;
      // A bounded axis is filled; the scroll view's height is unbounded, so
      // the column keeps its design height there.
      expect(size.width, screen.width, reason: '$host $screen');
      expect(
        size.height,
        host == Host.unbounded ? 500 : screen.height,
        reason: '$host $screen',
      );
      expect(sizes['a']!.height, size.height, reason: '$host $screen');
    });
  });

  testWidgets('cross-axis expanded child of a row in a scroll view (A5)', (
    tester,
  ) async {
    final a = rect(
      'a',
      '',
      width: 60,
      height: 70,
      verticalFit: SizeFit.expanded,
    );
    final row = flex(
      'row',
      '',
      [a],
      type: RowColumnType.row,
      width: 200,
      height: 70,
      verticalFit: SizeFit.shrinkWrap,
    );
    final column = flex(
      'column',
      kRootNode,
      [row],
      type: RowColumnType.column,
      width: 300,
      height: 400,
      isScrollable: true,
    );
    await everywhere(tester, column, [row, a], (sizes, screen, host) {
      expect(sizes['a'], const Size(60, 70), reason: '$host $screen');
    });
  });

  testWidgets('flexible column takes its design size like a leaf (A6)', (
    tester,
  ) async {
    final a = rect('a', '');
    final inner = flex(
      'inner',
      '',
      [a],
      type: RowColumnType.column,
      width: 120,
      height: 150,
      horizontalFit: SizeFit.flexible,
      verticalFit: SizeFit.flexible,
    );
    final column = flex(
      'column',
      kRootNode,
      [inner],
      type: RowColumnType.column,
      width: 300,
      height: 400,
      isScrollable: true,
    );
    await everywhere(tester, column, [inner, a], (sizes, screen, host) {
      expect(sizes['inner'], const Size(120, 150), reason: '$host $screen');
    });
  });

  testWidgets('a child hidden at runtime gives up its flex share (P-S2)', (
    tester,
  ) async {
    final shown = rect('shown', '', horizontalFit: SizeFit.expanded);
    final hidden = rect('hidden', '', horizontalFit: SizeFit.expanded);
    final row = flex(
      'row',
      kRootNode,
      [shown, hidden],
      type: RowColumnType.row,
      width: 300,
      height: 50,
      mainAxisAlignment: MainAxisAlignmentC.center,
    );
    final visibility = Observable<List<ValueModel>>([
      const BoolValue(name: 'visible', value: false),
    ]);
    final codelesslyContext = CodelesslyContext.empty()
      ..nodeValues['hidden'] = visibility;
    for (final Size screen in screens) {
      for (final Host host in Host.values) {
        visibility.value = [const BoolValue(name: 'visible', value: false)];
        var sizes = await pump(
          tester,
          row,
          [shown, hidden],
          screen: screen,
          host: host,
          codelesslyContext: codelesslyContext,
        );
        expect(sizes['shown']!.width, 300, reason: '$host $screen');
        expect(
          tester.getTopLeft(rectOf('shown')).dx,
          tester.getTopLeft(rectOf('row')).dx,
          reason: 'starts at the row start: $host $screen',
        );

        visibility.value = [const BoolValue(name: 'visible', value: true)];
        await tester.pump();
        expect(tester.takeException(), isNull);
        sizes = {
          for (final id in ['shown', 'hidden']) id: tester.getSize(rectOf(id)),
        };
        expect(sizes['shown']!.width, 150, reason: '$host $screen');
        expect(sizes['hidden']!.width, 150, reason: '$host $screen');
      }
    }
  });

  testWidgets(
    'a hugging row stretches its children to its tallest child (V3)',
    (tester) async {
      final short = rect('short', '', height: 30);
      final tall = rect('tall', '', height: 80);
      final row = flex(
        'row',
        '',
        [short, tall],
        type: RowColumnType.row,
        width: 100,
        height: 80,
        horizontalFit: SizeFit.shrinkWrap,
        verticalFit: SizeFit.shrinkWrap,
        crossAxisAlignment: CrossAxisAlignmentC.stretch,
      );
      final column = flex(
        'column',
        kRootNode,
        [row],
        type: RowColumnType.column,
        width: 300,
        height: 400,
      );
      await everywhere(tester, column, [row, short, tall], (
        sizes,
        screen,
        host,
      ) {
        expect(sizes['row'], const Size(100, 80), reason: '$host $screen');
        expect(sizes['short'], const Size(50, 80), reason: '$host $screen');
      });
    },
  );

  testWidgets('a stretching column keeps a hugging child at its size (V3)', (
    tester,
  ) async {
    final tab = rect('tab', '', width: 60, height: 30);
    final tabs = flex(
      'tabs',
      '',
      [tab],
      type: RowColumnType.row,
      width: 60,
      height: 30,
      horizontalFit: SizeFit.shrinkWrap,
      verticalFit: SizeFit.shrinkWrap,
    );
    final bar = rect('bar', '', width: 40, height: 10);
    final column = flex(
      'column',
      kRootNode,
      [tabs, bar],
      type: RowColumnType.column,
      width: 300,
      height: 400,
      crossAxisAlignment: CrossAxisAlignmentC.stretch,
    );
    await everywhere(tester, column, [tabs, tab, bar], (sizes, screen, host) {
      // The hugging row keeps its width, at the start; the fixed one
      // stretches, as the editor lays them out.
      expect(sizes['tabs'], const Size(60, 30), reason: '$host $screen');
      expect(sizes['bar'], const Size(300, 10), reason: '$host $screen');
      expect(
        tester.getTopLeft(rectOf('tabs')).dx,
        tester.getTopLeft(rectOf('bar')).dx,
      );
    });
  });

  testWidgets('a hugging column\'s min size includes its padding', (
    tester,
  ) async {
    final label = rect('label', '', width: 60, height: 30);
    final tile = RowColumnNode(
      id: 'tile',
      name: 'tile',
      basicBoxLocal: NodeBox(0, 0, 120, 157),
      children: const ['label'],
      rowColumnType: RowColumnType.column,
      horizontalFit: SizeFit.shrinkWrap,
      verticalFit: SizeFit.shrinkWrap,
      padding: const EdgeInsetsModel.all(17.5),
      constraints: const BoxConstraintsModel(minWidth: 120, minHeight: 157),
    );
    label.parentID = 'tile';
    final column = flex(
      'column',
      kRootNode,
      [tile],
      type: RowColumnType.column,
      width: 300,
      height: 400,
    );
    await everywhere(tester, column, [tile, label], (sizes, screen, host) {
      // Like the editor, the min height is the tile's whole box: content
      // and padding together, not the content alone.
      expect(sizes['tile'], const Size(120, 157), reason: '$host $screen');
    });
  });

  testWidgets('fixed children wider than the row shrink to fit it (B1)', (
    tester,
  ) async {
    final children = [
      for (final id in ['a', 'b', 'c']) rect(id, '', width: 300, height: 40),
    ];
    final row = flex(
      'row',
      kRootNode,
      children,
      type: RowColumnType.row,
      width: 900,
      height: 40,
      horizontalFit: SizeFit.expanded,
    );
    await everywhere(tester, row, children, (sizes, screen, host) {
      final double rowWidth = sizes['row']!.width;
      // At the design size (and wider) they keep their size; narrower, each
      // gives up the same share of the overflow.
      final double expected = rowWidth >= 900 ? 300 : rowWidth / 3;
      for (final id in ['a', 'b', 'c']) {
        expect(
          sizes[id]!.width,
          moreOrLessEquals(expected, epsilon: 0.5),
          reason: '$host $screen',
        );
      }
    });
  });

  testWidgets('text in a row that shrinks keeps its longest word (B1)', (
    tester,
  ) async {
    final text = TextNode(
      id: 'text',
      name: 'text',
      basicBoxLocal: NodeBox(0, 0, 400, 20),
      horizontalFit: SizeFit.shrinkWrap,
      verticalFit: SizeFit.shrinkWrap,
      characters: 'Lorem ipsum dolor sit amet consectetur',
      textMixedProps: [StartEndProp(start: 0, end: 38, fontSize: 14)],
    );
    final a = rect('a', '', width: 300, height: 40);
    final b = rect('b', '', width: 300, height: 40);
    final row = flex(
      'row',
      kRootNode,
      [text, a, b],
      type: RowColumnType.row,
      width: 1000,
      height: 40,
      horizontalFit: SizeFit.expanded,
      verticalFit: SizeFit.shrinkWrap,
    );
    await everywhere(tester, row, [text, a, b], (sizes, screen, host) {
      final RenderParagraph paragraph = tester.renderObject(
        find.byType(RichText),
      );
      final double minContent = paragraph.getMinIntrinsicWidth(double.infinity);
      // The text squeezes and wraps, but never below its longest word,
      // while the boxes give up the rest.
      expect(
        paragraph.size.width,
        greaterThanOrEqualTo(minContent),
        reason: '$host $screen',
      );
      if (sizes['row']!.width < 1000) {
        expect(sizes['a']!.width, lessThan(300), reason: '$host $screen');
      }
    });
  });

  testWidgets(
    'reflowing text in a fixed-height column keeps its lines (B2, B4)',
    (tester) async {
      final text = TextNode(
        id: 'text',
        name: 'text',
        basicBoxLocal: NodeBox(0, 0, 1000, 20),
        horizontalFit: SizeFit.expanded,
        verticalFit: SizeFit.fixed,
        characters:
            'Lorem ipsum dolor sit amet consectetur adipiscing elit sed do '
            'eiusmod tempor incididunt ut labore et dolore magna aliqua',
        textMixedProps: [StartEndProp(start: 0, end: 120, fontSize: 14)],
      );
      final picture = rect('picture', '', width: 100, height: 100);
      final column = flex(
        'column',
        kRootNode,
        [text, picture],
        type: RowColumnType.column,
        width: 1000,
        height: 120,
        horizontalFit: SizeFit.expanded,
      );
      await everywhere(tester, column, [text, picture], (sizes, screen, host) {
        final RenderParagraph paragraph = tester.renderObject(
          find.byType(RichText),
        );
        final double lines = paragraph.getMinIntrinsicHeight(
          paragraph.size.width,
        );
        // The text keeps every line; the picture gives up the room instead.
        expect(
          paragraph.size.height,
          greaterThanOrEqualTo(lines),
          reason: '$host $screen',
        );
        if (screen.width == 390) {
          expect(lines, greaterThan(20), reason: 'the text reflows at 390');
        }
        if (lines > 20) {
          expect(
            sizes['picture']!.height,
            lessThan(100),
            reason: '$host $screen',
          );
        }
      });
    },
  );

  testWidgets('fixed children taller than the column shrink to fit it (B2)', (
    tester,
  ) async {
    final children = [
      for (final id in ['a', 'b']) rect(id, '', width: 40, height: 150),
    ];
    final column = flex(
      'column',
      kRootNode,
      children,
      type: RowColumnType.column,
      width: 40,
      height: 200,
    );
    await everywhere(tester, column, children, (sizes, screen, host) {
      expect(sizes['a']!.height, moreOrLessEquals(100, epsilon: 0.5));
      expect(sizes['b']!.height, moreOrLessEquals(100, epsilon: 0.5));
    });
  });

  testWidgets('rows that fit are laid out as designed', (tester) async {
    final a = rect('a', '', width: 100);
    final b = rect('b', '', width: 50, horizontalFit: SizeFit.expanded);
    final gap = spacer('gap', width: 10);
    final c = rect('c', '', width: 100);
    final row = flex(
      'row',
      kRootNode,
      [a, b, gap, c],
      type: RowColumnType.row,
      width: 350,
      height: 50,
    );
    await everywhere(tester, row, [a, b, gap, c], (sizes, screen, host) {
      final Size rowSize = sizes['row']!;
      expect(rowSize, host == Host.tight ? screen : const Size(350, 50));
      expect(sizes['a']!.width, 100);
      // The free space is shared by the expanded child and the spacer.
      expect(sizes['b']!.width, (350 - 200) / 2);
      expect(sizes['c']!.width, 100);
    });
  });
}
