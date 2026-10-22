import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

const ColorRGBA yellow = ColorRGBA(r: 1, g: 0.8, b: 0, a: 1);

/// 10px yellow and black stripes at 45°.
PaintModel stripes({
  GradientTileMode tileMode = GradientTileMode.repeated,
  double? extent = 20,
  PaintType type = PaintType.gradientLinear,
}) => PaintModel(
  id: 'stripes',
  type: type,
  gradientTransform: applyGradientRotation(null, 45),
  gradientStops: const [
    ColorStop(color: yellow, position: 0),
    ColorStop(color: yellow, position: 0.5),
    ColorStop(color: ColorRGBA.black, position: 0.5),
    ColorStop(color: ColorRGBA.black, position: 1),
  ],
  tileMode: tileMode,
  gradientExtent: extent,
);

Future<void> pumpNode(WidgetTester tester, BaseNode node) async {
  final registry = NodeRegistry()..setNodes({node.id: node});
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
            builder: (context) => manager.buildWidgetFromNode(
              node,
              context,
              settings: const WidgetBuildSettings(debugLabel: 'test'),
            ),
          ),
        ),
      ),
    ),
  );
}

/// The gradients of the fills painted on screen.
List<Gradient> paintedGradients(WidgetTester tester) => [
  for (final Widget widget in tester.allWidgets)
    if (widget is Ink && widget.decoration is BoxDecoration)
      (widget.decoration as BoxDecoration).gradient
    else if (widget is DecoratedBox && widget.decoration is BoxDecoration)
      (widget.decoration as BoxDecoration).gradient,
].nonNulls.toList();

void main() {
  test('a repeating gradient tiles over its extent', () {
    final gradient = retrieveGradient(stripes()) as LinearGradient;
    expect(gradient.tileMode, TileMode.repeated);
    expect(gradient.stops, [0, 0.5, 0.5, 1]);
    expect(
      gradient.transform,
      const GradientExtentTransform(radians: pi / 4, extent: 20),
    );

    // One run of the gradient, from the box's left to its right edge before
    // the transform, is 20px long after it, whatever the box's size.
    const Rect bounds = Rect.fromLTWH(0, 0, 300, 8);
    final matrix = gradient.transform!.transform(bounds)!;
    final Offset start = MatrixUtils.transformPoint(matrix, bounds.centerLeft);
    final Offset end = MatrixUtils.transformPoint(matrix, bounds.centerRight);
    expect((end - start).distance, closeTo(20, 1e-9));
    expect((end - start).direction, closeTo(pi / 4, 1e-9));
    expect((start + end) / 2, bounds.center);
  });

  test('a radial gradient repeats over its radius', () {
    final gradient = retrieveGradient(
      stripes(type: PaintType.gradientRadial),
    ) as RadialGradient;
    expect(gradient.tileMode, TileMode.repeated);
    const Rect bounds = Rect.fromLTWH(0, 0, 100, 40);
    final matrix = gradient.transform!.transform(bounds)!;
    // The unscaled radius is half the shortest side, 20px; one run is 20px.
    final Offset edge = MatrixUtils.transformPoint(
      matrix,
      bounds.center + const Offset(20, 0),
    );
    expect((edge - bounds.center).distance, closeTo(20, 1e-9));
  });

  test('a gradient without an extent keeps spanning its box', () {
    final gradient = retrieveGradient(
      stripes(tileMode: GradientTileMode.clamp, extent: null),
    ) as LinearGradient;
    expect(gradient.tileMode, TileMode.clamp);
    expect(gradient.transform, const GradientRotation(pi / 4));

    final mirrored = retrieveGradient(
      stripes(tileMode: GradientTileMode.mirror),
    ) as LinearGradient;
    expect(mirrored.tileMode, TileMode.mirror);
  });

  testWidgets('a rectangle paints its fill as repeating stripes', (
    tester,
  ) async {
    await pumpNode(
      tester,
      RectangleNode(
        id: 'bar',
        name: 'Hazard Bar',
        basicBoxLocal: NodeBox(0, 0, 300, 8),
        fills: [stripes()],
      )..parentID = kRootNode,
    );
    final gradients = paintedGradients(tester);
    expect(gradients, hasLength(1));
    expect((gradients.single as LinearGradient).tileMode, TileMode.repeated);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a frame paints its fill as repeating stripes', (tester) async {
    await pumpNode(
      tester,
      FrameNode(
        id: 'frame',
        name: 'Hazard Frame',
        basicBoxLocal: NodeBox(0, 0, 300, 10),
        fills: [stripes()],
        children: const [],
      )..parentID = kRootNode,
    );
    final gradients = paintedGradients(tester);
    expect(gradients, hasLength(1));
    expect(
      gradients.single.transform,
      const GradientExtentTransform(radians: pi / 4, extent: 20),
    );
  });

  testWidgets('hard stops paint crisp stripes every extent', (tester) async {
    final GlobalKey key = GlobalKey();
    await tester.pumpWidget(
      Align(
        alignment: Alignment.topLeft,
        child: RepaintBoundary(
          key: key,
          child: SizedBox(
            width: 100,
            height: 4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                // Upright stripes: left to right, 10px yellow then 10px black.
                gradient: retrieveGradient(
                  stripes().copyWith(
                    gradientTransform: applyGradientRotation(null, 0),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final ByteData bytes = (await tester.runAsync<ByteData>(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage();
      return (await image.toByteData())!;
    }))!;
    Color pixel(int x) => Color(
      // RGBA bytes to ARGB.
      bytes.getUint32(x * 4, Endian.big) >> 8 | bytes.getUint8(x * 4 + 3) << 24,
    );
    const Color black = Color(0xFF000000);
    final Color yellowColor = yellow.toFlutterColor();
    // One run, 20px, is centered on the box: it starts at x = 40.
    for (final int start in [0, 20, 40, 60, 80]) {
      expect(pixel(start + 2), yellowColor, reason: 'x = ${start + 2}');
      expect(pixel(start + 8), yellowColor, reason: 'x = ${start + 8}');
      expect(pixel(start + 12), black, reason: 'x = ${start + 12}');
      expect(pixel(start + 18), black, reason: 'x = ${start + 18}');
    }
  });
}
