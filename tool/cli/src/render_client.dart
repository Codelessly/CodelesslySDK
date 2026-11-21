// The render command as tool/codelessly runs it: a request to the render server (tool/render/serve.sh) when it is
// up and serves this code, made from this process, with no shell in between; else tool/render/render.sh, as before.
//
// render.sh makes the same request from bash, which on Windows costs about three seconds of process starts (every
// `$(...)`, `cat`, `sed` and `git` is one) before the server is asked anything. Here the arguments are prepared as
// render.sh prepares them (prepareRenderArgs), the server's code is checked against its sources (serverIsCurrent),
// the line that names the versions is read from a cache kept until a commit or a pubspec changes (versionLine), and
// the request goes over the server's socket (build/.render-server/port), answered the moment the run ends. What is
// printed, written and returned is render.sh's: the same first line on stderr, the same report on stdout, the same
// exit status, the same files.
//
// Whatever this cannot do as render.sh does (a path only bash can read, no server, a server that serves older code,
// a server that stops during the run) is left to render.sh itself, with the arguments as they were given.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'common.dart';

/// Whether the phases' times are printed (`--timings`, or CODELESSLY_TIMINGS set to anything but 0).
bool timingsAsked(List<String> args) =>
    args.contains('--timings') || !const {'', '0'}.contains(Platform.environment['CODELESSLY_TIMINGS'] ?? '');

/// When tool/codelessly started (it says so in CODELESSLY_STARTED, seconds since the epoch), else this process.
final DateTime commandStarted = () {
  final s = double.tryParse((Platform.environment['CODELESSLY_STARTED'] ?? '').replaceAll(',', '.'));
  return s == null ? DateTime.now() : DateTime.fromMicrosecondsSinceEpoch((s * 1000000).round());
}();

/// The command's own phases (the render's are the server's): `start 40 ms, checks 12 ms, ...; total 600 ms`.
class CommandTimings {
  final List<(String, int)> _phases = [];
  DateTime _last = commandStarted;

  /// The time since the last lap (first: since the command started) is [phase]'s.
  void lap(String phase) {
    final now = DateTime.now();
    _phases.add((phase, now.difference(_last).inMicroseconds));
    _last = now;
  }

  String get line => '${[for (final (name, us) in _phases) '$name ${(us / 1000).round()} ms'].join(', ')}; '
      'total ${DateTime.now().difference(commandStarted).inMilliseconds} ms';
}

/// The render command with this process's terminal: the report on stdout, the rest on stderr. Its exit status.
Future<int> renderInherited(List<String> args, {CommandTimings? timings}) async {
  final code = await _viaServer(args, stdout, stderr, timings);
  if (code != null) return code;
  final status = await runInherited(renderScript, args);
  timings?.lap('render.sh');
  return status;
}

/// The render command; its exit status and what it printed (stdout and stderr together).
Future<(int, String)> renderCaptured(List<String> args) async {
  final text = StringBuffer();
  final code = await _viaServer(args, text, text, null);
  if (code != null) return (code, '$text');
  final (status, rest) = await runCaptured(renderScript, args);
  return (status, '$text$rest');
}

/// The options whose value is a path (render.sh's list).
const _pathOptions = {'--out', '--fonts', '--slots', '--compare', '--sheet', '--sheet-base', '--pick-file'};

/// The options whose value is not a path, when it does not start with `--` (render.sh's list).
final _valueOptions = RegExp(r'^--(sizes|screen|tap|double-tap|long-press|right-click|wheel|pinch|hover|focus|key|type|set|stage|scroll|drag|'
    r'navigate|wait|frames|now|clock|insets|text-scale|keyboard|screen-timeout|label|state|component|props|theme|compare-map|sheet-height|'
    r'sheet-columns|sheet-title)$');

/// What render.sh makes of its command line: the harness's arguments (paths absolute), `--out`, the design system
/// `--design-system` names and whether `--timings` was among them.
typedef PreparedRender = ({List<String> args, String? out, String? designSystem, bool timings});

/// The arguments as render.sh hands them to the harness, or null when a path is one only bash can read (a POSIX
/// path on Windows that is not a drive's).
PreparedRender? prepareRenderArgs(List<String> argv, {String? cwd, bool? windows}) {
  final onWindows = windows ?? Platform.isWindows;
  final here = cwd ?? (onWindows ? Directory.current.path : (Platform.environment['PWD'] ?? Directory.current.path));
  String? abs(String p) {
    if (!(p.startsWith('/') || RegExp(r'^[A-Za-z]:[/\\]').hasMatch(p))) p = '$here/$p';
    return onWindows ? mixedPath(p) : p;
  }

  final args = <String>[];
  String? out, designSystem;
  var expectPath = false, wantDesignSystem = false, timings = false;
  var prev = '';
  for (var a in argv) {
    if (wantDesignSystem) {
      final p = abs(a);
      if (p == null) return null;
      designSystem = p;
      wantDesignSystem = false;
      continue;
    }
    if (expectPath) {
      // `--fonts system` names the system's font directories, not a path.
      if (prev != '--fonts' || a != 'system') {
        final p = abs(a);
        if (p == null) return null;
        a = p;
      }
      expectPath = false;
      args.add(a);
      if (prev == '--out') out = a;
      prev = '';
      continue;
    }
    if (a == '--timings') {
      timings = true;
    } else if (_pathOptions.contains(a)) {
      expectPath = true;
      prev = a;
      args.add(a);
    } else if (a == '--design-system') {
      wantDesignSystem = true;
    } else if (a.startsWith('--')) {
      args.add(a);
    } else if (args.isNotEmpty && args.last == '--image-map') {
      // <url prefix>=<folder>: the folder after the last "=", made absolute; a table (a .json file) is a path too.
      final eq = a.lastIndexOf('=');
      final dir = abs(eq < 0 ? a : a.substring(eq + 1));
      var key = eq < 0 ? a : a.substring(0, eq);
      if (dir == null) return null;
      if (key.endsWith('.json')) {
        final k = abs(key);
        if (k == null) return null;
        key = k;
      }
      args.add('$key=$dir');
    } else if (args.isNotEmpty && _valueOptions.hasMatch(args.last)) {
      // A positional argument right after a value-taking option is that option's value.
      args.add(a);
    } else {
      final p = abs(a);
      if (p == null) return null;
      args.add(p);
    }
  }
  return (args: args, out: out, designSystem: designSystem, timings: timings);
}

/// [p] as `cygpath -m` writes it (what Dart reads on Windows): `C:/Users/x`, the drive's letter a capital, `.`,
/// `..` and doubled separators worked out, a separator at the end kept. `/c/Users/x` is drive C's. Null for a
/// POSIX path that is not a drive's (`/tmp/x`: only the shell knows where that is) or a network path.
String? mixedPath(String p) {
  final String drive, rest;
  if (RegExp(r'^[A-Za-z]:[/\\]').hasMatch(p)) {
    drive = p[0];
    rest = p.substring(2);
  } else if (RegExp(r'^/[A-Za-z](/|$)').hasMatch(p)) {
    drive = p[1];
    rest = p.substring(2);
  } else {
    return null;
  }
  final parts = <String>[];
  for (final s in rest.split(RegExp(r'[/\\]+'))) {
    if (s.isEmpty || s == '.') continue;
    if (s == '..') {
      if (parts.isNotEmpty) parts.removeLast();
    } else {
      parts.add(s);
    }
  }
  final tail = parts.isNotEmpty && RegExp(r'[/\\]$').hasMatch(rest) ? '/' : '';
  return '${drive.toUpperCase()}:/${parts.join('/')}$tail';
}

/// The sibling codelessly_api checkout (tool/lib/env.sh's codelessly_find_api): `$CODELESSLY_API`, else
/// ../CodelesslyAPI or ../codelessly_api beside the SDK; null when there is none.
String? siblingApi(String sdk) {
  for (final d in [Platform.environment['CODELESSLY_API'] ?? '', '$sdk/../CodelesslyAPI', '$sdk/../codelessly_api']) {
    if (d.isEmpty) continue;
    final pubspec = File('$d/pubspec.yaml');
    if (pubspec.existsSync() && pubspec.readAsLinesSync().any((l) => l.startsWith('name: codelessly_api'))) return d;
  }
  return null;
}

/// Whether nothing the render server runs changed since it started: no file or folder of the SDK's lib/ and
/// tool/render/, its pubspecs, the server itself (tool/cli/src/pool.dart), or the sibling API's lib/ and pubspec is newer than its `ready` file (render.sh's
/// `find ... -newer`).
bool serverIsCurrent(String sdk, String? api, File ready) {
  final DateTime since;
  try {
    since = ready.statSync().modified;
  } on FileSystemException {
    return false;
  }
  bool newer(String path) {
    final s = FileStat.statSync(path);
    return s.type != FileSystemEntityType.notFound && s.modified.isAfter(since);
  }

  for (final root in ['$sdk/lib', '$sdk/tool/render', if (api != null) '$api/lib']) {
    if (!Directory(root).existsSync()) continue;
    if (newer(root)) return false;
    for (final e in Directory(root).listSync(recursive: true, followLinks: false)) {
      if (newer(e.path)) return false;
    }
  }
  for (final f in ['$sdk/pubspec.yaml', '$sdk/pubspec_overrides.yaml', '$sdk/tool/cli/src/pool.dart', if (api != null) '$api/pubspec.yaml']) {
    if (newer(f)) return false;
  }
  return true;
}

/// What a checkout's `git rev-parse HEAD` and its branch depend on, read from its files: HEAD and the ref it names.
/// `-` for a folder that is no checkout's top; null when it cannot be told from the files (a reftable store).
String? _headState(String repo) {
  var git = '$repo/.git';
  if (FileSystemEntity.isFileSync(git)) {
    final m = RegExp(r'^gitdir:\s*(.+)$', multiLine: true).firstMatch(File(git).readAsStringSync());
    if (m == null) return null;
    final dir = m[1]!.trim();
    git = RegExp(r'^([A-Za-z]:[/\\]|/)').hasMatch(dir) ? dir : '$repo/$dir';
  } else if (!FileSystemEntity.isDirectorySync(git)) {
    // Inside another checkout, or none: git looks above, which these files do not say.
    return Directory(repo).parent.path == repo || !_insideCheckout(repo) ? '-' : null;
  }
  if (Directory('$git/reftable').existsSync()) return null;
  final headFile = File('$git/HEAD');
  if (!headFile.existsSync()) return null;
  final head = headFile.readAsStringSync().trim();
  if (!head.startsWith('ref: ')) return head;
  final ref = head.substring(5).trim();
  var common = git;
  final commonFile = File('$git/commondir');
  if (commonFile.existsSync()) {
    final c = commonFile.readAsStringSync().trim();
    common = RegExp(r'^([A-Za-z]:[/\\]|/)').hasMatch(c) ? c : '$git/$c';
  }
  for (final dir in {git, common}) {
    final loose = File('$dir/$ref');
    if (loose.existsSync()) return '$head ${loose.readAsStringSync().trim()}';
  }
  final packed = File('$common/packed-refs');
  if (packed.existsSync()) {
    for (final l in packed.readAsLinesSync()) {
      if (l.endsWith(' $ref')) return '$head ${l.split(' ').first}';
    }
  }
  return '$head (unborn)';
}

bool _insideCheckout(String dir) {
  for (var d = Directory(dir).absolute; d.parent.path != d.path; d = d.parent) {
    if (FileSystemEntity.typeSync('${d.path}/.git') != FileSystemEntityType.notFound) return true;
  }
  return false;
}

/// `codelessly_sdk <version> @ <commit> on <branch> at <path>, codelessly_api ...`: tool/lib/env.sh's
/// codelessly_version_line, which costs a dozen process starts (two of them git's). It is kept in
/// build/.version-line with what it was made from (each checkout's HEAD and the ref it names, the pubspecs, the
/// overrides file, $CODELESSLY_API) and made again by tool/lib/version_line.sh only when one of those changed.
/// Null when it cannot be made (render.sh then says why).
Future<String?> versionLine(String sdk) async {
  String stamp(String path) {
    final s = FileStat.statSync(path);
    return s.type == FileSystemEntityType.notFound ? '-' : '${s.modified.microsecondsSinceEpoch}:${s.size}';
  }

  final key = StringBuffer('1\u0001${Platform.environment['CODELESSLY_API'] ?? ''}');
  for (final repo in [sdk, Platform.environment['CODELESSLY_API'] ?? '', '$sdk/../CodelesslyAPI', '$sdk/../codelessly_api']) {
    if (repo.isEmpty || !Directory(repo).existsSync()) {
      key.write('\u0001-');
      continue;
    }
    final head = _headState(repo);
    if (head == null) return _makeVersionLine(sdk);
    key.write('\u0001$head\u0001${stamp('$repo/pubspec.yaml')}\u0001${stamp('$repo/docs/reference/STARTER.md')}');
  }
  key.write('\u0001${stamp('$sdk/pubspec_overrides.yaml')}\u0001${stamp('$sdk/pubspec.lock')}');
  final cache = File('$sdk/build/.version-line');
  try {
    final kept = cache.readAsStringSync().split('\u0002');
    if (kept.length == 2 && kept[0] == '$key' && kept[1].isNotEmpty) return kept[1];
  } on FileSystemException {
    // None kept yet.
  }
  final line = await _makeVersionLine(sdk);
  if (line != null) {
    try {
      final tmp = File('${cache.path}.$pid.tmp')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('$key\u0002$line');
      tmp.renameSync(cache.path);
    } on FileSystemException {
      // Not kept: made again next time.
    }
  }
  return line;
}

Future<String?> _makeVersionLine(String sdk) async {
  final (code, text) = await runCaptured('$sdk/tool/lib/version_line.sh', const []);
  final line = text.trim();
  return code == 0 && line.startsWith('codelessly_sdk ') && !line.contains('\n') ? line : null;
}

/// `--design-system <folder>` with one document (render.sh's): the document is rendered as a site of its own, in
/// `<out>/.site`, that uses that design system. Returns what to tell and the exit status when it cannot be (2),
/// null when it was done ([args] then names the site), and throws [_LeftToTheScript] for what only the script does.
String? _designSystemSite(List<String> args, String out, String designSystem) {
  final doc = [for (var i = 0; i < args.length; i++) if (args[i].endsWith('.json') && File(args[i]).existsSync()) i].firstOrNull;
  if (doc == null || !File('$designSystem/design_system.json').existsSync()) {
    return '--design-system <folder> goes with one document (.json) and a folder that holds design_system.json.';
  }
  final site = Directory('$out/.site');
  if (site.existsSync()) site.deleteSync(recursive: true);
  site.createSync(recursive: true);
  final name = args[doc].split(RegExp(r'[/\\]')).last;
  File(args[doc]).copySync('${site.path}/$name');
  // The manifest names the design system relative to itself (realpath --relative-to: links resolved).
  List<String> parts(String p) => Directory(p).resolveSymbolicLinksSync().split(RegExp(r'[/\\]+')).where((s) => s.isNotEmpty).toList();
  final from = parts(site.path), to = parts(designSystem);
  if (Platform.isWindows && from.first.toLowerCase() != to.first.toLowerCase()) throw const _LeftToTheScript();
  var same = 0;
  while (same < from.length && same < to.length && (Platform.isWindows ? from[same].toLowerCase() == to[same].toLowerCase() : from[same] == to[same])) {
    same++;
  }
  final rel = [for (var i = same; i < from.length; i++) '..', ...to.skip(same)].join('/');
  File('${site.path}/site.json').writeAsStringSync('{"schema": 3, "pages": ["$name"], "designSystem": "${rel.isEmpty ? '.' : rel}"}\n');
  args[doc] = '$out/.site';
  return null;
}

class _LeftToTheScript implements Exception {
  const _LeftToTheScript();
}

/// The run as a request to the render server. Null when it is render.sh's to do (nothing printed, or what
/// render.sh says before it goes on to render the usual way); else the exit status.
Future<int?> _viaServer(List<String> argv, StringSink out, StringSink err, CommandTimings? timings) async {
  final sdk = sdkRoot.path.replaceAll(r'\', '/');
  final server = renderServerDir;
  final ready = File('$server/ready'), pidFile = File('$server/pid'), portFile = File('$server/port');
  if (!ready.existsSync() || !pidFile.existsSync() || !portFile.existsSync()) return null;
  final prepared = prepareRenderArgs(argv);
  if (prepared == null || prepared.out == null) return null;
  final args = prepared.args, outDir = prepared.out!;
  final sayTimings = prepared.timings || timingsAsked(const []);
  final api = siblingApi(sdk);
  if (!serverIsCurrent(sdk, api, ready)) return null;
  final version = await versionLine(sdk);
  if (version == null) return null;
  final String serverPid;
  final int port;
  final String token;
  try {
    serverPid = pidFile.readAsStringSync().trim();
    final at = portFile.readAsStringSync().trim().split(' ');
    port = int.parse(at[0]);
    token = at[1];
  } on Object {
    return null;
  }
  timings?.lap('checks');
  final Socket socket;
  try {
    socket = await Socket.connect(InternetAddress.loopbackIPv4, port, timeout: const Duration(seconds: 2));
  } on Object {
    return null; // Not up after all: render.sh sees the same and renders the usual way.
  }
  Directory? work;
  try {
    Directory(outDir).createSync(recursive: true);
    if (prepared.designSystem case final String ds) {
      try {
        final problem = _designSystemSite(args, outDir, ds);
        if (problem != null) {
          err.writeln(problem);
          return 2;
        }
      } on _LeftToTheScript {
        return null;
      }
    }
    work = Directory(outDir).createTempSync('.render.');
    final argsFile = '${work.path.replaceAll(r'\', '/')}/args';
    // One argument after another, each ended by a NUL: an argument may hold a newline.
    File(argsFile).writeAsStringSync(args.map((a) => '$a\u0000').join());
    err.writeln('Rendering with $version, the render server (pid $serverPid).');
    final answer = await askRender(socket, token, argsFile, onQueued: (place) {
      err.writeln('The render server\'s workers are all busy: this run waits its turn (place $place in the queue).');
    });
    final answered = answer == 'done';
    timings?.lap('render');
    if (answer != null && answer.startsWith('busy ')) {
      final at = answer.split(' ');
      err.writeln('The render server is busy: ${at[1]} runs wait already, which is its limit (tool/codelessly serve --queue <n> sets another). '
          'Not rendered: ask again in a moment.');
      return 2;
    }
    if (answer != null && answer.startsWith('failed ')) {
      err.writeln(answer.substring(7));
      return 2;
    }
    final retry = File('$argsFile.retry'), status = File('$argsFile.status');
    if (retry.existsSync()) {
      err.writeln('The render server had other files registered for fonts this run draws (${retry.readAsLinesSync().firstOrNull ?? ''}); '
          'it stopped. Rendering the usual way; tool/render/serve.sh starts it again.');
      await _serverGone(port, server);
      return null;
    }
    if (answered && status.existsSync()) {
      out.write(File('$argsFile.report').readAsStringSync());
      final spent = File('$argsFile.timings');
      if (sayTimings && spent.existsSync()) err.writeln('timings: render ${spent.readAsStringSync().trim()}');
      return int.tryParse(status.readAsStringSync().trim()) ?? 2;
    }
    err.writeln('The render server stopped during the run; rendering the usual way.');
    return null;
  } finally {
    socket.destroy();
    try {
      work?.deleteSync(recursive: true);
    } on FileSystemException {
      // Left behind: a dot folder in --out.
    }
  }
}

/// One render asked of the render server over [socket]: the arguments in [argsFile]. Returns its last word:
/// `done` (the report, the status and the timings are beside the arguments file), `busy <queued> <limit>` (its
/// queue is full: not rendered), `failed <why>`, or null when the server went away. [onQueued] is told the run's
/// place in the queue when it has to wait for a worker.
Future<String?> askRender(Socket socket, String token, String argsFile, {void Function(int place)? onQueued}) async {
  String? last;
  try {
    socket.setOption(SocketOption.tcpNoDelay, true);
    socket.write('$token run $argsFile\n');
    await socket.flush();
    await for (final line in utf8.decoder.bind(socket).transform(const LineSplitter())) {
      if (line.startsWith('queued ')) {
        onQueued?.call(int.tryParse(line.substring(7)) ?? 1);
      } else if (line.isNotEmpty) {
        last = line;
      }
    }
  } on Object {
    // The server went away: no word.
  }
  return last;
}

/// Waits (10 s at most) until the server that handed a run back no longer listens, then clears its folder, as
/// render.sh does before it renders the usual way.
Future<void> _serverGone(int port, String server) async {
  for (var i = 0; i < 100; i++) {
    try {
      (await Socket.connect(InternetAddress.loopbackIPv4, port, timeout: const Duration(milliseconds: 200))).destroy();
    } on Object {
      break;
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  try {
    Directory(server).deleteSync(recursive: true);
  } on FileSystemException {
    // serve.sh clears it when it starts.
  }
}
