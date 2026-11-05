import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Path nodes paint gradient fills and strokes (a shirt badge shaded top to
/// bottom) and drop shadows that follow their outline, not their box.
void main() {
  Future<ByteData> render(PathNodePainter painter, Size size) async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    painter.paint(Canvas(recorder), size);
    final ui.Image image = await recorder.endRecording().toImage(size.width.toInt(), size.height.toInt());
    return (await image.toByteData())!;
  }

  Color pixel(ByteData data, int width, int x, int y) {
    final int i = (y * width + x) * 4;
    return Color.fromARGB(data.getUint8(i + 3), data.getUint8(i), data.getUint8(i + 1), data.getUint8(i + 2));
  }

  test('a linear gradient fill maps to a Gradient and shades the shape', () async {
    final PaintModel gradient = PaintModel.linearGradient(
      id: 'g',
      gradientBeginX: 0,
      gradientBeginY: -1,
      gradientEndX: 0,
      gradientEndY: 1,
      gradientStops: [
        ColorStop(position: 0, color: ColorRGBA(r: 1, g: 0, b: 0, a: 1)),
        ColorStop(position: 1, color: ColorRGBA(r: 0, g: 0, b: 1, a: 1)),
      ],
    );
    expect(pathPaintOf(gradient), isA<Gradient>());
    expect(pathPaintOf(PaintModel.solid(id: 's', color: ColorRGB.black)), isA<Color>());

    final ByteData data = await render(
      PathNodePainter(data: 'M0 0 H40 V40 H0 Z', fills: [pathPaintOf(gradient)!]),
      const Size(40, 40),
    );
    final Color top = pixel(data, 40, 20, 2), bottom = pixel(data, 40, 20, 37);
    expect((top.r * 255).round(), greaterThan(200));
    expect((top.b * 255).round(), lessThan(60));
    expect((bottom.b * 255).round(), greaterThan(200));
    expect((bottom.r * 255).round(), lessThan(60));
  });

  test('a drop shadow follows the outline of the path', () async {
    // A triangle in the top-left half of the box; its shadow is offset
    // down 10 px. The bottom-right corner of the box stays clear.
    final ByteData data = await render(
      PathNodePainter(
        data: 'M0 0 H30 L0 30 Z',
        fills: [const Color(0xFFFFFFFF)],
        shadows: [const BoxShadow(color: Color(0xFF000000), offset: Offset(0, 10))],
      ),
      const Size(40, 40),
    );
    expect(pixel(data, 40, 2, 36).a, greaterThan(0.9)); // under the triangle's lower tip: shadow
    expect(pixel(data, 40, 37, 37).a, 0); // the box's corner: nothing
    expect(pixel(data, 40, 5, 5), const Color(0xFFFFFFFF)); // the fill on top
  });

  testWidgets('a path node built from JSON paints its gradient body', (tester) async {
    final PathNode node = PathNode(
      id: 'shirt',
      name: 'Shirt',
      basicBoxLocal: NodeBox(0, 0, 40, 40),
      pathData: 'M0 0 H40 V40 H0 Z',
      fills: [
        PaintModel.linearGradient(id: 'g', gradientStops: [
          ColorStop(position: 0, color: ColorRGBA(r: 1, g: 0, b: 0, a: 1)),
          ColorStop(position: 1, color: ColorRGBA(r: 0, g: 0, b: 1, a: 1)),
        ]),
      ],
    );
    final PathNode copy = PathNode.fromJson(node.toJson());
    expect(copy.fills.single.type, PaintType.gradientLinear);
    expect(pathPaintOf(copy.fills.single), isA<Gradient>());
  });
}
