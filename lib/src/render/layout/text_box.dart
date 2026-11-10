import 'dart:math' as math;

import 'package:flutter/rendering.dart';

class RenderTextIntrinsicSlack extends RenderProxyBox {
  /// [width] rounded up to a whole pixel.
  static double slackWidth(double width) =>
      width <= 0 || !width.isFinite ? width : width.ceilToDouble();

  @override
  double computeMaxIntrinsicWidth(double height) =>
      slackWidth(super.computeMaxIntrinsicWidth(height));
}

/// The render object of [TextMinHeight].
class RenderTextMinHeight extends RenderProxyBox {
  RenderTextMinHeight({required double minHeight}) {
    _minHeight = minHeight;
  }

  double get minHeight => _minHeight;
  late double _minHeight;
  set minHeight(double value) {
    if (value == _minHeight) return;
    _minHeight = value;
    markNeedsLayout();
  }

  BoxConstraints _childConstraints(BoxConstraints constraints) =>
      constraints.copyWith(
        minHeight: constraints.constrainHeight(
          math.max(constraints.minHeight, minHeight),
        ),
      );

  @override
  void performLayout() {
    final RenderBox? child = this.child;
    if (child == null) {
      size = _childConstraints(constraints).smallest;
      return;
    }
    child.layout(_childConstraints(constraints), parentUsesSize: true);
    size = child.size;
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      child?.getDryLayout(_childConstraints(constraints)) ??
      _childConstraints(constraints).smallest;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      math.max(minHeight, super.computeMaxIntrinsicHeight(width));
}
