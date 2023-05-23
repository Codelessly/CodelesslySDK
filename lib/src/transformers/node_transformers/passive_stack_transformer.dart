import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';

import '../../../codelessly_sdk.dart';

class PassiveStackTransformer extends NodeWidgetTransformer<BaseNode> {
  PassiveStackTransformer(super.getNode, super.manager);

  /// Retrieves the widest child from given [siblings].
  BaseNode? getWidestSiblingFromSiblingsList(
      List<BaseNode> siblings, BaseNode parent) {
    if (siblings.isEmpty) return null;

    return siblings.reduce((a, b) {
      // If one of the siblings has alignment, while the other does not,
      // return the one with alignment.
      if (a.alignment != AlignmentModel.none &&
          b.alignment == AlignmentModel.none) {
        return a;
      }
      if (b.alignment != AlignmentModel.none &&
          a.alignment == AlignmentModel.none) {
        return b;
      }

      // If both siblings have alignment or both do not have alignment, compare
      // their widths.
      return a.basicBoxLocal.width > b.basicBoxLocal.width ? a : b;
    });
  }

  /// Retrieves the widest child for given [parent] node.
  BaseNode? getWidestSiblingForParent(BaseNode parent) {
    final List<BaseNode> siblings =
        parent.childrenOrEmpty.map(getNode).toList();
    return getWidestSiblingFromSiblingsList(siblings, parent);
  }

  /// Retrieves the tallest child from given [siblings].
  BaseNode? getTallestSiblingFromSiblingsList(
      List<BaseNode> siblings, BaseNode parent) {
    if (siblings.isEmpty) return null;

    return siblings.reduce((a, b) {
      // If one of the siblings has alignment, while the other does not,
      // return the one with alignment.
      if (a.alignment != AlignmentModel.none &&
          b.alignment == AlignmentModel.none) {
        return a;
      }
      if (b.alignment != AlignmentModel.none &&
          a.alignment == AlignmentModel.none) {
        return b;
      }

      // If both siblings have alignment or both do not have alignment, compare
      // their heights.
      return a.basicBoxLocal.height > b.basicBoxLocal.height ? a : b;
    });
  }

  /// Retrieves the tallest child for given [parent] node.
  BaseNode? getTallestSiblingForParent(BaseNode parent) {
    final List<BaseNode> siblings =
        parent.childrenOrEmpty.map(getNode).toList();
    return getTallestSiblingFromSiblingsList(siblings, parent);
  }

  @override
  Widget buildWidget(
    BaseNode node,
    BuildContext context, [
    WidgetBuildSettings settings = const WidgetBuildSettings(),
  ]) =>
      buildWidgetForChildren(node, context, settings: settings);

  Widget buildWidgetForChildren(
    BaseNode node,
    BuildContext context, {
    List<ValueModel> values = const [],
    List<BaseNode>? childrenNodes,
    WidgetBuildSettings settings = const WidgetBuildSettings(),
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

    final isAllPositioned =
        children.every((node) => node.alignment.data == null);

    final List<Widget> childrenWidgets = [];

    final BaseNode? widestChild = isAllPositioned && node.isHorizontalWrap
        ? getWidestSiblingFromSiblingsList(children, node)
        : null;
    final BaseNode? tallestChild = isAllPositioned && node.isVerticalWrap
        ? getTallestSiblingFromSiblingsList(children, node)
        : null;

    for (final BaseNode childNode in children) {
      Widget child =
          manager.buildWidgetFromNode(childNode, context, settings: settings);

      if (childNode.alignment == AlignmentModel.none) {
        child = wrapWithPositioned(
          childNode,
          node,
          child,
          isWidest: widestChild?.id == childNode.id,
          isTallest: tallestChild?.id == childNode.id,
        );
      } else {
        child = Align(
          alignment: childNode.alignment.flutterAlignment!,
          child: child,
        );
      }
      childrenWidgets.add(child);
    }

    Widget stack = manager
        .getTransformer<PassiveRectangleTransformer>()
        .buildRectangle(node, children: childrenWidgets);

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

    if (isTestLayout) {
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

  Widget wrapWithPositioned(
    BaseNode childNode,
    BaseNode node,
    Widget child, {
    required bool isWidest,
    required bool isTallest,
  }) {
    final double? left = childNode.isHorizontalExpanded
        ? 0
        : childNode.edgePins.left != null
            ? childNode.outerBoxLocal.x - node.innerBoxGlobal.edgeLeft
            : null;
    final double? right = childNode.isHorizontalExpanded
        ? 0
        : childNode.edgePins.right != null
            ? childNode.edgePins.right! - node.innerBoxGlobal.edgeRight
            : null;
    final double? top = childNode.isVerticalExpanded
        ? 0
        : childNode.edgePins.top != null
            ? childNode.outerBoxLocal.y - node.innerBoxGlobal.edgeTop
            : null;
    final double? bottom = childNode.isVerticalExpanded
        ? 0
        : childNode.edgePins.bottom != null
            ? childNode.edgePins.bottom! - node.innerBoxGlobal.edgeBottom
            : null;
    final double? width =
        childNode.isHorizontalExpanded || childNode.isHorizontalWrap
            ? null
            : childNode.outerBoxLocal.width;
    final double? height =
        childNode.isVerticalExpanded || childNode.isVerticalWrap
            ? null
            : childNode.outerBoxLocal.height;

    assert(left == null || right == null || width == null);
    assert(top == null || bottom == null || height == null);

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
  }
}
