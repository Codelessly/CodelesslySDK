// A canvas's slots laid out as Flutter's Scaffold lays out its own.
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

/// A [RenderScaffoldSlots] child's parent data.
class ScaffoldSlotParentData extends ContainerBoxParentData<RenderBox> {}

/// The Scaffold's `kFloatingActionButtonMargin`.
const double scaffoldFabMargin = 16;

/// A canvas's slot children, named by [slots] (one name per child, in child
/// order): `body`, `appBar`, `bottomNavigationBar`, `floatingActionButton`,
/// placed as [Scaffold] places them: the app bar across the top at its own
/// height, the bottom navigation bar across the bottom, the body in between
/// (loose: up to the width and the height left), the floating action button
/// at the end, [scaffoldFabMargin] from the right edge and above the bottom
/// bar (`FloatingActionButtonLocation.endFloat`). Paints and hit tests in
/// Scaffold's order: body, app bar, bottom bar, button on top.
class RenderScaffoldSlots extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, ContainerBoxParentData<RenderBox>>,
        RenderBoxContainerDefaultsMixin<RenderBox, ContainerBoxParentData<RenderBox>> {
  /// The slot of each child, in child order.
  List<String> get slots => _slots;
  List<String> _slots = const [];
  set slots(List<String> value) {
    if (listEquals(value, _slots)) return;
    _slots = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! ScaffoldSlotParentData) child.parentData = ScaffoldSlotParentData();
  }

  RenderBox? _child(String slot) {
    var i = 0;
    for (RenderBox? c = firstChild; c != null; c = childAfter(c), i++) {
      if (i < _slots.length && _slots[i] == slot) return c;
    }
    return null;
  }

  static void _place(RenderBox child, Offset at) => (child.parentData! as BoxParentData).offset = at;

  @override
  void performLayout() {
    final c = constraints;
    final body = _child('body'), bar = _child('appBar'), nav = _child('bottomNavigationBar'), fab = _child('floatingActionButton');
    var width = c.maxWidth.isFinite ? c.maxWidth : c.minWidth;
    var height = c.maxHeight.isFinite ? c.maxHeight : c.minHeight;
    final full = BoxConstraints(minWidth: width, maxWidth: width, maxHeight: height);
    var top = 0.0, bottom = 0.0;
    if (bar != null) {
      bar.layout(full, parentUsesSize: true);
      top = bar.size.height;
      _place(bar, Offset.zero);
    }
    if (nav != null) {
      nav.layout(full, parentUsesSize: true);
      bottom = nav.size.height;
    }
    if (body != null) {
      body.layout(BoxConstraints(maxWidth: width, maxHeight: math.max(0, height - top - bottom)), parentUsesSize: true);
      // Unbounded (a canvas measured by its content): as tall as its parts.
      if (!c.maxWidth.isFinite) width = math.max(width, body.size.width);
      if (!c.maxHeight.isFinite) height = math.max(height, top + body.size.height + bottom);
      _place(body, Offset(0, top));
    }
    size = c.constrain(Size(width, height));
    if (nav != null) _place(nav, Offset(0, size.height - bottom));
    if (fab != null) {
      fab.layout(BoxConstraints.loose(size), parentUsesSize: true);
      final contentBottom = size.height - bottom;
      _place(fab, Offset(size.width - fab.size.width - scaffoldFabMargin, contentBottom - fab.size.height - scaffoldFabMargin));
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    for (final slot in const ['body', 'appBar', 'bottomNavigationBar', 'floatingActionButton']) {
      final child = _child(slot);
      if (child != null) context.paintChild(child, offset + (child.parentData! as BoxParentData).offset);
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (final slot in const ['floatingActionButton', 'bottomNavigationBar', 'appBar', 'body']) {
      final child = _child(slot);
      if (child == null) continue;
      final offset = (child.parentData! as BoxParentData).offset;
      final hit = result.addWithPaintOffset(
          offset: offset, position: position, hitTest: (r, p) => child.hitTest(r, position: p));
      if (hit) return true;
    }
    return false;
  }

  @override
  double computeMinIntrinsicWidth(double height) => _child('body')?.getMinIntrinsicWidth(height) ?? 0;
  @override
  double computeMaxIntrinsicWidth(double height) => _child('body')?.getMaxIntrinsicWidth(height) ?? 0;
  @override
  double computeMinIntrinsicHeight(double width) =>
      [for (final s in const ['appBar', 'body', 'bottomNavigationBar']) _child(s)?.getMinIntrinsicHeight(width) ?? 0].fold(0.0, (a, b) => a + b);
  @override
  double computeMaxIntrinsicHeight(double width) =>
      [for (final s in const ['appBar', 'body', 'bottomNavigationBar']) _child(s)?.getMaxIntrinsicHeight(width) ?? 0].fold(0.0, (a, b) => a + b);
}
