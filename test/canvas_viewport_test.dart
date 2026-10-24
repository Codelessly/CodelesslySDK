import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final CanvasNode canvas = CanvasNode(
    id: 'canvas',
    name: 'Dialog',
    basicBoxLocal: NodeBox(0, 0, 1440, 900),
    children: const [],
    properties: CanvasProperties(bodyId: 'body'),
    scaleMode: ScaleMode.responsive,
  );
  const BoxConstraints screen = BoxConstraints(maxWidth: 390, maxHeight: 844);

  test('a dialog canvas keeps its design size', () {
    final box = CanvasViewport.resolve(
      canvas,
      screen,
      sizing: CanvasSizing.design,
    );
    expect(box.width, 390);
    expect(box.height, 844);
    final wide = CanvasViewport.resolve(
      canvas,
      const BoxConstraints(maxWidth: 1920, maxHeight: 1080),
      sizing: CanvasSizing.design,
    );
    expect((wide.width, wide.height), (1440.0, 900.0));
  });

  test('a responsive dialog canvas follows the screen', () {
    final box = CanvasViewport.resolve(
      canvas,
      const BoxConstraints(maxWidth: 1920, maxHeight: 1080),
      sizing: CanvasSizing.design,
      responsive: true,
    );
    expect((box.width, box.height), (1920.0, 1080.0));
  });

  test('a responsive popover canvas keeps its design size', () {
    final CanvasNode menu = CanvasNode(
      id: 'menu',
      name: 'Menu',
      basicBoxLocal: NodeBox(0, 0, 240, 160),
      children: const [],
      properties: CanvasProperties(bodyId: 'body'),
      scaleMode: ScaleMode.responsive,
    );
    final box = CanvasViewport.resolve(
      menu,
      const BoxConstraints(maxWidth: 1920, maxHeight: 1080),
      sizing: CanvasSizing.content,
      responsive: true,
    );
    expect((box.width, box.height), (240.0, 160.0));
  });
}
