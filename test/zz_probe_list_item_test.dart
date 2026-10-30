import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Finder byId(String id) => find.byWidgetPredicate((w) {
  final k = w.key;
  return k is ValueKey &&
      k.value is String &&
      (k.value as String).endsWith('[$id]');
});

void main() {
  for (final bool stretch in [true, false])
    for (final SizeFit itemV in [SizeFit.expanded, SizeFit.fixed])
      testWidgets('probe stretch=$stretch itemV=$itemV', (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final outer = ListViewNode(
          id: 'outer',
          name: 'outer',
          basicBoxLocal: NodeBox(0, 0, 300, 200),
          horizontalFit: SizeFit.expanded,
          verticalFit: SizeFit.expanded,
          scrollDirection: AxisC.horizontal,
          properties: ListViewProperties(itemCount: 3),
          children: ['item'],
        )..parentID = kRootNode;
        final item = RowColumnNode(
          id: 'item',
          name: 'item',
          basicBoxLocal: NodeBox(0, 0, 288, 600),
          rowColumnType: RowColumnType.column,
          horizontalFit: SizeFit.fixed,
          verticalFit: itemV,
          crossAxisAlignment: stretch
              ? CrossAxisAlignmentC.stretch
              : CrossAxisAlignmentC.start,
          children: ['inner'],
        )..parentID = 'outer';
        final inner = ListViewNode(
          id: 'inner',
          name: 'inner',
          basicBoxLocal: NodeBox(0, 0, 300, 200),
          horizontalFit: SizeFit.expanded,
          verticalFit: SizeFit.expanded,
          properties: ListViewProperties(itemCount: 2),
          children: ['cell'],
        )..parentID = 'item';
        final cell = RowColumnNode(
          id: 'cell',
          name: 'cell',
          basicBoxLocal: NodeBox(0, 0, 272, 40),
          rowColumnType: RowColumnType.row,
          horizontalFit: SizeFit.expanded,
          verticalFit: SizeFit.fixed,
          children: [],
        )..parentID = 'inner';
        final registry = NodeRegistry()
          ..setNodes({
            for (final n in <BaseNode>[outer, item, inner, cell]) n.id: n,
          });
        final manager = PassiveNodeTransformerManager(
          registry.getNodeByID,
          (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
        );
        await tester.pumpWidget(
          ChangeNotifierProvider<CodelesslyContext>.value(
            value: CodelesslyContext.empty(),
            child: MaterialApp(
              home: Builder(
                builder: (context) => manager.buildWidgetFromNode(
                  outer,
                  context,
                  settings: const WidgetBuildSettings(debugLabel: 'test'),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        for (final id in ['outer', 'item', 'inner', 'cell']) {
          final f = byId(id);
          print(
            '$id: ${f.evaluate().length} ${f.evaluate().isEmpty ? '-' : tester.getSize(f.first)}',
          );
        }
      });
}
