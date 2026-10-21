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

  const FitBox({
    super.key,
    this.width,
    this.height,
    this.fillWidth = false,
    this.fillHeight = false,
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
    Widget? child,
  }) : this(
         key: key,
         width: horizontalFit == SizeFit.shrinkWrap ? null : size.width,
         height: verticalFit == SizeFit.shrinkWrap ? null : size.height,
         fillWidth: horizontalFit == SizeFit.expanded,
         fillHeight: verticalFit == SizeFit.expanded,
         child: child,
       );

  @override
  RenderFitBox createRenderObject(BuildContext context) => RenderFitBox(
    width: width,
    height: height,
    fillWidth: fillWidth,
    fillHeight: fillHeight,
  );

  @override
  void updateRenderObject(BuildContext context, RenderFitBox renderObject) {
    renderObject
      ..width = width
      ..height = height
      ..fillWidth = fillWidth
      ..fillHeight = fillHeight;
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

/// The render object of [FitBox].
class RenderFitBox extends RenderProxyBox {
  RenderFitBox({
    this._width,
    this._height,
    this._fillWidth = false,
    this._fillHeight = false,
  });

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
    final double? w = _extent(
      fill: _fillWidth,
      design: _width,
      max: constraints.maxWidth,
    );
    final double? h = _extent(
      fill: _fillHeight,
      design: _height,
      max: constraints.maxHeight,
    );
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

  // A sized axis reports its design size, like a SizedBox. A fill or hug axis
  // reports its child's, like SizedBox(double.infinity) or no box.
  double? get _sizedWidth => _fillWidth ? null : _width;
  double? get _sizedHeight => _fillHeight ? null : _height;

  @override
  double computeMinIntrinsicWidth(double height) =>
      _sizedWidth ?? child?.getMinIntrinsicWidth(_sizedHeight ?? height) ?? 0;

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _sizedWidth ?? child?.getMaxIntrinsicWidth(_sizedHeight ?? height) ?? 0;

  @override
  double computeMinIntrinsicHeight(double width) =>
      _sizedHeight ?? child?.getMinIntrinsicHeight(_sizedWidth ?? width) ?? 0;

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
///   design. When the children don't fit a bounded main axis, every non-flex
///   child gives up room in proportion to its size (like CSS `flex-shrink`),
///   so content squeezes and wraps instead of running offscreen. A child that
///   cannot get smaller than its content still overflows.
///
/// When everything fits, as it does at the design size, the layout is
/// exactly [RenderFlex]'s.
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
    super.children,
  });

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
      );
}

/// The render object of [CodelesslyFlex].
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
    super.spacing,
  });

  /// How finely shrink shares are weighted: flex factors are integers, so a
  /// child's share is its main extent in 1/64 px.
  static const double _shrinkResolution = 64;

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
        _inflexible(super.performLayout);
      } else {
        super.performLayout();
      }
      return;
    }

    super.performLayout();

    // Shrink pass: only when the children overflow a bounded main axis.
    double used = spacing * math.max(0, childCount - 1);
    final Map<RenderBox, double> natural = {};
    RenderBox? child = firstChild;
    while (child != null) {
      final double extent = _mainExtent(child.size);
      used += extent;
      natural[child] = extent;
      child = childAfter(child);
    }
    if (used - _mainExtent(size) <= precisionErrorTolerance) return;

    _withFlex((child, data) {
      // A flex child already got no room; it keeps a token weight so it is
      // still laid out with a bounded main axis.
      if ((data.flex ?? 0) > 0) return (1, FlexFit.tight);
      final int weight = (natural[child]! * _shrinkResolution).round();
      if (weight <= 0) return (0, data.fit);
      return (weight, FlexFit.loose);
    }, super.performLayout);
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    if (!_mainAxisBounded(constraints) && _hasFlexChild) {
      return _inflexible(() => super.computeDryLayout(constraints));
    }
    return super.computeDryLayout(constraints);
  }

  @override
  double? computeDryBaseline(
    covariant BoxConstraints constraints,
    TextBaseline baseline,
  ) {
    if (!_mainAxisBounded(constraints) && _hasFlexChild) {
      return _inflexible(() => super.computeDryBaseline(constraints, baseline));
    }
    return super.computeDryBaseline(constraints, baseline);
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
