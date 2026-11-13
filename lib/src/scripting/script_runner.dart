// The script engine, the default `Services.scripts`. A run is the driver's protocol over the
// platform's sandbox (QuickJS through package:codelessly_quickjs on devices,
// a Web Worker on the web): `__cl_start`, then host calls answered and
// variable writes applied through the [ScriptHost] until the run ends.
import 'dart:async';
import 'dart:convert';

import 'package:codelessly_api/core.dart' show Json, ScriptCapability, ScriptDef, ScriptParam, ScriptTest;

import '../services/scripts.dart';
import 'sandbox/script_sandbox.dart';
import 'script_reach.dart';

/// Runs [ScriptDef]s in the platform's [ScriptSandbox] ([sandbox], or
/// [ScriptSandbox.instance]). Without an engine (no `codelessly_quickjs` in
/// the app on a device) every run fails with an `EngineUnavailable` error.
class SandboxScriptRunner implements ScriptRunner {
  const SandboxScriptRunner({this.sandbox});

  /// The sandbox to run in; null: the platform's.
  final ScriptSandbox? sandbox;

  static int _runCount = 0;

  /// The longest a run may take in all, waits on the host included.
  static Duration wallTimeout = const Duration(minutes: 5);

  ScriptSandbox get _box => sandbox ?? ScriptSandbox.instance;

  /// The other scripts [script] can call, by name: a page script over a
  /// project one.
  static Map<String, ScriptDef> callable(ScriptDef script, Iterable<ScriptDef> scripts) {
    final out = <String, ScriptDef>{};
    for (final s in scripts) {
      if (s.name == script.name) continue;
      final had = out[s.name];
      if (had == null || (had.isProjectScope && !s.isProjectScope)) out[s.name] = s;
    }
    return out;
  }

  /// Builds the request the driver's `__cl_start` takes.
  static Json request(
    ScriptDef script, {
    Json args = const {},
    Iterable<ScriptDef> scripts = const [],
    ScriptHost? host,
    int? seed,
    DateTime? now,
  }) {
    final grants = script.capabilities.toSet();
    final readsVariables = grants.contains(ScriptCapability.variablesRead) || grants.contains(ScriptCapability.variablesWrite);
    // Only what the run can reach (ScriptReach): the scripts it names and,
    // across them, the variables they name.
    final others = callable(script, scripts);
    final reach = ScriptReach.of(script, others);
    Map<String, Object?> varsFor(ScriptHost host) {
      final names = reach.variables;
      if (names == null) return host.variables();
      if (host is NamedVariablesScriptHost) return host.variablesNamed(names);
      final all = host.variables();
      return {for (final n in names) if (all.containsKey(n)) n: all[n]};
    }

    return {
      'run': 'r${++_runCount}',
      'source': script.source,
      'paramNames': script.paramNames,
      'params': {
        for (final ScriptParam p in script.params) p.name: args.containsKey(p.name) ? args[p.name] : p.defaultValue,
      },
      'grants': [for (final c in script.capabilities) c.id],
      if (readsVariables && host != null) 'vars': jsonData(varsFor(host)),
      if (grants.contains(ScriptCapability.nodesRead) && host != null) 'nodes': jsonData(host.nodeValues()),
      'seed': seed ?? _seedOf(script, args),
      if (grants.contains(ScriptCapability.clock)) 'now': (now ?? DateTime.now()).millisecondsSinceEpoch,
      'scripts': {
        for (final s in others.values)
          if (reach.scripts?.contains(s.name) ?? true) s.name: {'source': s.source, 'paramNames': s.paramNames},
      },
    };
  }

  /// A seed derived from the script and its arguments, so the same call
  /// gives the same `Math.random` sequence every time.
  static int _seedOf(ScriptDef script, Json args) {
    // FNV-1a over the text, the same on every platform (String.hashCode
    // differs between the VM and the web).
    var h = 0x811c9dc5;
    for (final c in '${script.id}:${script.version}:${_stableText(args)}'.codeUnits) {
      h ^= c;
      // h * 0x01000193 mod 2^32, without products above 2^53 (the web's
      // integers are doubles).
      h = (h * 0x193 + ((h & 0xff) << 24)) & 0xffffffff;
    }
    return (h & 0x7fffffff) | 1;
  }

  static String _stableText(Object? v) {
    if (v is Map) {
      final keys = [for (final k in v.keys) '$k']..sort();
      return '{${keys.map((k) => '$k:${_stableText(v[k])}').join(',')}}';
    }
    if (v is List) return '[${v.map(_stableText).join(',')}]';
    return '$v';
  }

  /// JSON-safe data: what the host hands the script.
  static Object? jsonData(Object? v, [int depth = 0]) {
    if (depth > 64) return null;
    if (v == null || v is bool || v is String) return v;
    if (v is num) return v.isFinite ? v : null;
    if (v is List) return [for (final e in v) jsonData(e, depth + 1)];
    if (v is Map) {
      return <String, Object?>{for (final e in v.entries) '${e.key}': jsonData(e.value, depth + 1)};
    }
    if (v is DateTime) return v.toIso8601String();
    try {
      // Models with toJson, such as colors.
      return jsonData((v as dynamic).toJson(), depth + 1);
    } on Object {
      return '$v';
    }
  }

  @override
  Future<ScriptRunResult> run(
    ScriptDef script, {
    Json args = const {},
    List<ScriptDef> scripts = const [],
    ScriptHost? host,
    int? seed,
    DateTime? now,
  }) async {
    final ScriptSandbox box;
    try {
      box = _box;
    } on Object catch (e) {
      return ScriptRunResult.failure('EngineUnavailable', '$e');
    }
    // A run waiting on the app reads the variables afresh when it resumes:
    // what they are after its own writes and whatever else changed them
    // meanwhile (the run script action serializes writers; app.yield lets
    // others run during a wait).
    final grants = script.capabilities.toSet();
    final readsVars = host != null &&
        (grants.contains(ScriptCapability.variablesWrite) || grants.contains(ScriptCapability.variablesRead));
    final req = request(script, args: args, scripts: scripts, host: host, seed: seed, now: now);
    final run = req['run'] as String;
    final budget = Duration(milliseconds: script.timeoutMs);
    final logs = <Json>[];
    final writes = <Json>[];
    final wall = Stopwatch()..start();
    try {
      var state = await box.start(req, cpuBudget: budget, memoryLimit: script.memoryLimitMb << 20);
      while (true) {
        _collectLogs(state, logs);
        final responses = <Json>[];
        for (final event in state['events'] as List? ?? const []) {
          if (event is! Map) continue;
          if (event['type'] == 'write') {
            final name = '${event['name']}';
            try {
              host?.setVariable(name, event['value']);
              writes.add({'name': name, 'value': event['value']});
            } on ScriptHostError catch (e) {
              logs.add({'level': 'error', 'message': 'vars.set("$name"): ${e.message}'});
            }
          } else if (event['type'] == 'call') {
            responses.add(await _call(host, event));
          }
        }
        if (state['status'] != 'waiting') {
          final error = state['error'];
          return ScriptRunResult(
            value: state['status'] == 'done' ? state['value'] : null,
            error: state['status'] == 'done'
                ? null
                : error is Map
                    ? error.cast<String, Object?>()
                    : {'type': 'Error', 'message': 'The script failed'},
            logs: logs,
            writes: writes,
            cpuMs: (state['cpuMs'] as num?)?.toDouble() ?? 0,
            memory: (state['memory'] as num?)?.toInt(),
          );
        }
        if (responses.isEmpty) {
          // Waiting with no host call to answer: it waits on a promise that
          // nothing will settle, e.g. `await new Promise(() => {})`.
          box.end(run);
          return ScriptRunResult(
            error: {
              'type': 'Error',
              'message': 'The script is waiting on a promise that never settles. Await only app.* calls, script.* calls '
                  'and promises your own code settles.',
            },
            logs: logs,
            writes: writes,
          );
        }
        if (wall.elapsed > wallTimeout) {
          box.end(run);
          return ScriptRunResult(
            error: {
              'type': 'LimitError',
              'limit': 'time',
              'message': 'The script waited on the app for more than ${wallTimeout.inSeconds} s.',
            },
            logs: logs,
            writes: writes,
          );
        }
        state = await box.resume(run, responses, cpuBudget: budget,
            vars: readsVars ? (jsonData(host.variables()) as Map).cast<String, Object?>() : null);
      }
    } on Object catch (e) {
      box.end(run);
      return ScriptRunResult(
        error: {'type': e is ScriptEngineUnavailable ? 'EngineUnavailable' : 'Error', 'message': '$e'},
        logs: logs,
        writes: writes,
      );
    }
  }

  /// Checks [script]'s source compiles, without running it. Returns null,
  /// or the error `{type, message, line?, column?}`. Never throws.
  Future<Json?> check(ScriptDef script) async {
    try {
      return await _box.check(script.source, script.paramNames);
    } on Object catch (e) {
      return {'type': e is ScriptEngineUnavailable ? 'EngineUnavailable' : 'Error', 'message': '$e'};
    }
  }

  /// Runs [script] synchronously, for formulas. Returns null when the
  /// platform can't run scripts synchronously (the web); call [run] then. A
  /// script that waits on the host (awaits an `app.*` call) fails.
  ScriptRunResult? runSync(
    ScriptDef script, {
    Json args = const {},
    List<ScriptDef> scripts = const [],
    ScriptHost? host,
  }) {
    final ScriptSandbox box;
    try {
      box = _box;
    } on Object catch (e) {
      return ScriptRunResult.failure('EngineUnavailable', '$e');
    }
    if (!box.isSynchronous) return null;
    final req = request(script, args: args, scripts: scripts, host: host);
    try {
      final started = box.start(req, cpuBudget: Duration(milliseconds: script.timeoutMs), memoryLimit: script.memoryLimitMb << 20);
      if (started is Future) return null;
      final state = started;
      if (state['status'] == 'waiting') {
        box.end(req['run'] as String);
        return ScriptRunResult.failure(
          'TypeError',
          'A formula can\'t wait on the app: script.${script.name}() awaits an app.* call. Run it with a "Run script" '
              'action instead.',
        );
      }
      final logs = <Json>[];
      _collectLogs(state, logs);
      final error = state['error'];
      return ScriptRunResult(
        value: state['status'] == 'done' ? state['value'] : null,
        error: state['status'] == 'done' ? null : (error as Map?)?.cast<String, Object?>(),
        logs: logs,
        cpuMs: (state['cpuMs'] as num?)?.toDouble() ?? 0,
        memory: (state['memory'] as num?)?.toInt(),
      );
    } on Object catch (e) {
      return ScriptRunResult.failure(e is ScriptEngineUnavailable ? 'EngineUnavailable' : 'Error', '$e');
    }
  }

  static void _collectLogs(Json state, List<Json> logs) {
    for (final l in state['logs'] as List? ?? const []) {
      if (l is Map) logs.add(l.cast<String, Object?>());
    }
  }

  static Future<Json> _call(ScriptHost? host, Map event) async {
    final id = event['id'];
    if (host == null) {
      return {
        'id': id,
        'ok': false,
        'error': {'type': 'HostError', 'message': 'There is no app to call here.'},
      };
    }
    try {
      final value = await host.call('${event['name']}', [...?(event['args'] as List?)]);
      return {'id': id, 'ok': true, 'value': jsonData(value)};
    } on ScriptHostError catch (e) {
      return {
        'id': id,
        'ok': false,
        'error': {'type': e.type, 'message': e.message},
      };
    } on Object catch (e) {
      return {
        'id': id,
        'ok': false,
        'error': {'type': 'HostError', 'message': '$e'},
      };
    }
  }
}

/// A [ScriptHost] with sample data, for running scripts outside a screen:
/// the editor's console and tests, the MCP. Variable writes change [vars];
/// app calls are recorded in [calls] and answered by [responses] (by call
/// name), or with null.
class SampleScriptHost implements ScriptHost {
  SampleScriptHost({Json? vars, Json? nodes, this.responses = const {}})
      : vars = {...?vars},
        nodes = {...?nodes};

  /// The sample variables, by name.
  final Json vars;

  /// The sample input values, by node id.
  final Json nodes;

  /// What each kind of app call answers, by call name (`callApi`,
  /// `cloudData`, ...).
  final Json responses;

  /// The app calls the script made: `{name, args}`.
  final List<Json> calls = [];

  @override
  Map<String, Object?> variables() => Map.of(vars);

  @override
  Map<String, Object?> nodeValues() => Map.of(nodes);

  @override
  void setVariable(String name, Object? value) => vars[name] = value;

  @override
  Future<Object?> call(String name, List<Object?> args) async {
    calls.add({'name': name, 'args': args});
    return responses[name];
  }
}

/// The outcome of one [ScriptTest].
class ScriptTestResult {
  const ScriptTestResult(this.test, this.run, {required this.passed, this.reason});

  final ScriptTest test;
  final ScriptRunResult run;

  /// Whether it gave what the case expects.
  final bool passed;

  /// Why it didn't, when it didn't.
  final String? reason;

  Json toJson() => {
        'name': test.name,
        'passed': passed,
        'reason': ?reason,
        'result': run.toJson(),
      };
}

/// Runs [script]'s test cases ([cases], by default its own
/// [ScriptDef.tests]) with [runner], each with its sample variables and
/// inputs in a [SampleScriptHost]. [scripts] are the others it can call.
/// The editor's scripts panel and the MCP's `scripts.test`.
Future<List<ScriptTestResult>> runScriptTests(
  ScriptDef script, {
  List<ScriptTest>? cases,
  List<ScriptDef> scripts = const [],
  ScriptRunner runner = const SandboxScriptRunner(),
}) async {
  final results = <ScriptTestResult>[];
  for (final t in cases ?? script.tests) {
    final run = await runner.run(script, args: t.args, scripts: scripts, host: SampleScriptHost(vars: t.vars, nodes: t.nodes));
    final reason = scriptTestFailure(t, run);
    results.add(ScriptTestResult(t, run, passed: reason == null, reason: reason));
  }
  return results;
}

/// Why [run] doesn't give what [t] expects, or null when it does. Map key
/// order doesn't matter; whole doubles equal ints.
String? scriptTestFailure(ScriptTest t, ScriptRunResult run) {
  final expectError = t.expectError;
  if (expectError != null) {
    if (run.ok) return 'Expected a $expectError, but it returned ${_compared(run.value)}.';
    if (!expectedError(expectError, run.error!)) {
      return 'Expected a $expectError, but it failed with ${run.error!['type']}: ${run.error!['message']}';
    }
    return null;
  }
  if (!run.ok) {
    return 'It failed: ${run.error!['type']}: ${run.error!['message']}'
        '${run.error!['line'] != null ? ' (line ${run.error!['line']})' : ''}';
  }
  if (_compared(run.value) != _compared(t.expect)) return 'Expected ${_compared(t.expect)}, got ${_compared(run.value)}.';
  return null;
}

/// Whether a run's [error] is the one a test's `expectError` names: its
/// type (`RangeError`), its message (`Pick a template`), or both as
/// `Type: message` (`Error: Pick a template`). A validation script throws
/// plain `Error`s, so only the message tells its failures apart.
bool expectedError(String expected, Map<String, Object?> error) {
  final type = '${error['type'] ?? ''}', message = '${error['message'] ?? ''}';
  final want = expected.trim();
  return want == type || want == message || want == '$type: $message';
}

String _compared(Object? v) => jsonEncode(_sorted(v));

Object? _sorted(Object? v) {
  if (v is Map) {
    final keys = [for (final k in v.keys) '$k']..sort();
    return {for (final k in keys) k: _sorted(v[k])};
  }
  if (v is List) return [for (final e in v) _sorted(e)];
  if (v is double && v == v.truncateToDouble() && v.abs() < 1e15) return v.toInt();
  return v;
}
