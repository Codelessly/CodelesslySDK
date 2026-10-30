import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// A [LayoutBuilder] that answers intrinsic size queries instead of
/// throwing.
///
/// A [LayoutBuilder] can't report intrinsic sizes (its child is only built
/// during layout), so in debug builds it throws "LayoutBuilder does not
/// support returning intrinsic dimensions" when an ancestor such as
/// [IntrinsicWidth], [IntrinsicHeight], a wrapping list or a stretched row
/// measures it, and takes down the whole tree. In release it reports zero.
///
/// This one reports [intrinsicSize] (zero by default) in every build mode,
/// so a node built with it (an image placeholder, a field that fills its
/// height) can sit anywhere a design puts it.
class IntrinsicSafeLayoutBuilder extends ConstrainedLayoutBuilder<BoxConstraints> {
  /// The size reported to intrinsic and dry layout queries.
  final Size intrinsicSize;

  /// Creates a layout builder that reports [intrinsicSize] when measured.
  const IntrinsicSafeLayoutBuilder({
    super.key,
    required super.builder,
    this.intrinsicSize = Size.zero,
  });

  @override
  RenderAbstractLayoutBuilderMixin<BoxConstraints, RenderBox>
  createRenderObject(BuildContext context) =>
      _RenderIntrinsicSafeLayoutBuilder(intrinsicSize);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderObject renderObject,
  ) {
    (renderObject as _RenderIntrinsicSafeLayoutBuilder).intrinsicSize =
        intrinsicSize;
  }
}

class _RenderIntrinsicSafeLayoutBuilder extends RenderBox
    with
        RenderObjectWithChildMixin<RenderBox>,
        RenderObjectWithLayoutCallbackMixin,
        RenderAbstractLayoutBuilderMixin<BoxConstraints, RenderBox> {
  _RenderIntrinsicSafeLayoutBuilder(this._intrinsicSize);

  Size _intrinsicSize;

  set intrinsicSize(Size value) {
    if (value == _intrinsicSize) return;
    _intrinsicSize = value;
    markNeedsLayout();
  }

  @override
  double computeMinIntrinsicWidth(double height) => _intrinsicSize.width;

  @override
  double computeMaxIntrinsicWidth(double height) => _intrinsicSize.width;

  @override
  double computeMinIntrinsicHeight(double width) => _intrinsicSize.height;

  @override
  double computeMaxIntrinsicHeight(double width) => _intrinsicSize.height;

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      constraints.constrain(_intrinsicSize);

  @override
  double? computeDryBaseline(
    BoxConstraints constraints,
    TextBaseline baseline,
  ) => null;

  @override
  void performLayout() {
    final BoxConstraints constraints = this.constraints;
    runLayoutCallback();
    if (child != null) {
      child!.layout(constraints, parentUsesSize: true);
      size = constraints.constrain(child!.size);
    } else {
      size = constraints.biggest;
    }
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
    if (child != null) context.paintChild(child!, offset);
  }
}
