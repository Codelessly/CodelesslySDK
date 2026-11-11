import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import 'fit_box.dart';

/// A [Flex] that hugs its cross axis and stretches its children across it:
/// as thick as its thickest child, every stretching child that thick.
///
/// Flutter stretches only to a bounded cross axis. This lays the flex out
/// once with its children unstretched to find its natural thickness, then
/// again with that thickness fixed and the stretch back on, instead of an
/// [IntrinsicHeight] / [IntrinsicWidth]: no intrinsic pass (which a viewport
/// or LayoutBuilder can't answer, and which can measure text differently
/// from how it lays out), and the same result.
///
/// Laid out stretched, the children have tight constraints across, so they
/// are relayout boundaries: a change inside one relays out only that child,
/// at the thickness measured before. Whatever changes the content under one
/// calls [relayoutAbove] (the node tree does, for every node it re-applies),
/// so the thickness is measured again and incremental layout gives what a
/// fresh layout gives.
///
/// Children that fill the cross axis take their design thickness when
/// measured unstretched. A [RenderCodelesslyFlex] with
/// [RenderCodelesslyFlex.fillsAcross] also reports their content's
/// thickness ([RenderCodelesslyFlex.fillContentCross]), which counts too, as
/// under [IntrinsicHeight]: a flex of only such children isn't as thin as
/// their design sizes (often 0) say.
class RenderHugCross extends RenderProxyBox {
  /// Marks every [RenderHugCross] above [object] as needing layout. Call it
  /// outside the layout phase.
  static void relayoutAbove(RenderObject object) {
    for (RenderObject? p = object.parent; p != null; p = p.parent) {
      if (p is RenderHugCross) p.markNeedsLayout();
    }
  }

  @override
  void performLayout() {
    final RenderBox? box = child;
    if (box is! RenderFlex) {
      super.performLayout();
      return;
    }
    final CrossAxisAlignment wanted = box.crossAxisAlignment;
    final bool row = box.direction == Axis.horizontal;
    // Unbounded across, as hugging means: children that fill that axis take
    // their own (design) size instead of all the room the parent offers.
    final BoxConstraints loose = row
        ? constraints.copyWith(minHeight: 0, maxHeight: double.infinity)
        : constraints.copyWith(minWidth: 0, maxWidth: double.infinity);
    // Switching the flex's alignment mid-layout is a mutation of a
    // descendant, allowed inside a layout callback (as LayoutBuilder does).
    invokeLayoutCallback<BoxConstraints>(
      // Any non-stretching alignment measures the same; center needs no
      // text direction for a column's cross axis.
      (_) => box.crossAxisAlignment = CrossAxisAlignment.center,
    );
    box.layout(loose, parentUsesSize: true);
    double natural = row ? box.size.height : box.size.width;
    if (box is RenderCodelesslyFlex) natural = math.max(natural, box.fillContentCross);
    final double cross = row
        ? constraints.constrainHeight(natural)
        : constraints.constrainWidth(natural);
    invokeLayoutCallback<BoxConstraints>(
      (_) => box.crossAxisAlignment = wanted,
    );
    box.layout(
      row
          ? constraints.copyWith(minHeight: cross, maxHeight: cross)
          : constraints.copyWith(minWidth: cross, maxWidth: cross),
      parentUsesSize: true,
    );
    size = box.size;
  }
}

