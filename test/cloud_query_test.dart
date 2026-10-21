// Firestore marks its queries and snapshots @sealed; the fakes below stand
// in for them.
// ignore_for_file: subtype_of_sealed_class

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/ui/cloud_query_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const WhereQueryOperator eq = WhereQueryOperator.equal;

CloudWhereFilter where(String field, WhereQueryOperator op, Object? value) =>
    CloudWhereFilter(field, op, value);

/// A document as the planner sees it.
typedef Doc = ({String id, Map<String, dynamic> data});

Doc doc(String id, Map<String, dynamic> data) => (id: id, data: data);

List<String> run(CloudQuery query, List<Doc> docs, {bool force = false}) {
  final CloudQueryPlan plan = query.plan(forceClient: force);
  // The server part runs first: only == filters reach it in client plans.
  final List<Doc> fromServer = [
    for (final Doc d in docs)
      if (plan.server.filters.every((f) => f.matches(d.data, d.id))) d,
  ];
  return plan
      .finish(fromServer, data: (d) => d.data, id: (d) => d.id)
      .map((d) => d.id)
      .toList();
}

/// Ids of [docs] that pass the single filter [filter].
List<String> matching(CloudWhereFilter filter, List<Doc> docs) => [
  for (final Doc d in docs)
    if (filter.matches(d.data, d.id)) d.id,
];

// --- A fake Firestore without composite indexes --------------------------

final FirebaseException missingIndex = FirebaseException(
  plugin: 'cloud_firestore',
  code: 'failed-precondition',
  message: 'The query requires an index. You can create it here: https://x',
);

class _Doc extends Fake implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _Doc(this.id, this._data);

  @override
  final String id;
  final Map<String, dynamic> _data;

  @override
  Map<String, dynamic> data() => _data;
}

class _Snapshot extends Fake implements QuerySnapshot<Map<String, dynamic>> {
  _Snapshot(this.docs);

  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;

  @override
  int get size => docs.length;
}

/// The documents of the fake collection.
List<QueryDocumentSnapshot<Map<String, dynamic>>> store = [];

/// Every query that was listened to, described.
List<String> listened = [];

/// An error every query fails with, when set.
FirebaseException? failure;

/// A query on [store] that, like a Firestore project with only automatic
/// indexes, fails any query combining filters with a sort, a range or
/// filters other than ==.
class _FakeQuery extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  _FakeQuery([this.equals = const {}, this.calls = const [], this.max]);

  final Map<Object, Object?> equals;
  final List<String> calls;
  final int? max;

  @override
  Query<Map<String, dynamic>> where(
    Object field, {
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? arrayContains,
    Iterable<Object?>? arrayContainsAny,
    Iterable<Object?>? whereIn,
    Iterable<Object?>? whereNotIn,
    bool? isNull,
  }) {
    if (isEqualTo != null) {
      return _FakeQuery(
        {...equals, field: isEqualTo},
        [...calls, '$field==$isEqualTo'],
        max,
      );
    }
    return _FakeQuery(equals, [...calls, '$field other'], max);
  }

  @override
  Query<Map<String, dynamic>> orderBy(
    Object field, {
    bool descending = false,
  }) => _FakeQuery(equals, [...calls, 'orderBy $field'], max);

  @override
  Query<Map<String, dynamic>> limit(int limit) =>
      _FakeQuery(equals, calls, limit);

  bool get _needsIndex =>
      calls.any((call) => !call.contains('==')) && calls.length > 1;

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) {
    listened.add(calls.join(', '));
    if (failure case final FirebaseException failure) {
      return Stream.error(failure);
    }
    if (_needsIndex) return Stream.error(missingIndex);
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs = [
      for (final d in store)
        if (equals.entries.every((e) => d.data()[e.key] == e.value)) d,
    ];
    final int? max = this.max;
    return Stream.value(
      _Snapshot(max == null ? docs : docs.take(max).toList()),
    );
  }

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      throw UnimplementedError();

  @override
  bool operator ==(Object other) =>
      other is _FakeQuery &&
      other.calls.join() == calls.join() &&
      other.max == max;

  @override
  int get hashCode => Object.hash(calls.join(), max);
}

class _FakeRoot extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _FakeQuery();
}

class _FakeFirestore extends Fake implements FirebaseFirestore {
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _FakeCollectionOfRoots();
}

class _FakeCollectionOfRoots extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) => _FakeRoot();
}

void main() {
  group('planning', () {
    test('owner filter plus a sort runs its equality part on Firestore', () {
      // V1: projects where ownerId == uid order by position.
      final query = CloudQuery(
        filters: [where('ownerId', eq, 'u1')],
        orderBy: const [CloudOrderBy('position')],
      );
      expect(query.runsOnServer, isFalse);
      final plan = query.plan();
      expect(plan.runsOnClient, isTrue);
      expect(plan.server.filters.single.field, 'ownerId');
      expect(plan.server.orderBy, isEmpty);
      expect(plan.server.limit, isNull);
      expect(plan.clientFilters, isEmpty);
      expect(plan.clientOrderBy.map((o) => o.field), [
        'position',
        cloudDocumentIdField,
      ]);
    });

    test('several equalities plus a sort send only the equalities', () {
      // V2: tasks where projectId, completed and ownerId order by position.
      final query = CloudQuery(
        filters: [
          where('projectId', eq, 'p1'),
          where('completed', eq, false),
          where('ownerId', eq, 'u1'),
        ],
        orderBy: const [CloudOrderBy('position')],
        limit: 2,
      );
      final plan = query.plan();
      expect(plan.server.filters.map((f) => f.field), [
        'projectId',
        'completed',
        'ownerId',
      ]);
      expect(plan.server.limit, isNull, reason: 'limit applies after sort');
      expect(plan.clientLimit, 2);

      final docs = [
        doc('a', {
          'projectId': 'p1',
          'completed': false,
          'ownerId': 'u1',
          'position': 3,
        }),
        doc('b', {
          'projectId': 'p1',
          'completed': false,
          'ownerId': 'u1',
          'position': 1,
        }),
        doc('c', {
          'projectId': 'p1',
          'completed': true,
          'ownerId': 'u1',
          'position': 0,
        }),
        doc('d', {
          'projectId': 'p1',
          'completed': false,
          'ownerId': 'u2',
          'position': 0,
        }),
        doc('e', {
          'projectId': 'p1',
          'completed': false,
          'ownerId': 'u1',
          'position': 2.5,
        }),
      ];
      expect(run(query, docs), ['b', 'e']);
    });

    test('queries Firestore serves without a composite index stay whole', () {
      bool server(CloudQuery query) => query.plan().runsOnClient == false;
      expect(server(const CloudQuery()), isTrue);
      expect(server(const CloudQuery(limit: 5)), isTrue);
      expect(
        server(
          CloudQuery(filters: [where('a', eq, 1), where('b', eq, 2)], limit: 3),
        ),
        isTrue,
        reason: 'equalities merge single-field indexes',
      );
      expect(
        server(
          CloudQuery(
            filters: [
              where('a', eq, 1),
              where('tags', WhereQueryOperator.arrayContains, 'x'),
              where('c', WhereQueryOperator.inArray, [1, 2]),
            ],
          ),
        ),
        isTrue,
      );
      expect(
        server(
          const CloudQuery(orderBy: [CloudOrderBy('a', descending: true)]),
        ),
        isTrue,
      );
      expect(
        server(
          CloudQuery(
            filters: [
              where('a', WhereQueryOperator.greaterThan, 1),
              where('a', WhereQueryOperator.lessThan, 5),
            ],
            orderBy: const [CloudOrderBy('a')],
          ),
        ),
        isTrue,
        reason: 'one field is one single-field index',
      );
      expect(
        server(
          CloudQuery(
            filters: [where('a', eq, 1), where('b', eq, 2)],
            orderBy: const [CloudOrderBy(cloudDocumentIdField)],
          ),
        ),
        isTrue,
        reason: 'every index ends with the document id ascending',
      );
    });

    test('queries that need a composite index are planned for the app', () {
      bool client(CloudQuery query) => query.plan().runsOnClient;
      expect(
        client(
          const CloudQuery(orderBy: [CloudOrderBy('a'), CloudOrderBy('b')]),
        ),
        isTrue,
      );
      expect(
        client(
          CloudQuery(
            filters: [
              where('a', eq, 1),
              where('b', WhereQueryOperator.lessThan, 2),
            ],
          ),
        ),
        isTrue,
      );
      expect(
        client(
          CloudQuery(
            filters: [where('a', WhereQueryOperator.greaterThan, 1)],
            orderBy: const [CloudOrderBy('b')],
          ),
        ),
        isTrue,
      );
      expect(
        client(
          CloudQuery(
            filters: [where('a', eq, 1)],
            orderBy: const [
              CloudOrderBy(cloudDocumentIdField, descending: true),
            ],
          ),
        ),
        isTrue,
      );
      // Combinations Firestore refuses outright.
      expect(
        client(
          CloudQuery(
            filters: [
              where('a', WhereQueryOperator.arrayContains, 1),
              where('b', WhereQueryOperator.arrayContains, 2),
            ],
          ),
        ),
        isTrue,
      );
      expect(
        client(
          CloudQuery(
            filters: [
              where('a', WhereQueryOperator.notInArray, [1]),
              where('a', WhereQueryOperator.notEqual, 2),
            ],
          ),
        ),
        isTrue,
      );
    });

    test('without an == filter Firestore gets the first filter alone', () {
      final plan = CloudQuery(
        filters: [
          where('status', WhereQueryOperator.inArray, ['a', 'b']),
          where('size', WhereQueryOperator.greaterThan, 2),
        ],
        orderBy: const [CloudOrderBy('position')],
      ).plan();
      expect(plan.server.filters.single.field, 'status');
      expect(plan.clientFilters.single.field, 'size');
    });

    test('a forced plan sends Firestore only == filters', () {
      final query = CloudQuery(
        filters: [
          where('ownerId', eq, 'u1'),
          where('tags', WhereQueryOperator.arrayContains, 'x'),
        ],
        limit: 1,
      );
      expect(query.plan().runsOnClient, isFalse);
      final plan = query.plan(forceClient: true);
      expect(plan.server.filters.single.field, 'ownerId');
      expect(plan.clientFilters.single.field, 'tags');
      expect(plan.clientLimit, 1);
      expect(
        run(query, [
          doc('a', {
            'ownerId': 'u1',
            'tags': ['y'],
          }),
          doc('b', {
            'ownerId': 'u1',
            'tags': ['x'],
          }),
          doc('c', {
            'ownerId': 'u1',
            'tags': ['x', 'y'],
          }),
        ], force: true),
        ['b'],
      );
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
      doc('list', {
        'v': [1, 'b'],
      }),
      doc('map', {
        'v': {'k': 1},
      }),
      doc('date', {'v': Timestamp.fromMillisecondsSinceEpoch(0)}),
    ];

    test('==, != and the range operators', () {
      expect(matching(where('v', eq, 1), docs), ['one', 'oneDouble']);
      expect(matching(where('v', eq, null), docs), ['null']);
      expect(matching(where('v', eq, [1, 'b']), docs), ['list']);
      expect(matching(where('v', eq, {'k': 1.0}), docs), ['map']);
      expect(matching(where('v', eq, double.nan), docs), ['nan']);
      expect(matching(where('v', WhereQueryOperator.notEqual, 1), docs), [
        'false',
        'two',
        'nan',
        'text',
        'list',
        'map',
        'date',
      ], reason: '!= skips missing fields and nulls');
      expect(matching(where('v', WhereQueryOperator.greaterThan, 1), docs), [
        'two',
      ], reason: 'ranges only match their own type');
      expect(
        matching(where('v', WhereQueryOperator.greaterThanOrEqual, 1), docs),
        ['one', 'oneDouble', 'two'],
      );
      expect(matching(where('v', WhereQueryOperator.lessThan, 'c'), docs), [
        'text',
      ]);
      expect(
        matching(where('v', WhereQueryOperator.lessThanOrEqual, 1), docs),
        ['one', 'oneDouble', 'nan'],
      );
      expect(
        matching(
          where('v', WhereQueryOperator.greaterThan, DateTime.utc(1969)),
          docs,
        ),
        ['date'],
      );
    });

    test('array and list operators', () {
      expect(
        matching(where('v', WhereQueryOperator.arrayContains, 'b'), docs),
        ['list'],
      );
      expect(
        matching(
          where('v', WhereQueryOperator.arrayContainsAny, [9, 1.0]),
          docs,
        ),
        ['list'],
      );
      expect(
        matching(where('v', WhereQueryOperator.inArray, [false, 'b']), docs),
        ['false', 'text'],
      );
      expect(
        matching(where('v', WhereQueryOperator.notInArray, [1, 'b']), docs),
        ['false', 'two', 'nan', 'list', 'map', 'date'],
        reason: 'not-in skips missing fields and nulls',
      );
    });

    test('document id and dotted fields', () {
      final nested = [
        doc('x', {
          'meta': {'rank': 2},
        }),
        doc('y', {
          'meta': {'rank': 1},
        }),
        doc('z', {'meta': 'flat'}),
      ];
      expect(matching(where(cloudDocumentIdField, eq, 'y'), nested), ['y']);
      expect(
        run(
          CloudQuery(
            filters: [where('meta.rank', WhereQueryOperator.greaterThan, 0)],
            orderBy: const [
              CloudOrderBy(cloudDocumentIdField, descending: true),
            ],
          ),
          nested,
        ),
        ['y', 'x'],
      );
    });

    test(
      'sorting orders types, skips missing fields and breaks ties by id',
      () {
        final query = CloudQuery(
          filters: [where('owner', eq, 'u')],
          orderBy: const [CloudOrderBy('v')],
        );
        final owned = [
          for (final d in docs) doc(d.id, {...d.data, 'owner': 'u'}),
        ];
        expect(run(query, owned), [
          'null',
          'false',
          'nan',
          'one',
          'oneDouble',
          'two',
          'date',
          'text',
          'list',
          'map',
        ]);

        final descending = CloudQuery(
          filters: [where('owner', eq, 'u')],
          orderBy: const [CloudOrderBy('v', descending: true)],
          limit: 3,
        );
        expect(run(descending, owned), ['map', 'list', 'text']);
      },
    );

    test('multiple sorts', () {
      final query = CloudQuery(
        filters: [where('o', eq, 1)],
        orderBy: const [
          CloudOrderBy('group'),
          CloudOrderBy('position', descending: true),
        ],
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

    test('an inequality with no sort orders by its field, like Firestore', () {
      final query = CloudQuery(
        filters: [
          where('o', eq, 1),
          where('size', WhereQueryOperator.greaterThan, 0),
        ],
        limit: 2,
      );
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
      expect(compareCloudStrings('\u{1F600}', '￿'), greaterThan(0));
      expect('\u{1F600}'.compareTo('￿'), lessThan(0));
      expect(compareCloudStrings('a', 'ab'), lessThan(0));
      expect(compareCloudStrings('B', 'a'), lessThan(0));
    });
  });

  test('errors read as Firestore wrote them', () {
    expect(isMissingIndexError(missingIndex), isTrue);
    expect(isMissingIndexError(StateError('x')), isFalse);
    expect(
      describeCloudError(missingIndex),
      'The query requires an index. You can create it here: https://x '
      '(failed-precondition)',
    );
    expect(describeCloudError(StateError('x')), 'Bad state: x');
  });

  test('data rules give owner-only collections the owner filter', () {
    const rules = DataRules({
      'projects': DataRule.owner,
      'notes': DataRule.signedIn,
    });
    expect(rules.readFilters('projects', null), isNull);
    expect(rules.readFilters('notes', null), isNull);
    expect(rules.readFilters('notes', 'u1'), isEmpty);
    expect(rules.readFilters('other', null), isEmpty);
    final owner = rules.readFilters('projects/p/items', 'u1')!.single;
    expect(owner.field, DataRules.ownerField);
    expect(owner.operator, eq);
    expect(owner.value, 'u1');
  });

  group('cloud database', () {
    late FirestoreCloudDatabase database;
    late Observable<VariableData> variable;

    setUp(() {
      listened = [];
      failure = null;
      store = [
        _Doc('p2', {'ownerId': 'u1', 'position': 2, 'name': 'Two'}),
        _Doc('p1', {'ownerId': 'u1', 'position': 1, 'name': 'Inbox'}),
        _Doc('x', {'ownerId': 'u2', 'position': 0, 'name': 'Theirs'}),
      ];
      database = FirestoreCloudDatabase(
        'project',
        PublishSource.publish,
        firestore: _FakeFirestore(),
      )..rules = const DataRules({'projects': DataRule.owner});
      database.currentUserId = () => 'u1';
      variable = Observable(
        VariableData(id: 'projects', name: 'projects', type: VariableType.map),
      );
    });

    Future<void> load(List<WhereQueryFilter> where, {bool sorted = true}) =>
        database.streamCollectionToVariable(
          'projects',
          variable,
          whereFilters: where,
          orderByOperations: [
            if (sorted) const OrderByQueryFilter(field: 'position'),
          ],
          scopedValues: ScopedValues.empty(),
          nullSubstitutionMode: NullSubstitutionMode.emptyString,
        );

    List<String?> names() => [
      for (final item in (variable.value.getValue() as Map)['data'] as List)
        (item as Map)['name'] as String?,
    ];

    test('owner-only data sorted by position loads with no index', () async {
      await load(const []);
      expect((variable.value.getValue() as Map)['status'], 'success');
      expect(names(), ['Inbox', 'Two']);
      expect(listened, ['ownerId==u1'], reason: 'one query, no error trip');
    });

    test('errors reach the variable with Firestore\'s message', () async {
      failure = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'Missing or insufficient permissions.',
      );
      await load(const []);
      final Map value = variable.value.getValue() as Map;
      expect(value['status'], 'error');
      expect(
        value['error'],
        'Missing or insufficient permissions. (permission-denied)',
      );
    });

    test('a missing index Firestore still reports reruns in the app', () async {
      // An in filter with == runs on Firestore as planned; this fake has no
      // index for it, so it fails once and reruns with == only.
      await load([
        const WhereQueryFilter(
          field: 'name',
          operator: WhereQueryOperator.inArray,
          value: '["Inbox", "Theirs"]',
        ),
      ], sorted: false);
      expect(listened, ['ownerId==u1, name other', 'ownerId==u1']);
      expect((variable.value.getValue() as Map)['status'], 'success');
      expect(names(), ['Inbox']);
    });
  });

  testWidgets('lists finish planned queries in the app', (tester) async {
    store = [
      _Doc('b', {'ownerId': 'u1', 'position': 2}),
      _Doc('a', {'ownerId': 'u1', 'position': 1}),
      _Doc('c', {'ownerId': 'u2', 'position': 0}),
    ];
    for (final bool sorted in [true, false]) {
      listened = [];
      final query = CloudQuery(
        filters: [where('ownerId', eq, 'u1')],
        orderBy: [if (sorted) const CloudOrderBy('position')],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CloudQueryBuilder(
            key: ValueKey(sorted),
            ref: _FakeQuery(),
            query: query,
            pageSize: 20,
            builder: (context, snapshot, child) => Text(
              snapshot.hasError
                  ? 'error'
                  : snapshot.docs.map((doc) => doc.id).join(','),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(sorted ? 'a,b' : 'b,a'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('lists rerun a query Firestore reports a missing index for', (
    tester,
  ) async {
    store = [
      _Doc('b', {
        'ownerId': 'u1',
        'tags': ['x'],
      }),
      _Doc('a', {
        'ownerId': 'u1',
        'tags': ['y'],
      }),
    ];
    listened = [];
    await tester.pumpWidget(
      MaterialApp(
        home: CloudQueryBuilder(
          ref: _FakeQuery(),
          query: CloudQuery(
            filters: [
              where('ownerId', eq, 'u1'),
              where('tags', WhereQueryOperator.arrayContains, 'x'),
            ],
          ),
          pageSize: 20,
          builder: (context, snapshot, child) => Text(
            snapshot.hasError
                ? 'error'
                : snapshot.docs.map((doc) => doc.id).join(','),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('b'), findsOneWidget);
    expect(listened.last, 'ownerId==u1');
    expect(tester.takeException(), isNull);
  });
}
