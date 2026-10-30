import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';

import '../../../codelessly_sdk.dart';

/// Scene-backed tabs, separate from the label-only TabBar control.
class PassiveTabsTransformer extends NodeWidgetTransformer<TabsNode> {
  PassiveTabsTransformer(super.getNode, super.manager);

  @override
  Widget buildWidget(
    TabsNode node,
    BuildContext context,
    WidgetBuildSettings settings,
  ) => PassiveTabsWidget(node: node, manager: manager, settings: settings);
}

class PassiveTabsWidget extends StatefulWidget {
  final TabsNode node;
  final WidgetNodeTransformerManager manager;
  final WidgetBuildSettings settings;

  const PassiveTabsWidget({
    super.key,
    required this.node,
    required this.manager,
    required this.settings,
  });

  @override
  State<PassiveTabsWidget> createState() => _PassiveTabsWidgetState();
}

class _PassiveTabsWidgetState extends State<PassiveTabsWidget> {
  String? selectedChild;

  @override
  void initState() {
    super.initState();
    selectedChild = widget.node.tabs.firstOrNull?.child;
  }

  @override
  void didUpdateWidget(covariant PassiveTabsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.node.tabs.any((tab) => tab.child == selectedChild)) {
      selectedChild = widget.node.tabs.firstOrNull?.child;
    }
  }

  BaseNode? _resolve(String id) {
    if (id == widget.node.id) return null;
    try {
      final child = widget.manager.getNode(id);
      // Reject an ancestor or a cycle in the parent chain before rendering.
      final visited = <String>{widget.node.id};
      BaseNode current = widget.node;
      while (current.parentID.isNotEmpty) {
        if (!visited.add(current.parentID)) return null;
        if (current.parentID == id) return null;
        current = widget.manager.getNode(current.parentID);
      }
      if (_reachesSelf(child, <String>{})) return null;
      return child;
    } on Object {
      return null;
    }
  }

  bool _reachesSelf(BaseNode node, Set<String> visited) {
    if (node.id == widget.node.id) return true;
    if (!visited.add(node.id)) return false;
    if (node is TabsNode) {
      for (final tab in node.tabs) {
        try {
          if (_reachesSelf(widget.manager.getNode(tab.child), visited)) {
            return true;
          }
        } on Object {
          // A missing nested child cannot close a cycle.
        }
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final tabs = widget.node.tabs;
    final index = tabs.indexWhere((tab) => tab.child == selectedChild);
    final selected = index < 0 ? 0 : index;
    final child = tabs.isEmpty ? null : _resolve(tabs[selected].child);
    return AdaptiveNodeBox(
      node: widget.node,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              for (var i = 0; i < tabs.length; i++)
                Expanded(
                  child: TextButton(
                    onPressed: () =>
                        setState(() => selectedChild = tabs[i].child),
                    style: TextButton.styleFrom(
                      foregroundColor: i == selected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    child: Text(tabs[i].title),
                  ),
                ),
            ],
          ),
          if (child != null)
            Expanded(
              child: widget.manager.buildWidgetFromNode(
                child,
                context,
                settings: widget.settings,
              ),
            ),
        ],
      ),
    );
  }
}
