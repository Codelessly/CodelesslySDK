import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';

import '../../../codelessly_sdk.dart';

class PassiveStackTransformer extends NodeWidgetTransformer<BaseNode> {
  PassiveStackTransformer(super.getNode, super.manager);

  static Widget buildStackChild(
    BaseNode node,
    BaseNode parent,
    BuildContext context, {
    WidgetNodeTransformerManager? manager,
    Widget? childWidget,
    required BaseNode? widestChild,
    required BaseNode? tallestChild,
    required AlignmentModel commonAlignment,
    required WidgetBuildSettings settings,
  }) {
    assert(childWidget != null || manager != null,
        'Either childWidget or manager must be provided.');

    Widget child = childWidget ??
        manager!.buildWidgetFromNode(node, context, settings: settings);

    final bool shouldWrapWithPositioned =
        node.alignment == AlignmentModel.none ||
            (parent.isOneOrBothWrap && node.alignment != commonAlignment);

    // TODO: Put this in codegen too.
    if (shouldWrapWithPositioned) {
      // You cannot use the Align widget when inside a shrink-wrapping Stack.
      // The Align RenderBox will force the Stack to grow as much as possible.
      // Positioned widgets are only laid out after the Stack lays out its
      // concrete children and figures out its own size. So for wrapping stacks,
      // we need to use Positioned instead of Align.
      //
      // The behavior is absolutely different, but it's the best compromise we
      // can do.
      if (node.alignment != AlignmentModel.none) {
        final align = node.alignment.data!;

        child = Positioned(
          left: align.x <= 0
              ? node.outerBoxLocal.left - parent.innerBoxLocal.edgeLeft
              : null,
          right: align.x >= 0
              ? (parent.innerBoxLocal.width - node.outerBoxLocal.right) +
                  parent.innerBoxLocal.edgeRight
              : null,
          top: align.y <= 0
              ? node.outerBoxLocal.top - parent.innerBoxLocal.edgeTop
              : null,
          bottom: align.y >= 0
              ? (parent.innerBoxLocal.height - node.outerBoxLocal.bottom) +
                  parent.innerBoxLocal.edgeBottom
              : null,
          child: child,
        );
      } else {
        child = wrapWithPositioned(
          node,
          parent,
          child,
          isWidest: widestChild?.id == node.id,
          isTallest: tallestChild?.id == node.id,
        );
      }
    } else {
      if (node.alignment != commonAlignment) {
        child = Align(
          alignment: node.alignment.flutterAlignment!,
          child: child,
        );
      }
    }

    return KeyedSubtree(
      key: ValueKey(
        'Static Stack child [${node.id}](${node.name})<${node.type}> on parent [${parent.id}](${parent.name})<${parent.type}>',
      ),
      child: child,
    );
  }

  /// Wraps a child with a [Positioned] widget. Does not wrap if the child
  /// is the widest or tallest child.
  static Widget wrapWithPositioned(
    BaseNode childNode,
    BaseNode node,
    Widget child, {
    required bool isWidest,
    required bool isTallest,
  }) {
    final bool horizontallyExpands = childNode.isHorizontalExpanded &&
        childNode.resolvedConstraints.maxWidth == null;
    final bool verticallyExpands = childNode.isVerticalExpanded &&
        childNode.resolvedConstraints.maxHeight == null;

    final double? left = horizontallyExpands
        ? 0
        : childNode.edgePins.left != null
            ? childNode.outerBoxLocal.x - node.innerBoxGlobal.edgeLeft
            : null;
    final double? right = horizontallyExpands
        ? 0
        : childNode.edgePins.right != null
            ? childNode.edgePins.right! - node.innerBoxGlobal.edgeRight
            : null;
    final double? top = verticallyExpands
        ? 0
        : childNode.edgePins.top != null
            ? childNode.outerBoxLocal.y - node.innerBoxGlobal.edgeTop
            : null;
    final double? bottom = verticallyExpands
        ? 0
        : childNode.edgePins.bottom != null
            ? childNode.edgePins.bottom! - node.innerBoxGlobal.edgeBottom
            : null;
    final double? width = horizontallyExpands ||
            childNode.isHorizontalWrap ||
            childNode.edgePins.isHorizontallyExpanded
        ? null
        : childNode.outerBoxLocal.width;
    final double? height = verticallyExpands ||
            childNode.isVerticalWrap ||
            childNode.edgePins.isVerticallyExpanded
        ? null
        : childNode.outerBoxLocal.height;

    // This is required to make wrapping stack in a scroll view work because
    // wrapping stack cannot figure out its size when there only positioned
    // children.
    if (!isTallest && !isWidest) {
      return Positioned(
        left: left,
        right: right,
        top: top,
        bottom: bottom,
        width: width,
        height: height,
        child: child,
      );
    } else if (isTallest) {
      return Padding(
        padding: EdgeInsets.only(left: left ?? 0, right: right ?? 0),
        child: child,
      );
    } else {
      return Padding(
        padding: EdgeInsets.only(top: top ?? 0, bottom: bottom ?? 0),
        child: child,
      );
    }

    // return Positioned(
    //   left: left,
    //   right: right,
    //   top: top,
    //   bottom: bottom,
    //   width: width,
    //   height: height,
    //   child: child,
    // );
  }

  @override
  Widget buildWidget(
    BaseNode node,
    BuildContext context,
    WidgetBuildSettings settings,
  ) =>
      buildWidgetForChildren(node, context, settings: settings);

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

    final AlignmentModel commonAlignment =
        retrieveCommonStackAlignment(node, children);
    final isAllPositioned =
        children.every((node) => node.alignment.data == null);

    final List<Widget> childrenWidgets = [];

    final BaseNode? widestChild = isAllPositioned && node.isHorizontalWrap
        ? getWidestNode(children)
        : null;
    final BaseNode? tallestChild = isAllPositioned && node.isVerticalWrap
        ? getTallestNode(children)
        : null;

    for (final BaseNode childNode in children) {
      final Widget child = buildStackChild(
        childNode,
        node,
        context,
        widestChild: widestChild,
        tallestChild: tallestChild,
        commonAlignment: commonAlignment,
        manager: manager,
        settings: settings,
      );
      childrenWidgets.add(child);
    }

    Widget stack =
        manager.getTransformer<PassiveRectangleTransformer>().buildRectangle(
              node,
              stackAlignment: commonAlignment,
              children: childrenWidgets,
              settings: settings,
            );

    // // This makes sure that children stay positioned correctly even if the stack
    // // is shrink wrapping. It makes it so the stack sizes itself to its tallest
    // // or widest child as a "best" size.
    // if (node.isOneWrap) {
    //   return SizedBox(
    //     width: node.isHorizontalWrap ? widestChild?.outerBoxLocal.width : null,
    //     height: node.isVerticalWrap ? tallestChild?.outerBoxLocal.height : null,
    //     child: stack,
    //   );
    // }

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
