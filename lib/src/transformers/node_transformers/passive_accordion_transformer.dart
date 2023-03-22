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

  Widget buildPreview({Widget? title, Widget? content}) {
    return PassiveAccordionWidget(
      topWidget: AdaptiveSizeFitBox(
        horizontalFit: SizeFit.expanded,
        verticalFit: SizeFit.fixed,
        size: SizeC(300, 64),
        child: Align(
          alignment: Alignment.centerLeft,
          child: title,
        ),
      ),
      bottomWidget: AdaptiveSizeFitBox(
        horizontalFit: SizeFit.expanded,
        verticalFit: SizeFit.fixed,
        size: SizeC(300, 38),
        child: content,
      ),
      node: AccordionNode(
        children: [],
        basicBoxLocal: NodeBox(0, 0, 0, 0),
        name: 'AccordionNode',
        id: 'accordion_node',
      ),
    );
  }
}

class PassiveAccordionWidget extends StatelessWidget {
  final AccordionNode node;
  final Widget topWidget;
  final Widget bottomWidget;

  const PassiveAccordionWidget({
    super.key,
    required this.node,
    required this.topWidget,
    required this.bottomWidget,
  });

  @override
  Widget build(BuildContext context) {
    return AccordionWidget(
      node: node,
      topWidget: topWidget,
      bottomWidget: bottomWidget,
      isInitiallyExpanded: node.isExpanded,
    );
  }
}

class AccordionWidget extends StatefulWidget {
  final Widget topWidget;
  final Widget bottomWidget;
  final bool isInitiallyExpanded;
  final AccordionNode node;

  const AccordionWidget({
    required this.topWidget,
    required this.bottomWidget,
    required this.node,
    this.isInitiallyExpanded = false,
    super.key,
  });

  @override
  State<AccordionWidget> createState() => _AccordionWidgetState();
}

class _AccordionWidgetState extends State<AccordionWidget> {
  late bool isExpanded = widget.isInitiallyExpanded;

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
                        setState(() {
                          isExpanded = !isExpanded;
                        });
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
