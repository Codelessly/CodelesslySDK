import 'dart:math';

import 'package:flutter/material.dart';

class StripePainter extends CustomPainter {
  final Color bgColor;
  final Color stripeColor;
  final int nbOfStripes;
  final double? stripeWidth;

  StripePainter({
    required this.bgColor,
    required this.stripeColor,
    this.nbOfStripes = 10,
    this.stripeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double x = 0;
    const double y = 0;
    final double width = size.width;
    final double height = size.height;

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(x, y, width, height));

    final featuresCount = nbOfStripes;
    final maxDimension = max(width, height);
    final stripeW = stripeWidth ?? maxDimension / featuresCount / 6;
    var step = stripeW * 9;
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = bgColor;
    canvas.drawRect(Rect.fromLTWH(x, y, width, height), paint);
    final rectStripesCount =
        featuresCount * 3; // to make sure we cover the whole rectangle
    final allStripesPath = Path();
    for (var i = 1; i < rectStripesCount; i += 2) {
      final stripePath = Path();
      stripePath.moveTo(x - stripeW + step, y);
      stripePath.lineTo(x + step, y);
      stripePath.lineTo(x, y + step);
      stripePath.lineTo(x - stripeW, y + step);
      stripePath.close();
      allStripesPath.addPath(stripePath, Offset.zero);
      step += stripeW * 9;
    }
    paint
      ..style = PaintingStyle.fill
      ..color = stripeColor;
    canvas.drawPath(allStripesPath, paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
