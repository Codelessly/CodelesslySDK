import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';

import '../../../codelessly_sdk.dart';

class PassiveStackTransformer extends NodeWidgetTransformer<BaseNode> {
  PassiveStackTransformer(super.getNode, super.manager);

  /// Builds [node] as a child of the freeform container [parent], placed by
  /// [placementFor].
  static Widget buildStackChild(
    BaseNode node,
    BaseNode parent,
    BuildContext context, {
    WidgetNodeTransformerManager? manager,
    Widget? childWidget,
    required WidgetBuildSettings settings,
  }) {
    assert(
      childWidget != null || manager != null,
      'Either childWidget or manager must be provided.',
    );

    final Widget child =
        childWidget ??
        manager!.buildWidgetFromNode(node, context, settings: settings);

    return FreeformChild(
      key: ValueKey(
        'Static Stack child [${node.id}](${node.name})<${node.type}> on parent [${parent.id}](${parent.name})<${parent.type}>',
      ),
      placement: placementFor(node, parent),
      child: child,
    );
  }

  /// How [node] is placed inside the freeform container [parent], derived
  /// from the same data the editor's solver uses:
  ///
  /// - An aligned node is aligned inside the parent's padded box
  ///   (`FreeFormAlignmentDecorator`).
  /// - A node expanded on an axis without a max constraint fills that axis.
  /// - A node pinned to both edges of an axis and not shrink-wrapping on it
  ///   stretches between the pins (the editor's "chained" sizing).
  /// - A node pinned only to the end edge keeps its distance from that edge.
  /// - A node pinned only to the start edge keeps its distance from it when
  ///   its [PositioningMode] is [PositioningMode.pin]. In
  ///   [PositioningMode.align] (the default for anything dropped into a
  ///   freeform container, whose pins are just its design x/y), it keeps its
  ///   share of the free space, like [Align], so the layout spreads with a
  ///   wider parent instead of clustering at the top left.
  /// - Along the scroll axis of a scrolling parent, children are content and
  ///   keep their design offset.
  ///
  /// At design size every rule gives the design position and size.
  static FreeformPlacement placementFor(BaseNode node, BaseNode parent) {
    final bool scrolls = parent is ScrollableMixin && parent.isScrollable;
    final bool verticalScroll = scrolls && parent.scrollDirection.isVertical;
    return FreeformPlacement(
      horizontal: _axisPlacement(
        node,
        parent,
        horizontal: true,
        isScrollAxis: scrolls && !verticalScroll,
      ),
      vertical: _axisPlacement(
        node,
        parent,
        horizontal: false,
        isScrollAxis: verticalScroll,
      ),
    );
  }

  static FreeformAxisPlacement _axisPlacement(
    BaseNode node,
    BaseNode parent, {
    required bool horizontal,
    required bool isScrollAxis,
  }) {
    final double start = horizontal
        ? node.outerBoxLocal.x - parent.innerBoxLocal.edgeLeft
        : node.outerBoxLocal.y - parent.innerBoxLocal.edgeTop;
    final double extent = horizontal
        ? node.outerBoxLocal.width
        : node.outerBoxLocal.height;
    final double parentExtent = horizontal
        ? parent.innerBoxLocal.width
        : parent.innerBoxLocal.height;
    final SizeFit fit = horizontal ? node.horizontalFit : node.verticalFit;
    final bool expands =
        fit == SizeFit.expanded &&
        (horizontal
                ? node.resolvedConstraints.maxWidth
                : node.resolvedConstraints.maxHeight) ==
            null;
    final bool wraps = fit == SizeFit.shrinkWrap;
    final double? size = wraps || expands ? null : extent;

    FreeformAxisPlacement placement(
      FreeformAxisMode mode, {
      double alignment = 0,
    }) => FreeformAxisPlacement(
      mode: mode,
      start: start,
      extent: extent,
      parentExtent: parentExtent,
      size: size,
      alignment: alignment,
      clamp: !isScrollAxis,
      expands: expands,
    );

    if (node.alignment.data case final AlignmentData alignment) {
      return placement(
        FreeformAxisMode.align,
        alignment: horizontal ? alignment.x : alignment.y,
      );
    }
    if (expands) return placement(FreeformAxisMode.fill);
    if (isScrollAxis) return placement(FreeformAxisMode.start);

    final EdgePinsModel pins = node.edgePins;
    final bool pinnedStart = (horizontal ? pins.left : pins.top) != null;
    final bool pinnedEnd = (horizontal ? pins.right : pins.bottom) != null;
    final bool parentWraps = horizontal
        ? parent.isHorizontalWrap
        : parent.isVerticalWrap;

    if (pinnedStart && pinnedEnd && !wraps) {
      return placement(FreeformAxisMode.stretch);
    }
    if (pinnedEnd && !pinnedStart) return placement(FreeformAxisMode.end);
    if (!pinnedEnd &&
        !parentWraps &&
        node.positioningMode == PositioningMode.align) {
      return placement(FreeformAxisMode.relative);
    }
    return placement(FreeformAxisMode.start);
  }

  @override
  Widget buildWidget(
    BaseNode node,
    BuildContext context,
    WidgetBuildSettings settings,
  ) => buildWidgetForChildren(node, context, settings: settings);

  Widget buildWidgetForChildren(
    BaseNode node,
    BuildContext context, {
    List<ValueModel> values = const [],
    List<BaseNode>? childrenNodes,
    required WidgetBuildSettings settings,
  }) {
    if (node is! ChildrenMixin) {
      throw Exception(
        'PassiveStackTransformer can only be used on nodes that implement ChildrenMixin',
      );
    }

    final List<BaseNode> children = [
      if (childrenNodes != null)
        ...childrenNodes
      else
        for (final String childId in node.children) getNode(childId),
    ];

    final List<Widget> childrenWidgets = [
      FreeformLayout(
        wrapsWidth: node.isHorizontalWrap,
        wrapsHeight: node.isVerticalWrap,
        designSize: node.innerBoxLocal.size.flutterSize,
        children: [
          for (final BaseNode childNode in children)
            buildStackChild(
              childNode,
              node,
              context,
              manager: manager,
              settings: settings,
            ),
        ],
      ),
    ];

    Widget stack = manager
        .getTransformer<PassiveRectangleTransformer>()
        .buildRectangle(node, children: childrenWidgets, settings: settings);

    if (kIsTestLayout) {
      return DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.yellow, width: 2),
        ),
        position: DecorationPosition.foreground,
        child: stack,
      );
    } else {
      return stack;
    }
  }
}
