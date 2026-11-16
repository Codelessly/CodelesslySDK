// Variables kept on the device (`Variable.persists`): a screen's variable
// that starts from the value it had last time, from the app's local
// storage, and saves every change back.
import 'dart:async';

import 'package:codelessly_api/codelessly_api.dart' show Variable;
import 'package:flutter/foundation.dart';

import '../runtime/expressions/scopes.dart';
import '../services/storage.dart';

/// The local storage key persisted variable [v] is kept under.
String persistedVariableKey(Variable v) =>
    'codelessly.variable.${v.id.isEmpty ? v.name : v.id}';

/// Keeps variable [variable] of [scope] in [storage] while attached.
class PersistedVariable {
  PersistedVariable._(
    this.scope,
    this.variable,
    this.storage,
    this._watch,
    this.key,
  );

  /// Starts [variable] (declared in [scope]) from its stored value, if
  /// any, and saves each change. Does nothing (but [dispose]) without
  /// [storage] or when it doesn't persist.
  ///
  /// [key] is the storage key (default: [persistedVariableKey]); a component
  /// variable is kept per instance under its instance's key.
  factory PersistedVariable.attach(
    VariableScope scope,
    Variable variable,
    LocalStorage? storage, {
    String? key,
  }) {
    if (storage == null || !variable.persists)
      return PersistedVariable._(scope, variable, null, null, '');
    final at = key ?? persistedVariableKey(variable);
    if (storage.containsKey(at)) {
      final stored = storage.get(at);
      if (_matchesStoredShape(stored, variable.value) &&
          variable.type.coerce(stored) != null) {
        scope.set(variable.name, stored);
      } else {
        // A changed declaration must not resurrect an obsolete saved value on
        // the next reload. The declared default remains in the scope.
        unawaited(storage.remove(at));
      }
    }
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

// The default acts as a small structural schema. Empty collections can only
// check their outer type; a nonempty default also checks its entries.
bool _matchesStoredShape(Object? stored, Object? declared) {
  if (declared is Map) {
    if (stored is! Map) return false;
    for (final entry in declared.entries) {
      if (!stored.containsKey(entry.key) ||
          !_matchesStoredShape(stored[entry.key], entry.value))
        return false;
    }
    return true;
  }
  if (declared is List) {
    return stored is List &&
        (declared.isEmpty ||
            stored.every((item) => _matchesStoredShape(item, declared.first)));
  }
  if (declared is num) return stored is num;
  if (declared == null) return true;
  return stored.runtimeType == declared.runtimeType;
}
