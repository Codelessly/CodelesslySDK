import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// A dialog whose canvas holds a responsive layout fills the screen, and its
/// layout draws the dialog: the canvas's own fill would hide the screen
/// behind the barrier, so it paints none there.
void main() {
  final CanvasNode canvas = CanvasNode(
    id: 'dialog',
    name: 'New card',
    basicBoxLocal: NodeBox(0, 0, 520, 600),
    scaleMode: ScaleMode.responsive,
    children: const ['layout'],
    properties: CanvasProperties(bodyId: 'layout'),
  );
  final VarianceNode layout = VarianceNode(
    id: 'layout',
    name: 'layout',
    basicBoxLocal: NodeBox(0, 0, 520, 600),
    variants: [
      Variant(
        id: 'default',
        name: 'Mobile',
        children: const [],
        breakpoint: ScreenBreakpoint.mobile,
      ),
    ],
  );
  final Map<String, BaseNode> nodes = {canvas.id: canvas, layout.id: layout};
  final PassiveNodeTransformerManager manager = PassiveNodeTransformerManager(
    (id) => nodes[id]!,
    (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
  );
  final PassiveCanvasTransformer transformer = manager
      .getTransformer<PassiveCanvasTransformer>();

  test('a responsive dialog canvas paints no fill over the screen', () {
    expect(transformer.showsOverScreen(CanvasSizing.design, canvas), isTrue);
    // As a screen, or as a sheet or popover sized by itself, it keeps it.
    expect(transformer.showsOverScreen(CanvasSizing.fill, canvas), isFalse);
    expect(transformer.showsOverScreen(CanvasSizing.sheet, canvas), isFalse);
    expect(transformer.showsOverScreen(CanvasSizing.content, canvas), isFalse);
  });
}
