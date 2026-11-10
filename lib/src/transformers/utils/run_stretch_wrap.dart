import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// A [Wrap] whose children are each as thick across [direction] as the
/// thickest child of their run: equal-height tiles in every row of a
/// feature grid, like CSS flex-wrap with `align-items: stretch`.
///
/// Runs are filled like [Wrap] does, with [spacing] between the children of
/// a run, [runSpacing] between runs and [alignment] along a run. Every child
/// is then laid out again with its own extent along [direction] and the
/// run's thickness across it.
///
/// A child's thickness is its natural one: its max intrinsic extent across
/// [direction] for its extent along it, when [measureChildren] is true, else
/// the extent it takes when laid out with an unbounded cross axis. Pass
/// false when a child can't report intrinsic sizes (it holds a viewport).
class RunStretchWrap extends MultiChildRenderObjectWidget {
  /// Creates a [RunStretchWrap].
  const RunStretchWrap({
    super.key,
    this.direction = Axis.horizontal,
    this.spacing = 0,
    this.runSpacing = 0,
    this.alignment = WrapAlignment.start,
    this.measureChildren = true,
    super.children,
  });

  /// The direction runs are filled in.
  final Axis direction;

  /// The gap between two children of a run.
  final double spacing;

  /// The gap between two runs.
  final double runSpacing;

  /// How the children of a run are placed along it.
  final WrapAlignment alignment;

  /// Whether the children's thickness is measured from their intrinsic
  /// sizes.
  final bool measureChildren;

  @override
  RenderRunStretchWrap createRenderObject(BuildContext context) =>
      RenderRunStretchWrap(
        direction: direction,
        spacing: spacing,
        runSpacing: runSpacing,
        alignment: alignment,
        measureChildren: measureChildren,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderRunStretchWrap renderObject,
  ) {
    renderObject
      ..direction = direction
      ..spacing = spacing
      ..runSpacing = runSpacing
      ..alignment = alignment
      ..measureChildren = measureChildren;
  }
}

/// Parent data of a child of [RenderRunStretchWrap].
class RunStretchWrapParentData extends ContainerBoxParentData<RenderBox> {}

/// The render object of [RunStretchWrap].
class RenderRunStretchWrap extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, RunStretchWrapParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, RunStretchWrapParentData> {
  /// Creates a [RenderRunStretchWrap].
  RenderRunStretchWrap({
    this._direction = Axis.horizontal,
    this._spacing = 0,
    this._runSpacing = 0,
    this._alignment = WrapAlignment.start,
    this._measureChildren = true,
  });

  Axis _direction;
  Axis get direction => _direction;
  set direction(Axis value) {
    if (_direction == value) return;
    _direction = value;
    markNeedsLayout();
  }

  double _spacing;
  double get spacing => _spacing;
  set spacing(double value) {
    if (_spacing == value) return;
    _spacing = value;
    markNeedsLayout();
  }

  double _runSpacing;
  double get runSpacing => _runSpacing;
  set runSpacing(double value) {
    if (_runSpacing == value) return;
    _runSpacing = value;
    markNeedsLayout();
  }

  WrapAlignment _alignment;
  WrapAlignment get alignment => _alignment;
  set alignment(WrapAlignment value) {
    if (_alignment == value) return;
    _alignment = value;
    markNeedsLayout();
  }

  bool _measureChildren;
  bool get measureChildren => _measureChildren;
  set measureChildren(bool value) {
    if (_measureChildren == value) return;
    _measureChildren = value;
    markNeedsLayout();
  }

  bool get _horizontal => _direction == Axis.horizontal;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! RunStretchWrapParentData) {
      child.parentData = RunStretchWrapParentData();
    }
  }

  List<RenderBox> get _children {
    final List<RenderBox> children = [];
    RenderBox? child = firstChild;
    while (child != null) {
      children.add(child);
      child = childAfter(child);
    }
    return children;
  }

  double _mainOf(Size size) => _horizontal ? size.width : size.height;
  double _crossOf(Size size) => _horizontal ? size.height : size.width;

  /// The natural thickness of [child] at [main] along the runs, or
  /// [fallback] when it isn't measured.
  double _naturalCross(RenderBox child, double main, double fallback) {
    if (!_measureChildren) return fallback;
    final double measured = _horizontal
        ? child.getMaxIntrinsicHeight(main)
        : child.getMaxIntrinsicWidth(main);
    // A child with nothing in it to measure (an empty box that fills the
    // cross axis) keeps the extent it was laid out at.
    return measured.isFinite && measured > 0 ? measured : fallback;
  }

  /// Splits children of extents [mains] into runs that fit [limit].
  List<List<int>> _runs(List<double> mains, double limit) {
    final List<List<int>> runs = [];
    List<int> run = [];
    double extent = 0;
    for (int i = 0; i < mains.length; i++) {
      final double next = run.isEmpty ? mains[i] : extent + _spacing + mains[i];
      if (run.isNotEmpty && next > limit + 1e-6) {
        runs.add(run);
        run = [i];
        extent = mains[i];
      } else {
        run.add(i);
        extent = next;
      }
    }
    if (run.isNotEmpty) runs.add(run);
    return runs;
  }

  /// The size the runs of children of [mains] and thicknesses [crosses]
  /// take in [limit].
  Size _measure(List<double> mains, List<double> crosses, double limit) {
    double main = 0;
    double cross = 0;
    final List<List<int>> runs = _runs(mains, limit);
    for (int r = 0; r < runs.length; r++) {
      final List<int> run = runs[r];
      double runMain = 0;
      double runCross = 0;
      for (int k = 0; k < run.length; k++) {
        runMain += mains[run[k]] + (k > 0 ? _spacing : 0);
        runCross = math.max(runCross, crosses[run[k]]);
      }
      main = math.max(main, runMain);
      cross += runCross + (r > 0 ? _runSpacing : 0);
    }
    return _horizontal ? Size(main, cross) : Size(cross, main);
  }

  BoxConstraints _looseFor(double limit) => _horizontal
      ? BoxConstraints(maxWidth: limit)
      : BoxConstraints(maxHeight: limit);

  @override
  double computeMinIntrinsicWidth(double height) {
    final List<RenderBox> children = _children;
    if (_horizontal) {
      return children.fold(
        0.0,
        (value, child) =>
            math.max(value, child.getMinIntrinsicWidth(double.infinity)),
      );
    }
    return _intrinsicCross(children, height);
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    final List<RenderBox> children = _children;
    if (_horizontal) return _intrinsicMain(children);
    return _intrinsicCross(children, height);
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    final List<RenderBox> children = _children;
    if (!_horizontal) {
      return children.fold(
        0.0,
        (value, child) =>
            math.max(value, child.getMinIntrinsicHeight(double.infinity)),
      );
    }
    return _intrinsicCross(children, width);
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    final List<RenderBox> children = _children;
    if (!_horizontal) return _intrinsicMain(children);
    return _intrinsicCross(children, width);
  }

  /// The extent of all [children] in one run.
  double _intrinsicMain(List<RenderBox> children) {
    double total = 0;
    for (int i = 0; i < children.length; i++) {
      total +=
          (_horizontal
              ? children[i].getMaxIntrinsicWidth(double.infinity)
              : children[i].getMaxIntrinsicHeight(double.infinity)) +
          (i > 0 ? _spacing : 0);
    }
    return total;
  }

  /// The thickness of the runs of [children] in [limit].
  double _intrinsicCross(List<RenderBox> children, double limit) {
    final List<double> mains = [
      for (final RenderBox child in children)
        math.min(
          _horizontal
              ? child.getMaxIntrinsicWidth(double.infinity)
              : child.getMaxIntrinsicHeight(double.infinity),
          limit,
        ),
    ];
    final List<double> crosses = [
      for (int i = 0; i < children.length; i++)
        _horizontal
            ? children[i].getMaxIntrinsicHeight(mains[i])
            : children[i].getMaxIntrinsicWidth(mains[i]),
    ];
    return _crossOf(_measure(mains, crosses, limit));
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final double limit = _horizontal
        ? constraints.maxWidth
        : constraints.maxHeight;
    final List<RenderBox> children = _children;
    final List<double> mains = [];
    final List<double> crosses = [];
    for (final RenderBox child in children) {
      final Size size = child.getDryLayout(_looseFor(limit));
      mains.add(_mainOf(size));
      crosses.add(_naturalCross(child, _mainOf(size), _crossOf(size)));
    }
    return constraints.constrain(_measure(mains, crosses, limit));
  }

  @override
  void performLayout() {
    final BoxConstraints constraints = this.constraints;
    final double limit = _horizontal
        ? constraints.maxWidth
        : constraints.maxHeight;
    final List<RenderBox> children = _children;
    if (children.isEmpty) {
      size = constraints.smallest;
      return;
    }

    final List<double> mains = [];
    final List<double> crosses = [];
    for (final RenderBox child in children) {
      child.layout(_looseFor(limit), parentUsesSize: true);
      final double main = _mainOf(child.size);
      mains.add(main);
      crosses.add(_naturalCross(child, main, _crossOf(child.size)));
    }

    final List<List<int>> runs = _runs(mains, limit);
    final Size measured = _measure(mains, crosses, limit);
    size = constraints.constrain(measured);
    final double containerMain = _mainOf(size);

    double crossOffset = 0;
    for (int r = 0; r < runs.length; r++) {
      final List<int> run = runs[r];
      double runMain = 0;
      double runCross = 0;
      for (int k = 0; k < run.length; k++) {
        runMain += mains[run[k]] + (k > 0 ? _spacing : 0);
        runCross = math.max(runCross, crosses[run[k]]);
      }
      final double free = math.max(0, containerMain - runMain);
      final int count = run.length;
      double leading = 0;
      double between = _spacing;
      switch (_alignment) {
        case WrapAlignment.start:
          break;
        case WrapAlignment.end:
          leading = free;
        case WrapAlignment.center:
          leading = free / 2;
        case WrapAlignment.spaceBetween:
          between += count > 1 ? free / (count - 1) : 0;
        case WrapAlignment.spaceAround:
          leading = free / count / 2;
          between += free / count;
        case WrapAlignment.spaceEvenly:
          leading = free / (count + 1);
          between += free / (count + 1);
      }

      double mainOffset = leading;
      for (final int i in run) {
        final RenderBox child = children[i];
        child.layout(
          _horizontal
              ? BoxConstraints.tightFor(width: mains[i], height: runCross)
              : BoxConstraints.tightFor(width: runCross, height: mains[i]),
          parentUsesSize: true,
        );
        final RunStretchWrapParentData data =
            child.parentData! as RunStretchWrapParentData;
        data.offset = _horizontal
            ? Offset(mainOffset, crossOffset)
            : Offset(crossOffset, mainOffset);
        mainOffset += mains[i] + between;
      }
      crossOffset += runCross + _runSpacing;
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);
}
