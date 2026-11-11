import 'dart:async';

import 'sandbox_factory_stub.dart'
    if (dart.library.ffi) 'quickjs_sandbox.dart'
    if (dart.library.js_interop) 'worker_sandbox.dart';

/// Where scripts run: an isolated JavaScript engine that has run the script
/// driver (see `script_driver.dart`).
///
/// On Android, iOS, macOS and Linux it is QuickJS, through the
/// `codelessly_quickjs` package; on the web it is a Web Worker. Both speak
/// the driver's protocol: a run's state comes back as a map with `status`
/// (`waiting`, `done` or `error`), the `events` it produced (variable
/// writes and host calls), its `logs`, and its `value` or `error`.
abstract class ScriptSandbox {
  /// The sandbox for this platform.
  static ScriptSandbox get instance => _instance ??= createPlatformSandbox();
  static ScriptSandbox? _instance;

  /// Replaces the platform sandbox, e.g. in tests.
  static set instance(ScriptSandbox sandbox) => _instance = sandbox;

  /// Whether runs can complete synchronously, so formulas can call scripts
  /// directly. True for QuickJS; false for the web, where a formula gets a
  /// script's result once it arrives.
  bool get isSynchronous;

  /// Starts a run described by [request] (see the driver's `__cl_start`)
  /// and returns its state once it waits on the host or ends.
  ///
  /// [cpuBudget] is how long the script may compute before it is stopped
  /// with a `LimitError`.
  FutureOr<Map<String, Object?>> start(
    Map<String, Object?> request, {
    required Duration cpuBudget,
    required int memoryLimit,
  });

  /// Delivers host call [responses] to the run [run] and returns its next
  /// state. [vars], when given, replaces the variables the run reads: what
  /// they are now, after the run's own writes and other actions' changes.
  FutureOr<Map<String, Object?>> resume(
    String run,
    List<Map<String, Object?>> responses, {
    required Duration cpuBudget,
    Map<String, Object?>? vars,
  });

  /// Compiles [source] (a script with params [paramNames]) without running
  /// it. Returns null when it compiles, else the error: `{type, message,
  /// line?, column?}`.
  FutureOr<Map<String, Object?>?> check(String source, List<String> paramNames);

  /// Ends [run] and frees what it holds. A run that ended by itself is
  /// already freed.
  void end(String run);
}

/// Thrown when there is no script engine on this platform.
class ScriptEngineUnavailable implements Exception {
  /// Why.
  final String message;

  /// Creates a [ScriptEngineUnavailable].
  const ScriptEngineUnavailable(this.message);

  @override
  String toString() => message;
}
