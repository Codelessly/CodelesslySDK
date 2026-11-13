import 'package:codelessly_api/core.dart' show Json;

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

/// A failure with a stable [code] (`file-too-large`) that layouts branch on
/// as `${result.error.code}`, and a readable [message].
class CodedFailure implements Exception {
  const CodedFailure(this.code, this.message);
  final String code;
  final String message;
  @override
  String toString() => message;
}

/// The stable code of [error]: an [AuthFailure]'s (`wrong-password`), a
/// Firebase exception's (`permission-denied`), a [CodedFailure]'s; else ''.
String errorCodeOf(Object error) {
  try {
    final code = (error as dynamic).code;
    return code is String ? code : (code == null ? '' : '$code');
  } catch (_) {
    return '';
  }
}

/// Stable, JSON-only event for the canvas's actionError reaction:
/// `{error: {type, code, message, action, nodeId, retryable}}`;
/// [retryable]: the failed chain can run again (`retryFailed`).
Json actionErrorEvent(Object error, {String? action, bool retryable = false}) {
  String? nodeId;
  while (error is ActionFailed) {
    action = error.action;
    nodeId = error.nodeId ?? nodeId;
    error = error.error;
  }
  return Map.unmodifiable({'error': Map<String, Object?>.unmodifiable({
    'type': error.runtimeType.toString(),
    'code': errorCodeOf(error),
    'message': '$error',
    'action': action ?? '',
    'nodeId': nodeId ?? '',
    'retryable': retryable,
  })});
}
