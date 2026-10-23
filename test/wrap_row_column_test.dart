import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

RectangleNode box(String id, {double width = 60, double height = 30}) =>
    RectangleNode(id: id, name: id, basicBoxLocal: NodeBox(0, 0, width, height))
      ..parentID = 'row';

Finder findBox(String id) =>
    find.byKey(ValueKey('Rectangle Transformer of $id [$id]'));

/// Pumps [row] holding [boxes] at the top left of the screen.
Future<void> pumpRow(
  WidgetTester tester,
  RowColumnNode row,
  List<BaseNode> boxes,
) async {
  row
    ..parentID = kRootNode
    ..children = [for (final b in boxes) b.id];
  final registry = NodeRegistry()
    ..setNodes({
      for (final node in [row, ...boxes]) node.id: node,
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
                row,
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

RowColumnNode wrapRow({
  double width = 200,
  double height = 30,
  MainAxisAlignmentC mainAxisAlignment = MainAxisAlignmentC.start,
  CrossAxisAlignmentC crossAxisAlignment = CrossAxisAlignmentC.start,
  SizeFit verticalFit = SizeFit.shrinkWrap,
}) => RowColumnNode(
  id: 'row',
  name: 'row',
  basicBoxLocal: NodeBox(0, 0, width, height),
  children: [],
  rowColumnType: RowColumnType.row,
  mainAxisAlignment: mainAxisAlignment,
  crossAxisAlignment: crossAxisAlignment,
  verticalFit: verticalFit,
  wrap: true,
  spacing: 10,
  runSpacing: 8,
);

void main() {
  testWidgets('a wrapping row breaks its children into runs', (tester) async {
    final row = wrapRow();
    final boxes = [for (int i = 0; i < 6; i++) box('b$i')];
    await pumpRow(tester, row, boxes);

    expect(find.byType(Wrap), findsOneWidget);
    // 3 * 60 + 2 * 10 = 200: three boxes fit each run.
    const expected = [
      Offset(0, 0),
      Offset(70, 0),
      Offset(140, 0),
      Offset(0, 38),
      Offset(70, 38),
      Offset(140, 38),
    ];
    for (int i = 0; i < boxes.length; i++) {
      expect(
        tester.getTopLeft(findBox('b$i')),
        expected[i],
        reason: 'b$i in run ${i ~/ 3}',
      );
      expect(tester.getSize(findBox('b$i')), const Size(60, 30));
    }
    // The row hugs both runs vertically and keeps its width.
    expect(tester.getSize(find.byType(Wrap)), const Size(200, 68));
  });

  testWidgets('main axis alignment aligns the children in each run and the '
      'runs, cross axis alignment aligns children in their run', (
    tester,
  ) async {
    final row = wrapRow(
      height: 100,
      verticalFit: SizeFit.fixed,
      mainAxisAlignment: MainAxisAlignmentC.center,
      crossAxisAlignment: CrossAxisAlignmentC.end,
    );
    await pumpRow(tester, row, [
      box('a', width: 80, height: 20),
      box('b'),
      box('c'),
    ]);

    // Runs take 30 + 8 + 30 = 68 of 100 and start at 16. Run 1 takes 150 of
    // 200 and starts at 25; a is 20 tall in a 30 tall run.
    expect(tester.getTopLeft(findBox('a')), const Offset(25, 26));
    expect(tester.getTopLeft(findBox('b')), const Offset(115, 16));
    expect(tester.getTopLeft(findBox('c')), const Offset(70, 54));
  });

  testWidgets('expanded children are not flexed and take their own size', (
    tester,
  ) async {
    final row = wrapRow();
    await pumpRow(tester, row, [
      box('a'),
      box('wide', width: 100)..horizontalFit = SizeFit.expanded,
      box('c'),
    ]);
    expect(find.byType(Flexible), findsNothing);
    expect(tester.getSize(findBox('wide')), const Size(100, 30));
    expect(tester.getTopLeft(findBox('wide')), const Offset(70, 0));
    expect(tester.getTopLeft(findBox('c')), const Offset(0, 38));
  });

  testWidgets('a child hidden at runtime takes no room or spacing', (
    tester,
  ) async {
    final row = wrapRow();
    await pumpRow(tester, row, [
      box('a'),
      box('hidden')..variables['visible'] = r'${= false}',
      box('b'),
      box('c'),
    ]);
    expect(findBox('hidden'), findsNothing);
    expect(tester.getTopLeft(findBox('a')), Offset.zero);
    expect(tester.getTopLeft(findBox('b')), const Offset(70, 0));
    expect(tester.getTopLeft(findBox('c')), const Offset(140, 0));
    expect(tester.getSize(find.byType(Wrap)), const Size(200, 30));
  });

  testWidgets('without wrap the row is a single line', (tester) async {
    final row = wrapRow()..wrap = false;
    await pumpRow(tester, row, [box('a'), box('b')]);
    expect(find.byType(Wrap), findsNothing);
    expect(tester.getTopLeft(findBox('b')), const Offset(60, 0));
  });
}
