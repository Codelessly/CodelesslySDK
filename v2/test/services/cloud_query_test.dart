// Ported from SDK 8.x's cloud_query_test: the planner and the in-app query
// must give what Firestore gives.
import 'package:codelessly_sdk_v2/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

const eq = WhereOperator.equal;

CloudWhereFilter where(String field, WhereOperator op, Object? value) => CloudWhereFilter(field, op, value);

typedef Doc = ({String id, Map<String, Object?> data});

Doc doc(String id, Map<String, Object?> data) => (id: id, data: data);

List<String> run(CloudQuery query, List<Doc> docs, {bool force = false}) {
  final plan = query.plan(forceClient: force);
  final fromServer = [
    for (final d in docs)
      if (plan.server.filters.every((f) => f.matches(d.data, d.id))) d,
  ];
  return plan.finish(fromServer, data: (d) => d.data, id: (d) => d.id).map((d) => d.id).toList();
}

List<String> matching(CloudWhereFilter filter, List<Doc> docs) => [
      for (final d in docs)
        if (filter.matches(d.data, d.id)) d.id,
    ];

void main() {
  group('planning', () {
    test('owner filter plus a sort runs its equality part on the server', () {
      final query = CloudQuery(filters: [where('ownerId', eq, 'u1')], orderBy: const [CloudOrderBy('position')]);
      expect(query.runsOnServer, isFalse);
      final plan = query.plan();
      expect(plan.runsOnClient, isTrue);
      expect(plan.server.filters.single.field, 'ownerId');
      expect(plan.server.orderBy, isEmpty);
      expect(plan.server.limit, isNull);
      expect(plan.clientFilters, isEmpty);
      expect(plan.clientOrderBy.map((o) => o.field), ['position', cloudDocumentIdField]);
    });

    test('several equalities plus a sort send only the equalities', () {
      final query = CloudQuery(
        filters: [where('projectId', eq, 'p1'), where('completed', eq, false), where('ownerId', eq, 'u1')],
        orderBy: const [CloudOrderBy('position')],
        limit: 2,
      );
      final plan = query.plan();
      expect(plan.server.filters.map((f) => f.field), ['projectId', 'completed', 'ownerId']);
      expect(plan.server.limit, isNull, reason: 'limit applies after sort');
      expect(plan.clientLimit, 2);
      final docs = [
        doc('a', {'projectId': 'p1', 'completed': false, 'ownerId': 'u1', 'position': 3}),
        doc('b', {'projectId': 'p1', 'completed': false, 'ownerId': 'u1', 'position': 1}),
        doc('c', {'projectId': 'p1', 'completed': true, 'ownerId': 'u1', 'position': 0}),
        doc('d', {'projectId': 'p1', 'completed': false, 'ownerId': 'u2', 'position': 0}),
        doc('e', {'projectId': 'p1', 'completed': false, 'ownerId': 'u1', 'position': 2.5}),
      ];
      expect(run(query, docs), ['b', 'e']);
    });

    test('queries the server serves without a composite index stay whole', () {
      bool server(CloudQuery query) => !query.plan().runsOnClient;
      expect(server(const CloudQuery()), isTrue);
      expect(server(const CloudQuery(limit: 5)), isTrue);
      expect(server(CloudQuery(filters: [where('a', eq, 1), where('b', eq, 2)], limit: 3)), isTrue);
      expect(
        server(CloudQuery(filters: [
          where('a', eq, 1),
          where('tags', WhereOperator.arrayContains, 'x'),
          where('c', WhereOperator.inArray, [1, 2]),
        ])),
        isTrue,
      );
      expect(server(const CloudQuery(orderBy: [CloudOrderBy('a', descending: true)])), isTrue);
      expect(
        server(CloudQuery(
          filters: [where('a', WhereOperator.greaterThan, 1), where('a', WhereOperator.lessThan, 5)],
          orderBy: const [CloudOrderBy('a')],
        )),
        isTrue,
      );
      expect(
        server(CloudQuery(
          filters: [where('a', eq, 1), where('b', eq, 2)],
          orderBy: const [CloudOrderBy(cloudDocumentIdField)],
        )),
        isTrue,
      );
    });

    test('queries that need a composite index are planned for the app', () {
      bool client(CloudQuery query) => query.plan().runsOnClient;
      expect(client(const CloudQuery(orderBy: [CloudOrderBy('a'), CloudOrderBy('b')])), isTrue);
      expect(client(CloudQuery(filters: [where('a', eq, 1), where('b', WhereOperator.lessThan, 2)])), isTrue);
      expect(
        client(CloudQuery(filters: [where('a', WhereOperator.greaterThan, 1)], orderBy: const [CloudOrderBy('b')])),
        isTrue,
      );
      expect(
        client(CloudQuery(
          filters: [where('a', eq, 1)],
          orderBy: const [CloudOrderBy(cloudDocumentIdField, descending: true)],
        )),
        isTrue,
      );
      expect(
        client(CloudQuery(filters: [
          where('a', WhereOperator.arrayContains, 1),
          where('b', WhereOperator.arrayContains, 2),
        ])),
        isTrue,
      );
      expect(
        client(CloudQuery(filters: [
          where('a', WhereOperator.notInArray, [1]),
          where('a', WhereOperator.notEqual, 2),
        ])),
        isTrue,
      );
    });

    test('a ready composite index sends the query whole', () {
      final query = CloudQuery(filters: [where('done', eq, false)], orderBy: const [CloudOrderBy('due', descending: true)]);
      expect(query.requiredIndex!.key, 'done:asc,due:desc');
      expect(query.plan(readyIndexes: {'done:asc,due:desc'}).runsOnClient, isFalse);
      expect(query.requiredIndex!.toJson(), {
        'key': 'done:asc,due:desc',
        'fields': [
          {'fieldPath': 'done', 'order': 'ASCENDING'},
          {'fieldPath': 'due', 'order': 'DESCENDING'},
        ],
      });
      expect(
        CloudQuery(filters: [where('tags', WhereOperator.arrayContains, 'x')], orderBy: const [CloudOrderBy('a')])
            .requiredIndex!
            .key,
        'tags:contains,a:asc',
      );
    });

    test('without an == filter the server gets the first filter alone', () {
      final plan = CloudQuery(
        filters: [where('status', WhereOperator.inArray, ['a', 'b']), where('size', WhereOperator.greaterThan, 2)],
        orderBy: const [CloudOrderBy('position')],
      ).plan();
      expect(plan.server.filters.single.field, 'status');
      expect(plan.clientFilters.single.field, 'size');
    });

    test('a forced plan sends the server only == filters', () {
      final query = CloudQuery(
        filters: [where('ownerId', eq, 'u1'), where('tags', WhereOperator.arrayContains, 'x')],
        limit: 1,
      );
      expect(query.plan().runsOnClient, isFalse);
      final plan = query.plan(forceClient: true);
      expect(plan.server.filters.single.field, 'ownerId');
      expect(plan.clientFilters.single.field, 'tags');
      expect(plan.clientLimit, 1);
      expect(
        run(
          query,
          [
            doc('a', {'ownerId': 'u1', 'tags': ['y']}),
            doc('b', {'ownerId': 'u1', 'tags': ['x']}),
            doc('c', {'ownerId': 'u1', 'tags': ['x', 'y']}),
          ],
          force: true,
        ),
        ['b'],
      );
    });

    test('pages start after the last document of the previous page', () {
      final docs = [for (var i = 0; i < 5; i++) doc('d$i', {'o': 1, 'n': i})];
      final first = CloudQuery(filters: [where('o', eq, 1)], orderBy: const [CloudOrderBy('n')], limit: 2);
      expect(run(first, docs), ['d0', 'd1']);
      expect(run(first.copyWith(startAfter: 'd1'), docs), ['d2', 'd3']);
    });
  });

  group('client results match Firestore', () {
    final docs = [
      doc('missing', {}),
      doc('null', {'v': null}),
      doc('false', {'v': false}),
      doc('one', {'v': 1}),
      doc('oneDouble', {'v': 1.0}),
      doc('two', {'v': 2.5}),
      doc('nan', {'v': double.nan}),
      doc('text', {'v': 'b'}),
      doc('list', {'v': [1, 'b']}),
      doc('map', {'v': {'k': 1}}),
      doc('date', {'v': DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)}),
    ];

    test('==, != and the range operators', () {
      expect(matching(where('v', eq, 1), docs), ['one', 'oneDouble']);
      expect(matching(where('v', eq, null), docs), ['null']);
      expect(matching(where('v', eq, [1, 'b']), docs), ['list']);
      expect(matching(where('v', eq, {'k': 1.0}), docs), ['map']);
      expect(matching(where('v', eq, double.nan), docs), ['nan']);
      expect(
        matching(where('v', WhereOperator.notEqual, 1), docs),
        ['false', 'two', 'nan', 'text', 'list', 'map', 'date'],
        reason: '!= skips missing fields and nulls',
      );
      expect(matching(where('v', WhereOperator.greaterThan, 1), docs), ['two'], reason: 'ranges only match their own type');
      expect(matching(where('v', WhereOperator.greaterThanOrEqual, 1), docs), ['one', 'oneDouble', 'two']);
      expect(matching(where('v', WhereOperator.lessThan, 'c'), docs), ['text']);
      expect(matching(where('v', WhereOperator.lessThanOrEqual, 1), docs), ['one', 'oneDouble', 'nan']);
      expect(matching(where('v', WhereOperator.greaterThan, DateTime.utc(1969)), docs), ['date']);
    });

    test('array and list operators', () {
      expect(matching(where('v', WhereOperator.arrayContains, 'b'), docs), ['list']);
      expect(matching(where('v', WhereOperator.arrayContainsAny, [9, 1.0]), docs), ['list']);
      expect(matching(where('v', WhereOperator.inArray, [false, 'b']), docs), ['false', 'text']);
      expect(
        matching(where('v', WhereOperator.notInArray, [1, 'b']), docs),
        ['false', 'two', 'nan', 'list', 'map', 'date'],
        reason: 'not-in skips missing fields and nulls',
      );
    });

    test('document id and dotted fields', () {
      final nested = [
        doc('x', {'meta': {'rank': 2}}),
        doc('y', {'meta': {'rank': 1}}),
        doc('z', {'meta': 'flat'}),
      ];
      expect(matching(where(cloudDocumentIdField, eq, 'y'), nested), ['y']);
      expect(
        run(
          CloudQuery(
            filters: [where('meta.rank', WhereOperator.greaterThan, 0)],
            orderBy: const [CloudOrderBy(cloudDocumentIdField, descending: true)],
          ),
          nested,
        ),
        ['y', 'x'],
      );
    });

    test('sorting orders types, skips missing fields and breaks ties by id', () {
      final query = CloudQuery(filters: [where('owner', eq, 'u')], orderBy: const [CloudOrderBy('v')]);
      final owned = [for (final d in docs) doc(d.id, {...d.data, 'owner': 'u'})];
      expect(run(query, owned), ['null', 'false', 'nan', 'one', 'oneDouble', 'two', 'date', 'text', 'list', 'map']);
      final descending = CloudQuery(
        filters: [where('owner', eq, 'u')],
        orderBy: const [CloudOrderBy('v', descending: true)],
        limit: 3,
      );
      expect(run(descending, owned), ['map', 'list', 'text']);
    });

    test('multiple sorts', () {
      final query = CloudQuery(
        filters: [where('o', eq, 1)],
        orderBy: const [CloudOrderBy('group'), CloudOrderBy('position', descending: true)],
      );
      expect(
        run(query, [
          doc('a', {'o': 1, 'group': 2, 'position': 1}),
          doc('b', {'o': 1, 'group': 1, 'position': 1}),
          doc('c', {'o': 1, 'group': 1, 'position': 5}),
          doc('d', {'o': 1, 'group': 1}),
        ]),
        ['c', 'b', 'a'],
      );
    });

    test('an inequality with no sort orders by its field', () {
      final query = CloudQuery(filters: [where('o', eq, 1), where('size', WhereOperator.greaterThan, 0)], limit: 2);
      expect(
        run(query, [
          doc('a', {'o': 1, 'size': 9}),
          doc('b', {'o': 1, 'size': 3}),
          doc('c', {'o': 1, 'size': 0}),
          doc('d', {'o': 1, 'size': 4}),
        ]),
        ['b', 'd'],
      );
    });

    test('strings compare by code point, as UTF-8 bytes do', () {
      expect(compareCloudStrings('\u{1F600}', '\u{FFFF}'), greaterThan(0));
      expect('\u{1F600}'.compareTo('\u{FFFF}'), lessThan(0));
      expect(compareCloudStrings('a', 'ab'), lessThan(0));
      expect(compareCloudStrings('B', 'a'), lessThan(0));
    });
  });
}
