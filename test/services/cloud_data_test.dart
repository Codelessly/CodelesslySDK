import 'dart:async';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/counting_backend.dart';
import 'fakes.dart';

final _now = DateTime.utc(2026, 11, 4, 12);
DateTime now() => _now;

/// A backend taking 3 writes per batch.
class _SmallBatches extends MemoryDocumentBackend {
  @override
  int get maxBatchWrites => 3;
}

// Cloud data: written values follow the schema.

const posts = CollectionSchema('posts', fields: [
  SchemaField('text', required: true),
  SchemaField('likes', type: SchemaFieldType.number, defaultValue: '0'),
  SchemaField('pinned', type: SchemaFieldType.boolean),
  SchemaField('createdAt', type: SchemaFieldType.date, defaultValue: 'now'),
  SchemaField('tags', type: SchemaFieldType.list),
  SchemaField('author', type: SchemaFieldType.reference, referenceCollection: 'users'),
]);

// Live cloud data in the database: queries that follow the signed-in user,
// live aggregates that don't stream documents, batches committed at once,
// and joins read with a few `in` queries.

// The data rules on live cloud data: the audience filter and a collection's
// expiry hold for live queries, joins and live aggregates (a count never
// counts an expired document or one outside the reader's audience), and
// live audience reads follow a change of the user's role.

void main() {
  group('a cloud database', () {
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

    group('documents', () {
      test('a document is added, read, updated and removed, with its id and dates', () async {
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

      test('a document keeps its id unless it is replaced', () async {
        await db.addDocument('tasks', {'v': 1}, id: 'x');
        await db.addDocument('tasks', {'v': 2}, id: 'x');
        expect((await db.getDocument('tasks', 'x'))!['v'], 1);
        await db.addDocument('tasks', {'v': 3}, id: 'x', skipIfExists: false);
        expect((await db.getDocument('tasks', 'x'))!['v'], 3);
      });

      test('array operations add to and remove from a list field', () async {
        await db.addDocument('tasks', {'tags': ['a']}, id: 't');
        await db.updateDocument('tasks', 't', {'tags': {r'$arrayUnion': ['a', 'b']}});
        expect((await db.getDocument('tasks', 't'))!['tags'], ['a', 'b']);
        await db.updateDocument('tasks', 't', {'tags': const FieldOp.arrayRemove(['a'])});
        expect((await db.getDocument('tasks', 't'))!['tags'], ['b']);
      });

      test('a watched document reports its changes', () async {
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
      test('an owner-only collection stamps the owner and reads only the owner\'s documents', () async {
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

      test('a signed-in collection needs a user to read and write', () async {
        db.rules = rules({'collections': {'members': 'signedIn'}});
        expect(db.readFilters('members'), isNull);
        uid = 'u1';
        expect(db.readFilters('members'), isEmpty);
        expect(db.prepareWrite('members', {'a': 1}), {'a': 1});
      });

    });

    group('server-written rules and expiry', () {
      test('a server-written, owner-read collection reads only the owner\'s documents', () async {
        db.rules = rules({'collections': {'notes': 'ownerRead'}});
        expect(db.readFilters('notes'), isNull);
        uid = 'u1';
        backend.seed('data/p1/notes', {
          'n1': {'ownerId': 'u1', 'read': false},
          'n2': {'ownerId': 'u2'},
        });
        expect((await db.query('notes', const CloudQuery())).map((d) => d['id']), ['n1']);
        expect(db.prepareWrite('notes', {'read': true}), {'read': true}, reason: 'the owner is never restamped');
        await db.updateDocument('notes', 'n1', {'read': true});
        expect(backend.collections['data/p1/notes']!['n1']!['ownerId'], 'u1');
      });

      test('an audience collection reads the documents that name the reader', () async {
        backend.seed('data/p1/news', {
          'all': {'audience': ['*']},
          'pros': {'audience': ['role:pro']},
          'mine': {'audience': ['user:u1']},
          'members': {'audience': ['signedIn']},
          'none': {'title': 'x'},
        });
        db.rules = rules({'collections': {'news': 'audience'}});
        expect(db.readFilters('news'), isNull);
        uid = 'u1';
        expect((await db.query('news', const CloudQuery())).map((d) => d['id']).toSet(), {'all', 'mine'});
        final pro = BackendCloudDatabase(
          backend: backend,
          root: 'data/p1',
          rules: rules({'collections': {'news': 'audience'}}),
          userId: () => 'u9',
          audience: () => DataRules.audienceOf('u9', role: 'pro', signedIn: true),
        );
        expect((await pro.query('news', const CloudQuery())).map((d) => d['id']).toSet(), {'all', 'pros', 'members'});
        pro.dispose();
      });

      test('an expiring collection leaves out expired documents', () async {
        final strict = MemoryDocumentBackend(requireIndexes: true)
          ..seed('data/p1/offers', {
            'live': {'ownerId': 'u1', 'expiresAt': '2026-11-04T13:00:00.000Z', 'rank': 2},
            'later': {'ownerId': 'u1', 'expiresAt': DataRules.neverExpires, 'rank': 1},
            'old': {'ownerId': 'u1', 'expiresAt': '2026-11-04T11:00:00.000Z', 'rank': 0},
            'theirs': {'ownerId': 'u2', 'expiresAt': DataRules.neverExpires, 'rank': 3},
          });
        final rulesJson = {
          'collections': {'offers': 'ownerRead'},
          'expiry': {'offers': 'expiresAt'},
        };
        var clock = _now;
        final strictDb = BackendCloudDatabase(
          backend: strict,
          root: 'data/p1',
          rules: rules(rulesJson),
          userId: () => 'u1',
          now: () => clock,
        );
        expect(strictDb.readFilters('offers'), [
          const CloudWhereFilter('ownerId', WhereOperator.equal, 'u1'),
          const CloudWhereFilter('expiresAt', WhereOperator.greaterThan, '2026-11-04T12:00:00.000Z'),
        ]);
        const sorted = CloudQuery(orderBy: [CloudOrderBy('rank')]);
        // Owner and expiry together need their composite index (the functions
        // create it when the expiry is set); the app can't drop either filter.
        await expectLater(strictDb.query('offers', sorted), throwsA(isA<CloudIndexMissing>()));
        strict.indexes.add('ownerId:asc,expiresAt:asc');
        expect((await strictDb.query('offers', sorted)).map((d) => d['id']), ['later', 'live']);
        // Planned for the app, the database still got the owner and expiry
        // filters (its rules need them), not just the == one.
        expect(strict.queries.last.$2.filters, strictDb.readFilters('offers'));
        expect(strict.queries.last.$2.orderBy, isEmpty);

        final live = strictDb.watchQuery('offers', sorted);
        final first = await live.first;
        expect(first.map((d) => d['id']), ['later', 'live']);
        // Later on, a live query drops what has expired since it started.
        clock = DateTime.utc(2026, 11, 4, 14);
        expect((await strictDb.query('offers', sorted)).map((d) => d['id']), ['later']);
        expect(await strictDb.aggregate('offers', const CloudQuery(), CloudAggregate.count), 1);
        strictDb.dispose();
      });

      test('a write to an expiring collection carries its expiry', () async {
        db.rules = rules({
          'expiry': {'board': 'endsAt'},
        });
        uid = 'u1';
        final id = await db.addDocument('board', {'title': 'A'});
        expect(backend.collections['data/p1/board']![id]!['endsAt'], DataRules.neverExpires);
        await db.addDocument('board', {'title': 'B', 'endsAt': DateTime.utc(2026, 12, 1)}, id: 'b');
        expect(backend.collections['data/p1/board']!['b']!['endsAt'], '2026-12-01T00:00:00.000Z');
        await db.updateDocument('board', 'b', {'title': 'B2'});
        expect(backend.collections['data/p1/board']!['b']!['endsAt'], '2026-12-01T00:00:00.000Z',
            reason: 'an update without the field leaves it');
        await db.updateDocument('board', 'b', {'endsAt': ''});
        expect(backend.collections['data/p1/board']!['b']!['endsAt'], DataRules.neverExpires);
        await db.setDocuments('board', [
          {'id': 'c', 'title': 'C'},
        ]);
        expect(backend.collections['data/p1/board']!['c']!['endsAt'], DataRules.neverExpires);
        expect((await db.query('board', const CloudQuery())).length, 3);
      });
    });

    group('queries', () {
      setUp(() {
        backend.seed('data/p1/tasks', {
          for (var i = 0; i < 6; i++) 't$i': {'done': i.isEven, 'position': 5 - i, 'size': i},
        });
      });

      test('a query the server refuses for a missing index runs in the app instead', () async {
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

      test('a watched query follows changes', () async {
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

      test('count, sum and average', () async {
        const all = CloudQuery();
        expect(await db.aggregate('tasks', all, CloudAggregate.count), 6);
        expect(await db.aggregate('tasks', all, CloudAggregate.sum, field: 'size'), 15);
        expect(await db.aggregate('tasks', all, CloudAggregate.average, field: 'size'), 2.5);
        await expectLater(db.aggregate('tasks', all, CloudAggregate.sum), throwsA(isA<StateError>()));
        expect(aggregateDocuments([{'likes': 2}, {'likes': 5}, {'likes': 'many'}, {}], CloudAggregate.average, 'likes'), 3.5);
        expect(aggregateDocuments([], CloudAggregate.average, 'likes'), isNull);
      });

      test('referenced documents are loaded with their parent', () async {
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
      test('a batch sets many documents, replacing the collection', () async {
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

      test('documents are removed by id or by a filter', () async {
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

      test('a stored query fills in its values, paths and the document id', () {
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

    });
  });

  group('field types', () {
    group('convert', () {
      test('numbers, yes/no values, references, lists and objects convert to their field types', () {
        expect(CloudFieldValues.convert('12.5', SchemaFieldType.number), 12.5);
        expect(CloudFieldValues.convert(' 3 ', SchemaFieldType.number), 3);
        expect(CloudFieldValues.convert('', SchemaFieldType.number), isNull);
        expect(CloudFieldValues.convert('yes', SchemaFieldType.boolean), isTrue);
        expect(CloudFieldValues.convert('false', SchemaFieldType.boolean), isFalse);
        expect(CloudFieldValues.convert(0, SchemaFieldType.boolean), isFalse);
        expect(CloudFieldValues.convert({'id': 'u1', 'name': 'Ana'}, SchemaFieldType.reference), 'u1');
        expect(CloudFieldValues.convert('a, b,c', SchemaFieldType.list), ['a', 'b', 'c']);
        expect(CloudFieldValues.convert('[1,2]', SchemaFieldType.list), [1, 2]);
        expect(CloudFieldValues.convert('{"a":1}', SchemaFieldType.object), {'a': 1});
        expect(CloudFieldValues.convert(12, SchemaFieldType.text), '12');
        expect(CloudFieldValues.convert('12', null), '12');
      });

      test('dates are stored in UTC', () {
        expect(CloudFieldValues.convert('2026-10-22T10:00:00Z', SchemaFieldType.date), DateTime.utc(2026, 10, 22, 10));
        expect(CloudFieldValues.convert(0, SchemaFieldType.date), DateTime.utc(1970));
        expect(CloudFieldValues.convert('now', SchemaFieldType.date, now: () => DateTime.utc(2026)), DateTime.utc(2026));
        expect(CloudFieldValues.convert('soon', SchemaFieldType.date), isNull);
      });
    });

    group('buildWrite', () {
      Object? evaluate(String value) => switch (value) {
            r'${title}' => 'Hello',
            r'${count}' => '2',
            _ => value,
          };

      test('a new document gets its defaults, and a missing required field is refused', () {
        final data = CloudFieldValues.buildWrite(
          fields: const [
            CloudFieldWrite('text', r'${title}'),
            CloudFieldWrite('pinned', 'true'),
            CloudFieldWrite('tags', 'news, sport'),
            CloudFieldWrite('author', 'u1'),
            CloudFieldWrite('gone', '', operation: CloudFieldOperation.delete),
          ],
          schema: posts,
          evaluate: evaluate,
          create: true,
        );
        expect(data['text'], 'Hello');
        expect(data['pinned'], isTrue);
        expect(data['tags'], ['news', 'sport']);
        expect(data['likes'], 0);
        expect(data['createdAt'], isA<DateTime>());
        expect(data['author'], 'u1');
        expect(data.containsKey('gone'), isFalse);
        expect(
          () => CloudFieldValues.buildWrite(fields: const [], schema: posts, evaluate: evaluate, create: true),
          throwsA(isA<StateError>().having((e) => e.message, 'message', 'text is required.')),
        );
      });

      test('an update writes only what it changes, with no defaults', () {
        final data = CloudFieldValues.buildWrite(
          fields: const [
            CloudFieldWrite('likes', r'${count}', operation: CloudFieldOperation.increment),
            CloudFieldWrite('tags', 'old', operation: CloudFieldOperation.arrayRemove),
            CloudFieldWrite('labels', 'x', operation: CloudFieldOperation.arrayAdd),
            CloudFieldWrite('pinned', '', operation: CloudFieldOperation.delete),
            CloudFieldWrite('editedAt', '', operation: CloudFieldOperation.serverTime),
          ],
          schema: posts,
          evaluate: evaluate,
          create: false,
        );
        expect(data, {
          'likes': const FieldOp.increment(2),
          'tags': const FieldOp.arrayRemove(['old']),
          'labels': const FieldOp.arrayUnion(['x']),
          'pinned': FieldOp.delete,
          'editedAt': FieldOp.serverTime,
        });
      });
    });
  });

  group('live queries', () {
    late CountingBackend backend;
    late BackendCloudDatabase db;
    late StreamController<Object?> users;
    String? uid;

    setUp(() {
      uid = null;
      users = StreamController<Object?>.broadcast();
      backend = CountingBackend();
      db = BackendCloudDatabase(
        backend: backend,
        root: 'data/p',
        userId: () => uid,
        userChanges: users.stream,
        rules: DataRules.fromJson({
          'collections': {'marks': 'owner'},
        }),
      );
    });
    tearDown(() async {
      db.dispose();
      await users.close();
    });

    void signIn(String? user) {
      uid = user;
      users.add(user);
    }

    test('an owner-only live query follows the user signing in and out', () async {
      backend.seed('data/p/marks', {
        'a1': {'ownerId': 'ana', 'card': '1'},
        'a2': {'ownerId': 'ana', 'card': '2'},
        'b1': {'ownerId': 'bo', 'card': '1'},
      });
      final seen = <List<String>>[];
      final sub = db.watchQuery('marks', const CloudQuery()).listen((docs) => seen.add([for (final d in docs) d['id'] as String]));
      await pumpEventQueue();
      expect(seen, [<String>[]], reason: 'signed out: nothing, and the stream stays open');
      signIn('ana');
      await pumpEventQueue();
      expect(seen.last, ['a1', 'a2']);
      signIn('bo');
      await pumpEventQueue();
      expect(seen.last, ['b1']);
      expect(backend.listeningOn('data/p/marks'), 1, reason: 'the old user\'s listener closed');
      signIn(null);
      await pumpEventQueue();
      expect(seen.last, isEmpty);
      expect(backend.listeningOn('data/p/marks'), 0);
      await sub.cancel();
    });

    test('a live count of an owner-only collection is 0 signed out and follows the user', () async {
      backend.seed('data/p/marks', {
        'a1': {'ownerId': 'ana'},
        'a2': {'ownerId': 'ana'},
      });
      final counts = <num?>[];
      final sub = db.watchAggregate('marks', const CloudQuery(), CloudAggregate.count).listen(counts.add);
      await pumpEventQueue();
      signIn('ana');
      await pumpEventQueue();
      expect(counts, [0, 2]);
      await sub.cancel();
    });

    test('a live sum is worked out again on a timer, for writes made elsewhere', () async {
      backend.seed('data/p/orders', {'o1': {'total': 5}});
      final sums = <num?>[];
      final sub = db
          .watchAggregate('orders', const CloudQuery(), CloudAggregate.sum,
              field: 'total', every: const Duration(milliseconds: 40))
          .listen(sums.add);
      await pumpEventQueue();
      expect(sums, [5]);
      backend.seed('data/p/orders', {'o2': {'total': 7}}); // someone else's write
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(sums.last, 12);
      await sub.cancel();
    });

    group('joins', () {
      test('a join by a field attaches every match', () async {
        backend.seed('data/p/posts', {'p1': {'t': 1}, 'p2': {'t': 2}});
        backend.seed('data/p/comments', {
          'x': {'post': 'p1', 't': 'a'},
          'y': {'post': 'p1', 't': 'b'},
        });
        final out = await watchJoined(db, db.watchQuery('posts', const CloudQuery()), [
          CloudJoinSpec(collection: 'comments', as: 'comments', keyOf: (item) => item['id'], foreignField: 'post', many: true),
        ]).first;
        expect([for (final p in out) (p['comments'] as List).length], [2, 0]);
      });
    });
  });

  group('audiences and expiry, live', () {
    final rulesJson = {
      'collections': {'news': 'audience', 'notes': 'ownerRead', 'users': 'owner'},
      'expiry': {'news': 'expiresAt', 'notes': 'expiresAt', 'board': 'endsAt'},
    };
    late CountingBackend backend;
    late MemoryAuthService auth;
    late AuthAudience audience;
    late BackendCloudDatabase db;
    var clock = DateTime.utc(2026, 11, 4, 12);

    setUp(() {
      clock = DateTime.utc(2026, 11, 4, 12);
      backend = CountingBackend();
      auth = MemoryAuthService();
      audience = AuthAudience(
        users: auth.userChanges,
        currentUser: () => auth.currentUser,
        profile: (uid) => backend.watch('data/p/users', uid),
      );
      db = BackendCloudDatabase(
        backend: backend,
        root: 'data/p',
        rules: DataRules.fromJson(rulesJson),
        userId: () => auth.currentUser?.uid,
        userChanges: audience.changes,
        audience: audience.call,
        now: () => clock,
      );
      backend.seed('data/p/news', {
        'all': {'audience': ['*'], 'expiresAt': DataRules.neverExpires},
        'allOld': {'audience': ['*'], 'expiresAt': '2026-11-04T11:00:00.000Z'},
        'allSoon': {'audience': ['*'], 'expiresAt': '2026-11-04T13:00:00.000Z'},
        'pros': {'audience': ['role:pro'], 'expiresAt': DataRules.neverExpires},
        'members': {'audience': ['signedIn'], 'expiresAt': DataRules.neverExpires},
        'theirs': {'audience': ['user:someoneElse'], 'expiresAt': DataRules.neverExpires},
      });
    });
    tearDown(() => db.dispose());

    Future<void> signUp() async {
      // MemoryAuthService's userChanges subscribes its changes a turn late.
      await pumpEventQueue();
      await auth.signUp(email: 'a@b.c', password: 'secret');
      await pumpEventQueue();
    }

    Future<void> setRole(String role) async {
      final uid = auth.currentUser!.uid;
      await backend.commit([
        SetDocument('data/p/users', uid, {'role': role}, merge: true),
      ]);
      await pumpEventQueue();
    }

    test('a signed-in user\'s audience is their profile\'s role, and an anonymous user is not signed in',
        () async {
      final sub = audience.changes.listen((_) {});
      expect(audience(), isEmpty);
      await signUp();
      final uid = auth.currentUser!.uid;
      expect(audience(), ['*', 'user:$uid', 'role:user', 'signedIn']);
      await setRole('pro');
      expect(audience(), ['*', 'user:$uid', 'role:pro', 'signedIn']);
      await auth.signOut();
      await auth.signInAsGuest();
      await pumpEventQueue();
      expect(audience(), ['*', 'user:${auth.currentUser!.uid}', 'role:user']);
      await sub.cancel();
    });

    test('a live audience query drops expired documents and follows a change of role', () async {
      final seen = <Set<String>>[];
      final sub = db.watchQuery('news', const CloudQuery()).listen((d) => seen.add({for (final x in d) x['id'] as String}));
      await pumpEventQueue();
      expect(seen.last, isEmpty, reason: 'signed out');
      await signUp();
      expect(seen.last, {'all', 'allSoon', 'members'});
      await setRole('pro');
      expect(seen.last, {'all', 'allSoon', 'members', 'pros'}, reason: 'the role changed, not the user');
      expect(backend.listeningOn('data/p/news'), 1);
      await sub.cancel();
    });
  });
}
