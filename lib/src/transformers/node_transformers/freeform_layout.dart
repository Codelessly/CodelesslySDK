import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// How a child of a freeform container is placed along one axis.
///
/// These are the runtime equivalent of the editor's freeform decorators
/// (`FreeFormPositionEditor`, `FreeFormAlignmentDecorator` and chained sizing
/// in the editor's position manager), re-solved for whatever size the
/// container gets at runtime instead of frozen at the design size.
enum FreeformAxisMode {
  /// A fixed distance from the start (left/top) edge.
  start,

  /// A fixed distance from the end (right/bottom) edge.
  end,

  /// Pinned to both edges: the child spans the space between the pins.
  stretch,

  /// Expanded without a max constraint: the child fills the container.
  fill,

  /// Keeps its share of the free space, like Flutter's [Align]: a child that
  /// sat 25% of the way across the free space at design size stays 25% of the
  /// way across it at any size. Used for children in align positioning mode
  /// that carry no explicit pins.
  relative,

  /// Aligned with [Alignment.inscribe] semantics.
  align,
}

/// The design-size data and rule that place a child on one axis.
///
/// All distances are in the container's inner (padded) box, which is where
/// the children are laid out.
@immutable
class FreeformAxisPlacement {
  /// The rule for this axis.
  final FreeformAxisMode mode;

  /// Distance from the container's inner start edge to the child's outer
  /// start edge at design size.
  final double start;

  /// The child's outer extent at design size.
  final double extent;

  /// The container's inner extent at design size.
  final double parentExtent;

  /// The size the child is given on this axis, or null when the child sizes
  /// itself (shrink-wrap). Only used by [FreeformAxisMode.start],
  /// [FreeformAxisMode.end] and [FreeformAxisMode.relative].
  final double? size;

  /// The alignment value (-1..1) for [FreeformAxisMode.align].
  final double alignment;

  /// Whether the child is kept inside the container when the container is
  /// smaller than at design size. False along a scroll axis, where children
  /// are content of a fixed extent.
  final bool clamp;

  /// Whether the child expands on this axis (needs a bounded slot).
  final bool expands;

  const FreeformAxisPlacement({
    required this.mode,
    required this.start,
    required this.extent,
    required this.parentExtent,
    this.size,
    this.alignment = 0,
    this.clamp = true,
    this.expands = false,
  });

  /// Distance from the child's outer end edge to the container's inner end
  /// edge at design size.
  double get end => parentExtent - start - extent;

  /// How far the child hangs out of the container's start edge at design size.
  double get overhangStart => math.max(0, -start);

  /// How far the child hangs out of the container's end edge at design size.
  double get overhangEnd => math.max(0, -end);

  /// The space the child may occupy in a container of runtime [extent].
  /// It never hangs out further than it did at design size.
  double room(double extent) =>
      math.max(0, extent + overhangStart + overhangEnd);

  /// The size and offset of a [FreeformAxisMode.stretch] child in a container
  /// of runtime extent [s].
  ///
  /// The pins are kept as long as the container is at least as large as at
  /// design size, which is exactly the editor's chained sizing. When the
  /// container is smaller, the child keeps at least its design share of the
  /// container and the pins give up the rest in proportion, so the child
  /// never collapses to zero (Flutter would clamp it to 0 once the pins add
  /// up to more than the container).
  (double offset, double size) stretchIn(double s) {
    final double l = start;
    final double r = end;
    double size = s - l - r;
    if (l >= 0 && r >= 0 && l + r > 0 && parentExtent > 0) {
      final double minSize = math.min(extent, parentExtent) * s / parentExtent;
      if (size < minSize) {
        size = minSize;
        return ((s - size) * l / (l + r), size);
      }
    }
    return (l, math.max(0, size));
  }

  /// The share of the free space the child sat at for
  /// [FreeformAxisMode.relative], or null when there was no free space.
  double? get _freeSpaceShare {
    final double free = parentExtent - extent;
    if (free <= 0) return null;
    return start / free;
  }

  /// How much of the container's extent this child needs on a content-sized
  /// (shrink-wrapping or unbounded) axis, given the child's laid out
  /// [childExtent]. Mirrors the editor: a wrapping container is as large as
  /// its children plus their pins.
  double contribution(double childExtent) => switch (mode) {
    FreeformAxisMode.fill => 0,
    FreeformAxisMode.stretch => math.max(0, start) + math.max(0, end),
    FreeformAxisMode.align => childExtent,
    FreeformAxisMode.end => childExtent + math.max(0, end),
    FreeformAxisMode.start ||
    FreeformAxisMode.relative => math.max(0, start) + childExtent,
  };

  /// The constraints the child gets on this axis in a container of runtime
  /// extent [s]. [s] is null while the container's extent is not known yet
  /// (it is sized from its children); [incomingMax] is then the most it may
  /// grow to.
  (double min, double max) constraintsIn(double? s, double incomingMax) {
    switch (mode) {
      case FreeformAxisMode.fill:
        final double v = s ?? extent;
        return (v, v);
      case FreeformAxisMode.stretch:
        final double v = s == null ? extent : stretchIn(s).$2;
        return (v, v);
      case FreeformAxisMode.align:
        final double max = s ?? incomingMax;
        if (expands && max.isInfinite) return (extent, extent);
        return (0, max);
      case FreeformAxisMode.start:
      case FreeformAxisMode.end:
      case FreeformAxisMode.relative:
        final double max = s == null || !clamp
            ? (clamp ? incomingMax : double.infinity)
            : room(s);
        if (size case final double size) {
          final double v = math.min(size, max);
          return (v, v);
        }
        return (0, max);
    }
  }

  /// The child's offset on this axis in a container of runtime extent [s],
  /// given the child's laid out [childExtent].
  double offsetIn(double s, double childExtent, {required bool wraps}) {
    double offset;
    switch (mode) {
      case FreeformAxisMode.fill:
        return 0;
      case FreeformAxisMode.stretch:
        return stretchIn(s).$1;
      case FreeformAxisMode.align:
        return (s - childExtent) / 2 * (1 + alignment);
      case FreeformAxisMode.start:
        offset = wraps ? math.max(0, start) : start;
      case FreeformAxisMode.end:
        offset = s - (wraps ? math.max(0, end) : end) - childExtent;
      case FreeformAxisMode.relative:
        final double? share = _freeSpaceShare;
        if (wraps) {
          offset = math.max(0, start);
        } else if (share == null) {
          offset = start;
        } else {
          offset = start + (s - parentExtent) * share;
        }
    }
    if (!clamp) return offset;
    final double lower = wraps ? 0 : -overhangStart;
    final double upper = s + (wraps ? 0 : overhangEnd) - childExtent;
    return math.max(lower, math.min(offset, upper));
  }

  @override
  bool operator ==(Object other) =>
      other is FreeformAxisPlacement &&
      other.mode == mode &&
      other.start == start &&
      other.extent == extent &&
      other.parentExtent == parentExtent &&
      other.size == size &&
      other.alignment == alignment &&
      other.clamp == clamp &&
      other.expands == expands;

  @override
  int get hashCode => Object.hash(
    mode,
    start,
    extent,
    parentExtent,
    size,
    alignment,
    clamp,
    expands,
  );

  @override
  String toString() =>
      'FreeformAxisPlacement($mode, start: $start, extent: $extent, '
      'parent: $parentExtent, size: $size)';
}

/// The placement of one child of a [FreeformLayout] on both axes.
@immutable
class FreeformPlacement {
  final FreeformAxisPlacement horizontal;
  final FreeformAxisPlacement vertical;

  const FreeformPlacement({required this.horizontal, required this.vertical});

  @override
  bool operator ==(Object other) =>
      other is FreeformPlacement &&
      other.horizontal == horizontal &&
      other.vertical == vertical;

  @override
  int get hashCode => Object.hash(horizontal, vertical);
}

/// Parent data for children of [RenderFreeformLayout].
class FreeformParentData extends ContainerBoxParentData<RenderBox> {
  FreeformPlacement? placement;
}

/// Gives a child of a [FreeformLayout] its [placement].
class FreeformChild extends ParentDataWidget<FreeformParentData> {
  final FreeformPlacement placement;

  const FreeformChild({
    super.key,
    required this.placement,
    required super.child,
  });

  @override
  void applyParentData(RenderObject renderObject) {
    final FreeformParentData data =
        renderObject.parentData! as FreeformParentData;
    if (data.placement != placement) {
      data.placement = placement;
      renderObject.parent?.markNeedsLayout();
    }
  }

  @override
  Type get debugTypicalAncestorWidgetClass => FreeformLayout;
}

/// Lays out the children of a freeform container (frame, stack, freeform
/// placeholder) the way the editor's solver does, at whatever size the
/// container gets at runtime.
///
/// On an axis the container does not shrink-wrap and gets a bounded size, the
/// layout takes the full size, like a [Stack] of positioned children. On an
/// axis it shrink-wraps, it is as large as its children plus their pins, like
/// the editor's wrapping freeform model. On an unbounded axis it does not
/// shrink-wrap, it keeps at least its design extent.
class FreeformLayout extends MultiChildRenderObjectWidget {
  /// Whether the container shrink-wraps horizontally.
  final bool wrapsWidth;

  /// Whether the container shrink-wraps vertically.
  final bool wrapsHeight;

  /// The container's inner size at design size.
  final Size designSize;

  const FreeformLayout({
    super.key,
    required this.wrapsWidth,
    required this.wrapsHeight,
    required this.designSize,
    super.children,
  });

  @override
  RenderFreeformLayout createRenderObject(BuildContext context) =>
      RenderFreeformLayout(
        wrapsWidth: wrapsWidth,
        wrapsHeight: wrapsHeight,
        designSize: designSize,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderFreeformLayout renderObject,
  ) {
    renderObject
      ..wrapsWidth = wrapsWidth
      ..wrapsHeight = wrapsHeight
      ..designSize = designSize;
  }
}

/// The render object of [FreeformLayout].
class RenderFreeformLayout extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, FreeformParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, FreeformParentData> {
  RenderFreeformLayout({
    required bool wrapsWidth,
    required bool wrapsHeight,
    required Size designSize,
  }) {
    _wrapsWidth = wrapsWidth;
    _wrapsHeight = wrapsHeight;
    _designSize = designSize;
  }

  late bool _wrapsWidth;

  bool get wrapsWidth => _wrapsWidth;

  set wrapsWidth(bool value) {
    if (value == _wrapsWidth) return;
    _wrapsWidth = value;
    markNeedsLayout();
  }

  late bool _wrapsHeight;

  bool get wrapsHeight => _wrapsHeight;

  set wrapsHeight(bool value) {
    if (value == _wrapsHeight) return;
    _wrapsHeight = value;
    markNeedsLayout();
  }

  late Size _designSize;

  Size get designSize => _designSize;

  set designSize(Size value) {
    if (value == _designSize) return;
    _designSize = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! FreeformParentData) {
      child.parentData = FreeformParentData();
    }
  }

  static const FreeformPlacement _fallback = FreeformPlacement(
    horizontal: FreeformAxisPlacement(
      mode: FreeformAxisMode.start,
      start: 0,
      extent: 0,
      parentExtent: 0,
    ),
    vertical: FreeformAxisPlacement(
      mode: FreeformAxisMode.start,
      start: 0,
      extent: 0,
      parentExtent: 0,
    ),
  );

  FreeformPlacement _placementOf(RenderBox child) =>
      (child.parentData! as FreeformParentData).placement ?? _fallback;

  BoxConstraints _childConstraints(
    FreeformPlacement placement,
    double? width,
    double? height,
    BoxConstraints constraints,
  ) {
    final (double minW, double maxW) = placement.horizontal.constraintsIn(
      width,
      constraints.maxWidth,
    );
    final (double minH, double maxH) = placement.vertical.constraintsIn(
      height,
      constraints.maxHeight,
    );
    return BoxConstraints(
      minWidth: minW,
      maxWidth: maxW,
      minHeight: minH,
      maxHeight: maxH,
    );
  }

  /// Sizes this box and returns its size. [layoutChild] lays out (or dry lays
  /// out) a child and returns its size. When [positions] is given, every
  /// child is laid out at its final constraints and its offset is written
  /// into it; otherwise (dry layout) children are only measured when the size
  /// depends on them.
  Size _solve(
    BoxConstraints constraints,
    ChildLayouter layoutChild, {
    Map<RenderBox, Offset>? positions,
  }) {
    final bool contentWidth = wrapsWidth || !constraints.hasBoundedWidth;
    final bool contentHeight = wrapsHeight || !constraints.hasBoundedHeight;

    double? width = contentWidth ? null : constraints.maxWidth;
    double? height = contentHeight ? null : constraints.maxHeight;

    // First pass, only when an extent depends on the children: measure the
    // children with the extents known so far.
    if (contentWidth || contentHeight) {
      double needW = 0;
      double needH = 0;
      RenderBox? child = firstChild;
      while (child != null) {
        final FreeformPlacement placement = _placementOf(child);
        final Size size = layoutChild(
          child,
          _childConstraints(placement, width, height, constraints),
        );
        // A child collapsed to nothing (hidden at runtime) takes no room.
        if (size != Size.zero) {
          needW = math.max(
            needW,
            placement.horizontal.contribution(size.width),
          );
          needH = math.max(needH, placement.vertical.contribution(size.height));
        }
        child = childAfter(child);
      }
      if (contentWidth) {
        width = wrapsWidth ? needW : math.max(needW, designSize.width);
      }
      if (contentHeight) {
        height = wrapsHeight ? needH : math.max(needH, designSize.height);
      }
    }

    final Size size = constraints.constrain(Size(width!, height!));
    if (positions == null) return size;

    RenderBox? child = firstChild;
    while (child != null) {
      final FreeformPlacement placement = _placementOf(child);
      final Size childSize = layoutChild(
        child,
        _childConstraints(placement, size.width, size.height, constraints),
      );
      positions[child] = Offset(
        placement.horizontal.offsetIn(
          size.width,
          childSize.width,
          wraps: wrapsWidth,
        ),
        placement.vertical.offsetIn(
          size.height,
          childSize.height,
          wraps: wrapsHeight,
        ),
      );
      child = childAfter(child);
    }
    return size;
  }

  @override
  @protected
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      _solve(constraints, ChildLayoutHelper.dryLayoutChild);

  @override
  void performLayout() {
    final Map<RenderBox, Offset> positions = {};
    size = _solve(
      constraints,
      ChildLayoutHelper.layoutChild,
      positions: positions,
    );
    positions.forEach((child, offset) {
      (child.parentData! as FreeformParentData).offset = offset;
    });
  }

  /// The extent the children need on one axis, from their fixed sizes or,
  /// for children that size themselves, their intrinsic sizes.
  double _intrinsicExtent(
    bool horizontal,
    double Function(RenderBox child, FreeformAxisPlacement placement) measure,
  ) {
    double need = 0;
    RenderBox? child = firstChild;
    while (child != null) {
      final FreeformPlacement placement = _placementOf(child);
      final FreeformAxisPlacement axis = horizontal
          ? placement.horizontal
          : placement.vertical;
      final double extent = switch (axis.mode) {
        FreeformAxisMode.fill || FreeformAxisMode.stretch => 0,
        _ => axis.size ?? measure(child, axis),
      };
      need = math.max(need, axis.contribution(extent));
      child = childAfter(child);
    }
    return need;
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      _intrinsicExtent(true, (child, _) => child.getMinIntrinsicWidth(height));

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _intrinsicExtent(true, (child, _) => child.getMaxIntrinsicWidth(height));

  @override
  double computeMinIntrinsicHeight(double width) =>
      _intrinsicExtent(false, (child, _) => child.getMinIntrinsicHeight(width));

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _intrinsicExtent(false, (child, _) => child.getMaxIntrinsicHeight(width));

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      defaultComputeDistanceToHighestActualBaseline(baseline);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);
}
