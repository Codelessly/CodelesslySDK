import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// A status bar: segments whose flex is bound to counts.
void main() {
  RectangleNode segment(String id, String flexPath) => RectangleNode.fromJson({
    ...RectangleNode(
      id: id,
      name: id,
      basicBoxLocal: NodeBox(0, 0, 10, 8),
      horizontalFit: SizeFit.expanded,
    ).toJson(),
    'variables': {'flex': flexPath},
  })..parentID = 'bar';

  Future<Observable<VariableData>> pumpBar(
    WidgetTester tester, {
    double spacing = 0,
  }) async {
    final RowColumnNode bar = RowColumnNode(
      id: 'bar',
      name: 'bar',
      basicBoxLocal: NodeBox(0, 0, 400, 8),
      rowColumnType: RowColumnType.row,
      spacing: spacing,
      children: ['a', 'b', 'c'],
    )..parentID = kRootNode;
    final nodes = [
      bar,
      segment('a', r'${counts.closed}'),
      segment('b', r'${= counts.open * 1}'),
      segment('c', r'${counts.review}'),
    ];
    final Observable<VariableData> counts = Observable(
      VariableData(
        id: 'counts',
        name: 'counts',
        type: VariableType.map,
        value: {'closed': 3, 'open': 1, 'review': 0},
      ),
    );
    final registry = NodeRegistry()..setNodes({for (final n in nodes) n.id: n});
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: CodelesslyContext.empty()..variables['counts'] = counts,
        child: MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: Builder(
              builder: (context) => manager.buildWidgetFromNode(
                bar,
                context,
                settings: const WidgetBuildSettings(debugLabel: 'test'),
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    return counts;
  }

  Rect rect(WidgetTester tester, String id) => tester.getRect(
    find.byKey(ValueKey('Rectangle Transformer of $id [$id]')),
  );
  double width(WidgetTester tester, String id) => rect(tester, id).width;

  testWidgets('segments take shares of the width from their bound flex', (
    tester,
  ) async {
    final counts = await pumpBar(tester);
    double width(String id) => rect(tester, id).width;
    expect(width('a'), 300);
    expect(width('b'), 100);
    expect(width('c'), 0);

    counts.set(
      counts.value.copyWith(value: {'closed': 1, 'open': 1, 'review': 2}),
    );
    await tester.pump();
    expect(width('a'), 100);
    expect(width('c'), 200);
  });

  testWidgets('a zero flex segment takes no space and no spacing', (
    tester,
  ) async {
    await pumpBar(tester, spacing: 8);
    // One gap between the two shown segments: (400 - 8) split 3:1.
    expect(width(tester, 'a'), 294);
    expect(width(tester, 'b'), 98);
    expect(rect(tester, 'b').left, 302);
    expect(width(tester, 'c'), 0);
  });
}
