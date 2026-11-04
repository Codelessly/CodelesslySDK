// Moved from SDK 8.x unchanged in behaviour.
import 'package:flutter/rendering.dart';

/// A [Flex] that hugs its cross axis and stretches its children across it:
/// as thick as its thickest child, every stretching child that thick.
///
/// Flutter stretches only to a bounded cross axis. This lays the flex out
/// once with its children unstretched to find its natural thickness, then
/// again with that thickness fixed and the stretch back on, instead of an
/// [IntrinsicHeight] / [IntrinsicWidth]: no intrinsic pass (which a viewport
/// or LayoutBuilder can't answer, and which can measure text differently
/// from how it lays out), and the same result.
class RenderHugCross extends RenderProxyBox {
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
    final double natural = row ? box.size.height : box.size.width;
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

