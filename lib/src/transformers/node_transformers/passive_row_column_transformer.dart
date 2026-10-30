import 'dart:math' as math;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';

import '../../../codelessly_sdk.dart';

typedef WidgetInserter = Widget Function(Widget child);

class PassiveRowColumnTransformer extends NodeWidgetTransformer<RowColumnNode> {
  PassiveRowColumnTransformer(super.getNode, super.manager);

  /// Whether a child of [rowColumn], which hugs its cross axis, fills that
  /// axis while another child gives it a thickness: a card's severity edge
  /// as tall as its text, `IntrinsicHeight(child: Row(...))` in Flutter.
  /// The row is measured to its other children's thickness first, which the
  /// filling child then fills. With no such other child there is nothing to
  /// fill, and the child keeps its design size (see FitBox), as the editor
  /// lays it out. A spacer's thickness is not used, so it gives none.
  static bool fillsAcrossWrappingRowColumn(
    BaseNode rowColumn,
    List<BaseNode> childrenNodes,
  ) {
    final bool isRow =
        (rowColumn as RowColumnMixin).rowColumnType == RowColumnType.row;
    SizeFit crossFit(BaseNode child) =>
        isRow ? child.verticalFit : child.horizontalFit;
    bool fills(BaseNode child) =>
        child is! SpacerNode && crossFit(child) == SizeFit.expanded;
    return childrenNodes.any(fills) &&
        childrenNodes.any((child) => child is! SpacerNode && !fills(child));
  }

  static Widget buildRowColumnWidget(
    BaseNode rowColumnNode, {
    required List<Widget> childrenWidgets,
    required List<BaseNode> childrenNodes,
    required bool withScroll,
    required GetNode getNode,
  }) {
    assert(rowColumnNode is RowColumnMixin);

    final bool isRow =
        (rowColumnNode as RowColumnMixin).rowColumnType == RowColumnType.row;

    // If the node is a canvas node's body, it is a placeholder that expands to
    // fill the canvas, while the canvas is already meant to do that as a
    // scroll view. Its height follows its content (at least its min height).
    final BaseNode? parent = rowColumnNode.parentID == kRootNode
        ? null
        : getNode(rowColumnNode.parentID);
    final bool isPlaceholder =
        parent is CanvasNode && parent.properties.bodyId == rowColumnNode.id;

    // A flexible Row/Column that scrolls along its main axis is a Flutter
    // Flexible (loose) around its scroll view: as long as its content, at
    // most the space its parent gives it, and the content scrolls past that.
    final bool contentSized =
        withScroll && scrollsFlexiblyOnMainAxis(rowColumnNode);

    // Padding belongs outside this widget unless scrolling moves it inside.
    final bool scrolls =
        withScroll &&
        rowColumnNode is ScrollableMixin &&
        (rowColumnNode as ScrollableMixin).isScrollable;
    final EdgeInsetsModel padding =
        rowColumnNode is DefaultShapeNode && !scrolls
        ? rowColumnNode.resolvedPadding()
        : EdgeInsetsModel.zero;

    final FitBox outerBox = FitBox(
      width: contentSized && isRow
          ? null
          : _outerExtent(
              rowColumnNode.horizontalFit,
              design: rowColumnNode.outerBoxLocal.width,
              min: rowColumnNode.constraints.minWidth,
              max: rowColumnNode.constraints.maxWidth,
              inset: padding.horizontal,
            ),
      fillWidth: _fillsAxis(
        rowColumnNode.horizontalFit,
        max: rowColumnNode.constraints.maxWidth,
      ),
      height: contentSized && !isRow
          ? null
          : isPlaceholder && rowColumnNode.verticalFit.isFlex
          ? rowColumnNode.constraints.minHeight
          : _outerExtent(
              rowColumnNode.verticalFit,
              design: rowColumnNode.outerBoxLocal.height,
              min: rowColumnNode.constraints.minHeight,
              max: rowColumnNode.constraints.maxHeight,
              inset: padding.vertical,
            ),
      fillHeight:
          !(isPlaceholder && rowColumnNode.verticalFit.isFlex) &&
          _fillsAxis(
            rowColumnNode.verticalFit,
            max: rowColumnNode.constraints.maxHeight,
          ),
    );

    final bool wrapsChildren = rowColumnWraps(rowColumnNode);
    if (wrapsChildren) {
      return _withOuterBox(
        outerBox,
        _withMinExtent(
          rowColumnNode,
          padding,
          isPlaceholder,
          _buildWrap(rowColumnNode, childrenWidgets, withScroll: withScroll),
        ),
      );
    }

    final SizeFit mainFit = isRow
        ? rowColumnNode.horizontalFit
        : rowColumnNode.verticalFit;
    final bool crossWraps = isRow
        ? rowColumnNode.isVerticalWrap
        : rowColumnNode.isHorizontalWrap;
    final double? crossMin = isRow
        ? rowColumnNode.constraints.minHeight
        : rowColumnNode.constraints.minWidth;

    // A Row/Column that hugs its cross axis is as thick as its thickest
    // child, as the editor sizes it. Children that align or stretch across
    // it need that thickness first: Flutter would otherwise align them in,
    // or stretch them to, the whole incoming cross axis (or fail when that
    // is unbounded). An intrinsic wrapper can't measure a subtree with a
    // viewport or LayoutBuilder in it; a stretch then falls back to start,
    // so children keep their own thickness instead of the incoming one.
    final bool stretches =
        rowColumnNode.crossAxisAlignment == CrossAxisAlignmentC.stretch;
    bool measureCross = false;
    bool stretchFallsBack = false;
    if (!wrapsChildren && crossMin == null && crossWraps) {
      final bool anyChildNeedsAlignment = childrenNodes.any(
        (child) => child.alignment != AlignmentModel.none,
      );
      if (stretches ||
          anyChildNeedsAlignment ||
          fillsAcrossWrappingRowColumn(rowColumnNode, childrenNodes)) {
        final bool blocked = childrenNodes.any(
          (child) => subtreeBlocksIntrinsics(child, getNode),
        );
        measureCross = !blocked;
        stretchFallsBack = blocked && stretches;
      }
    }

    final CrossAxisAlignment crossAxisAlignment = stretchFallsBack
        ? CrossAxisAlignment.start
        : rowColumnNode.crossAxisAlignment.flutterAxis;
    Widget res = CodelesslyFlex(
      direction: isRow ? Axis.horizontal : Axis.vertical,
      mainAxisAlignment: rowColumnNode.mainAxisAlignment.flutterAxis,
      crossAxisAlignment: crossAxisAlignment,
      // Flex asserts a baseline to align to; texts align on the alphabetic one.
      textBaseline: crossAxisAlignment == CrossAxisAlignment.baseline
          ? TextBaseline.alphabetic
          : null,
      mainAxisSize: mainFit == SizeFit.shrinkWrap
          ? MainAxisSize.min
          : MainAxisSize.max,
      spacing: rowColumnNode.spacing,
      key: ValueKey(rowColumnNode.id),
      children: childrenWidgets,
    );

    if (measureCross) {
      res = isRow ? IntrinsicHeight(child: res) : IntrinsicWidth(child: res);
    }

    // A wrapping row/column puts its children on new runs instead of
    // scrolling them along its main axis.
    if (withScroll &&
        !wrapsChildren &&
        rowColumnNode is ScrollableMixin &&
        (rowColumnNode as ScrollableMixin).isScrollable) {
      res = wrapWithPaddedScrollable(
        padding: rowColumnNode.resolvedPadding().flutterEdgeInsetsDirectional,
        node: (rowColumnNode as ScrollableMixin),
        // Sized by its content, there is no free space to align it in.
        fillViewport:
            !contentSized &&
            rowColumnNode.mainAxisAlignment != MainAxisAlignmentC.start,
        flexContent: hasMainAxisFlexChild(rowColumnNode, childrenNodes),
        contentSizedOnScrollAxis: contentSized,
        child: res,
      );
    }

    return _withOuterBox(
      outerBox,
      _withMinExtent(rowColumnNode, padding, isPlaceholder, res),
    );
  }

  static Widget _withMinExtent(
    BaseNode node,
    EdgeInsetsModel padding,
    bool isPlaceholder,
    Widget res,
  ) {
    final double? minWidth = node.horizontalFit == SizeFit.shrinkWrap
        ? _minExtent(node.constraints.minWidth, padding.horizontal)
        : null;
    final double? minHeight =
        node.verticalFit == SizeFit.shrinkWrap &&
            !(isPlaceholder && node.verticalFit.isFlex)
        ? _minExtent(node.constraints.minHeight, padding.vertical)
        : null;
    if (minWidth == null && minHeight == null) return res;
    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: minWidth ?? 0,
        minHeight: minHeight ?? 0,
      ),
      child: res,
    );
  }

  /// Puts [res] in the row/column's own box, [outerBox], when it has one.
  static Widget _withOuterBox(FitBox outerBox, Widget res) {
    if (outerBox.width == null &&
        outerBox.height == null &&
        !outerBox.fillWidth &&
        !outerBox.fillHeight) {
      return res;
    }

    // Without a fill this is exactly a SizedBox; the editor's design-mode
    // scroll unwraps it to put its scroll view inside.
    if (!outerBox.fillWidth && !outerBox.fillHeight) {
      return SizedBox(
        width: outerBox.width,
        height: outerBox.height,
        child: res,
      );
    }

    return FitBox(
      width: outerBox.width,
      height: outerBox.height,
      fillWidth: outerBox.fillWidth,
      fillHeight: outerBox.fillHeight,
      child: res,
    );
  }

  /// The [CodelesslyWrap] of a row/column that wraps (see
  /// [RowColumnMixin.wrap]): a row wraps horizontally and a column
  /// vertically, with the row/column's spacing within runs and its
  /// runSpacing between them.
  ///
  /// The main-axis alignment places children within each run. The
  /// cross-axis alignment places them within their run and places the runs
  /// in the cross-axis free space (start, center or end; stretch and
  /// baseline act as start), as Figma auto layout does with wrap.
  ///
  /// A scrollable one scrolls along its cross axis, through its runs (see
  /// `RowColumnNode.scrollDirection`).
  static Widget _buildWrap(
    RowColumnMixin node,
    List<Widget> children, {
    required bool withScroll,
  }) {
    final WrapAlignment runAlignment = wrapRunAlignment(
      node.crossAxisAlignment,
    );
    Widget res = CodelesslyWrap(
      key: ValueKey(node.id),
      direction: node.rowColumnType == RowColumnType.row
          ? Axis.horizontal
          : Axis.vertical,
      alignment: wrapAlignment(node.mainAxisAlignment),
      spacing: node.spacing,
      runAlignment: runAlignment,
      runSpacing: node.runSpacing,
      crossAxisAlignment: wrapCrossAlignment(node.crossAxisAlignment),
      children: children,
    );
    if (withScroll && node is ScrollableMixin) {
      final ScrollableMixin scrollable = node as ScrollableMixin;
      if (scrollable.isScrollable) {
        res = wrapWithPaddedScrollable(
          padding: node.resolvedPadding().flutterEdgeInsetsDirectional,
          node: scrollable,
          fillViewport: runAlignment != WrapAlignment.start,
          child: res,
        );
      }
    }
    return res;
  }

  /// Whether [node] is a Row/Column that scrolls along its main axis and is
  /// flexible on it: it is as long as its content, capped by its [Flexible]
  /// parent, like the editor's `min(flex share, content)`.
  static bool scrollsFlexiblyOnMainAxis(BaseNode node) {
    if (node is! RowColumnMixin || node is! ScrollableMixin) return false;
    if (rowColumnWraps(node)) return false;
    final ScrollableMixin scrollable = node as ScrollableMixin;
    final bool isRow = node.rowColumnType == RowColumnType.row;
    if (!scrollable.isScrollable) return false;
    if (scrollable.scrollDirection !=
        (isRow ? AxisC.horizontal : AxisC.vertical)) {
      return false;
    }
    return (isRow ? node.horizontalFit : node.verticalFit) == SizeFit.flexible;
  }

  /// Whether [node] is a row/column whose children flow onto new runs when
  /// they don't fit ([RowColumnMixin.wrap]), built as a [CodelesslyWrap].
  static bool rowColumnWraps(BaseNode node) =>
      node is RowColumnMixin && node.wrap;

  /// The [Wrap.alignment] of a wrapping row/column with [alignment] as its
  /// main-axis alignment.
  static WrapAlignment wrapAlignment(MainAxisAlignmentC alignment) =>
      switch (alignment) {
        MainAxisAlignmentC.start => WrapAlignment.start,
        MainAxisAlignmentC.end => WrapAlignment.end,
        MainAxisAlignmentC.center => WrapAlignment.center,
        MainAxisAlignmentC.spaceBetween => WrapAlignment.spaceBetween,
        MainAxisAlignmentC.spaceAround => WrapAlignment.spaceAround,
        MainAxisAlignmentC.spaceEvenly => WrapAlignment.spaceEvenly,
      };

  /// The [Wrap.crossAxisAlignment] of a wrapping row/column with
  /// [alignment] as its cross-axis alignment.
  static WrapCrossAlignment wrapCrossAlignment(CrossAxisAlignmentC alignment) =>
      switch (alignment) {
        CrossAxisAlignmentC.center => WrapCrossAlignment.center,
        CrossAxisAlignmentC.end => WrapCrossAlignment.end,
        CrossAxisAlignmentC.start ||
        CrossAxisAlignmentC.stretch ||
        CrossAxisAlignmentC.baseline => WrapCrossAlignment.start,
      };

  /// The [Wrap.runAlignment] of a wrapping row/column with [alignment] as
  /// its cross-axis alignment.
  static WrapAlignment wrapRunAlignment(CrossAxisAlignmentC alignment) =>
      switch (alignment) {
        CrossAxisAlignmentC.center => WrapAlignment.center,
        CrossAxisAlignmentC.end => WrapAlignment.end,
        CrossAxisAlignmentC.start ||
        CrossAxisAlignmentC.stretch ||
        CrossAxisAlignmentC.baseline => WrapAlignment.start,
      };

  /// The design extent of a Row/Column's own box on one axis, or null when it
  /// hugs its children.
  ///
  /// Fixed and locked take the solved outer size. shrinkWrap hugs; its min
  /// constraint is a minimum ([_minExtent]), not a size. Expanded takes its max constraint when it has one,
  /// and otherwise fills a bounded axis or takes its design size on an
  /// unbounded one. Flexible takes its design size, as leaves do: its
  /// [Flexible] parent lets it get smaller, never larger, matching the
  /// editor's `min(flex share, design size)`.
  ///
  /// [inset] is the padding outside this widget on the axis, which a min or
  /// max constraint (the whole box's) leaves less room inside.
  static double? _outerExtent(
    SizeFit fit, {
    required double design,
    required double? min,
    required double? max,
    double inset = 0,
  }) => switch (fit) {
    // A hugging axis has no size of its own: its min constraint is applied
    // as a minimum (see [_minExtent]), so content larger than it grows it.
    SizeFit.shrinkWrap => null,
    SizeFit.expanded => max == null ? design : math.max(0, max - inset),
    SizeFit.fixed || SizeFit.locked || SizeFit.flexible => design,
  };

  /// The minimum a hugging axis keeps: its min constraint less the padding
  /// outside this widget, or null without one.
  static double? _minExtent(double? min, double inset) =>
      min == null ? null : math.max(0, min - inset);

  static bool _fillsAxis(SizeFit fit, {required double? max}) =>
      fit == SizeFit.expanded && max == null;

  /// Whether any of [children] flexes along [rowColumnNode]'s main axis
  /// (expanded, flexible, or a flex spacer).
  static bool hasMainAxisFlexChild(
    BaseNode rowColumnNode,
    Iterable<BaseNode> children,
  ) {
    final bool isRow =
        (rowColumnNode as RowColumnMixin).rowColumnType == RowColumnType.row;
    return children.any(
      (child) => (isRow ? child.horizontalFit : child.verticalFit).isFlex,
    );
  }

  static Widget wrapChildWithSizeFits(
    BaseNode node,
    BaseNode parentRowColumn,
    Widget childWidget,
    int flex, {
    AlignmentModel? alignment,
    WidgetInserter? flexibleSpaceBackground,
    GetNode? getNode,
  }) {
    assert(parentRowColumn is RowColumnMixin);

    if (rowColumnWraps(parentRowColumn)) {
      return wrapChildInRun(
        node,
        parentRowColumn,
        childWidget,
        flexibleSpaceBackground: flexibleSpaceBackground,
        getNode: getNode,
      );
    }

    final RowColumnMixin parent = parentRowColumn as RowColumnMixin;
    final AxisC mainAxis = (parent.rowColumnType == RowColumnType.row
        ? AxisC.horizontal
        : AxisC.vertical);
    final SizeFit mainAxisFit = (mainAxis == AxisC.horizontal
        ? node.horizontalFit
        : node.verticalFit);

    // A spacer flexes like Flutter's Spacer. The flex goes around everything
    // built for it, as for any other child: a host's wrappers (the editor's
    // geometry probes) would otherwise sit between the Flex and an Expanded
    // inside, and the Flex would lay the spacer out at its design size.
    if (node is SpacerNode) {
      return switch (mainAxisFit) {
        SizeFit.expanded => Expanded(flex: flex, child: childWidget),
        SizeFit.flexible => Flexible(flex: flex, child: childWidget),
        _ => childWidget,
      };
    }

    final SizeFit crossAxisFit = (mainAxis == AxisC.horizontal
        ? node.verticalFit
        : node.horizontalFit);

    // A parent that stretches its children across gives each one the full
    // cross axis, like the editor's solver, except a child that hugs on that
    // axis: the solver keeps its own size there and places it at the start.
    // In a parent that hugs the cross axis too (measured with an
    // IntrinsicHeight/Width), the solver stretches hugging children to the
    // thickest one, so cards in a row get equal heights.
    final bool parentHugsCross =
        (mainAxis == AxisC.horizontal
            ? parentRowColumn.verticalFit
            : parentRowColumn.horizontalFit) ==
        SizeFit.shrinkWrap;
    final AlignmentGeometry? childAlignment =
        (alignment ?? node.alignment).data?.flutterAlignmentGeometry ??
        (parent.crossAxisAlignment == CrossAxisAlignmentC.stretch &&
                crossAxisFit == SizeFit.shrinkWrap &&
                !parentHugsCross
            ? AlignmentDirectional.topStart
            : null);
    final bool hasAlignment = childAlignment != null;

    final double? mainAxisMaxConstraint = (mainAxis == AxisC.horizontal
        ? node.constraints.maxWidth
        : node.constraints.maxHeight);
    // final double? horizontalMaxConstraint = node.constraints.maxWidth;
    // final double? verticalMaxConstraint = node.constraints.maxHeight;

    if (node.horizontalFit == node.verticalFit) {
      if (hasAlignment) {
        childWidget = Align(alignment: childAlignment, child: childWidget);
      }
      if (flexibleSpaceBackground != null) {
        childWidget = flexibleSpaceBackground(childWidget);
      }
      switch (node.horizontalFit) {
        case SizeFit.shrinkWrap:
        case SizeFit.locked:
        case SizeFit.fixed:
          break;
        case SizeFit.expanded:
          if (mainAxisMaxConstraint != null) {
            // When there's constraints on the main axis, we need to use
            // Flexible instead of Expanded because Expanded will try to
            // expand and won't respect the constraints.
            childWidget = Flexible(flex: flex, child: childWidget);
          } else {
            childWidget = Expanded(flex: flex, child: childWidget);
          }
        case SizeFit.flexible:
          childWidget = Flexible(flex: flex, child: childWidget);
      }
    } else {
      // If any side flexes we need to wrap the node into a Flexible.
      if (node.horizontalFit.isFlex || node.verticalFit.isFlex) {
        // Commenting this our fixes row column responsiveness.

        // double width = node.outerBoxLocal.width;
        // double height = node.outerBoxLocal.height;
        //
        // if (horizontalMaxConstraint == null &&
        //     (node.horizontalFit == SizeFit.expanded ||
        //         (hasAlignment && mainAxis == AxisC.vertical))) {
        //   width = double.infinity;
        // }
        // if (verticalMaxConstraint == null &&
        //     (node.verticalFit == SizeFit.expanded ||
        //         (hasAlignment && mainAxis == AxisC.horizontal))) {
        //   height = double.infinity;
        // }

        // if (crossAxisFit == SizeFit.expanded) {
        //   childWidget = ConstrainedBox(
        //     constraints: BoxConstraints.expand(width: width, height: height),
        //     child: childWidget,
        //   );
        // }

        if (hasAlignment) {
          childWidget = Align(alignment: childAlignment, child: childWidget);
        }

        if (flexibleSpaceBackground != null) {
          childWidget = flexibleSpaceBackground(childWidget);
        }

        // We only want to wrap in Flex if node flexes on main axis in order
        // to avoid having it's flexFactor accounted for unnecessarily.
        // We can do this because children on cross axis get restricted bounds.
        if (mainAxisFit.isFlex) {
          if (mainAxisFit == SizeFit.flexible) {
            childWidget = Flexible(flex: flex, child: childWidget);
          } else {
            if (mainAxisMaxConstraint != null) {
              // When there's constraints on the main axis, we need to use
              // Flexible instead of Expanded because Expanded will try to
              // expand and won't respect the constraints.
              childWidget = Flexible(flex: flex, child: childWidget);
            } else {
              childWidget = Expanded(flex: flex, child: childWidget);
            }
          }
        }
      } else {
        if (hasAlignment) {
          childWidget = Align(alignment: childAlignment, child: childWidget);
        }
        if (flexibleSpaceBackground != null) {
          childWidget = flexibleSpaceBackground(childWidget);
        }
      }
    }

    // A squeezable node that wraps its content hugs it while it fits and
    // shrinks to the room the Row/Column has left when it doesn't.
    if (mainAxisFit == SizeFit.shrinkWrap && node.squeezable) {
      childWidget = Flexible(flex: flex, child: childWidget);
    }

    return childWidget;
  }

  /// Sizes a child of a wrapping row/column ([rowColumnWraps]) for its [CodelesslyWrap] run.
  ///
  /// Expanded and flexible mean nothing in a run, so a child that flexes on
  /// an axis hugs its content there instead, as the editor lays it out: an
  /// intrinsic wrapper measures it. A subtree that can't report intrinsic
  /// sizes ([subtreeBlocksIntrinsics]) takes its design size on that axis,
  /// the size the editor solved for it. A spacer has no content and takes
  /// no room. The child's own alignment is not applied: an [Align] would
  /// take the whole run.
  static Widget wrapChildInRun(
    BaseNode node,
    BaseNode parentRowColumn,
    Widget childWidget, {
    WidgetInserter? flexibleSpaceBackground,
    GetNode? getNode,
  }) {
    if (node is SpacerNode) {
      final bool isRow =
          (parentRowColumn as RowColumnMixin).rowColumnType ==
          RowColumnType.row;
      return SizedBox(
        width: isRow ? node.outerBoxLocal.width : 0,
        height: isRow ? 0 : node.outerBoxLocal.height,
      );
    }

    if (flexibleSpaceBackground != null) {
      childWidget = flexibleSpaceBackground(childWidget);
    }

    final bool flexesHorizontally = node.horizontalFit.isFlex;
    final bool flexesVertically = node.verticalFit.isFlex;
    if (!flexesHorizontally && !flexesVertically) return childWidget;

    // Leaves with expanded fit have no intrinsic content extent (FitBox
    // reports zero); unlike content-hugging row/columns they keep their
    // design size in a wrap.
    final bool blocked =
        node is! RowColumnMixin ||
        getNode == null ||
        subtreeBlocksIntrinsics(node, getNode);
    if (blocked) {
      return SizedBox(
        width: flexesHorizontally ? node.outerBoxLocal.width : null,
        height: flexesVertically ? node.outerBoxLocal.height : null,
        child: childWidget,
      );
    }
    if (flexesHorizontally) childWidget = IntrinsicWidth(child: childWidget);
    if (flexesVertically) childWidget = IntrinsicHeight(child: childWidget);
    return childWidget;
  }

  @override
  Widget buildWidget(
    BaseNode node,
    BuildContext context,
    WidgetBuildSettings settings,
  ) => PassiveRowColumnWidget(
    node: node,
    children: node.childrenOrEmpty.map(getNode).toList(),
    manager: manager,
    settings: settings,
  );
}

class PassiveRowColumnWidget extends StatelessWidget {
  const PassiveRowColumnWidget({
    required this.node,
    required this.children,
    required this.manager,
    required this.settings,
    super.key,
  });

  final BaseNode node;
  final List<BaseNode> children;
  final NodeTransformerManager manager;
  final WidgetBuildSettings settings;

  /// A child hidden at runtime collapses: it tells the [CodelesslyFlex] so
  /// the row/column's spacing skips it, and a flexing one gives up its share
  /// of the free space, so a visible sibling (an empty state next to a
  /// hidden spinner) can take all of it. The flex drops to zero rather than
  /// removing the [Flexible] so the child keeps its state when it shows
  /// again.
  Widget _collapseWhenHidden(
    BuildContext context,
    BaseNode child,
    Widget sizedWidget,
  ) {
    final NodeTransformerManager manager = this.manager;
    // A child that reads its parent's size can only tell whether it is
    // hidden as it is laid out, so it keeps its place.
    if (manager is! PassiveNodeTransformerManager || readsParentSize(child)) {
      return FlexChildVisibility(collapsed: false, child: sizedWidget);
    }

    Widget buildChild(BuildContext context) {
      final bool hidden = manager.runtimeVisibility(context, child) == false;
      if (sizedWidget is! Flexible) {
        return FlexChildVisibility(collapsed: hidden, child: sizedWidget);
      }
      // A flex bound to data (a bar's share of a gauge) or set by a
      // condition replaces the node's own: the row lays out the Flexible, so
      // the child's own style overrides can't change its share. One bound to
      // no share (an empty progress fill) takes no space.
      final num? boundFlex = child.variables.containsKey('flex')
          ? PropertyValueDelegate.getPropertyValue<num>(
              child,
              'flex',
              scopedValues: ScopedValues.of(context),
            )
          : null;
      final bool empty = boundFlex != null && boundFlex <= 0;
      final bool collapsed = hidden || empty;
      final int flex = boundFlex != null && boundFlex > 0
          ? boundFlex.round()
          : sizedWidget.flex;
      final bool isRow =
          node is RowColumnMixin &&
          (node as RowColumnMixin).rowColumnType == RowColumnType.row;
      // Without flex the collapsed child would be laid out with unbounded
      // main-axis constraints, which a scrollable inside it can't take
      // (a hidden grid computed NaN offsets), so it gets no space at all.
      return FlexChildVisibility(
        collapsed: collapsed,
        child: Flexible(
          flex: collapsed ? 0 : flex,
          fit: sizedWidget.fit,
          child: SizedBox(
            width: hidden || (empty && isRow) ? 0 : null,
            height: hidden || (empty && !isRow) ? 0 : null,
            child: sizedWidget.child,
          ),
        ),
      );
    }

    final List<Listenable> listenables = manager.listenablesFor(context, child);
    if (listenables.isEmpty) return buildChild(context);
    return ManagedListenableBuilder(
      key: ValueKey('${child.id}-flex'),
      listenables: listenables,
      builder: buildChild,
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> widgetChildren = children.map((child) {
      final Widget builtWidget = manager.buildWidgetByID(
        child.id,
        context,
        settings: settings,
      );

      final Widget sizedWidget =
          PassiveRowColumnTransformer.wrapChildWithSizeFits(
            child,
            node,
            builtWidget,
            child.flex,
            getNode: manager.getNode,
          );
      return _collapseWhenHidden(context, child, sizedWidget);
    }).toList();

    final Widget child = (node is DefaultShapeNode)
        ? manager.getTransformer<PassiveRectangleTransformer>().buildRectangle(
            node as DefaultShapeNode,
            applyPadding:
                node is! ScrollableMixin ||
                !(node as ScrollableMixin).isScrollable,
            children: [
              PassiveRowColumnTransformer.buildRowColumnWidget(
                node,
                childrenWidgets: widgetChildren,
                childrenNodes: children,
                withScroll: true,
                getNode: manager.getNode,
              ),
            ],
            settings: settings,
          )
        : PassiveRowColumnTransformer.buildRowColumnWidget(
            node,
            childrenWidgets: widgetChildren,
            childrenNodes: children,
            withScroll: true,
            getNode: manager.getNode,
          );

    if (kIsTestLayout) {
      return DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.green, width: 1),
        ),
        position: DecorationPosition.foreground,
        child: child,
      );
    } else {
      return child;
    }
  }
}
