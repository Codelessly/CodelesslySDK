import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/src/data/local_database.dart';
import 'package:codelessly_sdk/src/utils/remembered_variables.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryDatabase extends LocalDatabase {
  MemoryDatabase() : super(identifier: 'test');
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

/// A remembered variable keeps its value on the device between runs: the
/// coach's lineup is still there after a reload.
void main() {
  VariableData bench({bool remember = true}) => VariableData(
        id: 'v1',
        name: 'bench',
        type: VariableType.list,
        value: '["ollie-hart"]',
        extra: remember ? const {'remember': true} : const {},
      );

  test('changes are stored, and the next run starts from them', () {
    final db = MemoryDatabase();
    final first = rememberedObservable(bench(), db);
    expect(first.value.value, '["ollie-hart"]');
    first.value = first.value.copyWith(value: '["priya-nair","ollie-hart"]');
    expect(db.data['remember.bench'], '["priya-nair","ollie-hart"]');

    final next = rememberedObservable(bench(), db);
    expect(next.value.value, '["priya-nair","ollie-hart"]');
  });

  test('a variable without the flag, computed variables and host values are not restored', () {
    final db = MemoryDatabase()..data['remember.bench'] = '[]';
    expect(rememberedObservable(bench(remember: false), db).value.value, '["ollie-hart"]');
    expect(rememberedObservable(bench(), db, hostValue: true).value.value, '["ollie-hart"]');
    final computed = VariableData(id: 'c', name: 'filled', type: VariableType.integer, formula: 'count(slots)', extra: const {'remember': true});
    expect(computed.remember, isFalse);
    expect(rememberedObservable(bench(), null).value.value, '["ollie-hart"]', reason: 'no storage: works as before');
  });
}
