import 'package:codelessly_api/api.dart';
import 'package:flutter/material.dart';

import '../node_transformer.dart';

class PassivePlaceholderTransformer
    extends NodeWidgetTransformer<PlaceholderNode> {
  PassivePlaceholderTransformer(super.getNode, super.manager);

  @override
  Widget buildWidget(
    PlaceholderNode node,
    BuildContext context, [
    WidgetBuildSettings settings = const WidgetBuildSettings(),
  ]) {
    return const SizedBox();
  }
}
