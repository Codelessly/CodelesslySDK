// The data rules on live cloud data: the audience filter and a collection's
// expiry hold for live queries, joins and live aggregates (a count never
// counts an expired document or one outside the reader's audience), and
// live audience reads follow a change of the user's role.

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/counting_backend.dart';

void main() {
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

  test('the audience of a signed-in user: their profile role, user without one; anonymous users are not signed in',
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

  test('a live count counts neither expired documents nor those outside the audience', () async {
    final counts = <num?>[];
    final sub = db.watchAggregate('news', const CloudQuery(), CloudAggregate.count).listen(counts.add);
    await pumpEventQueue();
    expect(counts.last, 0, reason: 'signed out');
    await signUp();
    expect(counts.last, 3);
    await setRole('pro');
    expect(counts.last, 4);
    clock = DateTime.utc(2026, 11, 4, 14);
    await db.addDocument('news', {'audience': ['*']});
    await pumpEventQueue();
    expect(counts.last, 4, reason: 'allSoon expired, the new one never expires');
    expect(backend.listeningOn('data/p/news'), 0, reason: 'no document listener');
    await sub.cancel();
  });

  test('a join into an expiring audience collection attaches only what the reader may see', () async {
    backend.seed('data/p/cards', {
      for (final id in ['all', 'allOld', 'pros', 'theirs', 'members']) 'c_$id': {'news': id},
    });
    await signUp();
    final items = db.watchQuery('cards', const CloudQuery());
    final joined = watchJoined(db, items, [
      CloudJoinSpec(collection: 'news', as: 'item', keyOf: (card) => card['news']),
    ]);
    late List<Json> last;
    final sub = joined.listen((d) => last = d);
    await pumpEventQueue();
    Map<String, Object?> byId() => {for (final c in last) c['id'] as String: c['item']};
    expect(byId()['c_all'], isNotNull);
    expect(byId()['c_members'], isNotNull);
    expect(byId()['c_allOld'], isNull, reason: 'expired');
    expect(byId()['c_pros'], isNull, reason: 'not their role yet');
    expect(byId()['c_theirs'], isNull, reason: 'someone else\'s');
    await setRole('pro');
    expect(byId()['c_pros'], isNotNull);
    await sub.cancel();
  });

  test('an atomic batch creating in an expiring collection stamps the field', () async {
    await signUp();
    final ids = await db.commitBatch([
      const CloudBatchWrite(CloudBatchOperation.create, 'board', data: {'title': 'x'}),
    ]);
    expect(backend.inner.collections['data/p/board']![ids.single]!['endsAt'], DataRules.neverExpires);
  });
}
