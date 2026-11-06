import 'package:codelessly_api/codelessly_api.dart';

import '../utils/observable.dart';
import 'local_database.dart';

/// The local storage key a persisted variable ([VariableData.persists]) is
/// kept under.
String persistedVariableKey(VariableData variable) =>
    'codelessly.variable.${variable.id}';

/// The notifier for an app or page variable. A variable that persists
/// starts from the value [storage] kept for it last time, if any, and saves
/// every new value back; any other variable is just wrapped.
Observable<VariableData> persistedVariable(
  VariableData variable,
  LocalDatabase? storage,
) {
  if (!variable.persists || storage == null) return Observable(variable);
  final String key = persistedVariableKey(variable);
  final Object? stored = storage.get(key);
  final Observable<VariableData> notifier = Observable(
    stored is String ? variable.copyWith(value: stored) : variable,
  );
  notifier.addListener(() => storage.put(key, notifier.value.value));
  return notifier;
}
