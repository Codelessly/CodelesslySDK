// Variables kept on the device (`Variable.persists`): a screen's variable
// that starts from the value it had last time, from the app's local
// storage, and saves every change back. SDK 8.x's persistedVariable.
import 'package:codelessly_api/codelessly_api.dart' show Variable;
import 'package:flutter/foundation.dart';

import '../runtime/expressions/scopes.dart';
import '../services/storage.dart';

/// The local storage key persisted variable [v] is kept under (SDK 8.x's).
String persistedVariableKey(Variable v) => 'codelessly.variable.${v.id.isEmpty ? v.name : v.id}';

/// Keeps variable [variable] of [scope] in [storage] while attached.
class PersistedVariable {
  PersistedVariable._(this.scope, this.variable, this.storage, this._watch);

  /// Starts [variable] (declared in [scope]) from its stored value, if
  /// any, and saves each change. Does nothing (but [dispose]) without
  /// [storage] or when it doesn't persist.
  factory PersistedVariable.attach(VariableScope scope, Variable variable, LocalStorage? storage) {
    if (storage == null || !variable.persists) return PersistedVariable._(scope, variable, null, null);
    final key = persistedVariableKey(variable);
    if (storage.containsKey(key)) scope.set(variable.name, storage.get(key));
    final watch = scope.watch(variable.name);
    final p = PersistedVariable._(scope, variable, storage, watch);
    watch.addListener(p._save);
    return p;
  }

  final VariableScope scope;
  final Variable variable;
  final LocalStorage? storage;
  final Listenable? _watch;

  void _save() => storage?.put(persistedVariableKey(variable), scope.valueOf(variable.name, scope));

  void dispose() => _watch?.removeListener(_save);
}
