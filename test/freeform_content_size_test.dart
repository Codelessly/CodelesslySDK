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

  testWidgets('a drag track thumb reads its slot width as parent', (tester) async {
    final RectangleNode thumb = RectangleNode(
      id: 'thumb',
      name: 'thumb',
      basicBoxLocal: NodeBox(0, 4, 28, 28),
      positioningMode: PositioningMode.pin,
      edgePins: const EdgePinsModel(left: 0, top: 4, right: null, bottom: null),
    )
      ..drag = const DragModel(
        track: DragTrackModel(shape: DragTrackShape.line, variable: 'v', min: 0, max: 1, x2: 200),
      )
      ..variables['dragTrack.x2'] = r'${= parent.width - 28}';
    final FrameNode slot = FrameNode(
      id: 'slot',
      name: 'slot',
      basicBoxLocal: NodeBox(0, 0, 300, 36),
      children: ['thumb'],
    )..parentID = kRootNode;
    thumb.parentID = slot.id;
    final NodeRegistry registry = NodeRegistry()..setNodes({slot.id: slot, thumb.id: thumb});
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    final CodelesslyContext context = CodelesslyContext.empty()
      ..variables['v'] = Observable(VariableData(id: 'v', name: 'v', type: VariableType.decimal, value: 0.5));
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: context,
        child: MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: Builder(
              builder: (c) => manager.buildWidgetFromNode(
                slot,
                c,
                settings: const WidgetBuildSettings(debugLabel: 'test'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Half way along a 272 px track.
    expect(tester.getTopLeft(_of('thumb')).dx, closeTo(136, 1));
  });
}
