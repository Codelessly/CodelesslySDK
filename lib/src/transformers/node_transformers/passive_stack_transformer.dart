import 'package:codelessly_api/codelessly_api.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import '../../../codelessly_sdk.dart';

class PassiveStackTransformer extends NodeWidgetTransformer<BaseNode> {
  PassiveStackTransformer(super.getNode, super.manager);

  /// Retrieves the widest child from given [siblings].
  BaseNode? getWidestSiblingFromSiblingsList(
      List<BaseNode> siblings, BaseNode parent) {
    if (siblings.isEmpty) return null;

    final BaseNode? firstSibling = parent is! RowColumnMixin
        ? siblings.firstWhereOrNull((element) => element.alignment.data != null)
        : siblings.first;
    if (firstSibling == null) return null;
    return siblings.fold<BaseNode>(
        firstSibling,
        (previousValue, element) => (parent is RowColumnMixin ||
                    element.alignment.data != null) &&
                element.basicBoxLocal.width > previousValue.basicBoxLocal.width
            ? element
            : previousValue);
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

    final BaseNode? firstSibling = parent is! RowColumnMixin
        ? siblings.firstWhereOrNull((element) => element.alignment.data != null)
        : siblings.first;
    if (firstSibling == null) return null;

    return siblings.fold<BaseNode>(
        firstSibling,
        (previousValue, element) =>
            (parent is RowColumnMixin || element.alignment.data != null) &&
                    element.basicBoxLocal.height >
                        previousValue.basicBoxLocal.height
                ? element
                : previousValue);
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
      return const SizedBox(child: Icon(Icons.error));
    }

    final List<BaseNode> children = [];

    if (childrenNodes == null) {
      for (final String childId in node.children) {
        children.add(getNode(childId));
      }
    } else {
      children.addAll(childrenNodes);
    }

    final BaseNode? widestChild =
        getWidestSiblingFromSiblingsList(children, node);
    final BaseNode? tallestChild =
        getTallestSiblingFromSiblingsList(children, node);

    final List<Widget> childrenWidgets = [];
    for (final BaseNode childNode in children) {
      Widget child =
          manager.buildWidgetFromNode(childNode, context, settings: settings);

      if (childNode.alignment == AlignmentModel.none) {
        child = wrapWithPositioned(childNode, node, child);
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

    // This makes sure that children stay positioned correctly even if the stack
    // is shrink wrapping. It makes it so the stack sizes itself to its tallest
    // or widest child as a "best" size.
    if (node.isOneWrap) {
      return SizedBox(
        width: node.isHorizontalWrap ? widestChild?.outerBoxLocal.width : null,
        height: node.isVerticalWrap ? tallestChild?.outerBoxLocal.height : null,
        child: stack,
      );
    }

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

  Widget wrapWithPositioned(BaseNode childNode, BaseNode node, Widget child) {
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

    return Positioned(
      left: left,
      right: right,
      top: top,
      bottom: bottom,
      width: width,
      height: height,
      child: child,
    );
  }
}
