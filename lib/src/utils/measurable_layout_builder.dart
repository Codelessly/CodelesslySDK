import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// A [LayoutBuilder] that can be measured: it reports intrinsic sizes and a
/// dry layout instead of throwing "LayoutBuilder does not support returning
/// intrinsic dimensions".
///
/// A node tree puts a builder like this under nodes whose widget depends on
/// the constraints they get (a node that reads its parent's size, a
/// responsive variant, a chart, a one-line text field filling its height).
/// Those nodes still sit in rows and columns whose children are measured,
/// e.g. `IntrinsicHeight(Row(crossAxisAlignment: stretch))` for a timeline
/// rail as tall as the entry beside it, and one plain [LayoutBuilder] below
/// would stop the whole screen from painting.
///
/// The intrinsic sizes are those of the subtree the builder built last,
/// measured as it is. Before it has built anything (the first layout of a
/// measured parent asks before laying it out) they are [fallbackSize], the
/// node's design size, and the parent is laid out once more after that
/// frame with the real measurements.
class MeasurableLayoutBuilder extends ConstrainedLayoutBuilder<BoxConstraints> {
  /// Creates a [MeasurableLayoutBuilder].
  const MeasurableLayoutBuilder({
    super.key,
    required super.builder,
    this.fallbackSize,
  });

  /// The size reported before the builder has built anything: the design
  /// size of the node it builds. Null reports zero.
  final Size? fallbackSize;

  @override
  RenderMeasurableLayoutBuilder createRenderObject(BuildContext context) =>
      RenderMeasurableLayoutBuilder(fallbackSize: fallbackSize);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderMeasurableLayoutBuilder renderObject,
  ) {
    renderObject.fallbackSize = fallbackSize;
  }
}

/// The render object of [MeasurableLayoutBuilder].
class RenderMeasurableLayoutBuilder extends RenderBox
    with
        RenderObjectWithChildMixin<RenderBox>,
        RenderObjectWithLayoutCallbackMixin,
        RenderAbstractLayoutBuilderMixin<BoxConstraints, RenderBox> {
  /// Creates a [RenderMeasurableLayoutBuilder].
  RenderMeasurableLayoutBuilder({this._fallbackSize});

  Size? _fallbackSize;

  /// See [MeasurableLayoutBuilder.fallbackSize].
  Size? get fallbackSize => _fallbackSize;
  set fallbackSize(Size? value) {
    if (_fallbackSize == value) return;
    _fallbackSize = value;
    if (child == null) markNeedsLayout();
  }

  /// Whether a size was reported from [fallbackSize] since the last layout,
  /// so the parent must measure again once the subtree is built.
  bool _guessed = false;
  bool _remeasureScheduled = false;

  double _fallback(double Function(Size size) extent) {
    _guessed = true;
    final Size? size = _fallbackSize;
    if (size == null) return 0;
    final double value = extent(size);
    return value.isFinite && value > 0 ? value : 0;
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      child?.getMinIntrinsicWidth(height) ?? _fallback((s) => s.width);

  @override
  double computeMaxIntrinsicWidth(double height) =>
      child?.getMaxIntrinsicWidth(height) ?? _fallback((s) => s.width);

  @override
  double computeMinIntrinsicHeight(double width) =>
      child?.getMinIntrinsicHeight(width) ?? _fallback((s) => s.height);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      child?.getMaxIntrinsicHeight(width) ?? _fallback((s) => s.height);

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final RenderBox? child = this.child;
    if (child != null) {
      return constraints.constrain(child.getDryLayout(constraints));
    }
    _guessed = true;
    return constraints.constrain(_fallbackSize ?? Size.zero);
  }

  @override
  double? computeDryBaseline(
    covariant BoxConstraints constraints,
    TextBaseline baseline,
  ) => child?.getDryBaseline(constraints, baseline);

  @override
  void performLayout() {
    final BoxConstraints constraints = this.constraints;
    runLayoutCallback();
    final RenderBox? child = this.child;
    if (child != null) {
      child.layout(constraints, parentUsesSize: true);
      size = constraints.constrain(child.size);
    } else {
      size = constraints.biggest.isFinite
          ? constraints.biggest
          : constraints.smallest;
    }
    if (_guessed && child != null) _remeasureAfterFrame();
  }

  /// Lays the parent out again after this frame, now that the subtree it
  /// measured through [fallbackSize] exists.
  void _remeasureAfterFrame() {
    _guessed = false;
    if (_remeasureScheduled) return;
    _remeasureScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _remeasureScheduled = false;
      // Dropping the cached intrinsics lays the parent out again.
      if (attached) markNeedsLayout();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      child?.getDistanceToActualBaseline(baseline) ??
      super.computeDistanceToActualBaseline(baseline);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      child?.hitTest(result, position: position) ?? false;

  @override
  void paint(PaintingContext context, Offset offset) {
    final RenderBox? child = this.child;
    if (child != null) context.paintChild(child, offset);
  }
}
