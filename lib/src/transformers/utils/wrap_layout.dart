import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'fit_layout.dart';

/// A [Wrap] for wrapping row/column nodes (`RowColumnMixin.wrap`).
///
/// It lays its children out like Flutter's [Wrap]: along [direction] until
/// the next child does not fit the incoming main-axis maximum, then on a new
/// run, with [spacing] between children of a run and [runSpacing] between
/// runs. [alignment] places children within each run, [crossAxisAlignment]
/// places them within their run's thickness and [runAlignment] places the
/// runs in the free cross-axis space. Like [Wrap], it is as long as its
/// longest run and as thick as its runs, within the incoming constraints.
///
/// Unlike [Wrap], children that are collapsed (wrapped in a
/// [FlexChildVisibility] that says so, as a row/column's children are while
/// a visibility formula hides them) take no part in the layout: they get no
/// gaps and start no run, like CSS `gap` and Figma auto layout, and as
/// [CodelesslyFlex] does for a row/column that does not wrap.
///
/// Children are given the incoming main-axis maximum and an unbounded cross
/// axis, as in [Wrap]: none of them can be flexible.
class CodelesslyWrap extends MultiChildRenderObjectWidget {
  const CodelesslyWrap({
    super.key,
    this.direction = Axis.horizontal,
    this.alignment = WrapAlignment.start,
    this.spacing = 0,
    this.runAlignment = WrapAlignment.start,
    this.runSpacing = 0,
    this.crossAxisAlignment = WrapCrossAlignment.start,
    this.textDirection,
    this.verticalDirection = VerticalDirection.down,
    this.clipBehavior = Clip.none,
    super.children,
  });

  /// See [Wrap.direction].
  final Axis direction;

  /// See [Wrap.alignment].
  final WrapAlignment alignment;

  /// The gap between consecutive shown children of a run.
  final double spacing;

  /// See [Wrap.runAlignment].
  final WrapAlignment runAlignment;

  /// The gap between consecutive runs.
  final double runSpacing;

  /// See [Wrap.crossAxisAlignment].
  final WrapCrossAlignment crossAxisAlignment;

  /// See [Wrap.textDirection].
  final TextDirection? textDirection;

  /// See [Wrap.verticalDirection].
  final VerticalDirection verticalDirection;

  /// See [Wrap.clipBehavior].
  final Clip clipBehavior;

  @override
  RenderCodelesslyWrap createRenderObject(BuildContext context) =>
      RenderCodelesslyWrap(
        direction: direction,
        alignment: alignment,
        spacing: spacing,
        runAlignment: runAlignment,
        runSpacing: runSpacing,
        crossAxisAlignment: crossAxisAlignment,
        textDirection: textDirection ?? Directionality.maybeOf(context),
        verticalDirection: verticalDirection,
        clipBehavior: clipBehavior,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderCodelesslyWrap renderObject,
  ) {
    renderObject
      ..direction = direction
      ..alignment = alignment
      ..spacing = spacing
      ..runAlignment = runAlignment
      ..runSpacing = runSpacing
      ..crossAxisAlignment = crossAxisAlignment
      ..textDirection = textDirection ?? Directionality.maybeOf(context)
      ..verticalDirection = verticalDirection
      ..clipBehavior = clipBehavior;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(EnumProperty<Axis>('direction', direction))
      ..add(EnumProperty<WrapAlignment>('alignment', alignment))
      ..add(DoubleProperty('spacing', spacing))
      ..add(EnumProperty<WrapAlignment>('runAlignment', runAlignment))
      ..add(DoubleProperty('runSpacing', runSpacing))
      ..add(
        EnumProperty<WrapCrossAlignment>(
          'crossAxisAlignment',
          crossAxisAlignment,
        ),
      );
  }
}

/// One run of a [RenderCodelesslyWrap]: the indices of its shown children
/// in child order, its length and its thickness.
class _Run {
  final List<int> children = <int>[];
  double mainExtent = 0;
  double crossExtent = 0;
}

/// The result of laying out a [RenderCodelesslyWrap] for some constraints.
class _WrapResult {
  _WrapResult(this.size, this.offsets);

  final Size size;

  /// The offset of each child, in child order. Collapsed children are at
  /// the origin.
  final List<Offset> offsets;
}

/// The render object of [CodelesslyWrap].
class RenderCodelesslyWrap extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, CodelesslyFlexParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, CodelesslyFlexParentData> {
  RenderCodelesslyWrap({
    this._direction = Axis.horizontal,
    this._alignment = WrapAlignment.start,
    this._spacing = 0,
    this._runAlignment = WrapAlignment.start,
    this._runSpacing = 0,
    this._crossAxisAlignment = WrapCrossAlignment.start,
    this._textDirection,
    this._verticalDirection = VerticalDirection.down,
    this._clipBehavior = Clip.none,
  });

  Axis get direction => _direction;
  Axis _direction;
  set direction(Axis value) {
    if (_direction == value) return;
    _direction = value;
    markNeedsLayout();
  }

  WrapAlignment get alignment => _alignment;
  WrapAlignment _alignment;
  set alignment(WrapAlignment value) {
    if (_alignment == value) return;
    _alignment = value;
    markNeedsLayout();
  }

  double get spacing => _spacing;
  double _spacing;
  set spacing(double value) {
    if (_spacing == value) return;
    _spacing = value;
    markNeedsLayout();
  }

  WrapAlignment get runAlignment => _runAlignment;
  WrapAlignment _runAlignment;
  set runAlignment(WrapAlignment value) {
    if (_runAlignment == value) return;
    _runAlignment = value;
    markNeedsLayout();
  }

  double get runSpacing => _runSpacing;
  double _runSpacing;
  set runSpacing(double value) {
    if (_runSpacing == value) return;
    _runSpacing = value;
    markNeedsLayout();
  }

  WrapCrossAlignment get crossAxisAlignment => _crossAxisAlignment;
  WrapCrossAlignment _crossAxisAlignment;
  set crossAxisAlignment(WrapCrossAlignment value) {
    if (_crossAxisAlignment == value) return;
    _crossAxisAlignment = value;
    markNeedsLayout();
  }

  TextDirection? get textDirection => _textDirection;
  TextDirection? _textDirection;
  set textDirection(TextDirection? value) {
    if (_textDirection == value) return;
    _textDirection = value;
    markNeedsLayout();
  }

  VerticalDirection get verticalDirection => _verticalDirection;
  VerticalDirection _verticalDirection;
  set verticalDirection(VerticalDirection value) {
    if (_verticalDirection == value) return;
    _verticalDirection = value;
    markNeedsLayout();
  }

  Clip get clipBehavior => _clipBehavior;
  Clip _clipBehavior;
  set clipBehavior(Clip value) {
    if (_clipBehavior == value) return;
    _clipBehavior = value;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  bool get _isHorizontal => _direction == Axis.horizontal;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! CodelesslyFlexParentData) {
      child.parentData = CodelesslyFlexParentData();
    }
  }

  static bool _collapsed(RenderBox child) =>
      (child.parentData! as CodelesslyFlexParentData).collapsed;

  List<RenderBox> get _children {
    final List<RenderBox> result = <RenderBox>[];
    RenderBox? child = firstChild;
    while (child != null) {
      result.add(child);
      child = childAfter(child);
    }
    return result;
  }

  double _main(Size size) => _isHorizontal ? size.width : size.height;

  double _cross(Size size) => _isHorizontal ? size.height : size.width;

  BoxConstraints _childConstraints(double mainLimit) => _isHorizontal
      ? BoxConstraints(maxWidth: mainLimit)
      : BoxConstraints(maxHeight: mainLimit);

  /// Breaks the children of [sizes] (null for collapsed ones) into runs no
  /// longer than [mainLimit].
  List<_Run> _runs(List<Size?> sizes, double mainLimit) {
    final List<_Run> runs = <_Run>[];
    _Run? run;
    for (int i = 0; i < sizes.length; i++) {
      final Size? size = sizes[i];
      if (size == null) continue;
      final double main = _main(size);
      if (run != null &&
          run.children.isNotEmpty &&
          run.mainExtent + _spacing + main >
              mainLimit + precisionErrorTolerance) {
        run = null;
      }
      if (run == null) {
        run = _Run();
        runs.add(run);
      } else {
        run.mainExtent += _spacing;
      }
      run.children.add(i);
      run.mainExtent += main;
      run.crossExtent = math.max(run.crossExtent, _cross(size));
    }
    return runs;
  }

  /// The leading space and the space between items for [alignment] with
  /// [free] space and [count] items.
  static (double, double) _distribute(
    WrapAlignment alignment,
    double free,
    int count,
  ) => switch (alignment) {
    WrapAlignment.start => (0, 0),
    WrapAlignment.end => (free, 0),
    WrapAlignment.center => (free / 2, 0),
    WrapAlignment.spaceBetween => (0, count > 1 ? free / (count - 1) : 0),
    WrapAlignment.spaceAround => (free / count / 2, free / count),
    WrapAlignment.spaceEvenly => (free / (count + 1), free / (count + 1)),
  };

  _WrapResult _layout(
    BoxConstraints constraints,
    Size Function(RenderBox child, BoxConstraints constraints) layoutChild, {
    bool computeOffsets = true,
  }) {
    final List<RenderBox> children = _children;
    final double mainLimit = _isHorizontal
        ? constraints.maxWidth
        : constraints.maxHeight;
    final BoxConstraints childConstraints = _childConstraints(mainLimit);
    // Collapsed children are laid out too, so they have a size, but take no
    // part in the runs.
    final List<Size?> sizes = <Size?>[
      for (final RenderBox child in children)
        if (layoutChild(child, childConstraints) case final Size size)
          _collapsed(child) ? null : size,
    ];
    final List<_Run> runs = _runs(sizes, mainLimit);

    double longest = 0;
    double thickness = 0;
    for (int r = 0; r < runs.length; r++) {
      longest = math.max(longest, runs[r].mainExtent);
      thickness += runs[r].crossExtent + (r > 0 ? _runSpacing : 0);
    }
    final Size size = constraints.constrain(
      _isHorizontal ? Size(longest, thickness) : Size(thickness, longest),
    );
    final List<Offset> offsets = List<Offset>.filled(
      children.length,
      Offset.zero,
    );
    if (!computeOffsets || runs.isEmpty) return _WrapResult(size, offsets);

    final double containerMain = _main(size);
    final double containerCross = _cross(size);
    final bool flipMain = _isHorizontal
        ? _textDirection == TextDirection.rtl
        : _verticalDirection == VerticalDirection.up;
    final bool flipCross = _isHorizontal
        ? _verticalDirection == VerticalDirection.up
        : _textDirection == TextDirection.rtl;

    final (double runLeading, double runBetween) = _distribute(
      _runAlignment,
      math.max(0, containerCross - thickness),
      runs.length,
    );
    double crossOffset = runLeading;
    for (final _Run run in runs) {
      final (double leading, double between) = _distribute(
        _alignment,
        math.max(0, containerMain - run.mainExtent),
        run.children.length,
      );
      double mainOffset = leading;
      for (final int i in run.children) {
        final Size childSize = sizes[i]!;
        final double childMain = _main(childSize);
        final double childCross = _cross(childSize);
        final double free = run.crossExtent - childCross;
        final double inRun = switch (_crossAxisAlignment) {
          WrapCrossAlignment.start => 0,
          WrapCrossAlignment.end => free,
          WrapCrossAlignment.center => free / 2,
        };
        double main = mainOffset;
        double cross = crossOffset + inRun;
        if (flipMain) main = containerMain - main - childMain;
        if (flipCross) cross = containerCross - cross - childCross;
        offsets[i] = _isHorizontal ? Offset(main, cross) : Offset(cross, main);
        mainOffset += childMain + _spacing + between;
      }
      crossOffset += run.crossExtent + _runSpacing + runBetween;
    }
    return _WrapResult(size, offsets);
  }

  bool _hasOverflow = false;

  @override
  void performLayout() {
    final _WrapResult result = _layout(constraints, (child, constraints) {
      child.layout(constraints, parentUsesSize: true);
      return child.size;
    });
    size = result.size;
    final List<RenderBox> children = _children;
    double contentMain = 0;
    double contentCross = 0;
    for (int i = 0; i < children.length; i++) {
      final RenderBox child = children[i];
      final BoxParentData data = child.parentData! as BoxParentData;
      data.offset = result.offsets[i];
      contentMain = math.max(
        contentMain,
        _main(Size(data.offset.dx, data.offset.dy)) + _main(child.size),
      );
      contentCross = math.max(
        contentCross,
        _cross(Size(data.offset.dx, data.offset.dy)) + _cross(child.size),
      );
    }
    _hasOverflow =
        contentMain > _main(size) + precisionErrorTolerance ||
        contentCross > _cross(size) + precisionErrorTolerance;
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) => _layout(
    constraints,
    (child, constraints) => child.getDryLayout(constraints),
    computeOffsets: false,
  ).size;

  /// The thickness of the runs for a main-axis extent of [mainExtent], from
  /// the children's max intrinsic sizes (as [RenderWrap] does).
  double _thicknessFor(double mainExtent) {
    final List<Size?> sizes = <Size?>[
      for (final RenderBox child in _children)
        if (_collapsed(child)) null else _intrinsicSize(child, mainExtent),
    ];
    final List<_Run> runs = _runs(sizes, mainExtent);
    double thickness = 0;
    for (int r = 0; r < runs.length; r++) {
      thickness += runs[r].crossExtent + (r > 0 ? _runSpacing : 0);
    }
    return thickness;
  }

  Size _intrinsicSize(RenderBox child, double mainExtent) {
    if (_isHorizontal) {
      final double width = math.min(
        child.getMaxIntrinsicWidth(double.infinity),
        mainExtent,
      );
      return Size(width, child.getMaxIntrinsicHeight(width));
    }
    final double height = math.min(
      child.getMaxIntrinsicHeight(double.infinity),
      mainExtent,
    );
    return Size(child.getMaxIntrinsicWidth(height), height);
  }

  double _minMain() {
    double result = 0;
    for (final RenderBox child in _children) {
      if (_collapsed(child)) continue;
      result = math.max(
        result,
        _isHorizontal
            ? child.getMinIntrinsicWidth(double.infinity)
            : child.getMinIntrinsicHeight(double.infinity),
      );
    }
    return result;
  }

  double _maxMain() {
    double result = 0;
    int shown = 0;
    for (final RenderBox child in _children) {
      if (_collapsed(child)) continue;
      result += _isHorizontal
          ? child.getMaxIntrinsicWidth(double.infinity)
          : child.getMaxIntrinsicHeight(double.infinity);
      shown++;
    }
    return result + (shown > 1 ? _spacing * (shown - 1) : 0);
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      _isHorizontal ? _minMain() : _thicknessFor(height);

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _isHorizontal ? _maxMain() : _thicknessFor(height);

  @override
  double computeMinIntrinsicHeight(double width) =>
      _isHorizontal ? _thicknessFor(width) : _minMain();

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _isHorizontal ? _thicknessFor(width) : _maxMain();

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      defaultComputeDistanceToHighestActualBaseline(baseline);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  final LayerHandle<ClipRectLayer> _clipRectLayer =
      LayerHandle<ClipRectLayer>();

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_hasOverflow && _clipBehavior != Clip.none) {
      _clipRectLayer.layer = context.pushClipRect(
        needsCompositing,
        offset,
        Offset.zero & size,
        defaultPaint,
        clipBehavior: _clipBehavior,
        oldLayer: _clipRectLayer.layer,
      );
    } else {
      _clipRectLayer.layer = null;
      defaultPaint(context, offset);
    }
  }

  @override
  void dispose() {
    _clipRectLayer.layer = null;
    super.dispose();
  }
}
