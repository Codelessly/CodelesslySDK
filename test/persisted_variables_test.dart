import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Local storage kept in memory.
class _MemoryDatabase extends LocalDatabase {
  _MemoryDatabase() : super(identifier: 'test');
  final Map<String, Object?> data = {};

  @override
  bool containsKey(String key) => data.containsKey(key);
  @override
  Map<String, dynamic> getAll() => Map.of(data);
  @override
  Future<void> put(String key, Object? value) async => data[key] = value;
  @override
  Object? get(String key, {Object? defaultValue}) => data[key] ?? defaultValue;
  @override
  Future<void> remove(String key) async => data.remove(key);
  @override
  Future<void> clear() async => data.clear();
  @override
  Listenable getNotifier(String? key) => ChangeNotifier();
  @override
  void reset() => data.clear();
}

/// A variable marked to persist keeps its value on the device between
/// visits: a hive log.
void main() {
  VariableData hives({bool persist = true}) => VariableData(
    id: 'v1',
    name: 'hiveData',
    type: VariableType.list,
    value: '[{"id": "clover"}]',
    extra: {if (persist) VariableData.persistKey: true},
  );

  test('changes are saved and the next start begins with them', () {
    final storage = _MemoryDatabase();
    final first = Observable(PersistedVariables.restore(hives(), storage));
    expect(first.value.value, contains('clover'));
    PersistedVariables.watch(first, storage);
    first.value = first.value.copyWith(
      value: '[{"id": "clover"}, {"id": "heather"}]',
    );
    expect(
      storage.data[PersistedVariables.keyOf(hives())],
      contains('heather'),
    );

    // The next visit.
    final next = PersistedVariables.restore(hives(), storage);
    expect(next.value, contains('heather'));
  });

  test('a variable that does not persist is never saved or restored', () {
    final storage = _MemoryDatabase()
      ..data[PersistedVariables.keyOf(hives())] = '[]';
    final v = Observable(
      PersistedVariables.restore(hives(persist: false), storage),
    );
    expect(v.value.value, contains('clover'));
    PersistedVariables.watch(v, storage);
    v.value = v.value.copyWith(value: '[{"id": "x"}]');
    expect(storage.data[PersistedVariables.keyOf(hives())], '[]');
    expect(hives().persists, isTrue);
    expect(hives(persist: false).persists, isFalse);
  });
}
