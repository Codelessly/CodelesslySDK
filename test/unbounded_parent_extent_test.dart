import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// A `widthFactor` (or `${parent.width}`) on an axis its parent lays it out
// unbounded on takes the parent's extent there, as the design canvas
// shows: the Energy chart's seven bar slots (items of a horizontal list,
// widthFactor 1/7) and the By-room fill bars (a fixed child of a row,
// widthFactor = the room's share).

Finder _of(String id) =>
    find.byKey(ValueKey('Rectangle Transformer of $id [$id]'));

Future<void> _pump(WidgetTester tester, List<BaseNode> nodes) async {
  tester.view.physicalSize = const Size(800, 600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final registry = NodeRegistry()..setNodes({for (final n in nodes) n.id: n});
  final manager = PassiveNodeTransformerManager(
    registry.getNodeByID,
    (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
  );
  await tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: CodelesslyContext.empty()
        ..variables['days'] = Observable(
          VariableData(
            id: 'days',
            name: 'days',
            type: VariableType.list,
            value: [1, 2, 3, 4, 5, 6, 7],
          ),
        ),
      child: MaterialApp(
        home: Scaffold(
          body: Align(
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
    ),
  );
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('a horizontal list\'s items take a fraction of its width', (
    tester,
  ) async {
    final ListViewNode bars = ListViewNode(
      id: 'bars',
      name: 'bars',
      basicBoxLocal: NodeBox(0, 0, 350, 180),
      scrollDirection: AxisC.horizontal,
      isScrollable: false,
      properties: ListViewProperties(),
      children: ['slot'],
      variables: {'data': r'${days}'},
    )..parentID = kRootNode;
    final RectangleNode slot =
        RectangleNode(
            id: 'slot',
            name: 'slot',
            basicBoxLocal: NodeBox(0, 0, 40, 180),
          )
          ..parentID = 'bars'
          ..variables['widthFactor'] = r'${= 1 / 7}';
    await _pump(tester, [bars, slot]);
    expect(_of('slot'), findsNWidgets(7));
    expect(tester.getSize(_of('slot').first).width, closeTo(50, 0.01));
    expect(
      tester.getTopLeft(_of('slot').at(6)).dx -
          tester.getTopLeft(_of('slot').first).dx,
      closeTo(300, 0.01),
    );
  });

  testWidgets('a fixed child of a row takes a fraction of the row', (
    tester,
  ) async {
    final RowColumnNode track = RowColumnNode(
      id: 'track',
      name: 'track',
      rowColumnType: RowColumnType.row,
      basicBoxLocal: NodeBox(0, 0, 300, 8),
      children: ['fill'],
    )..parentID = kRootNode;
    final RectangleNode fill =
        RectangleNode(
            id: 'fill',
            name: 'fill',
            basicBoxLocal: NodeBox(0, 0, 100, 8),
          )
          ..parentID = 'track'
          ..widthFactor = 0.4;
    await _pump(tester, [track, fill]);
    expect(tester.getSize(_of('fill')).width, closeTo(120, 0.01));
  });

  testWidgets('a child of a hugging row keeps its own width', (tester) async {
    final RowColumnNode track = RowColumnNode(
      id: 'track',
      name: 'track',
      rowColumnType: RowColumnType.row,
      basicBoxLocal: NodeBox(0, 0, 300, 8),
      horizontalFit: SizeFit.shrinkWrap,
      children: ['fill', 'other'],
    )..parentID = kRootNode;
    final RectangleNode fill =
        RectangleNode(
            id: 'fill',
            name: 'fill',
            basicBoxLocal: NodeBox(0, 0, 100, 8),
          )
          ..parentID = 'track'
          ..variables['width'] = r'${= parent.width == null ? 33 : 99}';
    final RectangleNode other = RectangleNode(
      id: 'other',
      name: 'other',
      basicBoxLocal: NodeBox(0, 0, 10, 8),
    )..parentID = 'track';
    await _pump(tester, [track, fill, other]);
    expect(tester.getSize(_of('fill')).width, 33);
  });
}
