import 'dart:ui';

import 'package:codelessly_api/api.dart';

import 'extensions.dart';

/// Converts a Flutter [Color] to a [ColorRGB] object.
ColorRGB colorToRGB(Color color) {
  return ColorRGB(
    r: color.red / 255,
    g: color.green / 255,
    b: color.blue / 255,
    // a: 1.0,
  );
}

/// Converts a Flutter [Color] to a [ColorRGBA] object.
ColorRGBA colorToRGBA(Color color) {
  return ColorRGBA(
    r: color.red / 255,
    g: color.green / 255,
    b: color.blue / 255,
    a: color.opacity,
  );
}

/// Converts the fills of a given [node] to a single [Color] object.
Color retrieveFillColor(GeometryMixin node) {
  if (node.fills.isEmpty) {
    return Color(0x00000000);
  }

  final fill = node.fills.first;
  if (fill.visible == false) {
    return Color(0x00000000);
  }
  if (fill.color != null) {
    return fill.toFlutterColor()!;
  }

  return Color(0xff000000);
}

/// Converts the strokes of a given [node] to a single [Color] object.
Color retrieveStrokeColor(GeometryMixin node,
    [int index = 0, bool all = false]) {
  if (node.strokes.isEmpty) {
    // Some methods expect a non-null color.
    return Color(0x00000000);
  }

  // If we want to disregard the single color index and retrieve all of the colors,
  // we set [all] to true and we blend all the colors.
  if (all) {
    Color? stroke;
    // We get all the paints that have a color and reverse the list because the
    // strokes most recently added are the ones that are on top.
    for (PaintModel paint
        in node.strokes.where((element) => element.color != null).toList()) {
      // Beginning stroke.
      if (stroke == null) {
        stroke = paint.toFlutterColor()!;
      } else {
        // Blend
        stroke = Color.alphaBlend(paint.toFlutterColor()!, stroke);
      }
    }

    if (stroke == null) {
      final List<PaintModel> gradients = node.strokes
          .where((element) =>
              element.gradientStops != null &&
              element.gradientStops!.isNotEmpty)
          .toList();

      if (gradients.isNotEmpty) {
        return gradients.last.gradientStops![0].color.toFlutterColor();
      } else {
        // Return black when something unknown is found until we have better support
        // for Gradients. Some methods expect a non-null color, so returning null
        // may crash the UI.
        return Color(0xff000000);
      }
    }

    return stroke;
  }

  // Otherwise, we retrieve a single index color.
  final PaintModel stroke = node.strokes[index];

  if (stroke.color != null) {
    return stroke.toFlutterColor()!;
  } else if (stroke.gradientStops != null && stroke.gradientStops!.isNotEmpty) {
    return stroke.gradientStops![0].color.toFlutterColor();
  } else {
    // Return black when something unknown is found until we have better support
    // for Gradients. Some methods expect a non-null color, so returning null
    // may crash the UI.
    return Color(0xff000000);
  }
}

/// Converts a [PaintModel] to a [Color] object.
Color retrieveColorFromPaint(PaintModel paint) {
  assert(paint.type == PaintType.solid,
      'retrieveColorFromPaint() only accepts Paints that are PaintType.SOLID');
  return paint.toFlutterColor()!;
}
