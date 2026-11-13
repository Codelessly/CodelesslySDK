// A core-only runtime: CoreActions with no feature installed runs the core
// actions (variables, flow, delay, navigation, functions) and fails a
// feature's action with a clear error. This file imports the core runtime
// only: nothing under lib/src/features.
import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/src/runtime/actions/context.dart';
import 'package:codelessly_sdk/src/runtime/actions/feature.dart';
import 'package:codelessly_sdk/src/runtime/actions/runner.dart';
import 'package:codelessly_sdk/src/runtime/actions/ui.dart';
import 'package:codelessly_sdk/src/runtime/contracts.dart';
import 'package:codelessly_sdk/src/runtime/expressions/scopes.dart';
import 'package:flutter_test/flutter_test.dart';

/// A node with [actions] on click, decoded as a published layout is (with
/// the standard catalog: the full editor's types, typed).
Node clickNode(List<Json> actions, {Catalog catalog = standardCatalog}) => Node.fromJson({
      'type': 'box',
      'actions': [
        {'trigger': {'type': 'click'}, 'actions': actions},
      ],
    }, id: 'n', catalog: catalog)!;

Json setVar(String name, String value, {String op = 'set'}) =>
    {'type': 'setVariable', 'variable': name, 'value': value, 'op': op};

class _Ui extends NoActionUi {
  final List<String> navigated = [];
  @override
  Future<void> navigate(NavigateAction action, {Json params = const {}, Json baseParams = const {}}) async =>
      navigated.add(action.to);
}

class _Greeter {
  String greet(String name) => 'hello $name';
}

/// Services of an app's own: a locator with one service.
class _Services implements CodelesslyServices, ServiceLocator {
  final greeter = _Greeter();
  @override
  Future<Object?> callApi(String apiId, {Json params = const {}}) async => null;
  @override
  Future<bool> openUrl(String url) async => false;
  @override
  T? service<T extends Object>() => greeter is T ? greeter as T : null;
}

void main() {
  late VariableScope scope;
  late List<Object> errors;
  late _Ui ui;
  late CoreActionContext context;

  setUp(() {
    scope = VariableScope([
      const Variable(name: 'n', type: VariableType.integer, value: 0),
      const Variable(name: 'said', type: VariableType.text, value: ''),
      const Variable(name: 'list', type: VariableType.list, value: [1, 2, 3]),
    ]);
    errors = [];
    ui = _Ui();
    context = CoreActionContext(
      scope: scope,
      ui: ui,
      services: _Services(),
      functions: {'double': (context, params) => (params['x'] as num) * 2},
      onError: (e, s, a) => errors.add(e),
    );
  });

  Future<void> click(List<Json> actions, {CoreActions runner = const CoreActions()}) =>
      runner.run(clickNode(actions), 'click', context);

  test('core actions run with no feature installed', () async {
    await click([
      setVar('n', '1', op: 'add'),
      {
        'type': 'if',
        'condition': {'left': r'${n}', 'op': 'equalsTo', 'right': '1'},
        'then': [setVar('n', '10', op: 'add')],
        'else': [setVar('n', '100', op: 'add')],
      },
      {'type': 'delay', 'ms': 1},
      {
        'type': 'forEach',
        'items': 'list',
        'actions': [setVar('n', r'${loop.item}', op: 'add')],
      },
      {'type': 'callFunction', 'name': 'double', 'params': {'x': 4}},
      setVar('said', r'${result}'),
      {'type': 'callFunction', 'name': 'media.probe', 'optional': true},
      {'type': 'navigate', 'to': 'details'},
    ]);
    expect(errors, isEmpty);
    expect(scope.read('n'), 17);
    expect(scope.read('said'), '8');
    expect(ui.navigated, ['details']);
  });

  for (final type in ['auth', 'cloudData', 'paywall', 'speak', 'callApi', 'setStorage']) {
    test('a $type action fails clearly: its feature is not installed', () async {
      await click([
        setVar('n', '1', op: 'add'),
        {'type': type},
        setVar('n', '1', op: 'add'),
      ]);
      expect(scope.read('n'), 1, reason: 'the chain stops at the action');
      final failure = errors.single as ActionFailed;
      expect(failure.action, type);
      expect('${failure.error}', contains("No handler for action '$type'"));
      expect('${failure.error}', contains("isn't installed"));
    });
  }

  test('decoded with the core catalog, a feature action is a type nobody declared: skipped', () async {
    await const CoreActions().run(
        clickNode([setVar('n', '1', op: 'add'), {'type': 'callApi'}, setVar('n', '1', op: 'add')], catalog: Catalog.core),
        'click',
        context);
    expect(scope.read('n'), 2);
    expect(errors, isEmpty);
    expect(const CoreActions().catalog, same(Catalog.core));
  });

  test('a feature function that is not installed is a missing function', () async {
    await click([
      {'type': 'callFunction', 'name': 'media.probe'},
    ]);
    expect('${(errors.single as ActionFailed).error}', contains('No function named [media.probe]'));
  });

  test("an app's own feature gives handlers, functions and its service by type", () async {
    final feature = CodelesslyFeature(
      name: 'greeting',
      actions: {
        // A type the API declares (replacing nothing here) and one it doesn't.
        'speak': (action, run) => run.result = run.require<_Greeter>('Greeting').greet('speaker'),
        'acme.greet': (action, run) =>
            run.result = run.require<_Greeter>('Greeting').greet('${(action as UnknownAction).json['name']}'),
      },
      functions: {'acme.shout': (action, run) => '${run.json(action.params)['text']}!'},
    );
    final runner = CoreActions(features: [feature]);
    await click([{'type': 'acme.greet', 'name': 'Ada'}, setVar('said', r'${result}')], runner: runner);
    expect(scope.read('said'), 'hello Ada');
    await click([{'type': 'speak'}, setVar('said', r'${result}')], runner: runner);
    expect(scope.read('said'), 'hello speaker');
    await click([
      {'type': 'callFunction', 'name': 'acme.shout', 'params': {'text': 'hey'}},
      setVar('said', r'${result}'),
    ], runner: runner);
    expect(scope.read('said'), 'hey!');
    expect(errors, isEmpty);
    // Without the feature, its undeclared type is skipped, as any unknown one.
    await click([{'type': 'acme.greet', 'name': 'Bo'}, setVar('said', 'after')]);
    expect(scope.read('said'), 'after');
    expect(errors, isEmpty);
  });

  test('a handler of the app replaces a feature\'s for the same type', () async {
    final feature = CodelesslyFeature(name: 'a', actions: {'speak': (a, run) => run.result = 'feature'});
    final runner = CoreActions(features: [feature], handlers: {'speak': (a, run) => run.result = 'app'});
    await click([{'type': 'speak'}, setVar('said', r'${result}')], runner: runner);
    expect(scope.read('said'), 'app');
  });
}
