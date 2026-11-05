import 'package:codelessly_api/codelessly_api.dart';

import '../data/local_database.dart';
import 'observable.dart';

/// Keeps the variables marked to persist ([VariableData.persists]) in local
/// storage: a variable starts with its saved value, and every change to it
/// is saved.
abstract final class PersistedVariables {
  /// The storage key of [variable]'s saved value.
  static String keyOf(VariableData variable) =>
      'codelessly.variable.${variable.id}';

  /// [variable] with its saved value, when it persists and one was saved.
  static T restore<T extends VariableData>(T variable, LocalDatabase? storage) {
    if (!variable.persists || storage == null) return variable;
    final String key = keyOf(variable);
    if (!storage.containsKey(key)) return variable;
    final Object? saved = storage.get(key);
    if (saved is! String) return variable;
    return variable.copyWith(value: saved) as T;
  }

  /// Saves [notifier]'s value whenever it changes, when it persists.
  static void watch(Observable<VariableData> notifier, LocalDatabase? storage) {
    if (!notifier.value.persists || storage == null) return;
    String last = notifier.value.value;
    notifier.addListener(() {
      final String value = notifier.value.value;
      if (value == last) return;
      last = value;
      storage.put(keyOf(notifier.value), value);
    });
  }
}
