import 'dart:math';
import 'dart:ui' as ui;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;
import 'package:flutter_test/flutter_test.dart';

PaintModel stripes({double? every, List<num>? transform}) => PaintModel(
  id: 'p',
  type: PaintType.gradientLinear,
  gradientTransform: transform,
  gradientRepeatEvery: every,
  gradientStops: const [
    ColorStop(position: 0, color: ColorRGBA(r: 1, g: 1, b: 0, a: 1)),
    ColorStop(position: 0.5, color: ColorRGBA(r: 1, g: 1, b: 0, a: 1)),
    ColorStop(position: 0.5, color: ColorRGBA.black),
    ColorStop(position: 1, color: ColorRGBA.black),
  ],
);

void main() {
  test('a repeating gradient tiles at a fixed pixel period', () {
    final LinearGradient gradient =
        retrieveGradient(stripes(every: 20))! as LinearGradient;
    expect(gradient.tileMode, TileMode.repeated);
    final Matrix4 m = gradient.transform!.transform(
      const Rect.fromLTWH(0, 0, 100, 40),
    )!;
    // The gradient's end (the right edge, x 100) lands 20 px from the left.
    expect(m.transform3(Vector3(100, 20, 0)).x, closeTo(20, 1e-9));
    expect(m.transform3(Vector3(0, 20, 0)).x, closeTo(0, 1e-9));
  });

  test('without a period it still stretches across the box', () {
    final LinearGradient gradient =
        retrieveGradient(stripes())! as LinearGradient;
    expect(gradient.tileMode, TileMode.clamp);
    expect(gradient.transform, isA<GradientRotation>());
  });

  testWidgets('paints even stripes at any width', (tester) async {
    Future<List<int>> row(double width) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        Center(
          child: RepaintBoundary(
            key: key,
            child: Container(
              width: width,
              height: 10,
              decoration: BoxDecoration(
                gradient: retrieveGradient(stripes(every: 20)),
              ),
            ),
          ),
        ),
      );
      late List<int> reds;
      await tester.runAsync(() async {
        final RenderRepaintBoundary boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final ui.Image image = await boundary.toImage();
        final data = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        // The red channel along the middle row, sampled mid-band: yellow
        // (255) then black (0), every 10 px, at both widths.
        reds = [
          for (final int x in const <int>[5, 15, 25, 35, 45, 55])
            data.getUint8(
              ((5 * image.width) + min<int>(x, image.width - 1)) * 4,
            ),
        ];
      });
      return reds;
    }

    expect(await row(60), [255, 0, 255, 0, 255, 0]);
    expect(await row(300), [255, 0, 255, 0, 255, 0]);
  });
}
