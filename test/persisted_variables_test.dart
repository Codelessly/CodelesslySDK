import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/data/persisted_variables.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Local storage in memory.
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

void main() {
  VariableData sideA({bool persist = true}) => VariableData(
    id: 'v1',
    name: 'sideA',
    type: VariableType.list,
    value: ['s01'],
    extra: persist ? {VariableData.persistKey: true} : null,
  );

  test('a persisted variable saves each change and starts from it', () {
    final db = _MemoryDatabase();
    final first = persistedVariable(sideA(), db);
    expect(first.value.getValue(), ['s01']);
    first.value = first.value.copyWith(value: ['s01', 's09']);
    expect(db.get(persistedVariableKey(sideA())), '["s01","s09"]');
    // Next launch: the stored value wins over the default.
    final next = persistedVariable(sideA(), db);
    expect(next.value.getValue(), ['s01', 's09']);
  });

  test('other variables are not stored', () {
    final db = _MemoryDatabase();
    final v = persistedVariable(sideA(persist: false), db);
    v.value = v.value.copyWith(value: ['s02']);
    expect(db.data, isEmpty);
    expect(sideA(persist: false).persists, isFalse);
  });

  test('computed variables never persist', () {
    final v = VariableData(
      id: 'c',
      name: 'usedA',
      formula: 'length(sideA)',
      extra: {VariableData.persistKey: true},
    );
    expect(v.persists, isFalse);
  });

  test('the flag survives JSON', () {
    final back = VariableData.fromJson(sideA().toJson());
    expect(back.persists, isTrue);
  });
}
