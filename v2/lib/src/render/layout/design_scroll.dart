// A render-object viewport for generic scrolling containers. Design canvases
// stay at rest; runtime NodeViews opt into clamped wheel/drag scrolling and
// programmatic reveal. Lists retain their own virtualized widget viewports.
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

class RenderDesignScroll extends RenderProxyBox {
  RenderDesignScroll({required this._axis, this._reverse = false, Clip clipBehavior = Clip.hardEdge})
    : _clip = clipBehavior;

  /// Runtime input is opt-in; design canvases always keep their resting offset.
  bool _interactive = false;
  bool Function()? interactionEnabled;
  bool get interactive => interactionEnabled?.call() ?? _interactive;
  set interactive(bool value) {
    if (_interactive == value) return;
    _interactive = value;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  double _pixels = 0;
  double get pixels => interactive ? _pixels : 0;
  double get maxScrollExtent {
    final c = child;
    if (c == null || !hasSize || !c.hasSize) return 0;
    return math.max(0, _axis == Axis.vertical ? c.size.height - size.height : c.size.width - size.width);
  }

  /// Called after a runtime user/programmatic scroll, not during layout.
  void Function(double pixels)? onOffsetChanged;

  void jumpTo(double value) {
    _stopAnimation();
    _setPixels(value);
  }

  void _setPixels(double value) {
    if (!value.isFinite || !interactive) return;
    final next = value.clamp(0.0, maxScrollExtent).toDouble();
    if (next == _pixels) return;
    _pixels = next;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
    onOffsetChanged?.call(next);
  }

  Ticker? _ticker;
  Completer<void>? _animation;
  void _stopAnimation() {
    _ticker?.dispose();
    _ticker = null;
    final pending = _animation;
    _animation = null;
    if (pending != null && !pending.isCompleted) pending.complete();
  }

  Future<void> animateTo(double value, {required Duration duration, required Curve curve}) {
    _stopAnimation();
    if (!interactive || !value.isFinite || duration <= Duration.zero) {
      _setPixels(value);
      return Future<void>.value();
    }
    final from = _pixels, to = value.clamp(0.0, maxScrollExtent).toDouble();
    if (from == to) return Future<void>.value();
    final pending = _animation = Completer<void>();
    _ticker = Ticker((elapsed) {
      final t = (elapsed.inMicroseconds / duration.inMicroseconds).clamp(0.0, 1.0);
      _setPixels(from + (to - from) * curve.transform(t));
      if (t >= 1) _stopAnimation();
    })..start();
    return pending.future;
  }

  DragGestureRecognizer? _drag;
  void _ensureDrag() {
    if ((_axis == Axis.vertical && _drag is VerticalDragGestureRecognizer) ||
        (_axis == Axis.horizontal && _drag is HorizontalDragGestureRecognizer)) {
      return;
    }
    _drag?.dispose();
    _drag = _axis == Axis.vertical ? VerticalDragGestureRecognizer() : HorizontalDragGestureRecognizer();
    _drag!.onStart = (_) => _stopAnimation();
    _drag!.onUpdate = (d) => jumpTo(_pixels + (_reverse ? 1 : -1) * (d.primaryDelta ?? 0));
  }

  @override
  bool hitTestSelf(Offset position) => interactive;

  @override
  void handleEvent(PointerEvent event, covariant HitTestEntry entry) {
    if (!interactive) return;
    if (event is PointerDownEvent && maxScrollExtent > 0) {
      _ensureDrag();
      _drag!.addPointer(event);
    } else if (event is PointerScrollEvent) {
      final delta = (_axis == Axis.vertical ? event.scrollDelta.dy : event.scrollDelta.dx) * (_reverse ? -1 : 1);
      if ((_pixels + delta).clamp(0.0, maxScrollExtent) == _pixels) return;
      GestureBinding.instance.pointerSignalResolver.register(event, (_) => jumpTo(_pixels + delta));
    }
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    if (!interactive) return;
    config
      ..isSemanticBoundary = true
      ..hasImplicitScrolling = true
      ..scrollPosition = pixels
      ..scrollExtentMin = 0
      ..scrollExtentMax = maxScrollExtent;
    final extent = hasSize ? (_axis == Axis.vertical ? size.height : size.width) * .8 : 0.0;
    void forward() => jumpTo(_pixels + extent);
    void backward() => jumpTo(_pixels - extent);
    final canForward = _pixels < maxScrollExtent;
    final canBackward = _pixels > 0;
    // Flutter names these as the content's drag direction: normal scrollUp
    // increases pixels (ScrollPosition._updateSemanticActions).
    if (_axis == Axis.vertical) {
      if (_reverse ? canBackward : canForward) config.onScrollUp = _reverse ? backward : forward;
      if (_reverse ? canForward : canBackward) config.onScrollDown = _reverse ? forward : backward;
    } else {
      if (_reverse ? canBackward : canForward) config.onScrollLeft = _reverse ? backward : forward;
      if (_reverse ? canForward : canBackward) config.onScrollRight = _reverse ? forward : backward;
    }
  }

  @override
  void showOnScreen({
    RenderObject? descendant,
    Rect? rect,
    Duration duration = Duration.zero,
    Curve curve = Curves.ease,
  }) {
    if (interactive && descendant != null && hasSize) {
      final target = MatrixUtils.transformRect(descendant.getTransformTo(this), rect ?? descendant.paintBounds);
      final start = _axis == Axis.vertical ? target.top : target.left;
      final end = _axis == Axis.vertical ? target.bottom : target.right;
      final extent = _axis == Axis.vertical ? size.height : size.width;
      final delta = start < 0 ? start : (end > extent ? end - extent : 0.0);
      if (delta != 0) {
        unawaited(animateTo(_pixels + delta * (_reverse ? -1 : 1), duration: duration, curve: curve));
      }
    }
    // Ancestor viewports still get the request; this viewport itself is visible.
    super.showOnScreen(descendant: this, rect: Offset.zero & size, duration: duration, curve: curve);
  }

  @override
  void detach() {
    _stopAnimation();
    _drag?.dispose();
    _drag = null;
    super.detach();
  }

  Axis _axis;
  Axis get axis => _axis;
  set axis(Axis v) {
    if (v == _axis) return;
    _axis = v;
    _drag?.dispose();
    _drag = null;
    _stopAnimation();
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
    _pixels = _pixels.clamp(0.0, maxScrollExtent).toDouble();
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
    if (child == null) return Offset.zero;
    final resting = _axis == Axis.vertical ? size.height - child.size.height : size.width - child.size.width;
    final offset = _reverse ? resting + pixels : -pixels;
    return _axis == Axis.vertical ? Offset(0, offset) : Offset(offset, 0);
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
      _clipLayer.layer = context.pushClipRect(
        needsCompositing,
        offset,
        Offset.zero & size,
        paintContent,
        clipBehavior: _clip,
        oldLayer: _clipLayer.layer,
      );
    } else {
      _clipLayer.layer = null;
      paintContent(context, offset);
    }
  }

  @override
  void dispose() {
    _stopAnimation();
    _drag?.dispose();
    _clipLayer.layer = null;
    super.dispose();
  }

  @override
  Rect? describeApproximatePaintClip(RenderObject child) => _clip == Clip.none || !hasSize ? null : Offset.zero & size;

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
