// Canvas viewport and location, layout id resolution and the initial
// screen; plus loading, caching and fonts.

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Node canvasNode(double w, double h, {ScaleMode mode = ScaleMode.responsive, bool hug = false, double? maxWidth}) => Node.fromJson({
      'type': 'canvas',
      'layout': {
        'width': w,
        'height': hug ? {'hug': h} : h,
        if (maxWidth != null) 'constraints': {'maxWidth': maxWidth},
      },
      if (mode != ScaleMode.responsive) 'props': {'scaleMode': mode.name},
    }, id: 'c')!;

void main() {

  group('CanvasViewport', () {
    const screen = BoxConstraints(maxWidth: 390, maxHeight: 844);

    test('a screen fills the space it is given', () {
      final box = CanvasViewport.resolve(canvasNode(1440, 900), screen);
      expect((box.width, box.height, box.scale), (390.0, 844.0, 1.0));
    });

    test('a dialog keeps its design size, within the screen', () {
      final c = canvasNode(1440, 900);
      final box = CanvasViewport.resolve(c, screen, sizing: CanvasSizing.design);
      expect((box.width, box.height), (390.0, 844.0));
      final wide = CanvasViewport.resolve(c, const BoxConstraints(maxWidth: 1920, maxHeight: 1080), sizing: CanvasSizing.design);
      expect((wide.width, wide.height), (1440.0, 900.0));
    });

    test('a sheet fills the width at its design height', () {
      final box = CanvasViewport.resolve(canvasNode(390, 300), const BoxConstraints(maxWidth: 800, maxHeight: 1000),
          sizing: CanvasSizing.fillWidth);
      expect((box.width, box.height), (800.0, 300.0));
    });

    test('with unlimited height a screen takes its design height, or its content\'s when it hugs', () {
      const tall = BoxConstraints(maxWidth: 390);
      expect(CanvasViewport.resolve(canvasNode(390, 844), tall).height, 844);
      expect(CanvasViewport.resolve(canvasNode(390, 844, hug: true), tall).height, isNull);
      expect(CanvasViewport.resolve(canvasNode(390, 844), const BoxConstraints(maxHeight: 500)).width, 390);
    });

    test('an auto-scaling screen lays out at its design width and scales to the space', () {
      final c = canvasNode(1440, 900, mode: ScaleMode.autoScale);
      final box = CanvasViewport.resolve(c, const BoxConstraints(maxWidth: 720));
      expect(box.layoutWidth, 1440);
      expect(box.scale, 0.5);
      expect(box.height, 450);
      final capped = CanvasViewport.resolve(canvasNode(1440, 900, mode: ScaleMode.autoScale, maxWidth: 720),
          const BoxConstraints(maxWidth: 2000, maxHeight: 1000));
      expect(capped.scale, 0.5);
      expect(capped.layoutHeight, 2000);
      expect(CanvasViewport.autoScaleHeight(c, 2880), 1800);
    });
  });

}

