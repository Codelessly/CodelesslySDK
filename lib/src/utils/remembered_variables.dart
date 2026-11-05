import 'package:codelessly_api/codelessly_api.dart';

import '../data/local_database.dart';
import 'observable.dart';

/// The storage key of a remembered variable ([VariableData.remember]).
String rememberedKey(VariableData variable) => 'remember.${variable.name}';

/// The notifier for a shared (app or page) [variable]: when it is
/// remembered, it starts from the value [storage] kept from the last run
/// (unless the host app passed one), and every change is written back.
Observable<VariableData> rememberedObservable(
  VariableData variable,
  LocalDatabase? storage, {
  bool hostValue = false,
}) {
  if (!variable.remember || storage == null) return Observable(variable);
  final String key = rememberedKey(variable);
  final Object? stored = storage.get(key);
  final Observable<VariableData> notifier = Observable(
    stored is String && !hostValue ? variable.copyWith(value: stored) : variable,
  );
  notifier.addListener(() => storage.put(key, notifier.value.value));
  return notifier;
}
