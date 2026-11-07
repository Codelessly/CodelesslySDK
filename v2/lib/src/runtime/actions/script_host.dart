// The run script action: a layout's script run by the app's ScriptRunner,
// with a host over the running chain (its variables, the screen's inputs,
// navigation, APIs, actions). SDK 8.x's runScript and FlutterScriptHost.
import 'dart:async';
import 'dart:convert';

import 'package:codelessly_api_v2/codelessly_api.dart';

import '../../render/source.dart';
import '../../services/services.dart';
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
Future<void> runScriptAction(RunScriptAction a, ActionRun run) async {
  final host = run.host;
  final scripts = host is RuntimeActionContext ? host.scripts : const <ScriptDef>[];
  final script = findScript(scripts, a.script.trim());
  final services = run.context.services;
  final runner = services is Services ? services.scripts : const NoScriptRunner();
  final result = script == null
      ? ScriptRunResult.failure('ReferenceError', 'There is no script "${a.script}".')
      : await runner.run(
          script,
          args: {for (final e in a.arguments.entries) e.key: scriptArgument(e.value, run)},
          scripts: scripts,
          host: RuntimeScriptHost(run),
        );
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

/// A [ScriptHost] over a running chain.
class RuntimeScriptHost implements ScriptHost {
  RuntimeScriptHost(this.run);

  final ActionRun run;

  Iterable<VariableScope> get _scopes sync* {
    for (ValueScope? s = run.context.scope; s != null; s = s.parent) {
      if (s is VariableScope) yield s;
    }
  }

  @override
  Map<String, Object?> variables() {
    final out = <String, Object?>{};
    for (final s in _scopes) {
      for (final v in s.variables) {
        if (v.isFunction || out.containsKey(v.name)) continue;
        out[v.name] = s.valueOf(v.name, run.scope);
      }
    }
    return out;
  }

  @override
  Map<String, Object?> nodeValues() {
    final tree = run.host.tree;
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
  Future<Object?> call(String name, List<Object?> args) async {
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
