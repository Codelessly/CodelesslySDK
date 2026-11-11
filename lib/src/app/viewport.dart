// How a canvas (screen) sizes itself in the space its host gives it, by its
// scale mode: a responsive canvas lays out at the space's size, an
// autoScale one at its design size, scaled to fit the width.
import 'dart:math' as math;

import 'package:codelessly_api/codelessly_api.dart' show CanvasProps, Node, ScaleMode, SizeFit;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// How a canvas sizes itself in its host.
enum CanvasSizing {
  /// The canvas is the screen: it fills the width and height it's given.
  /// On an unbounded axis it takes its design size (an autoScale canvas its
  /// scaled height; a canvas that hugs its height, its content's).
  fill,

  /// The canvas keeps its design size within the space it's given (a
  /// dialog).
  design,

  /// The canvas fills the width and keeps its design height (a sheet).
  fillWidth,
}

/// The box a canvas takes, and the size it's laid out at inside it.
@immutable
class CanvasBox {
  const CanvasBox({required this.width, required this.height, required this.layoutWidth, required this.layoutHeight, required this.scale});

  /// The box (null height: the canvas's content height).
  final double width;
  final double? height;

  /// The size the canvas lays out at (its design size when scaled).
  final double layoutWidth;
  final double? layoutHeight;

  /// layout → box scale (1 unless autoScale).
  final double scale;

  @override
  String toString() => 'CanvasBox($width×$height, layout $layoutWidth×$layoutHeight @$scale)';
}

/// Canvas sizing by scale mode.
abstract final class CanvasViewport {
  /// The scale mode of [canvas].
  static ScaleMode scaleModeOf(Node canvas) => canvas.prop(CanvasProps.scaleMode);

  /// Whether [canvas] hugs its content vertically instead of using its
  /// design height.
  static bool sizesToContent(Node canvas) =>
      canvas.layout.height.fit == SizeFit.hug && scaleModeOf(canvas) == ScaleMode.responsive;

  /// The design size of [canvas].
  static Size designSize(Node canvas) => Size(canvas.layout.width.value, canvas.layout.height.value);

  /// The height an autoScale [canvas] takes when scaled to [width]: its
  /// design height times the scale, after its max width cap.
  static double autoScaleHeight(Node canvas, double width) {
    final design = designSize(canvas);
    if (design.width <= 0 || !width.isFinite) return design.height;
    final maxWidth = canvas.layout.constraints.maxWidth;
    final scaled = maxWidth == null ? width : math.min(width, maxWidth);
    return design.height * scaled / design.width;
  }

  /// The box [canvas] takes in [constraints] under [sizing].
  static CanvasBox resolve(Node canvas, BoxConstraints constraints, {CanvasSizing sizing = CanvasSizing.fill}) {
    final design = designSize(canvas);
    final autoScale = scaleModeOf(canvas) == ScaleMode.autoScale;
    final contentHeight = sizesToContent(canvas);
    final double width;
    double? height;
    if (sizing == CanvasSizing.fill) {
      width = constraints.hasBoundedWidth ? constraints.maxWidth : design.width;
      if (constraints.hasBoundedHeight) {
        height = constraints.maxHeight;
      } else if (autoScale) {
        height = autoScaleHeight(canvas, width);
      } else if (!contentHeight) {
        height = design.height;
      }
    } else {
      width = sizing == CanvasSizing.fillWidth && constraints.hasBoundedWidth
          ? constraints.maxWidth
          : constraints.constrainWidth(design.width);
      if (!contentHeight) {
        height = constraints.constrainHeight(autoScale ? autoScaleHeight(canvas, width) : design.height);
      }
    }
    if (!autoScale || design.width <= 0) {
      return CanvasBox(width: width, height: height, layoutWidth: width, layoutHeight: height, scale: 1);
    }
    // Scaled to fit the width (up to the canvas's max width), laid out at
    // its design width; the height it lays out at keeps the box's ratio.
    final maxWidth = canvas.layout.constraints.maxWidth;
    final shown = maxWidth == null ? width : math.min(width, maxWidth);
    final scale = shown / design.width;
    return CanvasBox(
      width: width,
      height: height,
      layoutWidth: design.width,
      layoutHeight: height == null ? null : math.max(design.height, height / scale),
      scale: scale,
    );
  }

  /// The width breakpoints are picked by: the width the widget is laid out
  /// in, so a layout embedded in a 390 wide frame inside a 1440 wide window
  /// shows its 390 canvas. Only when it's unbounded (in a horizontal scroll
  /// view) does the screen width stand in for it.
  static double breakpointWidth(BuildContext context, BoxConstraints constraints) =>
      constraints.hasBoundedWidth ? constraints.maxWidth : MediaQuery.sizeOf(context).width;
}

/// Lays [child] (a canvas's NodeView) out in the canvas box: at the
/// layout size, scaled into the box (autoScale), top-centered.
class CanvasViewportBox extends StatelessWidget {
  const CanvasViewportBox({super.key, required this.box, required this.child});

  final CanvasBox box;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // One structure for every mode, so switching canvases or modes keeps
    // the child (and its render tree) where it is.
    return SizedBox(
      width: box.width,
      height: box.height,
      child: ClipRect(
        child: _ScaledBox(
          scale: box.scale,
          child: SizedBox(width: box.layoutWidth, height: box.layoutHeight, child: child),
        ),
      ),
    );
  }
}

/// Lays its child out unconstrained in height when its own height is
/// unbounded, else at its size divided by [scale], and paints it scaled by
/// [scale] from the top center.
class _ScaledBox extends SingleChildRenderObjectWidget {
  const _ScaledBox({required this.scale, super.child});

  final double scale;

  @override
  _RenderScaledBox createRenderObject(BuildContext context) => _RenderScaledBox(scale);

  @override
  void updateRenderObject(BuildContext context, _RenderScaledBox renderObject) => renderObject.scale = scale;
}

class _RenderScaledBox extends RenderProxyBox {
  _RenderScaledBox(this._scale);

  double _scale;
  set scale(double v) {
    if (v == _scale) return;
    _scale = v;
    markNeedsLayout();
  }

  Matrix4 get _transform {
    final c = child;
    final dx = c == null ? 0.0 : (size.width - c.size.width * _scale) / 2;
    return Matrix4.translationValues(dx, 0, 0)..scaleByDouble(_scale, _scale, 1, 1);
  }

  @override
  void performLayout() {
    final c = child;
    if (c == null) {
      size = constraints.smallest;
      return;
    }
    c.layout(constraints.loosen().copyWith(maxWidth: double.infinity, maxHeight: double.infinity), parentUsesSize: true);
    size = constraints.constrain(Size(c.size.width * _scale, c.size.height * _scale));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final c = child;
    if (c == null) return;
    if (_scale == 1) {
      layer = null;
      context.paintChild(c, offset + Offset((size.width - c.size.width) / 2, 0));
      return;
    }
    layer = context.pushTransform(needsCompositing, offset, _transform, (context, offset) => context.paintChild(c, offset),
        oldLayer: layer as TransformLayer?);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final c = child;
    if (c == null) return false;
    return result.addWithPaintTransform(
      transform: _transform,
      position: position,
      hitTest: (result, position) => c.hitTest(result, position: position),
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) => transform.multiply(_transform);
}
