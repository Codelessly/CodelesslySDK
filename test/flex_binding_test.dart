import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

RectangleNode bar(String id, {String? flex}) =>
    RectangleNode(
        id: id,
        name: id,
        basicBoxLocal: NodeBox(0, 0, 10, 20),
        horizontalFit: SizeFit.expanded,
      )
      ..parentID = 'row'
      ..variables.addAll({'flex': ?flex});

Future<Map<String, double>> pumpRow(
  WidgetTester tester,
  List<RectangleNode> bars,
) async {
  final RowColumnNode row = RowColumnNode(
    id: 'row',
    name: 'row',
    basicBoxLocal: NodeBox(0, 0, 300, 20),
    children: [for (final b in bars) b.id],
    rowColumnType: RowColumnType.row,
  )..parentID = kRootNode;
  final registry = NodeRegistry()
    ..setNodes({
      for (final node in [row, ...bars]) node.id: node,
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
  return {
    for (final b in bars)
      b.id: tester
          .getSize(
            find.byKey(ValueKey('Rectangle Transformer of ${b.id} [${b.id}]')),
          )
          .width,
  };
}

void main() {
  testWidgets('expanded children share the free space by their bound flex', (
    tester,
  ) async {
    // A temperature gauge: 52 below the band, 16 in it, 32 above it.
    final widths = await pumpRow(tester, [
      bar('low', flex: r'${= 52}'),
      bar('band', flex: r'${= 68 - 52}'),
      bar('high', flex: r'${= 100 - 68}'),
    ]);
    expect(widths['low'], closeTo(156, 0.5));
    expect(widths['band'], closeTo(48, 0.5));
    expect(widths['high'], closeTo(96, 0.5));
  });

  testWidgets('without a binding a child keeps its own flex', (tester) async {
    final widths = await pumpRow(tester, [bar('a'), bar('b', flex: r'${= 2}')]);
    expect(widths['a'], closeTo(100, 0.5));
    expect(widths['b'], closeTo(200, 0.5));
  });
}
