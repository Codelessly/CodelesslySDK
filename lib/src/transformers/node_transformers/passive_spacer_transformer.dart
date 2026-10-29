import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';

import '../../../codelessly_sdk.dart';

class PassiveSpacerTransformer extends NodeWidgetTransformer<SpacerNode> {
  PassiveSpacerTransformer(super.getNode, super.manager);

  /// The spacer's own box. In a Row or Column, a spacer that flexes on the
  /// main axis fills what it is given there: its parent wraps everything
  /// built for it in an [Expanded] or [Flexible] (see
  /// [PassiveRowColumnTransformer.wrapChildWithSizeFits]), like Flutter's
  /// [Spacer]. Where the main axis is unbounded there is nothing to share,
  /// and it keeps its design size instead (see CodelesslyFlex and FitBox).
  Widget buildSpacer(BaseNode node) {
    final BaseNode parentNode = getNode(node.parentID);

    if (parentNode is! RowColumnMixin) {
      return AdaptiveNodeBox(node: node);
    }

    final AxisC mainAxis = parentNode.mainAxis;
    final SizeFit mainFit = mainAxis == AxisC.horizontal
        ? node.horizontalFit
        : node.verticalFit;

    // The wrapping parent supplies the spacer's design length; a flexing
    // spacer in an ordinary row is expanded by wrapChildWithSizeFits.
    if (mainFit.isFlex &&
        !PassiveRowColumnTransformer.rowColumnWraps(parentNode)) {
      return FitBox(
        width: mainAxis.isHorizontal ? node.outerBoxLocal.width : null,
        height: mainAxis.isVertical ? node.outerBoxLocal.height : null,
        fillWidth: mainAxis.isHorizontal,
        fillHeight: mainAxis.isVertical,
      );
    }
    return SizedBox(
      width: mainAxis.isVertical ? null : node.outerBoxLocal.width,
      height: mainAxis.isHorizontal ? null : node.outerBoxLocal.height,
    );
  }

  @override
  Widget buildWidget(
    SpacerNode node,
    BuildContext context,
    WidgetBuildSettings settings,
  ) {
    return buildSpacer(node);
  }
}
