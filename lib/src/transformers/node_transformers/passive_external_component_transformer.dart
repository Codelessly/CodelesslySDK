import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../codelessly_sdk.dart';

class PassiveExternalComponentTransformer
    extends NodeWidgetTransformer<ExternalComponentNode> {
  PassiveExternalComponentTransformer(super.getNode, super.manager);

  @override
  Widget buildWidget(
    ExternalComponentNode node,
    BuildContext context, [
    WidgetBuildSettings settings = const WidgetBuildSettings(),
  ]) {
    return PassiveExternalComponentWidget(node: node, settings: settings);
  }
}

class PassiveExternalComponentWidget extends StatelessWidget {
  final ExternalComponentNode node;
  final WidgetBuildSettings settings;

  const PassiveExternalComponentWidget({
    super.key,
    required this.node,
    this.settings = const WidgetBuildSettings(),
  });

  @override
  Widget build(BuildContext context) {
    final CodelesslyContext codelesslyContext =
        context.watch<CodelesslyContext>();
    final WidgetBuilder? builder =
        codelesslyContext.externalComponentBuilders[node.builderID];

    return AdaptiveNodeBox(
      node: node,
      child: builder?.call(context) ?? const Placeholder(),
    );
  }
}
