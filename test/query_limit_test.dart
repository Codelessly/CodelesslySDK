// Firestore marks its queries @sealed; this test fake stands in for them.
// ignore_for_file: subtype_of_sealed_class

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records the calls made on it; each call returns a new query, like Firestore.
class _FakeQuery extends Fake implements Query<Map<String, dynamic>> {
  _FakeQuery([this.calls = const []]);

  final List<String> calls;

  @override
  Query<Map<String, dynamic>> limit(int limit) =>
      _FakeQuery([...calls, 'limit($limit)']);

  @override
  Query<Map<String, dynamic>> orderBy(
    Object field, {
    bool descending = false,
  }) => _FakeQuery([...calls, 'orderBy($field)']);
}

void main() {
  List<String> build({
    int? limit,
    List<OrderByQueryFilter> orderBy = const [],
  }) {
    final query = constructQueryFromRef(
      _FakeQuery(),
      whereFilters: const [],
      orderByOperations: orderBy,
      limit: limit,
      scopedValues: ScopedValues.empty(),
      nullSubstitutionMode: NullSubstitutionMode.emptyString,
    );
    return (query as _FakeQuery).calls;
  }

  test('limit is applied without filters', () {
    expect(build(limit: 5), ['limit(5)']);
  });

  test('limit is applied after ordering', () {
    expect(build(limit: 3, orderBy: [OrderByQueryFilter(field: 'createdAt')]), [
      'orderBy(createdAt)',
      'limit(3)',
    ]);
  });

  test('no limit leaves the query alone', () {
    expect(build(), isEmpty);
  });
}
