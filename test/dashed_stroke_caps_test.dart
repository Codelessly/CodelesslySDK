import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'stroke_side_test.dart' show pumpNode, strokePaint;

/// A 100x100 circle (a fully rounded box) with a stroke of tiny dashes, like
/// the strobe dots on a turntable platter.
RectangleNode platter({
  required StrokeCapEnum cap,
  List<double> dashPattern = const [0, 10],
  StrokeSide side = StrokeSide.all,
}) => RectangleNode(
  id: 'platter',
  name: 'Platter',
  basicBoxLocal: NodeBox(0, 0, 100, 100),
  cornerRadius: const CornerRadius.all(RadiusModel.circular(50)),
  strokes: [PaintModel.solid(id: 'stroke', color: ColorRGB.fromHex('#000000'))],
  strokeWeight: 4,
  strokeAlign: StrokeAlignC.inside,
  strokeCap: cap,
  strokeSide: side,
  dashPattern: dashPattern,
)..parentID = kRootNode;

/// Paints [painter] into a [size] image and returns how many pixels have
/// any ink, so tests need no golden files.
Future<int> inkedPixels(
  WidgetTester tester,
  CustomPainter painter, {
  Size size = const Size(100, 100),
}) async {
  final int? count = await tester.runAsync(() async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    painter.paint(Canvas(recorder), size);
    final ui.Image image = await recorder.endRecording().toImage(
      size.width.toInt(),
      size.height.toInt(),
    );
    final ByteData bytes = (await image.toByteData())!;
    int inked = 0;
    for (int i = 3; i < bytes.lengthInBytes; i += 4) {
      if (bytes.getUint8(i) > 0) inked++;
    }
    return inked;
  });
  return count!;
}

StrokePainter painterFor({
  required StrokeCapEnum cap,
  List<double> dashPattern = const [0, 10],
  StrokeSide side = StrokeSide.all,
}) => StrokePainter(
  strokeWidth: 4,
  dashPattern: dashPattern,
  strokeCap: cap,
  strokeSide: side,
  borderRadius: BorderRadius.circular(50),
);

void main() {
  testWidgets('Zero-length dashes with round caps paint a dot each, inside '
      'the stroke band', (tester) async {
    await pumpNode(tester, platter(cap: StrokeCapEnum.round));
    expect(tester.takeException(), isNull);
    // The first dash sits at the start of the stroke's center line, which is
    // half the stroke width inside the box.
    expect(
      strokePaint(),
      paints
        ..circle(radius: 2)
        ..circle(radius: 2)
        ..circle(radius: 2),
    );
    // A circle of center line radius 48 is ~301.6 long: 31 dots, 10 apart.
    final int inked = await inkedPixels(
      tester,
      painterFor(cap: StrokeCapEnum.round),
    );
    // Each dot is a circle of radius 2 (~12.6 px).
    expect(inked, greaterThan(31 * 8));
  });

  testWidgets('Zero-length dashes with square caps paint a square each', (
    tester,
  ) async {
    await pumpNode(tester, platter(cap: StrokeCapEnum.square));
    expect(tester.takeException(), isNull);
    expect(
      strokePaint(),
      paints
        ..path()
        ..path()
        ..path(),
    );
    expect(
      await inkedPixels(tester, painterFor(cap: StrokeCapEnum.square)),
      greaterThan(31 * 10),
    );
  });

  testWidgets('Dashes without caps and no length still paint nothing', (
    tester,
  ) async {
    expect(await inkedPixels(tester, painterFor(cap: StrokeCapEnum.none)), 0);
  });

  testWidgets('Tiny round dashes stay within the stroke band of the box', (
    tester,
  ) async {
    final int? outside = await tester.runAsync(() async {
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      painterFor(
        cap: StrokeCapEnum.round,
        dashPattern: const [0.001, 6],
      ).paint(Canvas(recorder), const Size(100, 100));
      final ui.Image image = await recorder.endRecording().toImage(120, 120);
      final ByteData bytes = (await image.toByteData())!;
      int count = 0;
      for (int y = 0; y < 120; y++) {
        for (int x = 0; x < 120; x++) {
          final double dx = x + 0.5 - 50, dy = y + 0.5 - 50;
          final double r2 = dx * dx + dy * dy;
          // Ink outside the circle, or deeper inside than the stroke reaches.
          if ((r2 > 51 * 51 || r2 < 45 * 45) &&
              bytes.getUint8((y * 120 + x) * 4 + 3) > 0) {
            count++;
          }
        }
      }
      return count;
    });
    expect(outside, 0);
  });

  testWidgets('Round dashes with length paint along the stroke', (
    tester,
  ) async {
    final int dots = await inkedPixels(
      tester,
      painterFor(cap: StrokeCapEnum.round),
    );
    final int dashes = await inkedPixels(
      tester,
      painterFor(cap: StrokeCapEnum.round, dashPattern: const [4, 6]),
    );
    expect(dashes, greaterThan(dots));
  });

  testWidgets('A dashed side with round caps draws dots too', (tester) async {
    expect(
      await inkedPixels(
        tester,
        painterFor(cap: StrokeCapEnum.round, side: StrokeSide.top),
      ),
      greaterThan(0),
    );
  });

  testWidgets('A pattern of zeros paints nothing and does not hang', (
    tester,
  ) async {
    expect(
      await inkedPixels(
        tester,
        painterFor(cap: StrokeCapEnum.round, dashPattern: const [0, 0]),
      ),
      0,
    );
  });
}
