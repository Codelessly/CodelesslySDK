// The script runtime's conformance suite. It runs on the Dart VM, where
// scripts run in QuickJS (`flutter test`), and in Chrome, where they run in
// a Web Worker (`flutter test --platform chrome`), with the same
// expectations, so it is also the parity test between the two engines.
import 'dart:convert';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/engine_setup.dart';
import 'support/fake_host.dart';

int _ids = 0;

ScriptModel script(
  String source, {
  List<String> params = const [],
  List<ScriptCapability> caps = const [],
  int timeoutMs = 1000,
  String? name,
  Map<String, Object?> defaults = const {},
}) => ScriptModel(
  id: 's${++_ids}',
  name: name ?? 'test${_ids}',
  source: source,
  params: [
    for (final p in params) ScriptParam(name: p, defaultValue: defaults[p]),
  ],
  capabilities: caps,
  timeoutMs: timeoutMs,
);

Future<ScriptRunResult> run(
  String source, {
  List<String> params = const [],
  Map<String, Object?> args = const {},
  List<ScriptCapability> caps = const [],
  ScriptHost? host,
  int timeoutMs = 1000,
  Map<String, ScriptModel> scripts = const {},
  Map<String, Object?> defaults = const {},
  DateTime? now,
}) => ScriptRunner.run(
  script(
    source,
    params: params,
    caps: caps,
    timeoutMs: timeoutMs,
    defaults: defaults,
  ),
  args: args,
  host: host,
  scripts: scripts,
  now: now,
);

Matcher hasError(String type, [Object? message]) => isA<ScriptRunResult>()
    .having((r) => r.ok, 'ok', false)
    .having((r) => r.error?['type'], 'error.type', type)
    .having((r) => r.error?['message'], 'error.message', message ?? anything);

Matcher hasValue(Object? value) => isA<ScriptRunResult>()
    .having((r) => r.error, 'error', isNull)
    .having((r) => r.value, 'value', value);

void main() {
  setUpAll(setUpScriptEngine);

  group('values and params ($scriptEngineName)', () {
    test('returns from the top level', () async {
      expect(
        await run(
          'return a * b + 1',
          params: ['a', 'b'],
          args: {'a': 6, 'b': 7},
        ),
        hasValue(43),
      );
    });

    test(
      'calls main with the params when the top level returns nothing',
      () async {
        expect(
          await run(
            'function main(x, y) { return [x, y, x + y] }',
            params: ['x', 'y'],
            args: {'x': 2, 'y': 3},
          ),
          hasValue([2, 3, 5]),
        );
      },
    );

    test('uses defaults and the params object', () async {
      expect(
        await run(
          'return [rate, params.rate, years]',
          params: ['rate', 'years'],
          args: {'years': 30},
          defaults: {'rate': 6.5},
        ),
        hasValue([6.5, 6.5, 30]),
      );
    });

    test(
      'returns JSON data: objects, lists, nulls; undefined is null',
      () async {
        expect(
          await run(
            'return {a: [1, "two", null, true], b: {c: 1.5}, d: undefined}',
          ),
          hasValue({
            'a': [1, 'two', null, true],
            'b': {'c': 1.5},
          }),
        );
        expect(await run('let x = 1'), hasValue(null));
      },
    );

    test('a result that is not JSON data is an error', () async {
      expect(
        await run('const a = {}; a.self = a; return a'),
        hasError('TypeError'),
      );
    });

    test('async code and awaits inside the script', () async {
      expect(
        await run(
          'const f = async (x) => x * 2; const xs = await Promise.all([f(1), f(2)]); return xs',
        ),
        hasValue([2, 4]),
      );
    });
  });

  group('host bindings', () {
    test('vars.get, has and all read the variables', () async {
      final host = FakeHost(
        vars: {
          'count': 41,
          'name': 'Ada',
          'tags': ['a'],
        },
      );
      expect(
        await run(
          'return [vars.get("count"), vars.has("name"), vars.has("nope"), vars.all().tags]',
          caps: [ScriptCapability.variablesRead],
          host: host,
        ),
        hasValue([
          41,
          true,
          false,
          ['a'],
        ]),
      );
    });

    test(
      'vars.set changes variables, in order, and later reads see it',
      () async {
        final host = FakeHost(vars: {'count': 1, 'log': []});
        final r = await run(
          'vars.set("count", vars.get("count") + 1); vars.set("log", ["x"]); vars.set("count", 10); return vars.get("count")',
          caps: [
            ScriptCapability.variablesRead,
            ScriptCapability.variablesWrite,
          ],
          host: host,
        );
        expect(r, hasValue(10));
        expect(host.vars, {
          'count': 10,
          'log': ['x'],
        });
        expect(r.writes.map((w) => w['name']), ['count', 'log', 'count']);
      },
    );

    test('vars.set of an unknown variable throws in the script', () async {
      expect(
        await run(
          'try { vars.set("nope", 1) } catch (e) { return e.name + ": " + e.message }',
          caps: [ScriptCapability.variablesWrite],
          host: FakeHost(),
        ),
        hasValue('ReferenceError: There is no variable named "nope".'),
      );
    });

    test('a write the host refuses is logged, not fatal', () async {
      final host = FakeHost(vars: {'total': 1}, computed: {'total'});
      final r = await run(
        'vars.set("total", 2); return "done"',
        caps: [ScriptCapability.variablesWrite],
        host: host,
      );
      expect(r, hasValue('done'));
      expect(r.logs.single['message'], contains('computed'));
      expect(host.vars['total'], 1);
    });

    test(
      'vars.set copies the value: later changes in the script do not leak',
      () async {
        final host = FakeHost(vars: {'list': []});
        await run(
          'const a = [1]; vars.set("list", a); a.push(2); return 0',
          caps: [ScriptCapability.variablesWrite],
          host: host,
        );
        expect(host.vars['list'], [1]);
      },
    );

    test('nodes.value reads inputs', () async {
      final host = FakeHost(nodes: {'email': 'a@b.co', 'agree': true});
      expect(
        await run(
          'return [nodes.value("email"), nodes.value("agree"), nodes.value("missing")]',
          caps: [ScriptCapability.nodesRead],
          host: host,
        ),
        hasValue(['a@b.co', true, null]),
      );
    });

    test('app calls are awaited host functions', () async {
      final host = FakeHost();
      final r = await run(
        '''
        const w = await app.callApi("weather", {city: "SF"});
        await app.navigate("Details", {id: 7});
        const ran = await app.runAction({type: "showToast", message: "hi"});
        await app.toast("saved");
        await app.delay(5);
        const docs = await app.cloudData({operation: "query", collection: "todos"});
        await app.back({ok: true});
        return [w.body.temp, ran.ran, docs.docs.length];
        ''',
        caps: [
          ScriptCapability.api,
          ScriptCapability.navigation,
          ScriptCapability.actions,
          ScriptCapability.cloud,
        ],
        host: host,
      );
      expect(r, hasValue([21, 'showToast', 2]));
      expect(host.calls, [
        'callApi(weather, {city: SF})',
        'navigate(Details, {id: 7})',
        'runAction({type: showToast, message: hi})',
        'toast(saved)',
        'delay(5)',
        'cloudData({operation: query, collection: todos})',
        'back({ok: true})',
      ]);
    });

    test('a failed host call rejects in the script', () async {
      expect(
        await run(
          'try { await app.callApi("broken") } catch (e) { return [e.name, e.message] }',
          caps: [ScriptCapability.api],
          host: FakeHost(),
        ),
        hasValue(['HostError', 'Network down']),
      );
    });

    test('console logs come back with the result', () async {
      final r = await run(
        'console.log("a", 1, {b: 2}); console.warn("w"); console.error(new Error("e")); return 0',
      );
      expect(r.logs, [
        {'level': 'log', 'message': 'a 1 {"b":2}'},
        {'level': 'warn', 'message': 'w'},
        {'level': 'error', 'message': 'Error: e'},
      ]);
    });

    test('scripts call other scripts with script.name()', () async {
      final helper = script(
        'return Math.round(x * 100) / 100',
        params: ['x'],
        name: 'cents',
      );
      expect(
        await run(
          'return [await script.cents(1.005 * 3), "cents" in script, "nope" in script]',
          scripts: {'cents': helper},
        ),
        hasValue([3.01, true, false]),
      );
    });

    test('fmt formats the same on every engine', () async {
      expect(
        await run('''return [
          fmt.number(1234567.891), fmt.number(3.14159, 2), fmt.currency(1234.5), fmt.currency(1500, "JPY"),
          fmt.currency(-9.99, "EUR"), fmt.percent(0.256), fmt.percent(0.256, 1), fmt.round(2.675, 2),
          fmt.date("2026-03-09T15:04:05Z", "EEE, MMM d, yyyy h:mm a"), fmt.date("2026-12-25"), fmt.duration(3725),
          (1234.5).toLocaleString(), (0.5).toLocaleString("en-US", {style: "percent"}),
          ["b", "a", "C"].sort((x, y) => x.localeCompare(y)),
        ]'''),
        hasValue([
          '1,234,567.891',
          '3.14',
          r'$1,234.50',
          '¥1,500',
          '-€9.99',
          '26%',
          '25.6%',
          2.68,
          'Mon, Mar 9, 2026 3:04 PM',
          '2026-12-25',
          '1:02:05',
          '1,234.5',
          '50%',
          ['a', 'b', 'C'],
        ]),
      );
    });
  });

  group('capabilities', () {
    final Map<String, String> needs = {
      'vars.get("x")': 'variables.read',
      'vars.set("x", 1)': 'variables.write',
      'nodes.value("x")': 'nodes.read',
      'app.navigate("x")': 'navigation',
      'app.back()': 'navigation',
      'app.callApi("x")': 'api',
      'app.cloudData({})': 'cloud',
      'app.runAction({})': 'actions',
      'app.toast("x")': 'actions',
      'app.delay(1)': 'actions',
      'Date.now()': 'clock',
      'new Date()': 'clock',
    };
    for (final MapEntry<String, String> e in needs.entries) {
      test('${e.key} needs ${e.value}', () async {
        final r = await run('return ${e.key}', host: FakeHost(vars: {'x': 1}));
        expect(r, hasError('CapabilityError', contains('"${e.value}"')));
      });
    }

    test('the clock reads the time when granted; dates are UTC', () async {
      final r = await run(
        'const d = new Date(); return [Date.now(), d.getHours(), d.toISOString(), new Date("2026-01-05").getHours(), new Date(2026, 0, 5).getDate()]',
        caps: [ScriptCapability.clock],
        now: DateTime.utc(2026, 7, 4, 13, 30),
      );
      expect(r.value, [
        isA<int>().having(
          (ms) => ms,
          'ms',
          closeTo(
            DateTime.utc(2026, 7, 4, 13, 30).millisecondsSinceEpoch,
            2000,
          ),
        ),
        13,
        startsWith('2026-07-04T13:30'),
        0,
        5,
      ]);
    });
  });

  group('sandbox', () {
    test(
      'no network, timers, storage, workers or other ambient globals',
      () async {
        const names = [
          'fetch',
          'XMLHttpRequest',
          'WebSocket',
          'EventSource',
          'importScripts',
          'setTimeout', //
          'setInterval',
          'queueMicrotask',
          'indexedDB',
          'caches',
          'localStorage',
          'postMessage',
          'self',
          'window',
          'document',
          'navigator',
          'location',
          'Worker',
          'SharedWorker',
          'WebAssembly',
          'Intl',
          'SharedArrayBuffer',
          'Atomics',
          'crypto',
          'performance',
          'require',
          'process',
          'Deno',
          'std',
          'os',
          'print',
          'eval',
          'Request',
          'Response',
          'FontFace',
          'OffscreenCanvas',
          'BroadcastChannel',
          'WeakRef',
          'FinalizationRegistry',
        ];
        final r = await run(
          'return [${names.map((n) => 'typeof $n').join(', ')}]',
        );
        expect(
          r.value,
          List.filled(names.length, 'undefined'),
          reason: jsonEncode(r.toJson()),
        );
        final r2 = await run(
          'return [${names.map((n) => '"$n" in globalThis').join(', ')}]',
        );
        expect(r2.value, isNot(contains(true)), reason: jsonEncode(r2.value));
      },
    );

    test('code generation at run time is blocked', () async {
      for (final String code in [
        'return Function("return 1")()',
        'return (function(){}).constructor("return typeof fetch")()',
        'return (async function(){}).constructor("return 1")()',
        'return (function*(){}).constructor("yield 1")().next()',
        'return [].map.constructor("return this")()',
      ]) {
        expect(await run(code), hasError('EvalError'), reason: code);
      }
    });

    test('import() and import.meta are rejected before running', () async {
      for (final String code in [
        'return import("https://example.com/x.js")',
        'const m = await import ("data:text/javascript,1"); return 1',
        'return import.meta',
      ]) {
        expect(
          await run(code),
          hasError('SyntaxError', contains('import')),
          reason: code,
        );
      }
      // ...but not the word in text or comments.
      expect(
        await run('// import("x")\nreturn "import(y)"'),
        hasValue('import(y)'),
      );
    });

    test('built-ins are frozen, so runs cannot affect each other', () async {
      for (final String code in [
        'Array.prototype.evil = 1',
        'Object.prototype.polluted = 1',
        'Math.random = () => 4',
        'JSON.parse = null',
        'globalThis.leak = 1',
        'String.prototype.trim = null',
      ]) {
        expect(
          await run('"use strict"; $code; return 1'),
          hasError('TypeError'),
          reason: code,
        );
      }
      expect(
        await run(
          'return [typeof [].evil, typeof ({}).polluted, typeof globalThis.leak, JSON.parse("1")]',
        ),
        hasValue(['undefined', 'undefined', 'undefined', 1]),
      );
    });

    test('a run cannot reach another run\'s data', () async {
      final host = FakeHost(vars: {'secret': 'hunter2'});
      await run(
        'return vars.get("secret")',
        caps: [ScriptCapability.variablesRead],
        host: host,
      );
      expect(
        await run(
          'return [typeof vars.get, (() => { try { return vars.get("secret") } catch (e) { return e.name } })()]',
        ),
        hasValue(['function', 'CapabilityError']),
      );
    });

    test('custom errors and overriding inherited methods still work', () async {
      expect(
        await run('''
          class ValidationError extends Error { constructor(m) { super(m); this.name = "ValidationError"; } }
          const o = {}; o.toString = () => "custom";
          try { throw new ValidationError("bad"); } catch (e) { return [e.name, String(e), String(o), e instanceof Error]; }
        '''),
        hasValue(['ValidationError', 'ValidationError: bad', 'custom', true]),
      );
    });
  });

  group('limits', () {
    test('an endless loop stops with a LimitError', () async {
      final r = await run('while (true) {}', timeoutMs: 200);
      expect(r, hasError('LimitError'));
      expect(r.error!['limit'], 'time');
    });

    test('an endless chain of promise jobs stops too', () async {
      expect(
        await run('while (true) { await null; }', timeoutMs: 200),
        hasError('LimitError'),
      );
    });

    test('a loop that catches errors cannot swallow the limit', () async {
      expect(
        await run(
          'while (true) { try { while (true) {} } catch (e) {} }',
          timeoutMs: 200,
        ),
        hasError('LimitError'),
      );
    });

    test('the engine still works after a script hit a limit', () async {
      await run('while (true) {}', timeoutMs: 100);
      expect(await run('return 1 + 1'), hasValue(2));
    });

    test('endless recursion stops with a LimitError', () async {
      final r = await run('function f(n) { return f(n + 1) + 1 } return f(0)');
      expect(r, hasError('LimitError'));
      expect(r.error!['limit'], 'depth');
    });

    test('time waiting on the app does not count', () async {
      expect(
        await run(
          'await app.delay(300); return "ok"',
          caps: [ScriptCapability.actions],
          host: FakeHost(),
          timeoutMs: 100,
        ),
        hasValue('ok'),
      );
    });

    test('logs are capped', () async {
      final r = await run(
        'for (let i = 0; i < 2000; i++) console.log(i); return 1',
      );
      expect(r.logs.length, 500);
    });
  });

  group('errors', () {
    test('syntax errors have a line and column', () async {
      final r = await run('let a = 1;\nlet b = ;\n');
      expect(r, hasError('SyntaxError'));
      expect(r.error!['line'], 2);
      expect(r.error!['column'], isA<int>());
    });

    test(
      'runtime errors have a line, column and the functions they passed',
      () async {
        final r = await run(
          'function outer() {\n  return inner();\n}\nfunction inner() {\n  return null.x;\n}\nreturn outer();',
        );
        expect(r, hasError('TypeError'));
        expect(r.error!['line'], 5);
        expect(r.error!['stack'], ['inner', 'outer']);
      },
    );

    test('a thrown Error keeps its type and message', () async {
      final r = await run('\n\nthrow new RangeError("too big")');
      expect(r, hasError('RangeError', 'too big'));
      expect(r.error!['line'], 3);
    });

    test('a thrown value that is not an Error', () async {
      expect(await run('throw {code: 42}'), hasError('Error', '{"code":42}'));
    });

    test('check compiles without running', () async {
      expect(await ScriptRunner.check(script('while (true) {}')), isNull);
      final Map<String, Object?>? error = await ScriptRunner.check(
        script('let a = 1;\nlet b = ;'),
      );
      expect(error?['type'], 'SyntaxError');
      expect(error?['line'], 2);
      expect(
        (await ScriptRunner.check(script('return import("x")')))?['type'],
        'SyntaxError',
      );
      expect(
        await ScriptRunner.check(script('return a + 1', params: ['a'])),
        isNull,
      );
    });

    test('a script may declare names the host uses', () async {
      expect(
        await run(
          'let nodes = 3; const app = 4; function fmt() { return 5 } return nodes + app + fmt()',
        ),
        hasValue(12),
      );
    });

    test('reserved parameter names are rejected', () async {
      expect(await run('return 1', params: ['vars']), hasError('SyntaxError'));
    });
  });

  group('determinism', () {
    test('Math.random is seeded by the script and its arguments', () async {
      final a = await run(
        'return [Math.random(), Math.random()]',
        params: ['x'],
        args: {'x': 1},
      );
      final b = await run(
        'return [Math.random(), Math.random()]',
        params: ['x'],
        args: {'x': 1},
      );
      final ScriptModel s = script('return Math.random()', params: ['x']);
      final c1 = await ScriptRunner.run(s, args: {'x': 1});
      final c2 = await ScriptRunner.run(s, args: {'x': 1});
      final c3 = await ScriptRunner.run(s, args: {'x': 2});
      expect(c1.value, c2.value);
      expect(c1.value, isNot(c3.value));
      expect(a.value, isA<List>());
      expect(b.value, isA<List>());
    });

    test('the same results on every engine', () async {
      final r = await run(determinismCorpus);
      expect(r.error, isNull);
      expect(r.value, determinismGolden);
    });
  });
}

/// Cases where engines are known to differ (number formatting, Math,
/// dates, sorting, Unicode, JSON), run on both engines.
const String determinismCorpus = r'''
const cases = [
  0.1 + 0.2, 1 / 3, 1e21, 1e-7, 123456789.123456789, 2 ** 53 + 1, -0, 5 % -3, -5 % 3,
  Math.pow(1.1, 100), Math.pow(1.0054166666666667, -360), Math.sqrt(2), Math.round(-2.5), Math.round(2.5),
  Math.sin(1), Math.cos(0.5), Math.exp(1), Math.log(10), Math.atan2(1, 3),
  (1.005).toFixed(2), (1234.5678).toFixed(1), (0.000001234).toPrecision(2), (255).toString(16), (1e21).toFixed(2),
  String(-1e-7), String(2 ** 64), 9007199254740993, parseInt('08'), parseFloat('3.14abc'), Number(' 12 '),
  JSON.stringify({a: 1.0, b: [0.1, 1e21, -0], c: 'é "\n'}),
  [3, 1, 2, 10, 20].sort(), [{k: 1, v: 'a'}, {k: 0, v: 'b'}, {k: 1, v: 'c'}].sort((a, b) => a.k - b.k).map(x => x.v).join(''),
  'ß'.toUpperCase(), 'İ'.toLowerCase().length, [...'😀a'].length, ~5, -7 >>> 28,
  new Date(Date.UTC(2026, 0, 31)).toISOString(), new Date('2026-03-01T10:00:00').getTime(), new Date(2026, 1, 30).toISOString(),
  new Date(0).toString(), (12345.678).toLocaleString(), (1234.5).toLocaleString('en-US', {style: 'currency', currency: 'USD'}),
  'Banana' < 'apple', ['é', 'e', 'z', 'E'].sort((a, b) => a.localeCompare(b)).join(''),
];
return cases.map((v) => typeof v === 'number' ? String(v) : JSON.stringify(v));
''';

/// The corpus's results, the same on QuickJS and in the browser.
const List<String> determinismGolden = [
  "0.30000000000000004",
  "0.3333333333333333",
  "1e+21",
  "1e-7",
  "123456789.12345679",
  "9007199254740992",
  "0",
  "2",
  "-2",
  "13780.612339822364",
  "0.1430247275075218",
  "1.4142135623730951",
  "-2",
  "3",
  "0.8414709848078965",
  "0.8775825618903728",
  "2.718281828459045",
  "2.302585092994046",
  "0.3217505543966422",
  "\"1.00\"",
  "\"1234.6\"",
  "\"0.0000012\"",
  "\"ff\"",
  "\"1e+21\"",
  "\"-1e-7\"",
  "\"18446744073709552000\"",
  "9007199254740992",
  "8",
  "3.14",
  "12",
  "\"{\\\"a\\\":1,\\\"b\\\":[0.1,1e+21,0],\\\"c\\\":\\\"é \\\\\\\"\\\\n\\\"}\"",
  "[1,10,2,20,3]",
  "\"bac\"",
  "\"SS\"",
  "2",
  "2",
  "-6",
  "15",
  "\"2026-01-31T00:00:00.000Z\"",
  "1772359200000",
  "\"2026-03-02T00:00:00.000Z\"",
  "\"Thu Jan 01 1970 00:00:00 GMT+0000\"",
  "\"12,345.678\"",
  "\"\$1,234.50\"",
  "true",
  "\"Eezé\"",
];
