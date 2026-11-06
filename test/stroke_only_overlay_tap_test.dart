import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/functions/action_chain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// A card whose outline is a stroke-only rectangle laid over its content
/// (a hand-drawn sketch line on top of a papercraft card). The outline has
/// no fill, so taps inside it reach the button underneath, as in Flutter
/// where an outline painted over a card doesn't block it.
void main() {
  testWidgets('a stroke-only rectangle on top lets taps through to a button', (
    tester,
  ) async {
    int taps = 0;
    final CodelesslyContext codelessly = CodelesslyContext.empty()
      ..functions = {'hit': (context, reference, params) => taps++};
    final FrameNode button =
        FrameNode(
            id: 'button',
            name: 'button',
            basicBoxLocal: NodeBox(20, 20, 300, 55),
            children: const ['edge', 'face'],
          )
          ..parentID = 'card'
          ..reactions = [
            Reaction(
              trigger: TriggerModel(type: TriggerType.click),
              action: CallFunctionAction(name: 'hit'),
            ),
          ];
    final RectangleNode edge = RectangleNode(
      id: 'edge',
      name: 'edge',
      basicBoxLocal: NodeBox(0, 5, 300, 50),
      positioningMode: PositioningMode.pin,
      edgePins: const EdgePinsModel(left: 0, top: 5, right: 0, bottom: 0),
      fills: [PaintModel.solid(id: 'edge-fill', color: ColorRGBA.black)],
    )..parentID = 'button';
    final RowColumnNode face = RowColumnNode(
      id: 'face',
      name: 'face',
      basicBoxLocal: NodeBox(0, 0, 300, 50),
      rowColumnType: RowColumnType.row,
      mainAxisAlignment: MainAxisAlignmentC.center,
      crossAxisAlignment: CrossAxisAlignmentC.center,
      padding: const EdgeInsetsModel.symmetric(horizontal: 22),
      fills: [PaintModel.solid(id: 'face-fill', color: ColorRGBA.white)],
      children: const ['label'],
    )..parentID = 'button';
    final TextNode label = TextNode(
      id: 'label',
      name: 'label',
      basicBoxLocal: NodeBox(100, 15, 60, 20),
      horizontalFit: SizeFit.shrinkWrap,
      verticalFit: SizeFit.shrinkWrap,
      data: 'Start',
    )..parentID = 'face';
    final FrameNode card = FrameNode(
      id: 'card',
      name: 'card',
      basicBoxLocal: NodeBox(0, 0, 340, 100),
      children: const ['button', 'sketch'],
    )..parentID = kRootNode;
    final RectangleNode sketch = RectangleNode(
      id: 'sketch',
      name: 'sketch',
      basicBoxLocal: NodeBox(0, 0, 340, 100),
      positioningMode: PositioningMode.pin,
      edgePins: const EdgePinsModel(left: 0, top: 0, right: 0, bottom: 0),
      strokeWeight: 1,
      strokes: [PaintModel.solid(id: 'sketch-stroke', color: ColorRGBA.black)],
      cornerRadius: CornerRadius.all(RadiusModel.circular(16)),
    )..parentID = 'card';
    final NodeRegistry registry = NodeRegistry()
      ..setNodes({
        for (final n in <BaseNode>[card, button, edge, face, label, sketch])
          n.id: n,
      });
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: codelessly,
        child: MaterialApp(
          home: ActionChainHost(
            child: Align(
              alignment: Alignment.topLeft,
              child: Builder(
                builder: (c) => manager.buildWidgetFromNode(
                  card,
                  c,
                  settings: const WidgetBuildSettings(debugLabel: 'test'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final Rect box = tester.getRect(
      find
          .byKey(const ValueKey('Rectangle Transformer of button [button]'))
          .first,
    );
    await tester.tapAt(box.center);
    await tester.pumpAndSettle();
    expect(taps, 1, reason: 'tap on the face');
    await tester.tapAt(box.bottomCenter - const Offset(0, 2));
    await tester.pumpAndSettle();
    expect(taps, 2, reason: 'tap on the edge');
  });
}
