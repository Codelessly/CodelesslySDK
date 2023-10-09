import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';

import '../../../codelessly_sdk.dart';

class PassiveAccordionTransformer extends NodeWidgetTransformer<AccordionNode> {
  PassiveAccordionTransformer(super.getNode, super.manager);

  @override
  Widget buildWidget(
      AccordionNode node, BuildContext context, WidgetBuildSettings settings) {
    return PassiveAccordionWidget(
      node: node,
      topWidget: manager.buildWidgetFromNode(getNode(node.children[0]), context,
          settings: settings),
      bottomWidget: manager.buildWidgetFromNode(
          getNode(node.children[1]), context,
          settings: settings),
    );
  }

  Widget buildPreview({
    required BuildContext context,
    AccordionNode? node,
    Widget? title,
    Widget? content,
    bool enabled = false,
    WidgetBuildSettings settings =
        const WidgetBuildSettings(debugLabel: 'buildPreview', isPreview: true),
  }) {
    node ??= AccordionNode(
      children: [],
      basicBoxLocal: NodeBox(0, 0, 0, 0),
      name: 'AccordionNode',
      id: 'accordion_node',
    );
    return PassiveAccordionWidget(
      enabled: enabled,
      topWidget: title ??
          manager.buildWidgetFromNode(getNode(node.children[0]), context,
              settings: settings),
      bottomWidget: content ??
          manager.buildWidgetFromNode(getNode(node.children[1]), context,
              settings: settings),
      node: node,
    );
  }
}

class PassiveAccordionWidget extends StatefulWidget {
  final Widget topWidget;
  final Widget bottomWidget;
  final bool isInitiallyExpanded;
  final AccordionNode node;
  final bool enabled;

  const PassiveAccordionWidget({
    required this.topWidget,
    required this.bottomWidget,
    required this.node,
    this.isInitiallyExpanded = false,
    this.enabled = true,
    super.key,
  });

  @override
  State<PassiveAccordionWidget> createState() => _AccordionWidgetState();
}

class _AccordionWidgetState extends State<PassiveAccordionWidget> {
  late bool isExpanded = widget.isInitiallyExpanded;

  @override
  void didUpdateWidget(covariant PassiveAccordionWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isInitiallyExpanded != widget.isInitiallyExpanded) {
      isExpanded = widget.isInitiallyExpanded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveNodeBox(
      node: widget.node,
      child: Column(
        mainAxisAlignment: widget.node.mainAxisAlignment.flutterAxis,
        crossAxisAlignment: widget.node.crossAxisAlignment.flutterAxis,
        children: [
          Stack(
            children: [
              widget.topWidget,
              Positioned(
                right: 8,
                top: 8,
                bottom: 8,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: TextButton(
                      onPressed: () {
                        if (widget.enabled) return;
                        setState(() => isExpanded = !isExpanded);
                      },
                      child: Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_down
                            : Icons.keyboard_arrow_up,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            switchInCurve: Curves.easeInOut,
            transitionBuilder: (child, animation) {
              return SizeTransition(sizeFactor: animation, child: child);
            },
            child: isExpanded ? Center(child: widget.bottomWidget) : SizedBox(),
          ),
        ],
      ),
    );
  }
}
