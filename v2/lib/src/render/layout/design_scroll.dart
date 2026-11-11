// A scroll view at rest, as a render object: what SingleChildScrollView's
// viewport does at scroll offset 0, without a ScrollPosition, controller,
// gesture detector or element tree. The design canvas shows content at its
// start (the end, when reversed), clipped to the viewport.
import 'package:flutter/rendering.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';

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

/// Interactive counterpart of the design viewport. Keeps the same layout
/// contract while accepting drag and wheel input without adding an element
/// for every scrolling row/column in the document.
class RenderRuntimeScroll extends RenderDesignScroll {
  RenderRuntimeScroll({required super.axis}) {
    _ticker = Ticker(_tick);
  }

  /// False for a node configured with never-scroll physics.
  bool userScrollable = true;

  double _pixels = 0;
  double get pixels => _pixels;
  double get maxScrollExtent {
    if (child == null || !hasSize || !child!.hasSize) return 0;
    final delta = axis == Axis.vertical ? child!.size.height - size.height : child!.size.width - size.width;
    return delta.isFinite && delta > 0 ? delta : 0;
  }

  void jumpTo(double value) {
    _ticker.stop();
    _setPixels(value);
  }

  void _setPixels(double value) {
    final next = value.clamp(0.0, maxScrollExtent);
    if (_pixels == next) return;
    _pixels = next;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  late final Ticker _ticker;
  FrictionSimulation? _simulation;
  DragGestureRecognizer? _drag;
  Axis? _dragAxis;

  void _tick(Duration elapsed) {
    final simulation = _simulation;
    if (simulation == null) return;
    final seconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    final value = simulation.x(seconds);
    _setPixels(value);
    if (simulation.isDone(seconds) || value < 0 || value > maxScrollExtent) _ticker.stop();
  }

  DragGestureRecognizer get _recognizer {
    if (_dragAxis != axis) {
      _drag?.dispose();
      _dragAxis = axis;
      _drag = axis == Axis.vertical ? VerticalDragGestureRecognizer() : HorizontalDragGestureRecognizer();
      _drag!
        ..onStart = (_) { _ticker.stop(); }
        ..onUpdate = (d) { _setPixels(_pixels + (reverse ? 1.0 : -1.0) * (d.primaryDelta ?? 0)); }
        ..onEnd = (d) {
          final velocity = (reverse ? 1.0 : -1.0) * (d.primaryVelocity ?? 0);
          if (velocity.abs() < 50) return;
          _simulation = FrictionSimulation(.135, _pixels, velocity);
          _ticker.start();
        };
    }
    return _drag!;
  }

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  void handleEvent(PointerEvent event, BoxHitTestEntry entry) {
    if (event is PointerDownEvent && userScrollable && maxScrollExtent > 0) _recognizer.addPointer(event);
    if (event is PointerScrollEvent && userScrollable && maxScrollExtent > 0) {
      final delta = axis == Axis.vertical ? event.scrollDelta.dy : event.scrollDelta.dx;
      final target = (_pixels + (reverse ? -delta : delta)).clamp(0.0, maxScrollExtent);
      if (target != _pixels) {
        GestureBinding.instance.pointerSignalResolver.register(event, (_) => jumpTo(target));
      }
    }
  }

  @override
  void performLayout() {
    super.performLayout();
    _pixels = _pixels.clamp(0.0, maxScrollExtent);
  }

  @override
  Offset get _paintOffset {
    final distance = reverse ? maxScrollExtent - _pixels : _pixels;
    return axis == Axis.vertical ? Offset(0, -distance) : Offset(-distance, 0);
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config
      ..isSemanticBoundary = true
      ..hasImplicitScrolling = true
      ..scrollPosition = _pixels
      ..scrollExtentMin = 0
      ..scrollExtentMax = maxScrollExtent;
    if (userScrollable && maxScrollExtent > 0) {
      void forward() => jumpTo(_pixels + (axis == Axis.vertical ? size.height : size.width) * .8);
      void backward() => jumpTo(_pixels - (axis == Axis.vertical ? size.height : size.width) * .8);
      if (axis == Axis.vertical) {
        config.onScrollUp = reverse ? backward : forward;
        config.onScrollDown = reverse ? forward : backward;
      } else {
        config.onScrollLeft = reverse ? backward : forward;
        config.onScrollRight = reverse ? forward : backward;
      }
    }
  }

  @override
  void detach() {
    _ticker.stop();
    super.detach();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _drag?.dispose();
    super.dispose();
  }
}
