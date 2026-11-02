import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'node_motion.dart';

/// Animates a node's size when it changes: see `BaseNode.sizeTransition`.
///
/// Whenever [child] lays out at a new size, this box eases from the size it
/// had to the new one over [duration] with [curve]. On each axis:
///
/// * [resizeWidth] / [resizeHeight] true (a node with a set size, e.g. a
///   toggle's thumb whose width is bound): [child] is laid out at every size
///   in between, so it visibly grows or shrinks.
/// * false (a node hugging its content, e.g. an FAQ answer opening): [child]
///   is laid out at its new size at once and the box around it grows or
///   shrinks, clipping it meanwhile, which reveals or hides it smoothly.
///
/// The first layout takes the child's size as it is. Below a
/// [NodeMotionScope] that turns motion off (the design canvas), or with a
/// zero [duration], the box always takes its child's size.
class NodeSizeTransition extends StatefulWidget {
  /// Creates a [NodeSizeTransition].
  const NodeSizeTransition({
    super.key,
    required this.duration,
    this.curve = Curves.easeInOut,
    this.resizeWidth = false,
    this.resizeHeight = false,
    required this.child,
  });

  /// How long a change of size takes.
  final Duration duration;

  /// The easing of a change of size.
  final Curve curve;

  /// Whether the child is laid out at each width in between.
  final bool resizeWidth;

  /// Whether the child is laid out at each height in between.
  final bool resizeHeight;

  /// The node's widget.
  final Widget child;

  @override
  State<NodeSizeTransition> createState() => _NodeSizeTransitionState();
}

class _NodeSizeTransitionState extends State<NodeSizeTransition>
    with SingleTickerProviderStateMixin {
  @override
  Widget build(BuildContext context) => _SizeTransitionBox(
    vsync: this,
    duration: widget.duration,
    curve: widget.curve,
    resizeWidth: widget.resizeWidth,
    resizeHeight: widget.resizeHeight,
    enabled:
        widget.duration > Duration.zero && NodeMotionScope.animatesAt(context),
    child: widget.child,
  );
}

class _SizeTransitionBox extends SingleChildRenderObjectWidget {
  const _SizeTransitionBox({
    required this.vsync,
    required this.duration,
    required this.curve,
    required this.resizeWidth,
    required this.resizeHeight,
    required this.enabled,
    super.child,
  });

  final TickerProvider vsync;
  final Duration duration;
  final Curve curve;
  final bool resizeWidth;
  final bool resizeHeight;
  final bool enabled;

  @override
  RenderNodeSizeTransition createRenderObject(BuildContext context) =>
      RenderNodeSizeTransition(
        vsync: vsync,
        duration: duration,
        curve: curve,
        resizeWidth: resizeWidth,
        resizeHeight: resizeHeight,
        enabled: enabled,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderNodeSizeTransition renderObject,
  ) {
    renderObject
      ..vsync = vsync
      ..duration = duration
      ..curve = curve
      ..resizeWidth = resizeWidth
      ..resizeHeight = resizeHeight
      ..enabled = enabled;
  }
}

const double _tolerance = 1e-6;

/// The render object of [NodeSizeTransition].
class RenderNodeSizeTransition extends RenderProxyBox {
  /// Creates a [RenderNodeSizeTransition].
  RenderNodeSizeTransition({
    required TickerProvider vsync,
    required Duration duration,
    this._curve = Curves.easeInOut,
    this._resizeWidth = false,
    this._resizeHeight = false,
    this._enabled = true,
  }) : _vsync = vsync,
       _controller = AnimationController(vsync: vsync, duration: duration) {
    _controller.addListener(() {
      if (_controller.value != _lastValue) markNeedsLayout();
    });
  }

  final AnimationController _controller;
  double? _lastValue;

  /// The size the box eases from, and to.
  Size? _from;
  Size? _to;

  bool _overflows = false;
  final LayerHandle<ClipRectLayer> _clipLayer = LayerHandle<ClipRectLayer>();

  TickerProvider _vsync;
  set vsync(TickerProvider value) {
    if (_vsync == value) return;
    _vsync = value;
    _controller.resync(value);
  }

  set duration(Duration value) => _controller.duration = value;

  Curve _curve;
  set curve(Curve value) => _curve = value;

  bool _resizeWidth;
  set resizeWidth(bool value) {
    if (_resizeWidth == value) return;
    _resizeWidth = value;
    markNeedsLayout();
  }

  bool _resizeHeight;
  set resizeHeight(bool value) {
    if (_resizeHeight == value) return;
    _resizeHeight = value;
    markNeedsLayout();
  }

  bool _enabled;
  set enabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    markNeedsLayout();
  }

  /// Whether the box is easing to a new size.
  bool get isAnimating => _controller.isAnimating;

  Size get _current {
    final Size to = _to!;
    if (!_controller.isAnimating && _controller.value >= 1) return to;
    return Size.lerp(_from, to, _curve.transform(_controller.value))!;
  }

  @override
  void detach() {
    _controller.stop();
    super.detach();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    // Resume an interrupted change.
    if (_to != null && _controller.value < 1) markNeedsLayout();
  }

  @override
  void dispose() {
    _clipLayer.layer = null;
    _controller.dispose();
    super.dispose();
  }

  @override
  void performLayout() {
    _lastValue = _controller.value;
    _overflows = false;
    final RenderBox? child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(constraints, parentUsesSize: true);
    final Size target = child.size;
    if (!_enabled || _to == null) {
      _controller.stop();
      _lastValue = 1;
      _controller.value = 1;
      _from = _to = target;
      size = target;
      return;
    }
    if (target != _to) {
      _from = _current;
      _to = target;
      _lastValue = 0;
      _controller.forward(from: 0);
    } else if (_controller.value < 1 && !_controller.isAnimating) {
      // Interrupted while detached.
      _controller.forward();
    }
    final Size current = constraints.constrain(_current);
    size = current;
    if (current == target) return;
    if (_resizeWidth || _resizeHeight) {
      child.layout(
        constraints.tighten(
          width: _resizeWidth ? current.width : null,
          height: _resizeHeight ? current.height : null,
        ),
        parentUsesSize: true,
      );
    }
    _overflows =
        child.size.width > size.width + _tolerance ||
        child.size.height > size.height + _tolerance;
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      child?.getDryLayout(constraints) ?? constraints.smallest;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) return;
    if (!_overflows) {
      _clipLayer.layer = null;
      return super.paint(context, offset);
    }
    _clipLayer.layer = context.pushClipRect(
      needsCompositing,
      offset,
      Offset.zero & size,
      super.paint,
      oldLayer: _clipLayer.layer,
    );
  }
}
