import 'dart:math' as math;

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
    AxisC? scrollAxis,
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
      placement: placementFor(
        withBoundSize(context, node),
        parent,
        scrollAxis: scrollAxis,
      ),
      child: child,
    );
  }

  /// [node] with the `width` and `height` its variables, formulas or
  /// conditions give it, so the parent places it at that size (a meter's
  /// fill, a to-scale dimension line). [node] itself when neither is bound.
  static BaseNode withBoundSize(BuildContext context, BaseNode node) {
    final ScopedValues scopedValues = ScopedValues.of(context);
    final CodelesslyContext? codelesslyContext = scopedValues.codelesslyContext;
    bool bound(String property) =>
        node.variables.containsKey(property) ||
        codelesslyContext?.conditions.findByNodeProperty(node.id, property) !=
            null;
    if (!bound('width') && !bound('height')) return node;
    double? value(String property) {
      final num? v = PropertyValueDelegate.getPropertyValue<num>(
        node,
        property,
        scopedValues: scopedValues,
      );
      return v != null && v.isFinite ? math.max(0, v.toDouble()) : null;
    }

    final NodeBox box = node.basicBoxLocal;
    final double width = value('width') ?? box.width;
    final double height = value('height') ?? box.height;
    if (width == box.width && height == box.height) return node;
    final BaseNode? sized = NodeJsonConverter().fromJson({
      ...node.toJson(),
      'basicBoxLocal': NodeBox(box.x, box.y, width, height).toJson(),
    });
    if (sized == null) return node;
    return sized..parentID = node.parentID;
  }

  /// How [node] is placed inside the freeform container [parent], derived
  /// from the same data the editor's solver uses:
  ///
  /// - An aligned node is aligned inside the parent's padded box
  ///   (`FreeFormAlignmentDecorator`).
  /// - A node expanded on an axis without a max constraint fills that axis.
  /// - A node pinned to both edges of an axis and not shrink-wrapping on it
  ///   stretches between the pins (the editor's "chained" sizing).
  /// - A shrink-wrapping node pinned to both edges sizes itself, as in the
  ///   editor (it is not chained), and keeps its share of the free space
  ///   between the pins, so a node centred between them stays centred.
  /// - A node pinned only to the end edge keeps its distance from that edge.
  /// - A node pinned only to the start edge keeps its distance from it when
  ///   its [PositioningMode] is [PositioningMode.pin]. In
  ///   [PositioningMode.align] (the default for anything dropped into a
  ///   freeform container, whose pins are just its design x/y), it keeps its
  ///   share of the free space, like [Align], so the layout spreads with a
  ///   wider parent instead of clustering at the top left.
  /// - Along [scrollAxis] (see [scrollAxisFor]), children are content: they
  ///   keep their design offset, and their design size is only a minimum so
  ///   content that grows at runtime can be scrolled to.
  ///
  /// At design size every rule gives the design position and size.
  static FreeformPlacement placementFor(
    BaseNode node,
    BaseNode parent, {
    AxisC? scrollAxis,
  }) {
    if (parent is ScrollableMixin && parent.isScrollable) {
      scrollAxis ??= parent.scrollDirection;
    }
    final bool scrolls = scrollAxis != null;
    final bool verticalScroll = scrollAxis == AxisC.vertical;
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

    // Pins are distances from the parent's middle box; children are laid out
    // in its padded (inner) box.
    final EdgePinsModel pins = node.edgePins;
    final double? startPin = switch (horizontal ? pins.left : pins.top) {
      final double pin =>
        pin -
            (horizontal
                ? parent.innerBoxLocal.edgeLeft
                : parent.innerBoxLocal.edgeTop),
      null => null,
    };
    final double? endPin = switch (horizontal ? pins.right : pins.bottom) {
      final double pin =>
        pin -
            (horizontal
                ? parent.innerBoxLocal.edgeRight
                : parent.innerBoxLocal.edgeBottom),
      null => null,
    };
    final bool pinnedStart = startPin != null;
    final bool pinnedEnd = endPin != null;

    // Where the child starts on this axis at design size. A pinned axis is
    // placed by its pins alone, never by the stored box, which the editor can
    // leave stale (for example after a canvas resize it did not re-solve).
    // The stored box origin is only used where the pins are just the design
    // x/y: align positioning mode with no end pin, and nothing pinned.
    final bool placedByPins =
        pinnedEnd || node.positioningMode == PositioningMode.pin;
    final double start;
    if (placedByPins && startPin != null) {
      start = startPin;
    } else if (placedByPins && endPin != null) {
      start = parentExtent - endPin - extent;
    } else {
      start = horizontal
          ? node.outerBoxLocal.x - parent.innerBoxLocal.edgeLeft
          : node.outerBoxLocal.y - parent.innerBoxLocal.edgeTop;
    }

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
      growsWithContent: node is TextNode,
    );

    if (node.alignment.data case final AlignmentData alignment) {
      return placement(
        FreeformAxisMode.align,
        alignment: horizontal ? alignment.x : alignment.y,
      );
    }
    if (expands) return placement(FreeformAxisMode.fill);
    if (isScrollAxis) return placement(FreeformAxisMode.start);

    final bool parentWraps = horizontal
        ? parent.isHorizontalWrap
        : parent.isVerticalWrap;

    if (startPin != null && endPin != null && !wraps) {
      // Chained sizing: the pins decide the extent, not the stored box.
      final double? minConstraint = horizontal
          ? node.resolvedConstraints.minWidth
          : node.resolvedConstraints.minHeight;
      return FreeformAxisPlacement(
        mode: FreeformAxisMode.stretch,
        start: startPin,
        extent: parentExtent - startPin - endPin,
        parentExtent: parentExtent,
        clamp: !isScrollAxis,
        growsWithContent: node is TextNode,
        minSize: minConstraint == null
            ? 0
            : minConstraint +
                  (horizontal
                      ? node.outerBoxLocal.horizontalEdgeSpace
                      : node.outerBoxLocal.verticalEdgeSpace),
      );
    }
    if (startPin != null && endPin != null && !parentWraps) {
      // A shrink-wrapping child between two pins keeps the pins' ratio of
      // the free space around its own size: centred between equal pins.
      final double pinned = math.max(0, startPin) + math.max(0, endPin);
      if (pinned > 0) {
        return placement(
          FreeformAxisMode.align,
          alignment: 2 * math.max(0, startPin) / pinned - 1,
        );
      }
    }
    if (pinnedEnd && !pinnedStart) return placement(FreeformAxisMode.end);
    if (!pinnedEnd &&
        !parentWraps &&
        node.positioningMode == PositioningMode.align) {
      return placement(FreeformAxisMode.relative);
    }
    return placement(FreeformAxisMode.start);
  }

  /// The axis along which the children of [node] scroll: its own scroll
  /// direction when it scrolls, or the canvas's when [node] is the body of a
  /// scrolling canvas (the canvas scrolls its body as content).
  AxisC? scrollAxisFor(BaseNode node) {
    if (node is ScrollableMixin && node.isScrollable) {
      return node.scrollDirection;
    }
    if (node.id == kRootNode || node.parentID == kRootNode) return null;
    final BaseNode parent = getNode(node.parentID);
    if (parent is CanvasNode &&
        parent.properties.bodyId == node.id &&
        parent.isScrollable) {
      return parent.scrollDirection;
    }
    return null;
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

    final AxisC? scrollAxis = scrollAxisFor(node);
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
              scrollAxis: scrollAxis,
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
