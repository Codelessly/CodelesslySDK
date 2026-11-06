import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Hit-tests its child wherever the child is drawn, even outside this
/// widget's own box.
///
/// A node that motion moves (a planet travelling its orbit from where it
/// rests on the Sun, a card slid aside) is laid out at rest; its transform
/// draws it elsewhere. Flutter only hit-tests a box's children inside the
/// box, so the boxes around the transform (margins, constraints, the place
/// a list gives it) refused taps where the node is drawn, and took them
/// where it isn't. This box skips that check and asks its child.
class HitBeyondBounds extends SingleChildRenderObjectWidget {
  /// Creates a [HitBeyondBounds].
  const HitBeyondBounds({super.key, super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderHitBeyondBounds();
}

class _RenderHitBeyondBounds extends RenderProxyBox {
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final RenderBox? child = this.child;
    if (child == null) return false;
    if (_hitThrough(child, result, position)) {
      result.add(BoxHitTestEntry(this, position));
      return true;
    }
    return false;
  }

  /// Hit-tests [box] without its own size check while it only lays out
  /// (padding, constraints, alignment, sizing boxes), down to the box that
  /// draws the node somewhere else (a transform), which hit-tests its
  /// child where it draws it. Boxes that decide about pointers themselves
  /// (ignore or absorb pointers, listeners, offstage) are asked as usual.
  static bool _hitThrough(RenderBox box, BoxHitTestResult result, Offset position) {
    final bool layoutOnly = box is RenderShiftedBox ||
        (box is RenderProxyBox &&
            box is! RenderTransform &&
            box is! RenderFractionalTranslation &&
            box is! RenderIgnorePointer &&
            box is! RenderAbsorbPointer &&
            box is! RenderOffstage &&
            box is! RenderProxyBoxWithHitTestBehavior &&
            box is! RenderMouseRegion);
    if (!layoutOnly) return box.hitTest(result, position: position);
    RenderBox? child;
    Offset offset = Offset.zero;
    if (box is RenderShiftedBox) {
      child = box.child;
      if (child != null) offset = (child.parentData! as BoxParentData).offset;
    } else if (box is RenderProxyBox) {
      child = box.child;
    }
    if (child == null) return box.hitTest(result, position: position);
    final RenderBox inner = child;
    final bool hit = result.addWithPaintOffset(
      offset: offset,
      position: position,
      hitTest: (BoxHitTestResult r, Offset p) => _hitThrough(inner, r, p),
    );
    if (hit) result.add(BoxHitTestEntry(box, position));
    return hit;
  }
}

/// Whether [node]'s motion can draw it away from where it is laid out: a
/// path, a translation or a shift (saved or bound).
bool movesByMotion(BaseNode node) {
  final MotionModel? m = node.motion;
  if (m != null &&
      (m.hasPath || m.translateX != 0 || m.translateY != 0 || m.shiftX != 0 || m.shiftY != 0)) {
    return true;
  }
  return node.variables.keys.any(
    (key) =>
        key == 'motion.path' ||
        key == 'motion.pathProgress' ||
        key == 'motion.translateX' ||
        key == 'motion.translateY' ||
        key == 'motion.shiftX' ||
        key == 'motion.shiftY',
  );
}
