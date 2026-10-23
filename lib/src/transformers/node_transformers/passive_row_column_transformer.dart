import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';

import '../../../codelessly_sdk.dart';

typedef WidgetInserter = Widget Function(Widget child);

class PassiveRowColumnTransformer extends NodeWidgetTransformer<RowColumnNode> {
  PassiveRowColumnTransformer(super.getNode, super.manager);

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

    final FitBox outerBox = FitBox(
      width: contentSized && isRow
          ? null
          : _outerExtent(
              rowColumnNode.horizontalFit,
              design: rowColumnNode.outerBoxLocal.width,
              min: rowColumnNode.constraints.minWidth,
              max: rowColumnNode.constraints.maxWidth,
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
            ),
      fillHeight:
          !(isPlaceholder && rowColumnNode.verticalFit.isFlex) &&
          _fillsAxis(
            rowColumnNode.verticalFit,
            max: rowColumnNode.constraints.maxHeight,
          ),
    );

    if (rowColumnNode.wrap) {
      return _withOuterBox(
        outerBox,
        _buildWrap(rowColumnNode, childrenWidgets, withScroll: withScroll),
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
    if (crossMin == null && crossWraps) {
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

    Widget res = CodelesslyFlex(
      direction: isRow ? Axis.horizontal : Axis.vertical,
      mainAxisAlignment: rowColumnNode.mainAxisAlignment.flutterAxis,
      crossAxisAlignment: stretchFallsBack
          ? CrossAxisAlignment.start
          : rowColumnNode.crossAxisAlignment.flutterAxis,
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

    if (withScroll &&
        rowColumnNode is ScrollableMixin &&
        (rowColumnNode as ScrollableMixin).isScrollable) {
      res = wrapWithPaddedScrollable(
        padding: rowColumnNode.resolvedPadding().flutterEdgeInsets,
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

    return _withOuterBox(outerBox, res);
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
          padding: node.resolvedPadding().flutterEdgeInsets,
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
  /// Fixed and locked take the solved outer size. shrinkWrap hugs (at least
  /// its min constraint). Expanded takes its max constraint when it has one,
  /// and otherwise fills a bounded axis or takes its design size on an
  /// unbounded one. Flexible takes its design size, as leaves do: its
  /// [Flexible] parent lets it get smaller, never larger, matching the
  /// editor's `min(flex share, design size)`.
  static double? _outerExtent(
    SizeFit fit, {
    required double design,
    required double? min,
    required double? max,
  }) => switch (fit) {
    SizeFit.shrinkWrap => min,
    SizeFit.expanded => max ?? design,
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
  }) {
    assert(parentRowColumn is RowColumnMixin);

    if ((parentRowColumn as RowColumnMixin).wrap) {
      return _wrapChild(
        node,
        parentRowColumn,
        childWidget,
        flexibleSpaceBackground: flexibleSpaceBackground,
      );
    }

    if (node is SpacerNode) {
      return childWidget;
    }

    final AxisC mainAxis = (parentRowColumn.rowColumnType == RowColumnType.row
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

  /// A child of a wrapping row/column. Children of a [Wrap] can't flex: one
  /// that is expanded or flexible along the main axis keeps its design size
  /// there, like a fixed child (a [Wrap] would otherwise let it fill a whole
  /// run). Across, a [Wrap] gives an unbounded extent, where an expanded
  /// child takes its design size too (see [FitBox]). A spacer is a gap of its
  /// design length. A child's own alignment does not apply in a wrap.
  static Widget _wrapChild(
    BaseNode node,
    RowColumnMixin parent,
    Widget childWidget, {
    WidgetInserter? flexibleSpaceBackground,
  }) {
    if (flexibleSpaceBackground != null) {
      childWidget = flexibleSpaceBackground(childWidget);
    }
    final bool isRow = parent.rowColumnType == RowColumnType.row;
    // A spacer is a gap of its design length, with no thickness.
    if (node is SpacerNode) {
      return SizedBox(
        width: isRow ? node.outerBoxLocal.width : 0,
        height: isRow ? 0 : node.outerBoxLocal.height,
      );
    }
    final SizeFit mainFit = isRow ? node.horizontalFit : node.verticalFit;
    if (!mainFit.isFlex) return childWidget;
    return SizedBox(
      width: isRow ? node.outerBoxLocal.width : null,
      height: isRow ? null : node.outerBoxLocal.height,
      child: childWidget,
    );
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
    if (manager is! PassiveNodeTransformerManager) {
      return FlexChildVisibility(collapsed: false, child: sizedWidget);
    }

    Widget buildChild(BuildContext context) {
      final bool hidden = manager.runtimeVisibility(context, child) == false;
      if (sizedWidget is! Flexible) {
        return FlexChildVisibility(collapsed: hidden, child: sizedWidget);
      }
      // Without flex the hidden child would be laid out with unbounded
      // main-axis constraints, which a scrollable inside it can't take
      // (a hidden grid computed NaN offsets), so it gets no space at all.
      return FlexChildVisibility(
        collapsed: hidden,
        child: Flexible(
          flex: hidden ? 0 : sizedWidget.flex,
          fit: sizedWidget.fit,
          child: SizedBox(
            width: hidden ? 0 : null,
            height: hidden ? 0 : null,
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
