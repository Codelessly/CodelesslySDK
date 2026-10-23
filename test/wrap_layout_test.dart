import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

RectangleNode _rect(
  String id, {
  double width = 140,
  double height = 40,
  SizeFit horizontalFit = SizeFit.fixed,
}) => RectangleNode(
  id: id,
  name: id,
  basicBoxLocal: NodeBox(0, 0, width, height),
  horizontalFit: horizontalFit,
)..parentID = 'specs';

RowColumnNode _specs(
  List<BaseNode> children, {
  RowColumnType type = RowColumnType.row,
  MainAxisAlignmentC mainAxisAlignment = MainAxisAlignmentC.start,
  CrossAxisAlignmentC crossAxisAlignment = CrossAxisAlignmentC.start,
  NodeBox? box,
  SizeFit horizontalFit = SizeFit.expanded,
  SizeFit verticalFit = SizeFit.shrinkWrap,
}) => RowColumnNode(
  id: 'specs',
  name: 'specs',
  basicBoxLocal: box ?? NodeBox(0, 0, 342, 88),
  children: [for (final child in children) child.id],
  rowColumnType: type,
  horizontalFit: horizontalFit,
  verticalFit: verticalFit,
  mainAxisAlignment: mainAxisAlignment,
  crossAxisAlignment: crossAxisAlignment,
  wrap: true,
  wrapSpacing: 24,
  wrapRunSpacing: 8,
)..parentID = kRootNode;

Finder _of(String id) =>
    find.byKey(ValueKey('Rectangle Transformer of $id [$id]'));

Future<void> _pump(
  WidgetTester tester,
  RowColumnNode root,
  List<BaseNode> children, {
  required double width,
  CodelesslyContext? codelesslyContext,
}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final registry = NodeRegistry()
    ..setNodes({
      for (final node in [root, ...children]) node.id: node,
    });
  final manager = PassiveNodeTransformerManager(
    registry.getNodeByID,
    (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
  );
  await tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: codelesslyContext ?? CodelesslyContext.empty(),
      child: MaterialApp(
        home: Scaffold(
          body: Align(
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
  final List<RectangleNode> specs = [_rect('odo'), _rect('loc'), _rect('pre')];

  testWidgets('children that do not fit wrap onto the next line at 390', (
    tester,
  ) async {
    await _pump(tester, _specs(specs), specs, width: 390);
    expect(tester.getTopLeft(_of('odo')), Offset.zero);
    expect(tester.getTopLeft(_of('loc')), const Offset(164, 0));
    // 140 + 24 + 140 + 24 + 140 = 468 > 390: the third starts a new line.
    expect(tester.getTopLeft(_of('pre')), const Offset(0, 48));
    // The row hugs its two lines.
    expect(tester.getSize(find.byType(Wrap)).height, 88);
  });

  for (final double width in [600, 834, 1440]) {
    testWidgets('all children fit on one line at $width', (tester) async {
      await _pump(tester, _specs(specs), specs, width: width);
      expect(tester.getTopLeft(_of('pre')), const Offset(328, 0));
      expect(tester.getSize(find.byType(Wrap)).height, 40);
    });
  }

  testWidgets('a column wraps into new columns', (tester) async {
    final List<RectangleNode> tall = [
      for (final id in ['a', 'b', 'c']) _rect(id, width: 60, height: 300),
    ];
    final RowColumnNode column = _specs(
      tall,
      type: RowColumnType.column,
      box: NodeBox(0, 0, 200, 700),
      horizontalFit: SizeFit.shrinkWrap,
      verticalFit: SizeFit.fixed,
    );
    await _pump(tester, column, tall, width: 390);
    expect(tester.getTopLeft(_of('b')), const Offset(0, 324));
    expect(tester.getTopLeft(_of('c')), const Offset(68, 0));
  });

  testWidgets('main and cross axis alignment place the lines', (tester) async {
    final List<RectangleNode> mixed = [
      _rect('odo'),
      _rect('loc', height: 20),
      _rect('pre'),
    ];
    await _pump(
      tester,
      _specs(
        mixed,
        mainAxisAlignment: MainAxisAlignmentC.end,
        crossAxisAlignment: CrossAxisAlignmentC.center,
      ),
      mixed,
      width: 390,
    );
    // Line one ends at the right edge; the short child is centered in it.
    expect(tester.getTopLeft(_of('loc')), const Offset(390 - 140, 10));
    expect(tester.getTopLeft(_of('pre')), const Offset(390 - 140, 48));
  });

  testWidgets('spacers and children hidden at runtime take no space', (
    tester,
  ) async {
    final SpacerNode spacer = SpacerNode(
      id: 'gap',
      name: 'gap',
      basicBoxLocal: NodeBox(0, 0, 100, 10),
      horizontalFit: SizeFit.expanded,
    )..parentID = 'specs';
    final RectangleNode hidden = _rect('hidden')
      ..variables['visible'] = r'${= false}';
    final List<BaseNode> children = [specs[0], spacer, hidden, specs[1]];
    await _pump(tester, _specs(children), children, width: 390);
    expect(_of('hidden'), findsNothing);
    expect(tester.getTopLeft(_of('loc')), const Offset(164, 0));
  });

  testWidgets('a child that expands on the main axis fills its own line', (
    tester,
  ) async {
    final RectangleNode wide = _rect(
      'wide',
      width: 100,
      horizontalFit: SizeFit.expanded,
    );
    final List<BaseNode> children = [specs[0], wide];
    await _pump(tester, _specs(children), children, width: 390);
    expect(tester.getRect(_of('wide')), const Rect.fromLTWH(0, 48, 390, 40));
  });

  test('wrap round-trips through JSON and is omitted when off', () {
    final RowColumnNode node = _specs(specs);
    final RowColumnNode copy = RowColumnNode.fromJson(node.toJson());
    expect(copy.wrap, isTrue);
    expect(copy.wrapSpacing, 24);
    expect(copy.wrapRunSpacing, 8);
    final Map json = (RowColumnNode.fromJson(
      node.toJson(),
    )..wrap = false).toJson();
    expect(json.containsKey('wrap'), isFalse);
  });
}
