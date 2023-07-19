import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';

import '../node_transformer.dart';

class PassiveSpacerTransformer extends NodeWidgetTransformer<SpacerNode> {
  PassiveSpacerTransformer(super.getNode, super.manager);

  Widget buildSpacer(BaseNode node, int flex) {
    final BaseNode parentNode = getNode(node.parentID);

    if (parentNode is! RowColumnMixin) {
      throw Exception(
        'SpacerNode must be a child of a RowColumnNode to be rendered.'
        ' ${node.name} is a child of [${parentNode.id}](${parentNode.name})',
      );
    }

    final AxisC mainAxis = parentNode.mainAxis;
    final SizeFit horizontalFit = node.horizontalFit;
    final SizeFit verticalFit = node.verticalFit;
    final SizeFit mainFit =
        (mainAxis == AxisC.horizontal ? horizontalFit : verticalFit);

    final Widget spacerWidget;
    if (mainFit.isFlex) {
      spacerWidget = Spacer(flex: flex);
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
    BuildContext context, [
    WidgetBuildSettings settings = const WidgetBuildSettings(),
  ]) {
    return buildSpacer(node, node.flex);
  }
}
