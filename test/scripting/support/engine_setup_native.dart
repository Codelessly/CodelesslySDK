import 'dart:io';

import 'package:codelessly_sdk/src/scripting/sandbox/quickjs_sandbox.dart';

/// Points the SDK at a QuickJS build for this machine, building it with
/// `tool/build_quickjs.sh` (CMake and a C compiler) when it's missing.
void setUpScriptEngine() {
  final String ext = Platform.isMacOS ? 'dylib' : 'so';
  final String path =
      '${Directory.current.path}/.dart_tool/codelessly_quickjs/libcodelessly_quickjs.$ext';
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
