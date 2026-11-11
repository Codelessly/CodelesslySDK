import 'package:codelessly_api/codelessly_api.dart' show Json;

/// An action failed: [action] is its type, [error] why. Node identity is
/// metadata only; authored error events never expose raw objects or stacks.
class ActionFailed implements Exception {
  const ActionFailed(this.action, this.error, {this.nodeId});
  final String action;
  final Object error;
  final String? nodeId;
  @override
  String toString() => 'Action $action failed: $error';
}

/// Stable, JSON-only event for the canvas's actionError reaction.
Json actionErrorEvent(Object error, {String? action}) {
  String? nodeId;
  while (error is ActionFailed) {
    action = error.action;
    nodeId = error.nodeId ?? nodeId;
    error = error.error;
  }
  return Map.unmodifiable({'error': Map<String, Object?>.unmodifiable({
    'type': error.runtimeType.toString(),
    'message': '$error',
    'action': action ?? '',
    'nodeId': nodeId ?? '',
  })});
}
