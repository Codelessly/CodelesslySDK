import 'dart:math' as math;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Sizes a node on both axes from its [SizeFit]s. This is the one place the
/// runtime decides what a fit means.
///
/// On each axis:
/// - **fill** (a `SizeFit.expanded` node): takes the incoming maximum when it
///   is bounded. When it is unbounded (a scroll view, a non-flex slot of a
///   Row/Column, a shrink-wrapping parent) there is nothing to fill, so the
///   node falls back to its design size ([width]/[height]), the size the
///   editor solved for it. Without a design size it hugs its child.
/// - **sized** (fixed, locked, flexible): exactly [width]/[height], clamped to
///   the incoming constraints.
/// - **hug** (shrinkWrap, [width]/[height] null and not fill): the incoming
///   constraints pass through to the child.
///
/// A `SizedBox(double.infinity)` would throw under an unbounded axis; this
/// box never does, and at the design size it lays out exactly like one.
class FitBox extends SingleChildRenderObjectWidget {
  /// The design width, used when the box is sized, or when it fills and the
  /// incoming width is unbounded.
  final double? width;

  /// The design height, used when the box is sized, or when it fills and the
  /// incoming height is unbounded.
  final double? height;

  /// Whether the box takes all of a bounded incoming width.
  final bool fillWidth;

  /// Whether the box takes all of a bounded incoming height.
  final bool fillHeight;

  /// Width / height to keep, for a node whose aspect ratio is locked: when
  /// the box fills one axis, the other follows it; filling both, it is the
  /// largest box of this ratio that fits. See [lockedAspectRatio].
  final double? aspectRatio;

  const FitBox({
    super.key,
    this.width,
    this.height,
    this.fillWidth = false,
    this.fillHeight = false,
    this.aspectRatio,
    super.child,
  });

  /// A box that follows [horizontalFit] and [verticalFit] with [size] as the
  /// design size: shrinkWrap hugs, expanded fills (design size when the axis
  /// is unbounded), and every other fit takes the design size.
  FitBox.fromFits({
    Key? key,
    required SizeFit? horizontalFit,
    required SizeFit? verticalFit,
    required SizeC size,
    double? aspectRatio,
    Widget? child,
  }) : this(
         key: key,
         width: horizontalFit == SizeFit.shrinkWrap ? null : size.width,
         height: verticalFit == SizeFit.shrinkWrap ? null : size.height,
         fillWidth: horizontalFit == SizeFit.expanded,
         fillHeight: verticalFit == SizeFit.expanded,
         aspectRatio: aspectRatio,
         child: child,
       );

  @override
  RenderFitBox createRenderObject(BuildContext context) => RenderFitBox(
    width: width,
    height: height,
    fillWidth: fillWidth,
    fillHeight: fillHeight,
    aspectRatio: aspectRatio,
  );

  @override
  void updateRenderObject(BuildContext context, RenderFitBox renderObject) {
    renderObject
      ..width = width
      ..height = height
      ..fillWidth = fillWidth
      ..fillHeight = fillHeight
      ..aspectRatio = aspectRatio;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DoubleProperty('width', width, defaultValue: null))
      ..add(DoubleProperty('height', height, defaultValue: null))
      ..add(FlagProperty('fillWidth', value: fillWidth, ifTrue: 'fillWidth'))
      ..add(
        FlagProperty('fillHeight', value: fillHeight, ifTrue: 'fillHeight'),
      );
  }
}

/// The width / height a node keeps at runtime, when its aspect ratio is
/// locked and it fills an axis; null otherwise. See [FitBox.aspectRatio].
double? lockedAspectRatio(BaseNode node) {
  if (!node.aspectRatioLock) return null;
  if (node.horizontalFit != SizeFit.expanded &&
      node.verticalFit != SizeFit.expanded) {
    return null;
  }
  final double width = node.basicBoxLocal.width;
  final double height = node.basicBoxLocal.height;
  if (width <= 0 || height <= 0) return null;
  return width / height;
}

/// The render object of [FitBox].
class RenderFitBox extends RenderProxyBox {
  RenderFitBox({
    this._width,
    this._height,
    this._fillWidth = false,
    this._fillHeight = false,
    this._aspectRatio,
  });

  double? _aspectRatio;
  double? get aspectRatio => _aspectRatio;
  set aspectRatio(double? value) {
    if (_aspectRatio == value) return;
    _aspectRatio = value;
    markNeedsLayout();
  }

  double? _width;
  double? get width => _width;
  set width(double? value) {
    if (_width == value) return;
    _width = value;
    markNeedsLayout();
  }

  double? _height;
  double? get height => _height;
  set height(double? value) {
    if (_height == value) return;
    _height = value;
    markNeedsLayout();
  }

  bool _fillWidth;
  bool get fillWidth => _fillWidth;
  set fillWidth(bool value) {
    if (_fillWidth == value) return;
    _fillWidth = value;
    markNeedsLayout();
  }

  bool _fillHeight;
  bool get fillHeight => _fillHeight;
  set fillHeight(bool value) {
    if (_fillHeight == value) return;
    _fillHeight = value;
    markNeedsLayout();
  }

  /// The extent on one axis, or null when the axis hugs.
  static double? _extent({
    required bool fill,
    required double? design,
    required double max,
  }) {
    if (fill && max.isFinite) return max;
    if (design == null || !design.isFinite) return null;
    return math.max(0, design);
  }

  BoxConstraints _childConstraints(BoxConstraints constraints) {
    double? w = _extent(
      fill: _fillWidth,
      design: _width,
      max: constraints.maxWidth,
    );
    double? h = _extent(
      fill: _fillHeight,
      design: _height,
      max: constraints.maxHeight,
    );
    final double? ratio = _aspectRatio;
    if (ratio != null && ratio > 0 && ratio.isFinite) {
      final bool widthFills = _fillWidth && constraints.hasBoundedWidth;
      final bool heightFills = _fillHeight && constraints.hasBoundedHeight;
      if (widthFills && heightFills && w != null && h != null) {
        if (w / h > ratio) {
          w = h * ratio;
        } else {
          h = w / ratio;
        }
      } else if (widthFills && w != null) {
        h = w / ratio;
      } else if (heightFills && h != null) {
        w = h * ratio;
      }
    }
    return BoxConstraints.tightFor(width: w, height: h).enforce(constraints);
  }

  @override
  void performLayout() {
    final BoxConstraints childConstraints = _childConstraints(constraints);
    final RenderBox? child = this.child;
    if (child == null) {
      size = childConstraints.smallest;
      return;
    }
    child.layout(childConstraints, parentUsesSize: true);
    size = childConstraints.constrain(child.size);
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final BoxConstraints childConstraints = _childConstraints(constraints);
    final RenderBox? child = this.child;
    if (child == null) return childConstraints.smallest;
    return childConstraints.constrain(child.getDryLayout(childConstraints));
  }

  @override
  double? computeDryBaseline(
    covariant BoxConstraints constraints,
    TextBaseline baseline,
  ) => child?.getDryBaseline(_childConstraints(constraints), baseline);

  // A sized axis reports its design size as its max intrinsic, like a
  // SizedBox, and its content's min-content size (at most the design size)
  // as its min intrinsic: the least it can be squeezed to without clipping,
  // which is what a Row/Column shrinking to fit a small screen asks for. A
  // fill or hug axis reports its child's, like SizedBox(double.infinity) or
  // no box.
  double? get _sizedWidth => _fillWidth ? null : _width;
  double? get _sizedHeight => _fillHeight ? null : _height;

  @override
  double computeMinIntrinsicWidth(double height) {
    final double content =
        child?.getMinIntrinsicWidth(_sizedHeight ?? height) ?? 0;
    final double? sized = _sizedWidth;
    return sized == null ? content : math.min(sized, content);
  }

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _sizedWidth ?? child?.getMaxIntrinsicWidth(_sizedHeight ?? height) ?? 0;

  @override
  double computeMinIntrinsicHeight(double width) {
    final double content =
        child?.getMinIntrinsicHeight(_sizedWidth ?? width) ?? 0;
    final double? sized = _sizedHeight;
    return sized == null ? content : math.min(sized, content);
  }

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _sizedHeight ?? child?.getMaxIntrinsicHeight(_sizedWidth ?? width) ?? 0;
}

/// A [Flex] (Row or Column) for node trees, which follows the editor where
/// Flutter's [RenderFlex] would fail:
///
/// - **Unbounded main axis.** When the incoming main axis is unbounded (a
///   scroll view, a non-flex slot of another Flex) there is no free space to
///   share, so `Expanded`/`Flexible` children are laid out like the others, at
///   their own size. That is what a release build of Flutter already does; a
///   debug build throws "RenderFlex children have non-zero flex but incoming
///   constraints are unbounded" instead. An expanded child's [FitBox] then
///   takes its design size, as the editor gives it.
/// - **Not enough room.** The editor never lets a Row/Column get smaller
///   than its fixed content, but a runtime screen can be narrower than the
///   design. When the children don't fit a bounded main axis, the non-flex
///   children give up room in proportion to how far each can shrink, down to
///   its min-content size (like CSS `flex-shrink` with `min-width: auto`),
///   so boxes squeeze and text wraps instead of running offscreen. Text never
///   goes below its lines; content that can't fit even then overflows.
///
/// - **Spacing skips collapsed children.** [spacing] goes only between
///   consecutive children that are shown, like CSS `gap` or Figma auto
///   layout, so a column of alternative panels of which one shows has no
///   stray gaps. A child is collapsed when it is wrapped in a
///   [FlexChildVisibility] that says so, as a row/column's children are
///   while a visibility formula hides them. Collapsed children still take
///   part in the alignment's free-space distribution, at their (zero) size,
///   as in [RenderFlex].
///
/// When everything fits and every child shows, as at the design size, the
/// layout is exactly [RenderFlex]'s.
class CodelesslyFlex extends Flex {
  const CodelesslyFlex({
    super.key,
    required super.direction,
    super.mainAxisAlignment,
    super.mainAxisSize,
    super.crossAxisAlignment,
    super.textDirection,
    super.verticalDirection,
    super.textBaseline,
    super.clipBehavior,
    super.spacing,
    this.squeeze = true,
    super.children,
  });

  /// Whether children that overflow a bounded main axis squeeze (see
  /// above). The design canvas turns it off: there children keep the sizes
  /// the layout solver gave them and overflow, as in [RenderFlex].
  final bool squeeze;

  @override
  RenderCodelesslyFlex createRenderObject(BuildContext context) =>
      RenderCodelesslyFlex(
        direction: direction,
        mainAxisAlignment: mainAxisAlignment,
        mainAxisSize: mainAxisSize,
        crossAxisAlignment: crossAxisAlignment,
        textDirection: getEffectiveTextDirection(context),
        verticalDirection: verticalDirection,
        textBaseline: textBaseline,
        clipBehavior: clipBehavior,
        spacing: spacing,
        squeeze: squeeze,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderCodelesslyFlex renderObject,
  ) {
    super.updateRenderObject(context, renderObject);
    renderObject.squeeze = squeeze;
  }
}

/// Parent data of a [CodelesslyFlex] child.
class CodelesslyFlexParentData extends FlexParentData {
  /// Whether the child is collapsed (hidden and taking no space), so it
  /// gets no [CodelesslyFlex.spacing] on either side.
  bool collapsed = false;

  @override
  String toString() => '${super.toString()}; collapsed=$collapsed';
}

/// Tells a [CodelesslyFlex] whether its [child] is [collapsed]: hidden at
/// runtime and taking no space, so the flex leaves no gap next to it.
///
/// A widget that hides itself deep in its subtree can't tell its flex: its
/// box is still there, at zero size. The row/column that builds the child
/// knows why it is hidden and wraps it in this. A zero-size box alone does
/// not mean hidden: an empty text or a zero-width divider still gets its
/// gaps, as in CSS.
class FlexChildVisibility extends ParentDataWidget<CodelesslyFlexParentData> {
  const FlexChildVisibility({
    super.key,
    required this.collapsed,
    required super.child,
  });

  /// Whether [child] is hidden and takes no space.
  final bool collapsed;

  @override
  void applyParentData(RenderObject renderObject) {
    final CodelesslyFlexParentData data =
        renderObject.parentData! as CodelesslyFlexParentData;
    if (data.collapsed == collapsed) return;
    data.collapsed = collapsed;
    final RenderObject? parent = renderObject.parent;
    if (parent is RenderObject) parent.markNeedsLayout();
  }

  @override
  Type get debugTypicalAncestorWidgetClass => CodelesslyFlex;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
      FlagProperty('collapsed', value: collapsed, ifTrue: 'collapsed'),
    );
  }
}

/// The render object of [CodelesslyFlex].
///
/// The gaps are laid out here rather than by [RenderFlex], which puts one
/// between every pair of children: [RenderFlex] runs with no spacing and
/// with the main axis shortened by the gaps between the shown children
/// ([_gaps]), so flex children share what is left after the gaps as they
/// do in Flutter. The children are then moved along by the gaps before
/// them, and the flex grows by the gaps. Free space, alignment and
/// overflow come out as [RenderFlex] computes them with spacing.
class RenderCodelesslyFlex extends RenderFlex {
  RenderCodelesslyFlex({
    super.direction,
    super.mainAxisAlignment,
    super.mainAxisSize,
    super.crossAxisAlignment,
    super.textDirection,
    super.verticalDirection,
    super.textBaseline,
    super.clipBehavior,
    double spacing = 0,
    this._squeeze = true,
  }) : _gap = spacing,
       assert(spacing >= 0);

  /// The gap between consecutive shown children (the widget's
  /// [Flex.spacing]).
  double get gap => _gap;
  double _gap;
  set gap(double value) {
    assert(value >= 0);
    if (_gap == value) return;
    _gap = value;
    markNeedsLayout();
  }

  /// [RenderFlex] lays out without spacing; this flex's [gap] is the
  /// spacing, set by [Flex.updateRenderObject] through this setter.
  @override
  double get spacing => 0;

  @override
  set spacing(double value) => gap = value;

  /// See [CodelesslyFlex.squeeze].
  bool get squeeze => _squeeze;
  bool _squeeze;
  set squeeze(bool value) {
    if (_squeeze == value) return;
    _squeeze = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! CodelesslyFlexParentData) {
      child.parentData = CodelesslyFlexParentData();
    }
  }

  static bool _collapsed(RenderBox child) {
    final ParentData? data = child.parentData;
    return data is CodelesslyFlexParentData && data.collapsed;
  }

  /// The space the gaps take on the main axis: [gap] between each pair of
  /// consecutive shown children.
  double get _gaps {
    if (_gap <= 0) return 0;
    int shown = 0;
    RenderBox? child = firstChild;
    while (child != null) {
      if (!_collapsed(child)) shown++;
      child = childAfter(child);
    }
    return _gap * math.max(0, shown - 1);
  }

  /// [constraints] while [RenderFlex] lays out: the main axis shortened by
  /// the gaps.
  BoxConstraints? _innerConstraints;

  @override
  BoxConstraints get constraints => _innerConstraints ?? super.constraints;

  BoxConstraints _withoutGaps(BoxConstraints constraints, double gaps) {
    double shorten(double extent) => math.max(0, extent - gaps);
    return direction == Axis.horizontal
        ? constraints.copyWith(
            minWidth: shorten(constraints.minWidth),
            maxWidth: shorten(constraints.maxWidth),
          )
        : constraints.copyWith(
            minHeight: shorten(constraints.minHeight),
            maxHeight: shorten(constraints.maxHeight),
          );
  }

  Size _withGaps(Size size, double gaps) => direction == Axis.horizontal
      ? Size(size.width + gaps, size.height)
      : Size(size.width, size.height + gaps);

  /// Whether children are placed right to left or bottom to top, as
  /// [RenderFlex] decides it.
  bool get _flipMainAxis => switch (direction) {
    Axis.horizontal => textDirection == TextDirection.rtl,
    Axis.vertical => verticalDirection == VerticalDirection.up,
  };

  /// [RenderFlex]'s layout, with [gap] between consecutive shown children.
  void _layOutWithGaps() {
    final double gaps = _gaps;
    if (gaps <= 0) {
      super.performLayout();
      return;
    }
    final BoxConstraints outer = constraints;
    _innerConstraints = _withoutGaps(outer, gaps);
    try {
      super.performLayout();
    } finally {
      _innerConstraints = null;
    }
    size = outer.constrain(_withGaps(size, gaps));

    // Each child moves along by the gaps before it in visual order: one per
    // shown child before it.
    final bool flip = _flipMainAxis;
    int shownBefore = 0;
    RenderBox? child = flip ? lastChild : firstChild;
    while (child != null) {
      final FlexParentData data = child.parentData! as FlexParentData;
      final double shift = _gap * shownBefore;
      if (shift != 0) {
        data.offset += direction == Axis.horizontal
            ? Offset(shift, 0)
            : Offset(0, shift);
      }
      if (!_collapsed(child)) shownBefore++;
      child = flip ? data.previousSibling : data.nextSibling;
    }
  }

  bool _mainAxisBounded(BoxConstraints constraints) =>
      direction == Axis.horizontal
      ? constraints.hasBoundedWidth
      : constraints.hasBoundedHeight;

  double _mainExtent(Size size) =>
      direction == Axis.horizontal ? size.width : size.height;

  /// Runs [body] with the children's flex factors and fits replaced by
  /// [replace], then restores them, so the widgets' parent data stays the
  /// source of truth for the next layout.
  T _withFlex<T>(
    (int?, FlexFit?) Function(RenderBox child, FlexParentData data) replace,
    T Function() body,
  ) {
    final List<(FlexParentData, int?, FlexFit?)> saved = [];
    RenderBox? child = firstChild;
    while (child != null) {
      final FlexParentData data = child.parentData! as FlexParentData;
      saved.add((data, data.flex, data.fit));
      final (int? flex, FlexFit? fit) = replace(child, data);
      data
        ..flex = flex
        ..fit = fit;
      child = data.nextSibling;
    }
    try {
      return body();
    } finally {
      for (final (FlexParentData data, int? flex, FlexFit? fit) in saved) {
        data
          ..flex = flex
          ..fit = fit;
      }
    }
  }

  T _inflexible<T>(T Function() body) =>
      _withFlex((child, data) => (0, data.fit), body);

  bool get _hasFlexChild {
    RenderBox? child = firstChild;
    while (child != null) {
      final FlexParentData data = child.parentData! as FlexParentData;
      if ((data.flex ?? 0) > 0) return true;
      child = data.nextSibling;
    }
    return false;
  }

  @override
  void performLayout() {
    if (!_mainAxisBounded(constraints)) {
      if (_hasFlexChild) {
        _inflexible(_layOutWithGaps);
      } else {
        _layOutWithGaps();
      }
      return;
    }

    _layOutWithGaps();
    if (!_squeeze) return;

    // Shrink pass: only when the children overflow a bounded main axis.
    final double available = _mainExtent(size) - _gaps;
    double used = 0;
    double capacity = 0;
    final Map<RenderBox, (double, double)> extents = {};
    RenderBox? child = firstChild;
    while (child != null) {
      final FlexParentData data = child.parentData! as FlexParentData;
      final double natural = _mainExtent(child.size);
      used += natural;
      if ((data.flex ?? 0) <= 0) {
        final double floor = math.min(natural, _minContent(child));
        extents[child] = (natural, floor);
        capacity += natural - floor;
      }
      child = data.nextSibling;
    }
    final double overflow = used - available;
    if (overflow <= precisionErrorTolerance) return;
    // Content that can't fit even at its minimum stays at its natural size
    // and overflows visibly, rather than clipping lines of text.
    if (overflow > capacity) return;

    // Each child gives up a share of the overflow in proportion to how far
    // it can shrink, so none goes below its min-content size. Flex factors
    // are integers, so the target sizes become weights in 1/[_resolution] px.
    _withFlex((child, data) {
      // A flex child already got no room; it keeps a token weight so it is
      // still laid out with a bounded main axis.
      if ((data.flex ?? 0) > 0) return (1, FlexFit.tight);
      final (double natural, double floor) = extents[child]!;
      final double target = natural - (natural - floor) * overflow / capacity;
      final int weight = (target * _resolution).round();
      if (weight <= 0) return (0, data.fit);
      return (weight, FlexFit.loose);
    }, _layOutWithGaps);
  }

  /// Shrink weights are main extents in 1/[_resolution] px.
  static const double _resolution = 1e6;

  /// Room kept above each child's min-content size, so that rounding and
  /// the flex children's token weights never push a text below its lines.
  static const double _floorSlack = 1e-3;

  /// The least main extent [child] takes without clipping its content (its
  /// CSS min-content size), probed the way Flutter's own constraint checks
  /// do, so subtrees that can't report intrinsics (layout builders,
  /// viewports) report zero instead of throwing.
  double _minContent(RenderBox child) {
    final bool wasChecking = RenderObject.debugCheckingIntrinsics;
    RenderObject.debugCheckingIntrinsics = true;
    try {
      final double value = direction == Axis.horizontal
          ? child.getMinIntrinsicWidth(double.infinity)
          : child.getMinIntrinsicHeight(child.size.width);
      if (!value.isFinite || value <= 0) return 0;
      return value + _floorSlack;
    } finally {
      RenderObject.debugCheckingIntrinsics = wasChecking;
    }
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    Size dryLayout() {
      final double gaps = _gaps;
      if (gaps <= 0) return super.computeDryLayout(constraints);
      final Size inner = super.computeDryLayout(
        _withoutGaps(constraints, gaps),
      );
      return constraints.constrain(_withGaps(inner, gaps));
    }

    if (!_mainAxisBounded(constraints) && _hasFlexChild) {
      return _inflexible(dryLayout);
    }
    return dryLayout();
  }

  @override
  double? computeDryBaseline(
    covariant BoxConstraints constraints,
    TextBaseline baseline,
  ) {
    double? dryBaseline() {
      final double gaps = _gaps;
      if (gaps <= 0) return super.computeDryBaseline(constraints, baseline);
      final double? inner = super.computeDryBaseline(
        _withoutGaps(constraints, gaps),
        baseline,
      );
      // A row's baseline is on its cross axis, which the gaps don't move. A
      // column's is its first child's: no gaps come before the first shown
      // child, or all of them do when the column runs bottom to top.
      if (inner == null || direction == Axis.horizontal) return inner;
      return _flipMainAxis ? inner + gaps : inner;
    }

    if (!_mainAxisBounded(constraints) && _hasFlexChild) {
      return _inflexible(dryBaseline);
    }
    return dryBaseline();
  }

  // Intrinsic sizes: the gaps add to the main axis, and come out of the
  // main extent the flex children share when the cross size is measured.

  double _mainIntrinsic(double Function() measure) => measure() + _gaps;

  double _crossExtent(double extent) =>
      extent.isFinite ? math.max(0, extent - _gaps) : extent;

  @override
  double computeMinIntrinsicWidth(double height) => direction == Axis.horizontal
      ? _mainIntrinsic(() => super.computeMinIntrinsicWidth(height))
      : super.computeMinIntrinsicWidth(_crossExtent(height));

  @override
  double computeMaxIntrinsicWidth(double height) => direction == Axis.horizontal
      ? _mainIntrinsic(() => super.computeMaxIntrinsicWidth(height))
      : super.computeMaxIntrinsicWidth(_crossExtent(height));

  @override
  double computeMinIntrinsicHeight(double width) => direction == Axis.vertical
      ? _mainIntrinsic(() => super.computeMinIntrinsicHeight(width))
      : super.computeMinIntrinsicHeight(_crossExtent(width));

  @override
  double computeMaxIntrinsicHeight(double width) => direction == Axis.vertical
      ? _mainIntrinsic(() => super.computeMaxIntrinsicHeight(width))
      : super.computeMaxIntrinsicHeight(_crossExtent(width));

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DoubleProperty('gap', gap, defaultValue: 0))
      ..add(FlagProperty('squeeze', value: squeeze, ifFalse: 'no squeeze'));
  }
}

/// The content of a scroll view whose main axis must be at least
/// [viewportExtent] long. The child is laid out once with the scroll view's
/// unbounded main axis to find its natural length. When that is shorter than
/// the viewport it is laid out again with exactly the viewport's length, so:
///
/// - main-axis alignment (center, end, space*) spreads the children while
///   they fit, and scrolls once they don't;
/// - `Expanded`/`Flexible` children (and flex spacers) share the room left in
///   the viewport. Once the content is longer than the viewport they take
///   their design size and the content scrolls.
///
/// This is the editor's rule for a scrolling Row/Column: its Flex gets the
/// main extent `max(viewport, content)`.
class ScrollContentExtent extends SingleChildRenderObjectWidget {
  /// The scroll axis.
  final Axis axis;

  /// The viewport's main-axis length, minus the scroll view's padding.
  final double viewportExtent;

  const ScrollContentExtent({
    super.key,
    required this.axis,
    required this.viewportExtent,
    super.child,
  });

  @override
  RenderScrollContentExtent createRenderObject(BuildContext context) =>
      RenderScrollContentExtent(axis: axis, viewportExtent: viewportExtent);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderScrollContentExtent renderObject,
  ) {
    renderObject
      ..axis = axis
      ..viewportExtent = viewportExtent;
  }
}

/// The render object of [ScrollContentExtent].
class RenderScrollContentExtent extends RenderProxyBox {
  RenderScrollContentExtent({
    required this._axis,
    required this._viewportExtent,
  });

  Axis _axis;
  Axis get axis => _axis;
  set axis(Axis value) {
    if (_axis == value) return;
    _axis = value;
    markNeedsLayout();
  }

  double _viewportExtent;
  double get viewportExtent => _viewportExtent;
  set viewportExtent(double value) {
    if (_viewportExtent == value) return;
    _viewportExtent = value;
    markNeedsLayout();
  }

  BoxConstraints _fill(BoxConstraints constraints, Size natural) {
    final double natExtent = _axis == Axis.vertical
        ? natural.height
        : natural.width;
    if (!_viewportExtent.isFinite || natExtent >= _viewportExtent) {
      return constraints;
    }
    return _axis == Axis.vertical
        ? constraints.tighten(height: _viewportExtent)
        : constraints.tighten(width: _viewportExtent);
  }

  @override
  void performLayout() {
    final RenderBox? child = this.child;
    if (child == null) {
      size = constraints.constrain(
        _axis == Axis.vertical
            ? Size(0, _viewportExtent.isFinite ? _viewportExtent : 0)
            : Size(_viewportExtent.isFinite ? _viewportExtent : 0, 0),
      );
      return;
    }
    child.layout(constraints, parentUsesSize: true);
    final BoxConstraints filled = _fill(constraints, child.size);
    if (filled != constraints) child.layout(filled, parentUsesSize: true);
    size = constraints.constrain(child.size);
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final RenderBox? child = this.child;
    if (child == null) return constraints.smallest;
    final Size natural = child.getDryLayout(constraints);
    final BoxConstraints filled = _fill(constraints, natural);
    if (filled == constraints) return natural;
    return constraints.constrain(child.getDryLayout(filled));
  }
}
