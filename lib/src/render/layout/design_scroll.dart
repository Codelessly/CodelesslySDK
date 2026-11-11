// A scroll viewport: at rest on the design canvas, interactive in a running app.
// The at-rest layout matches SingleChildScrollView's
// viewport does at scroll offset 0, without a ScrollPosition, controller,
// gesture detector or element tree. The design canvas shows content at its
// start (the end, when reversed), clipped to the viewport.
import 'package:flutter/rendering.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';

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
    _drag?.dispose();
    _drag = null;
    _flingEpoch++;
    if (!value) _offset = 0;
    markNeedsPaint();
  }

  double _offset = 0;
  double get offset => _offset;
  double get maxScrollExtent {
    final c = child;
    if (c == null || !hasSize || !c.hasSize) return 0;
    return (_axis == Axis.vertical
            ? c.size.height - size.height
            : c.size.width - size.width)
        .clamp(0, double.infinity);
  }

  void Function(double offset, double maxExtent)? onScroll;
  /// Moves an interactive viewport relative to its current position.
  void jumpBy(double delta) {
    if (interactive) jumpTo(offset + delta);
  }

  void jumpTo(double value) {
    _flingEpoch++;
    _moveTo(value);
  }

  void _moveTo(double value) {
    final next = value.clamp(0, maxScrollExtent).toDouble();
    if (next == _offset) return;
    _offset = next;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
    onScroll?.call(_offset, maxScrollExtent);
  }

  double get _sign => _reverse ? -1 : 1;
  DragGestureRecognizer? _drag;
  int _flingEpoch = 0;
  DragGestureRecognizer _recognizer() => _drag ??=
      (_axis == Axis.vertical
            ? VerticalDragGestureRecognizer(debugOwner: this)
            : HorizontalDragGestureRecognizer(debugOwner: this))
        ..onStart = (_) {
          _flingEpoch++;
        }
        ..onUpdate = (event) {
          jumpTo(_offset - (event.primaryDelta ?? 0) * _sign);
        }
        ..onEnd = (event) {
          _fling(-(event.primaryVelocity ?? 0) * _sign);
        };

  void _fling(double velocity) {
    if (velocity.abs() < 30) return;
    final simulation = FrictionSimulation(.135, _offset, velocity);
    final epoch = ++_flingEpoch;
    Duration? start;
    void tick(Duration now) {
      if (!attached || !_interactive || epoch != _flingEpoch) return;
      start ??= now;
      final t = (now - start!).inMicroseconds / Duration.microsecondsPerSecond;
      final value = simulation.x(t);
      _moveTo(value);
      if (!simulation.isDone(t) && value >= 0 && value <= maxScrollExtent) {
        SchedulerBinding.instance.scheduleFrameCallback(tick);
      }
    }

    SchedulerBinding.instance.scheduleFrameCallback(tick);
  }

  @override
  bool hitTestSelf(Offset position) => _interactive;

  @override
  void handleEvent(PointerEvent event, HitTestEntry entry) {
    if (!_interactive) return;
    if (event is PointerDownEvent) _recognizer().addPointer(event);
    if (event is PointerScrollEvent) {
      final delta =
          (_axis == Axis.vertical
              ? event.scrollDelta.dy
              : event.scrollDelta.dx) *
          _sign;
      if ((_offset + delta).clamp(0, maxScrollExtent) != _offset) {
        GestureBinding.instance.pointerSignalResolver.register(
          event,
          (_) => jumpTo(_offset + delta),
        );
      }
    }
  }

  Axis _axis;
  Axis get axis => _axis;
  set axis(Axis v) {
    if (v == _axis) return;
    _axis = v;
    _drag?.dispose();
    _drag = null;
    _flingEpoch++;
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
    _offset = _offset.clamp(0, maxScrollExtent);
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
    final end = _axis == Axis.vertical
        ? size.height - child.size.height
        : size.width - child.size.width;
    final position = _reverse
        ? end + (_interactive ? _offset : 0)
        : (_interactive ? -_offset : 0.0);
    return _axis == Axis.vertical ? Offset(0, position) : Offset(position, 0);
  }

  bool get _overflows {
    final child = this.child;
    return child != null &&
        (child.size.width > size.width || child.size.height > size.height);
  }

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
  void detach() {
    _flingEpoch++;
    _drag?.dispose();
    _drag = null;
    super.detach();
  }

  @override
  void dispose() {
    _drag?.dispose();
    _flingEpoch++;
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
