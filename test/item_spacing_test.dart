import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// RowColumnNode.itemSpacing: the gap between consecutive children, as
// Flutter's Flex.spacing (and CSS gap) lays it out.

RectangleNode rect(
  String id, {
  double width = 50,
  double height = 50,
  SizeFit horizontalFit = SizeFit.fixed,
  SizeFit verticalFit = SizeFit.fixed,
  bool visible = true,
}) => RectangleNode(
  id: id,
  name: id,
  basicBoxLocal: NodeBox(0, 0, width, height),
  horizontalFit: horizontalFit,
  verticalFit: verticalFit,
  visible: visible,
);

RowColumnNode rowColumn(
  List<BaseNode> children, {
  RowColumnType type = RowColumnType.row,
  double width = 300,
  double height = 50,
  double itemSpacing = 10,
  SizeFit horizontalFit = SizeFit.fixed,
  SizeFit verticalFit = SizeFit.fixed,
  MainAxisAlignmentC mainAxisAlignment = MainAxisAlignmentC.start,
}) {
  for (final child in children) {
    child.parentID = 'row';
  }
  return RowColumnNode(
    id: 'row',
    name: 'row',
    basicBoxLocal: NodeBox(0, 0, width, height),
    children: [for (final child in children) child.id],
    rowColumnType: type,
    horizontalFit: horizontalFit,
    verticalFit: verticalFit,
    mainAxisAlignment: mainAxisAlignment,
    crossAxisAlignment: CrossAxisAlignmentC.start,
    itemSpacing: itemSpacing,
  )..parentID = kRootNode;
}

Finder rectOf(String id) =>
    find.byKey(ValueKey('Rectangle Transformer of $id [$id]'));

Future<void> pump(
  WidgetTester tester,
  RowColumnNode root,
  List<BaseNode> nodes, {
  CodelesslyContext? codelesslyContext,
}) async {
  tester.view.physicalSize = const Size(800, 600);
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
      value: codelesslyContext ?? CodelesslyContext.empty(),
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
}

/// Main-axis offset of [id] from the row/column's start.
double mainOffset(WidgetTester tester, String id, {bool isRow = true}) {
  final Offset child = tester.getTopLeft(rectOf(id));
  final Offset row = tester.getTopLeft(rectOf('row'));
  return isRow ? child.dx - row.dx : child.dy - row.dy;
}

double mainSize(WidgetTester tester, String id, {bool isRow = true}) {
  final Size size = tester.getSize(rectOf(id));
  return isRow ? size.width : size.height;
}

Observable<List<ValueModel>> visibility(bool visible) =>
    Observable<List<ValueModel>>([BoolValue(name: 'visible', value: visible)]);

void main() {
  testWidgets('start: children are spaced by the gap via Flex.spacing', (
    tester,
  ) async {
    final children = [rect('a'), rect('b'), rect('c')];
    await pump(tester, rowColumn(children), children);
    expect(mainOffset(tester, 'a'), 0);
    expect(mainOffset(tester, 'b'), 60);
    expect(mainOffset(tester, 'c'), 120);
    final CodelesslyFlex flex = tester.widget(find.byType(CodelesslyFlex));
    expect(flex.spacing, 10);
  });

  testWidgets('center: the gaps are centered with the children', (
    tester,
  ) async {
    final children = [rect('a'), rect('b'), rect('c')];
    await pump(
      tester,
      rowColumn(children, mainAxisAlignment: MainAxisAlignmentC.center),
      children,
    );
    // (300 - 150 - 20) / 2 = 65.
    expect(mainOffset(tester, 'a'), 65);
    expect(mainOffset(tester, 'b'), 125);
    expect(mainOffset(tester, 'c'), 185);
  });

  testWidgets('end: the last child ends at the row end', (tester) async {
    final children = [rect('a'), rect('b')];
    await pump(
      tester,
      rowColumn(children, mainAxisAlignment: MainAxisAlignmentC.end),
      children,
    );
    expect(mainOffset(tester, 'a'), 190);
    expect(mainOffset(tester, 'b'), 250);
  });

  testWidgets('spaceBetween: the gap adds to the distributed space', (
    tester,
  ) async {
    final children = [rect('a'), rect('b'), rect('c')];
    await pump(
      tester,
      rowColumn(children, mainAxisAlignment: MainAxisAlignmentC.spaceBetween),
      children,
    );
    expect(mainOffset(tester, 'a'), 0);
    expect(mainOffset(tester, 'b'), 125);
    expect(mainOffset(tester, 'c'), 250);
  });

  testWidgets('spaceEvenly and spaceAround', (tester) async {
    final children = [rect('a'), rect('b')];
    await pump(
      tester,
      rowColumn(children, mainAxisAlignment: MainAxisAlignmentC.spaceEvenly),
      children,
    );
    // free = 300 - 100 - 10 = 190, 3 slots of 190/3.
    expect(mainOffset(tester, 'a'), moreOrLessEquals(190 / 3));
    expect(mainOffset(tester, 'b'), moreOrLessEquals(2 * 190 / 3 + 60));

    await pump(
      tester,
      rowColumn(children, mainAxisAlignment: MainAxisAlignmentC.spaceAround),
      children,
    );
    // free = 190, 2 slots of 95: 47.5 on the outside.
    expect(mainOffset(tester, 'a'), 47.5);
    expect(mainOffset(tester, 'b'), 47.5 + 50 + 95 + 10);
  });

  testWidgets('expanded children share the space left after the gaps', (
    tester,
  ) async {
    final children = [
      rect('a'),
      rect('e', horizontalFit: SizeFit.expanded),
      rect('b'),
    ];
    await pump(tester, rowColumn(children), children);
    expect(mainSize(tester, 'e'), 180);
    expect(mainOffset(tester, 'e'), 60);
    expect(mainOffset(tester, 'b'), 250);
  });

  testWidgets('a shrink-wrapping column sums the gaps', (tester) async {
    final children = [rect('a'), rect('b'), rect('c')];
    await pump(
      tester,
      rowColumn(
        children,
        type: RowColumnType.column,
        width: 50,
        itemSpacing: 8,
        verticalFit: SizeFit.shrinkWrap,
      ),
      children,
    );
    expect(tester.getSize(rectOf('row')).height, 166);
    expect(mainOffset(tester, 'c', isRow: false), 116);
  });

  testWidgets('a child hidden with the eye toggle keeps its space and gaps', (
    tester,
  ) async {
    final children = [rect('a'), rect('h', visible: false), rect('b')];
    await pump(tester, rowColumn(children), children);
    expect(mainOffset(tester, 'b'), 120);
  });

  testWidgets('a child hidden at runtime gives up its gap', (tester) async {
    final hidden = visibility(false);
    final codelesslyContext = CodelesslyContext.empty()
      ..nodeValues['h'] = hidden;
    final children = [rect('a'), rect('h'), rect('b')];
    await pump(
      tester,
      rowColumn(children),
      children,
      codelesslyContext: codelesslyContext,
    );
    expect(mainOffset(tester, 'b'), 60);

    hidden.value = [const BoolValue(name: 'visible', value: true)];
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(mainOffset(tester, 'h'), 60);
    expect(mainOffset(tester, 'b'), 120);

    // The first child hidden: no gap before the second.
    final first = visibility(false);
    await pump(
      tester,
      rowColumn(children),
      children,
      codelesslyContext: CodelesslyContext.empty()..nodeValues['a'] = first,
    );
    expect(mainOffset(tester, 'h'), 0);
    expect(mainOffset(tester, 'b'), 60);
  });

  testWidgets('runtime-hidden children with spaceBetween and expanded', (
    tester,
  ) async {
    final children = [rect('a'), rect('h'), rect('b')];
    await pump(
      tester,
      rowColumn(children, mainAxisAlignment: MainAxisAlignmentC.spaceBetween),
      children,
      codelesslyContext: CodelesslyContext.empty()
        ..nodeValues['h'] = visibility(false),
    );
    expect(mainOffset(tester, 'a'), 0);
    expect(mainOffset(tester, 'b'), 250);

    // Two expanded children around a hidden one get one gap between them.
    final flexChildren = [
      rect('e1', horizontalFit: SizeFit.expanded),
      rect('h'),
      rect('e2', horizontalFit: SizeFit.expanded),
    ];
    await pump(
      tester,
      rowColumn(flexChildren),
      flexChildren,
      codelesslyContext: CodelesslyContext.empty()
        ..nodeValues['h'] = visibility(false),
    );
    expect(mainSize(tester, 'e1'), 145);
    expect(mainSize(tester, 'e2'), 145);
    expect(mainOffset(tester, 'e2'), 155);
  });

  testWidgets('a hidden child keeps its state while its gap comes and goes', (
    tester,
  ) async {
    final hidden = visibility(true);
    final children = [rect('a'), rect('h'), rect('b')];
    await pump(
      tester,
      rowColumn(children),
      children,
      codelesslyContext: CodelesslyContext.empty()..nodeValues['a'] = hidden,
    );
    final Element before = tester.element(rectOf('b'));
    hidden.value = [const BoolValue(name: 'visible', value: false)];
    await tester.pump();
    expect(mainOffset(tester, 'b'), 60);
    expect(tester.element(rectOf('b')), same(before));
  });
}
