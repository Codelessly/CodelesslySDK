// A scroll view at rest, as a render object: what SingleChildScrollView's
// viewport does at scroll offset 0, without a ScrollPosition, controller,
// gesture detector or element tree. The design canvas shows content at its
// start (the end, when reversed), clipped to the viewport.
import 'package:flutter/rendering.dart';

class RenderDesignScroll extends RenderProxyBox {
  RenderDesignScroll({required this._axis, this._reverse = false, Clip clipBehavior = Clip.hardEdge})
      : _clip = clipBehavior;

  Axis _axis;
  Axis get axis => _axis;
  set axis(Axis v) {
    if (v == _axis) return;
    _axis = v;
    markNeedsLayout();
  }

  bool _reverse;
  bool get reverse => _reverse;
  set reverse(bool v) {
    if (v == _reverse) return;
    _reverse = v;
    markNeedsPaint();
  }

  Clip _clip;
  Clip get clipBehavior => _clip;
  set clipBehavior(Clip v) {
    if (v == _clip) return;
    _clip = v;
    markNeedsPaint();
  }

  /// Called with the viewport's extent along [axis] before the content lays
  /// out (the SDK's LayoutBuilder hands it to ScrollContentExtent).
  void Function(double viewportExtent)? onViewport;

  // As the SDK's viewport: its own layer (shaders anchored to layer origins,
  // like debug overflow stripes, paint the same) and cheap repaints.
  @override
  bool get isRepaintBoundary => true;

  BoxConstraints _contentConstraints(BoxConstraints c) =>
      _axis == Axis.vertical ? c.widthConstraints() : c.heightConstraints();

  @override
  void performLayout() {
    final child = this.child;
    final cb = onViewport;
    if (cb != null) {
      final extent = _axis == Axis.vertical ? constraints.maxHeight : constraints.maxWidth;
      // The content's extent depends on the viewport (LayoutBuilder-style):
      // mutating descendants is allowed inside a layout callback.
      invokeLayoutCallback<BoxConstraints>((_) => cb(extent));
    }
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(_contentConstraints(constraints), parentUsesSize: true);
    size = constraints.constrain(child.size);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final child = this.child;
    if (child == null) return constraints.smallest;
    return constraints.constrain(child.getDryLayout(_contentConstraints(constraints)));
  }

  @override
  double computeMinIntrinsicWidth(double height) => child?.getMinIntrinsicWidth(height) ?? 0;
  @override
  double computeMaxIntrinsicWidth(double height) => child?.getMaxIntrinsicWidth(height) ?? 0;
  @override
  double computeMinIntrinsicHeight(double width) => child?.getMinIntrinsicHeight(width) ?? 0;
  @override
  double computeMaxIntrinsicHeight(double width) => child?.getMaxIntrinsicHeight(width) ?? 0;

  /// Offset 0: the content's start at the viewport's start; reversed, its
  /// end at the viewport's end.
  Offset get _paintOffset {
    final child = this.child;
    if (child == null || !_reverse) return Offset.zero;
    return _axis == Axis.vertical
        ? Offset(0, size.height - child.size.height)
        : Offset(size.width - child.size.width, 0);
  }

  bool get _overflows {
    final child = this.child;
    return child != null && (child.size.width > size.width || child.size.height > size.height);
  }

  final LayerHandle<ClipRectLayer> _clipLayer = LayerHandle();

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    void paintContent(PaintingContext c, Offset o) => c.paintChild(child, o + _paintOffset);
    if (_overflows && _clip != Clip.none) {
      _clipLayer.layer = context.pushClipRect(needsCompositing, offset, Offset.zero & size, paintContent,
          clipBehavior: _clip, oldLayer: _clipLayer.layer);
    } else {
      _clipLayer.layer = null;
      paintContent(context, offset);
    }
  }

  @override
  void dispose() {
    _clipLayer.layer = null;
    super.dispose();
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final o = _paintOffset;
    transform.translateByDouble(o.dx, o.dy, 0, 1);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final child = this.child;
    if (child == null) return false;
    return result.addWithPaintOffset(
      offset: _paintOffset,
      position: position,
      hitTest: (r, p) => child.hitTest(r, position: p),
    );
  }
}
