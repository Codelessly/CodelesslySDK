// Cloud queries: the planner and the in-app query
// must give what Firestore gives.
import 'package:codelessly_sdk/codelessly_sdk.dart';
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
  group('what is sent to the server', () {

    test('a query that needs an index the server lacks is finished in the app', () {
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

    test('each page starts after the last document of the one before', () {
      final docs = [for (var i = 0; i < 5; i++) doc('d$i', {'o': 1, 'n': i})];
      final first = CloudQuery(filters: [where('o', eq, 1)], orderBy: const [CloudOrderBy('n')], limit: 2);
      expect(run(first, docs), ['d0', 'd1']);
      expect(run(first.copyWith(startAfter: 'd1'), docs), ['d2', 'd3']);
    });
  });

  group('results worked out in the app match Firestore', () {
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

    test('for equals, not equals and the range operators', () {
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

    test('for the array and list operators', () {
      expect(matching(where('v', WhereOperator.arrayContains, 'b'), docs), ['list']);
      expect(matching(where('v', WhereOperator.arrayContainsAny, [9, 1.0]), docs), ['list']);
      expect(matching(where('v', WhereOperator.inArray, [false, 'b']), docs), ['false', 'text']);
      expect(
        matching(where('v', WhereOperator.notInArray, [1, 'b']), docs),
        ['false', 'two', 'nan', 'list', 'map', 'date'],
        reason: 'not-in skips missing fields and nulls',
      );
    });

    test('for the document id and nested fields', () {
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

    test('when sorting mixed types, missing fields and ties', () {
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

    test('with several sort keys', () {
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

    test('when a range filter has no sort', () {
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

    test('when comparing text', () {
      expect(compareCloudStrings('\u{1F600}', '\u{FFFF}'), greaterThan(0));
      expect('\u{1F600}'.compareTo('\u{FFFF}'), lessThan(0));
      expect(compareCloudStrings('a', 'ab'), lessThan(0));
      expect(compareCloudStrings('B', 'a'), lessThan(0));
    });
  });
}
