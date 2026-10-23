import 'dart:math';
import 'dart:ui';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';

import '../../utils/extensions.dart';

/// This stroke painter is needed because Flutter's built in stroke for
/// containers only does inside strokes and doesn't do dotted borders.
///
/// TODO: We can use Path.extractPath to get proper curved segments instead
///       of using tangents and all the math and logic we're doing right now.
///       Alternatively, we can use a CustomClipper to clip out the full stroke
///       path for dotted borders.
class StrokePainter extends CustomPainter {
  /// The width of the stroke.
  final double strokeWidth;

  /// The miter limit of the stroke.
  final double strokeMiterLimit;

  /// The alignment of the stroke. Whether it is inside, outside, or centered.
  final StrokeAlignC strokeAlign;

  /// The cap shape of the stroke.
  final StrokeCapEnum strokeCap;

  /// The dash pattern of the stroke. Empty if solid.
  /// The most dashes painted along one path, so a pattern with tiny
  /// entries can't stall a frame.
  static const int maxDashes = 20000;

  final List<double> dashPattern;

  /// Paints the stroke with this gradient, spread over the node's box,
  /// instead of [color].
  final Gradient? gradient;

  /// The side of the stroke. Whether it is all, top, bottom, left, or right.
  final StrokeSide strokeSide;

  /// The shape of the box. Whether it is a rectangle or a circle.
  final BoxShape boxShape;

  /// The color of the stroke.
  final Color color;

  /// The border radius of the box.
  final BorderRadius borderRadius;

  /// A convenience getter for the inside alignment of the stroke. Helps
  /// simplify some calculations.
  double get isInside => strokeAlign == StrokeAlignC.inside ? -1 : 1;

  /// A convenience getter for the inside alignment of the stroke. Helps
  /// simplify some calculations.
  double get isOutside => strokeAlign == StrokeAlignC.outside ? -1 : 1;

  /// A convenience getter for the inside alignment of the stroke. Helps
  /// simplify some calculations.
  double get isCenter => strokeAlign == StrokeAlignC.center ? -1 : 1;

  /// The constructor for the stroke painter.
  StrokePainter({
    this.strokeWidth = 1,
    this.color = Colors.black,
    this.strokeMiterLimit = 4,
    this.dashPattern = const [],
    this.gradient,
    this.boxShape = BoxShape.rectangle,
    this.strokeSide = StrokeSide.all,
    this.strokeAlign = StrokeAlignC.inside,
    this.strokeCap = StrokeCapEnum.square,
    this.borderRadius = BorderRadius.zero,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Whether the shape that we're outlining is so thin that it is effectively
    // a line rather than a quadrilateral.
    final bool isLine =
        size.shortestSide <= strokeWidth * 2 && boxShape == BoxShape.rectangle;
    final bool isHorizLine = isLine && size.width <= strokeWidth * 2;
    final bool isVertLine = isLine && size.height <= strokeWidth * 2;

    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = strokeCap.flutterStrokeCap
      ..strokeMiterLimit = strokeMiterLimit
      ..shader = gradient?.createShader(Offset.zero & size);

    // If the stroke is dotted, we take a completely different rendering
    // route.
    if (dashPattern.isNotEmpty && strokeSide != StrokeSide.all) {
      _paintDashedSide(canvas, size, paint);
    } else if (dashPattern.isNotEmpty) {
      final Path path = Path();

      // Let's first create the appropriate path. If it's a circle,
      // It doesn't matter if the it's an outside/inside/center stroke yet.
      // We will be doing manual calculations to figure that out below.
      // For now, we just want the border path.
      if (isLine) {
        path
          ..moveTo(
            isHorizLine ? strokeWidth / 2 : 0,
            isVertLine ? strokeWidth / 2 : 0,
          )
          ..lineTo(
            isHorizLine ? strokeWidth / 2 : size.width,
            isVertLine ? strokeWidth / 2 : size.height,
          );
        paint.style = PaintingStyle.stroke;
      } else {
        if (boxShape == BoxShape.circle) {
          final double circleDiameter = min(size.width, size.height);
          final Rect basicRect = Rect.fromCenter(
            center: Offset(size.width / 2, size.height / 2),
            width: circleDiameter,
            height: circleDiameter,
          );
          path.addOval(basicRect);
        } else {
          final Rect basicRect = Rect.fromLTWH(0, 0, size.width, size.height);
          final RRect roundedBox = borderRadius.toRRect(basicRect);
          path.addRRect(roundedBox);
        }
      }

      // We loop over each "segment" of the path. Not up to us to know what
      // those segments are, we just work with them. Flutter likes being
      // mysterious.
      // A pattern that doesn't advance (no positive entry) would loop
      // forever; the cap keeps a tiny pattern on a long path from stalling a
      // frame.
      final double period = dashPattern.fold(0.0, (a, b) => a + max(0.0, b));
      for (final PathMetric metric in path.computeMetrics()) {
        if (period <= 0) break;
        double totalDistance = 0;
        bool draw = true;
        int dashes = 0;
        // Each path starts the pattern from its first entry.
        final LoopingList<double> dashArray = LoopingList(dashPattern);

        // We need to draw a dashed line, so we iterate with a while loop
        // our desired dash distance.
        while (totalDistance < metric.length && dashes++ < maxDashes) {
          final double dashDistance = max(0.0, dashArray.nextValue());

          if (draw) {
            // Now that we're about to draw a singular dash, we need to do it
            // manually. We do this with tangent calculations. Luckily for us,
            // Flutter has a convenient method for that!
            final Tangent? tangent = metric.getTangentForOffset(totalDistance);

            if (tangent != null) {
              // The tangent is always the PARALLEL vector for a given
              // line. So imagine a ball on a table. The table's line is a
              // tangent line on the ball's specific intersection point with
              // the line.
              //
              // We don't want that though, we want an actual perpendicular line
              // like a pin on a circle. To do that, we just calculate the
              // perpendicular vector of that. It's easy in 2D, it's just
              // (-y, x) or (y, -x)
              //
              // And here, since this is a pin coming out of a circle, we want
              // the pin to actually be either outside the circle or inside
              // the circle; inside stroke or outside stroke. This is where
              // isInside, isCenter, and isOutside come in. They are changing
              // the vector's direction between (-y, x) or (y, -x), flipping
              // the direction for our convenience.
              final Offset parallelTangentVector = tangent.vector;
              final Offset normal =
                  Offset(
                    parallelTangentVector.dy * isInside * isCenter,
                    parallelTangentVector.dx * isOutside,
                  ) *
                  // Multiply by the stroke thickness to figure out the distance
                  // needed from the start position to the stroke.
                  strokeWidth *
                  // If it's a center stroke, we need to divide the normal by 2.
                  // It will be rendered twice, once inside, once outside,
                  // achieving the center stroke effect.
                  (strokeAlign == StrokeAlignC.center ? 0.5 : 1);

              canvas.drawLine(
                tangent.position,
                tangent.position + normal,

                // The width of the "needle" on the "balloon"
                paint..strokeWidth = dashDistance,
              );

              // If it's a center stroke though, we draw another line in the
              // opposite direction alongside the earlier line.
              if (strokeAlign == StrokeAlignC.center) {
                canvas.drawLine(
                  tangent.position,

                  // Rendering the needle as if it were on the inside of the
                  // balloon.
                  tangent.position + normal * -1,

                  // The width of the "needle" on the "balloon"
                  paint..strokeWidth = dashDistance,
                );
              }
            }
          }
          totalDistance += dashDistance;
          draw = !draw;
        }
      }
    } else {
      paintStrokeBand(
        canvas,
        Offset.zero & size,
        paint: paint..style = PaintingStyle.fill,
        width: strokeWidth,
        side: strokeSide,
        align: strokeAlign,
        borderRadius: boxShape == BoxShape.circle ? null : borderRadius,
        shape: boxShape,
      );
    }
  }

  /// Paints a dashed stroke along the one side [strokeSide] names. The dashes
  /// run along that edge and sit inside, across or outside it as
  /// [strokeAlign] says.
  void _paintDashedSide(Canvas canvas, Size size, Paint paint) {
    final double offset = switch (strokeAlign) {
      StrokeAlignC.inside => strokeWidth / 2,
      StrokeAlignC.center => 0,
      StrokeAlignC.outside => -strokeWidth / 2,
    };
    final (Offset start, Offset end) = switch (strokeSide) {
      StrokeSide.top => (Offset(0, offset), Offset(size.width, offset)),
      StrokeSide.bottom => (
        Offset(0, size.height - offset),
        Offset(size.width, size.height - offset),
      ),
      StrokeSide.left => (Offset(offset, 0), Offset(offset, size.height)),
      StrokeSide.right => (
        Offset(size.width - offset, 0),
        Offset(size.width - offset, size.height),
      ),
      StrokeSide.all => (Offset.zero, Offset.zero),
    };
    final double length = (end - start).distance;
    if (length <= 0 || dashPattern.every((dash) => dash <= 0)) return;
    final LoopingList<double> dashes = LoopingList(dashPattern);
    final Offset direction = (end - start) / length;
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;
    double distance = 0;
    bool draw = true;
    int count = 0;
    while (distance < length && count++ < maxDashes) {
      final double dash = max(0.0, dashes.nextValue());
      if (draw && dash > 0) {
        canvas.drawLine(
          start + direction * distance,
          start + direction * min(distance + dash, length),
          paint,
        );
      }
      distance += dash;
      draw = !draw;
    }
  }

  @override
  bool shouldRepaint(covariant StrokePainter oldDelegate) =>
      oldDelegate.borderRadius != borderRadius ||
      oldDelegate.boxShape != boxShape ||
      oldDelegate.color != color ||
      oldDelegate.dashPattern != dashPattern ||
      oldDelegate.gradient != gradient ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.strokeAlign != strokeAlign ||
      oldDelegate.strokeSide != strokeSide ||
      oldDelegate.strokeCap != strokeCap ||
      oldDelegate.strokeMiterLimit != strokeMiterLimit;
}

/// A helper class that loops or repeats the values of a given list.
class LoopingList<T> {
  /// The list of values to loop through.
  final List<T> values;

  /// The current index of the list.
  int _index = 0;

  /// Creates a new [LoopingList] with the given [values].
  LoopingList(this.values);

  /// Returns the next value in the list, looping back to the first value if
  /// the end of the list is reached.
  T nextValue() {
    if (_index >= values.length) {
      _index = 0;
    }
    return values[_index++];
  }
}

/// How far a stroke of [width] reaches into the box (`inset`) and out of it
/// (`outset`) on each side. Only the sides [side] names get a stroke;
/// [align] splits its width between the inside and the outside of the edge,
/// as Figma and the editor do.
({EdgeInsets inset, EdgeInsets outset}) strokeBandInsets({
  required StrokeSide side,
  required double width,
  required StrokeAlignC align,
}) {
  final double inward = switch (align) {
    StrokeAlignC.inside => width,
    StrokeAlignC.center => width / 2,
    StrokeAlignC.outside => 0,
  };
  final double outward = width - inward;
  EdgeInsets only(double value) => switch (side) {
    StrokeSide.all => EdgeInsets.all(value),
    StrokeSide.left => EdgeInsets.only(left: value),
    StrokeSide.right => EdgeInsets.only(right: value),
    StrokeSide.top => EdgeInsets.only(top: value),
    StrokeSide.bottom => EdgeInsets.only(bottom: value),
  };
  return (inset: only(inward), outset: only(outward));
}

/// Paints the band a solid stroke covers around [rect]: the area between the
/// box's shape grown by the stroke's outset and shrunk by its inset (see
/// [strokeBandInsets]).
///
/// The corners follow [borderRadius]: the outer edge of a rounded corner
/// grows with the outset and the inner edge shrinks with the inset (never
/// below zero), so a stroke on one side tapers into the corners next to it.
/// A sharp corner stays sharp on both edges.
void paintStrokeBand(
  Canvas canvas,
  Rect rect, {
  required Paint paint,
  required double width,
  required StrokeSide side,
  required StrokeAlignC align,
  BorderRadius? borderRadius,
  BoxShape shape = BoxShape.rectangle,
}) {
  if (width <= 0) return;
  final RRect base = switch (shape) {
    BoxShape.circle => RRect.fromRectAndRadius(
      Rect.fromCircle(center: rect.center, radius: rect.shortestSide / 2),
      Radius.circular(rect.shortestSide / 2),
    ),
    BoxShape.rectangle => (borderRadius ?? BorderRadius.zero).toRRect(rect),
  };
  final (:inset, :outset) = strokeBandInsets(
    side: side,
    width: width,
    align: align,
  );

  Radius grow(Radius radius, double dx, double dy) =>
      radius.x <= 0 || radius.y <= 0
      ? Radius.zero
      : Radius.elliptical(max(0, radius.x + dx), max(0, radius.y + dy));

  final RRect outer = RRect.fromLTRBAndCorners(
    base.left - outset.left,
    base.top - outset.top,
    base.right + outset.right,
    base.bottom + outset.bottom,
    topLeft: grow(base.tlRadius, outset.left, outset.top),
    topRight: grow(base.trRadius, outset.right, outset.top),
    bottomRight: grow(base.brRadius, outset.right, outset.bottom),
    bottomLeft: grow(base.blRadius, outset.left, outset.bottom),
  );
  final double innerLeft = base.left + inset.left;
  final double innerTop = base.top + inset.top;
  final double innerRight = base.right - inset.right;
  final double innerBottom = base.bottom - inset.bottom;
  if (innerRight <= innerLeft || innerBottom <= innerTop) {
    // The stroke covers the whole box.
    canvas.drawRRect(outer, paint);
    return;
  }
  final RRect inner = RRect.fromLTRBAndCorners(
    innerLeft,
    innerTop,
    innerRight,
    innerBottom,
    topLeft: grow(base.tlRadius, -inset.left, -inset.top),
    topRight: grow(base.trRadius, -inset.right, -inset.top),
    bottomRight: grow(base.brRadius, -inset.right, -inset.bottom),
    bottomLeft: grow(base.blRadius, -inset.left, -inset.bottom),
  );
  canvas.drawDRRect(outer, inner, paint);
}
