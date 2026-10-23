import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';

import '../../../codelessly_sdk.dart';

class PassiveSpacerTransformer extends NodeWidgetTransformer<SpacerNode> {
  PassiveSpacerTransformer(super.getNode, super.manager);

  Widget buildSpacer(BaseNode node, int flex) {
    final BaseNode parentNode = getNode(node.parentID);

    if (parentNode is! RowColumnMixin) {
      return AdaptiveNodeBox(node: node);
    }

    final AxisC mainAxis = parentNode.mainAxis;
    final SizeFit horizontalFit = node.horizontalFit;
    final SizeFit verticalFit = node.verticalFit;
    final SizeFit mainFit = (mainAxis == AxisC.horizontal
        ? horizontalFit
        : verticalFit);

    final Widget spacerWidget;
    // A wrap has no free space to fill: a flex spacer keeps its design size.
    if (mainFit.isFlex && !PassiveRowColumnTransformer.isWrap(parentNode)) {
      // Fills its share of the free space. Where the main axis is unbounded
      // there is none, and it keeps its design size instead (see
      // CodelesslyFlex and FitBox).
      spacerWidget = Expanded(
        flex: flex,
        child: FitBox(
          width: mainAxis.isHorizontal ? node.outerBoxLocal.width : null,
          height: mainAxis.isVertical ? node.outerBoxLocal.height : null,
          fillWidth: mainAxis.isHorizontal,
          fillHeight: mainAxis.isVertical,
        ),
      );
    } else {
      spacerWidget = SizedBox(
        width: mainAxis.isVertical ? null : node.outerBoxLocal.width,
        height: mainAxis.isHorizontal ? null : node.outerBoxLocal.height,
      );
    }

    return spacerWidget;
  }

  @override
  Widget buildWidget(
    SpacerNode node,
    BuildContext context,
    WidgetBuildSettings settings,
  ) {
    return buildSpacer(node, node.flex);
  }
}
