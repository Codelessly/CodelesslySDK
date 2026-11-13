import 'package:flutter/rendering.dart';

/// The share (0–1) of [box] visible on screen, inside every clip around it.
/// A box larger than the view counts as wholly visible when it covers it.
double visibleShare(RenderBox box) {
  if (!box.attached || !box.hasSize || box.size.isEmpty) return 0;
  var rect = MatrixUtils.transformRect(box.getTransformTo(null), Offset.zero & box.size);
  final full = rect;
  RenderObject child = box;
  for (var p = box.parent; p != null; p = p.parent) {
    final clip = p.describeApproximatePaintClip(child);
    if (clip != null) {
      final global = MatrixUtils.transformRect(p.getTransformTo(null), clip);
      rect = rect.intersect(global);
      if (rect.isEmpty) return 0;
    }
    child = p;
  }
  final root = child;
  if (root is RenderView) {
    final screen = Offset.zero & root.size;
    rect = rect.intersect(screen);
    if (rect.width <= 0 || rect.height <= 0) return 0;
    final view = full.intersect(screen);
    if (view.width >= screen.width - 0.5 && view.height >= screen.height - 0.5) return 1;
  }
  if (rect.width <= 0 || rect.height <= 0) return 0;
  return (rect.width * rect.height) / (full.width * full.height);
}
