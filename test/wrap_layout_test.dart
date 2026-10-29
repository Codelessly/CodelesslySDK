import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// A row/column with `wrap` on renders as a Flutter Wrap: children flow onto
// new runs, `runSpacing` separates the runs, and children that flex along
// the main axis hug their content.

RectangleNode rect(
  String id, {
  double width = 100,
  double height = 40,
  SizeFit horizontalFit = SizeFit.fixed,
  SizeFit verticalFit = SizeFit.fixed,
}) => RectangleNode(
  id: id,
  name: id,
  basicBoxLocal: NodeBox(0, 0, width, height),
  horizontalFit: horizontalFit,
  verticalFit: verticalFit,
);

RowColumnNode rowColumn(
  String id,
  String parent,
  List<BaseNode> children, {
  RowColumnType type = RowColumnType.row,
  double width = 250,
  double height = 300,
  SizeFit horizontalFit = SizeFit.fixed,
  SizeFit verticalFit = SizeFit.fixed,
  bool wrap = true,
  double spacing = 0,
  double runSpacing = 0,
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
    mainAxisAlignment: mainAxisAlignment,
    crossAxisAlignment: crossAxisAlignment,
    wrap: wrap,
    spacing: spacing,
    runSpacing: runSpacing,
  )..parentID = parent;
}

Finder rectOf(String id) =>
    find.byKey(ValueKey('Rectangle Transformer of $id [$id]'));

/// Pumps [root] with its descendants [nodes] at the top left of the screen
/// and fails on any Flutter error.
Future<void> pump(
  WidgetTester tester,
  BaseNode root,
  List<BaseNode> nodes,
) async {
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
}

/// Where [id]'s rectangle sits relative to the row/column [parent].
Offset offsetOf(WidgetTester tester, String id, String parent) =>
    tester.getTopLeft(rectOf(id)) -
    tester.getTopLeft(find.byKey(ValueKey(parent)).first);

void main() {
  testWidgets('a wrapping row moves children that do not fit to a new run', (
    tester,
  ) async {
    final children = [rect('a'), rect('b'), rect('c')];
    final row = rowColumn('row', kRootNode, children);
    await pump(tester, row, children);

    expect(find.byType(CodelesslyWrap), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is Flex), findsNothing);
    expect(offsetOf(tester, 'a', 'row'), Offset.zero);
    expect(offsetOf(tester, 'b', 'row'), const Offset(100, 0));
    expect(offsetOf(tester, 'c', 'row'), const Offset(0, 40));
    expect(tester.getSize(rectOf('c')), const Size(100, 40));
  });

  testWidgets('run spacing separates the runs', (tester) async {
    final children = [
      rect('a'),
      rect('b', height: 20),
      rect('c'),
      rect('d', width: 60),
      rect('e', width: 60),
    ];
    final row = rowColumn(
      'row',
      kRootNode,
      children,
      runSpacing: 12,
      verticalFit: SizeFit.shrinkWrap,
    );
    await pump(tester, row, children);

    expect(offsetOf(tester, 'c', 'row'), const Offset(0, 52));
    expect(offsetOf(tester, 'd', 'row'), const Offset(100, 52));
    expect(offsetOf(tester, 'e', 'row'), const Offset(160, 52));
    // A row that hugs its height is as tall as its runs.
    expect(tester.getSize(find.byKey(const ValueKey('row')).first).height, 92);
  });

  testWidgets('alignments place children within their runs', (tester) async {
    final children = [rect('a'), rect('b', height: 20), rect('c', height: 30)];
    final row = rowColumn(
      'row',
      kRootNode,
      children,
      mainAxisAlignment: MainAxisAlignmentC.center,
      crossAxisAlignment: CrossAxisAlignmentC.center,
    );
    await pump(tester, row, children);

    final CodelesslyWrap wrap = tester.widget(find.byType(CodelesslyWrap));
    expect(wrap.alignment, WrapAlignment.center);
    expect(wrap.crossAxisAlignment, WrapCrossAlignment.center);
    expect(wrap.runAlignment, WrapAlignment.center);
    // The two runs occupy 70px and are centered in the fixed 300px row.
    expect(offsetOf(tester, 'a', 'row'), const Offset(25, 115));
    expect(offsetOf(tester, 'b', 'row'), const Offset(125, 125));
    expect(offsetOf(tester, 'c', 'row'), const Offset(75, 155));
  });

  testWidgets('a wrapping column flows into a new column run', (tester) async {
    final children = [rect('a'), rect('b'), rect('c')];
    final column = rowColumn(
      'col',
      kRootNode,
      children,
      type: RowColumnType.column,
      width: 300,
      height: 100,
      runSpacing: 10,
    );
    await pump(tester, column, children);

    final CodelesslyWrap wrap = tester.widget(find.byType(CodelesslyWrap));
    expect(wrap.direction, Axis.vertical);
    expect(offsetOf(tester, 'b', 'col'), const Offset(0, 40));
    expect(offsetOf(tester, 'c', 'col'), const Offset(110, 0));
  });

  testWidgets('a child that expands along a wrapping row hugs its content', (
    tester,
  ) async {
    final inner = rect('inner', width: 70, height: 30);
    final chip = rowColumn(
      'chip',
      'row',
      [inner],
      wrap: false,
      width: 200,
      height: 30,
      horizontalFit: SizeFit.expanded,
      verticalFit: SizeFit.shrinkWrap,
    );
    final children = [rect('a'), chip, rect('c')];
    final row = rowColumn('row', kRootNode, children);
    await pump(tester, row, [...children, inner]);

    expect(tester.getSize(find.byKey(const ValueKey('chip')).first).width, 70);
    expect(offsetOf(tester, 'inner', 'row'), const Offset(100, 0));
    expect(offsetOf(tester, 'c', 'row'), const Offset(0, 40));
  });

  testWidgets('a row that does not wrap is unchanged', (tester) async {
    final children = [rect('a'), rect('b'), rect('c')];
    final row = rowColumn('row', kRootNode, children, width: 300, wrap: false);
    await pump(tester, row, children);

    expect(find.byType(CodelesslyWrap), findsNothing);
    expect(find.byWidgetPredicate((w) => w is Flex), findsOneWidget);
    expect(offsetOf(tester, 'c', 'row'), const Offset(200, 0));
  });

  testWidgets('PR83 spacing, runs, and wide row', (tester) async {
    final children = [
      rect('a', width: 50, height: 20),
      rect('b', width: 50, height: 30),
      rect('c', width: 50, height: 20),
    ];
    final row = rowColumn(
      'row',
      kRootNode,
      children,
      width: 120,
      height: 20,
      verticalFit: SizeFit.shrinkWrap,
      spacing: 10,
      runSpacing: 5,
    );
    await pump(tester, row, children);
    final wrap = tester.widget<CodelesslyWrap>(find.byType(CodelesslyWrap));
    expect(wrap.spacing, 10);
    expect(wrap.runSpacing, 5);
    expect(offsetOf(tester, 'b', 'row'), const Offset(60, 0));
    expect(offsetOf(tester, 'c', 'row'), const Offset(0, 35));
  });

  testWidgets('PR83 expanded children and spacers keep design size', (
    tester,
  ) async {
    final gap = SpacerNode(
      id: 'gap',
      name: 'gap',
      basicBoxLocal: NodeBox(0, 0, 20, 20),
      horizontalFit: SizeFit.expanded,
      verticalFit: SizeFit.expanded,
    );
    final children = <BaseNode>[
      rect('a', width: 60, height: 20, horizontalFit: SizeFit.expanded),
      gap,
      rect('b', width: 60, height: 20, verticalFit: SizeFit.expanded),
    ];
    final row = rowColumn(
      'row',
      kRootNode,
      children,
      width: 120,
      height: 20,
      spacing: 0,
      verticalFit: SizeFit.shrinkWrap,
    );
    await pump(tester, row, children);
    expect(tester.getSize(rectOf('a')), const Size(60, 20));
    expect(tester.getSize(rectOf('b')), const Size(60, 20));
    expect(offsetOf(tester, 'b', 'row'), const Offset(0, 20));
  });

  testWidgets('PR83 stretch maps to start cross alignment', (tester) async {
    final children = [rect('a'), rect('b')];
    final row = rowColumn(
      'row',
      kRootNode,
      children,
      width: 250,
      mainAxisAlignment: MainAxisAlignmentC.spaceBetween,
      crossAxisAlignment: CrossAxisAlignmentC.stretch,
    );
    await pump(tester, row, children);
    final wrap = tester.widget<CodelesslyWrap>(find.byType(CodelesslyWrap));
    expect(wrap.alignment, WrapAlignment.spaceBetween);
    expect(wrap.crossAxisAlignment, WrapCrossAlignment.start);
    expect(wrap.runAlignment, WrapAlignment.start);
  });

  testWidgets('PR83 wide row stays on one line', (tester) async {
    final children = [
      rect('a', width: 50, height: 20),
      rect('b', width: 50, height: 20),
      rect('c', width: 50, height: 20),
    ];
    final row = rowColumn(
      'row',
      kRootNode,
      children,
      width: 300,
      height: 20,
      spacing: 10,
      verticalFit: SizeFit.shrinkWrap,
    );
    await pump(tester, row, children);
    expect(offsetOf(tester, 'c', 'row'), const Offset(120, 0));
  });

  testWidgets('PR83 wrap off leaves Flex in place', (tester) async {
    final children = [rect('a'), rect('b')];
    await pump(
      tester,
      rowColumn('row', kRootNode, children, wrap: false),
      children,
    );
    expect(find.byType(CodelesslyWrap), findsNothing);
  });
}
