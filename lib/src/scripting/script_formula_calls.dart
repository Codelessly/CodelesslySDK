import 'dart:collection';
import 'dart:convert';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/foundation.dart';

import '../../codelessly_sdk.dart';

/// Notifies when a script result that formulas are waiting for arrives
/// (on the web, where scripts run in a worker), so widgets whose formulas
/// call scripts rebuild with it.
class ScriptResults extends ChangeNotifier {
  ScriptResults._();

  /// The notifier every formula-bound widget shares.
  static final ScriptResults instance = ScriptResults._();

  /// Results of formula calls, by script, version and arguments.
  final LinkedHashMap<String, ScriptRunResult> _results = LinkedHashMap();

  /// Calls still running.
  final Set<String> _running = {};

  /// The most results kept.
  static const int maxResults = 500;

  ScriptRunResult? _get(String key) {
    final ScriptRunResult? r = _results.remove(key);
    if (r != null) _results[key] = r;
    return r;
  }

  void _put(String key, ScriptRunResult result) {
    _results[key] = result;
    while (_results.length > maxResults) {
      _results.remove(_results.keys.first);
    }
  }

  /// Forgets every cached result, e.g. after the scripts changed.
  void clear() => _results.clear();

  /// Lets widgets know results arrived.
  void announce() => notifyListeners();
}

/// What `script` resolves to in formulas: calls a script of the screen
/// with arguments in its parameters' order.
///
/// A formula only reads, so the script runs with its read capabilities
/// alone (`variables.read`, `nodes.read`, `clock`): it can't change
/// variables or call the app. Results are cached by arguments when the
/// script reads nothing else, so rebuilds don't run it again. On the web,
/// where a script runs in a worker, the first evaluation starts it and
/// gives null; widgets rebuild with the result through [ScriptResults].
class ScriptFormulaCalls implements FormulaScripts {
  /// Where the formula is evaluated.
  final ScopedValues scopedValues;

  /// Creates a [ScriptFormulaCalls].
  const ScriptFormulaCalls(this.scopedValues);

  static const Set<ScriptCapability> _readOnly = {
    ScriptCapability.variablesRead,
    ScriptCapability.nodesRead,
    ScriptCapability.clock,
  };

  @override
  Object? callScript(String name, List<Object?> args) {
    final CodelesslyContext? context = scopedValues.codelesslyContext;
    final ScriptModel? found = context?.findScript(name);
    if (found == null) throw StateError('There is no script named "$name"');
    final ScriptModel script = found.copyWith(
      capabilities: found.capabilities.where(_readOnly.contains).toList(),
    );
    final Map<String, Object?> named = {
      for (int i = 0; i < script.params.length; i++)
        if (i < args.length) script.params[i].name: args[i],
    };
    final bool pure = script.capabilities.isEmpty;
    final String key = '${script.id}@${script.version}:${_text(named)}';
    final ScriptResults results = ScriptResults.instance;
    if (pure) {
      final ScriptRunResult? cached = results._get(key);
      if (cached != null) return cached.ok ? cached.value : null;
    }
    final ScriptHost host = _ReadOnlyHost(context!, scopedValues);
    final ScriptRunResult? now = ScriptRunner.runSync(
      script,
      args: named,
      scripts: context.scripts,
      host: host,
    );
    if (now != null) {
      if (pure) results._put(key, now);
      _report(script, now);
      return now.ok ? now.value : null;
    }
    // The web: run it in the worker, and rebuild when it's done.
    final ScriptRunResult? earlier = results._get(key);
    if (results._running.add(key)) {
      ScriptRunner.run(
        script,
        args: named,
        scripts: context.scripts,
        host: host,
      ).then((ScriptRunResult result) {
        results._running.remove(key);
        final bool changed =
            earlier == null ||
            jsonEncode(earlier.value) != jsonEncode(result.value) ||
            earlier.ok != result.ok;
        results._put(key, result);
        _report(script, result);
        if (changed) results.announce();
      });
    }
    return earlier != null && earlier.ok ? earlier.value : null;
  }

  static void _report(ScriptModel script, ScriptRunResult result) {
    if (result.ok) return;
    DebugLogger.instance.printInfo(
      'script.${script.name}() failed in a formula: ${result.error!['type']}: ${result.error!['message']}',
      name: 'ScriptFormulaCalls',
    );
  }

  static String _text(Object? v) {
    try {
      return jsonEncode(v);
    } on Object {
      return '$v';
    }
  }
}

/// A [ScriptHost] that only reads: for scripts called from formulas.
class _ReadOnlyHost implements ScriptHost {
  final CodelesslyContext context;
  final ScopedValues scopedValues;

  _ReadOnlyHost(this.context, this.scopedValues);

  @override
  Map<String, Object?> variables() => {
    for (final Observable<VariableData> v in context.variables.values)
      if (!v.value.isFunction)
        v.value.name:
            PropertyValueDelegate.getVariableValueFromPath<Object>(
              v.value.name.wrapWithVariableSyntax(),
              scopedValues: scopedValues,
            ) ??
            v.value.getValue(),
  };

  @override
  Map<String, Object?> nodeValues() => {
    for (final MapEntry<String, Observable<List<ValueModel>>> e
        in context.nodeValues.entries)
      if (e.value.value
              .where((v) => v.name == 'value' || v.name == 'inputValue')
              .firstOrNull
          case final ValueModel value)
        e.key: value.value,
  };

  @override
  void setVariable(String name, Object? value) =>
      throw const ScriptHostError('A formula can\'t change variables.');

  @override
  Future<Object?> call(String name, List<Object?> args) =>
      throw const ScriptHostError('A formula can\'t call the app.');
}
