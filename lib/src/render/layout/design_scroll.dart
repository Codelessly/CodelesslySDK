// A node's scroll viewport: at rest on the design canvas, interactive in
// a running app. Keeps scrolling in the render tree without one widget per
// node, with wheel arbitration, axis gestures, clamped fling and semantics.
import 'dart:async';
import 'package:flutter/animation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/physics.dart';

class RenderDesignScroll extends RenderProxyBox {
  RenderDesignScroll({
    required this._axis,
    this._reverse = false,
    Clip clipBehavior = Clip.hardEdge,
  }) : _clip = clipBehavior;

  bool _interactive = false;
  bool get interactive => _interactive;
  set interactive(bool value) {
    if (value == _interactive) return;
    _interactive = value;
    if (!value) {
      _stop();
      _drag?.dispose();
      _drag = null;
      _pixels = 0;
    }
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  /// Offset from the logical start, independent of reverse.
  double get pixels => _pixels;
  double get offset => _pixels;
  void jumpBy(double delta) { if (interactive) jumpTo(_pixels + delta); }
  double _pixels = 0;
  double get maxScrollExtent {
    final c = child;
    if (!hasSize || c == null || !c.hasSize) return 0;
    return ((_axis == Axis.vertical
            ? c.size.height - size.height
            : c.size.width - size.width))
        .clamp(0, double.infinity);
  }

  void Function(Map<String, Object?>)? onScroll, onScrollEnd;
  Timer? _scrollEnd;
  bool _pendingEvent = false;
  Map<String, Object?> get metrics => {
    'offset': _pixels,
    'pixels': _pixels,
    'min': 0.0,
    'max': maxScrollExtent,
    'viewport': hasSize
        ? (_axis == Axis.vertical ? size.height : size.width)
        : 0.0,
    'fraction': maxScrollExtent > 0 ? _pixels / maxScrollExtent : 0.0,
    'progress': maxScrollExtent > 0 ? _pixels / maxScrollExtent : 0.0,
    'axis': _axis.name,
  };
  void _notifyScroll() {
    if (onScroll == null && onScrollEnd == null) return;
    if (!_pendingEvent) {
      _pendingEvent = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _pendingEvent = false;
        if (attached) onScroll?.call(metrics);
      });
      SchedulerBinding.instance.scheduleFrame();
    }
    _scrollEnd?.cancel();
    _scrollEnd = Timer(const Duration(milliseconds: 100), () {
      if (attached) onScrollEnd?.call(metrics);
    });
  }


  DragGestureRecognizer? _drag;
  Ticker? _ticker;
  Completer<void>? _animationDone;
  void _stop() {
    _ticker?.dispose();
    _ticker = null;
    final d = _animationDone;
    _animationDone = null;
    if (d != null && !d.isCompleted) d.complete();
  }

  /// Logical offset revealing [target] at [alignment] in this viewport.
  double getOffsetToReveal(RenderObject target,double alignment) {
    final rect=MatrixUtils.transformRect(target.getTransformTo(this),target.paintBounds);
    final start=_axis==Axis.vertical?rect.top:rect.left;
    final extent=_axis==Axis.vertical?rect.height:rect.width;
    final viewport=_axis==Axis.vertical?size.height:size.width;
    return _pixels+(start-(viewport-extent)*alignment)*(_reverse?-1:1);
  }

  Future<void> reveal(
    RenderObject target, {
    double alignment = 0,
    double extraOffset = 0,
    Duration duration = Duration.zero,
    Curve curve = Curves.easeInOut,
  }) {
    if (!interactive || !hasSize || target is! RenderBox || !target.hasSize) {
      return Future.value();
    }
    final rect = MatrixUtils.transformRect(
      target.getTransformTo(this),
      Offset.zero & target.size,
    );
    final leading = _axis == Axis.vertical ? rect.top : rect.left;
    final targetExtent = _axis == Axis.vertical ? rect.height : rect.width;
    final viewport = _axis == Axis.vertical ? size.height : size.width;
    final paint = _axis == Axis.vertical ? _paintOffset.dy : _paintOffset.dx;
    final contentStart = leading - paint;
    final desired = reverse
        ? maxScrollExtent - contentStart + (viewport - targetExtent) * alignment
        : contentStart - (viewport - targetExtent) * alignment;
    return animateTo(desired - extraOffset, duration: duration, curve: curve);
  }


  void jumpTo(double value) {
    _stop();
    _setPixels(value);
  }

  void _setPixels(double value) {
    final next = value.clamp(0.0, maxScrollExtent);
    if (next == _pixels) return;
    _pixels = next;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
    _notifyScroll();
  }

  Future<void> animateTo(
    double value, {
    required Duration duration,
    Curve curve = Curves.easeInOut,
  }) {
    _stop();
    if (duration == Duration.zero) {
      _setPixels(value);
      return Future.value();
    }
    final start = _pixels,
        end = value.clamp(0.0, maxScrollExtent),
        done = Completer<void>();
    _animationDone = done;
    _ticker = Ticker((elapsed) {
      final t = (elapsed.inMicroseconds / duration.inMicroseconds).clamp(
        0.0,
        1.0,
      );
      _setPixels(start + (end - start) * curve.transform(t));
      if (t >= 1) {
        _stop();

      }
    })..start();
    return done.future;
  }

  void _fling(double velocity) {
    _stop();
    if (velocity.abs() < 50) {

      return;
    }
    final simulation = FrictionSimulation(.135, _pixels, velocity);
    _ticker = Ticker((elapsed) {
      final t = elapsed.inMicroseconds / 1000000.0, x = simulation.x(t);
      _setPixels(x);
      if (simulation.isDone(t) || x <= 0 || x >= maxScrollExtent) {
        _stop();

      }
    })..start();
  }

  void _ensureDrag() {
    if (_drag != null) return;
    final drag = _axis == Axis.vertical ? VerticalDragGestureRecognizer(debugOwner: this) : HorizontalDragGestureRecognizer(debugOwner: this);
    drag.onStart = (_) { _stop(); };
    drag.onUpdate = (d) { _setPixels(_pixels + (d.primaryDelta ?? 0) * (_reverse ? 1 : -1)); };
    drag.onEnd = (d) { _fling((d.primaryVelocity ?? 0) * (_reverse ? 1 : -1)); };
    drag.onCancel = () { onScrollEnd?.call(metrics); };
    _drag = drag;
  }

  @override
  bool hitTestSelf(Offset position) => _interactive;
  @override
  void handleEvent(PointerEvent event, HitTestEntry entry) {
    if (!_interactive || maxScrollExtent <= 0) return;
    if (event is PointerDownEvent) {
      _ensureDrag();
      _drag!.addPointer(event);
    }
    if (event is PointerScrollEvent) {
      final delta =
          (_axis == Axis.vertical
              ? event.scrollDelta.dy
              : event.scrollDelta.dx) *
          (_reverse ? -1 : 1);
      if ((_pixels + delta).clamp(0, maxScrollExtent) == _pixels) return;
      GestureBinding.instance.pointerSignalResolver.register(event, (e) {
        _stop();
        _setPixels(_pixels + delta);

      });
    }
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    if (!_interactive) return;
    config
      ..isSemanticBoundary = true
      ..scrollPosition = _pixels
      ..scrollExtentMin = 0
      ..scrollExtentMax = maxScrollExtent;
    void by(double delta) => _setPixels(_pixels + delta);
    if (_axis == Axis.vertical) {
      config.onScrollUp = () => by(-size.height * .8);
      config.onScrollDown = () => by(size.height * .8);
    } else {
      config.onScrollLeft = () => by(-size.width * .8);
      config.onScrollRight = () => by(size.width * .8);
    }
  }

  @override
  void detach() {
    _stop();
    _scrollEnd?.cancel();
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
      final extent = _axis == Axis.vertical
          ? constraints.maxHeight
          : constraints.maxWidth;
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
    _pixels = _pixels.clamp(0, maxScrollExtent);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final child = this.child;
    if (child == null) return constraints.smallest;
    return constraints.constrain(
      child.getDryLayout(_contentConstraints(constraints)),
    );
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      child?.getMinIntrinsicWidth(height) ?? 0;
  @override
  double computeMaxIntrinsicWidth(double height) =>
      child?.getMaxIntrinsicWidth(height) ?? 0;
  @override
  double computeMinIntrinsicHeight(double width) =>
      child?.getMinIntrinsicHeight(width) ?? 0;
  @override
  double computeMaxIntrinsicHeight(double width) =>
      child?.getMaxIntrinsicHeight(width) ?? 0;

  /// Offset 0: the content's start at the viewport's start; reversed, its
  /// end at the viewport's end.
  Offset get _paintOffset {
    final child = this.child;
    if (child == null) return Offset.zero;
    final base = _reverse
        ? (_axis == Axis.vertical
              ? size.height - child.size.height
              : size.width - child.size.width)
        : 0.0;
    final offset = base + (_interactive ? _pixels * (_reverse ? 1 : -1) : 0);
    return _axis == Axis.vertical ? Offset(0, offset) : Offset(offset, 0);
  }

  bool get _overflows {
    final child = this.child;
    return child != null &&
        (child.size.width > size.width || child.size.height > size.height);
  }

  @override
  Rect? describeApproximatePaintClip(RenderObject child) =>
      _clip != Clip.none && _overflows ? Offset.zero & size : null;

  final LayerHandle<ClipRectLayer> _clipLayer = LayerHandle();

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    void paintContent(PaintingContext c, Offset o) =>
        c.paintChild(child, o + _paintOffset);
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
    _stop();
    _scrollEnd?.cancel();
    _drag?.dispose();
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
