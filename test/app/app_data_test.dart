import 'dart:async';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart' show settle;

// `loadCloudData` with `scope: app`: one live subscription per app, shared by
// every CodelesslyWidget of the same Codelessly instance (two host screens, a
// badge and a list), writing an app variable every screen reads, and
// outliving the screen that opened it.


class _CountingCloud extends BackendCloudDatabase {
  _CountingCloud() : super(backend: MemoryDocumentBackend());
  int watches = 0;
  int live = 0;

  @override
  Stream<List<Json>> watchQuery(String path, CloudQuery query, {List<String> loadRelated = const []}) {
    watches++;
    final inner = super.watchQuery(path, query, loadRelated: loadRelated);
    late StreamSubscription<List<Json>> sub;
    late StreamController<List<Json>> out;
    out = StreamController<List<Json>>(
      onListen: () {
        live++;
        sub = inner.listen(out.add, onError: out.addError);
      },
      onCancel: () {
        live--;
        return sub.cancel();
      },
    );
    return out.stream;
  }
}

Json _load(String scope, {bool onlyUnread = false}) => {
      'type': 'loadCloudData',
      'variable': 'cards',
      'single': false,
      'scope': scope,
      'query': {
        'collectionPath': 'cards',
        if (onlyUnread)
          'where': [
            {'field': 'read', 'operator': 'equal', 'value': 'false'},
          ],
      },
    };

PublishLayout _screen(String id, String text, Json load) => PublishLayout.fromJson({
      'schema': 2,
      'id': id,
      'roots': ['$id-canvas'],
      'nodes': {
        '$id-canvas': {
          'type': 'canvas',
          'slots': {'body': '$id-body'},
          'layout': {'width': 390, 'height': 300},
          'actions': [
            {
              'trigger': {'type': 'load'},
              'actions': [load],
            },
          ],
        },
        '$id-body': {
          'type': 'stack',
          'layout': {
            'width': {'fill': 390},
            'height': {'fill': 300},
          },
          'children': ['$id-label'],
        },
        '$id-label': {
          'type': 'text',
          'props': {'text': text},
          'layout': {'width': 300, 'height': 20},
        },
      },
    });

PublishBundle _bundle(String scope) {
  final list = _screen('list', r'${cards.status} ${= length(cards.data)} cards', _load(scope));
  final badge = _screen('badge', r'${= length(cards.data)}', _load(scope));
  return PublishBundle(
    model: PublishModel(
      projectId: 'shared',
      entryLayoutId: 'list',
      layouts: {'list': PublishLayoutInfo.of(list), 'badge': PublishLayoutInfo.of(badge)},
      variables: {
        'cards': const Variable(name: 'cards', type: VariableType.map, value: <String, Object?>{}).toJson(),
      },
    ),
    layouts: {'list': list, 'badge': badge},
  );
}

/// Auth operations finish immediately but user stream delivery is controlled.
class _DelayedAuth extends MemoryAuthService {
  _DelayedAuth({super.signedIn});
  final events = StreamController<AppUser?>.broadcast();
  @override
  Stream<AppUser?> get userChanges => events.stream;
  void deliver() => events.add(currentUser);
  @override
  void dispose() {
    events.close();
    super.dispose();
  }
}

Node _node(List<Json> actions) => Node.fromJson({
  'type': 'box',
  'actions': [
    {
      'trigger': {'type': 'click'},
      'actions': actions,
    },
  ],
}, id: 'action')!;
PublishBundle _authBundle() {
  final layout = PublishLayout.fromJson({
    'schema': 2,
    'id': 'home',
    'roots': ['canvas'],
    'variables': {
      'canvas': [const Variable(name: 'seen', value: '').toJson(), const Variable(name: 'uid', value: '').toJson()],
    },
    'nodes': {
      'canvas': {
        'type': 'canvas',
        'layout': {'width': 390, 'height': 844},
        'slots': {'body': 'body'},
      },
      'body': {
        'type': 'stack',
        'layout': {
          'width': {'fill': 390},
          'height': {'fill': 844},
        },
        'children': ['signup', 'signout'],
      },
      'signup': {
        'type': 'box',
        'layout': {'width': 100, 'height': 50},
        'actions': [
          {
            'trigger': {'type': 'click'},
            'actions': [
              {'type': 'auth', 'operation': 'signUp', 'email': 'nova@example.test', 'password': 'Stargazer42', 'displayName': 'Nova Sky'},
              {
                'type': 'cloudDocuments',
                'operation': 'add',
                'path': 'users',
                'id': r'${auth.uid}',
                'document': r'{"displayName":"${auth.displayName}","email":"${auth.email}","uid":"${auth.uid}"}',
              },
              {'type': 'auth', 'operation': 'updateProfile', 'displayName': 'Nova Sky Updated'},
              {'type': 'setVariable', 'variable': 'seen', 'value': r'${auth.displayName}'},
              {'type': 'setVariable', 'variable': 'uid', 'value': r'${auth.uid}'},
            ],
          },
        ],
      },
      'signout': {
        'type': 'box',
        'layout': {
          'width': 100,
          'height': 50,
          'y': {'start': 60},
        },
        'actions': [
          {
            'trigger': {'type': 'click'},
            'actions': [
              {'type': 'auth', 'operation': 'signOut'},
              {'type': 'setVariable', 'variable': 'seen', 'value': r'${auth.displayName}'},
              {'type': 'setVariable', 'variable': 'uid', 'value': r'${auth.uid}'},
            ],
          },
        ],
      },
    },
  });
  return PublishBundle(
    model: PublishModel(projectId: 'sandbox', entryLayoutId: 'home', layouts: {'home': PublishLayoutInfo.of(layout)}),
    layouts: {'home': layout},
  );
}

void main() {
  group('page variables', () {
    test('a page\'s variables keep their values across its layouts and hide app variables of the same name', () {
      final app = Codelessly();
      addTearDown(app.dispose);
      app.declareAppVariables([
        const Variable(name: 'count', type: VariableType.integer, value: 3),
        const Variable(name: 'appLabel', value: 'shared app'),
      ]);
      final first = app.pageVariables('page-one', [
        const Variable(name: 'count', type: VariableType.integer, value: 5),
        const Variable(name: 'label', value: 'original'),
      ]);
      expect(first.read('count'), 5);
      expect(first.read('appLabel'), 'shared app');
      first.set('label', 'edited');
      final nextLayout = app.pageVariables('page-one', [
        const Variable(name: 'label', value: 'original'),
      ]);
      expect(identical(first, nextLayout), isTrue);
      expect(nextLayout.read('label'), 'edited');
      expect(app.appVariables.read('count'), 3);
      final otherPage = app.pageVariables('page-two', [
        const Variable(name: 'label', value: 'second page'),
      ]);
      expect(otherPage.read('label'), 'second page');
      expect(
        otherPage.read('count'),
        3,
        reason: 'another page inherits only app state',
      );
    });

    test('two apps never share page variables', () {
      final first = Codelessly(), second = Codelessly();
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      final a = first.pageVariables('same-page', [
        const Variable(name: 'label', value: 'first'),
      ]);
      final b = second.pageVariables('same-page', [
        const Variable(name: 'label', value: 'second'),
      ]);
      a.set('label', 'changed');
      expect(b.read('label'), 'second');
    });
  });

  group('live data shared by an app', () {
    late _CountingCloud cloud;
    late Codelessly app;

    Future<void> start(WidgetTester tester, String scope) async {
      cloud = _CountingCloud();
      await cloud.addDocument('cards', {'title': 'a'}, id: 'a');
      await cloud.addDocument('cards', {'title': 'b'}, id: 'b');
      app = Codelessly.fromBundle(
        _bundle(scope),
        config: CodelesslyConfig(services: Services(cloud: cloud, analytics: const NoAnalytics())),
        fonts: const NoFontFetcher(),
      );
    }

    Widget host({bool list = true, bool badge = true}) => MaterialApp(
          home: Column(children: [
            if (list) SizedBox(height: 300, child: CodelesslyWidget(key: const ValueKey('list'), codelessly: app, layoutId: 'list')),
            if (badge) SizedBox(height: 300, child: CodelesslyWidget(key: const ValueKey('badge'), codelessly: app, layoutId: 'badge')),
          ]),
        );

    String shown(WidgetTester tester, String id) {
      final tree = tester.widgetList<NodeView>(find.byType(NodeView)).map((v) => v.tree).firstWhere((t) => t.boxOf('$id-label') != null);
      return tree.boxOf('$id-label')!.node!.prop(TextProps.text);
    }

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
    }

    testWidgets('two widgets of one app share one live subscription, which outlives them', (tester) async {
      await start(tester, 'app');
      await tester.pumpWidget(host());
      await settle(tester);
      expect(cloud.watches, 1, reason: 'the second load shares the first one\'s subscription');
      expect(shown(tester, 'list'), 'loaded 2 cards');
      expect(shown(tester, 'badge'), '2');
      expect(app.appVariables.read('cards.status'), 'loaded');

      await cloud.addDocument('cards', {'title': 'c'}, id: 'c');
      await settle(tester);
      expect(shown(tester, 'list'), 'loaded 3 cards');
      expect(shown(tester, 'badge'), '3');

      // The screen that opened it goes; the badge stays live.
      await tester.pumpWidget(host(list: false));
      await settle(tester);
      await cloud.addDocument('cards', {'title': 'd'}, id: 'd');
      await settle(tester);
      expect(shown(tester, 'badge'), '4');
      expect(cloud.live, 1);

      // Showing it again reads the live value at once, without a new subscription.
      await tester.pumpWidget(host());
      await settle(tester);
      expect(shown(tester, 'list'), 'loaded 4 cards');
      expect(cloud.watches, 1);

      await tester.pumpWidget(const SizedBox());
      expect(cloud.live, 1, reason: 'the app keeps it while it lives');
      app.dispose();
      await tester.pump();
      expect(cloud.live, 0);
      cloud.dispose();
    });

    testWidgets('a screen\'s own load opens one subscription, closed when the screen goes', (tester) async {
      await start(tester, 'screen');
      await tester.pumpWidget(host());
      await settle(tester);
      expect(cloud.watches, 2);
      expect(shown(tester, 'badge'), '2');
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(cloud.live, 0);
      app.dispose();
      cloud.dispose();
    });

    group('an app\'s live data', () {

      test('reports a later error instead of crashing', () async {
        final vars = VariableScope(const []);
        addTearDown(vars.dispose);
        final errors = <Object>[];
        final sources = AppDataSources(vars, onError: (e, _) => errors.add(e));
        addTearDown(sources.dispose);
        final s = StreamController<Object?>();
        final load = sources.load('v', 'k', () => s.stream);
        s.add(1);
        await load;
        s.addError(StateError('offline'));
        await Future<void>.delayed(Duration.zero);
        expect(errors, hasLength(1));
        expect(vars.read('v.status'), 'error');
      });

      test('reloads when the signed-in user changes', () async {
        final values = ValuesScope({
          'auth': {'uid': 'u1'},
        });
        final vars = VariableScope(const [], parent: values);
        addTearDown(values.dispose);
        addTearDown(vars.dispose);
        final sources = AppDataSources(vars);
        addTearDown(sources.dispose);
        final users = <Object?>[];
        Stream<Object?> open() {
          users.add(vars.read('auth.uid'));
          return Stream.value([vars.read('auth.uid')]);
        }

        await sources.load('mine', 'q', open);
        values.set('auth', {'uid': 'u1', 'name': 'renamed'});
        expect(users, ['u1'], reason: 'the same user');
        values.set('auth', {'uid': 'u2'});
        await Future<void>.delayed(Duration.zero);
        expect(users, ['u1', 'u2']);
        expect(vars.read('mine.data'), ['u2']);
      });
    });
  });

  group('the signed-in user', () {
    testWidgets('a profile update keeps the fields it leaves out and clears the ones it sets empty', (tester) async {
      final auth = _DelayedAuth(
        signedIn: const AppUser(uid: 'sandbox', displayName: 'Original', photoUrl: 'https://sandbox.example/original.png'),
      );
      final app = Codelessly.fromBundle(
        _authBundle(),
        config: CodelesslyConfig(
          services: Services(auth: auth, analytics: const NoAnalytics()),
        ),
        fonts: const NoFontFetcher(),
      );
      final controller = CodelesslyWidgetController();
      final errors = <Object>[];
      await tester.pumpWidget(
        MaterialApp(
          home: CodelesslyWidget(codelessly: app, controller: controller, onActionError: (e, s, a) => errors.add(e)),
        ),
      );
      await settle(tester);
      Future<void> update(Json fields) => const CodelesslyActions().trigger(
        _node([
          {'type': 'auth', 'operation': 'updateProfile', ...fields},
        ]),
        'click',
        controller.actionContext!,
      );
      await update({'displayName': 'Changed name'});
      expect(auth.currentUser!.displayName, 'Changed name');
      expect(auth.currentUser!.photoUrl, 'https://sandbox.example/original.png');
      expect(controller.read('auth.photoUrl'), 'https://sandbox.example/original.png');
      await update({'photoUrl': 'https://sandbox.example/changed.png'});
      expect(auth.currentUser!.displayName, 'Changed name');
      expect(controller.read('auth.displayName'), 'Changed name');
      expect(controller.read('auth.photoUrl'), 'https://sandbox.example/changed.png');
      await update({'displayName': r'${seen}'});
      expect(controller.read('auth.displayName'), '');
      expect(controller.read('auth.photoUrl'), 'https://sandbox.example/changed.png');
      await update({'displayName': 'Restored name'});
      await update({'photoUrl': r'${seen}'});
      expect(controller.read('auth.displayName'), 'Restored name');
      expect(controller.read('auth.photoUrl'), '');
      await update({'photoUrl': 'https://sandbox.example/final.png'});
      await const CodelesslyActions().trigger(
        _node([
          {'type': 'auth', 'operation': 'updatePhoto', 'photoUrl': ''},
        ]),
        'click',
        controller.actionContext!,
      );
      expect(controller.read('auth.displayName'), 'Restored name');
      expect(controller.read('auth.photoUrl'), '');
      expect(errors, isEmpty);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      app.dispose();
      auth.dispose();
    });
    test('after an auth failure the user stays signed out until a sign-in succeeds', () async {
      final auth = _DelayedAuth(
        signedIn: const AppUser(uid: 'old', email: 'old@example.test', displayName: 'Old'),
      );
      final app = Codelessly(
        config: CodelesslyConfig(
          services: Services(auth: auth, analytics: const NoAnalytics()),
        ),
      );
      final scope = app.appVariables;
      final context = RuntimeActionContext(scope: scope, services: app.services, refreshAuthValues: app.refreshAuthValues);
      expect(scope.read('auth.displayName'), 'Old');
      auth.events.addError(StateError('sandbox auth stream unavailable'));
      await pumpEventQueue();
      expect(auth.currentUser!.uid, 'old');
      expect(scope.read('auth.isSignedIn'), false);
      await const CodelesslyActions().trigger(
        _node([
          {'type': 'auth', 'operation': 'sendPasswordResetEmail', 'email': 'old@example.test'},
          {'type': 'auth', 'operation': 'updateProfile', 'displayName': 'Still stale'},
        ]),
        'click',
        context.withScope(ValuesScope({}, scope)),
      );
      expect(scope.read('auth.isSignedIn'), false, reason: 'non-sign-in operations cannot revive a stale service identity');
      await const CodelesslyActions().trigger(
        _node([
          {'type': 'auth', 'operation': 'signUp', 'email': 'new@example.test', 'password': 'Stargazer42', 'displayName': 'New'},
        ]),
        'click',
        context.withScope(ValuesScope({}, scope)),
      );
      expect(scope.read('auth.isSignedIn'), true);
      expect(scope.read('auth.email'), 'new@example.test');
      expect(scope.read('auth.displayName'), 'New');
      context.dispose();
      app.dispose();
      auth.dispose();
    });
  });
}
