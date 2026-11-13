// Variables kept on the device (`Variable.persists`): a screen's variable
// that starts from the value it had last time, from the app's local
// storage, and saves every change back.
import 'package:codelessly_api/codelessly_api.dart' show Variable;
import 'package:flutter/foundation.dart';

import '../runtime/expressions/scopes.dart';
import '../services/storage.dart';

/// The local storage key persisted variable [v] is kept under.
String persistedVariableKey(Variable v) => 'codelessly.variable.${v.id.isEmpty ? v.name : v.id}';

/// Keeps variable [variable] of [scope] in [storage] while attached.
class PersistedVariable {
  PersistedVariable._(this.scope, this.variable, this.storage, this._watch, this.key);

  /// Starts [variable] (declared in [scope]) from its stored value, if
  /// any, and saves each change. Does nothing (but [dispose]) without
  /// [storage] or when it doesn't persist.
  ///
  /// [key] is the storage key (default: [persistedVariableKey]); a component
  /// variable is kept per instance under its instance's key.
  factory PersistedVariable.attach(VariableScope scope, Variable variable, LocalStorage? storage, {String? key}) {
    if (storage == null || !variable.persists) return PersistedVariable._(scope, variable, null, null, '');
    final at = key ?? persistedVariableKey(variable);
    if (storage.containsKey(at)) scope.set(variable.name, storage.get(at));
    final watch = scope.watch(variable.name);
    final p = PersistedVariable._(scope, variable, storage, watch, at);
    watch.addListener(p._save);
    return p;
  }

  final VariableScope scope;
  final Variable variable;
  final LocalStorage? storage;
  final Listenable? _watch;

  /// Where its value is kept.
  final String key;

  void _save() => storage?.put(key, scope.valueOf(variable.name, scope));

  void dispose() => _watch?.removeListener(_save);
}
