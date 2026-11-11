// A node's margin, negative sides included.
import 'dart:math' as math;

import 'package:flutter/rendering.dart';

/// Space around a child, any side of it negative: a negative side takes the
/// child that far past this box (a scrim reaching over its parent's
/// padding, a card overlapping its neighbour). This box keeps the size its
/// parent gives it; the child is laid out larger by the overhang and placed
/// out over it. With no negative side it is Flutter's padding.
class RenderMargin extends RenderShiftedBox {
  RenderMargin({required EdgeInsets margin, RenderBox? child}) : _margin = margin, super(child); // ignore: prefer_initializing_formals

  EdgeInsets get margin => _margin;
  EdgeInsets _margin;
  set margin(EdgeInsets value) {
    if (value == _margin) return;
    _margin = value;
    markNeedsLayout();
  }

  static double _less(double v, double by) => v.isFinite ? math.max(0, v - by) : v;

  BoxConstraints _inner(BoxConstraints c) {
    final h = _margin.horizontal, v = _margin.vertical;
    return BoxConstraints(
      minWidth: _less(c.minWidth, h),
      maxWidth: _less(c.maxWidth, h),
      minHeight: _less(c.minHeight, v),
      maxHeight: _less(c.maxHeight, v),
    );
  }

  Size _outer(BoxConstraints c, Size inner) =>
      c.constrain(Size(math.max(0, inner.width + _margin.horizontal), math.max(0, inner.height + _margin.vertical)));

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = _outer(constraints, Size.zero);
      return;
    }
    child.layout(_inner(constraints), parentUsesSize: true);
    (child.parentData! as BoxParentData).offset = Offset(_margin.left, _margin.top);
    size = _outer(constraints, child.size);
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      _outer(constraints, child?.getDryLayout(_inner(constraints)) ?? Size.zero);

  @override
  double computeMinIntrinsicWidth(double height) =>
      math.max(0, (child?.getMinIntrinsicWidth(_less(height, _margin.vertical)) ?? 0) + _margin.horizontal);

  @override
  double computeMaxIntrinsicWidth(double height) =>
      math.max(0, (child?.getMaxIntrinsicWidth(_less(height, _margin.vertical)) ?? 0) + _margin.horizontal);

  @override
  double computeMinIntrinsicHeight(double width) =>
      math.max(0, (child?.getMinIntrinsicHeight(_less(width, _margin.horizontal)) ?? 0) + _margin.vertical);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      math.max(0, (child?.getMaxIntrinsicHeight(_less(width, _margin.horizontal)) ?? 0) + _margin.vertical);
}
