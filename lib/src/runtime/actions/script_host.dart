// The run script action: a layout's script run by the app's ScriptRunner,
// with a host over the running chain (its variables, the screen's inputs,
// navigation, APIs, actions).
import 'dart:async';
import 'dart:convert';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/foundation.dart';

import '../../render/node_tree.dart' show NodeTree;
import '../../render/source.dart';
import '../../services/scripts.dart';
import '../contracts.dart' show ValueScope;
import '../expressions/formula.dart';
import '../expressions/paths.dart';
import '../expressions/scopes.dart';
import 'context.dart';
import 'node_values.dart';
import 'runner.dart';
import 'values.dart';
import 'wiring.dart' show TreeReactions;

/// A run script action's script failed and it had no `onError` actions.
class ScriptFailed implements Exception {
  const ScriptFailed(this.message, this.error);

  final String message;

  /// `{type, message, line?, column?}`.
  final Json error;

  @override
  String toString() => message;
}

/// Runs [a]: its result is `${result}` (and its result variable's value);
/// a failure runs its `onError` with `${result}` `{error, logs}`, or stops
/// the chain without them.
Future<void> runScriptAction(RunScriptAction a, ActionRun run) {
  final host = run.host;
  final scripts = host is CoreActionContext
      ? host.scripts
      : const <ScriptDef>[];
  final script = findScript(scripts, a.script.trim());
  Future<void> execute() => _executeScriptAction(a, run, script, scripts);
  if ((script?.allows(ScriptCapability.variablesWrite) ?? false) ||
      a.resultVariable.trim().isNotEmpty) {
    return _serializeScriptWrite(run, execute);
  }
  return execute();
}

final _scriptWriteTurns = Expando<_WriteTurns>('script variable writes');
final _heldScriptWriteScopes = Object();
final _scriptWriteTurn = Object();

/// The writers of one app scope, one at a time.
class _WriteTurns {
  Future<void> _tail = Future<void>.value();

  /// Waits for the writers ahead; returns the function that lets the next go.
  Future<void Function()> take() async {
    final done = Completer<void>();
    final before = _tail;
    _tail = done.future;
    await before;
    var released = false;
    return () {
      if (released) return;
      released = true;
      done.complete();
    };
  }
}

/// A writer's turn: given back while its script waits on the app
/// (app.delay, a navigation, an API call) and taken again before it goes on.
class ScriptWriteTurn {
  ScriptWriteTurn._(this._turns);

  final _WriteTurns _turns;
  void Function()? _release;

  Future<void> _take() async => _release = await _turns.take();

  void _giveBack() {
    _release?.call();
    _release = null;
  }

  /// Runs [wait] without the turn, so other writers (a cancel, a timer tick)
  /// can run meanwhile; the script reads fresh variables when it resumes.
  Future<T> without<T>(Future<T> Function() wait) async {
    _giveBack();
    try {
      return await wait();
    } finally {
      await _take();
    }
  }

  /// The turn of the script running in this zone, if it writes variables.
  static ScriptWriteTurn? get current => Zone.current[_scriptWriteTurn] as ScriptWriteTurn?;
}

/// A script takes its variable snapshot when it starts. Writers sharing an app
/// scope must run through their commits in order, or a timer can overwrite a
/// newer edit with an old snapshot. Pure reads and different apps stay parallel.
/// A writer waiting on the app gives its turn back meanwhile (it reads the
/// variables afresh when it resumes), so a long run with delays doesn't hold
/// every other writer until it ends.
Future<void> _serializeScriptWrite(
  ActionRun run,
  Future<void> Function() execute,
) async {
  Object owner = run.context.scope;
  for (
    ValueScope? scope = run.context.scope;
    scope != null;
    scope = scope.parent
  ) {
    if (scope is VariableScope) owner = scope;
  }
  final held =
      Zone.current[_heldScriptWriteScopes] as Set<Object>? ?? const <Object>{};
  // A host action nested in this script is part of the same write chain.
  if (held.contains(owner)) return execute();
  final turn = ScriptWriteTurn._(_scriptWriteTurns[owner] ??= _WriteTurns());
  await turn._take();
  try {
    if (run.isCanceled) throw const ActionsCanceled();
    await runZoned<Future<void>>(
      execute,
      zoneValues: {
        _heldScriptWriteScopes: {...held, owner},
        _scriptWriteTurn: turn,
      },
    );
  } finally {
    turn._giveBack();
  }
}

Future<void> _executeScriptAction(
  RunScriptAction a,
  ActionRun run,
  ScriptDef? script,
  List<ScriptDef> scripts,
) async {
  final runner = run.service<ScriptRunner>() ?? const NoScriptRunner();
  final result = script == null
      ? ScriptRunResult.failure('ReferenceError', 'There is no script "${a.script}".')
      : await runner.run(
          script,
          args: {for (final e in a.arguments.entries) e.key: scriptArgument(e.value, run)},
          scripts: scripts,
          host: RuntimeScriptHost(run),
        );
  if (kDebugMode) {
    for (final log in result.logs) {
      debugPrint('[script ${script?.name ?? a.script}] ${log['level']}: ${log['message']}');
    }
  }
  if (result.ok) {
    run.result = result.value;
    final name = a.resultVariable.trim();
    if (name.isNotEmpty) setVariableIn(run.context.scope, name, result.value);
    return;
  }
  final error = result.error!;
  if (a.onError.isNotEmpty) {
    run.result = {'error': error, 'logs': result.logs};
    await run.run(a.onError);
    return;
  }
  final line = error['line'] == null ? '' : ' (line ${error['line']})';
  throw ScriptFailed('Script ${script?.name ?? a.script} failed: ${error['type']}: ${error['message']}$line', error);
}

/// What a run script argument passes: the value of a text that is exactly
/// one `${...}` (a list stays a list), else the text filled in, read as
/// JSON when it is JSON (`30` a number, `true` a boolean), else as text.
Object? scriptArgument(String text, ActionRun run) {
  if (FormulaEvaluator.exactExpression(text) != null || exactPath(text) != null) return run.evaluate(text);
  final t = run.text(text).trim();
  final jsonLike = t.isNotEmpty &&
      (num.tryParse(t) != null ||
          t == 'true' ||
          t == 'false' ||
          t == 'null' ||
          (t.startsWith('[') && t.endsWith(']')) ||
          (t.startsWith('{') && t.endsWith('}')));
  if (jsonLike) {
    try {
      return jsonDecode(t);
    } on FormatException {
      // Not JSON: the text.
    }
  }
  return run.text(text);
}

/// The variables a script reads in [scope] (and the scopes around it),
/// computed ones read from [reader]; function variables aren't values.
Map<String, Object?> scriptVariables(ValueScope? scope, ValueScope reader, {Set<String>? only}) {
  final out = <String, Object?>{};
  for (ValueScope? s = scope; s != null; s = s.parent) {
    if (s is! VariableScope) continue;
    for (final v in s.variables) {
      if (v.isFunction || out.containsKey(v.name) || (only != null && !only.contains(v.name))) continue;
      out[v.name] = s.valueOf(v.name, reader);
    }
  }
  return out;
}

/// The values of the inputs on [tree]'s screen, by node id.
Map<String, Object?> scriptNodeValues(NodeTree? tree) {
  var source = tree?.source;
  if (source is NodeValues) source = source.base;
  if (tree == null || source is! DocumentSource) return const {};
  final out = <String, Object?>{};
  for (final id in source.document.nodes.keys) {
    final node = tree.resolve(id);
    final path = node == null ? null : TreeReactions.valuePaths[node.type];
    if (path == null) continue;
    out[id] = readJsonPath(node!.toJson(), path);
  }
  return out;
}

/// A [ScriptHost] over a running chain.
class RuntimeScriptHost implements NamedVariablesScriptHost {
  RuntimeScriptHost(this.run);

  final ActionRun run;

  @override
  Map<String, Object?> variables() => scriptVariables(run.context.scope, run.scope);

  @override
  Map<String, Object?> variablesNamed(Set<String> names) => scriptVariables(run.context.scope, run.scope, only: names);

  @override
  Map<String, Object?> nodeValues() => scriptNodeValues(run.host.tree);

  @override
  void setVariable(String name, Object? value) {
    final found = variableOf(run.context.scope, name);
    if (found == null) throw ScriptHostError('There is no variable named "$name".');
    if (found.$2.isComputed) throw ScriptHostError('"$name" is computed from a formula and can\'t be set.');
    final type = found.$2.type;
    if (value != null && type.coerce(value) == null && type != VariableType.text) {
      throw ScriptHostError('"$name" holds a ${type.name}, so it can\'t be set to ${jsonEncode(value)}.', 'TypeError');
    }
    setVariableIn(run.context.scope, name, type == VariableType.text && value is! String && value != null ? jsonEncode(value) : value);
  }

  @override
  Future<Object?> call(String name, List<Object?> args) {
    // app.yield(ms): wait, giving the write turn back meanwhile. Every other
    // call keeps it, so a run stays one transaction (read, await, write).
    final turn = ScriptWriteTurn.current;
    if (name == 'yield' && turn != null) return turn.without(() => _call('delay', args));
    return _call(name == 'yield' ? 'delay' : name, args);
  }

  Future<Object?> _call(String name, List<Object?> args) async {
    Object? arg(int i) => i < args.length ? args[i] : null;
    Json map(Object? v) => v is Map ? {for (final e in v.entries) '${e.key}': e.value} : const {};
    switch (name) {
      case 'navigate':
        await run.host.ui.navigate(NavigateAction(to: '${arg(0)}'), params: map(arg(1)));
        return null;
      case 'back':
        await run.host.ui.navigate(const NavigateAction(mode: NavigationMode.pop), params: map(arg(0)));
        return null;
      case 'callApi':
        final response = await run.context.services.callApi('${arg(0)}', params: map(arg(1)));
        return response;
      case 'runAction':
        final action = ActionDef.fromJson(arg(0));
        if (action == null || action is UnknownAction) throw const ScriptHostError('app.runAction() needs an action object.');
        if (action is RunScriptAction) {
          throw const ScriptHostError('Scripts call other scripts with script.name(...), not app.runAction().');
        }
        return _runActions([action]);
      case 'toast':
        return _runActions([ShowToastAction(message: '${arg(0)}')]);
      case 'delay':
        final ms = arg(0) is num ? (arg(0)! as num).clamp(0, 60000).toInt() : 0;
        await run.wait(Duration(milliseconds: ms));
        return null;
      case 'cloudData':
        final json = arg(0);
        if (json is! Map) throw const ScriptHostError('app.cloudData() needs a request object.');
        return _runActions([?ActionDef.fromJson({...map(json), 'type': CloudDataAction.typeName})]);
    }
    throw ScriptHostError('Unknown host call "$name".');
  }

  /// Runs [actions] in a chain nested in this one; what `${result}` they
  /// leave.
  Future<Object?> _runActions(List<ActionDef> actions) async {
    final nested = run.nested(null);
    await nested.run(actions);
    return nested.result;
  }
}
