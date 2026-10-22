import 'package:flutter/widgets.dart';

/// Lets the user pinch or scroll to zoom [child] and drag to pan it; a
/// double tap zooms in, and another zooms back out. Keeps [child]'s size in
/// the layout.
class ZoomableBox extends StatefulWidget {
  /// What is zoomed.
  final Widget child;

  /// The most it zooms in.
  final double maxScale;

  const ZoomableBox({super.key, required this.child, this.maxScale = 4});

  @override
  State<ZoomableBox> createState() => _ZoomableBoxState();
}

class _ZoomableBoxState extends State<ZoomableBox> {
  final TransformationController controller = TransformationController();
  TapDownDetails? doubleTap;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void toggleZoom() {
    if (controller.value.getMaxScaleOnAxis() > 1) {
      controller.value = Matrix4.identity();
      return;
    }
    final Offset at = doubleTap?.localPosition ?? Offset.zero;
    const double scale = 2.5;
    controller.value = Matrix4.identity()
      ..translateByDouble(-at.dx * (scale - 1), -at.dy * (scale - 1), 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: (details) => doubleTap = details,
      onDoubleTap: toggleZoom,
      child: ClipRect(
        child: InteractiveViewer(
          transformationController: controller,
          maxScale: widget.maxScale,
          child: widget.child,
        ),
      ),
    );
  }
}
