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

class PassivePageViewWidget extends StatefulWidget {
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
  State<PassivePageViewWidget> createState() => _PassivePageViewWidgetState();
}

class _PassivePageViewWidgetState extends State<PassivePageViewWidget> {
  late PageController controller;

  @override
  void initState() {
    super.initState();
    controller = PageController(
      initialPage: widget.node.properties.initialPage,
      keepPage: widget.node.properties.keepPage,
      viewportFraction: widget.node.properties.viewportFraction,
    );
  }

  @override
  void didUpdateWidget(covariant PassivePageViewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.node.properties.initialPage !=
        oldWidget.node.properties.initialPage) {
      controller.jumpToPage(widget.node.properties.initialPage);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.node.children.isEmpty) {
      return AdaptiveNodeBox(node: widget.node, child: SizedBox());
    }
    final itemNode = widget.node.children.first;

    return AdaptiveNodeBox(
      node: widget.node,
      child: PageView.builder(
        itemCount: widget.node.properties.itemCount,
        physics: widget.node.physics.flutterScrollPhysics,
        scrollDirection: widget.node.scrollDirection.flutterAxis,
        reverse: widget.node.reverse,
        clipBehavior: widget.node.clipsContent ? Clip.hardEdge : Clip.none,
        padEnds: widget.node.properties.padEnds,
        pageSnapping: widget.node.properties.pageSnapping,
        controller: controller,
        onPageChanged: (index) {
          // TODO:
        },
        itemBuilder: (context, index) => IndexedItemProvider(
          index: index,
          child: widget.manager.buildWidgetByID(
            itemNode,
            context,
            settings: widget.settings,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
