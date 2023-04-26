import 'dart:math';

import 'package:flutter/material.dart';

import '../../../codelessly_sdk.dart';

class PlaceholderPainter extends CustomPainter {
  final Color bgColor;
  final Color dashColor;
  final TextSpan? textSpan;
  final double scaleInverse;
  final double scale;

  late final Paint bgPaint = Paint()
    ..style = PaintingStyle.fill
    ..color = bgColor;

  PlaceholderPainter({
    required this.bgColor,
    required this.dashColor,
    required this.textSpan,
    required this.scaleInverse,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    double gap = 2;

    double outerLeft = gap;
    double outerTop = gap;
    double outerWidth = size.width - gap * 2;
    double outerHeight = size.height - gap * 2;
    if (outerWidth <= 1) {
      outerWidth = size.width;
      outerTop = 0;
    }
    if (outerHeight <= 1) {
      outerHeight = size.height;
      outerLeft = 0;
    }

    final Rect outerRect =
        Rect.fromLTWH(outerLeft, outerTop, outerWidth, outerHeight);

    canvas.drawRect(
      outerRect,
      bgPaint,
    );

    gap = 4;
    double innerWidth = size.width - gap * 4;
    double innerHeight = size.height - gap * 4;
    double innerLeft = gap * 2;
    double innerTop = gap * 2;
    // if (innerWidth <= 1) {
    //   innerWidth = outerWidth;
    //   innerLeft = outerLeft;
    // }
    // if (innerHeight <= 1) {
    //   innerHeight = outerHeight;
    //   innerTop = outerTop;
    // }

    final Rect innerRect =
        Rect.fromLTWH(innerLeft, innerTop, innerWidth, innerHeight);

    canvas.drawRect(innerRect, bgPaint);

    final Path path = dashPath(
      Path()..addRect(innerRect),
      6 * scaleInverse,
      6 * scaleInverse,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = dashColor
        ..strokeWidth = 1.5 * scaleInverse
        ..style = PaintingStyle.stroke,
    );

    if (textSpan == null) return;

    final maxWidth = size.width - gap * 2;
    final maxHeight = size.height - gap * 2;

    final TextPainter textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '...',
      textAlign: TextAlign.center,
    )..layout(maxWidth: maxWidth < 100 ? 100 : double.infinity);

    final textWidth = textPainter.width;
    final textHeight = textPainter.height;

    canvas.translate(size.width / 2, size.height / 2);

    // Scale the text to always fit inside the box.
    final double textScale = min(
      1.0,
      min(
        maxWidth / textWidth,
        maxHeight / textHeight,
      ),
    );
    canvas.scale(textScale);

    canvas.translate(
      -textPainter.width / 2,
      -textPainter.height / 2,
    );

    textPainter.paint(
      canvas,
      Offset.zero,
    );

    canvas.translate(
      textPainter.width / 2,
      textPainter.height / 2,
    );
    canvas.scale(1 / textScale);

    canvas.translate(-size.width / 2, -size.height / 2);
  }

  @override
  bool shouldRepaint(covariant PlaceholderPainter oldDelegate) =>
      bgColor != oldDelegate.bgColor ||
      dashColor != oldDelegate.dashColor ||
      textSpan != oldDelegate.textSpan ||
      scaleInverse != oldDelegate.scaleInverse ||
      scale != oldDelegate.scale;
}
