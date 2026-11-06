import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Finder _of(String id) =>
    find.byKey(ValueKey('Rectangle Transformer of $id [$id]'));

/// The Mixtape J-card stage: a fixed-height frame with padding whose
/// 320x354 content is scaled to fit (contentFit contain), in a scrolling
/// column, where its height is unbounded from above.
void main() {
  Future<void> pump(WidgetTester tester, {required bool scroll}) async {
    tester.view.physicalSize = const Size(700, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final RectangleNode card = RectangleNode(
      id: 'card',
      name: 'card',
      basicBoxLocal: NodeBox(0, 0, 320, 354),
      positioningMode: PositioningMode.pin,
      edgePins: const EdgePinsModel(left: 0, top: 0, right: null, bottom: null),
    )..parentID = 'stage';
    final FrameNode stage = FrameNode(
      id: 'stage',
      name: 'stage',
      basicBoxLocal: NodeBox(0, 0, 300, 418),
      children: ['card'],
      horizontalFit: SizeFit.expanded,
      verticalFit: SizeFit.fixed,
      padding: const EdgeInsetsModel.all(34),
      contentFit: Fit.contain,
      contentSize: const SizeC(320, 354),
    )..parentID = kRootNode;
    final registry = NodeRegistry()..setNodes({'stage': stage, 'card': card});
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    final Widget built = Builder(
      builder: (context) => manager.buildWidgetFromNode(
        stage,
        context,
        settings: const WidgetBuildSettings(debugLabel: 'test'),
      ),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: CodelesslyContext.empty(),
        child: MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 600,
              height: 1000,
              child: scroll
                  ? SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [const SizedBox(height: 100), built],
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [const SizedBox(height: 100), built],
                    ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  }

  for (final bool scroll in [false, true]) {
    testWidgets('padded scaled content sits centred (scroll: $scroll)', (tester) async {
      await pump(tester, scroll: scroll);
      final Rect stage = tester.getRect(_of('stage'));
      expect(stage.height, 418);
      final Rect card = tester.getRect(_of('card'));
      // 350 tall (418 - 2 x 34) and 320/354 x 350 wide, centred in the
      // padded box: 34 from the top.
      expect(card.height, closeTo(350, 0.5));
      expect(card.top - stage.top, closeTo(34, 0.5));
      expect(card.center.dx, closeTo(stage.center.dx, 0.5));
    });
  }
}
