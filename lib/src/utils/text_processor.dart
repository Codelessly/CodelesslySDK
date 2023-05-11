import 'dart:ui';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';

import '../../codelessly_sdk.dart';

/// A convenience extension to quickly recalculate the [TextNode] sizes.
/// This is useful when the [TextNode] is updated and the sizes need to be
/// recalculated.
extension TextNodePrecalculator on TextNode {
  /// Recalculates the [TextNode] sizes.
  /// See: [processTextNode]
  void processTextSizes() => processTextNode(this);

  /// Recalculates the [TextNode] [minTextWidth] value.
  /// See: [_calculateMinWidth]
  void recalculateMinWidth() => _calculateMinWidth(this);
}

/// Calculates the [textNode] sizes and stores them in the [textNode] instance.
///
/// This function will create a new [TextSizeCalculator] instance and use it to
/// calculate a range of widths that map to a computed text height. So for
/// example, it loops through a big range of pixels and calculates the painted
/// text height for every pixel width. If in a section of that range is from
/// 400 -> 500 pixels of width and it so happens that that entire range
/// paints the text at a height of, say, 100 pixels, then the [textNode]
/// [precalculatedSizes] map will have a key of 100 and a value of
/// `WidthRange(from: 400, to: 500)`.
///
/// This results in the map inside the [textNode] to have groups of widths
/// that map to unique heights.
void processTextNode(TextNode textNode) {
  final TextSizeCalculator calculator = TextSizeCalculator(node: textNode);

  textNode.precalculatedSizes.clear();

  int maxWidth = calculator.getMaxWidth().round();
  textNode.maxTextWidth = maxWidth.toDouble();
  textNode.minTextWidth = calculator.getMinWidth();
  textNode.minTextHeight = calculator.getHeightForWidth(maxWidth.toDouble());

  int widthFrom = 0;
  int width = 0;
  int currentHeight = calculator.getHeightForWidth(width.toDouble()).round();
  int lastHeight = currentHeight;
  textNode.maxTextHeight = currentHeight.toDouble();

  textNode.precalculatedSizes[currentHeight] =
      WidthRange(from: widthFrom, to: width);

  while (width < maxWidth) {
    width++;

    currentHeight = calculator.getHeightForWidth(width.toDouble()).round();

    if (currentHeight != lastHeight) {
      textNode.precalculatedSizes[lastHeight] =
          WidthRange(from: widthFrom, to: width);
      lastHeight = currentHeight;
      widthFrom = width + 1;
    }
  }

  textNode.precalculatedSizes[currentHeight] =
      WidthRange(from: widthFrom, to: maxWidth);
}

/// Creates a new [TextSizeCalculate] instance using the given [textNode] to
/// calculate a new [minTextWidth] value.
void _calculateMinWidth(TextNode textNode) {
  final TextSizeCalculator calculator = TextSizeCalculator(node: textNode);
  textNode.minTextWidth = calculator.getMinWidth();
}

/// A default implementation of the [ITextSizeCalculator] interface.
class TextSizeCalculator implements ITextSizeCalculator {
  /// The [TextPainter] instance used to calculate the text sizes.
  final TextPainter painter;

  /// The [TextNode] instance used to calculate the text sizes.
  final TextNode node;

  /// Creates a new [TextSizeCalculator] instance.
  TextSizeCalculator({required this.node})
      : painter = TextPainter(
          text: TextSpan(
            children: PassiveTextTransformer.getTextSpan(
              node,
              CodelesslyContext.empty(),
            ),
          ),
          textScaleFactor: PlatformDispatcher.instance.textScaleFactor,
          textDirection: TextDirection.ltr,
          textWidthBasis: TextWidthBasis.longestLine,
          maxLines: node.maxLines,
        ) {
    if (node.overflow == TextOverflowC.ellipsis) {
      painter.ellipsis = '\u2026';
    }
  }

  @override
  double getHeightForWidth(double width) {
    final double unSpacedWidth = width -
        node.outerBoxLocal.horizontalEdgeSpace -
        node.innerBoxLocal.horizontalEdgeSpace;
    painter.layout(minWidth: unSpacedWidth, maxWidth: unSpacedWidth);
    return node.innerBoxLocal.verticalEdgeSpace +
        node.outerBoxLocal.verticalEdgeSpace +
        painter.height;
  }

  // Never used here.
  @override
  double getWidthForHeight(double height, double fallbackWidth) {
    return fallbackWidth;
  }

  @override
  double getMinWidth() {
    // If overflow is ellipsis with default maxLines we let free shrinking.
    final isEllipsis = node.overflow == TextOverflowC.ellipsis;
    final hasNoMaxLines = node.maxLines == null;
    if (isEllipsis && hasNoMaxLines) {
      return 0;
    }

    painter.layout(minWidth: 0, maxWidth: double.infinity);
    return node.innerBoxLocal.horizontalEdgeSpace +
        node.outerBoxLocal.horizontalEdgeSpace +
        painter.minIntrinsicWidth;
  }

  @override
  double getMaxWidth() {
    painter.layout(minWidth: 0, maxWidth: double.infinity);
    return node.innerBoxLocal.horizontalEdgeSpace +
        node.outerBoxLocal.horizontalEdgeSpace +
        painter.maxIntrinsicWidth;
  }

  @override
  double getBestTextWidthAtCurrentNodeBox() {
    final double width = node.innerBoxLocal.width;
    painter.layout(minWidth: 0, maxWidth: width);
    final LineMetrics longestLine = painter.computeLineMetrics().reduce(
          (value, element) => value.width > element.width ? value : element,
        );
    return longestLine.width + 1;
  }

  @override
  double getMinHeight() {
    return node.innerBoxLocal.verticalEdgeSpace +
        node.outerBoxLocal.verticalEdgeSpace;
  }

  @override
  double computeDistanceToActualBaseline(CTextBaseline baseline) {
    painter.layout(minWidth: 0, maxWidth: double.infinity);

    final TextBaseline flutterBaseline;
    switch (baseline) {
      case CTextBaseline.alphabetic:
        flutterBaseline = TextBaseline.alphabetic;
        break;
      case CTextBaseline.ideographic:
        flutterBaseline = TextBaseline.ideographic;
        break;
    }
    return painter.computeDistanceToActualBaseline(flutterBaseline);
  }
}
