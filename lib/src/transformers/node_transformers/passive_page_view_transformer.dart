import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';

import '../../utils/extensions.dart';
import '../transformers.dart';

class PassivePageViewTransformer extends NodeWidgetTransformer<PageViewNode> {
  PassivePageViewTransformer(super.getNode, super.manager);

  @override
  Widget buildWidget(
      PageViewNode node, BuildContext context, WidgetBuildSettings settings) {
    return PassivePageViewWidget(
      node: node,
      manager: manager,
      settings: settings,
    );
  }
}

class PassivePageViewWidget extends StatelessWidget {
  final PageViewNode node;
  final NodeTransformerManager manager;
  final WidgetBuildSettings settings;

  const PassivePageViewWidget({
    super.key,
    required this.node,
    required this.manager,
    this.settings = const WidgetBuildSettings(),
  });

  @override
  Widget build(BuildContext context) {
    if (node.children.isEmpty) {
      return AdaptiveNodeBox(node: node, child: SizedBox());
    }
    final itemNode = node.children.first;

    return AdaptiveNodeBox(
      node: node,
      child: PageView.builder(
        itemCount: node.properties.itemCount,
        physics: node.physics.flutterScrollPhysics,
        scrollDirection: node.scrollDirection.flutterAxis,
        reverse: node.reverse,
        clipBehavior: node.clipsContent ? Clip.hardEdge : Clip.none,
        padEnds: node.properties.padEnds,
        pageSnapping: node.properties.pageSnapping,
        onPageChanged: (index) {
          // TODO:
        },
        itemBuilder: (context, index) => IndexedItemProvider(
          index: index,
          child: manager.buildWidgetByID(
            itemNode,
            context,
            settings: settings,
          ),
        ),
      ),
    );
  }
}