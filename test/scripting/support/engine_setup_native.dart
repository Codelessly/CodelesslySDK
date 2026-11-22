import 'dart:io';

import 'package:codelessly_sdk/src/scripting/sandbox/quickjs_sandbox.dart';

final String _path =
    '${Directory.current.path}/.dart_tool/codelessly_quickjs/libcodelessly_quickjs.${Platform.isMacOS ? 'dylib' : 'so'}';

/// Why the tests that run scripts cannot run on this machine, or null when
/// they can: the test build of QuickJS (`tool/build_quickjs.sh`) is for
/// Linux and macOS, and needs CMake with a C compiler where it is not
/// built yet.
final String? scriptEngineUnavailable = () {
  if (File(_path).existsSync()) return null;
  if (!Platform.isLinux && !Platform.isMacOS) {
    return 'QuickJS for the tests is built on Linux and macOS only (tool/build_quickjs.sh): '
        'not on ${Platform.operatingSystem}';
  }
  try {
    if (Process.runSync('cmake', ['--version']).exitCode == 0) return null;
  } on ProcessException {
    // No cmake.
  }
  return 'QuickJS for the tests is not built and cannot be here: tool/build_quickjs.sh needs CMake and a C compiler';
}();

/// Points the SDK at a QuickJS build for this machine, building it with
/// `tool/build_quickjs.sh` (CMake and a C compiler) when it's missing.
void setUpScriptEngine() {
  final String path = _path;
  // Flutter runs suites in separate processes. Serialize their first build
  // so concurrent CMake configurations cannot corrupt the shared cache.
  Directory(File(path).parent.path).createSync(recursive: true);
  final lock = File('$path.lock').openSync(mode: FileMode.append);
  try {
    lock.lockSync(FileLock.blockingExclusive);
    if (!File(path).existsSync()) {
      final ProcessResult r = Process.runSync('bash', ['tool/build_quickjs.sh']);
      if (r.exitCode != 0) {
        throw StateError(
          'Could not build QuickJS for the tests:\n${r.stdout}\n${r.stderr}',
        );
      }
    }
  } finally {
    lock.unlockSync();
    lock.closeSync();
  }
  QuickJsLibrary.libraryPath = path;
}

/// The engine the tests run on.
const String scriptEngineName = 'quickjs';
