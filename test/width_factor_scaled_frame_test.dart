import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// A frame sized as a fraction of its row (widthFactor), square
/// (layoutAspectRatio), scaling its content to fit (contentFit): the vault
/// doors on Safecracker's wall, 74% of each tile.
void main() {
  Future<Size> frameSize(WidgetTester tester, double design, double rowWidth) async {
    final nodes = <BaseNode>[
      RowColumnNode(
        id: 'row',
        name: 'row',
        rowColumnType: RowColumnType.row,
        basicBoxLocal: NodeBox(0, 0, rowWidth, 300),
        horizontalFit: SizeFit.fixed,
        verticalFit: SizeFit.fixed,
        mainAxisAlignment: MainAxisAlignmentC.center,
        children: ['box'],
      )..parentID = kRootNode,
      FrameNode(
          id: 'box',
          name: 'box',
          basicBoxLocal: NodeBox(0, 0, design, design),
          horizontalFit: SizeFit.fixed,
          verticalFit: SizeFit.fixed,
          children: ['art'],
        )
        ..parentID = 'row'
        ..widthFactor = 0.74
        ..layoutAspectRatio = 1
        ..contentFit = Fit.contain
        ..contentSize = SizeC(design, design),
      FrameNode(id: 'art', name: 'art', basicBoxLocal: NodeBox(0, 0, design, design), children: [])
        ..parentID = 'box',
    ];
    final registry = NodeRegistry()..setNodes({for (final n in nodes) n.id: n});
    final manager = PassiveNodeTransformerManager(registry.getNodeByID, (a, b, c, d, e) => const SizedBox());
    await tester.pumpWidget(ChangeNotifierProvider<CodelesslyContext>.value(
      value: CodelesslyContext.empty(),
      child: MaterialApp(
        home: Material(
          child: Align(
            alignment: Alignment.topLeft,
            child: Builder(
              builder: (context) => manager.buildWidgetFromNode(nodes.first, context,
                  settings: const WidgetBuildSettings(debugLabel: 'test', withReactions: true)),
            ),
          ),
        ),
      ),
    ));
    return tester.getSize(find.byKey(const ValueKey('box')).first);
  }

  testWidgets('74% of a 224 wide row is 166, whatever the design size', (tester) async {
    for (final double design in [120, 160, 240]) {
      final Size s = await frameSize(tester, design, 224);
      expect(s.width, closeTo(224 * 0.74, 1), reason: 'design $design');
      expect(s.height, closeTo(224 * 0.74, 1), reason: 'design $design');
    }
  });
}
