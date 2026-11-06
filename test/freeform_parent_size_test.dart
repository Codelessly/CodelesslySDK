import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Finder _of(String id) => find.byKey(ValueKey('Rectangle Transformer of $id [$id]'));

void main() {
  testWidgets('a fixed-size child reads its freeform parent\'s size as parent', (
    tester,
  ) async {
    final RectangleNode fill = RectangleNode(
      id: 'fill',
      name: 'fill',
      basicBoxLocal: NodeBox(0, 0, 10, 14),
      positioningMode: PositioningMode.pin,
      edgePins: const EdgePinsModel(left: 0, top: 0, right: null, bottom: null),
    )..variables['width'] = r'${= 18 + (parent.width - 28) * 0.5}';
    final FrameNode track = FrameNode(
      id: 'track',
      name: 'track',
      basicBoxLocal: NodeBox(0, 0, 300, 36),
      children: ['fill'],
    )..parentID = kRootNode;
    fill.parentID = track.id;
    final NodeRegistry registry = NodeRegistry()..setNodes({track.id: track, fill.id: fill});
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
              builder: (c) => manager.buildWidgetFromNode(
                track,
                c,
                settings: const WidgetBuildSettings(debugLabel: 'test'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(_of('fill')).width, 18 + (300 - 28) * 0.5);
  });
}
