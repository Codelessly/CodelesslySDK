// Layout render objects: the fit-box semantics every layout is built with.
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';


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

  /// A share of the room on each axis (`Layout.widthFactor`/`heightFactor`).
  double? _widthFactor, _heightFactor;
  set widthFactor(double? v) {
    if (v == _widthFactor) return;
    _widthFactor = v;
    markNeedsLayout();
  }

  set heightFactor(double? v) {
    if (v == _heightFactor) return;
    _heightFactor = v;
    markNeedsLayout();
  }

  /// While set, this box, filling this axis under no bound, takes its
  /// content's extent, as a CSS `height: 100%` against an indefinite
  /// height computes to `auto`, instead of its design size: a grid
  /// measuring the items of a row that shrink-wraps (CSS grid's auto rows)
  /// sets it on each item's own box for that measuring layout only.
  Axis? measureContentAlong;

  /// The extent on one axis, or null when the axis hugs.
  static double? _extent({
    required bool fill,
    required double? design,
    required double max,
    double? factor,
    bool contentWhenUnbounded = false,
  }) {
    if (factor != null && max.isFinite) return math.max(0, max * factor);
    if (fill && max.isFinite) return max;
    if (fill && contentWhenUnbounded) return null;
    if (design == null || !design.isFinite) return null;
    return math.max(0, design);
  }

  BoxConstraints _childConstraints(BoxConstraints constraints) {
    final double? w = _extent(
      fill: _fillWidth,
      design: _width,
      max: constraints.maxWidth,
      factor: _widthFactor,
      contentWhenUnbounded: measureContentAlong == Axis.horizontal,
    );
    final double? h = _extent(
      fill: _fillHeight,
      design: _height,
      max: constraints.maxHeight,
      factor: _heightFactor,
      contentWhenUnbounded: measureContentAlong == Axis.vertical,
    );
    final double? ratio = _aspectRatio;
    if (ratio != null && ratio.isFinite && ratio > 0) {
      final Size? kept = keepAspectRatio(w, h, ratio, constraints, (
        fillWidth: _fillWidth,
        fillHeight: _fillHeight,
      ));
      if (kept != null) return BoxConstraints.tight(kept);
    }
    return BoxConstraints.tightFor(width: w, height: h).enforce(constraints);
  }

  /// The size a box of [ratio] (width / height) takes from its preferred
  /// width [w] and height [h] (null where it hugs) within [constraints].
  /// The width leads unless it hugs or only the height fills. Null when
  /// both axes hug.
  @visibleForTesting
  static Size? keepAspectRatio(
    double? w,
    double? h,
    double ratio,
    BoxConstraints constraints,
    ({bool fillWidth, bool fillHeight}) fills,
  ) {
    final bool heightLeads =
        h != null && (w == null || (fills.fillHeight && !fills.fillWidth));
    if (!heightLeads && w != null) {
      double width = constraints.constrainWidth(w);
      double height = width / ratio;
      if (height > constraints.maxHeight) {
        height = constraints.maxHeight;
        width = constraints.constrainWidth(height * ratio);
      }
      return Size(width, constraints.constrainHeight(height));
    }
    if (h != null) {
      double height = constraints.constrainHeight(h);
      double width = height * ratio;
      if (width > constraints.maxWidth) {
        width = constraints.maxWidth;
        height = constraints.constrainHeight(width / ratio);
      }
      return Size(constraints.constrainWidth(width), height);
    }
    return null;
  }

  /// Whether a layout of this box filled an axis with no room to fill (its
  /// parent measured it unbounded: a hugging row or column, a wrapping
  /// line, a grid row sized to its content, a scroll view) and so took its
  /// design size there: the number in `{"fill": n}` decided its extent. For
  /// tools to report; not cleared by a later bounded layout, since the
  /// unbounded one may have decided the parent's size.
  bool designWidthUsed = false, designHeightUsed = false;

  void _noteDesignFallback(BoxConstraints constraints) {
    if (_fillWidth && !constraints.maxWidth.isFinite && _widthFactor == null &&
        measureContentAlong != Axis.horizontal && _width != null && _width!.isFinite) {
      designWidthUsed = true;
    }
    if (_fillHeight && !constraints.maxHeight.isFinite && _heightFactor == null &&
        measureContentAlong != Axis.vertical && _height != null && _height!.isFinite) {
      designHeightUsed = true;
    }
  }

  @override
  void performLayout() {
    _noteDesignFallback(constraints);
    final BoxConstraints childConstraints = _childConstraints(constraints);
    final RenderBox? child = this.child;
    if (child == null) {
      size = childConstraints.smallest;
      return;
    }
    child.layout(childConstraints, parentUsesSize: true);
    // A child whose own layout threw has no size: take the smallest, so
    // one broken node doesn't break its ancestors' layout and hit tests too
    // (in a debug build such a throw inside a pointer update leaves the
    // mouse tracker unusable).
    size = childConstraints.constrain(child.hasSize ? child.size : childConstraints.smallest);
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
    if (_ratioWidth(height) case final double w) return w;
    final double content =
        child?.getMinIntrinsicWidth(_sizedHeight ?? height) ?? 0;
    final double? sized = _sizedWidth;
    return sized == null ? content : math.min(sized, content);
  }

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _sizedWidth ?? _ratioWidth(height) ?? child?.getMaxIntrinsicWidth(_sizedHeight ?? height) ?? 0;

  @override
  double computeMinIntrinsicHeight(double width) {
    if (_ratioHeight(width) case final double h) return h;
    final double content =
        child?.getMinIntrinsicHeight(_sizedWidth ?? width) ?? 0;
    final double? sized = _sizedHeight;
    return sized == null ? content : math.min(sized, content);
  }

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _sizedHeight ?? _ratioHeight(width) ?? child?.getMaxIntrinsicHeight(_sizedWidth ?? width) ?? 0;

  /// With an aspect ratio and a height that isn't set: the height [width]
  /// (or the box's own width) gives. A grid row sized by its items'
  /// intrinsic heights otherwise drew a card that only keeps its ratio
  /// as tall as its text lines.
  double? _ratioHeight(double width) {
    final double? ratio = _aspectRatio;
    if (ratio == null || !ratio.isFinite || ratio <= 0 || _sizedHeight != null) return null;
    final double w = _sizedWidth ?? width;
    return w.isFinite ? w / ratio : null;
  }

  /// With an aspect ratio and a width that isn't set: the width [height]
  /// (or the box's own height) gives.
  double? _ratioWidth(double height) {
    final double? ratio = _aspectRatio;
    if (ratio == null || !ratio.isFinite || ratio <= 0 || _sizedWidth != null) return null;
    final double h = _sizedHeight ?? height;
    return h.isFinite ? h * ratio : null;
  }
}


/// Parent data of a [CodelesslyFlex] child.
class CodelesslyFlexParentData extends FlexParentData {
  /// Whether the child is collapsed (hidden and taking no space), so it
  /// gets no [CodelesslyFlex.spacing] on either side.
  bool collapsed = false;

  /// In a wrapping row/column: CSS `flex-basis`, the main size the child
  /// counts when lines are broken (null: its own size).
  double? basis;

  /// In a wrapping row/column, with a [basis]: CSS `flex-grow`, its share
  /// of the room left on its line (0: none).
  int grow = 0;

  @override
  String toString() => '${super.toString()}; collapsed=$collapsed${basis == null ? '' : '; basis=$basis grow=$grow'}';
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

  /// A flex that doesn't squeeze its children ([squeeze] false: the
  /// designer let them run past its end, as a Flutter Row in a release
  /// build does) paints them, clipped as [clipBehavior] says, without the
  /// debug build's yellow-and-black overflow stripe and its error report:
  /// the design canvas and the debug editor then show what the published
  /// app shows.
  @override
  void paint(PaintingContext context, Offset offset) {
    if (_squeeze) {
      super.paint(context, offset);
      return;
    }
    if (clipBehavior == Clip.none) {
      _overflowClip.layer = null;
      defaultPaint(context, offset);
      return;
    }
    _overflowClip.layer = context.pushClipRect(needsCompositing, offset, Offset.zero & size, defaultPaint,
        clipBehavior: clipBehavior, oldLayer: _overflowClip.layer);
  }

  final LayerHandle<ClipRectLayer> _overflowClip = LayerHandle<ClipRectLayer>();

  @override
  void dispose() {
    _overflowClip.layer = null;
    super.dispose();
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

  /// [RenderFlex]'s layout, with [gap] between consecutive shown children,
  /// and the free space of a spread alignment shared among the shown ones.
  void _layOutWithGaps() {
    _layOutWithGapsOnly();
    _spreadAmongShown();
  }

  /// A collapsed child (hidden: the Flutter author leaves it out of the
  /// children, `if (visible) child`) takes no part in [MainAxisAlignment.spaceBetween],
  /// [MainAxisAlignment.spaceAround] or [MainAxisAlignment.spaceEvenly]:
  /// [RenderFlex] counted it as a zero-length slot; the shown children are
  /// placed again as they would be without it.
  void _spreadAmongShown() {
    final MainAxisAlignment align = mainAxisAlignment;
    if (align != MainAxisAlignment.spaceBetween && align != MainAxisAlignment.spaceAround && align != MainAxisAlignment.spaceEvenly) {
      return;
    }
    int shown = 0;
    bool anyCollapsed = false;
    double used = 0;
    for (RenderBox? child = firstChild; child != null; child = childAfter(child)) {
      if (_collapsed(child)) {
        anyCollapsed = true;
      } else {
        shown++;
        used += _mainExtent(child.size);
      }
    }
    if (!anyCollapsed || shown == 0) return;
    final double free = _mainExtent(size) - used - _gap * (shown - 1);
    if (free <= precisionErrorTolerance) return;
    final (double lead, double between) = switch (align) {
      MainAxisAlignment.spaceBetween => (0.0, shown > 1 ? free / (shown - 1) : 0.0),
      MainAxisAlignment.spaceAround => (free / shown / 2, free / shown),
      _ => (free / (shown + 1), free / (shown + 1)),
    };
    final bool flip = _flipMainAxis;
    double position = lead;
    RenderBox? child = flip ? lastChild : firstChild;
    while (child != null) {
      final FlexParentData data = child.parentData! as FlexParentData;
      data.offset = direction == Axis.horizontal ? Offset(position, data.offset.dy) : Offset(data.offset.dx, position);
      if (!_collapsed(child)) position += _mainExtent(child.size) + _gap + between;
      child = flip ? data.previousSibling : data.nextSibling;
    }
  }

  void _layOutWithGapsOnly() {
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

  /// Picks the children that fill the cross axis, whose content thickness
  /// [fillContentCross] measures while the cross axis is unbounded (a
  /// [RenderHugCross] measuring this flex). Null measures none.
  bool Function(RenderBox child)? get fillsAcross => _fillsAcross;
  bool Function(RenderBox child)? _fillsAcross;
  set fillsAcross(bool Function(RenderBox child)? value) {
    if (value == _fillsAcross) return;
    _fillsAcross = value;
    markNeedsLayout();
  }

  /// After a layout with an unbounded cross axis: the greatest max
  /// intrinsic cross extent of the [fillsAcross] children, each at the main
  /// extent it was laid out at (0 when there are none).
  double get fillContentCross => _fillContentCross;
  double _fillContentCross = 0;

  @override
  void performLayout() {
    _layOut();
    _fillContentCross = 0;
    final bool Function(RenderBox)? fills = _fillsAcross;
    final bool row = direction == Axis.horizontal;
    if (fills == null || (row ? constraints.hasBoundedHeight : constraints.hasBoundedWidth)) return;
    for (RenderBox? child = firstChild; child != null; child = childAfter(child)) {
      if (!fills(child)) continue;
      _fillContentCross = math.max(
        _fillContentCross,
        row
            ? child.getMaxIntrinsicHeight(child.size.width)
            : child.getMaxIntrinsicWidth(child.size.height),
      );
    }
  }

  void _layOut() {
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
    // At most the viewport, not exactly it: the content (a Row/Column that
    // fills its main axis) still takes the whole viewport, but tight
    // constraints would make it a relayout boundary, so content that grows
    // later (a form that finishes loading) would never reach this box to be
    // measured again, and would overflow the viewport instead of scrolling.
    return _axis == Axis.vertical
        ? constraints.copyWith(
            minHeight: math.min(constraints.minHeight, _viewportExtent),
            maxHeight: _viewportExtent,
          )
        : constraints.copyWith(
            minWidth: math.min(constraints.minWidth, _viewportExtent),
            maxWidth: _viewportExtent,
          );
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

