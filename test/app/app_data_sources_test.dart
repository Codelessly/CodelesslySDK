// `loadCloudData` with `scope: app`: one live subscription per app, shared by
// every CodelesslyWidget of the same Codelessly instance (two host screens, a
// badge and a list), writing an app variable every screen reads, and
// outliving the screen that opened it.
import 'dart:async';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

void main() {
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

  testWidgets('screen scoped loads open one subscription per screen, closed with it', (tester) async {
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

  group('AppDataSources', () {
    test('another source for the variable replaces the first; a failed one opens again', () async {
      final vars = VariableScope(const []);
      addTearDown(vars.dispose);
      final sources = AppDataSources(vars);
      addTearDown(sources.dispose);
      final a = StreamController<Object?>(), b = StreamController<Object?>();
      var cancelledA = false;
      a.onCancel = () => cancelledA = true;
      final first = sources.load('v', 'a', () => a.stream);
      expect(vars.read('v.status'), 'loading', reason: 'declared on first use');
      a.add([1]);
      await first;
      expect(vars.read('v.data'), [1]);
      expect(sources.load('v', 'a', () => throw StateError('not opened again')), completes);
      final second = sources.load('v', 'b', () => b.stream);
      await Future<void>.delayed(Duration.zero);
      expect(cancelledA, isTrue);
      b.addError(StateError('rules'));
      await expectLater(second, throwsStateError);
      expect(vars.read('v.status'), 'error');
      expect(sources.active, isEmpty);
      final c = StreamController<Object?>();
      final third = sources.load('v', 'b', () => c.stream);
      c.add([3]);
      await third;
      expect(vars.read('v.data'), [3]);
      expect(sources.opened, 3);
    });

    test('a later error is reported, not thrown', () async {
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

    test('every source opens again when the signed-in user changes', () async {
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
}
