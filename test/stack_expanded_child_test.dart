import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// A child of an align-positioned frame that is set to expanded fills the
/// frame on that axis, whether or not it has an alignment.
void main() {
  BaseNode child(
    String type,
    AlignmentModel alignment, {
    SizeFit horizontalFit = SizeFit.expanded,
    SizeFit verticalFit = SizeFit.fixed,
  }) {
    final NodeBox box = NodeBox(30, 20, 300, 48);
    const EdgePinsModel pins = EdgePinsModel(
      left: 30,
      top: 20,
      right: null,
      bottom: null,
    );
    final BaseNode node = switch (type) {
      'slider' => SliderNode(
        id: 'c',
        name: 'c',
        basicBoxLocal: box,
        value: 20,
        properties: SliderProperties(),
        edgePins: pins,
        positioningMode: PositioningMode.align,
        alignment: alignment,
        horizontalFit: horizontalFit,
        verticalFit: verticalFit,
      ),
      _ => RectangleNode(
        id: 'c',
        name: 'c',
        basicBoxLocal: box,
        edgePins: pins,
        positioningMode: PositioningMode.align,
        alignment: alignment,
        horizontalFit: horizontalFit,
        verticalFit: verticalFit,
      ),
    };
    return node..parentID = 'frame';
  }

  Future<Rect> pumpIn(WidgetTester tester, BaseNode node) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final FrameNode frame = FrameNode(
      id: 'frame',
      name: 'frame',
      basicBoxLocal: NodeBox(0, 0, 360, 200),
      children: [node.id],
      horizontalFit: SizeFit.expanded,
      verticalFit: SizeFit.expanded,
      edgePins: EdgePinsModel.standard,
      clipsContent: false,
    )..parentID = kRootNode;
    final registry = NodeRegistry()..setNodes({frame.id: frame, node.id: node});
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: CodelesslyContext.empty(),
        child: MaterialApp(
          home: Material(
            child: Builder(
              builder: (context) => manager.buildWidgetFromNode(
                frame,
                context,
                settings: const WidgetBuildSettings(debugLabel: 'test'),
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    final Finder finder = node is SliderNode
        ? find.byType(Slider)
        : find.byKey(ValueKey('Rectangle Transformer of ${node.debugLabel}'));
    return tester.getRect(finder);
  }

  for (final type in ['slider', 'rectangle']) {
    for (final alignment in [
      AlignmentModel.none,
      AlignmentModel.center,
      AlignmentModel.centerLeft,
    ]) {
      testWidgets('an expanded $type with alignment ${alignment.data} fills '
          'the frame width', (tester) async {
        final Rect rect = await pumpIn(tester, child(type, alignment));
        expect(rect.width, 390);
        expect(rect.left, 0);
      });
    }
  }

  testWidgets('a vertically expanded slider fills the frame height', (
    tester,
  ) async {
    final Rect rect = await pumpIn(
      tester,
      child(
        'slider',
        AlignmentModel.center,
        horizontalFit: SizeFit.fixed,
        verticalFit: SizeFit.expanded,
      ),
    );
    expect(rect.height, 844);
    expect(rect.width, 300);
  });

  testWidgets('a fixed slider with alignment keeps its size and alignment', (
    tester,
  ) async {
    final Rect rect = await pumpIn(
      tester,
      child('slider', AlignmentModel.center, horizontalFit: SizeFit.fixed),
    );
    expect(rect.width, 300);
    expect(rect.center.dx, 195);
  });
}
