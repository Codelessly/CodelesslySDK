// What the toolkit's commands share: arguments, the SDK's folders, running the render command.
import 'dart:convert';
import 'dart:io';

/// A mistake in how a command was called: printed, exit status 2.
class UsageError implements Exception {
  const UsageError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Prints [doc] and returns the exit status for a call that asked for help (0) or gave nothing (2).
int usage(String doc, {bool asked = true}) {
  stdout.writeln(doc);
  return asked ? 0 : 2;
}

/// Command-line arguments: `--flag`, `--option value` (the options in [valued], repeatable), positionals.
class Args {
  Args(List<String> argv, {Set<String> valued = const {}}) {
    for (var i = 0; i < argv.length; i++) {
      final a = argv[i];
      if (a == '-h' || a == '--help') {
        help = true;
      } else if (valued.contains(a)) {
        if (i + 1 >= argv.length) throw UsageError('$a needs a value.');
        (options[a] ??= []).add(argv[++i]);
      } else if (a.startsWith('--')) {
        flags.add(a);
      } else {
        positional.add(a);
      }
    }
  }

  bool help = false;
  final List<String> positional = [];
  final Set<String> flags = {};
  final Map<String, List<String>> options = {};

  String? operator [](String option) => options[option]?.last;
  List<String> all(String option) => options[option] ?? const [];
  bool has(String flag) => flags.contains(flag);
}

(int, int) parseSize(String s) {
  final m = RegExp(r'^\s*(\d+)x(\d+)\s*$').firstMatch(s.toLowerCase());
  if (m == null) throw UsageError('Bad size "$s": write WIDTHxHEIGHT, e.g. 390x844.');
  return (int.parse(m[1]!), int.parse(m[2]!));
}

/// The SDK checkout this toolkit belongs to: `$CODELESSLY_SDK` (set by tool/codelessly), else found from the
/// script's own place, else the working directory's.
final Directory sdkRoot = () {
  final env = Platform.environment['CODELESSLY_SDK'];
  if (env != null && env.isNotEmpty) return Directory(env);
  // From source (dart run tool/cli/codelessly.dart): tool/cli/ is two folders down.
  final script = File.fromUri(Platform.script);
  for (var d = script.parent; d.path != d.parent.path; d = d.parent) {
    if (File('${d.path}/tool/render/render.sh').existsSync()) return d;
  }
  return Directory.current;
}();

String get renderScript => '${sdkRoot.path}/tool/render/render.sh';
String get serveScript => '${sdkRoot.path}/tool/render/serve.sh';

/// Runs a command; returns its exit status and its stdout and stderr together, as the person would read them.
Future<(int, String)> runCaptured(String exe, List<String> args, {String? cwd, Duration? timeout}) async {
  final script = Platform.isWindows && exe.endsWith('.sh');
  final p = await Process.start(script ? 'bash' : exe, script ? [exe, ...args] : args, workingDirectory: cwd);
  final out = StringBuffer();
  final done = Future.wait([
    p.stdout.transform(utf8.decoder).forEach(out.write),
    p.stderr.transform(utf8.decoder).forEach(out.write),
  ]);
  final code = timeout == null ? await p.exitCode : await p.exitCode.timeout(timeout, onTimeout: () {
    p.kill();
    return 124;
  });
  await done;
  return (code, out.toString());
}

/// Runs a command with this process's terminal: its output shows as it comes.
Future<int> runInherited(String exe, List<String> args, {String? cwd}) async {
  // Windows cannot start a shell script: bash runs it.
  final script = Platform.isWindows && exe.endsWith('.sh');
  final p = await Process.start(script ? 'bash' : exe, script ? [exe, ...args] : args, workingDirectory: cwd, mode: ProcessStartMode.inheritStdio);
  return p.exitCode;
}

/// [path] made absolute against [base] (the working directory by default).
String absolute(String path, [String? base]) {
  if (path.startsWith('/') || RegExp(r'^[A-Za-z]:[\\/]').hasMatch(path)) return path;
  final b = base ?? Directory.current.path;
  return File('$b/$path').absolute.uri.normalizePath().toFilePath();
}

/// Pretty JSON, one space per level (as the toolkit's files are written).
String prettyJson(Object? value) => const JsonEncoder.withIndent(' ').convert(value);

Object? readJson(String path) => jsonDecode(File(path).readAsStringSync());
