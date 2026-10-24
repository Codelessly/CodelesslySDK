import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// Rows with `wrap` on render as a Wrap: children that don't fit the row's
// width start a new run, like the editor's layout solver lays them out.

RectangleNode rect(
  String id, {
  double width = 50,
  double height = 20,
  SizeFit horizontalFit = SizeFit.fixed,
  SizeFit verticalFit = SizeFit.fixed,
}) => RectangleNode(
  id: id,
  name: id,
  basicBoxLocal: NodeBox(0, 0, width, height),
  horizontalFit: horizontalFit,
  verticalFit: verticalFit,
);

RowColumnNode wrapRow(
  List<BaseNode> children, {
  double width = 120,
  double height = 20,
  bool wrap = true,
  double spacing = 10,
  double runSpacing = 5,
  RowColumnType type = RowColumnType.row,
  SizeFit horizontalFit = SizeFit.fixed,
  SizeFit verticalFit = SizeFit.shrinkWrap,
  MainAxisAlignmentC mainAxisAlignment = MainAxisAlignmentC.start,
  CrossAxisAlignmentC crossAxisAlignment = CrossAxisAlignmentC.start,
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
    crossAxisAlignment: crossAxisAlignment,
    wrap: wrap,
    spacing: spacing,
    runSpacing: runSpacing,
  )..parentID = kRootNode;
}

Finder rectOf(String id) =>
    find.byKey(ValueKey('Rectangle Transformer of $id [$id]'));

/// Pumps [root] at the top-left of a 400x800 screen. Fails on any Flutter
/// error.
Future<void> pump(
  WidgetTester tester,
  BaseNode root,
  List<BaseNode> nodes,
) async {
  tester.view.physicalSize = const Size(400, 800);
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

void main() {
  testWidgets('a wrapping row puts children that do not fit on a new line', (
    tester,
  ) async {
    final children = [rect('a'), rect('b', height: 30), rect('c')];
    final row = wrapRow(children);
    await pump(tester, row, children);

    expect(find.byType(Wrap), findsOneWidget);
    final Wrap wrap = tester.widget(find.byType(Wrap));
    expect(wrap.spacing, 10);
    expect(wrap.runSpacing, 5);

    final Offset origin = tester.getTopLeft(find.byType(Wrap));
    // a and b fit in 120 (50 + 10 + 50); c starts a second run below the
    // 30 tall first run.
    expect(tester.getTopLeft(rectOf('a')) - origin, Offset.zero);
    expect(tester.getTopLeft(rectOf('b')) - origin, const Offset(60, 0));
    expect(tester.getTopLeft(rectOf('c')) - origin, const Offset(0, 35));

    expect(tester.getSize(find.byType(Wrap)), const Size(120, 55));
  });

  testWidgets('a wide enough wrapping row keeps one line', (tester) async {
    final children = [rect('a'), rect('b'), rect('c')];
    final row = wrapRow(children, width: 300);
    await pump(tester, row, children);

    final Offset origin = tester.getTopLeft(find.byType(Wrap));
    expect(tester.getTopLeft(rectOf('c')) - origin, const Offset(120, 0));
    expect(tester.getSize(find.byType(Wrap)).height, 20);
  });

  testWidgets('alignments map onto the Wrap', (tester) async {
    final children = [rect('a'), rect('b'), rect('c')];
    final row = wrapRow(
      children,
      spacing: 0,
      runSpacing: 0,
      mainAxisAlignment: MainAxisAlignmentC.spaceBetween,
      crossAxisAlignment: CrossAxisAlignmentC.stretch,
    );
    await pump(tester, row, children);

    final Wrap wrap = tester.widget(find.byType(Wrap));
    expect(wrap.alignment, WrapAlignment.spaceBetween);
    expect(wrap.crossAxisAlignment, WrapCrossAlignment.start);
    expect(wrap.direction, Axis.horizontal);
  });

  testWidgets('expanded children and spacers keep their design size', (
    tester,
  ) async {
    final SpacerNode gap = SpacerNode(
      id: 'gap',
      name: 'gap',
      basicBoxLocal: NodeBox(0, 0, 20, 20),
      horizontalFit: SizeFit.expanded,
      verticalFit: SizeFit.expanded,
    );
    final children = <BaseNode>[
      rect('a', width: 60, horizontalFit: SizeFit.expanded),
      gap,
      rect('b', width: 60, verticalFit: SizeFit.expanded),
    ];
    final row = wrapRow(children, spacing: 0, runSpacing: 0);
    await pump(tester, row, children);

    expect(tester.getSize(rectOf('a')), const Size(60, 20));
    expect(tester.getSize(rectOf('b')), const Size(60, 20));
    final Offset origin = tester.getTopLeft(find.byType(Wrap));
    // a (60) + gap (20) fit in 120; b starts the second run.
    expect(tester.getTopLeft(rectOf('b')) - origin, const Offset(0, 20));
  });

  testWidgets('wrap is off by default and ignored on columns', (tester) async {
    final children = [rect('a'), rect('b')];
    await pump(tester, wrapRow(children, wrap: false), children);
    expect(find.byType(Wrap), findsNothing);

    final columnChildren = [rect('c'), rect('d')];
    await pump(
      tester,
      wrapRow(
        columnChildren,
        type: RowColumnType.column,
        verticalFit: SizeFit.fixed,
        height: 100,
      ),
      columnChildren,
    );
    expect(find.byType(Wrap), findsNothing);
  });
}
