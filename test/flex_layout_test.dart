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
  testWidgets(
    'a row aligned to baselines lays out (it needs a text baseline)',
    (tester) async {
      final a = rect('a', '', width: 40, height: 30);
      final b = rect('b', '', width: 40, height: 10);
      final row = flex(
        'row',
        kRootNode,
        [a, b],
        type: RowColumnType.row,
        width: 200,
        height: 40,
        crossAxisAlignment: CrossAxisAlignmentC.baseline,
      );
      await everywhere(tester, row, [a, b], (sizes, screen, host) {
        expect(sizes['a'], const Size(40, 30));
      });
    },
  );

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

  group('a squeezable shrinkWrap child (loose Flexible)', () {
    TextNode label(String id, String characters, {bool squeezable = false}) =>
        TextNode(
          id: id,
          name: id,
          basicBoxLocal: NodeBox(0, 0, 120, 10),
          horizontalFit: SizeFit.shrinkWrap,
          verticalFit: SizeFit.shrinkWrap,
          characters: characters,
          maxLines: 1,
          overflow: TextOverflowC.ellipsis,
          textMixedProps: [
            StartEndProp(start: 0, end: characters.length, fontSize: 10),
          ],
        )..squeezable = squeezable;

    RenderParagraph paragraphOf(WidgetTester tester, String characters) =>
        tester.renderObject(
          find.byWidgetPredicate(
            (widget) =>
                widget is RichText && widget.text.toPlainText() == characters,
          ),
        );

    // A name and its count in a 200 wide row; the test font is 10 px a
    // character.
    Future<void> pumpRow(WidgetTester tester, String characters, Size screen) {
      final name = label('name', characters, squeezable: true);
      final count = label('count', 'x3');
      final row = flex(
        'row',
        kRootNode,
        [name, count],
        type: RowColumnType.row,
        width: 200,
        height: 10,
      );
      return pump(tester, row, [name, count], screen: screen, host: Host.loose);
    }

    for (final screen in screens) {
      testWidgets('hugs a short name and ellipsizes a long one at '
          '${screen.width.toInt()}', (tester) async {
        await pumpRow(tester, 'Ann', screen);
        final RenderParagraph short = paragraphOf(tester, 'Ann');
        expect(short.size.width, 30);
        expect(short.didExceedMaxLines, isFalse);
        expect(
          tester.getTopLeft(find.text('x3')).dx,
          tester.getTopRight(find.text('Ann')).dx,
        );

        const String long = 'Bartholomew Montgomeryfitzgerald';
        await pumpRow(tester, long, screen);
        final RenderParagraph name = paragraphOf(tester, long);
        // The name gives up what the count needs, and ellipsizes.
        expect(name.size.width, 180);
        expect(name.didExceedMaxLines, isTrue);
        expect(paragraphOf(tester, 'x3').size.width, 20);
        expect(
          tester.getTopRight(find.text('x3')).dx,
          tester.getTopRight(rectOf('row')).dx,
        );
      });
    }

    // A dialog body: a header and a card that is as tall as its content, up
    // to the height the column has left.
    testWidgets('a card hugs its content up to the room left', (tester) async {
      for (final int items in [1, 6]) {
        final header = rect('header', '', width: 300, height: 50);
        final children = [
          for (int i = 0; i < items; i++)
            rect('item$i', '', width: 300, height: 100),
        ];
        final card = flex(
          'card',
          '',
          children,
          type: RowColumnType.column,
          width: 300,
          height: 100,
          verticalFit: SizeFit.shrinkWrap,
          isScrollable: true,
        )..squeezable = true;
        final column = flex(
          'column',
          kRootNode,
          [header, card],
          type: RowColumnType.column,
          width: 300,
          height: 400,
        );
        for (final screen in screens) {
          final sizes = await pump(
            tester,
            column,
            [header, card, ...children],
            screen: screen,
            host: Host.loose,
          );
          expect(sizes['column'], const Size(300, 400));
          expect(
            sizes['card'],
            Size(300, items == 1 ? 100 : 350),
            reason: '$items items at $screen',
          );
          expect(sizes['item0'], const Size(300, 100));
        }
      }
    });
  });

  group('a wrapping row (Wrap)', () {
    // Chips 80 wide with a 10 margin on their right, so 90 apart.
    List<RectangleNode> chips({
      List<double> heights = const [20, 20, 20, 20],
    }) => [
      for (int i = 0; i < heights.length; i++)
        RectangleNode(
          id: 'chip$i',
          name: 'chip$i',
          basicBoxLocal: NodeBox(0, 0, 80, heights[i]),
          margin: const EdgeInsetsModel.only(right: 10),
        ),
    ];

    RowColumnNode wrapRow(
      List<BaseNode> children, {
      required double width,
      SizeFit horizontalFit = SizeFit.fixed,
      double runSpacing = 0,
      MainAxisAlignmentC mainAxisAlignment = MainAxisAlignmentC.start,
      CrossAxisAlignmentC crossAxisAlignment = CrossAxisAlignmentC.start,
    }) =>
        flex(
            'row',
            kRootNode,
            children,
            type: RowColumnType.row,
            width: width,
            height: 20,
            horizontalFit: horizontalFit,
            verticalFit: SizeFit.shrinkWrap,
            mainAxisAlignment: mainAxisAlignment,
            crossAxisAlignment: crossAxisAlignment,
          )
          ..wrap = true
          ..runSpacing = runSpacing;

    Offset offsetOf(WidgetTester tester, String id) =>
        tester.getTopLeft(rectOf(id)) - tester.getTopLeft(rectOf('row'));

    testWidgets('flows onto a second run when the row is too narrow', (
      tester,
    ) async {
      final children = chips();
      final row = wrapRow(children, width: 200, runSpacing: 8);
      final sizes = await pump(
        tester,
        row,
        children,
        screen: screens.first,
        host: Host.loose,
      );
      expect(offsetOf(tester, 'chip0'), Offset.zero);
      expect(offsetOf(tester, 'chip1'), const Offset(90, 0));
      expect(offsetOf(tester, 'chip2'), const Offset(0, 28));
      expect(offsetOf(tester, 'chip3'), const Offset(90, 28));
      expect(sizes['row'], const Size(200, 48));
      expect(sizes['chip3'], const Size(80, 20));
    });

    testWidgets('a row that fills the screen wraps only on a narrow one', (
      tester,
    ) async {
      // Six chips are 540 long: four fit on a phone, all of them on a tablet
      // or a desktop.
      final children = chips(heights: List.filled(6, 20));
      final row = wrapRow(
        children,
        width: 390,
        horizontalFit: SizeFit.expanded,
        runSpacing: 8,
      );
      for (final (screen, host) in [
        for (final screen in screens)
          for (final host in [Host.loose, Host.unbounded]) (screen, host),
      ]) {
        final sizes = await pump(
          tester,
          row,
          children,
          screen: screen,
          host: host,
        );
        final bool narrow = screen.width < 540;
        for (int i = 0; i < 6; i++) {
          expect(
            offsetOf(tester, 'chip$i'),
            narrow && i >= 4 ? Offset(90.0 * (i - 4), 28) : Offset(90.0 * i, 0),
            reason: 'chip$i at $screen in $host',
          );
        }
        expect(
          sizes['row'],
          Size(screen.width, narrow ? 48 : 20),
          reason: '$screen in $host',
        );
      }
    });

    testWidgets('aligns runs on the main axis and items across a run', (
      tester,
    ) async {
      final children = chips(heights: [20, 10, 20, 10]);
      final row = wrapRow(
        children,
        width: 200,
        mainAxisAlignment: MainAxisAlignmentC.end,
        crossAxisAlignment: CrossAxisAlignmentC.center,
      );
      await pump(
        tester,
        row,
        children,
        screen: screens.first,
        host: Host.loose,
      );
      // Each run is 180 long, placed at the end of the 200 wide row; the
      // shorter chip sits in the middle of its 20 tall run.
      expect(offsetOf(tester, 'chip0'), const Offset(20, 0));
      expect(offsetOf(tester, 'chip1'), const Offset(110, 5));
      expect(offsetOf(tester, 'chip2'), const Offset(20, 20));
      expect(offsetOf(tester, 'chip3'), const Offset(110, 25));
    });

    testWidgets('an expanded child and a flex spacer keep their design size', (
      tester,
    ) async {
      final a = rect('a', '', width: 80, height: 20);
      final s = spacer('s', width: 30, height: 20);
      final b = rect(
        'b',
        '',
        width: 60,
        height: 20,
        horizontalFit: SizeFit.expanded,
      );
      final row = wrapRow([a, s, b], width: 300);
      for (final host in Host.values) {
        final sizes = await pump(
          tester,
          row,
          [a, s, b],
          screen: screens.first,
          host: host,
        );
        expect(sizes['b'], const Size(60, 20), reason: '$host');
        expect(offsetOf(tester, 'b'), const Offset(110, 0), reason: '$host');
      }
    });
  });
}
