import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';

import '../../../codelessly_sdk.dart';

typedef WidgetInserter = Widget Function(Widget child);

class PassiveRowColumnTransformer extends NodeWidgetTransformer<RowColumnNode> {
  PassiveRowColumnTransformer(super.getNode, super.manager);

  /// The gap a row/column puts between consecutive children along its main
  /// axis: [RowColumnNode.itemSpacing], or 0 for other row/column-like nodes.
  static double itemSpacingOf(BaseNode node) => switch (node) {
    RowColumnNode(:final double itemSpacing)
        when itemSpacing.isFinite && itemSpacing > 0 =>
      itemSpacing,
    _ => 0,
  };

  /// Spaces [childrenWidgets] [spacing] apart along [rowColumnNode]'s main
  /// axis, leaving out the children [collapsed] marks: a child a visibility
  /// formula hides (or that is disabled) takes no space, so it takes no gap
  /// either, like CSS `display: none` in a flex box with a `gap`.
  ///
  /// When [collapsed] is null no child can collapse and the gap is Flutter's
  /// own `Flex.spacing` (returned as `spacing`). Otherwise the gaps are built
  /// into the children and the Flex gets no spacing:
  ///
  /// - A child that doesn't flex on the main axis gets the gap before it as
  ///   main-axis padding (or the one after it, when the next child flexes).
  ///   A fixed extent next to a child is exactly what `Flex.spacing` adds, so
  ///   placement is the same for every main-axis alignment and the flex
  ///   children share the same free space.
  /// - Between two flexing children the gap is a box of its own. A flexing
  ///   child takes the free space, so alignment spreads nothing and the box
  ///   lands where `Flex.spacing` would put the gap.
  ///
  /// Every child keeps its wrapper whether it gets a gap or not, and every
  /// child is keyed by its node id, so a child keeps its state while its
  /// siblings collapse and show again.
  static ({List<Widget> children, double spacing}) spaceChildren(
    BaseNode rowColumnNode, {
    required List<Widget> childrenWidgets,
    required List<BaseNode> childrenNodes,
    required double spacing,
    List<bool>? collapsed,
  }) {
    if (spacing <= 0 || childrenWidgets.length < 2) {
      return (children: childrenWidgets, spacing: 0);
    }
    if (collapsed == null) {
      return (children: childrenWidgets, spacing: spacing);
    }
    assert(childrenWidgets.length == childrenNodes.length);
    assert(collapsed.length == childrenNodes.length);

    final bool isRow =
        (rowColumnNode as RowColumnMixin).rowColumnType == RowColumnType.row;
    bool flexes(BaseNode child) =>
        (isRow ? child.horizontalFit : child.verticalFit).isFlex;

    final int count = childrenNodes.length;
    final List<double> leading = List<double>.filled(count, 0);
    final List<double> trailing = List<double>.filled(count, 0);
    // Index of a flexing child -> whether a gap box goes before it.
    final Set<int> boxBefore = {};

    int? previous;
    for (int i = 0; i < count; i++) {
      if (collapsed[i]) continue;
      if (previous != null) {
        if (!flexes(childrenNodes[i])) {
          leading[i] = spacing;
        } else if (!flexes(childrenNodes[previous])) {
          trailing[previous] = spacing;
        } else {
          boxBefore.add(i);
        }
      }
      previous = i;
    }

    final List<Widget> children = [];
    for (int i = 0; i < count; i++) {
      final BaseNode child = childrenNodes[i];
      Widget widget = childrenWidgets[i];
      if (boxBefore.contains(i)) {
        children.add(
          SizedBox(
            key: ValueKey('${child.id}-gap'),
            width: isRow ? spacing : null,
            height: isRow ? null : spacing,
          ),
        );
      }
      if (!flexes(child)) {
        widget = Padding(
          padding: isRow
              ? EdgeInsets.only(left: leading[i], right: trailing[i])
              : EdgeInsets.only(top: leading[i], bottom: trailing[i]),
          child: widget,
        );
      }
      children.add(
        KeyedSubtree(key: ValueKey('${child.id}-spaced'), child: widget),
      );
    }
    return (children: children, spacing: 0);
  }

  static Widget buildRowColumnWidget(
    BaseNode rowColumnNode, {
    required List<Widget> childrenWidgets,
    required List<BaseNode> childrenNodes,
    required bool withScroll,
    required GetNode getNode,
    List<bool>? collapsedChildren,
  }) {
    assert(rowColumnNode is RowColumnMixin);

    final spaced = spaceChildren(
      rowColumnNode,
      childrenWidgets: childrenWidgets,
      childrenNodes: childrenNodes,
      spacing: itemSpacingOf(rowColumnNode),
      collapsed: collapsedChildren,
    );

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

    final FitBox outerBox = FitBox(
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
      key: ValueKey(rowColumnNode.id),
      spacing: spaced.spacing,
      children: spaced.children,
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

  /// Whether [child] may take no space at runtime: a visibility formula or
  /// condition decides whether it shows, or it is disabled.
  bool _mayCollapse(BuildContext context, BaseNode child) {
    final NodeTransformerManager manager = this.manager;
    if (!child.enabled) return true;
    if (manager is! PassiveNodeTransformerManager) return false;
    return manager.runtimeVisibility(context, child) != null ||
        PropertyValueDelegate.getPropertyValue<bool>(
              child,
              'node_enabled',
              scopedValues: ScopedValues.of(context),
            ) !=
            null;
  }

  /// Whether [child] takes no space now (see [_mayCollapse]).
  bool _isCollapsed(BuildContext context, BaseNode child) {
    final NodeTransformerManager manager = this.manager;
    if (manager is! PassiveNodeTransformerManager) return !child.enabled;
    final bool enabled =
        PropertyValueDelegate.getPropertyValue<bool>(
          child,
          'node_enabled',
          scopedValues: ScopedValues.of(context),
        ) ??
        child.enabled;
    return !enabled || manager.runtimeVisibility(context, child) == false;
  }

  @override
  Widget build(BuildContext context) {
    // With a gap, a child that collapses at runtime must give up its gaps
    // too, so the row/column rebuilds when one of them shows or hides.
    final bool spaced = PassiveRowColumnTransformer.itemSpacingOf(node) > 0;
    final List<BaseNode> collapsible = spaced
        ? children.where((child) => _mayCollapse(context, child)).toList()
        : const [];
    if (collapsible.isEmpty) return _build(context, null);

    List<bool> collapsedNow(BuildContext context) => [
      for (final BaseNode child in children)
        collapsible.contains(child) && _isCollapsed(context, child),
    ];

    final NodeTransformerManager manager = this.manager;
    final List<Listenable> listenables =
        manager is PassiveNodeTransformerManager
        ? [
            for (final BaseNode child in collapsible)
              ...manager.listenablesFor(context, child),
          ]
        : const [];
    if (listenables.isEmpty) return _build(context, collapsedNow(context));
    return ManagedListenableBuilder(
      key: ValueKey('${node.id}-spacing'),
      listenables: listenables,
      builder: (context) => _build(context, collapsedNow(context)),
    );
  }

  Widget _build(BuildContext context, List<bool>? collapsedChildren) {
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
                collapsedChildren: collapsedChildren,
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
            collapsedChildren: collapsedChildren,
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
