// The actions runtime without a render tree: actions, chains, API calls,
// delays, list text items and trigger debounce.
import 'dart:async';
import 'dart:convert';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Variable v(String name, Object? value, [VariableType type = VariableType.text]) =>
    Variable(name: name, type: type, value: type.coerce(value));

/// A node whose `click` runs [actions] (JSON).
Node clickNode(List<Json> actions, {String trigger = 'click', Map<String, Object?> extra = const {}}) => Node.fromJson({
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

void main() {
  group('trigger guards', () {
    test('a timer stops updating after its reveal limit', () async {
      final h = Harness(variables: [v('reveal', 0, VariableType.integer)]);
      final node = clickNode([setVar('reveal', '3', op: 'add')], trigger: 'timer', extra: {
        'when': r'${= reveal < 5}',
      });
      for (var i = 0; i < 10; i++) {
        await h.actions.run(node, 'timer', h.context);
      }
      expect(h['reveal'], 6);
      h.scope.set('reveal', 100000);
      await h.actions.run(node, 'timer', h.context);
      expect(h['reveal'], 100000);
    });
    test('guards can read the triggering result or a boolean variable', () async {
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
    test('blocking functions run in order and are awaited', () async {
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

    test('a failing action stops the chain without escaping', () async {
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

    test('a failing non-blocking action does not stop the chain', () async {
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

    test('disabled actions and actions whose condition fails are skipped', () async {
      final h = Harness(variables: [v('n', 0, VariableType.integer), v('on', false, VariableType.boolean)]);
      await h.click([
        {...setVar('n', '1', op: 'add'), 'enabled': false},
        {...setVar('n', '10', op: 'add'), 'when': {'left': r'${on}', 'op': 'isTrue'}},
        setVar('n', '100', op: 'add'),
      ]);
      expect(h['n'], 100);
    });

    test('all reactions to a trigger run, in order, as one chain', () async {
      final h = Harness(variables: [v('log', '')]);
      final node = Node.fromJson({
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

    test('result: the event, then what each action gives', () async {
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

    testWidgets('a cancelled chain stops: a delay ends, nothing after it runs', (tester) async {
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
    testWidgets('waits as long as its duration formula says, else its fixed time', (tester) async {
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
    test('numbers set, add and subtract; booleans toggle', () async {
      final h = Harness(variables: [v('n', 5, VariableType.integer), v('d', 1.5, VariableType.decimal), v('b', false, VariableType.boolean)]);
      await h.click([setVar('n', '2', op: 'add'), setVar('d', '0.5', op: 'subtract'), {'type': 'setVariable', 'variable': 'b', 'op': 'toggle'}]);
      expect((h['n'], h['d'], h['b']), (7, 1.0, true));
      await h.click([setVar('n', r'${= n * 10}')]);
      expect(h['n'], 70);
    });

    test('a list set from a formula keeps empty and numeric text items', () async {
      final h = Harness(variables: [v('placed', const [], VariableType.list)]);
      await h.click([setVar('placed', r"${= map(range(4), i => '')}")]);
      expect(h['placed'], ['', '', '', '']);
      await h.click([setVar('placed', r"${= setAt(placed, 1, 'E')}")]);
      expect(h['placed'], ['', 'E', '', '']);
      await h.click([setVar('placed', r"${= map(range(2), i => '' + (i + 7))}")]);
      expect(h['placed'], ['7', '8']);
      await h.click([setVar('placed', r'${= map(range(2), i => i == 0)}')]);
      expect(h['placed'], [true, false]);
      await h.click([setVar('placed', r'${= map(range(2), i => -1)}', op: 'add')]);
      expect(h['placed'], [true, false, -1, -1]);
    });

    test('list operations at an index', () async {
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

    test('map operations by key, and a path into a variable', () async {
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

    test('computed and undeclared variables are not set', () async {
      final h = Harness(variables: [v('n', 1, VariableType.integer), const Variable(name: 'twice', formula: 'n * 2')]);
      await h.click([setVar('twice', '9'), setVar('nope', '1')]);
      expect(h['twice'], 2);
      expect(h['nope'], isNull);
      expect(h.errors, isEmpty);
    });
  });

  group('flow', () {
    test('if runs the branch its condition picks; navigation inside it reaches the UI', () async {
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

    test('for each runs its actions per item with result.item and result.index', () async {
      final h = Harness(variables: [v('rows', const ['a', 'b', 'c'], VariableType.list), v('out', '')]);
      await h.click([
        {'type': 'forEach', 'items': 'rows', 'actions': [setVar('out', r'${out}${result.index}${result.item}')]},
      ]);
      expect(h['out'], '0a1b2c');
    });

    test('confirm runs its actions or its cancel actions', () async {
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

    test('modals: open gives the chain what closed it; toasts and links', () async {
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

  group('services', () {
    test('call API: success and error branches read the response as result', () async {
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

    test('storage: write, paths into stored maps, remove, clear', () async {
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

    test('cloud data: create, query into a variable, update, delete', () async {
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

    test('auth: sign up, sign in, an error into its variable', () async {
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
  });
}

class SocketLike implements Exception {
  const SocketLike();
}

/// Records what the actions ask of the UI.
class RecordingUi implements ActionUi {
  final List<String> log = [];
  bool confirmAnswer = false;
  Object? modalResult;

  @override
  Future<void> navigate(NavigateAction action, {Json params = const {}, Json baseParams = const {}}) async =>
      log.add('navigate ${action.mode.name} ${action.to} $params');

  @override
  Future<Object?> openModal(OpenModalAction action, {Json params = const {}}) async {
    log.add('modal ${action.to} ${action.presentation.name}');
    return modalResult;
  }

  @override
  bool closeModal(Object? result) {
    log.add('close $result');
    return true;
  }

  @override
  void showToast(ShowToastAction action,
          {required String message,
          String title = '',
          String actionLabel = '',
          Map<String, Object?> bound = const {},
          VoidCallback? onAction}) =>
      log.add('toast $message');

  @override
  Future<ConfirmOutcome> confirm(ConfirmAction action,
      {required String title,
      String message = '',
      String caption = '',
      String confirmLabel = 'OK',
      String cancelLabel = 'Cancel',
      Map<String, Object?> bound = const {},
      Json params = const {}}) async {
    log.add('confirm $title');
    return ConfirmOutcome(confirmAnswer);
  }

  @override
  Future<List<PickedFile>> pickFiles({bool images = true, bool multiple = true}) async => const [];
}
