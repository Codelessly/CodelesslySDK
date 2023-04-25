import 'package:flutter/material.dart';
import 'dart:ui' as ui;

class BackgroundPaint extends CustomPainter {
  final Color blue;
  final Color lightBlue;
  final Color purple;
  final Color yellow;
  final double anim;

  BackgroundPaint({
    required this.blue,
    required this.lightBlue,
    required this.purple,
    required this.yellow,
    required this.anim,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // final double diagonal = sqrt(pow(size.width, 2) + pow(size.height, 2));
    // const double rectWidth = 350;
    // const double rectHeight = 550;
    final double rectWidth = size.shortestSide * 0.75;
    final double rectHeight = size.shortestSide * 0.9;
    // final double horizontalOffset = size.width / 3;

    final Paint bluePaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = ui.Gradient.radial(
        Offset(rectWidth, 0),
        size.shortestSide,
        [blue, lightBlue],
      );
    final Paint bluePaintInverse = Paint()
      ..style = PaintingStyle.fill
      ..shader = ui.Gradient.radial(
        Offset(rectWidth, 0),
        size.shortestSide,
        [lightBlue, blue],
      );
    final Paint pinkPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = ui.Gradient.radial(
        Offset(rectWidth, 0),
        size.shortestSide,
        [blue, purple],
      );
    // final Paint pinkPaintInverse = Paint()
    //   ..style = PaintingStyle.fill
    //   ..shader = ui.Gradient.radial(
    //     const Offset(rectWidth, 0),
    //     size.shortestSide,
    //     [color2, color1],
    //   );
    final Paint yellowPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = ui.Gradient.radial(
        Offset(rectWidth, 0),
        size.shortestSide,
        [purple, yellow],
      );
    // final Paint yellowPaintInverse = Paint()
    //   ..style = PaintingStyle.fill
    //   ..shader = ui.Gradient.radial(
    //     const Offset(rectWidth, 0),
    //     size.shortestSide,
    //     [color3, color2],
    //   );

    // YELLOW
    final double bottom1 = rectHeight;
    final Path path1 = Path()
      ..moveTo(0, 0)
      ..lineTo(rectWidth, 0)
      ..cubicTo(
        rectWidth * 1,
        bottom1 * 0.8,
        rectWidth * 0,
        bottom1 * 0.5,
        0,
        bottom1,
      )
      ..close();

    canvas.drawShadow(path1, Colors.black, 10, false);
    canvas.drawPath(path1, yellowPaint);

    // PINK
    final double bottom2 = rectHeight - 150;
    final Path path2 = Path()
      ..moveTo(0, 0)
      ..lineTo(rectWidth, 0)
      ..cubicTo(
        rectWidth * 0.75,
        bottom2 * 0.7,
        rectWidth * 0.15,
        bottom2 * 0.5,
        0,
        bottom2,
      )
      ..close();

    canvas.drawShadow(path2, Colors.black, 10, false);
    canvas.drawPath(path2, pinkPaint);

    // BLUE
    final double bottom3 = rectHeight - 250;
    final Path path3 = Path()
      ..moveTo(0, 0)
      ..lineTo(rectWidth, 0)
      ..cubicTo(
        rectWidth * 0.5,
        bottom3 * 0.7,
        rectWidth * 0.25,
        bottom3 * 0.15,
        0,
        bottom3,
      )
      ..close();

    canvas.drawShadow(path3, Colors.black, 10, false);
    canvas.drawPath(path3, bluePaint);

    // BLUE INVERSE
    final double bottom3Inverse = rectHeight - 350;
    final Path path3Inverse = Path()
      ..moveTo(0, 0)
      ..lineTo(rectWidth, 0)
      ..cubicTo(
        rectWidth * 0.3,
        bottom3Inverse * 0.5,
        rectWidth * 0,
        bottom3Inverse * 0.05,
        0,
        bottom3Inverse,
      )
      ..close();

    canvas.drawPath(path3Inverse, bluePaintInverse);
  }

  @override
  bool shouldRepaint(covariant BackgroundPaint oldDelegate) =>
      oldDelegate.anim != anim;
}
