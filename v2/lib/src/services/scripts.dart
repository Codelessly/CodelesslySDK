// Scripts (API v2 `ScriptDef`, a layout's `scripts`): the service that runs
// one in a sandbox, and what a script reaches in the app (its host). The run
// script action asks the app's [ScriptRunner]; the SDK ships the interface
// and the host, an app plugs in an engine.
//
// TODO(scripts): port SDK 8.x's runner (lib/src/scripting: ScriptRunner,
// the JavaScript driver in script_driver.dart, the QuickJS sandbox via
// package:codelessly_quickjs on devices and the Web Worker sandbox on the
// web) as a `SandboxScriptRunner` implementing [ScriptRunner], in its own
// entry point so apps that run no scripts don't carry an engine. Its wire
// protocol (`__cl_start` / resume with host call answers) maps onto
// [ScriptHost] unchanged.
import 'dart:async';

import 'package:codelessly_api_v2/codelessly_api.dart' show Json, ScriptDef;

/// What a script can reach in the app: the screen's variables and inputs,
/// and host calls (`navigate`, `back`, `callApi`, `cloudData`, `runAction`,
/// `toast`, `delay`). Calls a script's capabilities don't grant never get
/// here: the runner refuses them.
abstract interface class ScriptHost {
  /// The variables the script can read, by name.
  Map<String, Object?> variables();

  /// The values of inputs on screen, by node id.
  Map<String, Object?> nodeValues();

  /// Sets variable [name]; throws a [ScriptHostError] when it can't.
  void setVariable(String name, Object? value);

  /// Performs host call [name] with [args]; returns JSON data.
  Future<Object?> call(String name, List<Object?> args);
}

/// A host call failed, as the script's `catch` sees it.
class ScriptHostError implements Exception {
  const ScriptHostError(this.message, [this.type = 'HostError']);

  final String message;

  /// The error's name in the script.
  final String type;

  @override
  String toString() => '$type: $message';
}

/// How a script run ended. A failed run is a result with an [error], never
/// an exception.
class ScriptRunResult {
  const ScriptRunResult({this.value, this.error, this.logs = const [], this.writes = const []});

  /// A failed result of [type] with [message].
  ScriptRunResult.failure(String type, String message) : this(error: {'type': type, 'message': message});

  /// What the script returned, as JSON data.
  final Object? value;

  /// Why it failed: `{type, message, line?, column?}`; null when it didn't.
  final Json? error;

  /// What it logged: `{level, message}`.
  final List<Json> logs;

  /// The variable writes it made, in order: `{name, value}`.
  final List<Json> writes;

  bool get ok => error == null;
}

/// Runs scripts: an app service (`Services.scripts`).
abstract interface class ScriptRunner {
  /// Runs [script] with [args] (by parameter name; missing ones take their
  /// defaults). [scripts] are the others it can call as `script.name()`;
  /// [host] is what it reaches in the app. Never throws.
  Future<ScriptRunResult> run(ScriptDef script,
      {Json args = const {}, List<ScriptDef> scripts = const [], ScriptHost? host});
}

/// The default [ScriptRunner]: no engine, every run fails with an
/// `EngineUnavailable` error (a run script action's `onError` runs).
class NoScriptRunner implements ScriptRunner {
  const NoScriptRunner();

  @override
  Future<ScriptRunResult> run(ScriptDef script,
          {Json args = const {}, List<ScriptDef> scripts = const [], ScriptHost? host}) async =>
      ScriptRunResult.failure('EngineUnavailable', 'This app has no script engine (Services.scripts).');
}

/// A [ScriptRunner] of Dart functions by script name or id: for tests and
/// apps that implement their scripts natively.
class FunctionScriptRunner implements ScriptRunner {
  const FunctionScriptRunner(this.functions);

  final Map<String, FutureOr<Object?> Function(Json args, ScriptHost? host)> functions;

  @override
  Future<ScriptRunResult> run(ScriptDef script,
      {Json args = const {}, List<ScriptDef> scripts = const [], ScriptHost? host}) async {
    final f = functions[script.id] ?? functions[script.name];
    if (f == null) return ScriptRunResult.failure('ReferenceError', 'No function for script ${script.name}.');
    final full = {
      for (final p in script.params)
        if (p.defaultValue != null) p.name: p.defaultValue,
      ...args,
    };
    try {
      return ScriptRunResult(value: await f(full, host));
    } on ScriptHostError catch (e) {
      return ScriptRunResult.failure(e.type, e.message);
    } catch (e) {
      return ScriptRunResult.failure('Error', '$e');
    }
  }
}
