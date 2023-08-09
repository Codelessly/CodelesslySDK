import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';

import '../../../codelessly_sdk.dart';

class PassiveStackTransformer extends NodeWidgetTransformer<BaseNode> {
  PassiveStackTransformer(super.getNode, super.manager);

  /// Retrieves the widest child from given [siblings].
  static BaseNode? getWidestNode(List<BaseNode> siblings) {
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

  /// Retrieves the tallest child from given [siblings].
  static BaseNode? getTallestNode(List<BaseNode> siblings) {
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

  static Widget buildStackChild(
    BaseNode node,
    BaseNode parent,
    BuildContext context, {
    WidgetNodeTransformerManager? manager,
    Widget? childWidget,
    required BaseNode? widestChild,
    required BaseNode? tallestChild,
    required AlignmentModel commonAlignment,
    WidgetBuildSettings settings = const WidgetBuildSettings(),
  }) {
    assert(childWidget != null || manager != null,
        'Either childWidget or manager must be provided.');

    Widget child = childWidget ??
        manager!.buildWidgetFromNode(node, context, settings: settings);

    if (node.alignment == AlignmentModel.none) {
      child = wrapWithPositioned(
        node,
        parent,
        child,
        isWidest: widestChild?.id == node.id,
        isTallest: tallestChild?.id == node.id,
      );
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

  static Widget wrapWithPositioned(
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
    final double? width = childNode.isHorizontalExpanded ||
            childNode.isHorizontalWrap ||
            childNode.edgePins.isHorizontallyExpanded
        ? null
            : childNode.outerBoxLocal.width;
    final double? height = childNode.isVerticalExpanded ||
            childNode.isVerticalWrap ||
            childNode.edgePins.isVerticallyExpanded
        ? null
            : childNode.outerBoxLocal.height;

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

  static AlignmentModel retrieveCommonAlignment(List<BaseNode> nodes) {
    final List<AlignmentModel> alignments = [];

    for (final BaseNode node in nodes) {
      final AlignmentModel alignment = node.alignment;
      if (alignment.data == null) continue;
      alignments.add(alignment);
    }

    final AlignmentModel? mostCommonAlignment;

    if (alignments.isEmpty) {
      mostCommonAlignment = null;
    } else {
      mostCommonAlignment = mostCommon<AlignmentModel>(alignments);
    }

    return mostCommonAlignment ?? AlignmentModel.none;
  }

  static T mostCommon<T>(List<T> list) {
    final Map<T, int> counts = {};
    for (final T element in list) {
      counts[element] = (counts[element] ?? 0) + 1;
    }
    return counts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
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

    final AlignmentModel commonAlignment = retrieveCommonAlignment(children);
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
}
