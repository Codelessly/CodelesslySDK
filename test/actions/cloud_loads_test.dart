// Load cloud data as a live binding: one listener per variable however
// often it loads, loads that follow the values their query reads, bounded
// loads with a truthful hasMore, live aggregates, joins without N reads,
// reloads, batches over a list, and reactions that run once per key.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart' hide Node;
import 'package:flutter_test/flutter_test.dart';

import '../support/counting_backend.dart';

Node _node(List<Json> actions, {Json trigger = const {'type': 'click'}, String id = 'button'}) => Node.fromJson({
      'type': 'box',
      'actions': [
        {'id': 'r1', 'trigger': trigger, 'actions': actions},
      ],
    }, id: id)!;

Json _load(String variable, String collection,
        {List<Json> where = const [], String? limit, String? aggregate, List<Json> joins = const [], Json extra = const {}}) =>
    {
      'type': 'loadCloudData',
      'variable': variable,
      'single': false,
      'query': {
        'enabled': true,
        'collectionPath': collection,
        if (where.isNotEmpty) 'whereFilters': where,
        if (joins.isNotEmpty) 'joins': joins,
      },
      'limit': ?limit,
      'aggregate': ?aggregate,
      ...extra,
    };

void main() {
  late CountingBackend backend;
  late BackendCloudDatabase db;
  late VariableScope scope;
  late RuntimeActionContext context;
  late List<Object> errors;

  Future<void> run(List<Json> actions, {Json trigger = const {'type': 'click'}}) async {
    await const CodelesslyActions().trigger(_node(actions, trigger: trigger), trigger['type'] as String, context);
    await pumpEventQueue();
  }

  setUp(() {
    CodelesslyActions.resetOnceKeys();
    backend = CountingBackend();
    db = BackendCloudDatabase(backend: backend, root: 'data/p', userId: () => 'ana');
    errors = [];
    scope = VariableScope([
      const Variable(name: 'cards', type: VariableType.map, value: <String, Object?>{}),
      const Variable(name: 'list', type: VariableType.list, value: <Object?>[]),
      const Variable(name: 'unread', type: VariableType.integer, value: 0),
      const Variable(name: 'topic', value: 'a'),
      const Variable(name: 'shown', type: VariableType.integer, value: 5),
      const Variable(name: 'flip', type: VariableType.integer, value: 0),
      const Variable(name: 'runs', type: VariableType.integer, value: 0),
    ]);
    context = RuntimeActionContext(
      scope: scope,
      services: Services(cloud: db, analytics: const NoAnalytics()),
      onError: (e, s, a) => errors.add(e),
    );
  });
  tearDown(() {
    context.dispose();
    scope.dispose();
    db.dispose();
  });

  test('loading a variable again replaces its listener, never stacks one; the screen going closes it', () async {
    backend.seed('data/p/cards', {'c1': {'t': 1}});
    for (var i = 0; i < 3; i++) {
      await run([_load('cards', 'cards')]);
    }
    expect(backend.listeningOn('data/p/cards'), 1);
    expect(backend.opened['data/p/cards'], 3);
    expect(scope.read('cards.status'), 'loaded');
    await run([{'type': 'reloadCloudData', 'variable': 'cards'}]);
    expect(backend.listeningOn('data/p/cards'), 1);
    expect(backend.opened['data/p/cards'], 4);
    context.dispose();
    await pumpEventQueue();
    expect(backend.listeningOn('data/p/cards'), 0);
  });

  test('a load follows the values its query reads, with one listener', () async {
    backend.seed('data/p/cards', {
      'c1': {'topic': 'a'},
      'c2': {'topic': 'b'},
      'c3': {'topic': 'b'},
    });
    await run([
      _load('cards', 'cards', where: [
        {'field': 'topic', 'operator': 'equal', 'value': r'${topic}'},
      ]),
    ]);
    expect((scope.read('cards.data') as List).length, 1);
    scope.set('topic', 'b');
    await pumpEventQueue();
    expect((scope.read('cards.data') as List).length, 2);
    expect(backend.listeningOn('data/p/cards'), 1);
    // Something it doesn't read changes: it stays.
    final opened = backend.opened['data/p/cards'];
    scope.set('flip', 9);
    await pumpEventQueue();
    expect(backend.opened['data/p/cards'], opened);
  });

  test('a load that keeps changing what it reads stops following, and says so once', () async {
    backend.seed('data/p/cards', {'c1': {'n': 1}});
    // A loop: each new value of cards changes flip, which the query reads.
    watchName(scope, 'cards')!.addListener(() {
      if (scope.read('cards.status') == 'loaded') scope.set('flip', (scope.read('flip') as int) + 1);
    });
    await run([
      _load('cards', 'cards', where: [
        {'field': 'n', 'operator': 'notEqual', 'value': r'${flip}'},
      ]),
    ]);
    for (var i = 0; i < 40; i++) {
      await pumpEventQueue();
    }
    expect(errors, hasLength(1));
    expect('$errors', contains('ran again 20 times in a second'));
    expect(backend.listeningOn('data/p/cards'), 1);
  });

  test('a load is bounded: its limit, a truthful hasMore, and a limit bound to a variable', () async {
    backend.seed('data/p/cards', {for (var i = 0; i < 7; i++) 'c$i': {'i': i}});
    await run([_load('cards', 'cards', limit: r'${shown}')]);
    expect((scope.read('cards.data') as List).length, 5);
    expect(scope.read('cards.hasMore'), isTrue);
    scope.set('shown', 10); // "Show more"
    await pumpEventQueue();
    expect((scope.read('cards.data') as List).length, 7);
    expect(scope.read('cards.hasMore'), isFalse);
    expect(backend.listeningOn('data/p/cards'), 1);
  });

  test('a load without a limit stops at the default, and 0 loads everything', () async {
    backend.seed('data/p/cards', {for (var i = 0; i < kDefaultCloudLoadLimit + 1; i++) 'c$i': {'i': i}});
    await run([_load('cards', 'cards')]);
    expect((scope.read('cards.data') as List).length, kDefaultCloudLoadLimit);
    expect(scope.read('cards.hasMore'), isTrue);
    await run([_load('cards', 'cards', limit: '0')]);
    expect((scope.read('cards.data') as List).length, kDefaultCloudLoadLimit + 1);
    expect(scope.read('cards.hasMore'), isFalse);
  });

  test('a list variable gets the documents themselves', () async {
    backend.seed('data/p/cards', {'c1': {'t': 1}});
    await run([_load('list', 'cards')]);
    expect((scope.read('list') as List).single['t'], 1);
  });

  test('a live count fills a number variable, follows this app\'s writes and opens no document listener', () async {
    backend.seed('data/p/cards', {for (var i = 0; i < 4; i++) 'c$i': {'read': i == 0}});
    final unread = _load('unread', 'cards', aggregate: 'count', where: [
      {'field': 'read', 'operator': 'equal', 'value': 'false'},
    ]);
    await run([unread]);
    expect(scope.read('unread'), 3);
    await run([
      {
        'type': 'cloudData',
        'operation': 'update',
        'collection': 'cards',
        'id': 'c1',
        'fields': [
          {'field': 'read', 'value': 'true'},
        ],
      },
    ]);
    expect(scope.read('unread'), 2);
    expect(backend.opened['data/p/cards'], isNull);
    // Into a map variable: the number is its data.
    await run([{...unread, 'variable': 'cards'}]);
    expect(scope.read('cards.data'), 2);
  });

  test('a join attaches per-user state with a few in queries, not one read per item', () async {
    backend.seed('data/p/cards', {for (var i = 0; i < 40; i++) 'c$i': {'i': i}});
    backend.seed('data/p/state', {
      'ana_c2': {'read': true},
      'bo_c3': {'read': true},
    });
    await run([
      _load('cards', 'cards', joins: [
        {'collection': 'state', 'as': 'state', 'id': r'${auth.uid}_${item.id}'},
      ]),
    ]);
    // `auth` isn't declared here: the template reads an empty uid until it is.
    expect(backend.listeningOn('data/p/state'), 2, reason: '40 items, 2 queries of 30');
    expect(backend.listeningOn('data/p/cards'), 1);
    expect(backend.queries['data/p/state'], isNull, reason: 'no one-shot read per item');

    // The same with a uid in scope, read from the item's join.
    final app = ValuesScope({
      'auth': {'uid': 'ana'},
    });
    final withAuth = VariableScope([const Variable(name: 'cards', type: VariableType.map, value: <String, Object?>{})], parent: app);
    final ctx = RuntimeActionContext(scope: withAuth, services: context.services);
    await const CodelesslyActions().trigger(
        _node([
          _load('cards', 'cards', joins: [
            {'collection': 'state', 'as': 'state', 'id': r'${auth.uid}_${item.id}'},
          ]),
        ]),
        'click',
        ctx);
    await pumpEventQueue();
    final byId = {for (final c in withAuth.read('cards.data') as List) (c as Map)['id']: c};
    expect((byId['c2']!['state'] as Map)['read'], isTrue);
    expect(byId['c3']!['state'], isNull);
    // Signing in as someone else re-reads the matches.
    app.set('auth', {'uid': 'bo'});
    await pumpEventQueue();
    final again = {for (final c in withAuth.read('cards.data') as List) (c as Map)['id']: c};
    expect(again['c2']!['state'], isNull);
    expect((again['c3']!['state'] as Map)['read'], isTrue);
    ctx.dispose();
    withAuth.dispose();
  });

  group('a cloud batch', () {
    Json markRead({String id = r'${loop.item.id}'}) => {
          'type': 'cloudData',
          'operation': 'update',
          'collection': 'state',
          'id': id,
          'fields': [
            {'field': 'readAt', 'operation': 'serverTime'},
            {'field': 'opens', 'operation': 'increment', 'value': '1'},
          ],
        };

    test('runs its steps per item of a list in one commit', () async {
      backend.seed('data/p/cards', {for (var i = 0; i < 3; i++) 'c$i': {'i': i}});
      await run([_load('cards', 'cards')]);
      final before = backend.commits;
      await run([
        {'type': 'cloudBatch', 'forEach': r'${cards}', 'steps': [markRead()]},
      ]);
      expect(backend.commits - before, 1);
      final state = backend.inner.collections['data/p/state']!;
      expect(state.keys, ['c0', 'c1', 'c2']);
      expect(state['c1']!['opens'], 1);
    });

    test('more than 500 writes commit in chunks; a transaction fails without writing', () async {
      scope.define(Variable(name: 'many', type: VariableType.list, value: [for (var i = 0; i < 600; i++) {'id': 'c$i'}]));
      await run([
        {'type': 'cloudBatch', 'forEach': 'many', 'transaction': true, 'steps': [markRead()]},
      ]);
      expect(backend.commits, 0);
      expect(errors, hasLength(1));
      await run([
        {'type': 'cloudBatch', 'forEach': 'many', 'steps': [markRead()]},
      ]);
      expect(backend.commits, 2);
      expect(backend.inner.collections['data/p/state'], hasLength(600));
    });

    test('without a list, its writes still commit at once', () async {
      await run([
        {'type': 'cloudBatch', 'steps': [markRead(id: 'x'), markRead(id: 'y')]},
      ]);
      expect(backend.commits, 1);
    });
  });

  test('a reaction with a onceKey runs once per key', () async {
    Future<void> seen(String id) => const CodelesslyActions().trigger(
        _node([
          {'type': 'setVariable', 'variable': 'runs', 'op': 'add', 'value': '1'},
        ], trigger: {'type': 'enterViewport', 'onceKey': r'${result.id}'}),
        'enterViewport',
        context,
        event: {
          'result': {'id': id},
        });
    await seen('a');
    await seen('a');
    await seen('b');
    expect(scope.read('runs'), 2);
  });

  testWidgets('an app-scoped load keeps a live count too, without a document listener', (tester) async {
    final layout = PublishLayout.fromJson({
      'schema': 2,
      'id': 'home',
      'roots': ['home-canvas'],
      'nodes': {
        'home-canvas': {
          'type': 'canvas',
          'layout': {'width': 390, 'height': 300},
          'actions': [
            {
              'trigger': {'type': 'load'},
              'actions': [
                {..._load('unread', 'cards', aggregate: 'count'), 'scope': 'app'},
              ],
            },
          ],
        },
      },
    });
    final appBackend = CountingBackend();
    final cloud = BackendCloudDatabase(backend: appBackend);
    appBackend.seed('data/default/cards', {'a': {'n': 1}, 'b': {'n': 2}});
    final app = Codelessly.fromBundle(
      PublishBundle(
        model: PublishModel(projectId: 'p', entryLayoutId: 'home', layouts: {'home': PublishLayoutInfo.of(layout)}),
        layouts: {'home': layout},
      ),
      config: CodelesslyConfig(services: Services(cloud: cloud, analytics: const NoAnalytics())),
      fonts: const NoFontFetcher(),
    );
    await tester.pumpWidget(MaterialApp(home: CodelesslyWidget(codelessly: app, layoutId: 'home')));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(app.appVariables.read('unread.data'), 2);
    await cloud.addDocument('cards', {'n': 3});
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(app.appVariables.read('unread.data'), 3);
    expect(appBackend.opened['data/default/cards'], isNull);
    await tester.pumpWidget(const SizedBox());
    app.dispose();
    await tester.pump();
    cloud.dispose();
  });

  testWidgets('app-scoped loads keep the expiry and audience rules: a count and a list without what the reader may not see',
      (tester) async {
    final layout = PublishLayout.fromJson({
      'schema': 2,
      'id': 'home',
      'roots': ['home-canvas'],
      'nodes': {
        'home-canvas': {
          'type': 'canvas',
          'layout': {'width': 390, 'height': 300},
          'actions': [
            {
              'trigger': {'type': 'load'},
              'actions': [
                {..._load('unread', 'news', aggregate: 'count'), 'scope': 'app'},
                {..._load('news', 'news'), 'scope': 'app'},
              ],
            },
          ],
        },
      },
    });
    final appBackend = CountingBackend();
    final cloud = BackendCloudDatabase(
      backend: appBackend,
      userId: () => 'ana',
      rules: DataRules.fromJson({
        'collections': {'news': 'audience'},
        'expiry': {'news': 'expiresAt'},
      }),
      now: () => DateTime.utc(2026, 11, 4, 12),
    );
    appBackend.seed('data/default/news', {
      'all': {'audience': ['*'], 'expiresAt': DataRules.neverExpires},
      'mine': {'audience': ['user:ana'], 'expiresAt': DataRules.neverExpires},
      'old': {'audience': ['*'], 'expiresAt': '2026-11-04T11:00:00.000Z'},
      'pros': {'audience': ['role:pro'], 'expiresAt': DataRules.neverExpires},
    });
    final app = Codelessly.fromBundle(
      PublishBundle(
        model: PublishModel(projectId: 'p', entryLayoutId: 'home', layouts: {'home': PublishLayoutInfo.of(layout)}),
        layouts: {'home': layout},
      ),
      config: CodelesslyConfig(services: Services(cloud: cloud, analytics: const NoAnalytics())),
      fonts: const NoFontFetcher(),
    );
    await tester.pumpWidget(MaterialApp(home: CodelesslyWidget(codelessly: app, layoutId: 'home')));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(app.appVariables.read('unread.data'), 2);
    expect({for (final d in app.appVariables.read('news.data') as List) (d as Map)['id']}, {'all', 'mine'});
    await tester.pumpWidget(const SizedBox());
    app.dispose();
    await tester.pump();
    cloud.dispose();
  });

  test('a screen load joining an expiring audience collection attaches only what the reader may see', () async {
    db.dispose();
    db = BackendCloudDatabase(
      backend: backend,
      root: 'data/p',
      userId: () => 'ana',
      rules: DataRules.fromJson({
        'collections': {'news': 'audience'},
        'expiry': {'news': 'expiresAt'},
      }),
      now: () => DateTime.utc(2026, 11, 4, 12),
    );
    context.dispose();
    context = RuntimeActionContext(scope: scope, services: Services(cloud: db, analytics: const NoAnalytics()));
    backend.seed('data/p/news', {
      'all': {'audience': ['*'], 'expiresAt': DataRules.neverExpires},
      'old': {'audience': ['*'], 'expiresAt': '2026-11-04T11:00:00.000Z'},
      'pros': {'audience': ['role:pro'], 'expiresAt': DataRules.neverExpires},
    });
    backend.seed('data/p/cards', {
      for (final id in ['all', 'old', 'pros']) 'c_$id': {'news': id},
    });
    await run([
      _load('cards', 'cards', joins: [
        {'collection': 'news', 'as': 'news', 'localField': 'news'},
      ]),
    ]);
    final byId = {for (final c in scope.read('cards.data') as List) (c as Map)['id']: c['news']};
    expect(byId.keys.toSet(), {'c_all', 'c_old', 'c_pros'});
    expect((byId['c_all'] as Map)['id'], 'all');
    expect(byId['c_old'], isNull, reason: 'expired');
    expect(byId['c_pros'], isNull, reason: 'not in its audience');
  });
}
