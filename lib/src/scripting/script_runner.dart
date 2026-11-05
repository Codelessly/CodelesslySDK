import 'dart:async';

import 'package:codelessly_api/codelessly_api.dart';

import 'sandbox/script_sandbox.dart';

/// What a script can reach in the app: implemented by the SDK for a running
/// layout (see `FlutterScriptHost`), and by tests and the Editor's console
/// with sample data.
abstract class ScriptHost {
  /// The variables the script can read and write, by name.
  Map<String, Object?> variables();

  /// The values of inputs on screen, by node id (and name, when unique).
  Map<String, Object?> nodeValues();

  /// Sets the variable [name] to [value]. Throws a [ScriptHostError] when
  /// it can't, e.g. a computed variable.
  void setVariable(String name, Object? value);

  /// Performs the host call [name] (`navigate`, `back`, `callApi`,
  /// `cloudData`, `runAction`, `toast` or `delay`) with [args] and returns
  /// its result as JSON data.
  Future<Object?> call(String name, List<Object?> args);
}

/// A host call failed, as data for the script's `catch`.
class ScriptHostError implements Exception {
  /// The error's name in the script, e.g. `HostError`.
  final String type;

  /// What went wrong.
  final String message;

  /// Creates a [ScriptHostError].
  const ScriptHostError(this.message, [this.type = 'HostError']);

  @override
  String toString() => '$type: $message';
}

/// A "Run script" action's script failed and it had no onError actions.
class ScriptFailedException implements Exception {
  /// What failed, e.g. `Script total failed: TypeError: ... (line 3)`.
  final String message;

  /// The script's error: `{type, message, line?, column?, stack?}`.
  final Map<String, Object?> error;

  /// Creates a [ScriptFailedException].
  const ScriptFailedException(this.message, this.error);

  @override
  String toString() => message;
}

/// The outcome of a script run. A failed run is a result with an [error],
/// never an exception.
class ScriptRunResult {
  /// What the script returned, as JSON data.
  final Object? value;

  /// Why the script failed: `{type, message, line?, column?, stack?,
  /// limit?}`, or null when it succeeded.
  final Map<String, Object?>? error;

  /// What it logged: `{level, message}` maps.
  final List<Map<String, Object?>> logs;

  /// The variable writes it made, in order: `{name, value}` maps.
  final List<Map<String, Object?>> writes;

  /// CPU time the script used, in milliseconds.
  final double cpuMs;

  /// Memory the engine used at the end, in bytes, when known.
  final int? memory;

  /// Creates a [ScriptRunResult].
  const ScriptRunResult({
    this.value,
    this.error,
    this.logs = const [],
    this.writes = const [],
    this.cpuMs = 0,
    this.memory,
  });

  /// A failed result of [type] with [message].
  ScriptRunResult.failure(String type, String message)
    : this(error: {'type': type, 'message': message});

  /// Whether the script finished without an error.
  bool get ok => error == null;

  /// The result as JSON: what `${result}` is after a failed "Run script"
  /// action, and what the Editor's console and the MCP show.
  Map<String, Object?> toJson() => {
    'ok': ok,
    'value': value,
    if (error != null) 'error': error,
    'logs': logs,
    if (writes.isNotEmpty) 'writes': writes,
    'cpuMs': cpuMs,
    if (memory != null) 'memory': memory,
  };

  @override
  String toString() => ok
      ? 'ScriptRunResult($value)'
      : 'ScriptRunResult(${error!['type']}: ${error!['message']})';
}

/// Runs [ScriptModel]s in the platform's [ScriptSandbox].
abstract final class ScriptRunner {
  static int _runCount = 0;

  /// The longest a run may take in all, waits on the host included.
  static Duration wallTimeout = const Duration(minutes: 5);

  /// Builds the request the driver's `__cl_start` takes.
  static Map<String, Object?> request(
    ScriptModel script, {
    Map<String, Object?> args = const {},
    Map<String, ScriptModel> scripts = const {},
    ScriptHost? host,
    int? seed,
    DateTime? now,
  }) {
    final Set<ScriptCapability> grants = script.capabilities.toSet();
    final bool readsVariables =
        grants.contains(ScriptCapability.variablesRead) ||
        grants.contains(ScriptCapability.variablesWrite);
    return {
      'run': 'r${++_runCount}',
      'source': script.source,
      'paramNames': script.paramNames,
      'params': {
        for (final ScriptParam p in script.params)
          p.name: args.containsKey(p.name) ? args[p.name] : p.defaultValue,
      },
      'grants': script.capabilityIds,
      if (readsVariables && host != null) 'vars': _json(host.variables()),
      if (grants.contains(ScriptCapability.nodesRead) && host != null)
        'nodes': _json(host.nodeValues()),
      'seed': seed ?? _seedOf(script, args),
      if (grants.contains(ScriptCapability.clock))
        'now': (now ?? DateTime.now()).millisecondsSinceEpoch,
      'scripts': {
        for (final ScriptModel s in scripts.values)
          if (s.name != script.name)
            s.name: {'source': s.source, 'paramNames': s.paramNames},
      },
    };
  }

  /// A seed derived from the script and its arguments, so the same call
  /// gives the same `Math.random` sequence every time.
  static int _seedOf(ScriptModel script, Map<String, Object?> args) {
    // FNV-1a over the text, the same on every platform (String.hashCode
    // differs between the VM and the web).
    int h = 0x811c9dc5;
    for (final int c
        in '${script.id}:${script.version}:${_stableText(args)}'.codeUnits) {
      h ^= c;
      // h * 0x01000193 mod 2^32, without products above 2^53 (the web's
      // integers are doubles).
      h = (h * 0x193 + ((h & 0xff) << 24)) & 0xffffffff;
    }
    return (h & 0x7fffffff) | 1;
  }

  static String _stableText(Object? v) {
    if (v is Map) {
      final List<String> keys = [for (final Object? k in v.keys) '$k']..sort();
      return '{${keys.map((k) => '$k:${_stableText(v[k])}').join(',')}}';
    }
    if (v is List) return '[${v.map(_stableText).join(',')}]';
    return '$v';
  }

  /// JSON-safe data: what the host hands the script.
  static Object? _json(Object? v, [int depth = 0]) {
    if (depth > 64) return null;
    if (v == null || v is bool || v is String) return v;
    if (v is num) return v.isFinite ? v : null;
    if (v is List) return [for (final Object? e in v) _json(e, depth + 1)];
    if (v is Map) {
      return <String, Object?>{
        for (final MapEntry e in v.entries)
          '${e.key}': _json(e.value, depth + 1),
      };
    }
    if (v is DateTime) return v.toIso8601String();
    try {
      // Models with toJson, such as ColorRGBA.
      return _json((v as dynamic).toJson(), depth + 1);
    } on Object {
      return '$v';
    }
  }

  /// Runs [script] with [args] and returns its result. [scripts] are the
  /// other scripts it can call as `script.name(...)`. Never throws.
  static Future<ScriptRunResult> run(
    ScriptModel script, {
    Map<String, Object?> args = const {},
    Map<String, ScriptModel> scripts = const {},
    ScriptHost? host,
    int? seed,
    DateTime? now,
    ScriptSandbox? sandbox,
  }) async {
    final ScriptSandbox box;
    try {
      box = sandbox ?? ScriptSandbox.instance;
    } on Object catch (e) {
      return ScriptRunResult.failure('EngineUnavailable', '$e');
    }
    final Map<String, Object?> req = request(
      script,
      args: args,
      scripts: scripts,
      host: host,
      seed: seed,
      now: now,
    );
    final String run = req['run'] as String;
    final Duration budget = Duration(milliseconds: script.timeoutMs);
    final List<Map<String, Object?>> logs = [];
    final List<Map<String, Object?>> writes = [];
    final Stopwatch wall = Stopwatch()..start();
    try {
      Map<String, Object?> state = await box.start(
        req,
        cpuBudget: budget,
        memoryLimit: script.memoryLimitMb << 20,
      );
      while (true) {
        _collectLogs(state, logs);
        final List<Map<String, Object?>> responses = [];
        for (final Object? event in state['events'] as List? ?? const []) {
          if (event is! Map) continue;
          if (event['type'] == 'write') {
            final String name = '${event['name']}';
            try {
              host?.setVariable(name, event['value']);
              writes.add({'name': name, 'value': event['value']});
            } on ScriptHostError catch (e) {
              logs.add({
                'level': 'error',
                'message': 'vars.set("$name"): ${e.message}',
              });
            }
          } else if (event['type'] == 'call') {
            responses.add(await _call(host, event));
          }
        }
        if (state['status'] != 'waiting') {
          final Object? error = state['error'];
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
        if (wall.elapsed > wallTimeout) {
          box.end(run);
          return ScriptRunResult(
            error: {
              'type': 'LimitError',
              'limit': 'time',
              'message':
                  'The script waited on the app for more than ${wallTimeout.inSeconds} s.',
            },
            logs: logs,
            writes: writes,
          );
        }
        state = await box.resume(run, responses, cpuBudget: budget);
      }
    } on Object catch (e) {
      box.end(run);
      return ScriptRunResult(
        error: {
          'type': e is ScriptEngineUnavailable ? 'EngineUnavailable' : 'Error',
          'message': '$e',
        },
        logs: logs,
        writes: writes,
      );
    }
  }

  /// Runs [script] synchronously, for formulas. Returns null when the
  /// platform can't run scripts synchronously (the web) or the script waits
  /// on the host (it awaits an `app.*` call); call [run] then.
  static ScriptRunResult? runSync(
    ScriptModel script, {
    Map<String, Object?> args = const {},
    Map<String, ScriptModel> scripts = const {},
    ScriptHost? host,
    ScriptSandbox? sandbox,
  }) {
    final ScriptSandbox box;
    try {
      box = sandbox ?? ScriptSandbox.instance;
    } on Object catch (e) {
      return ScriptRunResult.failure('EngineUnavailable', '$e');
    }
    if (!box.isSynchronous) return null;
    final Map<String, Object?> req = request(
      script,
      args: args,
      scripts: scripts,
      host: host,
    );
    try {
      final FutureOr<Map<String, Object?>> started = box.start(
        req,
        cpuBudget: Duration(milliseconds: script.timeoutMs),
        memoryLimit: script.memoryLimitMb << 20,
      );
      if (started is Future) return null;
      final Map<String, Object?> state = started;
      if (state['status'] == 'waiting') {
        box.end(req['run'] as String);
        return ScriptRunResult.failure(
          'TypeError',
          'A formula can\'t wait on the app: script.${script.name}() awaits an app.* call. Run it with a "Run script" action instead.',
        );
      }
      final List<Map<String, Object?>> logs = [];
      _collectLogs(state, logs);
      final Object? error = state['error'];
      return ScriptRunResult(
        value: state['status'] == 'done' ? state['value'] : null,
        error: state['status'] == 'done'
            ? null
            : (error as Map?)?.cast<String, Object?>(),
        logs: logs,
        cpuMs: (state['cpuMs'] as num?)?.toDouble() ?? 0,
        memory: (state['memory'] as num?)?.toInt(),
      );
    } on Object catch (e) {
      return ScriptRunResult.failure(
        e is ScriptEngineUnavailable ? 'EngineUnavailable' : 'Error',
        '$e',
      );
    }
  }

  static void _collectLogs(
    Map<String, Object?> state,
    List<Map<String, Object?>> logs,
  ) {
    for (final Object? l in state['logs'] as List? ?? const []) {
      if (l is Map) logs.add(l.cast<String, Object?>());
    }
  }

  static Future<Map<String, Object?>> _call(ScriptHost? host, Map event) async {
    final Object? id = event['id'];
    if (host == null) {
      return {
        'id': id,
        'ok': false,
        'error': {
          'type': 'HostError',
          'message': 'There is no app to call here.',
        },
      };
    }
    try {
      final Object? value = await host.call('${event['name']}', [
        ...?(event['args'] as List?),
      ]);
      return {'id': id, 'ok': true, 'value': _json(value)};
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
