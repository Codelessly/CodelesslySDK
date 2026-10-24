import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('an image fill keeps to the rounded corners', (tester) async {
    final RectangleNode board = RectangleNode(
      id: 'board',
      name: 'Board',
      basicBoxLocal: NodeBox(0, 0, 300, 200),
      cornerRadius: const CornerRadius.all(RadiusModel.circular(12)),
      fills: [
        PaintModel(
          id: 'topo',
          type: PaintType.image,
          downloadUrl: 'https://example.com/topo.png',
          opacity: 0.55,
        ),
      ],
    )..parentID = kRootNode;
    final registry = NodeRegistry()..setNodes({board.id: board});
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: CodelesslyContext.empty(),
        child: MaterialApp(
          home: Center(
            child: Builder(
              builder: (context) => manager.buildWidgetFromNode(
                board,
                context,
                settings: const WidgetBuildSettings(debugLabel: 'test'),
              ),
            ),
          ),
        ),
      ),
    );
    final Iterable<ClipRRect> clips = tester.widgetList<ClipRRect>(
      find.ancestor(
        of: find.byType(UltimateImageBuilder),
        matching: find.byType(ClipRRect),
      ),
    );
    expect(
      clips.map((clip) => clip.borderRadius),
      contains(BorderRadius.circular(12)),
    );
  });
}
