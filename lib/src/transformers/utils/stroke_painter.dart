import 'dart:math';
import 'dart:ui';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';

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
  final List<double> dashPattern;

  /// The side of the stroke. Whether it is all, top, bottom, left, or right.
  final StrokeSide strokeSide;

  /// The shape of the box. Whether it is a rectangle or a circle.
  final BoxShape boxShape;

  /// The color of the stroke.
  final Color color;

  /// The border radius of the box.
  final BorderRadius borderRadius;

  /// The border of the box. This is constructed from the other properties.
  final Border border;

  /// A helper list to iterate the dashes cleanly for dashed or dotted borders.
  /// This is constructed from the dash pattern.
  final LoopingList<double> dashArray;

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
    this.boxShape = BoxShape.rectangle,
    this.strokeSide = StrokeSide.all,
    this.strokeAlign = StrokeAlignC.inside,
    this.strokeCap = StrokeCapEnum.square,
    this.borderRadius = BorderRadius.zero,
  })  : dashArray = LoopingList(dashPattern),
        border = Border(
          left: strokeSide == StrokeSide.left
              ? BorderSide(color: color, width: strokeWidth)
              : BorderSide.none,
          right: strokeSide == StrokeSide.right
              ? BorderSide(color: color, width: strokeWidth)
              : BorderSide.none,
          bottom: strokeSide == StrokeSide.bottom
              ? BorderSide(color: color, width: strokeWidth)
              : BorderSide.none,
          top: strokeSide == StrokeSide.top
              ? BorderSide(color: color, width: strokeWidth)
              : BorderSide.none,
        );

  @override
  void paint(Canvas canvas, Size size) {
    final bool isLine =
        size.shortestSide <= strokeWidth * 2 && boxShape == BoxShape.rectangle;
    final bool isHorizLine = isLine && size.width <= strokeWidth * 2;
    final bool isVertLine = isLine && size.height <= strokeWidth * 2;

    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.values[strokeCap.index]
      ..strokeMiterLimit = strokeMiterLimit;

    // If the stroke is dotted, we take a completely different rendering
    // route.
    if (dashPattern.isNotEmpty) {
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
              height: circleDiameter);
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
      for (final PathMetric metric in path.computeMetrics()) {
        double totalDistance = 0;
        bool draw = true;

        // We need to draw a dashed line, so we iterate with a while loop
        // our desired dash distance.
        while (totalDistance < metric.length) {
          final double dashDistance = dashArray.nextValue();

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
              final Offset normal = Offset(
                    parallelTangentVector.dy * isInside * isCenter,
                    parallelTangentVector.dx * isOutside,
                  ) *
                  strokeWidth *
                  (strokeAlign == StrokeAlignC.center ? 0.5 : 1);

              canvas.drawLine(
                tangent.position,
                tangent.position + normal,
                paint..strokeWidth = dashDistance,
              );

              // If it's a center stroke though, we draw another line in the
              // opposite direction alongside the earlier line.
              if (strokeAlign == StrokeAlignC.center) {
                canvas.drawLine(
                  tangent.position,
                  tangent.position + normal * -1,
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
      // These variables create a new rectangle that is the "real" "visually
      // accurate" rectangle. IE: a rectangle containing the stroke inside its
      // borders.
      Offset topLeft = Offset.zero;
      Size realSize = size;
      switch (strokeAlign) {
        case StrokeAlignC.center:
          topLeft = Offset(-strokeWidth / 2, -strokeWidth / 2);
          realSize = Size(size.width + strokeWidth, size.height + strokeWidth);
        case StrokeAlignC.outside:
          topLeft = Offset(-strokeWidth, -strokeWidth);
          realSize =
              Size(size.width + strokeWidth * 2, size.height + strokeWidth * 2);
        case StrokeAlignC.inside:
          break;
      }

      // Outside strokes get tricky (yes they really do, trust me).
      // We have to handle them in a completely different way.
      if (strokeAlign == StrokeAlignC.outside) {
        // We create 2 paths. One is the normal border, the other is the
        // outer edge of the stroke. We will fill in the space between them
        // with a color to get our desired result.
        final Path innerPath = Path();
        final Path outerPath = Path();

        if (boxShape == BoxShape.circle) {
          final double circleDiameter = min(size.width, size.height);
          final Rect basicRect = Rect.fromCenter(
              center: Offset(size.width / 2, size.height / 2),
              width: circleDiameter,
              height: circleDiameter);
          innerPath.addOval(basicRect);
          outerPath.addOval(basicRect.inflate(strokeWidth));
        } else {
          final Rect basicRect = Rect.fromLTWH(0, 0, size.width, size.height);

          final RRect roundedBox = borderRadius.toRRect(basicRect);
          innerPath.addRRect(roundedBox);

          // The outer path is a bit tricky. You can't just inflate the rect
          // because if it has no borders, it will add a border anyways, which
          // really isn't nice. So to get around that, we interpolate a magic
          // number to EASE the (manual) inflation instead.
          //
          // In the end of the
          // day, you always need to make the borders larger for the outer edge
          // of the outside strike for it to look "normal".
          //
          // We just don't want
          // that inflation at no borders and we don't want it to instantly
          // appear after a border of 1 pixel exists (it'll effectively double).
          // So we just interpolate the first 10 pixels to ease the inflated
          // border in as the border radius increases on each corner.
          //
          // We get a really nice and seamless outside border transition this
          // way.
          outerPath.addRRect((borderRadius.add(
            BorderRadius.only(
              topRight: Radius.circular(
                  strokeWidth * (min(borderRadius.topRight.x, 10) / 10)),
              topLeft: Radius.circular(
                  strokeWidth * (min(borderRadius.topLeft.x, 10) / 10)),
              bottomLeft: Radius.circular(
                  strokeWidth * (min(borderRadius.bottomLeft.x, 10) / 10)),
              bottomRight: Radius.circular(
                  strokeWidth * (min(borderRadius.bottomRight.x, 10) / 10)),
            ),
          ) as BorderRadius)
              .toRRect(
            Rect.fromLTWH(
              topLeft.dx,
              topLeft.dy,
              realSize.width,
              realSize.height,
            ),
          ));
        }

        // This is where the magic happens. We want to fill the area
        // between two paths. To do that, there's this magic feature in
        // Flutter paths called FillType.evenOdd. It does the work for us.
        // It's effectively a mask system.
        final Path dest = Path()..fillType = PathFillType.evenOdd;
        dest.addPath(innerPath, Offset.zero);
        dest.addPath(outerPath, Offset.zero);

        canvas.drawPath(
          dest..close(),
          paint..style = PaintingStyle.fill,
        );
      } else {
        final Rect rect = Rect.fromLTWH(
            topLeft.dx, topLeft.dy, realSize.width, realSize.height);

        // For any other border, we can just use Flutter's built in painter.
        // No special handling required here.
        border.paint(
          canvas,
          rect,
          borderRadius: boxShape == BoxShape.circle ? null : borderRadius,
          shape: boxShape,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant StrokePainter oldDelegate) =>
      oldDelegate.borderRadius != borderRadius ||
      oldDelegate.border != border ||
      oldDelegate.boxShape != boxShape ||
      oldDelegate.color != color ||
      oldDelegate.dashPattern != dashPattern ||
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
