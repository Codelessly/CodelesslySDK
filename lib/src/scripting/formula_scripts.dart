// `script.name(args)` in formulas: SDK 8.x's ScriptFormulaCalls and
// ScriptResults, as a value scope declaring `script` above a screen's
// variables.
import 'dart:collection';
import 'dart:async';
import 'dart:convert';

import 'package:codelessly_api/codelessly_api.dart' show ScriptCapability, ScriptDef, findScript;
import 'package:flutter/foundation.dart';

import '../runtime/actions/script_host.dart' show scriptVariables;
import '../runtime/contracts.dart';
import '../runtime/expressions/formula.dart';
import '../runtime/expressions/scopes.dart';
import '../services/scripts.dart';
import 'script_runner.dart';

/// Declares `script`: formulas read it to call a screen's [scripts] with
/// arguments in their parameters' order.
///
/// A formula only reads, so a script runs with its read capabilities alone
/// (`variables.read`, `nodes.read`, `clock`): it can't change variables or
/// call the app. Results are cached by arguments when the script reads
/// nothing else, so re-applying a binding doesn't run it again. Where a
/// script can't run synchronously (the web's worker, a runner other than
/// [SandboxScriptRunner]) the first evaluation starts it and gives null;
/// `script` notifies when the result arrives, so what read it re-applies.
class ScriptsScope extends NamedScope implements FormulaScripts {
  ScriptsScope({required this.scripts, required this.runner, super.parent});

  final List<ScriptDef> scripts;
  final ScriptRunner runner;

  /// Where scripts read variables (the screen's variables); this scope by
  /// default.
  ValueScope? reader;

  /// The input values on screen, by node id.
  Map<String, Object?> Function()? nodeValues;

  /// The most results kept.
  static const int maxResults = 500;

  final LinkedHashMap<String, ScriptRunResult> _results = LinkedHashMap();
  final Set<String> _running = {};
  final Map<String, Future<ScriptRunResult>> _pending = {};
  Set<String>? _resolvingReads;
  bool _resolvedRead = false;
  bool _disposed = false;

  static const Set<ScriptCapability> _readOnly = {
    ScriptCapability.variablesRead,
    ScriptCapability.nodesRead,
    ScriptCapability.clock,
  };

  @override
  bool declares(String name) => name == 'script';

  @override
  Object? valueOf(String name, ValueScope reader) => name == 'script' ? this : null;

  /// Forgets every cached result, e.g. after the scripts changed.
  void clear() => _results.clear();

  ScriptRunResult? _get(String key) {
    final r = _results.remove(key);
    if (r != null) _results[key] = r;
    return r;
  }

  void _put(String key, ScriptRunResult result) {
    _results[key] = result;
    while (_results.length > maxResults) {
      _results.remove(_results.keys.first);
    }
  }

  @override
  Object? callScript(String name, List<Object?> args) {
    final found = findScript(scripts, name);
    if (found == null) throw StateError('There is no script named "$name"');
    final script = found.copyWith(capabilities: found.capabilities.where(_readOnly.contains).toList());
    final named = <String, Object?>{
      for (var i = 0; i < script.params.length; i++)
        if (i < args.length) script.params[i].name: args[i],
    };
    final pure = script.capabilities.isEmpty;
    final key = '${script.id}@${script.version}:${_text(named)}';
    _resolvingReads?.add(key);
    if (pure || _resolvedRead) {
      final cached = _get(key);
      if (cached != null) return cached.ok ? cached.value : null;
    }
    final host = _ReadOnlyHost(this);
    final runner = this.runner;
    final now = runner is SandboxScriptRunner ? runner.runSync(script, args: named, scripts: scripts, host: host) : null;
    if (now != null) {
      if (pure || _resolvingReads != null) _put(key, now);
      _report(script, now);
      return now.ok ? now.value : null;
    }
    // Asynchronous: run it, and notify when it's done.
    final earlier = _get(key);
    if (_running.add(key)) {
      _pending[key] = runner.run(script, args: named, scripts: scripts, host: host).then((result) {
        _running.remove(key);
        _pending.remove(key);
        if (_disposed) return result;
        final changedValue =
            earlier == null || jsonEncode(earlier.value) != jsonEncode(result.value) || earlier.ok != result.ok;
        _put(key, result);
        _report(script, result);
        if (changedValue) changed(const ['script']);
        return result;
      });
    }
    return earlier != null && earlier.ok ? earlier.value : null;
  }

  /// Resolves the script calls an action reads before it writes their value.
  /// UI formulas remain synchronous and repaint when their worker completes.
  Future<T> resolve<T>(T Function() evaluate) async {
    var warmed = false;
    for (var pass = 0; pass < 32; pass++) {
      if (_disposed) throw StateError('The script scope was disposed.');
      final reads = <String>{};
      final previousReads = _resolvingReads;
      final previousResolved = _resolvedRead;
      _resolvingReads = reads;
      _resolvedRead = warmed;
      late T value;
      try { value = evaluate(); } finally {
        _resolvingReads = previousReads;
        _resolvedRead = previousResolved;
      }
      final pending = <Future<ScriptRunResult>>[];
      for (final key in reads) {
        final future = _pending[key];
        if (future != null) {
          pending.add(future);
        } else if (_results[key] case final ScriptRunResult result when !result.ok) {
          throw StateError('Script formula failed: ${result.error}');
        }
      }
      if (pending.isEmpty) return value;
      for (final result in await Future.wait(pending)) {
        if (!result.ok) throw StateError('Script formula failed: ${result.error}');
      }
      warmed = true;
    }
    throw StateError('Script formula dependencies did not settle.');
  }

  static void _report(ScriptDef script, ScriptRunResult result) {
    if (result.ok || !kDebugMode) return;
    debugPrint('script.${script.name}() failed in a formula: ${result.error!['type']}: ${result.error!['message']}');
  }

  static String _text(Object? v) {
    try {
      return jsonEncode(v);
    } on Object {
      return '$v';
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// A [ScriptHost] that only reads: for scripts called from formulas.
class _ReadOnlyHost implements ScriptHost {
  _ReadOnlyHost(this.scope);

  final ScriptsScope scope;

  @override
  Map<String, Object?> variables() {
    final reader = scope.reader ?? scope;
    return scriptVariables(reader, reader);
  }

  @override
  Map<String, Object?> nodeValues() => scope.nodeValues?.call() ?? const {};

  @override
  void setVariable(String name, Object? value) => throw const ScriptHostError('A formula can\'t change variables.');

  @override
  Future<Object?> call(String name, List<Object?> args) => throw const ScriptHostError('A formula can\'t call the app.');
}
