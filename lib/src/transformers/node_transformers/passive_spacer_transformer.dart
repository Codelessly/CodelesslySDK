import 'package:codelessly_api/api.dart';
import 'package:flutter/material.dart';

import '../node_transformer.dart';

class PassiveSpacerTransformer extends NodeWidgetTransformer<SpacerNode> {
  PassiveSpacerTransformer(super.getNode, super.manager);

  Widget buildSpacer(BaseNode node, int flex) {
    final BaseNode parentNode = getNode(node.parentID);

    final AxisC mainAxis;
    if (parentNode is RowColumnNode) {
      mainAxis = parentNode.mainAxis;
    } else {
      mainAxis = AxisC.horizontal;
    }
    final SizeFit horizontalFit = node.horizontalFit;
    final SizeFit verticalFit = node.verticalFit;
    final SizeFit mainFit =
        (mainAxis == AxisC.horizontal ? horizontalFit : verticalFit);

    Widget spacerWidget = SizedBox(
      width: node.outerBoxLocal.width,
      height: node.outerBoxLocal.height,
    );

    if (mainFit == SizeFit.flexible) {
      spacerWidget = Flexible(
        flex: flex,
        child: spacerWidget,
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
