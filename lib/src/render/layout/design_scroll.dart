// A native single-child viewport. Design canvases stay at rest; running apps
// support clamped axis drags, pointer-wheel input, reveal and semantic actions
// without creating a widget/element for every authored container.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

class RenderDesignScroll extends RenderProxyBox {
  RenderDesignScroll({required this._axis, this._reverse = false, Clip clipBehavior = Clip.hardEdge})
      : _clip = clipBehavior;

  Axis _axis;
  Axis get axis => _axis;
  set axis(Axis v) {
    if (v == _axis) return;
    _axis = v;
    _resetInput();
    markNeedsLayout();
  }

  bool _reverse;
  bool get reverse => _reverse;
  set reverse(bool v) {
    if (v == _reverse) return;
    _reverse = v;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  Clip _clip;
  Clip get clipBehavior => _clip;
  set clipBehavior(Clip v) {
    if (v == _clip) return;
    _clip = v;
    markNeedsPaint();
  }

  bool _interactive = false;
  bool get interactive => _interactive;
  set interactive(bool value) {
    if (value == _interactive) return;
    _interactive = value;
    _resetInput();
    if (!value) _pixels = 0;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  bool _userScrollable = true;
  bool get userScrollable => _userScrollable;
  set userScrollable(bool value) {
    if (value == _userScrollable) return;
    _userScrollable = value;
    _resetInput();
    markNeedsSemanticsUpdate();
  }

  double _pixels = 0;
  double get pixels => _pixels;
  double get viewportExtent => _axis == Axis.vertical ? size.height : size.width;
  double get maxScrollExtent {
    final content = child;
    if (!hasSize || content == null || !content.hasSize) return 0;
    final extent = _axis == Axis.vertical ? content.size.height : content.size.width;
    return math.max(0, extent - viewportExtent);
  }

  DragGestureRecognizer? _drag;
  Ticker? _ticker;
  Completer<void>? _animation;

  void _resetInput() {
    _drag?.dispose();
    _drag = null;
    _stopAnimation();
  }

  void _stopAnimation() {
    _ticker?.dispose();
    _ticker = null;
    final animation = _animation;
    _animation = null;
    if (animation != null && !animation.isCompleted) animation.complete();
  }

  void _setPixels(double value) {
    final next = value.clamp(0.0, maxScrollExtent).toDouble();
    if (next == _pixels) return;
    _pixels = next;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  void _scrollBy(double physicalDelta) {
    _stopAnimation();
    _setPixels(_pixels + (_reverse ? -physicalDelta : physicalDelta));
  }

  DragGestureRecognizer _recognizer() {
    final recognizer = _drag;
    if (recognizer != null) return recognizer;
    final DragGestureRecognizer created = _axis == Axis.vertical
        ? VerticalDragGestureRecognizer(debugOwner: this)
        : HorizontalDragGestureRecognizer(debugOwner: this);
    created.onStart = (_) => _stopAnimation();
    created.onUpdate = (details) => _scrollBy(-(details.primaryDelta ?? 0));
    return _drag = created;
  }

  @override
  bool hitTestSelf(Offset position) => _interactive;

  @override
  void handleEvent(PointerEvent event, BoxHitTestEntry entry) {
    if (!_interactive || !_userScrollable || maxScrollExtent <= 0) return;
    if (event is PointerDownEvent) {
      _recognizer().addPointer(event);
    } else if (event is PointerPanZoomStartEvent) {
      _recognizer().addPointerPanZoom(event);
    } else if (event is PointerScrollEvent) {
      final delta = _axis == Axis.vertical ? event.scrollDelta.dy : event.scrollDelta.dx;
      final next = (_pixels + (_reverse ? -delta : delta)).clamp(0.0, maxScrollExtent);
      if (next != _pixels) {
        GestureBinding.instance.pointerSignalResolver.register(event, (_) => _scrollBy(delta));
      }
    }
  }

  /// Moves this viewport's logical offset; reverse uses its trailing edge as
  /// zero. New input or a new reveal completes and replaces any old animation.
  Future<void> scrollTo(double value, {Duration duration = Duration.zero, Curve curve = Curves.easeInOut}) {
    _stopAnimation();
    if (!_interactive) return Future.value();
    final target = value.clamp(0.0, maxScrollExtent).toDouble();
    if (duration <= Duration.zero || target == _pixels || !attached) {
      _setPixels(target);
      return Future.value();
    }
    final start = _pixels;
    final done = _animation = Completer<void>();
    _ticker = Ticker((elapsed) {
      final progress = (elapsed.inMicroseconds / duration.inMicroseconds).clamp(0.0, 1.0);
      _setPixels(start + (target - start) * curve.transform(progress));
      if (progress >= 1) _stopAnimation();
    })..start();
    return done.future;
  }

  /// Reveals an attached descendant, aligned along this viewport's axis.
  Future<void> reveal(RenderObject target, {double alignment = 0, double offset = 0,
      Rect? rect, Duration duration = Duration.zero, Curve curve = Curves.easeInOut}) {
    if (!_interactive || !attached || !target.attached || !hasSize) return Future.value();
    final bounds = MatrixUtils.transformRect(target.getTransformTo(this), rect ?? target.paintBounds);
    final start = _axis == Axis.vertical ? bounds.top : bounds.left;
    final extent = _axis == Axis.vertical ? bounds.height : bounds.width;
    final aligned = (viewportExtent - extent) * (_reverse ? 1 - alignment : alignment);
    return scrollTo(_pixels + (_reverse ? -1 : 1) * (start - aligned) - offset, duration: duration, curve: curve);
  }

  @override
  void showOnScreen({RenderObject? descendant, Rect? rect, Duration duration = Duration.zero, Curve curve = Curves.ease}) {
    if (descendant != null && descendant != this && _interactive) {
      final bounds = MatrixUtils.transformRect(descendant.getTransformTo(this), rect ?? descendant.paintBounds);
      final start = _axis == Axis.vertical ? bounds.top : bounds.left;
      final end = _axis == Axis.vertical ? bounds.bottom : bounds.right;
      final physicalAlignment = start < 0 ? 0.0 : end > viewportExtent ? 1.0 : null;
      if (physicalAlignment != null) {
        unawaited(reveal(descendant, rect: rect, alignment: _reverse ? 1 - physicalAlignment : physicalAlignment,
            duration: duration, curve: curve));
      }
      super.showOnScreen(descendant: this, rect: Offset.zero & size, duration: duration, curve: curve);
    } else {
      super.showOnScreen(descendant: descendant, rect: rect, duration: duration, curve: curve);
    }
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    if (!_interactive) return;
    config
      ..isSemanticBoundary = true
      ..hasImplicitScrolling = true
      ..scrollPosition = _pixels
      ..scrollExtentMin = 0
      ..scrollExtentMax = maxScrollExtent;
    final step = hasSize ? viewportExtent * 0.8 : 0.0;
    if (!_userScrollable) return;
    final backward = _reverse ? _pixels < maxScrollExtent : _pixels > 0;
    final forward = _reverse ? _pixels > 0 : _pixels < maxScrollExtent;
    if (_axis == Axis.vertical) {
      if (backward) config.onScrollUp = () => _scrollBy(-step);
      if (forward) config.onScrollDown = () => _scrollBy(step);
    } else {
      if (backward) config.onScrollLeft = () => _scrollBy(-step);
      if (forward) config.onScrollRight = () => _scrollBy(step);
    }
  }

  @override
  Rect? describeSemanticsClip(RenderObject? child) => hasSize ? Offset.zero & size : null;

  @override
  void detach() {
    _resetInput();
    super.detach();
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
    _pixels = _interactive ? _pixels.clamp(0.0, maxScrollExtent).toDouble() : 0;
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
    final base = _reverse ? (_axis == Axis.vertical ? size.height - child.size.height : size.width - child.size.width) : 0.0;
    final shift = base + (_reverse ? _pixels : -_pixels);
    return _axis == Axis.vertical ? Offset(0, shift) : Offset(shift, 0);
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
    _resetInput();
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
