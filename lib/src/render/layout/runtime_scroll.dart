// A running row/column/freeform viewport. Its design counterpart stays at
// rest; this one keeps a real scroll offset without adding an element per
// node. Flutter's gesture arena and physics arbitrate drags and nested wheels.
import 'dart:async';
import 'dart:math' as math;

import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart'
    show
        ScrollPhysics,
        ClampingScrollPhysics,
        BouncingScrollPhysics,
        NeverScrollableScrollPhysics,
        RangeMaintainingScrollPhysics,
        AlwaysScrollableScrollPhysics,
        FixedScrollMetrics,
        Curve,
        Curves;

import 'design_scroll.dart';

ScrollPhysics runtimeScrollPhysics(
  api.ScrollPhysicsType type, {
  bool alwaysScroll = false,
}) {
  final platform =
      defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS
      ? const BouncingScrollPhysics()
      : const ClampingScrollPhysics();
  final base = switch (type) {
    api.ScrollPhysicsType.platform => platform,
    api.ScrollPhysicsType.bouncing => const BouncingScrollPhysics(),
    api.ScrollPhysicsType.clamping => const ClampingScrollPhysics(),
    api.ScrollPhysicsType.never => const NeverScrollableScrollPhysics(),
    api.ScrollPhysicsType.rangeMaintaining => RangeMaintainingScrollPhysics(
      parent: platform,
    ),
  };
  return alwaysScroll && type != api.ScrollPhysicsType.never
      ? AlwaysScrollableScrollPhysics(parent: base)
      : base;
}

class RenderRuntimeScroll extends RenderDesignScroll
    implements RenderAbstractViewport {
  RenderRuntimeScroll({
    required super.axis,
    super.reverse = false,
    super.clipBehavior = Clip.hardEdge,
  });

  ScrollPhysics physics = const ClampingScrollPhysics();
  void Function(double pixels, double delta)? onChanged;
  VoidCallback? onScrollEnd;

  double _pixels = 0;
  double get pixels => _pixels;
  double get minScrollExtent => 0;
  double get viewportExtent => !hasSize
      ? 0
      : axis == Axis.vertical
      ? size.height
      : size.width;
  double get maxScrollExtent {
    final c = child;
    if (!hasSize || c == null || !c.hasSize) return 0;
    return math.max(
      0,
      (axis == Axis.vertical ? c.size.height : c.size.width) - viewportExtent,
    );
  }

  FixedScrollMetrics get _metrics => FixedScrollMetrics(
    minScrollExtent: 0,
    maxScrollExtent: maxScrollExtent,
    pixels: pixels,
    viewportDimension: viewportExtent,
    axisDirection: axis == Axis.vertical
        ? (reverse ? AxisDirection.up : AxisDirection.down)
        : (reverse ? AxisDirection.left : AxisDirection.right),
    devicePixelRatio: 1,
  );

  DragGestureRecognizer? _drag;
  Axis? _dragAxis;
  Ticker? _ticker;
  Completer<void>? _animation;
  Timer? _wheelEnd;
  bool _scrolling = false;
  bool _dragging = false;

  @override
  void performLayout() {
    super.performLayout();
    if (!_dragging && _ticker?.isActive != true) {
      // Filtering/replacing content can shrink its scroll range. Clamping
      // here affects paint only and never mutates the document during layout.
      _pixels = _pixels.clamp(0, maxScrollExtent).toDouble();
    }
  }

  @override
  Offset get paintOffset {
    final base = super.paintOffset;
    final distance = reverse ? pixels : -pixels;
    return base +
        (axis == Axis.vertical ? Offset(0, distance) : Offset(distance, 0));
  }

  bool _setPixels(double value, {bool user = false}) {
    if (!value.isFinite || (value - pixels).abs() < .001) return false;
    if (user) {
      value -= physics.applyBoundaryConditions(_metrics, value);
    } else {
      value = value.clamp(0, maxScrollExtent).toDouble();
    }
    if ((value - pixels).abs() < .001) return false;
    final delta = value - pixels;
    _pixels = value;
    _scrolling = true;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
    onChanged?.call(value, delta);
    return true;
  }

  void _stopAnimation() {
    _ticker?.dispose();
    _ticker = null;
    final pending = _animation;
    _animation = null;
    if (pending != null && !pending.isCompleted) pending.complete();
  }

  void _endScroll() {
    if (!_scrolling) return;
    _scrolling = false;
    if (attached) onScrollEnd?.call();
  }

  /// A logical offset from the leading edge (the end, when reversed).
  void jumpTo(double value) {
    _stopAnimation();
    _wheelEnd?.cancel();
    _setPixels(value);
    _endScroll();
  }

  Future<void> animateTo(
    double value, {
    required Duration duration,
    Curve curve = Curves.easeInOut,
  }) {
    _stopAnimation();
    _wheelEnd?.cancel();
    final end = value.clamp(0, maxScrollExtent).toDouble();
    if (duration <= Duration.zero || (end - pixels).abs() < .001 || !attached) {
      jumpTo(end);
      return Future.value();
    }
    final start = pixels;
    final done = _animation = Completer<void>();
    _ticker = Ticker((elapsed) {
      final t = (elapsed.inMicroseconds / duration.inMicroseconds).clamp(
        0.0,
        1.0,
      );
      _setPixels(start + (end - start) * curve.transform(t));
      if (t >= 1) {
        _stopAnimation();
        _endScroll();
      }
    })..start();
    return done.future;
  }

  /// Physical input: positive scrolls down/right, including reversed views.
  void scrollBy(double delta) {
    jumpTo(pixels + (reverse ? -delta : delta));
  }

  void _ballistic(double velocity) {
    _stopAnimation();
    final simulation = physics.createBallisticSimulation(_metrics, velocity);
    if (simulation == null) {
      _endScroll();
      return;
    }
    _ticker = Ticker((elapsed) {
      final seconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
      final changed = _setPixels(simulation.x(seconds), user: true);
      if (simulation.isDone(seconds) ||
          (elapsed > Duration.zero && !changed && !(_metrics.outOfRange))) {
        _stopAnimation();
        _endScroll();
      }
    })..start();
  }

  DragGestureRecognizer get _recognizer {
    if (_drag == null || _dragAxis != axis) {
      _drag?.dispose();
      _dragAxis = axis;
      final r = axis == Axis.vertical
          ? VerticalDragGestureRecognizer(debugOwner: this)
          : HorizontalDragGestureRecognizer(debugOwner: this);
      r.onStart = (_) {
        _stopAnimation();
        _wheelEnd?.cancel();
        _dragging = true;
      };
      r.onUpdate = (details) {
        final delta = physics.applyPhysicsToUserOffset(
          _metrics,
          -(details.primaryDelta ?? 0),
        );
        _setPixels(pixels + (reverse ? -delta : delta), user: true);
      };
      r.onEnd = (details) {
        _dragging = false;
        _ballistic((details.primaryVelocity ?? 0) * (reverse ? 1 : -1));
      };
      r.onCancel = () {
        _dragging = false;
        _ballistic(0);
      };
      _drag = r;
    }
    return _drag!;
  }

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  void handleEvent(PointerEvent event, HitTestEntry entry) {
    if (!physics.shouldAcceptUserOffset(_metrics)) return;
    if (event is PointerDownEvent) {
      _recognizer.addPointer(event);
    } else if (event is PointerPanZoomStartEvent) {
      _recognizer.addPointerPanZoom(event);
    } else if (event is PointerScrollEvent) {
      final physical = axis == Axis.vertical
          ? event.scrollDelta.dy
          : event.scrollDelta.dx;
      final logical = reverse ? -physical : physical;
      final next = (pixels + logical).clamp(0, maxScrollExtent);
      // The innermost viewport that can move wins; at its edge its parent
      // may consume the wheel instead.
      if ((next - pixels).abs() < .001) return;
      GestureBinding.instance.pointerSignalResolver.register(event, (_) {
        _stopAnimation();
        _setPixels(next.toDouble());
        _wheelEnd?.cancel();
        _wheelEnd = Timer(const Duration(milliseconds: 150), _endScroll);
      });
    }
  }

  @override
  RevealedOffset getOffsetToReveal(
    RenderObject target,
    double alignment, {
    Rect? rect,
    Axis? axis,
  }) {
    final bounds = MatrixUtils.transformRect(
      target.getTransformTo(this),
      rect ?? target.paintBounds,
    );
    if (axis != null && axis != this.axis) {
      return RevealedOffset(offset: pixels, rect: bounds);
    }
    final leading = this.axis == Axis.vertical ? bounds.top : bounds.left;
    final extent = this.axis == Axis.vertical ? bounds.height : bounds.width;
    final to =
        pixels +
        (reverse ? -1 : 1) * (leading - (viewportExtent - extent) * alignment);
    final delta = (to - pixels) * (reverse ? 1 : -1);
    return RevealedOffset(
      offset: to,
      rect: bounds.shift(
        this.axis == Axis.vertical ? Offset(0, delta) : Offset(delta, 0),
      ),
    );
  }

  @override
  void showOnScreen({
    RenderObject? descendant,
    Rect? rect,
    Duration duration = Duration.zero,
    Curve curve = Curves.ease,
  }) {
    if (descendant != null) {
      final bounds = MatrixUtils.transformRect(
        descendant.getTransformTo(this),
        rect ?? descendant.paintBounds,
      );
      final leading = axis == Axis.vertical ? bounds.top : bounds.left;
      final trailing = axis == Axis.vertical ? bounds.bottom : bounds.right;
      if (leading < 0 || trailing > viewportExtent) {
        final reveal = getOffsetToReveal(
          descendant,
          leading < 0 ? 0 : 1,
          rect: rect,
        );
        unawaited(animateTo(reveal.offset, duration: duration, curve: curve));
      }
    }
    super.showOnScreen(
      rect: Offset.zero & size,
      duration: duration,
      curve: curve,
    );
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config.isSemanticBoundary = true;
    config.hasImplicitScrolling = true;
    config.scrollPosition = pixels;
    config.scrollExtentMin = 0;
    config.scrollExtentMax = maxScrollExtent;
    if (!physics.shouldAcceptUserOffset(_metrics)) return;
    final page = viewportExtent * .8;
    if (axis == Axis.vertical) {
      config.onScrollUp = () => scrollBy(-page);
      config.onScrollDown = () => scrollBy(page);
    } else {
      config.onScrollLeft = () => scrollBy(-page);
      config.onScrollRight = () => scrollBy(page);
    }
  }

  @override
  void detach() {
    _stopAnimation();
    _wheelEnd?.cancel();
    _drag?.dispose();
    _drag = null;
    _dragging = false;
    super.detach();
  }

  @override
  void dispose() {
    _stopAnimation();
    _wheelEnd?.cancel();
    _drag?.dispose();
    super.dispose();
  }
}
