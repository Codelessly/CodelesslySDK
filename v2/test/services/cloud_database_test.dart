import 'dart:async';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

final _now = DateTime.utc(2026, 11, 4, 12);
DateTime now() => _now;

void main() {
  late MemoryDocumentBackend backend;
  late BackendCloudDatabase db;
  String? uid;

  DataRules rules(Map<String, Object?> json) => DataRules.fromJson(json);

  setUp(() {
    uid = null;
    backend = MemoryDocumentBackend(now: now);
    db = BackendCloudDatabase(backend: backend, root: 'data/p1', userId: () => uid, now: now);
  });
  tearDown(() => db.dispose());

  group('paths', () {
    test('alternate collection and document under the root', () {
      expect(db.collectionPath('tasks'), 'data/p1/tasks');
      expect(db.collectionPath('users/u1/tasks'), 'data/p1/users/u1/tasks');
      expect(db.collectionPath('users.u1'), 'data/p1/users/u1/default');
      expect(db.collectionPath(' '), 'data/p1/default');
    });
  });

  group('documents', () {
    test('add, read, update and remove, with id and dates', () async {
      final id = await db.addDocument('tasks', {'title': 'A', 'count': 1});
      final stored = backend.collections['data/p1/tasks']![id]!;
      expect(stored['createdAt'], _now.toIso8601String());
      expect(stored['updatedAt'], _now.toIso8601String());
      expect(stored['id'], id);

      final read = (await db.getDocument('tasks', id))!;
      expect(read['title'], 'A');
      expect(read['createdAt'], _now);
      expect(read.keys.last, 'updatedAt', reason: 'private fields last');

      await db.updateDocument('tasks', id, {'count': {r'$increment': 2}, 'title': {r'$delete': true}});
      final updated = (await db.getDocument('tasks', id))!;
      expect(updated['count'], 3);
      expect(updated.containsKey('title'), isFalse);
      expect(updated['createdAt'], _now, reason: 'an update keeps createdAt');

      expect(await db.removeDocument('tasks', id), isTrue);
      expect(await db.removeDocument('tasks', id), isFalse);
      expect(await db.getDocument('tasks', id), isNull);
    });

    test('an existing id is kept unless replaced', () async {
      await db.addDocument('tasks', {'v': 1}, id: 'x');
      await db.addDocument('tasks', {'v': 2}, id: 'x');
      expect((await db.getDocument('tasks', 'x'))!['v'], 1);
      await db.addDocument('tasks', {'v': 3}, id: 'x', skipIfExists: false);
      expect((await db.getDocument('tasks', 'x'))!['v'], 3);
    });

    test('array operations', () async {
      await db.addDocument('tasks', {'tags': ['a']}, id: 't');
      await db.updateDocument('tasks', 't', {'tags': {r'$arrayUnion': ['a', 'b']}});
      expect((await db.getDocument('tasks', 't'))!['tags'], ['a', 'b']);
      await db.updateDocument('tasks', 't', {'tags': const FieldOp.arrayRemove(['a'])});
      expect((await db.getDocument('tasks', 't'))!['tags'], ['b']);
    });

    test('watches a document', () async {
      final values = <Map<String, Object?>?>[];
      final sub = db.watchDocument('tasks', 'w').listen(values.add);
      await pumpEventQueue();
      await db.addDocument('tasks', {'v': 1}, id: 'w');
      await pumpEventQueue();
      await sub.cancel();
      expect(values.first, isNull);
      expect(values.last!['v'], 1);
    });
  });

  group('rules', () {
    test('owner-only collections stamp the owner and read only theirs', () async {
      db.rules = rules({'collections': {'tasks': 'owner'}});
      await expectLater(db.addDocument('tasks', {'t': 1}), throwsA(isA<StateError>()));
      expect(await db.watchQuery('tasks', const CloudQuery()).first, isEmpty);
      await expectLater(db.query('tasks', const CloudQuery()), throwsA(isA<StateError>()));

      uid = 'u1';
      await db.addDocument('tasks', {'t': 1}, id: 'mine');
      backend.seed('data/p1/tasks', {
        'theirs': {'t': 2, 'ownerId': 'u2'},
      });
      expect(backend.collections['data/p1/tasks']!['mine']!['ownerId'], 'u1');
      final docs = await db.query('tasks', const CloudQuery());
      expect(docs.map((d) => d['id']), ['mine']);
    });

    test('signed-in collections need a user to read and write', () async {
      db.rules = rules({'collections': {'members': 'signedIn'}});
      expect(db.readFilters('members'), isNull);
      uid = 'u1';
      expect(db.readFilters('members'), isEmpty);
      expect(db.prepareWrite('members', {'a': 1}), {'a': 1});
    });

    test('rules follow their source and notify', () async {
      final source = StreamController<DataRules>();
      final live = BackendCloudDatabase(backend: backend, rulesSource: source.stream);
      var notified = 0;
      live.addListener(() => notified++);
      source.add(rules({'collections': {'posts': 'publicReadOwnerWrite'}}));
      await pumpEventQueue();
      expect(live.rules.ruleFor('posts'), DataRule.publicReadOwnerWrite);
      expect(notified, 1);
      live.dispose();
      await source.close();
    });
  });

  group('queries', () {
    setUp(() {
      backend.seed('data/p1/tasks', {
        for (var i = 0; i < 6; i++) 't$i': {'done': i.isEven, 'position': 5 - i, 'size': i},
      });
    });

    test('a query needing an index runs in the app after the backend refuses it', () async {
      final strict = MemoryDocumentBackend(requireIndexes: true)
        ..seed('data/p1/tasks', backend.collections['data/p1/tasks']!);
      final strictDb = BackendCloudDatabase(backend: strict, root: 'data/p1');
      const query = CloudQuery(
        filters: [CloudWhereFilter('done', WhereOperator.equal, true)],
        orderBy: [CloudOrderBy('position')],
        limit: 2,
      );
      expect((await strictDb.query('tasks', query)).map((d) => d['id']), ['t4', 't2']);
      // Planned for the app up front: the backend only got the == filter.
      expect(strict.queries.single.$2.orderBy, isEmpty);

      // With the index ready (per the rules) the whole query goes to the
      // backend.
      strict.indexes.add('done:asc,position:asc');
      strictDb.rules = rules({
        'indexes': {'tasks': ['done:asc,position:asc']},
      });
      expect((await strictDb.query('tasks', query)).map((d) => d['id']), ['t4', 't2']);
      expect(strict.queries.last.$2.limit, 2);
      strictDb.dispose();
    });

    test('an index the backend still lacks reruns the query in the app', () async {
      final strict = MemoryDocumentBackend(requireIndexes: true)
        ..seed('data/p1/tasks', backend.collections['data/p1/tasks']!);
      // The rules claim an index the backend doesn't have.
      final strictDb = BackendCloudDatabase(
        backend: strict,
        root: 'data/p1',
        rules: rules({
          'indexes': {'tasks': ['done:asc,position:asc']},
        }),
      );
      const query = CloudQuery(
        filters: [CloudWhereFilter('done', WhereOperator.equal, true)],
        orderBy: [CloudOrderBy('position')],
      );
      expect((await strictDb.query('tasks', query)).map((d) => d['id']), ['t4', 't2', 't0']);
      final stream = await strictDb.watchQuery('tasks', query).first;
      expect(stream.map((d) => d['id']), ['t4', 't2', 't0']);
      strictDb.dispose();
    });

    test('watching a query follows changes', () async {
      const query = CloudQuery(
        filters: [CloudWhereFilter('done', WhereOperator.equal, false)],
        orderBy: [CloudOrderBy('position')],
      );
      final results = <List<String>>[];
      final sub = db.watchQuery('tasks', query).listen((docs) => results.add([for (final d in docs) d['id'] as String]));
      await pumpEventQueue();
      await db.updateDocument('tasks', 't1', {'done': true});
      await pumpEventQueue();
      await sub.cancel();
      expect(results, [
        ['t5', 't3', 't1'],
        ['t5', 't3'],
      ]);
    });

    test('aggregates', () async {
      const all = CloudQuery();
      expect(await db.aggregate('tasks', all, CloudAggregate.count), 6);
      expect(await db.aggregate('tasks', all, CloudAggregate.sum, field: 'size'), 15);
      expect(await db.aggregate('tasks', all, CloudAggregate.average, field: 'size'), 2.5);
      await expectLater(db.aggregate('tasks', all, CloudAggregate.sum), throwsA(isA<StateError>()));
      expect(aggregateDocuments([{'likes': 2}, {'likes': 5}, {'likes': 'many'}, {}], CloudAggregate.average, 'likes'), 3.5);
      expect(aggregateDocuments([], CloudAggregate.average, 'likes'), isNull);
    });

    test('loads referenced documents', () async {
      db.rules = rules({
        'schemas': {
          'tasks': {
            'fields': [
              {'name': 'author', 'type': 'reference', 'referenceCollection': 'users'},
            ],
          },
        },
      });
      backend.seed('data/p1/users', {
        'u1': {'name': 'Ana'},
      });
      await db.updateDocument('tasks', 't0', {'author': 'u1'});
      await db.updateDocument('tasks', 't2', {'author': 'gone'});
      final docs = await db.query(
        'tasks',
        const CloudQuery(filters: [CloudWhereFilter('done', WhereOperator.equal, true)], orderBy: [CloudOrderBy(cloudDocumentIdField)]),
        loadRelated: ['author'],
      );
      expect((docs[0]['author'] as Map)['name'], 'Ana');
      expect(docs[1]['author'], 'gone');
    });
  });

  group('batches', () {
    test('set documents in batches, replacing the collection', () async {
      final small = _SmallBatches();
      final batched = BackendCloudDatabase(backend: small, root: 'r');
      small.seed('r/items', {'old': {'v': 0}, 'keep': {'v': 0}});
      final written = await batched.setDocuments(
        'items',
        [
          for (var i = 0; i < 5; i++) {'id': 'i$i', 'v': i},
          {'id': 'keep', 'v': 9},
          {'v': 'no id'},
        ],
        replaceCollection: true,
      );
      expect(written, 7);
      expect(small.commits, 3, reason: '8 writes, 3 per batch');
      final ids = small.collections['r/items']!.keys.toSet();
      expect(ids.containsAll(['i0', 'i4', 'keep']), isTrue);
      expect(ids.contains('old'), isFalse);
      expect(ids.length, 7);
      batched.dispose();
    });

    test('remove documents by id or filter', () async {
      backend.seed('data/p1/items', {
        for (var i = 0; i < 4; i++) 'i$i': {'v': i},
      });
      expect(await db.removeDocuments('items', ids: ['i0', ' ', 'i0']), 1);
      expect(
        await db.removeDocuments('items', filters: const [CloudWhereFilter('v', WhereOperator.greaterThan, 1)]),
        2,
      );
      expect(backend.collections['data/p1/items']!.keys, ['i1']);
      expect(await db.removeDocuments('items'), 1);
    });
  });

  group('resolving a stored query', () {
    final scope = MapScope({
      'auth': {'uid': 'u1'},
      'max': 3,
      'tags': ['a', 'b'],
    });
    final expressions = FakeExpressions();

    test('evaluates values, paths and the document id field', () {
      final def = CloudQueryDef.fromJson({
        'collectionPath': r'users/${auth.uid}/tasks',
        'limit': 10,
        'whereFilters': [
          {'field': 'size', 'operator': 'lessThan', 'value': r'${max}'},
          {'field': 'done', 'operator': 'equal', 'value': 'false'},
          {'field': 'tag', 'operator': 'inArray', 'value': r'${tags}'},
          {'field': 'owner', 'operator': 'notInArray', 'value': r'${auth.uid}'},
          {'field': r'${documentId}', 'operator': 'equal', 'value': 'x'},
        ],
        'orderByFilters': [
          {'field': 'size', 'sortOrder': 'descending'},
        ],
      });
      expect(resolveCollectionPath(def, expressions, scope), 'users/u1/tasks');
      final query = resolveCloudQuery(def, expressions, scope, limit: 20, startAfter: 'last');
      expect(query.filters.map((f) => f.value), [3, false, ['a', 'b'], ['u1'], 'x']);
      expect(query.filters.last.field, cloudDocumentIdField);
      expect(query.orderBy.single, const CloudOrderBy('size', descending: true));
      expect(query.limit, 20);
      expect(query.startAfter, 'last');
    });

    test('literals', () {
      expect(parseLiteral('12'), 12);
      expect(parseLiteral('true'), isTrue);
      expect(parseLiteral('[1, 2]'), [1, 2]);
      expect(parseLiteral('{bad'), '{bad');
      expect(parseLiteral('hello'), 'hello');
      expect(resolveValue(r'n=${max}', expressions, scope), 'n=3');
    });
  });
}

/// A backend taking 3 writes per batch.
class _SmallBatches extends MemoryDocumentBackend {
  @override
  int get maxBatchWrites => 3;
}
