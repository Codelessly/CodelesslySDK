// Moved from SDK 8.x unchanged in behaviour.
import 'package:collection/collection.dart';
import 'package:flutter/rendering.dart';

/// Paints [shadows] around a box of [borderRadius], growing (or, for a
/// negative spread, shrinking) the corner radii with each shadow's spread.
class SpreadShadowPainter extends CustomPainter {
  const SpreadShadowPainter({
    required this.shadows,
    required this.borderRadius,
  });

  final List<BoxShadow> shadows;
  final BorderRadius borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final RRect box = borderRadius.toRRect(Offset.zero & size);
    for (final BoxShadow shadow in shadows) {
      canvas.drawRRect(
        box.shift(shadow.offset).inflate(shadow.spreadRadius),
        shadow.toPaint(),
      );
    }
  }

  @override
  bool shouldRepaint(SpreadShadowPainter oldDelegate) =>
      !const ListEquality<BoxShadow>().equals(oldDelegate.shadows, shadows) ||
      oldDelegate.borderRadius != borderRadius;
}
