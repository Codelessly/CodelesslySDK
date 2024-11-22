import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// A widget that applies a [BlendMode] to its child.
///
/// The [BlendMask] widget uses a [RenderBlendMask] to apply the specified
/// [blendMode] to its child widget during the paint phase. This can be used to
/// blend the child widget with the background or to create various visual
/// effects.
///
/// {@tool snippet}
/// This example shows how to use the [BlendMask] widget to apply a
/// [BlendMode.multiply] effect to an image.
///
/// ```dart
/// BlendMask(
///   blendMode: BlendMode.multiply,
///   child: Image.asset('assets/my_image.png'),
/// );
/// ```
/// {@end-tool}
///
/// See also:
///
///  * [BlendMode], which describes the different ways to blend a source image
///    with the destination image.
class BlendMask extends SingleChildRenderObjectWidget {
  /// The blend mode to apply to the child widget.
  final BlendMode blendMode;

  /// Creates a widget that blends its child using the given [blendMode].
  ///
  /// The [blendMode] argument must not be null.
  const BlendMask({
    this.blendMode = BlendMode.srcOver,
    super.key,
    super.child,
  });

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderBlendMask(blendMode);
  }

  @override
  void updateRenderObject(BuildContext context, RenderBlendMask renderObject) {
    renderObject.blendMode = blendMode;
  }
}

/// A render object that applies a [BlendMode] to its child during painting.
///
/// The [RenderBlendMask] uses a [Paint] object with the specified [blendMode]
/// and applies it to the child by saving a layer with that paint during the
/// paint phase.
///
/// This render object is typically used by the [BlendMask] widget.
class RenderBlendMask extends RenderProxyBox {
  BlendMode _blendMode;

  /// The blend mode to apply to the child during painting.
  ///
  /// Changing this value will cause the render object to repaint.
  BlendMode get blendMode => _blendMode;

  set blendMode(BlendMode value) {
    if (_blendMode == value) return;
    _blendMode = value;
    blender.blendMode = _blendMode;
    markNeedsPaint();
  }

  /// The [Paint] object used to blend the child.
  ///
  /// It is initialized with the [_blendMode] and a white color.
  final Paint blender;

  /// Creates a [RenderBlendMask] with the given [blendMode].
  ///
  /// The [blendMode] must not be null.
  RenderBlendMask(BlendMode blendMode)
      : _blendMode = blendMode,
        blender = Paint()
          ..blendMode = blendMode
          ..color = Colors.white;

  @override
  void paint(PaintingContext context, Offset offset) {
    // Complex blend modes can be raster cached incorrectly on the Skia backend.
    if (blendMode != BlendMode.srcOver) {
      context.setWillChangeHint();
    }

    context.canvas.saveLayer(offset & size, blender);

    super.paint(context, offset);

    context.canvas.restore();
  }
}
