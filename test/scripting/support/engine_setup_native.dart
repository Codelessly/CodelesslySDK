import 'dart:io';

import 'package:codelessly_sdk/src/scripting/sandbox/quickjs_sandbox.dart';

/// Points the SDK at a QuickJS build for this machine, building it with
/// `tool/build_quickjs.sh` (CMake and a C compiler) when it's missing.
void setUpScriptEngine() {
  final String ext = Platform.isMacOS ? 'dylib' : 'so';
  final String path =
      '${Directory.current.path}/.dart_tool/codelessly_quickjs/libcodelessly_quickjs.$ext';
  // Test files use separate Flutter processes. Serialize cold builds and recheck
  // under the lock, so one process cannot replace a library another is loading.
  final cache = Directory(
    '${Directory.current.path}/.dart_tool/codelessly_quickjs',
  )..createSync(recursive: true);
  final lock = File('${cache.path}/build.lock').openSync(mode: FileMode.append);
  var locked = false;
  try {
    lock.lockSync(FileLock.exclusive);
    locked = true;
    if (!File(path).existsSync()) {
      final ProcessResult r = Process.runSync('bash', [
        'tool/build_quickjs.sh',
      ]);
      if (r.exitCode != 0) {
        throw StateError(
          'Could not build QuickJS for the tests:\n${r.stdout}\n${r.stderr}',
        );
      }
    }
  } finally {
    if (locked) lock.unlockSync();
    lock.closeSync();
  }

  QuickJsLibrary.libraryPath = path;
}

/// The engine the tests run on.
const String scriptEngineName = 'quickjs';
