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
/// Messages in are `kind\nrun\npayload` (kind is `start`, `resume`,
/// `check` or `ping`). Messages out are `run\n#begin` when a step starts
/// running, `run\n#ms <step time>\nstate` once the run's jobs have run,
/// and `run\n#pong` for a ping.
const String _workerAdapter = r'''
(function () {
  'use strict';
  const post = self.postMessage.bind(self);
  const later = self.setTimeout.bind(self);
  const now = self.performance.now.bind(self.performance);
  // A step's time: from its message until the next task starts, by when
  // its promise jobs have all run.
  const stepMs = {};
  let open = null;
  function close() {
    if (open) stepMs[open.run] = now() - open.began;
    open = null;
  }
  self.addEventListener('message', function (e) {
    close();
    const text = String(e.data);
    const a = text.indexOf('\n'), b = text.indexOf('\n', a + 1);
    const kind = text.slice(0, a), run = text.slice(a + 1, b), payload = text.slice(b + 1);
    if (kind === 'ping') {
      post(run + '\n#pong');
      return;
    }
    if (kind === 'check') {
      post(run + '\n' + JSON.stringify({ run, check: globalThis.__cl_check(payload) }));
      return;
    }
    post(run + '\n#begin');
    open = { run, began: now() };
    try {
      (kind === 'start' ? globalThis.__cl_start : globalThis.__cl_resume)(payload);
    } catch (err) {
      post(run + '\n' + JSON.stringify({ run, status: 'error', error: { type: 'Error', message: String(err && err.message || err) } }));
      return;
    }
    // A timer runs after every pending promise reaction of the run.
    // The step's time, measured here: the app may be too busy to tell.
    later(function () {
      close();
      const ms = stepMs[run] || 0;
      delete stepMs[run];
      post(run + '\n#ms ' + ms + '\n' + globalThis.__cl_state(run));
    }, 0);
  });
})();
''';

/// The start of the function the driver wraps a script in; the same text
/// as the driver's `compile`, so a syntax error's column can be corrected.
String scriptHead(List<String> paramNames) =>
    '(async function __script(vars, nodes, app, console, fmt, script, params'
    '${paramNames.isEmpty ? '' : ', ${paramNames.join(', ')}'}) {"use strict"; {';

/// Runs scripts in a dedicated Web Worker.
///
/// The worker has no DOM and, after the driver's lockdown, no network,
/// storage or timers. A run that computes longer than its CPU budget
/// without waiting on the host can't be interrupted inside the worker, so
/// the worker is terminated (ending every run in it) and a new one starts
/// for the next run.
///
/// The worker runs one step at a time, and its messages wait while the app
/// is busy, so a run's clock starts when the worker says it began the
/// step, not when the app sent it; and before terminating, the app pings
/// the worker: one that answers isn't stuck in the run.
class WorkerSandbox implements ScriptSandbox {
  web.Worker? _worker;
  String? _url;

  final Map<String, Completer<Map<String, Object?>>> _waiting = {};
  final Map<String, Timer> _watchdogs = {};
  final Map<String, Stopwatch> _cpu = {};

  /// The time the worker measured for each run's steps so far.
  final Map<String, double> _workerMs = {};
  final Map<String, List<String>> _paramNames = {};
  final Map<String, String> _sources = {};
  final Map<String, Completer<Map<String, Object?>?>> _checks = {};
  final Map<String, Duration> _budgets = {};
  int _checkCount = 0;

  /// The run whose step the worker began last.
  String? _current;

  /// Counts the worker's messages, to tell whether it answered.
  int _heard = 0;

  /// How long a worker may take to answer a ping before it is terminated.
  static const Duration pingGrace = Duration(milliseconds: 750);

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
      _heard++;
      final String run = text.substring(0, nl);
      final String body = text.substring(nl + 1);
      if (body == '#pong') return;
      if (body == '#begin') {
        _began(run);
        return;
      }
      _deliver(run, body);
    }).toJS;
    worker.onerror = ((web.Event e) {
      e.preventDefault();
      _killWorker(
        'The script engine failed: ${e.isA<web.ErrorEvent>() ? (e as web.ErrorEvent).message : e.type}',
      );
    }).toJS;
    return _worker = worker;
  }

  /// Starts [run]'s clock and watchdog: the worker began a step of it.
  void _began(String run) {
    _current = run;
    if (!_waiting.containsKey(run)) return;
    final Stopwatch cpu = _cpu.putIfAbsent(run, Stopwatch.new)..start();
    final Duration budget = _budgets[run] ?? const Duration(seconds: 1);
    final Duration left = budget - cpu.elapsed;
    _watchdogs.remove(run)?.cancel();
    _watchdogs[run] = Timer(
      left.isNegative ? Duration.zero : left,
      () => _overBudget(run, budget),
    );
  }

  /// [run]'s step is over its budget, unless the worker has moved on (its
  /// result is waiting for the app) or answers a ping.
  void _overBudget(String run, Duration budget) {
    _watchdogs.remove(run);
    if (_current != run || !_waiting.containsKey(run)) return;
    final int heard = _heard;
    _worker?.postMessage('ping\n$run\n'.toJS);
    _watchdogs[run] = Timer(pingGrace, () {
      _watchdogs.remove(run);
      if (_heard != heard || !_waiting.containsKey(run)) return;
      _killWorker(
        'Another script ran too long, so the script engine restarted.',
        run: run,
        errorFor: {
          'type': 'LimitError',
          'limit': 'time',
          'message':
              'The script ran longer than ${budget.inMilliseconds} ms. Is there an endless loop?',
        },
      );
    });
  }

  void _deliver(String run, String message) {
    String stateJson = message;
    if (message.startsWith('#ms ')) {
      final int nl = message.indexOf('\n');
      _workerMs[run] =
          (_workerMs[run] ?? 0) +
          (double.tryParse(message.substring(4, nl)) ?? 0);
      stateJson = message.substring(nl + 1);
    }
    final Completer<Map<String, Object?>?>? checking = _checks.remove(run);
    if (checking != null) {
      final Object? check = (jsonDecode(stateJson) as Map)['check'];
      checking.complete(
        check is String && check.isNotEmpty
            ? (jsonDecode(check) as Map).cast<String, Object?>()
            : null,
      );
      return;
    }
    _watchdogs.remove(run)?.cancel();
    _cpu[run]?.stop();
    final Completer<Map<String, Object?>>? completer = _waiting.remove(run);
    if (completer == null) return;
    final Map<String, Object?> state = (jsonDecode(stateJson) as Map)
        .cast<String, Object?>();
    state['cpuMs'] =
        _workerMs[run] ?? (_cpu[run]?.elapsedMicroseconds ?? 0) / 1000;
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
    _workerMs.remove(run);
    _budgets.remove(run);
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
    _current = null;
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
    _budgets[run] = cpuBudget;
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
    Map<String, Object?>? vars,
  }) => _send(
    'resume',
    run,
    jsonEncode({'run': run, 'responses': responses, 'vars': ?vars}),
    cpuBudget,
  );

  @override
  Future<Map<String, Object?>?> check(
    String source,
    List<String> paramNames,
  ) async {
    final String id = 'check${++_checkCount}';
    final Completer<Map<String, Object?>?> done = Completer();
    _checks[id] = done;
    _ensureWorker().postMessage(
      'check\n$id\n${jsonEncode({'source': source, 'paramNames': paramNames})}'
          .toJS,
    );
    final Map<String, Object?>? error = await done.future.timeout(
      const Duration(seconds: 2),
      onTimeout: () {
        _checks.remove(id);
        return {'type': 'Error', 'message': 'The check timed out.'};
      },
    );
    if (error != null &&
        error['type'] == 'SyntaxError' &&
        error['line'] == null) {
      final (int, int)? pos = await locateSyntaxError(source, paramNames);
      if (pos != null) {
        error['line'] = pos.$1;
        error['column'] = pos.$2;
      }
    }
    return error;
  }

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
        ['$head$source\n}})'.toJS].toJS,
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
      if (e.isA<web.ErrorEvent>()) {
        final web.ErrorEvent error = e as web.ErrorEvent;
        final int line = error.lineno;
        int column = error.colno;
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
