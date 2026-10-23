import 'dart:math' as math;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Builds a scroll view. [shrinkWrap] says whether the view must size itself
/// to its items on its scroll axis.
typedef ViewportContentBuilder = Widget Function(
  BuildContext context,
  bool shrinkWrap,
);

/// The box a scroll viewport (list, grid or page view) gets on each axis, and
/// whether it shrink-wraps its items.
///
/// A Flutter viewport needs a bounded extent on both axes unless it
/// shrink-wraps, and it can only shrink-wrap its scroll axis. The editor lays
/// a viewport out at its design size (`basicBoxLocal`), so that is the
/// fallback wherever the node's fit cannot be honoured:
///
/// * Scroll axis
///   * fixed, locked, flexible: the design size.
///   * expanded: fill when the incoming extent is bounded, else the design
///     size (inside another scroll view, a list item or a non-flex slot).
///   * shrinkWrap: shrink-wrap the items when their number is known, else the
///     design size (an endless list has no content size).
/// * Cross axis
///   * expanded: fill when bounded, else the design size.
///   * anything else: the design size. A viewport cannot measure its items
///     on the cross axis, and the design size is the widest item the editor
///     solved.
///
/// The rule depends only on the node and the incoming constraints, so a list
/// nested in another scroll view, in a Column or in a list item gets the same
/// answer.
@immutable
class ViewportLayout {
  /// The width to give the viewport; [double.infinity] fills, null passes
  /// the incoming constraints through.
  final double? width;

  /// The height to give the viewport; [double.infinity] fills, null passes
  /// the incoming constraints through.
  final double? height;

  /// Whether the viewport sizes itself to its items on its scroll axis.
  final bool shrinkWrap;

  /// Creates a [ViewportLayout].
  const ViewportLayout({
    required this.width,
    required this.height,
    required this.shrinkWrap,
  });

  /// Resolves the layout of [node] scrolling along [scrollDirection] under
  /// [constraints]. [canShrinkWrap] is false for an endless list or a page
  /// view, which cannot size itself to its items.
  factory ViewportLayout.resolve({
    required BaseNode node,
    required AxisC scrollDirection,
    required bool canShrinkWrap,
    required BoxConstraints constraints,
  }) {
    final bool vertical = scrollDirection == AxisC.vertical;
    final SizeFit mainFit = vertical ? node.verticalFit : node.horizontalFit;
    final SizeFit crossFit = vertical ? node.horizontalFit : node.verticalFit;
    final double designMain = vertical
        ? node.basicBoxLocal.height
        : node.basicBoxLocal.width;
    final double designCross = vertical
        ? node.basicBoxLocal.width
        : node.basicBoxLocal.height;
    final bool mainBounded = vertical
        ? constraints.hasBoundedHeight
        : constraints.hasBoundedWidth;
    final bool crossBounded = vertical
        ? constraints.hasBoundedWidth
        : constraints.hasBoundedHeight;

    bool shrinkWrap = false;
    final double? main;
    switch (mainFit) {
      case SizeFit.expanded:
        main = mainBounded ? double.infinity : designMain;
      case SizeFit.shrinkWrap:
        shrinkWrap = canShrinkWrap;
        main = canShrinkWrap ? null : designMain;
      case SizeFit.fixed || SizeFit.locked || SizeFit.flexible:
        main = designMain;
    }

    final double cross = crossFit == SizeFit.expanded && crossBounded
        ? double.infinity
        : designCross;

    return ViewportLayout(
      width: vertical ? cross : main,
      height: vertical ? main : cross,
      shrinkWrap: shrinkWrap,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ViewportLayout &&
      other.width == width &&
      other.height == height &&
      other.shrinkWrap == shrinkWrap;

  @override
  int get hashCode => Object.hash(width, height, shrinkWrap);

  @override
  String toString() =>
      'ViewportLayout(width: $width, height: $height, shrinkWrap: $shrinkWrap)';
}

/// Sizes a list, grid or page view node by [ViewportLayout] and builds its
/// content with the resolved shrink-wrap flag.
///
/// Every state of the view goes through this box (empty template, loading,
/// error, loaded), so the node keeps one size while its data changes.
class ViewportNodeBox extends StatelessWidget {
  /// The list, grid or page view node.
  final BaseNode node;

  /// The node's scroll axis.
  final AxisC scrollDirection;

  /// Whether the view can size itself to its items: false for an endless
  /// list or a page view.
  final bool canShrinkWrap;

  /// Builds the content inside the resolved box.
  final ViewportContentBuilder builder;

  /// Creates a [ViewportNodeBox].
  const ViewportNodeBox({
    super.key,
    required this.node,
    required this.scrollDirection,
    required this.canShrinkWrap,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final ViewportLayout layout = ViewportLayout.resolve(
          node: node,
          scrollDirection: scrollDirection,
          canShrinkWrap: canShrinkWrap,
          constraints: constraints,
        );
        return SizedBox(
          width: layout.width,
          height: layout.height,
          child: builder(context, layout.shrinkWrap),
        );
      },
    );
  }
}

/// Places the item [child] of a list view the way the editor lays it out.
///
/// The editor sizes a list item by its own fit and pins it to the start of
/// the cross axis's centre line (top centre in a vertical list, centre left
/// in a horizontal one). A Flutter list instead forces the item to the list's
/// cross extent and leaves its scroll axis unbounded. So:
///
/// * Cross axis: the item keeps its own fit (a fixed item keeps its width, an
///   expanded one fills) and is aligned like in the editor.
/// * Scroll axis: with [itemExtent] the item fills the extent, as in the
///   editor. Otherwise an expanded or flexible item, which has nothing to
///   fill along an endless axis, takes its design extent.
class ListItemBox extends StatelessWidget {
  /// The item node.
  final BaseNode item;

  /// The list's scroll axis.
  final AxisC scrollDirection;

  /// The list's fixed item extent, if any.
  final double? itemExtent;

  /// The built item.
  final Widget child;

  /// Creates a [ListItemBox].
  const ListItemBox({
    super.key,
    required this.item,
    required this.scrollDirection,
    required this.itemExtent,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final bool vertical = scrollDirection == AxisC.vertical;
    final SizeFit mainFit = vertical ? item.verticalFit : item.horizontalFit;
    final double? main =
        itemExtent ??
        (mainFit == SizeFit.expanded || mainFit == SizeFit.flexible
            ? (vertical ? item.outerBoxLocal.height : item.outerBoxLocal.width)
            : null);

    Widget result = child;
    if (main != null) {
      result = SizedBox(
        width: vertical ? null : main,
        height: vertical ? main : null,
        child: result,
      );
    }
    return Align(
      alignment: vertical ? Alignment.topCenter : Alignment.centerLeft,
      child: result,
    );
  }
}

/// A grid delegate for a fixed cross axis count that keeps cells at least as
/// wide as the editor drew them.
///
/// The editor divides the grid's design cross extent by [crossAxisCount]. A
/// plain [SliverGridDelegateWithFixedCrossAxisCount] divides the runtime
/// extent instead, so a grid tuned to 4 columns at 1440 gets 90 px cells at
/// 390 and its items, laid out for ~350 px, overflow. This delegate fits as
/// many cells of [designCellExtent] (plus spacing) as the runtime cross
/// extent holds, at least one, and shares the extent between them. At the
/// design size that is exactly [crossAxisCount]; narrower screens get fewer
/// columns and wider ones more, and a cell is never narrower than designed
/// unless the grid itself is.
class DesignCellGridDelegate extends SliverGridDelegate {
  /// The column count at the design size.
  final int crossAxisCount;

  /// The cross extent of one cell at the design size. Zero or less falls
  /// back to [crossAxisCount] at every size.
  final double designCellExtent;

  /// See [SliverGridDelegateWithFixedCrossAxisCount.mainAxisSpacing].
  final double mainAxisSpacing;

  /// See [SliverGridDelegateWithFixedCrossAxisCount.crossAxisSpacing].
  final double crossAxisSpacing;

  /// See [SliverGridDelegateWithFixedCrossAxisCount.childAspectRatio].
  final double childAspectRatio;

  /// See [SliverGridDelegateWithFixedCrossAxisCount.mainAxisExtent].
  final double? mainAxisExtent;

  /// Creates a [DesignCellGridDelegate].
  const DesignCellGridDelegate({
    required this.crossAxisCount,
    required this.designCellExtent,
    this.mainAxisSpacing = 0,
    this.crossAxisSpacing = 0,
    this.childAspectRatio = 1,
    this.mainAxisExtent,
  });

  /// The column count for a runtime cross extent of [crossAxisExtent].
  int crossAxisCountFor(double crossAxisExtent) {
    if (!(designCellExtent > 0) || !crossAxisExtent.isFinite) {
      return math.max(1, crossAxisCount);
    }
    // The epsilon keeps the design size at exactly [crossAxisCount] despite
    // rounding in the design cell extent.
    final double fit =
        (crossAxisExtent + crossAxisSpacing) /
        (designCellExtent + crossAxisSpacing);
    return math.max(1, (fit + 1e-6).floor());
  }

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: crossAxisCountFor(constraints.crossAxisExtent),
      mainAxisSpacing: mainAxisSpacing,
      crossAxisSpacing: crossAxisSpacing,
      childAspectRatio: childAspectRatio,
      mainAxisExtent: mainAxisExtent,
    ).getLayout(constraints);
  }

  @override
  bool shouldRelayout(DesignCellGridDelegate oldDelegate) =>
      oldDelegate.crossAxisCount != crossAxisCount ||
      oldDelegate.designCellExtent != designCellExtent ||
      oldDelegate.mainAxisSpacing != mainAxisSpacing ||
      oldDelegate.crossAxisSpacing != crossAxisSpacing ||
      oldDelegate.childAspectRatio != childAspectRatio ||
      oldDelegate.mainAxisExtent != mainAxisExtent;
}

/// Whether list [node] builds all its items up front, as a plain [Flex]
/// rather than a viewport: it doesn't scroll, hugs its items along its axis
/// and has a known item count (bound data or a set count). Such a list builds
/// every item either way, so it needs no viewport.
bool listBuildsAllItems(ListViewNode node) {
  final SizeFit mainFit = node.scrollDirection == AxisC.vertical
      ? node.verticalFit
      : node.horizontalFit;
  return !node.isScrollable &&
      mainFit == SizeFit.shrinkWrap &&
      !node.useCloudDatabase &&
      (node.variables['data'] != null || node.properties.itemCount != null);
}

/// Whether [node] or any node below it builds a widget that cannot report
/// intrinsic sizes: a list, grid or page view (a viewport behind a
/// [LayoutBuilder]), a scrolling row, column or frame (a [LayoutBuilder]
/// when it fills its viewport), or a web view.
///
/// Wrapping such a subtree in [IntrinsicHeight] or [IntrinsicWidth] throws
/// ("LayoutBuilder does not support returning intrinsic dimensions",
/// "RenderViewport does not support returning intrinsic dimensions"), so a
/// caller that adds an intrinsic wrapper must skip it when this is true.
bool subtreeBlocksIntrinsics(BaseNode node, GetNode getNode) {
  if ((node is ListViewNode && !listBuildsAllItems(node)) ||
      node is GridViewNode ||
      node is PageViewNode ||
      node is WebViewNode) {
    return true;
  }
  if (node is ScrollableMixin && node is! CanvasNode && node.isScrollable) {
    return true;
  }
  if (node is ChildrenMixin) {
    for (final String id in node.children) {
      if (subtreeBlocksIntrinsics(getNode(id), getNode)) return true;
    }
  }
  return false;
}

/// Builds an endless list whose item builder returns null where the list
/// ends. Every item must be wrapped in an [ItemExtentReporter] fed by
/// [extents].
typedef EndlessListBuilder = Widget Function(
  BuildContext context,
  bool Function(int index) endsAt,
  ItemExtents extents,
);

/// The main-axis extents of the items of an [EndlessList] that are laid out
/// now.
class ItemExtents {
  final Map<int, double> _extents = {};

  /// Records that item [index] was laid out [extent] long.
  void record(int index, double extent) => _extents[index] = extent;

  /// Forgets item [index], which left the list.
  void forget(int index) => _extents.remove(index);

  /// The laid-out extent of item [index], or null when it is not laid out.
  double? operator [](int index) => _extents[index];
}

/// Bounds how many items an endless list (no item count, no data) builds,
/// without giving it an end.
///
/// A [ListView] without an item count builds items until they fill its
/// viewport and cache area. Items that take no space (zero height, or hidden
/// by a visibility formula) never fill it, so Flutter would build items
/// without limit until it runs out of memory. Items of real size are already
/// bounded by Flutter.
///
/// The rule: the list ends before an item when the [runLimit] items before
/// it were all laid out shorter than one logical pixel, where [runLimit] is
/// the number of items of the item's design extent ([estimatedItemExtent])
/// that cover the viewport and the cache area on both sides. The list keeps
/// no item count, so its scroll extent stays unbounded while items take
/// space: a scroll or jump of any length in one frame never reaches an end,
/// and the decision is made during layout from the items being laid out, not
/// a frame later.
///
/// Fixed-extent layouts (a list with an item extent, grids, page views)
/// already place items by arithmetic and stay bounded on their own.
class EndlessList extends StatefulWidget {
  /// The list's scroll axis.
  final Axis axis;

  /// The item's design extent.
  final double estimatedItemExtent;

  /// The list's cache extent before and after the viewport.
  final double cacheExtent;

  /// Builds the list.
  final EndlessListBuilder builder;

  /// Creates an [EndlessList].
  const EndlessList({
    super.key,
    required this.axis,
    required this.estimatedItemExtent,
    this.cacheExtent = RenderAbstractViewport.defaultCacheExtent,
    required this.builder,
  });

  /// How many consecutive items narrower than one pixel end a list whose
  /// viewport is [viewport] long.
  static int runLimit({
    required double viewport,
    required double cacheExtent,
    required double estimatedItemExtent,
  }) {
    final double covered =
        math.max(0.0, viewport) + 2 * math.max(0.0, cacheExtent);
    return math.max(1, (covered / math.max(1.0, estimatedItemExtent)).ceil());
  }

  /// Whether a list with [extents] ends before item [index], given
  /// [runLimit].
  static bool endsAt(int index, ItemExtents extents, int runLimit) {
    if (index < runLimit) return false;
    for (int i = index - runLimit; i < index; i++) {
      final double? extent = extents[i];
      if (extent == null || extent >= 1) return false;
    }
    return true;
  }

  @override
  State<EndlessList> createState() => _EndlessListState();
}

class _EndlessListState extends State<EndlessList> {
  final ItemExtents _extents = ItemExtents();
  double _viewport = 0;

  bool _endsAt(int index) => EndlessList.endsAt(
    index,
    _extents,
    EndlessList.runLimit(
      viewport: _viewport,
      cacheExtent: widget.cacheExtent,
      estimatedItemExtent: widget.estimatedItemExtent,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double max = widget.axis == Axis.vertical
            ? constraints.maxHeight
            : constraints.maxWidth;
        _viewport = max.isFinite ? max : 0;
        return widget.builder(context, _endsAt, _extents);
      },
    );
  }
}

/// Reports the main-axis extent its child is laid out at to [extents].
class ItemExtentReporter extends SingleChildRenderObjectWidget {
  /// Where the extent is recorded.
  final ItemExtents extents;

  /// The item's index.
  final int index;

  /// The list's scroll axis.
  final Axis axis;

  /// Creates an [ItemExtentReporter].
  const ItemExtentReporter({
    super.key,
    required this.extents,
    required this.index,
    required this.axis,
    super.child,
  });

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderItemExtentReporter(extents, index, axis);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderItemExtentReporter renderObject,
  ) {
    renderObject
      ..extents = extents
      ..index = index
      ..axis = axis;
  }
}

/// The render object of [ItemExtentReporter].
class RenderItemExtentReporter extends RenderProxyBox {
  /// Creates a [RenderItemExtentReporter].
  RenderItemExtentReporter(this.extents, this.index, this.axis);

  /// Where the extent is recorded.
  ItemExtents extents;

  /// The item's index.
  int index;

  /// The list's scroll axis.
  Axis axis;

  @override
  void performLayout() {
    super.performLayout();
    extents.record(index, axis == Axis.vertical ? size.height : size.width);
  }

  @override
  void detach() {
    extents.forget(index);
    super.detach();
  }
}
