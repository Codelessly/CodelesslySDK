import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Four `flex: 1` tiles with 8 px margins between them (a gap) are equal:
/// a flex child's margin is fixed space, not part of its flex share.
void main() {
  RectangleNode tile(
    String id, {
    EdgeInsetsModel? margin,
    bool hidden = false,
  }) => RectangleNode.fromJson({
    ...RectangleNode(
      id: id,
      name: id,
      basicBoxLocal: NodeBox(0, 0, 10, 40),
      horizontalFit: SizeFit.expanded,
      margin: margin ?? EdgeInsetsModel.zero,
    ).toJson(),
    // Hidden at runtime, as a bound visibility hides it.
    if (hidden) 'variables': {'visible': r'${= false}'},
  })..parentID = 'row';

  Future<void> pump(WidgetTester tester, List<BaseNode> nodes) async {
    final registry = NodeRegistry()..setNodes({for (final n in nodes) n.id: n});
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: CodelesslyContext.empty(),
        child: MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: Builder(
              builder: (context) => manager.buildWidgetFromNode(
                nodes.first,
                context,
                settings: const WidgetBuildSettings(debugLabel: 'test'),
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  }

  Rect rect(WidgetTester tester, String id) => tester.getRect(
    find.byKey(ValueKey('Rectangle Transformer of $id [$id]')),
  );

  RowColumnNode parent(
    RowColumnType type,
    List<String> children, {
    double spacing = 0,
  }) => RowColumnNode(
    id: 'row',
    name: 'row',
    basicBoxLocal: type == RowColumnType.row
        ? NodeBox(0, 0, 552, 40)
        : NodeBox(0, 0, 40, 552),
    rowColumnType: type,
    mainAxisAlignment: MainAxisAlignmentC.start,
    spacing: spacing,
    children: children,
  )..parentID = kRootNode;

  testWidgets('equal flex tiles with a gap margin in a row', (tester) async {
    await pump(tester, [
      parent(RowColumnType.row, ['a', 'b', 'c', 'd']),
      tile('a'),
      tile('b', margin: const EdgeInsetsModel.only(left: 8)),
      tile('c', margin: const EdgeInsetsModel.only(left: 8)),
      tile('d', margin: const EdgeInsetsModel.only(left: 8, top: 4)),
    ]);
    for (final id in ['a', 'b', 'c', 'd']) {
      expect(rect(tester, id).width, 132, reason: id);
    }
    expect(rect(tester, 'b').left, 140);
    expect(rect(tester, 'd').left, 420);
    // The cross-axis margin still applies.
    expect(rect(tester, 'd').top, 4);
  });

  testWidgets('trailing margins in a column', (tester) async {
    final RowColumnNode column = parent(RowColumnType.column, ['a', 'b']);
    final a = tile('a', margin: const EdgeInsetsModel.only(bottom: 12))
      ..verticalFit = SizeFit.expanded
      ..horizontalFit = SizeFit.fixed;
    final b = tile('b')
      ..verticalFit = SizeFit.expanded
      ..horizontalFit = SizeFit.fixed;
    await pump(tester, [column, a, b]);
    expect(rect(tester, 'a').height, 270);
    expect(rect(tester, 'b').height, 270);
    expect(rect(tester, 'b').top, 282);
  });

  testWidgets('a hidden flex tile takes its margin with it', (tester) async {
    await pump(tester, [
      parent(RowColumnType.row, ['a', 'b']),
      tile('a'),
      tile('b', margin: const EdgeInsetsModel.only(left: 8), hidden: true),
    ]);
    expect(rect(tester, 'a').width, 552);
  });

  testWidgets('spacing goes around a tile and its margins', (tester) async {
    await pump(tester, [
      parent(RowColumnType.row, ['a', 'b', 'c', 'd'], spacing: 10),
      tile('a', margin: const EdgeInsetsModel.only(right: 4)),
      tile('b', margin: const EdgeInsetsModel.only(left: 8)),
      tile('c', margin: const EdgeInsetsModel.only(left: 8)),
      tile('d', margin: const EdgeInsetsModel.only(left: 8)),
    ]);
    // 552 - 3 gaps of 10 - margins of 4 + 3 * 8 = 494, in four.
    for (final id in ['a', 'b', 'c', 'd']) {
      expect(rect(tester, id).width, 123.5, reason: id);
    }
    expect(rect(tester, 'b').left, 123.5 + 4 + 10 + 8);
    expect(rect(tester, 'd').right, 552);
  });

  testWidgets('a hidden tile takes its margin, and a gap, with it', (
    tester,
  ) async {
    await pump(tester, [
      parent(RowColumnType.row, ['a', 'b'], spacing: 10),
      tile('a'),
      tile('b', margin: const EdgeInsetsModel.only(left: 8), hidden: true),
    ]);
    expect(rect(tester, 'a').width, 552);
  });
}
