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
  }) {
    assert(rowColumnNode is RowColumnMixin);

    final bool isRow =
        (rowColumnNode as RowColumnMixin).rowColumnType == RowColumnType.row;

    final double? fixWidth;
    final double? fixHeight;
    if (rowColumnNode.verticalFit == SizeFit.locked ||
        rowColumnNode.verticalFit == SizeFit.fixed) {
      fixHeight = rowColumnNode.outerBoxLocal.height;
    } else if (rowColumnNode.verticalFit == SizeFit.shrinkWrap) {
      fixHeight = rowColumnNode.constraints.minHeight;
    } else {
      fixHeight = rowColumnNode.constraints.maxHeight ?? double.infinity;
    }
    if (rowColumnNode.horizontalFit == SizeFit.locked ||
        rowColumnNode.horizontalFit == SizeFit.fixed) {
      fixWidth = rowColumnNode.outerBoxLocal.width;
    } else if (rowColumnNode.horizontalFit == SizeFit.shrinkWrap) {
      fixWidth = rowColumnNode.constraints.minWidth;
    } else {
      fixWidth = rowColumnNode.constraints.maxWidth ?? double.infinity;
    }

    if (isRow) {
      Widget res = Row(
        mainAxisAlignment: rowColumnNode.mainAxisAlignment.flutterAxis,
        crossAxisAlignment: rowColumnNode.crossAxisAlignment.flutterAxis,
        mainAxisSize: (rowColumnNode.horizontalFit == SizeFit.shrinkWrap)
            ? MainAxisSize.min
            : MainAxisSize.max,
        key: ValueKey(rowColumnNode.id),
        children: childrenWidgets,
      );

      if (fixHeight == null && rowColumnNode.isVerticalWrap) {
        final bool anyChildNeedsAlignment = childrenNodes.any(
          (child) => child.alignment != AlignmentModel.none,
        );
        if (anyChildNeedsAlignment) {
          res = IntrinsicHeight(child: res);
        }
      }

      if (rowColumnNode is ScrollableMixin) {
        res = wrapWithScrollable(
          node: (rowColumnNode as ScrollableMixin),
          child: res,
        );
      }

      if (fixWidth == null && fixHeight == null) return res;

      return SizedBox(
        width: fixWidth,
        height: fixHeight,
        child: res,
      );
    } else {
      Widget res = Column(
        mainAxisAlignment: rowColumnNode.mainAxisAlignment.flutterAxis,
        crossAxisAlignment: rowColumnNode.crossAxisAlignment.flutterAxis,
        mainAxisSize: (rowColumnNode.verticalFit == SizeFit.shrinkWrap)
            ? MainAxisSize.min
            : MainAxisSize.max,
        key: ValueKey(rowColumnNode.id),
        children: childrenWidgets,
      );

      if (fixWidth == null && rowColumnNode.isHorizontalWrap) {
        final bool anyChildNeedsAlignment = childrenNodes.any(
          (child) => child.alignment != AlignmentModel.none,
        );
        if (anyChildNeedsAlignment) {
          res = IntrinsicWidth(child: res);
        }
      }

      if (rowColumnNode is ScrollableMixin) {
        res = wrapWithScrollable(
          node: (rowColumnNode as ScrollableMixin),
          child: res,
        );
      }

      if (fixWidth == null && fixHeight == null) return res;

      return SizedBox(
        width: fixWidth,
        height: fixHeight,
        child: res,
      );
    }
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

    final bool hasAlignment = (alignment ?? node.alignment).data != null;

    final AxisC mainAxis =
        ((parentRowColumn as RowColumnMixin).rowColumnType == RowColumnType.row
            ? AxisC.horizontal
            : AxisC.vertical);
    final SizeFit mainAxisFit =
        (mainAxis == AxisC.horizontal ? node.horizontalFit : node.verticalFit);
    // final SizeFit crossAxisFit =
    //     (mainAxis == AxisC.horizontal ? node.verticalFit : node.horizontalFit);

    final double? mainAxisMaxConstraint = (mainAxis == AxisC.horizontal
        ? node.constraints.maxWidth
        : node.constraints.maxHeight);
    // final double? horizontalMaxConstraint = node.constraints.maxWidth;
    // final double? verticalMaxConstraint = node.constraints.maxHeight;

    if (node.horizontalFit == node.verticalFit) {
      if (hasAlignment) {
        childWidget = Align(
          alignment:
              (alignment ?? node.alignment).data!.flutterAlignmentGeometry,
          child: childWidget,
        );
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
          break;
        case SizeFit.flexible:
          childWidget = Flexible(flex: flex, child: childWidget);
          break;
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
          childWidget = Align(
            alignment:
                (alignment ?? node.alignment).data!.flutterAlignmentGeometry,
            child: childWidget,
          );
        }

        if (flexibleSpaceBackground != null) {
          childWidget = flexibleSpaceBackground(childWidget);
        }

        // We only want to wrap in Flex if node flexes on main axis in order
        // to avoid having it's flexFactor accounted for unnecessarily.
        // We can do this because children on cross axis get restricted bounds.
        if (mainAxisFit.isFlex) {
          if (mainAxisFit == SizeFit.flexible) {
            childWidget = Flexible(
              flex: flex,
              child: childWidget,
            );
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
          childWidget = Align(
            alignment:
                (alignment ?? node.alignment).data!.flutterAlignmentGeometry,
            child: childWidget,
          );
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
    BuildContext context, [
    WidgetBuildSettings settings = const WidgetBuildSettings(),
  ]) =>
      PassiveRowColumnWidget(
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

  @override
  Widget build(BuildContext context) {
    final List<Widget> widgetChildren = children.map((child) {
      final Widget builtWidget =
          manager.buildWidgetByID(child.id, context, settings: settings);

      return PassiveRowColumnTransformer.wrapChildWithSizeFits(
        child,
        node,
        builtWidget,
        child.flex,
      );
    }).toList();

    final Widget child = (node is DefaultShapeNode)
        ? manager.getTransformer<PassiveRectangleTransformer>().buildRectangle(
            node as DefaultShapeNode,
            children: [
              PassiveRowColumnTransformer.buildRowColumnWidget(
                node,
                childrenWidgets: widgetChildren,
                childrenNodes: children,
              )
            ],
          )
        : PassiveRowColumnTransformer.buildRowColumnWidget(
            node,
            childrenWidgets: widgetChildren,
            childrenNodes: children,
          );

    if (isTestLayout) {
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
