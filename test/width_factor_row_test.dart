import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// A bar's fill sized by a share of its track (`widthFactor`), the track
/// filling what's left of a row beside a label: the share is of the track,
/// not of the row around it.
void main() {
  testWidgets(
    'a widthFactor child of an expanded row takes a share of that row',
    (tester) async {
      RowColumnNode row(
        String id,
        String parent,
        List<String> children, {
        SizeFit h = SizeFit.expanded,
      }) => RowColumnNode(
        id: id,
        name: id,
        basicBoxLocal: NodeBox(0, 0, 300, 10),
        children: children,
        rowColumnType: RowColumnType.row,
        horizontalFit: h,
        verticalFit: SizeFit.fixed,
        crossAxisAlignment: CrossAxisAlignmentC.stretch,
      )..parentID = parent;
      final RowColumnNode outer = row('outer', kRootNode, ['label', 'track']);
      final RectangleNode label = RectangleNode(
        id: 'label',
        name: 'label',
        basicBoxLocal: NodeBox(0, 0, 100, 10),
      )..parentID = 'outer';
      final RowColumnNode track = row('track', 'outer', ['fill']);
      final RectangleNode fill =
          RectangleNode(
              id: 'fill',
              name: 'fill',
              basicBoxLocal: NodeBox(0, 0, 100, 10),
            )
            ..parentID = 'track'
            ..widthFactor = 0.5
            ..variables['widthFactor'] = r'${= 0.25}';
      final nodes = <BaseNode>[outer, label, track, fill];
      final registry = NodeRegistry()
        ..setNodes({for (final n in nodes) n.id: n});
      final manager = PassiveNodeTransformerManager(
        registry.getNodeByID,
        (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
      );
      tester.view.physicalSize = const Size(600, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ChangeNotifierProvider<CodelesslyContext>.value(
          value: CodelesslyContext.empty(),
          child: MaterialApp(
            home: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 600,
                child: Builder(
                  builder: (context) => manager.buildWidgetFromNode(
                    outer,
                    context,
                    settings: const WidgetBuildSettings(debugLabel: 'test'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      Rect rectOf(String id) => tester.getRect(
        find.byKey(ValueKey('Rectangle Transformer of $id [$id]')),
      );
      // The track is 600 - 100 = 500 wide; a quarter of it is 125.
      expect(rectOf('fill').width, closeTo(125, 0.5));
    },
  );
}
