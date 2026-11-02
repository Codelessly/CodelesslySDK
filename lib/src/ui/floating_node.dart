import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Draws [child] in the app's overlay, exactly where it is laid out: above
/// every other node, not clipped by its ancestors and tappable outside
/// them. The layout keeps an empty box of the child's size, so nothing
/// around it moves. Used for nodes marked `floating` (a type-ahead's menu
/// under its field). Without an [Overlay] above it, the child is drawn in
/// place.
class FloatingNode extends StatefulWidget {
  const FloatingNode({super.key, required this.child});

  final Widget child;

  @override
  State<FloatingNode> createState() => _FloatingNodeState();
}

class _FloatingNodeState extends State<FloatingNode> {
  final LayerLink _link = LayerLink();
  final OverlayPortalController _portal = OverlayPortalController();
  BoxConstraints _constraints = const BoxConstraints();
  Size _size = Size.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _portal.show();
    });
  }

  void _setSize(Size size) {
    if (size == _size || !mounted) return;
    setState(() => _size = size);
  }

  @override
  Widget build(BuildContext context) {
    if (Overlay.maybeOf(context) == null) return widget.child;
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: (context) => CompositedTransformFollower(
        link: _link,
        showWhenUnlinked: false,
        child: Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: _constraints,
            child: _SizeReporter(onSize: _setSize, child: widget.child),
          ),
        ),
      ),
      child: CompositedTransformTarget(
        link: _link,
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints != _constraints) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && constraints != _constraints) {
                  setState(() => _constraints = constraints);
                }
              });
            }
            final Size size = constraints.constrain(_size);
            return SizedBox(width: size.width, height: size.height);
          },
        ),
      ),
    );
  }
}

/// Reports its child's size after each layout.
class _SizeReporter extends SingleChildRenderObjectWidget {
  const _SizeReporter({required this.onSize, super.child});

  final ValueChanged<Size> onSize;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSizeReporter(onSize);

  @override
  void updateRenderObject(BuildContext context, _RenderSizeReporter render) =>
      render.onSize = onSize;
}

class _RenderSizeReporter extends RenderProxyBox {
  _RenderSizeReporter(this.onSize);

  ValueChanged<Size> onSize;

  @override
  void performLayout() {
    super.performLayout();
    final Size reported = size;
    WidgetsBinding.instance.addPostFrameCallback((_) => onSize(reported));
  }
}
