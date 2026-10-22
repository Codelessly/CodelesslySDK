import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const CloudWhereFilter owner = CloudWhereFilter(
    'ownerId',
    WhereQueryOperator.equal,
    'u1',
  );

  test('a query that runs as is needs no index', () {
    expect(const CloudQuery(filters: [owner]).requiredIndex, isNull);
    expect(
      const CloudQuery(orderBy: [CloudOrderBy('createdAt')]).requiredIndex,
      isNull,
    );
  });

  test('equality filters then sorts then inequalities', () {
    const CloudQuery query = CloudQuery(
      filters: [
        owner,
        CloudWhereFilter('done', WhereQueryOperator.equal, false),
        CloudWhereFilter('priority', WhereQueryOperator.greaterThan, 1),
        CloudWhereFilter('tags', WhereQueryOperator.arrayContains, 'work'),
      ],
      orderBy: [CloudOrderBy('dueAt', descending: true)],
    );
    expect(
      query.requiredIndex!.key,
      'done:asc,ownerId:asc,tags:contains,dueAt:desc,priority:asc',
    );
    expect(query.requiredIndex!.toJson()['fields'], [
      {'fieldPath': 'done', 'order': 'ASCENDING'},
      {'fieldPath': 'ownerId', 'order': 'ASCENDING'},
      {'fieldPath': 'tags', 'arrayConfig': 'CONTAINS'},
      {'fieldPath': 'dueAt', 'order': 'DESCENDING'},
      {'fieldPath': 'priority', 'order': 'ASCENDING'},
    ]);
  });

  test('a ready index runs the query in Firestore', () {
    const CloudQuery query = CloudQuery(
      filters: [owner],
      orderBy: [CloudOrderBy('createdAt', descending: true)],
    );
    expect(query.plan().runsOnClient, isTrue);
    final String key = query.requiredIndex!.key;
    expect(key, 'ownerId:asc,createdAt:desc');
    expect(query.plan(readyIndexes: {key}).runsOnClient, isFalse);
    // Firestore still said no: back to the app.
    expect(
      query.plan(readyIndexes: {key}, forceClient: true).runsOnClient,
      isTrue,
    );
  });

  test('data rules read the ready indexes per collection', () {
    final DataRules rules = DataRules.fromJson({
      'indexes': {
        'tasks': ['ownerId:asc,createdAt:desc'],
      },
    });
    expect(rules.readyIndexesFor('users/u1/tasks'), {
      'ownerId:asc,createdAt:desc',
    });
    expect(rules.readyIndexesFor('posts'), isEmpty);
    expect(DataRules.fromJson(rules.toJson()).indexes, rules.indexes);
  });
}
