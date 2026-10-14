import 'dart:async';

/// The state shared by the actions of one chain: the actions a trigger runs
/// in order, or the actions nested in a for-each, an upload or an if/else.
///
/// Its [result] is what the `${result}` variable resolves to: the value the
/// previous action produced (e.g. the id of a document it added), or the
/// current item while a for-each or an upload runs its nested actions.
class ActionChain {
  /// Creates an [ActionChain] that starts with [result].
  ActionChain({this.result});

  /// What `${result}` resolves to.
  Object? result;

  static const Symbol _zoneKey = #codelesslyActionChain;

  /// The chain the running action belongs to, if any.
  static ActionChain? get current => Zone.current[_zoneKey] as ActionChain?;

  /// Sets the current chain's result, when an action runs in a chain.
  static void setResult(Object? result) => current?.result = result;

  /// Runs [body] in a new chain whose `${result}` starts as [result].
  static R run<R>(R Function() body, {Object? result}) => runZoned(
    body,
    zoneValues: {_zoneKey: ActionChain(result: result)},
  );
}
