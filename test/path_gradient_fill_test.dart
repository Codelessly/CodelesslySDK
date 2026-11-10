import 'dart:ui' as ui;

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ui.Color> pixel(PathNodePainter painter, Offset at) async {
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), const Size(100, 100));
  final image = await recorder.endRecording().toImage(100, 100);
  final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  final i = ((at.dy.toInt() * 100) + at.dx.toInt()) * 4;
  return ui.Color.fromARGB(
    data.getUint8(i + 3),
    data.getUint8(i),
    data.getUint8(i + 1),
    data.getUint8(i + 2),
  );
}

void main() {
  const square = 'M0 0 L100 0 L100 100 L0 100 Z';

  test('a path fills with a gradient over its box', () async {
    final painter = PathNodePainter(
      data: square,
      fills: const [
        PathFill.gradient(
          LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFF0000), Color(0xFF0000FF)],
          ),
        ),
      ],
    );
    final top = await pixel(painter, const Offset(50, 1));
    final bottom = await pixel(painter, const Offset(50, 98));
    expect((top.r * 255).round(), greaterThan(240));
    expect((bottom.b * 255).round(), greaterThan(240));
  });

  test('solid fills still paint, and gradients count for repaint', () async {
    final solid = PathNodePainter(
      data: square,
      fills: const [PathFill.color(Color(0xFF00FF00))],
    );
    expect((await pixel(solid, const Offset(50, 50))).g, closeTo(1, 0.01));
    final a = PathNodePainter(
      data: square,
      fills: const [
        PathFill.gradient(
          LinearGradient(colors: [Color(0xFF000000), Color(0xFFFFFFFF)]),
        ),
      ],
    );
    final b = PathNodePainter(
      data: square,
      fills: const [
        PathFill.gradient(
          LinearGradient(colors: [Color(0xFF000000), Color(0xFF00FF00)]),
        ),
      ],
    );
    expect(a.shouldRepaint(b), isTrue);
  });
}
