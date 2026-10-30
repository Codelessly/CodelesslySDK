import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';

import '../../../codelessly_sdk.dart';

/// A modal owns two scene references, but only its trigger participates in
/// the normal widget tree. The body is presented by the trigger's existing
/// ShowDialogAction, which addresses a published Canvas rather than a widget.
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
    if (content is! CanvasNode) {
      throw StateError(
        'Modal ${node.id} content must reference a Canvas; '
        'ShowDialogAction cannot present an arbitrary scene widget.',
      );
    }
    if (_contains(node.id, trigger.id, <String>{}) ||
        _contains(node.id, content.id, <String>{})) {
      throw StateError('Modal ${node.id} has a cyclic child reference.');
    }
    if (trigger is! SceneNode) {
      throw StateError('Modal ${node.id} trigger must be a scene node.');
    }
    final actions = trigger.reactions.map((reaction) => reaction.action);
    if (!actions.any(
      (action) =>
          action is ShowDialogAction && action.destinationId == content.id,
    )) {
      throw StateError(
        'Modal ${node.id} trigger must have a ShowDialogAction '
        'whose destinationId is the content Canvas ${content.id}.',
      );
    }
    return manager.buildWidgetFromNode(trigger, context, settings: settings);
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
