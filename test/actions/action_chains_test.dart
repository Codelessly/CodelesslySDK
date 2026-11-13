import 'dart:async';
import 'dart:convert';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import '../support/legacy.dart';

import '../support/recording_ui.dart';
import '../support/screen.dart' as harness;

// The actions runtime without a render tree: actions, chains, API calls,
// delays, list text items and trigger debounce.

Variable v(String name, Object? value, [VariableType type = VariableType.text]) =>
    Variable(name: name, type: type, value: type.coerce(value));

/// A node whose `click` runs [actions] (JSON).
Node clickNode(List<Json> actions, {String trigger = 'click', Map<String, Object?> extra = const {}}) => migratedNode({
      'type': 'box',
      'actions': [
        {'trigger': {'type': trigger, ...extra}, 'actions': actions},
      ],
    }, id: 'n')!;

class Harness {
  Harness({List<Variable> variables = const [], Services? services, Map<String, AppFunction> functions = const {}, ActionUi? ui})
      : scope = VariableScope(variables) {
    context = RuntimeActionContext(
      scope: scope,
      services: services ?? Services(),
      functions: functions,
      ui: ui ?? const NoActionUi(),
      onError: (e, s, a) => errors.add(e is ActionFailed ? e.error : e),
    );
  }

  final VariableScope scope;
  late final RuntimeActionContext context;
  final List<Object> errors = [];
  final actions = const CodelesslyActions();

  Future<void> click(List<Json> list, {Json event = const {}, ActionCancellation? cancellation}) =>
      actions.run(clickNode(list), 'click', context, event: event, cancellation: cancellation);

  Object? operator [](String name) => scope.read(name);
}

Json setVar(String name, String value, {String? op, String? index, String? mapKey}) => {
      'type': 'setVariable',
      'variable': name,
      'value': value,
      'op': ?op,
      'index': ?index,
      'mapKey': ?mapKey,
    };

class SocketLike implements Exception {
  const SocketLike();
}

// Actions: the set variable glide, animate
// variable, for-each's `loop`, haptics, run script (a pluggable runner),
// persisted variables and the back block (canvas blockBack and its
// backPressed reactions).

Node tapNode(List<Json> actions) => migratedNode({
      'type': 'box',
      'actions': [
        {'trigger': {'type': 'click'}, 'actions': actions},
      ],
    }, id: 'n')!;

class ScopeHarness {
  ScopeHarness({List<Variable> variables = const [], Services? services, List<ScriptDef> scripts = const [], Map<String, AppFunction> functions = const {}})
      : scope = VariableScope(variables) {
    context = RuntimeActionContext(
      scope: scope,
      services: services ?? Services(),
      scripts: scripts,
      functions: functions,
      onError: (e, s, a) => errors.add(e is ActionFailed ? e.error : e),
    );
  }

  final VariableScope scope;
  late final RuntimeActionContext context;
  final List<Object> errors = [];

  Future<void> click(List<Json> list, {ActionCancellation? cancellation}) =>
      const CodelesslyActions().run(tapNode(list), 'click', context, cancellation: cancellation);

  Object? operator [](String name) => scope.read(name);
}

// A screen's `load` chain survives the screen being moved within a frame
// (Strata v2: a specimen page pushed with a container transform; its record
// arrives after a 450 ms delay in its load reaction, and the route moved the
// page into a new wrapper mid-delay, which cancelled the chain: the record
// skeleton never went away). Removing it for good still cancels the chain.

Map<String, Json> _nodes() => {
      'col': {
        'type': 'column',
        'layout': {'width': 200, 'height': 100},
        'actions': [
          {
            'trigger': {'type': 'load'},
            'actions': [
              {'type': 'delay', 'ms': 300},
              {'type': 'setVariable', 'variable': 'state', 'value': 'ready'},
            ],
          },
        ],
      },
    };

Future<VariableScope> _host(WidgetTester tester, ValueNotifier<int> mode) async {
  final doc = LayoutDocument.fromJson({'roots': ['col'], 'nodes': _nodes()});
  final scope = VariableScope([const Variable(name: 'state', value: 'loading')]);
  final values = NodeValues(DocumentSource(doc));
  final tree = NodeTree(values, binder: NodeBinder(scope: scope));
  final context = RuntimeActionContext(scope: scope, ui: const NoActionUi(), tree: tree, nodeValues: values, services: Services());
  final reactions = TreeReactions(runner: const CodelesslyActions(), context: context);
  tree.interactions = reactions;
  addTearDown(() {
    reactions.dispose();
    tree.dispose();
  });
  final key = GlobalKey();
  await tester.pumpWidget(MaterialApp(
    home: ValueListenableBuilder<int>(
      valueListenable: mode,
      builder: (context, m, _) {
        final view = NodeView(key: key, tree: tree, rootId: 'col', interactive: true);
        return switch (m) {
          0 => Align(alignment: Alignment.topLeft, child: view),
          1 => Align(alignment: Alignment.topLeft, child: Padding(padding: const EdgeInsets.all(1), child: view)),
          _ => const SizedBox(),
        };
      },
    ),
  ));
  return scope;
}

Future<harness.Screen> setup(WidgetTester tester) => harness.show(
  tester,
  {
    'col': {
      'type': 'stack',
      'layout': {'width': 200, 'height': 400},
      'children': ['panel'],
    },
    'panel': {
      'type': 'column',
      'layout': {'width': 200, 'height': 400},
      'bind': {'visible': r'${shown}'},
      'children': ['button'],
    },
    'button': {
      'type': 'box',
      'layout': {'width': 100, 'height': 40},
      'actions': [
        harness.reaction('click', [
          {'type': 'setVariable', 'variable': 'shown', 'value': 'false'},
          {'type': 'delay', 'ms': 100},
          {'type': 'setVariable', 'variable': 'done', 'value': 'true'},
        ]),
      ],
    },
  },
  variables: [harness.v('shown', true, VariableType.boolean), harness.v('done', false, VariableType.boolean)],
);

Future<void> write(VariableScope scope, String formula, {ActionCancellation? cancellation}) => const CodelesslyActions().run(
  Node.fromJson({
    'type': 'box',
    'actions': [
      {
        'trigger': {'type': 'click'},
        'actions': [
          {'type': 'setVariable', 'variable': 'rows', 'value': formula},
        ],
      },
    ],
  }, id: 'tap')!,
  'click',
  RuntimeActionContext(scope: scope),
  cancellation: cancellation,
);

void main() {
  group('action types an app defines', () {
    test('an unknown action type runs the handler the app registered for it, in order', () async {
      final h = Harness(variables: [v('n', 0, VariableType.integer)]);
      final seen = <Object?>[];
      final actions = CodelesslyActions(handlers: {
        'acme.track': (a, run) {
          seen.add(((a as UnknownAction).json['event'], h['n']));
        },
      });
      await actions.run(
        clickNode([
          setVar('n', '1', op: 'add'),
          {'type': 'acme.track', 'event': 'tapped'},
          setVar('n', '1', op: 'add'),
        ]),
        'click',
        h.context,
      );
      expect(seen, [('tapped', 1)]);
      expect(h['n'], 2);
      expect(h.errors, isEmpty);
    });
    test('an unknown action type with no handler is skipped, as a disabled one is', () async {
      final h = Harness(variables: [v('n', 0, VariableType.integer)]);
      var calls = 0;
      await h.click([{'type': 'acme.track'}, setVar('n', '1', op: 'add')]);
      await CodelesslyActions(handlers: {'acme.track': (a, run) => calls++}).run(
        clickNode([{'type': 'acme.track', 'enabled': false}, setVar('n', '1', op: 'add')]),
        'click',
        h.context,
      );
      expect(calls, 0);
      expect(h['n'], 2);
      expect(h.errors, isEmpty);
    });
  });
  group('conditions on a trigger', () {
    test('a trigger\'s condition can read what triggered it or a yes/no variable', () async {
      final h = Harness(variables: [v('n', 0, VariableType.integer), v('on', false, VariableType.boolean)]);
      final byEvent = clickNode([setVar('n', '1', op: 'add')], extra: {'when': r'${= result.allow}'});
      await h.actions.run(byEvent, 'click', h.context, event: {'result': {'allow': false}});
      await h.actions.run(byEvent, 'click', h.context, event: {'result': {'allow': true}});
      expect(h['n'], 1);
      final byPath = clickNode([setVar('n', '10', op: 'add')], trigger: 'changed', extra: {'when': 'on'});
      await h.actions.run(byPath, 'changed', h.context);
      expect(h['n'], 1);
      h.scope.set('on', true);
      await h.actions.run(byPath, 'changed', h.context);
      expect(h['n'], 11);
    });
  });

  group('chains', () {
    test('actions run in order, each waiting for the one before', () async {
      final calls = <String>[];
      final first = Completer<void>();
      final h = Harness(functions: {
        'first': (c, p) {
          calls.add('first started');
          return first.future.then((_) => calls.add('first done'));
        },
        'second': (c, p) => calls.add('second'),
      });
      final done = h.click([
        {'type': 'callFunction', 'name': 'first'},
        {'type': 'callFunction', 'name': 'second'},
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(calls, ['first started']);
      first.complete();
      await done;
      expect(calls, ['first started', 'first done', 'second']);
    });

    test('a failing action stops the chain without crashing', () async {
      final calls = <String>[];
      final h = Harness(functions: {
        'fails': (c, p) async => throw StateError('x'),
        'throwsSync': (c, p) => throw StateError('y'),
        'next': (c, p) => calls.add('next'),
      });
      for (final failing in ['fails', 'throwsSync']) {
        await h.click([
          {'type': 'callFunction', 'name': failing},
          {'type': 'callFunction', 'name': 'next'},
        ]);
      }
      expect(calls, isEmpty);
      expect(h.errors, hasLength(2));
    });

    test('a failing action that does not block lets the chain go on', () async {
      final calls = <String>[];
      final h = Harness(functions: {
        'fails': (c, p) async => throw StateError('x'),
        'next': (c, p) => calls.add('next'),
      });
      await h.click([
        {'type': 'callFunction', 'name': 'fails', 'nonBlocking': true},
        {'type': 'callFunction', 'name': 'next'},
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(calls, ['next']);
      expect(h.errors, hasLength(1));
    });

    test('a disabled action, or one whose condition fails, is skipped', () async {
      final h = Harness(variables: [v('n', 0, VariableType.integer), v('on', false, VariableType.boolean)]);
      await h.click([
        {...setVar('n', '1', op: 'add'), 'enabled': false},
        {...setVar('n', '10', op: 'add'), 'when': {'left': r'${on}', 'op': 'isTrue'}},
        setVar('n', '100', op: 'add'),
      ]);
      expect(h['n'], 100);
    });

    test('all reactions to a trigger run, in order', () async {
      final h = Harness(variables: [v('log', '')]);
      final node = migratedNode({
        'type': 'box',
        'actions': [
          {'trigger': {'type': 'click'}, 'actions': [setVar('log', r'${log}a')]},
          {'trigger': {'type': 'load'}, 'actions': [setVar('log', r'${log}x')]},
          {'trigger': {'type': 'click'}, 'actions': [setVar('log', r'${log}b')]},
        ],
      }, id: 'n')!;
      await h.actions.trigger(node, 'click', h.context);
      expect(h['log'], 'ab');
    });

    test('each action can read the event and then what the action before it gave', () async {
      final h = Harness(variables: [v('seen', '')], functions: {'id': (c, p) => 'doc-${p['n']}'});
      await h.click([
        setVar('seen', r'${result.x}'),
        {'type': 'callFunction', 'name': 'id', 'params': {'n': r'${= 1 + 1}'}},
        setVar('seen', r'${seen}/${result}'),
      ], event: {'result': {'x': 7}});
      expect(h['seen'], '7/doc-2');
    });

    testWidgets('a debounced trigger runs once after a burst', (tester) async {
      {
        var calls = 0;
        final h = Harness(functions: {'search': (c, p) => calls++});
        final node = clickNode([{'type': 'callFunction', 'name': 'search'}], trigger: 'changed', extra: {'debounceMs': 300});
        for (var i = 0; i < 3; i++) {
          h.actions.run(node, 'changed', h.context, event: {'value': 'q$i'});
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(calls, 0);
        await tester.pump(const Duration(milliseconds: 300));
        expect(calls, 1);
        h.actions.run(clickNode([{'type': 'callFunction', 'name': 'search'}], trigger: 'changed'), 'changed', h.context);
        await tester.pump();
        expect(calls, 2);
      }
    });

    testWidgets('a cancelled chain stops: its delay ends and nothing after runs', (tester) async {
      {
        final h = Harness(variables: [v('n', 0, VariableType.integer)]);
        final cancel = ActionCancellation();
        var done = false;
        h.click([
          setVar('n', '1'),
          {'type': 'delay', 'ms': 1000},
          setVar('n', '2'),
        ], cancellation: cancel).then((_) => done = true);
        await tester.pump(const Duration(milliseconds: 100));
        expect(h['n'], 1);
        cancel.cancel();
        await tester.pump();
        expect(done, isTrue);
        await tester.pump(const Duration(seconds: 2));
        expect(h['n'], 1);
        expect(h.errors, isEmpty);
      }
    });
  });

  group('delay', () {
    testWidgets('waits as long as its formula says, else its fixed time', (tester) async {
      {
        final h = Harness(variables: [v('networkMode', 'slow'), v('done', false, VariableType.boolean)]);
        h.click([
          {'type': 'delay', 'ms': 900, 'duration': r"${= networkMode == 'slow' ? 4000 : 900}"},
          setVar('done', 'true'),
        ]);
        await tester.pump(const Duration(milliseconds: 3900));
        expect(h['done'], isFalse);
        await tester.pump(const Duration(milliseconds: 200));
        expect(h['done'], isTrue);

        h.scope.set('done', false);
        h.click([
          {'type': 'delay', 'ms': 300, 'duration': r'${missing}'},
          setVar('done', 'true'),
        ]);
        await tester.pump(const Duration(milliseconds: 310));
        expect(h['done'], isTrue);
      }
    });

  });

  group('set variable', () {
    test('sets, adds to and subtracts from numbers, and toggles yes/no values', () async {
      final h = Harness(variables: [v('n', 5, VariableType.integer), v('d', 1.5, VariableType.decimal), v('b', false, VariableType.boolean)]);
      await h.click([setVar('n', '2', op: 'add'), setVar('d', '0.5', op: 'subtract'), {'type': 'setVariable', 'variable': 'b', 'op': 'toggle'}]);
      expect((h['n'], h['d'], h['b']), (7, 1.0, true));
      await h.click([setVar('n', r'${= n * 10}')]);
      expect(h['n'], 70);
    });

    test('edits a list at an index', () async {
      final h = Harness(variables: [v('l', const ['a', 'b'], VariableType.list), v('i', 1, VariableType.integer)]);
      await h.click([setVar('l', 'x', op: 'insert', index: r'${i}')]);
      expect(h['l'], ['a', 'x', 'b']);
      await h.click([setVar('l', 'y', op: 'update', index: '0')]);
      expect(h['l'], ['y', 'x', 'b']);
      await h.click([{'type': 'setVariable', 'variable': 'l', 'op': 'removeAt', 'index': '2'}]);
      expect(h['l'], ['y', 'x']);
      await h.click([setVar('l', 'y', op: 'remove')]);
      expect(h['l'], ['x']);
      await h.click([setVar('l', '["p", "q"]', op: 'insertAll', index: '0')]);
      expect(h['l'], ['p', 'q', 'x']);
      await h.click([setVar('l', '[]')]);
      expect(h['l'], isEmpty);
    });

    test('edits a map by key, and a value deep inside a variable', () async {
      final h = Harness(variables: [v('m', const {'a': 1}, VariableType.map)]);
      await h.click([setVar('m', '2', op: 'update', mapKey: 'b')]);
      expect(h['m'], {'a': 1, 'b': 2});
      await h.click([{'type': 'setVariable', 'variable': 'm', 'op': 'remove', 'mapKey': 'a'}]);
      expect(h['m'], {'b': 2});
      await h.click([setVar('m', '{"c": [1]}', op: 'add')]);
      expect(h['m'], {'b': 2, 'c': [1]});
      await h.click([setVar('m.c', '5', op: 'add')]);
      expect(h['m'], {'b': 2, 'c': [1, 5]});
      await h.click([setVar('m.b', 'two')]);
      expect(h['m'], {'b': 'two', 'c': [1, 5]});
    });

    test('does not set a computed or undeclared variable', () async {
      final h = Harness(variables: [v('n', 1, VariableType.integer), const Variable(name: 'twice', formula: 'n * 2')]);
      await h.click([setVar('twice', '9'), setVar('nope', '1')]);
      expect(h['twice'], 2);
      expect(h['nope'], isNull);
      expect(h.errors, isEmpty);
    });
  });

  group('flow', () {
    test('an if runs the branch its condition picks, and navigation inside it still works', () async {
      final ui = RecordingUi();
      final h = Harness(variables: [v('err', '')], ui: ui);
      final chain = [
        {
          'type': 'if',
          'condition': {'and': [{'left': r'${err}', 'op': 'isEmpty'}]},
          'then': [{'type': 'navigate', 'mode': 'replace', 'to': 'home', 'params': {'id': r'${= 40 + 2}'}}],
          'else': [{'type': 'openLink', 'url': 'x'}],
        },
      ];
      await h.click(chain);
      expect(ui.log, ['navigate replace home {id: 42}']);
      h.scope.set('err', 'bad');
      await h.click(chain);
      expect(ui.log, hasLength(1));
    });

    test('a for-each runs its actions for each item, which they can read with its index', () async {
      final h = Harness(variables: [v('rows', const ['a', 'b', 'c'], VariableType.list), v('out', '')]);
      await h.click([
        {'type': 'forEach', 'items': 'rows', 'actions': [setVar('out', r'${out}${result.index}${result.item}')]},
      ]);
      expect(h['out'], '0a1b2c');
    });

    test('a confirm runs its actions, or its cancel actions', () async {
      final ui = RecordingUi()..confirmAnswer = true;
      final h = Harness(variables: [v('out', '')], ui: ui);
      final chain = [
        {'type': 'confirm', 'title': r'Delete ${= 1}?', 'actions': [setVar('out', 'yes')], 'cancelActions': [setVar('out', 'no')]},
      ];
      await h.click(chain);
      expect(h['out'], 'yes');
      ui.confirmAnswer = false;
      await h.click(chain);
      expect(h['out'], 'no');
      expect(ui.log, ['confirm Delete 1?', 'confirm Delete 1?']);
    });

    test('opening a modal gives the chain the value it closed with, and toasts and links reach the app', () async {
      final ui = RecordingUi()..modalResult = {'reason': 'late'};
      final services = Services(links: RecordingLinkOpener());
      final h = Harness(variables: [v('out', '')], ui: ui, services: services);
      await h.click([
        {'type': 'openModal', 'to': 'd', 'presentation': 'bottomSheet'},
        setVar('out', r'${result.reason}'),
        {'type': 'showToast', 'message': r'Saved ${out}'},
        {'type': 'openLink', 'url': r'https://x/${out}'},
        {'type': 'closeModal', 'result': {'ok': r'${= 1 == 1}'}},
      ]);
      expect(h['out'], 'late');
      expect(ui.log, ['modal d bottomSheet', 'toast Saved late', 'close {ok: true}']);
      expect((services.links as RecordingLinkOpener).opened, ['https://x/late']);
    });
  });

  test('closing a modal returns any value, also from inside an if', () async {
    final ui = RecordingUi();
    final h = Harness(variables: [v('day', '2026-12-15')], ui: ui);
    await h.click([
      {'type': 'closeModal', 'result': 'duplicate'},
      {'type': 'if', 'condition': {'left': r'${day}', 'op': 'notEqualsTo', 'right': ''},
       'then': [{'type': 'closeModal', 'result': r'${day}'}]},
      {'type': 'closeModal'},
    ]);
    expect(ui.log, ['close duplicate', 'close 2026-12-15', 'close null']);
  });

  group('services', () {
    test('an API call runs its success or error actions with the response', () async {
      final client = MockClient((r) async => r.url.path == '/ok'
          ? http.Response(jsonEncode({'temp': 21}), 200, headers: {'content-type': 'application/json'})
          : http.Response('nope', 500));
      final services = Services(
        api: HttpApiService(client: client),
        config: ServiceConfig(apis: {
          'ok': const HttpApi(id: 'ok', url: r'https://api/ok?city=${city}', inputs: [ApiInput('city')]),
          'bad': const HttpApi(id: 'bad', url: 'https://api/bad'),
        }),
      );
      final h = Harness(variables: [v('out', ''), v('city', 'Oslo')], services: services);
      await h.click([
        {
          'type': 'callApi', 'api': 'ok', 'params': {'city': r'${city}'}, //
          'onSuccess': [setVar('out', r'ok ${result.data.temp}')],
          'onError': [setVar('out', 'error')],
        },
      ]);
      expect(h['out'], 'ok 21');
      await h.click([
        {'type': 'callApi', 'api': 'bad', 'onSuccess': [setVar('out', 'ok')], 'onError': [setVar('out', r'error ${result.statusCode}')]},
      ]);
      expect(h['out'], 'error 500');
    });

    test('a failed request stops the chain unless it has error actions', () async {
      final client = MockClient((r) async => throw const SocketLike());
      final services = Services(api: HttpApiService(client: client), config: ServiceConfig(apis: {'a': const HttpApi(id: 'a', url: 'https://api/a')}));
      final h = Harness(variables: [v('out', '')], services: services);
      await h.click([{'type': 'callApi', 'api': 'a'}, setVar('out', 'after')]);
      expect(h['out'], '');
      expect(h.errors.single, isA<ApiRequestFailed>());
      await h.click([{'type': 'callApi', 'api': 'a', 'onError': [setVar('out', r'failed ${result.isError}')]}]);
      expect(h['out'], 'failed true');
    });

    test('storage actions write, write inside stored maps, remove and clear', () async {
      final services = Services();
      final h = Harness(services: services);
      await h.click([
        {'type': 'setStorage', 'key': 'n', 'valueType': 'integer', 'value': '2'},
        {'type': 'setStorage', 'key': 'n', 'valueType': 'integer', 'op': 'add', 'value': '3'},
        {'type': 'setStorage', 'key': 'prefs.theme', 'value': 'dark'},
        {'type': 'setStorage', 'key': 'n', 'valueType': 'integer', 'value': '9', 'skipIfExists': true},
      ]);
      expect(services.storage.get('n'), 5);
      expect(services.storage.get('prefs'), {'theme': 'dark'});
      await h.click([{'type': 'setStorage', 'operation': 'remove', 'key': 'prefs.theme'}]);
      expect(services.storage.get('prefs'), isEmpty);
      await h.click([{'type': 'setStorage', 'operation': 'clear'}]);
      expect(services.storage.get('n'), isNull);
    });

    test('cloud data actions create, load into a variable, update and delete', () async {
      final services = Services();
      final h = Harness(services: services, variables: [v('rows', const [], VariableType.list), v('id', '')]);
      await h.click([
        {'type': 'cloudData', 'operation': 'create', 'collection': 'tasks', 'fields': [{'field': 'title', 'value': 'A'}, {'field': 'n', 'value': r'${= 1}'}]},
        setVar('id', r'${result}'),
        {'type': 'cloudData', 'operation': 'update', 'collection': 'tasks', 'id': r'${id}', 'fields': [{'field': 'n', 'value': '2', 'operation': 'increment'}]},
        {'type': 'cloudData', 'operation': 'query', 'collection': 'tasks', 'resultVariable': 'rows'},
      ]);
      expect(h.errors, isEmpty);
      final rows = h['rows']! as List;
      expect(rows.single['title'], 'A');
      expect(rows.single['n'], 3);
      await h.click([{'type': 'cloudData', 'operation': 'delete', 'collection': 'tasks', 'id': r'${id}'}, {'type': 'cloudData', 'operation': 'count', 'collection': 'tasks', 'resultVariable': 'id'}]);
      expect(h['id'], '0');
    });

    test('auth actions sign up and sign in, and put an error into their variable', () async {
      final auth = MemoryAuthService();
      final h = Harness(services: Services(auth: auth), variables: [v('err', ''), v('uid', '')]);
      await h.click([
        {'type': 'auth', 'operation': 'signUp', 'email': 'a@b.c', 'password': 'secret1'},
        setVar('uid', r'${result}'),
      ]);
      expect(h['uid'], isNotEmpty);
      await h.click([
        {'type': 'auth', 'operation': 'signOut'},
        {'type': 'auth', 'operation': 'signIn', 'email': 'a@b.c', 'password': 'wrong', 'errorVariable': 'err'},
      ]);
      expect(h['err'], isNotEmpty);
      expect(h.errors, hasLength(1));
    });

    test('changing a password and deleting an account ask for the current password first', () async {
      final auth = MemoryAuthService();
      final h = Harness(services: Services(auth: auth), variables: [v('err', '')]);
      await h.click([
        {'type': 'auth', 'operation': 'signUp', 'email': 'a@b.c', 'password': 'secret1'},
        {'type': 'auth', 'operation': 'updatePassword', 'currentPassword': 'nope', 'password': 'secret22', 'errorVariable': 'err'},
      ]);
      expect(h['err'], isNotEmpty, reason: 'a wrong current password stops it');
      await h.click([
        {'type': 'auth', 'operation': 'updatePassword', 'currentPassword': 'secret1', 'password': 'secret22', 'errorVariable': 'err'},
        {'type': 'auth', 'operation': 'deleteAccount', 'currentPassword': 'secret22'},
      ]);
      expect(h['err'], '');
      expect(auth.currentUser, isNull, reason: 'deleted with the new password');
    });

    test('a guest who signs up keeps the same user id', () async {
      final auth = MemoryAuthService();
      final h = Harness(services: Services(auth: auth), variables: [v('guest', ''), v('uid', '')]);
      await h.click([
        {'type': 'auth', 'operation': 'signInAnonymously'},
        setVar('guest', r'${result}'),
      ]);
      expect(h.errors, isEmpty);
      expect(auth.currentUser!.isGuest, isTrue);
      expect(h['guest'], isNotEmpty);
      await h.click([
        {'type': 'auth', 'operation': 'signUp', 'email': 'g@b.c', 'password': 'secret1', 'displayName': 'Gus'},
        setVar('uid', r'${result}'),
      ]);
      expect(h['uid'], h['guest'], reason: 'signing up as a guest upgrades the same account');
      expect(auth.currentUser!.isGuest, isFalse);
      expect(auth.currentUser!.email, 'g@b.c');
    });
  });

  group('a variable set with a duration', () {
    testWidgets('glides a number to its value while the chain waits', (tester) async {
      final h = ScopeHarness(variables: [v('t', 0, VariableType.decimal), v('after', '')]);
      var done = false;
      unawaited(h.click([
        {'type': 'setVariable', 'variable': 't', 'value': '10', 'animateMs': '1000'},
        {'type': 'setVariable', 'variable': 'after', 'value': 'yes'},
      ]).then((_) => done = true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(h['t'] as double, closeTo(5, 0.2));
      expect(h['after'], '');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      expect(h['t'], 10.0);
      expect(h['after'], 'yes');
      expect(done, isTrue);
    });

    testWidgets('a number animated with a spring overshoots and settles on its target', (tester) async {
      // The legacy glide decodes as `animate` (animateTo); a spring drives it
      // instead of a duration.
      expect(legacyAction({'type': 'setVariable', 'variable': 't', 'value': '1', 'animateMs': '300'}), isA<AnimateAction>());
      final h = ScopeHarness(variables: [v('t', 0, VariableType.decimal)]);
      var done = false;
      unawaited(h.click([
        {'type': 'animate', 'variable': 't', 'command': 'animateTo', 'target': '10', 'spring': {'duration': 400, 'bounce': 0.4}},
      ]).then((_) => done = true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      final mid = h['t'] as double;
      expect(mid, inExclusiveRange(0, 14));
      var peak = mid;
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        peak = (h['t'] as double) > peak ? h['t'] as double : peak;
      }
      expect(peak, greaterThan(10), reason: 'a bouncy spring overshoots');
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(h['t'], 10.0);
      expect(done, isTrue);
    });

    testWidgets('sets text at once', (tester) async {
      final h = ScopeHarness(variables: [v('s', 'a')]);
      await h.click([
        {'type': 'setVariable', 'variable': 's', 'value': 'b', 'animateMs': '500'},
      ]);
      expect(h['s'], 'b');
    });
  });

  group('an animate-variable action', () {
    testWidgets('plays to the end while the chain waits, and can be paused, moved, resumed and stopped', (tester) async {
      final h = ScopeHarness(variables: [v('t', 0, VariableType.decimal), v('n', 0, VariableType.integer)]);
      var played = false;
      unawaited(h.click([
        {'type': 'animateVariable', 'variable': 't', 'from': '0', 'to': '100', 'durationMs': 1000},
      ]).then((_) => played = true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(h['t'] as double, closeTo(25, 1));
      await h.click([
        {'type': 'animateVariable', 'variable': 't', 'mode': 'pause'},
      ]);
      await tester.pump(const Duration(milliseconds: 300));
      final paused = h['t'] as double;
      await tester.pump(const Duration(milliseconds: 300));
      expect(h['t'], paused);
      expect(played, isFalse);
      // Seek sets the value; resume goes on from there (half way: half the
      // time left).
      await h.click([
        {'type': 'animateVariable', 'variable': 't', 'mode': 'seek', 'to': '50'},
      ]);
      expect(h['t'], 50.0);
      unawaited(h.click([
        {'type': 'animateVariable', 'variable': 't', 'mode': 'resume'},
      ]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 520));
      await tester.pump();
      expect(h['t'], 100.0);
      expect(played, isTrue);

      // An integer variable holds whole numbers; stop leaves it where it is.
      unawaited(h.click([
        {'type': 'animateVariable', 'variable': 'n', 'to': '10', 'durationMs': 1000},
      ]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 330));
      await h.click([
        {'type': 'animateVariable', 'variable': 'n', 'mode': 'stop'},
      ]);
      final stopped = h['n'];
      expect(stopped, isA<int>());
      await tester.pump(const Duration(milliseconds: 500));
      expect(h['n'], stopped);
    });

    testWidgets('takes its length from a formula', (tester) async {
      final h = ScopeHarness(variables: [v('t', 7, VariableType.decimal), v('total', 24, VariableType.decimal)]);
      unawaited(h.click([
        {'type': 'animateVariable', 'variable': 't', 'to': r'${total}', 'duration': r'${= (total - t) * 1000}'},
      ]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1000));
      expect(h['t'] as double, closeTo(8, 0.1), reason: 'one second of a 17 s play');
      await h.click([{'type': 'animateVariable', 'variable': 't', 'mode': 'stop'}]);
    });

    testWidgets('skips a computed or missing variable', (tester) async {
      final h = ScopeHarness(variables: [const Variable(name: 'c', type: VariableType.decimal, formula: '1 + 1')]);
      await h.click([
        {'type': 'animateVariable', 'variable': 'c', 'to': '5'},
        {'type': 'animateVariable', 'variable': 'nope', 'to': '5'},
      ]);
      expect(h.errors, isEmpty);
    });
  });

  test('a for-each turn can still read its item and index after an action in it gives a result', () async {
    final h = ScopeHarness(
      variables: [v('out', <Object?>[], VariableType.list)],
      functions: {'f': (c, p) => 'other'},
    );
    await h.click([
      {
        'type': 'forEach',
        'items': r'${= ["a", "b"]}',
        'actions': [
          {'type': 'callFunction', 'name': 'f'},
          {'type': 'setVariable', 'variable': 'out', 'op': 'add', 'value': r'${loop.index}:${loop.item}:${result}'},
        ],
      },
    ]);
    expect(h['out'], ['0:a:other', '1:b:other']);
  });

  testWidgets('a haptic action buzzes by its kind, only while its condition holds', (tester) async {
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') calls.add('${call.arguments}');
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final h = ScopeHarness(variables: [v('on', false, VariableType.boolean)]);
    Json haptic(String kind) => {
          'type': 'haptic',
          'kind': kind,
          'when': {'left': r'${on}', 'op': 'isTrue'},
        };
    await h.click([haptic('heavy')]);
    expect(calls, isEmpty);
    h.scope.set('on', true);
    await h.click([haptic('heavy'), haptic('selection')]);
    expect(calls, ['HapticFeedbackType.heavyImpact', 'HapticFeedbackType.selectionClick']);
  });

  test('a persisted variable starts from what the device stored and saves its changes', () async {
    final storage = MemoryLocalStorage({'codelessly.variable.var1': 'saved'});
    final scope = VariableScope(const [
      Variable(id: 'var1', name: 'draft', value: 'default', persist: true),
      Variable(id: 'var2', name: 'plain', value: 'p'),
    ]);
    final draft = PersistedVariable.attach(scope, scope.variable('draft')!, storage);
    final plain = PersistedVariable.attach(scope, scope.variable('plain')!, storage);
    expect(scope.read('draft'), 'saved');
    scope.set('draft', 'typed');
    scope.set('plain', 'q');
    expect(storage.get('codelessly.variable.var1'), 'typed');
    expect(storage.containsKey('codelessly.variable.var2'), isFalse);
    draft.dispose();
    plain.dispose();
    scope.set('draft', 'later');
    expect(storage.get('codelessly.variable.var1'), 'typed');
  });

  group('the back button', () {
    Json layout(String id, {Json canvas = const {}, List<Json> variables = const []}) => {
          'schema': 2,
          'id': id,
          'roots': ['$id-c'],
          'nodes': {
            '$id-c': {
              'type': 'canvas',
              'name': id,
              'slots': {'body': '$id-b'},
              'layout': {'width': 400, 'height': 600},
              ...canvas,
            },
            '$id-b': {'type': 'stack', 'layout': {'width': {'fill': 400}, 'height': {'fill': 600}}},
          },
          if (variables.isNotEmpty) 'variables': {'$id-c': variables},
        };

    PublishBundle bundle() => PublishBundle.fromJson({
          'schema': 2,
          'model': {
            'projectId': 'p',
            'entryLayoutId': 'home',
            'layouts': {
              'home': {
                'canvases': [
                  {'id': 'home-c', 'name': 'home'},
                ],
              },
              'form': {
                'canvases': [
                  {'id': 'form-c', 'name': 'form'},
                ],
              },
            },
          },
          'layouts': {
            'home': layout('home'),
            'form': layout('form', canvas: {
              'bind': {'props.blockBack': r'${dirty}'},
              'actions': [
                {
                  'trigger': {'type': 'backPressed'},
                  'actions': [
                    {'type': 'setVariable', 'variable': 'tries', 'op': 'add', 'value': '1'},
                  ],
                },
              ],
            }, variables: [
              {'name': 'dirty', 'type': 'boolean', 'value': true},
              {'name': 'tries', 'type': 'integer', 'value': 0},
              {'id': 'd1', 'name': 'draft', 'value': '', 'persist': true},
            ]),
          },
        });

    testWidgets('stays on a screen that blocks back and runs its back reaction, and leaves otherwise', (tester) async {
      final storage = MemoryLocalStorage({'codelessly.variable.d1': 'kept'});
      final codelessly = Codelessly(
        config: CodelesslyConfig(projectId: 'p', services: Services(storage: storage)),
        loader: MemoryPublishLoader(bundle()),
        fonts: const NoFontFetcher(),
      );
      final home = CodelesslyWidgetController();
      final form = CodelesslyWidgetController(layoutId: 'form');
      addTearDown(home.dispose);
      addTearDown(form.dispose);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(
        navigatorKey: navigator,
        home: CodelesslyWidget(codelessly: codelessly, controller: home),
      ));
      await tester.pumpAndSettle();
      unawaited(navigator.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => CodelesslyWidget(codelessly: codelessly, controller: form),
      )));
      await tester.pumpAndSettle();
      expect(form.canvasId, 'form-c');
      expect(form.read('draft'), 'kept');

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(navigator.currentState!.canPop(), isTrue, reason: 'the form stays');
      expect(form.read('tries'), 1);

      form.setVariable('dirty', false);
      form.setVariable('draft', 'new');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(navigator.currentState!.canPop(), isFalse, reason: 'back left the form');
      expect(storage.get('codelessly.variable.d1'), 'new');
    });
  });

  group('a load reaction whose node moves or goes', () {
    testWidgets('finishes when its node is moved while it waits', (tester) async {
      final mode = ValueNotifier(0);
      final scope = await _host(tester, mode);
      await tester.pump(const Duration(milliseconds: 100));
      mode.value = 1; // re-parented (GlobalKey move) in one frame
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(scope.valueOf('state', scope), 'ready');
    });

    testWidgets('stops when its node is removed while it waits', (tester) async {
      final mode = ValueNotifier(0);
      final scope = await _host(tester, mode);
      await tester.pump(const Duration(milliseconds: 100));
      mode.value = 2; // gone
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(scope.valueOf('state', scope), 'loading');
    });

    testWidgets('a reaction that hides its own node still finishes', (tester) async {
      final s = await setup(tester);
      await tester.tapAt(s.center('button'));
      await tester.pump();
      expect(s['shown'], false);
      expect(s.tree.boxOf('button')!.attached, false);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();
      expect(s['done'], true);
    });
  });

  group('values written from a slow script', () {
    test('a list written from a slow script keeps its old value until the result arrives', () async {
      final result = Completer<Object?>();
      final scripts = ScriptsScope(
        scripts: const [ScriptDef(id: 'next', name: 'next')],
        runner: FunctionScriptRunner({'next': (_, _) => result.future}),
      );
      final vars = VariableScope(const [
        Variable(name: 'rows', type: VariableType.list, value: [1]),
      ], parent: scripts);
      scripts.reader = vars;
      final running = write(vars, r'${= script.next()}');
      await Future<void>.delayed(Duration.zero);
      expect(vars.read('rows'), [1]);
      result.complete([1, 2]);
      await running;
      expect(vars.read('rows'), [1, 2]);
      scripts.dispose();
      vars.dispose();
    });
    test('a slow script that fails leaves the old value in place', () async {
      final scripts = ScriptsScope(
        scripts: const [ScriptDef(id: 'bad', name: 'bad')],
        runner: FunctionScriptRunner({'bad': (_, _) async => throw StateError('failed')}),
      );
      final vars = VariableScope(const [
        Variable(name: 'rows', type: VariableType.list, value: [1]),
      ], parent: scripts);
      scripts.reader = vars;
      await write(vars, r'${= script.bad()}');
      expect(vars.read('rows'), [1]);
      scripts.dispose();
      vars.dispose();
    });
  });
}
