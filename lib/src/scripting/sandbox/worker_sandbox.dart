import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../script_driver.dart';
import 'script_sandbox.dart';

/// A Web Worker on the web.
ScriptSandbox createPlatformSandbox() => WorkerSandbox();

/// The worker's own code: it keeps `postMessage`, `setTimeout` and its
/// message listener for itself, then runs the driver, which removes them
/// (and every other non-standard global) from the scripts' reach.
///
/// Messages in are `kind\nrun\npayload` (kind is `start` or `resume`).
/// Messages out are `run\nstate` once the run's jobs have run.
const String _workerAdapter = r'''
(function () {
  'use strict';
  const post = self.postMessage.bind(self);
  const later = self.setTimeout.bind(self);
  self.addEventListener('message', function (e) {
    const text = String(e.data);
    const a = text.indexOf('\n'), b = text.indexOf('\n', a + 1);
    const kind = text.slice(0, a), run = text.slice(a + 1, b), payload = text.slice(b + 1);
    try {
      (kind === 'start' ? globalThis.__cl_start : globalThis.__cl_resume)(payload);
    } catch (err) {
      post(run + '\n' + JSON.stringify({ run, status: 'error', error: { type: 'Error', message: String(err && err.message || err) } }));
      return;
    }
    // A timer runs after every pending promise reaction of the run.
    later(function () { post(run + '\n' + globalThis.__cl_state(run)); }, 0);
  });
})();
''';

/// The start of the function the driver wraps a script in; the same text
/// as the driver's `compile`, so a syntax error's column can be corrected.
String scriptHead(List<String> paramNames) =>
    '(async function __script(vars, nodes, app, console, fmt, script, params'
    '${paramNames.isEmpty ? '' : ', ${paramNames.join(', ')}'}) {"use strict"; ';

/// Runs scripts in a dedicated Web Worker.
///
/// The worker has no DOM and, after the driver's lockdown, no network,
/// storage or timers. A run that computes longer than its CPU budget
/// without waiting on the host can't be interrupted inside the worker, so
/// the worker is terminated (ending every run in it) and a new one starts
/// for the next run.
class WorkerSandbox implements ScriptSandbox {
  web.Worker? _worker;
  String? _url;

  final Map<String, Completer<Map<String, Object?>>> _waiting = {};
  final Map<String, Timer> _watchdogs = {};
  final Map<String, Stopwatch> _cpu = {};
  final Map<String, List<String>> _paramNames = {};
  final Map<String, String> _sources = {};

  @override
  bool get isSynchronous => false;

  web.Worker _ensureWorker() {
    final web.Worker? existing = _worker;
    if (existing != null) return existing;
    final String url = _url ??= web.URL.createObjectURL(
      web.Blob(
        [(_workerAdapter + scriptDriver).toJS].toJS,
        web.BlobPropertyBag(type: 'text/javascript'),
      ),
    );
    final web.Worker worker = web.Worker(url.toJS);
    worker.onmessage = ((web.MessageEvent e) {
      final String text = (e.data as JSString).toDart;
      final int nl = text.indexOf('\n');
      _deliver(text.substring(0, nl), text.substring(nl + 1));
    }).toJS;
    worker.onerror = ((web.Event e) {
      e.preventDefault();
      _killWorker(
        'The script engine failed: ${e is web.ErrorEvent ? e.message : e.type}',
      );
    }).toJS;
    return _worker = worker;
  }

  void _deliver(String run, String stateJson) {
    _watchdogs.remove(run)?.cancel();
    _cpu[run]?.stop();
    final Completer<Map<String, Object?>>? completer = _waiting.remove(run);
    if (completer == null) return;
    final Map<String, Object?> state = (jsonDecode(stateJson) as Map)
        .cast<String, Object?>();
    state['cpuMs'] = (_cpu[run]?.elapsedMicroseconds ?? 0) / 1000;
    final String? source = _sources[run];
    final List<String> paramNames = _paramNames[run] ?? const [];
    if (state['status'] != 'waiting') _forget(run);
    final Object? error = state['error'];
    if (error is Map &&
        error['type'] == 'RangeError' &&
        '${error['message']}'.contains('call stack')) {
      // V8's stack overflow; QuickJS's is a LimitError too.
      state['error'] = {
        'type': 'LimitError',
        'limit': 'depth',
        'message': 'Functions called each other too deeply. Is there an endless recursion?',
      };
    } else if (error is Map &&
        error['type'] == 'SyntaxError' &&
        error['line'] == null) {
      // V8 doesn't say where a syntax error in eval'd code is; a worker
      // whose own script has the error does.
      if (source != null) {
        locateSyntaxError(source, paramNames).then((pos) {
          if (pos != null) {
            error['line'] = pos.$1;
            error['column'] = pos.$2;
          }
          completer.complete(state);
        });
        return;
      }
    }
    completer.complete(state);
  }

  void _forget(String run) {
    _cpu.remove(run);
    _paramNames.remove(run);
    _sources.remove(run);
  }

  void _killWorker(
    String message, {
    Map<String, Object?>? errorFor,
    String? run,
  }) {
    _worker?.terminate();
    _worker = null;
    for (final MapEntry<String, Completer<Map<String, Object?>>> entry
        in _waiting.entries.toList()) {
      _watchdogs.remove(entry.key)?.cancel();
      entry.value.complete({
        'run': entry.key,
        'status': 'error',
        'error': entry.key == run && errorFor != null
            ? errorFor
            : {'type': 'Error', 'message': message},
      });
      _forget(entry.key);
    }
    _waiting.clear();
  }

  Future<Map<String, Object?>> _send(
    String kind,
    String run,
    String payload,
    Duration cpuBudget,
  ) {
    final web.Worker worker = _ensureWorker();
    final Completer<Map<String, Object?>> completer = Completer();
    _waiting[run] = completer;
    final Stopwatch cpu = _cpu.putIfAbsent(run, Stopwatch.new)..start();
    final Duration left = cpuBudget - cpu.elapsed;
    _watchdogs[run] = Timer(left.isNegative ? Duration.zero : left, () {
      _killWorker(
        'Another script ran too long, so the script engine restarted.',
        run: run,
        errorFor: {
          'type': 'LimitError',
          'limit': 'time',
          'message':
              'The script ran longer than ${cpuBudget.inMilliseconds} ms. Is there an endless loop?',
        },
      );
    });
    worker.postMessage('$kind\n$run\n$payload'.toJS);
    return completer.future;
  }

  @override
  Future<Map<String, Object?>> start(
    Map<String, Object?> request, {
    required Duration cpuBudget,
    required int memoryLimit,
  }) {
    final String run = request['run'] as String;
    _paramNames[run] = [
      for (final Object? p in request['paramNames'] as List? ?? const []) '$p',
    ];
    _sources[run] = request['source'] as String? ?? '';
    return _send('start', run, jsonEncode(request), cpuBudget);
  }

  @override
  Future<Map<String, Object?>> resume(
    String run,
    List<Map<String, Object?>> responses, {
    required Duration cpuBudget,
  }) => _send(
    'resume',
    run,
    jsonEncode({'run': run, 'responses': responses}),
    cpuBudget,
  );

  @override
  void end(String run) {
    _watchdogs.remove(run)?.cancel();
    _waiting.remove(run);
    _forget(run);
  }

  /// The line and column of the syntax error in [source], found by loading
  /// it as a worker's script, or null when it parses.
  static Future<(int, int)?> locateSyntaxError(
    String source,
    List<String> paramNames,
  ) {
    final String head = scriptHead(paramNames);
    final String url = web.URL.createObjectURL(
      web.Blob(
        ['$head$source\n})'.toJS].toJS,
        web.BlobPropertyBag(type: 'text/javascript'),
      ),
    );
    final web.Worker worker = web.Worker(url.toJS);
    final Completer<(int, int)?> done = Completer();
    void finish((int, int)? result) {
      if (done.isCompleted) return;
      worker.terminate();
      web.URL.revokeObjectURL(url);
      done.complete(result);
    }

    worker.onerror = ((web.Event e) {
      e.preventDefault();
      if (e is web.ErrorEvent) {
        final int line = e.lineno;
        int column = e.colno;
        if (line == 1) column -= head.length;
        finish((line, column < 1 ? 1 : column));
      } else {
        finish(null);
      }
    }).toJS;
    // A script that parses runs to its end without an error event.
    Timer(const Duration(milliseconds: 500), () => finish(null));
    return done.future;
  }
}
