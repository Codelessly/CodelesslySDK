import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import '../script_driver.dart';
import 'script_sandbox.dart';

/// QuickJS on Android, iOS, macOS and Linux.
ScriptSandbox createPlatformSandbox() => QuickJsSandbox();

final class _Cljs extends Opaque {}

typedef _NewC = Pointer<_Cljs> Function(Int64, Int64);
typedef _NewD = Pointer<_Cljs> Function(int, int);
typedef _FreeC = Void Function(Pointer<_Cljs>);
typedef _FreeD = void Function(Pointer<_Cljs>);
typedef _EvalC = Pointer<Uint8> Function(
  Pointer<_Cljs>,
  Pointer<Uint8>,
  Int64,
  Pointer<Uint8>,
  Int64,
);
typedef _EvalD = Pointer<Uint8> Function(
  Pointer<_Cljs>,
  Pointer<Uint8>,
  int,
  Pointer<Uint8>,
  int,
);
typedef _CallC = Pointer<Uint8> Function(
  Pointer<_Cljs>,
  Pointer<Uint8>,
  Pointer<Uint8>,
  Int64,
  Int64,
);
typedef _CallD = Pointer<Uint8> Function(
  Pointer<_Cljs>,
  Pointer<Uint8>,
  Pointer<Uint8>,
  int,
  int,
);
typedef _MemC = Int64 Function(Pointer<_Cljs>);
typedef _MemD = int Function(Pointer<_Cljs>);
typedef _AllocC = Pointer<Uint8> Function(Int64);
typedef _AllocD = Pointer<Uint8> Function(int);
typedef _PtrC = Void Function(Pointer<Uint8>);
typedef _PtrD = void Function(Pointer<Uint8>);
typedef _VersionC = Pointer<Uint8> Function();

/// The functions of the `codelessly_quickjs` native library.
class QuickJsLibrary {
  final _NewD _new;
  final _FreeD _free;
  final _EvalD _eval;
  final _CallD _call;
  final _MemD _memoryUsed;
  final _AllocD _alloc;
  final _PtrD _dealloc;
  final _PtrD _freeString;

  /// The QuickJS version, e.g. `2025-04-26`.
  final String version;

  QuickJsLibrary._(DynamicLibrary lib)
    : _new = lib.lookupFunction<_NewC, _NewD>('cljs_new'),
      _free = lib.lookupFunction<_FreeC, _FreeD>('cljs_free'),
      _eval = lib.lookupFunction<_EvalC, _EvalD>('cljs_eval'),
      _call = lib.lookupFunction<_CallC, _CallD>('cljs_call'),
      _memoryUsed = lib.lookupFunction<_MemC, _MemD>('cljs_memory_used'),
      _alloc = lib.lookupFunction<_AllocC, _AllocD>('cljs_alloc'),
      _dealloc = lib.lookupFunction<_PtrC, _PtrD>('cljs_dealloc'),
      _freeString = lib.lookupFunction<_PtrC, _PtrD>('cljs_free_string'),
      version = _readC(
        lib.lookupFunction<_VersionC, _VersionC>('cljs_version')(),
      );

  static QuickJsLibrary? _instance;

  /// A path to load the library from instead of the plugin's, e.g. a build
  /// for tests (see `tool/build_quickjs.sh`).
  static String? libraryPath;

  /// Loads the library: from [libraryPath] or `CODELESSLY_QUICKJS_LIBRARY`
  /// when set (tests), else from where the `codelessly_quickjs` Flutter
  /// plugin puts it.
  static QuickJsLibrary load() {
    final QuickJsLibrary? loaded = _instance;
    if (loaded != null) return loaded;
    final String? override =
        libraryPath ?? Platform.environment['CODELESSLY_QUICKJS_LIBRARY'];
    final List<DynamicLibrary Function()> candidates = [
      if (override != null && override.isNotEmpty)
        () => DynamicLibrary.open(override),
      if (Platform.isAndroid || Platform.isLinux)
        () => DynamicLibrary.open('libcodelessly_quickjs.so'),
      if (Platform.isIOS || Platform.isMacOS) ...[
        () => DynamicLibrary.open(
          'codelessly_quickjs.framework/codelessly_quickjs',
        ),
        DynamicLibrary.process,
      ],
      if (Platform.isWindows)
        () => DynamicLibrary.open('codelessly_quickjs.dll'),
    ];
    final List<String> errors = [];
    for (final DynamicLibrary Function() open in candidates) {
      try {
        final DynamicLibrary lib = open();
        if (!lib.providesSymbol('cljs_new')) continue;
        return _instance = QuickJsLibrary._(lib);
      } on Object catch (e) {
        errors.add('$e');
      }
    }
    throw ScriptEngineUnavailable(
      'The script engine is missing. Add the codelessly_quickjs package to the app '
      '(flutter pub add codelessly_quickjs) to run scripts on this platform.'
      '${errors.isEmpty ? '' : ' (${errors.join('; ')})'}',
    );
  }

  static String _readC(Pointer<Uint8> p) {
    if (p == nullptr) return '';
    int n = 0;
    while (p[n] != 0) {
      n++;
    }
    return utf8.decode(p.asTypedList(n));
  }

  Pointer<Uint8> _string(String s) {
    final Uint8List bytes = utf8.encode(s);
    final Pointer<Uint8> p = _alloc(bytes.length + 1);
    final Uint8List view = p.asTypedList(bytes.length + 1);
    view.setAll(0, bytes);
    view[bytes.length] = 0;
    return p;
  }

  String? _take(Pointer<Uint8> p) {
    if (p == nullptr) return null;
    final String s = _readC(p);
    _freeString(p);
    return s;
  }
}

/// One isolated QuickJS runtime with the driver loaded.
class QuickJsContext {
  final QuickJsLibrary _lib;
  Pointer<_Cljs> _handle;

  QuickJsContext._(this._lib, this._handle);

  /// Creates a runtime limited to [memoryLimit] bytes and evaluates the
  /// driver in it. Throws a [StateError] with the driver's error if it
  /// fails.
  factory QuickJsContext.create(
    QuickJsLibrary lib, {
    required int memoryLimit,
  }) {
    final Pointer<_Cljs> handle = lib._new(memoryLimit, 512 * 1024);
    if (handle == nullptr) {
      throw StateError('Could not create a JavaScript runtime');
    }
    final QuickJsContext context = QuickJsContext._(lib, handle);
    final String? error = context.eval(scriptDriver, 'driver.js');
    if (error != null) {
      context.dispose();
      throw StateError('The script driver failed to load: $error');
    }
    return context;
  }

  /// Evaluates [code]; returns null, or the error as JSON.
  String? eval(String code, String filename, {Duration? timeout}) {
    final Uint8List bytes = utf8.encode(code);
    final Pointer<Uint8> src = _lib._alloc(bytes.length + 1);
    src.asTypedList(bytes.length + 1)
      ..setAll(0, bytes)
      ..[bytes.length] = 0;
    final Pointer<Uint8> name = _lib._string(filename);
    try {
      return _lib._take(
        _lib._eval(
          _handle,
          src,
          bytes.length,
          name,
          timeout?.inMilliseconds ?? 0,
        ),
      );
    } finally {
      _lib._dealloc(src);
      _lib._dealloc(name);
    }
  }

  /// Calls the global function [function] with [argument] and runs the
  /// jobs it queued. Returns its result, or throws a [QuickJsException].
  String call(String function, String argument, {Duration? timeout}) {
    final Uint8List bytes = utf8.encode(argument);
    final Pointer<Uint8> arg = _lib._alloc(bytes.length + 1);
    arg.asTypedList(bytes.length + 1)
      ..setAll(0, bytes)
      ..[bytes.length] = 0;
    final Pointer<Uint8> name = _lib._string(function);
    try {
      final String out =
          _lib._take(
            _lib._call(
              _handle,
              name,
              arg,
              bytes.length,
              timeout == null ? 0 : timeout.inMilliseconds.clamp(1, 1 << 40),
            ),
          ) ??
          '';
      if (out.isNotEmpty && out.codeUnitAt(0) == 1) {
        throw QuickJsException(
          (jsonDecode(out.substring(1)) as Map).cast<String, Object?>(),
        );
      }
      return out;
    } finally {
      _lib._dealloc(arg);
      _lib._dealloc(name);
    }
  }

  /// Bytes the runtime's heap uses.
  int get memoryUsed => _lib._memoryUsed(_handle);

  /// Frees the runtime.
  void dispose() {
    if (_handle == nullptr) return;
    _lib._free(_handle);
    _handle = nullptr;
  }
}

/// An exception JavaScript threw out of a host-called function, or a limit.
class QuickJsException implements Exception {
  /// `{name, message, stack, limit?}`.
  final Map<String, Object?> error;

  /// Creates a [QuickJsException].
  const QuickJsException(this.error);

  @override
  String toString() => '${error['name']}: ${error['message']}';
}

/// Runs scripts in QuickJS runtimes.
///
/// A runtime that has loaded the driver is kept and reused by the next run,
/// which saves loading the driver each time (about 5 ms). Runs can't affect
/// each other through it: the driver froze every intrinsic and the global
/// object, and a run's own objects are unreachable once it ends. A runtime
/// that hit a limit, or holds more than a quarter of its memory limit after
/// a run, is thrown away instead.
class QuickJsSandbox implements ScriptSandbox {
  final Map<String, (QuickJsContext, Stopwatch)> _runs = {};

  /// Idle runtimes, by memory limit.
  final Map<int, List<QuickJsContext>> _idle = {};

  /// The most idle runtimes kept per memory limit.
  static const int maxIdle = 2;

  final Map<String, int> _limits = {};

  @override
  bool get isSynchronous => true;

  @override
  Map<String, Object?> start(
    Map<String, Object?> request, {
    required Duration cpuBudget,
    required int memoryLimit,
  }) {
    final String run = request['run'] as String;
    final List<QuickJsContext>? idle = _idle[memoryLimit];
    final QuickJsContext context = idle != null && idle.isNotEmpty
        ? idle.removeLast()
        : QuickJsContext.create(
            QuickJsLibrary.load(),
            memoryLimit: memoryLimit,
          );
    _limits[run] = memoryLimit;
    final Stopwatch cpu = Stopwatch();
    _runs[run] = (context, cpu);
    return _step(
      run,
      () => context.call(
        '__cl_start',
        jsonEncode(request),
        timeout: _remaining(cpuBudget, cpu),
      ),
      cpuBudget,
    );
  }

  @override
  Map<String, Object?> resume(
    String run,
    List<Map<String, Object?>> responses, {
    required Duration cpuBudget,
  }) {
    final (QuickJsContext, Stopwatch)? entry = _runs[run];
    if (entry == null) {
      return {
        'run': run,
        'status': 'error',
        'error': {'type': 'Error', 'message': 'The run has ended.'},
      };
    }
    final (QuickJsContext context, Stopwatch cpu) = entry;
    return _step(
      run,
      () => context.call(
        '__cl_resume',
        jsonEncode({'run': run, 'responses': responses}),
        timeout: _remaining(cpuBudget, cpu),
      ),
      cpuBudget,
    );
  }

  Duration _remaining(Duration budget, Stopwatch cpu) {
    final Duration left = budget - cpu.elapsed;
    return left > const Duration(milliseconds: 1)
        ? left
        : const Duration(milliseconds: 1);
  }

  Map<String, Object?> _step(
    String run,
    String Function() call,
    Duration budget,
  ) {
    final (QuickJsContext context, Stopwatch cpu) = _runs[run]!;
    Map<String, Object?> state;
    cpu.start();
    try {
      call();
      state = (jsonDecode(
        context.call('__cl_state', run, timeout: _remaining(budget, cpu)),
      ) as Map).cast<String, Object?>();
    } on QuickJsException catch (e) {
      state = {
        'run': run,
        'status': 'error',
        'error': _limitError(e.error, budget),
      };
    } finally {
      cpu.stop();
    }
    // The engine reports a limit it hit as an InternalError the script
    // couldn't catch; it's a LimitError for the app.
    final Object? error = state['error'];
    bool hitLimit = false;
    if (error is Map && error['type'] == 'InternalError') {
      final Object? limit = switch (error['message']) {
        'interrupted' => 'time',
        'out of memory' => 'memory',
        'stack overflow' => 'depth',
        _ => null,
      };
      if (limit != null) {
        hitLimit = true;
        state['error'] = _limitError({'limit': limit}, budget);
      }
    } else if (error is Map && error['type'] == 'LimitError') {
      hitLimit = true;
    }
    state['memory'] = context.memoryUsed;
    state['cpuMs'] = cpu.elapsedMicroseconds / 1000;
    if (state['status'] != 'waiting') _finish(run, reuse: !hitLimit);
    return state;
  }

  void _finish(String run, {required bool reuse}) {
    final (QuickJsContext, Stopwatch)? entry = _runs.remove(run);
    final int? limit = _limits.remove(run);
    if (entry == null) return;
    final QuickJsContext context = entry.$1;
    final List<QuickJsContext> idle = _idle.putIfAbsent(limit ?? 0, () => []);
    if (reuse &&
        limit != null &&
        idle.length < maxIdle &&
        context.memoryUsed < limit ~/ 4) {
      idle.add(context);
    } else {
      context.dispose();
    }
  }

  Map<String, Object?> _limitError(Map<String, Object?> e, Duration budget) {
    final Object? limit = e['limit'];
    return switch (limit) {
      'time' => {
        'type': 'LimitError',
        'limit': 'time',
        'message':
            'The script ran longer than ${budget.inMilliseconds} ms. Is there an endless loop?',
      },
      'memory' => {
        'type': 'LimitError',
        'limit': 'memory',
        'message': 'The script used more memory than it is allowed.',
      },
      'depth' => {
        'type': 'LimitError',
        'limit': 'depth',
        'message': 'Functions called each other too deeply. Is there an endless recursion?',
      },
      _ => {
        'type': e['name'] ?? 'Error',
        'message': e['message'] ?? 'The script failed',
      },
    };
  }

  @override
  void end(String run) {
    // A run ended early (cancelled while waiting): its pending promises may
    // still reference its objects, so its runtime isn't reused.
    _finish(run, reuse: false);
  }
}
