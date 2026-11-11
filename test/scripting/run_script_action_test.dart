// Run script actions on the real engine (QuickJS on the VM), through the
// runtime's action chain and the app shell; script test cases; the
// catalog.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/engine_setup.dart';

Variable v(String name, Object? value, [VariableType type = VariableType.text]) =>
    Variable(name: name, type: type, value: type.coerce(value));

Node clickNode(List<Json> actions) => Node.fromJson({
      'type': 'box',
      'actions': [
        {'trigger': {'type': 'click'}, 'actions': actions},
      ],
    }, id: 'n')!;

class Harness {
  Harness({List<Variable> variables = const [], List<ScriptDef> scripts = const []})
      : scope = VariableScope(variables) {
    context = RuntimeActionContext(
      scope: scope,
      services: Services(),
      scripts: scripts,
      onError: (e, s, a) => errors.add(e is ActionFailed ? e.error : e),
    );
  }

  final VariableScope scope;
  late final RuntimeActionContext context;
  final List<Object> errors = [];

  Future<void> click(List<Json> list) => const CodelesslyActions().run(clickNode(list), 'click', context);

  Object? operator [](String name) => scope.read(name);
}

final addTip = ScriptDef.fromJson({
  'id': 'tip',
  'name': 'addTip',
  'params': [
    {'name': 'bill'},
    {'name': 'pct', 'defaultValue': 18},
  ],
  'capabilities': ['variables.read', 'variables.write'],
  'source': '''
    const total = Math.round(bill * (1 + pct / 100) * 100) / 100;
    vars.set("total", total);
    vars.set("history", [...vars.get("history"), total]);
    return {total, people: vars.get("people")};
  ''',
})!;

void main() {
  setUpAll(setUpScriptEngine);

  test('Services run scripts in the platform engine by default', () {
    expect(Services().scripts, isA<SandboxScriptRunner>());
  });

  test('overlapping sandbox actions preserve complete state-map updates', () async {
    final h = Harness(scripts: [ScriptDef.fromJson({
      'id': 'edit', 'name': 'edit',
      'capabilities': ['variables.read', 'variables.write', 'actions'],
      'source': r"""
        const game = vars.get('game');
        await app.delay(15);
        vars.set('game', {count: game.count + 1, history: [...game.history, game.count + 1]});
      """,
    })!], variables: [v('game', {'count': 0, 'history': []}, VariableType.map)]);
    await Future.wait([
      h.click([{'type': 'runScript', 'script': 'edit'}]),
      h.click([{'type': 'runScript', 'script': 'edit'}]),
    ]);
    expect(h.errors, isEmpty);
    expect(h['game'], {'count': 2, 'history': [1, 2]});
  });

  test('A run script action passes typed arguments, writes variables and leaves its result', () async {
    final h = Harness(
      scripts: [addTip],
      variables: [
        v('people', 4, VariableType.integer),
        v('total', 0, VariableType.decimal),
        v('history', <Object?>[], VariableType.list),
        v('stored', null, VariableType.map),
        v('people2', 0, VariableType.integer),
      ],
    );
    await h.click([
      {'type': 'runScript', 'script': 'tip', 'arguments': {'bill': r'${people}0'}, 'resultVariable': 'stored'},
      {'type': 'setVariable', 'variable': 'people2', 'value': r'${result.people}'},
    ]);
    expect(h.errors, isEmpty);
    // `${people}0` is the text "40", which reads as the number 40.
    expect(h['total'], 47.2);
    expect(h['history'], [47.2]);
    expect(h['stored'], {'total': 47.2, 'people': 4});
    expect(h['people2'], 4);
  });

  test('A failing script runs its onError actions with the error and logs as the result', () async {
    final h = Harness(
      scripts: [
        ScriptDef.fromJson({
          'id': 'bad',
          'name': 'bad',
          'source': 'console.log("before");\nfunction f() {\n  throw new TypeError("nope");\n}\nf();',
        })!,
      ],
      variables: [v('message', ''), v('log', ''), v('after', '')],
    );
    await h.click([
      {
        'type': 'runScript',
        'script': 'bad',
        'onError': [
          {'type': 'setVariable', 'variable': 'message', 'value': r'${result.error.type} at line ${result.error.line}: ${result.error.message}'},
          {'type': 'setVariable', 'variable': 'log', 'value': r'${result.logs[0].message}'},
        ],
      },
      {'type': 'setVariable', 'variable': 'after', 'value': 'ran'},
    ]);
    expect(h['message'], 'TypeError at line 3: nope');
    expect(h['log'], 'before');
    expect(h['after'], 'ran');
  });

  test('A failing script without onError actions stops the chain', () async {
    final h = Harness(
      scripts: [ScriptDef.fromJson({'id': 'loop', 'name': 'loop', 'source': 'while (true) {}', 'timeoutMs': 100})!],
      variables: [v('after', '')],
    );
    await h.click([
      {'type': 'runScript', 'script': 'loop'},
      {'type': 'setVariable', 'variable': 'after', 'value': 'ran'},
    ]);
    expect(h['after'], '');
    expect(h.errors.single, isA<ScriptFailed>());
    expect((h.errors.single as ScriptFailed).error['type'], 'LimitError');
    expect((h.errors.single as ScriptFailed).error['limit'], 'time');
  });

  test('A script that is missing fails cleanly', () async {
    final h = Harness();
    await h.click([
      {'type': 'runScript', 'script': 'ghost'},
    ]);
    expect(h.errors.single.toString(), contains('There is no script "ghost"'));
  });

  test('Writes to a computed or mistyped variable are logged, not applied', () async {
    final h = Harness(
      scripts: [
        ScriptDef.fromJson({
          'id': 'w',
          'name': 'w',
          'capabilities': ['variables.write'],
          'source': 'vars.set("n", "abc"); vars.set("ok", 2); return 1',
        })!,
      ],
      variables: [v('n', 1, VariableType.integer), v('ok', 0, VariableType.integer), v('logs', '')],
    );
    await h.click([
      {'type': 'runScript', 'script': 'w'},
    ]);
    expect(h.errors, isEmpty);
    expect(h['n'], 1);
    expect(h['ok'], 2);
  });

  test('Scripts call the app: actions, delays and other scripts, within their capabilities', () async {
    final h = Harness(
      scripts: [
        ScriptDef.fromJson({
          'id': 'a',
          'name': 'flow',
          'capabilities': ['actions'],
          'source': '''
            await app.runAction({type: "setVariable", variable: "flag", value: "set"});
            await app.delay(5);
            const doubled = await script.twice(21);
            let denied;
            try { await app.callApi("x"); } catch (e) { denied = e.name; }
            return {doubled, denied};
          ''',
        })!,
        ScriptDef.fromJson({
          'id': 'b',
          'name': 'twice',
          'params': [
            {'name': 'n'},
          ],
          'source': 'return n * 2',
        })!,
      ],
      variables: [v('flag', ''), v('out', null, VariableType.map)],
    );
    await h.click([
      {'type': 'runScript', 'script': 'flow', 'resultVariable': 'out'},
    ]);
    expect(h.errors, isEmpty);
    expect(h['flag'], 'set');
    final out = h['out']! as Map;
    expect(out['doubled'], 42);
    expect(out['denied'], isNotNull);
  });

  testWidgets('A tap in the app shell runs a layout script on the engine', (tester) async {
    final bundle = PublishBundle.fromJson({
      'schema': 2,
      'model': {
        'projectId': 'p',
        'entryLayoutId': 'home',
        'layouts': {
          'home': {
            'canvases': [
              {'id': 'c', 'name': 'home'},
            ],
          },
        },
      },
      'layouts': {
        'home': {
          'schema': 2,
          'id': 'home',
          'roots': ['c'],
          'nodes': {
            'c': {
              'type': 'canvas',
              'name': 'home',
              'slots': {'body': 'body'},
              'layout': {'width': 400, 'height': 600},
            },
            'body': {
              'type': 'stack',
              'children': ['b'],
              'layout': {'width': {'fill': 400}, 'height': {'fill': 600}},
            },
            'b': {
              'type': 'box',
              'layout': {'width': 200, 'height': 100},
              'decoration': {
                'fills': [
                  {'color': '#FF2196F3'},
                ],
              },
              'actions': [
                {
                  'trigger': {'type': 'click'},
                  'actions': [
                    {'type': 'runScript', 'script': 'addTip', 'arguments': {'bill': '100'}, 'resultVariable': 'stored'},
                  ],
                },
              ],
            },
          },
          'variables': {
            'c': [
              {'name': 'people', 'type': 'integer', 'value': 2},
              {'name': 'total', 'type': 'decimal', 'value': 0},
              {'name': 'history', 'type': 'list', 'value': <Object?>[]},
              {'name': 'stored', 'type': 'map'},
            ],
          },
          'scripts': [addTip.toJson()],
        },
      },
    });
    final codelessly = Codelessly(
      config: const CodelesslyConfig(projectId: 'p'),
      loader: MemoryPublishLoader(bundle),
      fonts: const NoFontFetcher(),
    );
    final controller = CodelesslyWidgetController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(home: CodelesslyWidget(codelessly: codelessly, controller: controller)));
    await tester.pumpAndSettle();
    final box = controller.tree!.boxOf('b')!;
    await tester.tapAt(box.localToGlobal(box.size.center(Offset.zero)));
    await tester.pumpAndSettle();
    expect(controller.read('total'), 118.0);
    expect(controller.read('history'), [118.0]);
    expect(controller.read('stored'), {'total': 118.0, 'people': 2});
  });

  test('A script runs its stored test cases with sample variables', () async {
    const model = ScriptDef(
      id: 'v',
      name: 'validate',
      params: [ScriptParam(name: 'form')],
      capabilities: [ScriptCapability.variablesRead],
      source: """
        const errors = {};
        if (!/^[^@\\s]+@[^@\\s]+\\.[^@\\s]+\$/.test(form.email)) errors.email = 'Invalid email';
        if (form.age < vars.get('minAge')) errors.age = 'Too young';
        if (form.age > 150) throw new RangeError('age');
        return {valid: Object.keys(errors).length === 0, errors};
      """,
      tests: [
        ScriptTest(
          name: 'ok',
          args: {
            'form': {'email': 'a@b.co', 'age': 30},
          },
          vars: {'minAge': 13},
          expect: {'errors': <String, Object?>{}, 'valid': true},
        ),
        ScriptTest(
          name: 'bad',
          args: {
            'form': {'email': 'nope', 'age': 9},
          },
          vars: {'minAge': 13},
          expect: {
            'valid': false,
            'errors': {'email': 'Invalid email', 'age': 'Too young'},
          },
        ),
        ScriptTest(
          name: 'throws',
          args: {
            'form': {'email': 'a@b.co', 'age': 200},
          },
          vars: {'minAge': 13},
          expectError: 'RangeError',
        ),
        ScriptTest(
          name: 'wrong on purpose',
          args: {
            'form': {'email': 'a@b.co', 'age': 30},
          },
          vars: {'minAge': 13},
          expect: {'valid': false},
        ),
      ],
    );
    final results = await runScriptTests(model);
    expect([for (final r in results) r.passed], [true, true, true, false]);
    expect(results.last.reason, contains('Expected'));
    expect(results.first.toJson()['result'], containsPair('ok', true));
    expect(ScriptDef.fromJson(model.toJson())!.tests, model.tests);
  });

  test('Check compiles a script without running it', () async {
    const runner = SandboxScriptRunner();
    expect(await runner.check(const ScriptDef(id: 'a', name: 'a', source: 'while (true) {}')), isNull);
    final error = await runner.check(const ScriptDef(id: 'a', name: 'a', source: 'let a = 1;\nlet b = ;'));
    expect(error?['type'], 'SyntaxError');
    expect(error?['line'], 2);
  });

  test('The catalog describes every host API with its capability', () {
    final json = ScriptCatalog.toJson();
    final api = json['api']! as List;
    expect(
      api.map((e) => (e as Map)['signature']),
      containsAll(['vars.get(name)', 'app.callApi(name, inputs?)', 'fmt.currency(n, code?, digits?)']),
    );
    for (final c in ScriptCapability.values) {
      expect((json['capabilities']! as Map).containsKey(c.id), isTrue, reason: c.id);
    }
    expect(ScriptCatalog.entries.firstWhere((e) => e.signature == 'vars.set(name, value)').parameters, ['name', 'value']);
  });

  test('Without the native library a run fails with EngineUnavailable', () async {
    final r = await SandboxScriptRunner(sandbox: _Unavailable()).run(addTip, args: {'bill': 1});
    expect(r.error?['type'], 'EngineUnavailable');
  });
}

class _Unavailable implements ScriptSandbox {
  @override
  bool get isSynchronous => true;

  @override
  Map<String, Object?> start(Map<String, Object?> request, {required Duration cpuBudget, required int memoryLimit}) =>
      throw const ScriptEngineUnavailable('none');

  @override
  Map<String, Object?> resume(String run, List<Map<String, Object?>> responses, {required Duration cpuBudget}) =>
      throw const ScriptEngineUnavailable('none');

  @override
  Map<String, Object?>? check(String source, List<String> paramNames) => throw const ScriptEngineUnavailable('none');

  @override
  void end(String run) {}
}
