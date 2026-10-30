import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';

import '../../../codelessly_sdk.dart';

/// Presents the content only while the trigger's dialog route is open.
class PassiveModalTransformer extends NodeWidgetTransformer<ModalNode> {
  PassiveModalTransformer(super.getNode, super.manager);

  @override
  Widget buildWidget(
    ModalNode node,
    BuildContext context,
    WidgetBuildSettings settings,
  ) {
    final trigger = _resolve(node.trigger, node);
    final content = _resolve(node.content, node);
    if (_contains(node.id, trigger.id, <String>{}) ||
        _contains(node.id, content.id, <String>{})) {
      throw StateError('Modal ${node.id} has a cyclic child reference.');
    }
    if (trigger is! SceneNode || content is! SceneNode) {
      throw StateError('Modal ${node.id} children must be scene nodes.');
    }

    void open(BuildContext triggerContext) {
      showDialog<void>(
        context: triggerContext,
        builder: (dialogContext) => Dialog(
          child: Builder(
            builder: (bodyContext) => manager.buildWidgetFromNode(
              content,
              bodyContext,
              settings: settings,
            ),
          ),
        ),
      );
    }

    if (trigger is ButtonNode) {
      return PassiveButtonWidget(
        node: trigger,
        settings: settings,
        onPressed: (triggerContext) => open(triggerContext),
        onLongPress: (triggerContext) => FunctionsRepository.triggerAction(
          triggerContext,
          TriggerType.longPress,
          reactions: trigger.reactions,
        ),
      );
    }
    return GestureDetector(
      onTap: () => open(context),
      child: manager.buildWidgetFromNode(trigger, context, settings: settings),
    );
  }

  BaseNode _resolve(String id, ModalNode modal) {
    try {
      return getNode(id);
    } catch (_) {
      throw StateError('Modal ${modal.id} references missing node $id.');
    }
  }

  bool _contains(String target, String id, Set<String> visited) {
    if (id == target) return true;
    if (!visited.add(id)) return false;
    final BaseNode node;
    try {
      node = getNode(id);
    } catch (_) {
      throw StateError('Modal child graph references missing node $id.');
    }
    for (final child in node.childrenOrEmpty) {
      if (_contains(target, child, visited)) return true;
    }
    return false;
  }
}
