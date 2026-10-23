import 'dart:math' as math;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';

import '../../../codelessly_sdk.dart';

typedef WidgetInserter = Widget Function(Widget child);

class PassiveRowColumnTransformer extends NodeWidgetTransformer<RowColumnNode> {
  PassiveRowColumnTransformer(super.getNode, super.manager);

  /// Whether [node] is a row/column that wraps its children onto new runs
  /// ([RowColumnNode.wrap]). It renders as a [Wrap] instead of a [Flex].
  static bool wraps(BaseNode node) => node is RowColumnNode && node.wrap;

  /// [Wrap.alignment] for a wrapping row/column's main-axis alignment, which
  /// places the children within each run.
  static WrapAlignment wrapAlignmentOf(MainAxisAlignmentC alignment) =>
      switch (alignment) {
        MainAxisAlignmentC.start => WrapAlignment.start,
        MainAxisAlignmentC.end => WrapAlignment.end,
        MainAxisAlignmentC.center => WrapAlignment.center,
        MainAxisAlignmentC.spaceBetween => WrapAlignment.spaceBetween,
        MainAxisAlignmentC.spaceAround => WrapAlignment.spaceAround,
        MainAxisAlignmentC.spaceEvenly => WrapAlignment.spaceEvenly,
      };

  /// [Wrap.crossAxisAlignment] for a wrapping row/column's cross-axis
  /// alignment, which places each child within its run. A [Wrap] can't
  /// stretch or align baselines; those place children at the run's start,
  /// as the editor lays them out.
  static WrapCrossAlignment wrapCrossAlignmentOf(
    CrossAxisAlignmentC alignment,
  ) => switch (alignment) {
    CrossAxisAlignmentC.center => WrapCrossAlignment.center,
    CrossAxisAlignmentC.end => WrapCrossAlignment.end,
    CrossAxisAlignmentC.start ||
    CrossAxisAlignmentC.stretch ||
    CrossAxisAlignmentC.baseline => WrapCrossAlignment.start,
  };

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

    // A shape pads around this widget, except a scroll view, which puts the
    // padding inside itself. Min and max constraints size the whole box, so
    // the padding outside comes off them here.
    final bool scrolls =
        withScroll &&
        rowColumnNode is ScrollableMixin &&
        (rowColumnNode as ScrollableMixin).isScrollable;
    final EdgeInsetsModel padding =
        rowColumnNode is DefaultShapeNode && !scrolls
        ? rowColumnNode.resolvedPadding()
        : EdgeInsetsModel.zero;

    final FitBox outerBox = FitBox(
      width: _outerExtent(
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
      height: isPlaceholder && rowColumnNode.verticalFit.isFlex
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

    final bool wrapsChildren = wraps(rowColumnNode);

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
      if (stretches || anyChildNeedsAlignment) {
        final bool blocked = childrenNodes.any(
          (child) => subtreeBlocksIntrinsics(child, getNode),
        );
        measureCross = !blocked;
        stretchFallsBack = blocked && stretches;
      }
    }

    Widget res;
    if (wrapsChildren) {
      // Children flow onto new runs. Spacing along a run comes from the
      // children's margins, as in a Row/Column.
      res = Wrap(
        key: ValueKey(rowColumnNode.id),
        direction: isRow ? Axis.horizontal : Axis.vertical,
        alignment: wrapAlignmentOf(rowColumnNode.mainAxisAlignment),
        crossAxisAlignment: wrapCrossAlignmentOf(
          rowColumnNode.crossAxisAlignment,
        ),
        runSpacing: (rowColumnNode as RowColumnNode).runSpacing,
        children: childrenWidgets,
      );
    } else {
      res = CodelesslyFlex(
        direction: isRow ? Axis.horizontal : Axis.vertical,
        mainAxisAlignment: rowColumnNode.mainAxisAlignment.flutterAxis,
        crossAxisAlignment: stretchFallsBack
            ? CrossAxisAlignment.start
            : rowColumnNode.crossAxisAlignment.flutterAxis,
        mainAxisSize: mainFit == SizeFit.shrinkWrap
            ? MainAxisSize.min
            : MainAxisSize.max,
        key: ValueKey(rowColumnNode.id),
        children: childrenWidgets,
      );
    }

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
        padding: rowColumnNode.resolvedPadding().flutterEdgeInsets,
        node: (rowColumnNode as ScrollableMixin),
        fillViewport:
            rowColumnNode.mainAxisAlignment != MainAxisAlignmentC.start,
        flexContent: hasMainAxisFlexChild(rowColumnNode, childrenNodes),
        child: res,
      );
    }

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

  /// The design extent of a Row/Column's own box on one axis, or null when it
  /// hugs its children.
  ///
  /// Fixed and locked take the solved outer size. shrinkWrap hugs (at least
  /// its min constraint). Expanded takes its max constraint when it has one,
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
    SizeFit.shrinkWrap => min == null ? null : math.max(0, min - inset),
    SizeFit.expanded => max == null ? design : math.max(0, max - inset),
    SizeFit.fixed || SizeFit.locked || SizeFit.flexible => design,
  };

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

    if (wraps(parentRowColumn)) {
      return wrapChildInRun(
        node,
        parentRowColumn,
        childWidget,
        flexibleSpaceBackground: flexibleSpaceBackground,
        getNode: getNode,
      );
    }

    if (node is SpacerNode) {
      return childWidget;
    }

    final AxisC mainAxis =
        ((parentRowColumn as RowColumnMixin).rowColumnType == RowColumnType.row
        ? AxisC.horizontal
        : AxisC.vertical);
    final SizeFit mainAxisFit = (mainAxis == AxisC.horizontal
        ? node.horizontalFit
        : node.verticalFit);

    final SizeFit crossAxisFit = (mainAxis == AxisC.horizontal
        ? node.verticalFit
        : node.horizontalFit);

    // A parent that stretches its children across gives each one the full
    // cross axis, like the editor's solver, except a child that hugs on that
    // axis: the solver keeps its own size there and places it at the start.
    final AlignmentGeometry? childAlignment =
        (alignment ?? node.alignment).data?.flutterAlignmentGeometry ??
        (parentRowColumn.crossAxisAlignment == CrossAxisAlignmentC.stretch &&
                crossAxisFit == SizeFit.shrinkWrap
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

    return childWidget;
  }

  /// Sizes a child of a wrapping row/column ([wraps]) for its [Wrap] run.
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
    if (node is SpacerNode) return const SizedBox.shrink();

    if (flexibleSpaceBackground != null) {
      childWidget = flexibleSpaceBackground(childWidget);
    }

    final bool flexesHorizontally = node.horizontalFit.isFlex;
    final bool flexesVertically = node.verticalFit.isFlex;
    if (!flexesHorizontally && !flexesVertically) return childWidget;

    final bool blocked =
        getNode == null || subtreeBlocksIntrinsics(node, getNode);
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

  /// A flexing child hidden at runtime gives up its share of the free space,
  /// so a visible sibling (an empty state next to a hidden spinner) can take
  /// all of it. The flex drops to zero rather than removing the [Flexible] so
  /// the child keeps its state when it shows again.
  Widget _collapseWhenHidden(
    BuildContext context,
    BaseNode child,
    Widget sizedWidget,
  ) {
    final NodeTransformerManager manager = this.manager;
    if (sizedWidget is! Flexible || manager is! PassiveNodeTransformerManager) {
      return sizedWidget;
    }

    Widget buildFlexible(BuildContext context) {
      final bool hidden = manager.runtimeVisibility(context, child) == false;
      // Without flex the hidden child would be laid out with unbounded
      // main-axis constraints, which a scrollable inside it can't take
      // (a hidden grid computed NaN offsets), so it gets no space at all.
      return Flexible(
        flex: hidden ? 0 : sizedWidget.flex,
        fit: sizedWidget.fit,
        child: SizedBox(
          width: hidden ? 0 : null,
          height: hidden ? 0 : null,
          child: sizedWidget.child,
        ),
      );
    }

    final List<Listenable> listenables = manager.listenablesFor(context, child);
    if (listenables.isEmpty) return buildFlexible(context);
    return ManagedListenableBuilder(
      key: ValueKey('${child.id}-flex'),
      listenables: listenables,
      builder: buildFlexible,
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
