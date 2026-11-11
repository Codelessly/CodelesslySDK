// Live cloud data in the database: queries that follow the signed-in user,
// live aggregates that don't stream documents, batches committed at once,
// and joins read with a few `in` queries.
import 'dart:async';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/counting_backend.dart';

void main() {
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

  test('an owner-only live query follows sign in and out, with one listener', () async {
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

  test('a shared collection does not subscribe again when the user changes', () async {
    backend.seed('data/p/cards', {'c': {'t': 1}});
    final sub = db.watchQuery('cards', const CloudQuery()).listen((_) {});
    await pumpEventQueue();
    signIn('ana');
    await pumpEventQueue();
    expect(backend.opened['data/p/cards'], 1);
    await sub.cancel();
    expect(backend.listeningOn('data/p/cards'), 0);
  });

  test('a live count runs on the server, again after this app\'s writes, without a document listener', () async {
    backend.seed('data/p/cards', {
      for (var i = 0; i < 5; i++) 'c$i': {'read': i < 2},
    });
    final counts = <num?>[];
    final query = const CloudQuery(filters: [CloudWhereFilter('read', WhereOperator.equal, false)]);
    final sub = db.watchAggregate('cards', query, CloudAggregate.count).listen(counts.add);
    await pumpEventQueue();
    expect(counts, [3]);
    await db.updateDocument('cards', 'c4', {'read': true});
    await pumpEventQueue();
    expect(counts.last, 2);
    // A batch of writes runs it once more, not once per write.
    final before = backend.aggregates['data/p/cards']!;
    await db.commitBatch([
      for (final id in ['c2', 'c3']) CloudBatchWrite(CloudBatchOperation.update, 'cards', id: id, data: {'read': true}),
    ]);
    await pumpEventQueue();
    expect(counts.last, 0);
    expect(backend.aggregates['data/p/cards']! - before, 1);
    // Writes to another collection don't run it.
    await db.addDocument('other', {'x': 1});
    await pumpEventQueue();
    expect(backend.aggregates['data/p/cards']! - before, 1);
    expect(backend.opened['data/p/cards'], isNull, reason: 'no document listener');
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

  test('a live sum runs again on a timer for writes made elsewhere', () async {
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

  group('batches', () {
    test('writes commit at once, with owner stamps and field operations', () async {
      signIn('ana');
      backend.seed('data/p/cards', {'c1': {'views': 2}});
      final ids = await db.commitBatch([
        const CloudBatchWrite(CloudBatchOperation.create, 'marks', id: 'ana_c1', data: {'card': 'c1'}),
        CloudBatchWrite(CloudBatchOperation.update, 'cards', id: 'c1', data: {'views': FieldOp.increment(1)}),
        const CloudBatchWrite(CloudBatchOperation.create, 'marks', data: {'card': 'c2'}),
      ]);
      expect(backend.commits, 1);
      expect(ids.first, 'ana_c1');
      expect(ids.last, hasLength(20), reason: 'a generated id');
      expect((await db.getDocument('marks', 'ana_c1'))!['ownerId'], 'ana');
      expect((await db.getDocument('cards', 'c1'))!['views'], 3);
    });

    test('more than 500 writes commit in chunks; atomic ones fail before writing', () async {
      final writes = [
        for (var i = 0; i < 1200; i++) CloudBatchWrite(CloudBatchOperation.create, 'cards', id: 'c$i', data: {'i': i}),
      ];
      await expectLater(db.commitBatch(writes, atomic: true), throwsStateError);
      expect(backend.commits, 0);
      expect(await db.commitBatch(writes), hasLength(1200));
      expect(backend.commits, 3);
      expect(backend.inner.collections['data/p/cards'], hasLength(1200));
    });
  });

  group('joins', () {
    List<CloudJoinSpec> stateJoin(String user) => [
          CloudJoinSpec(collection: 'marks', as: 'state', keyOf: (item) => '${user}_${item['id']}'),
        ];

    test('N items mean N / 30 listeners, live, with the matches attached', () async {
      signIn('ana');
      backend.seed('data/p/cards', {for (var i = 0; i < 70; i++) 'c$i': {'n': i}});
      backend.seed('data/p/marks', {
        'ana_c3': {'ownerId': 'ana', 'read': true},
        'bo_c4': {'ownerId': 'bo', 'read': true},
      });
      final seen = <List<Json>>[];
      final sub = watchJoined(db, db.watchQuery('cards', const CloudQuery()), stateJoin('ana')).listen(seen.add);
      await pumpEventQueue();
      expect(seen, hasLength(1), reason: 'one value once every chunk answered');
      final byId = {for (final d in seen.last) d['id']: d};
      expect((byId['c3']!['state'] as Map)['read'], isTrue);
      expect(byId['c4']!['state'], isNull, reason: 'another user\'s mark is not read');
      expect(backend.listeningOn('data/p/cards'), 1);
      expect(backend.listeningOn('data/p/marks'), 3, reason: '70 keys: 3 in queries, not 70 reads');

      // A new mark arrives live.
      await db.addDocument('marks', {'read': true}, id: 'ana_c5', skipIfExists: false);
      await pumpEventQueue();
      expect(({for (final d in seen.last) d['id']: d}['c5']!['state'] as Map)['read'], isTrue);

      // A new item joins the last chunk with room: only that chunk subscribes again.
      final opened = backend.opened['data/p/marks']!;
      backend.seed('data/p/cards', {'c70': {'n': 70}});
      await pumpEventQueue();
      expect(seen.last, hasLength(71));
      expect(backend.listeningOn('data/p/marks'), 3);
      expect(backend.opened['data/p/marks']! - opened, 1);

      await sub.cancel();
      expect(backend.listeningOn('data/p/marks'), 0);
      expect(backend.listeningOn('data/p/cards'), 0);
    });

    test('by a field, with every match', () async {
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
}
