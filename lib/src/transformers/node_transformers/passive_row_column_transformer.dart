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

    FitBox outerBox = FitBox(
      aspectRatio: lockedAspectRatio(rowColumnNode),
      width: _outerExtent(
        rowColumnNode.horizontalFit,
        design: rowColumnNode.outerBoxLocal.width,
        min: rowColumnNode.constraints.minWidth,
        max: rowColumnNode.constraints.maxWidth,
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

    // A scrolling Row/Column that is flexible along its scroll axis (Flutter's
    // Flexible around a scroll view) is as long as its content, up to the
    // space its parent leaves it, and scrolls past that, rather than taking
    // its design size. Where that axis is unbounded it keeps its design size.
    final bool hugsScrollAxis = withScroll && hugsItsScrollAxis(rowColumnNode);
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
        fillViewport:
            rowColumnNode.mainAxisAlignment != MainAxisAlignmentC.start,
        flexContent: hasMainAxisFlexChild(rowColumnNode, childrenNodes),
        hugScrollAxis: hugsScrollAxis,
        child: res,
      );
    }

    if (hugsScrollAxis) {
      final Widget content = res;
      final double design = isRow
          ? rowColumnNode.outerBoxLocal.width
          : rowColumnNode.outerBoxLocal.height;
      res = LayoutBuilder(
        builder: (context, constraints) {
          final bool bounded = isRow
              ? constraints.hasBoundedWidth
              : constraints.hasBoundedHeight;
          if (bounded) return content;
          return SizedBox(
            width: isRow ? design : null,
            height: isRow ? null : design,
            child: content,
          );
        },
      );
      outerBox = FitBox(
        aspectRatio: outerBox.aspectRatio,
        width: isRow ? null : outerBox.width,
        height: isRow ? outerBox.height : null,
        fillWidth: !isRow && outerBox.fillWidth,
        fillHeight: isRow && outerBox.fillHeight,
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
      aspectRatio: outerBox.aspectRatio,
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

  /// Whether [node] is a scrolling Row/Column that is flexible along its
  /// scroll axis: it is then as long as its content, up to the space its
  /// parent leaves it, like a scroll view in Flutter's [Flexible].
  static bool hugsItsScrollAxis(BaseNode node) {
    if (node is! RowColumnMixin || node is! ScrollableMixin) return false;
    if (!(node as ScrollableMixin).isScrollable) return false;
    // A wrapping one scrolls across its runs; its main axis wraps instead.
    if (node.wrap) return false;
    final bool isRow = node.rowColumnType == RowColumnType.row;
    return (isRow ? node.horizontalFit : node.verticalFit) == SizeFit.flexible;
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
  ///
  /// A flexing child's bound `flex` (see
  /// [PassiveNodeTransformerManager.applyStyleOverrides]) is its share here,
  /// and a bound flex of zero or less collapses it like a hidden child: a
  /// bar segment for a count of 0 takes no space.
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
      bool hidden = manager.runtimeVisibility(context, child) == false;
      if (sizedWidget is! Flexible) {
        return FlexChildVisibility(collapsed: hidden, child: sizedWidget);
      }
      final int? boundFlex = _boundFlex(context, child);
      if (boundFlex != null && boundFlex <= 0) hidden = true;
      // Without flex the hidden child would be laid out with unbounded
      // main-axis constraints, which a scrollable inside it can't take
      // (a hidden grid computed NaN offsets), so it gets no space at all.
      return FlexChildVisibility(
        collapsed: hidden,
        child: Flexible(
          flex: hidden ? 0 : boundFlex ?? sizedWidget.flex,
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

  /// The flex a variable, formula or condition binds [child]'s `flex` to,
  /// rounded, or null when it isn't bound.
  ///
  /// The child's own widget gets it through
  /// [PassiveNodeTransformerManager.applyStyleOverrides], but its [Flexible]
  /// is built here, from the design flex, so the row/column reads it too.
  static int? _boundFlex(BuildContext context, BaseNode child) {
    final num? flex = PropertyValueDelegate.getPropertyValue<num>(
      child,
      'flex',
      scopedValues: ScopedValues.of(context),
    );
    if (flex == null || !flex.isFinite) return null;
    return flex.round();
  }

  /// The main-axis margins (leading, trailing) of a [child] that flexes on
  /// this row/column's main axis, or null when it doesn't flex or has none.
  ///
  /// A flex child's margin is fixed space, like a gap box between children,
  /// so it doesn't come out of the child's flex share: four `flex: 1` tiles
  /// with an 8 px margin between them are all the same width. A wrapping
  /// row/column's children don't flex, so their margins stay theirs.
  (double, double)? _flexMainMargins(BaseNode child) {
    if (child is SpacerNode) return null;
    final RowColumnMixin rowColumn = node as RowColumnMixin;
    if (rowColumn.wrap) return null;
    final bool isRow = rowColumn.rowColumnType == RowColumnType.row;
    final SizeFit mainFit = isRow ? child.horizontalFit : child.verticalFit;
    if (!mainFit.isFlex) return null;
    final EdgeInsetsModel m = child.margin;
    final (double lead, double trail) = isRow ? (m.l, m.r) : (m.t, m.b);
    if (lead == 0 && trail == 0) return null;
    return (lead, trail);
  }

  /// A fixed gap that stands in for a flex [child]'s main-axis margin, gone
  /// while the child is hidden or its bound flex takes no space.
  ///
  /// The gap belongs to its child, so it tells the [CodelesslyFlex] it is
  /// collapsed: the row/column's spacing goes around the child and its
  /// margins, not between them.
  Widget _marginGap(
    BuildContext context,
    BaseNode child,
    double extent, {
    required bool leading,
  }) {
    final bool isRow =
        (node as RowColumnMixin).rowColumnType == RowColumnType.row;
    final NodeTransformerManager manager = this.manager;
    Widget buildGap(BuildContext context) {
      bool hidden = false;
      if (manager is PassiveNodeTransformerManager) {
        final int? boundFlex = _boundFlex(context, child);
        hidden =
            manager.runtimeVisibility(context, child) == false ||
            (boundFlex != null && boundFlex <= 0);
      }
      final double size = hidden ? 0 : extent;
      return FlexChildVisibility(
        collapsed: true,
        child: SizedBox(
          width: isRow ? size : null,
          height: isRow ? null : size,
        ),
      );
    }

    if (manager is! PassiveNodeTransformerManager) return buildGap(context);
    final List<Listenable> listenables = manager.listenablesFor(context, child);
    if (listenables.isEmpty) return buildGap(context);
    return ManagedListenableBuilder(
      key: ValueKey('${child.id}-${leading ? 'lead' : 'trail'}-margin'),
      listenables: listenables,
      builder: buildGap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isRow =
        (node as RowColumnMixin).rowColumnType == RowColumnType.row;
    final List<Widget> widgetChildren = [];
    for (final BaseNode child in children) {
      final (double, double)? mainMargins = _flexMainMargins(child);
      BaseNode built = child;
      if (mainMargins != null) {
        // The child is built without its main-axis margin, which becomes
        // gaps outside its Flexible.
        final EdgeInsetsModel m = child.margin;
        final EdgeInsetsModel crossMargin = isRow
            ? EdgeInsetsModel.only(top: m.t, bottom: m.b)
            : EdgeInsetsModel.only(left: m.l, right: m.r);
        final BaseNode? copy = NodeJsonConverter().fromJson({
          ...child.toJson(),
          'margin': crossMargin.toJson(),
        });
        if (copy != null) built = copy..parentID = child.parentID;
      }
      final Widget builtWidget = identical(built, child)
          ? manager.buildWidgetByID(child.id, context, settings: settings)
          : manager.buildWidgetFromNode(built, context, settings: settings);

      final Widget sizedWidget =
          PassiveRowColumnTransformer.wrapChildWithSizeFits(
            child,
            node,
            builtWidget,
            child.flex,
          );
      if (mainMargins != null && mainMargins.$1 > 0) {
        widgetChildren.add(
          _marginGap(context, child, mainMargins.$1, leading: true),
        );
      }
      widgetChildren.add(_collapseWhenHidden(context, child, sizedWidget));
      if (mainMargins != null && mainMargins.$2 > 0) {
        widgetChildren.add(
          _marginGap(context, child, mainMargins.$2, leading: false),
        );
      }
    }

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
