import 'dart:math' as math;
import 'dart:ui' as ui;

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

/// Keeps a word whole. A paragraph given less width than its longest word
/// breaks that word wherever the line ends ("Breakfas / t", and in a column
/// squeezed to nothing a letter a line). Here the paragraph is laid out at
/// the width that word needs and drawn smaller so that it fits its box,
/// down to [minScale] of its size; a word that is still too long keeps its
/// line and is cut at the box's edge.
///
/// A text that takes one line and ends in an ellipsis is left to that; so is
/// a text whose words all fit.
class RenderWholeWords extends RenderProxyBox {
  /// The least a text is drawn at, as a share of its size.
  static const double minScale = 0.65;

  double _scale = 1;
  bool _clips = false;

  /// The share of its size the text is drawn at (1: as written).
  double get scale => _scale;

  /// Whether a word did not fit at [minScale] either, and is cut at the edge.
  bool get clips => _clips;

  /// The width the paragraph is laid out at for a box [maxWidth] wide, or
  /// null when its words fit as they are.
  double? _wordWidth(RenderBox child, double maxWidth) {
    if (!maxWidth.isFinite || maxWidth <= 0) return null;
    final double word = child.getMinIntrinsicWidth(double.infinity);
    if (word <= maxWidth + 0.5) return null;
    return word.ceilToDouble();
  }

  @override
  void performLayout() {
    final RenderBox? child = this.child;
    _scale = 1;
    _clips = false;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(constraints, parentUsesSize: true);
    final RenderBox? p = _paragraphOf(child);
    // One line as laid out: no word was broken.
    // (By its font size: a line is under 1.9 of it, two lines over.)
    final bool oneLine = p is RenderParagraph && (p.maxLines == 1 || child.size.height < _fontSize(p.text) * 1.9);
    final double? word = oneLine ? null : _wordWidth(child, constraints.maxWidth);
    if (word == null) {
      size = child.size;
      return;
    }
    final double max = constraints.maxWidth;
    _scale = math.max(minScale, max / word);
    _clips = max / word < minScale;
    // Laid out at the width the scale shows in full (the word's own when it
    // is cut): the other words wrap in that width.
    final double width = _clips ? word : max / _scale;
    child.layout(BoxConstraints(minWidth: math.min(constraints.minWidth / _scale, width), maxWidth: width), parentUsesSize: true);
    size = constraints.constrain(Size(math.min(max, child.size.width * _scale), child.size.height * _scale));
  }

  /// The largest font size [span] is written in (14 where it says none).
  static double _fontSize(InlineSpan span) {
    double size = 0;
    span.visitChildren((InlineSpan s) {
      size = math.max(size, s.style?.fontSize ?? 0);
      return true;
    });
    return size > 0 ? size : 14;
  }

  static RenderBox? _paragraphOf(RenderBox box) {
    RenderObject? o = box;
    while (o != null && o is! RenderParagraph) {
      o = o is RenderObjectWithChildMixin ? o.child as RenderObject? : null;
    }
    return o as RenderBox?;
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final RenderBox? child = this.child;
    if (child == null) return constraints.smallest;
    final Size plain = child.getDryLayout(constraints);
    final double? word = _wordWidth(child, constraints.maxWidth);
    if (word == null) return plain;
    final double max = constraints.maxWidth;
    final double scale = math.max(minScale, max / word);
    final double width = max / word < minScale ? word : max / scale;
    final Size laid = child.getDryLayout(BoxConstraints(maxWidth: width));
    return constraints.constrain(Size(math.min(max, laid.width * scale), laid.height * scale));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final RenderBox? child = this.child;
    if (child == null) return;
    if (_scale == 1 && !_clips) {
      context.paintChild(child, offset);
      return;
    }
    void draw(PaintingContext c, Offset o) {
      if (_scale == 1) {
        c.paintChild(child, o);
      } else {
        layer = c.pushTransform(needsCompositing, o, Matrix4.diagonal3Values(_scale, _scale, 1), (PaintingContext cc, Offset oo) => cc.paintChild(child, oo),
            oldLayer: layer is TransformLayer ? layer as TransformLayer? : null);
      }
    }

    if (_clips) {
      // Cut at the edge, fading out over its last letters as an ellipsis says.
      final Rect box = offset & size;
      final double fade = math.min(16, size.width / 2);
      context.canvas.saveLayer(box, Paint());
      context.canvas.clipRect(box);
      draw(context, offset);
      context.canvas.drawRect(
        Rect.fromLTWH(box.right - fade, box.top, fade, box.height),
        Paint()
          ..blendMode = BlendMode.dstIn
          ..shader = ui.Gradient.linear(Offset(box.right - fade, 0), Offset(box.right, 0), const [Color(0xFF000000), Color(0x00000000)]),
      );
      context.canvas.restore();
    } else {
      draw(context, offset);
    }
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    if (_scale != 1) transform.scaleByDouble(_scale, _scale, 1, 1);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    if (_scale == 1) return super.hitTestChildren(result, position: position);
    return result.addWithPaintTransform(
      transform: Matrix4.diagonal3Values(_scale, _scale, 1),
      position: position,
      hitTest: (BoxHitTestResult r, Offset p) => super.hitTestChildren(r, position: p),
    );
  }
}
