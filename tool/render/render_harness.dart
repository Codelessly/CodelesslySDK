// The render command's entry point, run by render.sh under `flutter test`
// (headless: no device, real fonts loaded from files). Reads its arguments
// from the file CODELESSLY_RENDER_ARGS names (each ended by a NUL, so one may
// hold a newline: [argsFromFile]) and writes the
// report next to the PNGs; render.sh prints it and exits with its status.
//
// With CODELESSLY_RENDER_SERVE=<dir> it serves instead: it stays up and renders each request dropped in
// <dir> (a `<id>.req` file holding the path of an arguments file, as above),
// one after another, writing that file's `.report` and `.status`. A run then
// costs the rendering alone, not Flutter's start (about 5 s). It writes
// <dir>/ready once it takes requests, and stops when <dir>/stop appears or no
// request came for CODELESSLY_RENDER_IDLE seconds (default 1800). It also
// listens on a socket of this machine (<dir>/port: the port and a token): a
// line `<token> <arguments file>` is a request, answered `done` when the run
// is over, so the caller neither looks for request files nor waits in steps.
//
// The render server (tool/render/serve.sh, tool/cli/src/pool.dart) runs several of these, each a worker in a
// process of its own (CODELESSLY_RENDER_WORKER names it), and hands them requests over that socket in two more
// forms: `<token> lead <arguments file>` (render the request, with whatever other workers the server sends to
// help, and write its report) and `<token> help <arguments file>` (render captures of a request another worker
// leads). src/fan.dart describes how the workers of one request share it. A third, `<token> solo <arguments file>`, is a
// request of one capture, which nobody can help with: it is rendered as a run of its own, with no shared folder.
// Those are answered with one line,
// `<verdict> <resident bytes> <captures rendered>[ bye]`: `done` (the report is written), `yield` (the server
// asked this worker to make way: the request goes on later, from where it is), `left` (a helper has no more to
// do) or `retry` (this worker has another file registered for a font the request draws: another worker must
// render it); `bye` when the worker takes no further request.
//
// Every run also writes `<arguments file>.timings`: where its time went, one
// line (src/timings.dart), which the command prints with --timings.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'src/args.dart';
import 'src/fan.dart';
import 'src/fonts.dart';
import 'src/google_fonts.dart' show renderUsesGoogleFonts;
import 'src/sheet.dart';
import 'src/render.dart';
import 'src/timings.dart';

void main() {
  final argsFile = Platform.environment['CODELESSLY_RENDER_ARGS'];
  final serveDir = Platform.environment['CODELESSLY_RENDER_SERVE'];
  // The command draws a family no file provides from Google Fonts (cached).
  renderUsesGoogleFonts = true;
  testWidgets('render', (tester) async {
    if (serveDir != null) return _serve(tester, serveDir);
    if (argsFile == null) return; // Not run by render.sh.
    await _renderOne(tester, argsFile);
  }, timeout: serveDir != null ? Timeout.none : const Timeout(Duration(minutes: 20)));
}

/// One run: the arguments in [argsFile]; its report and exit status beside it.
Future<void> _renderOne(WidgetTester tester, String argsFile) async {
  final lines = argsFromFile(File(argsFile).readAsStringSync());
  final status = File('$argsFile.status');
  // Where the run's time went (src/timings.dart), written beside the report before the status (which says the
  // run is over): the command prints it with --timings or CODELESSLY_TIMINGS=1.
  final timings = RenderTimings.current = RenderTimings();
  try {
    await _renderRuns(tester, lines, argsFile, status);
  } finally {
    File('$argsFile.timings').writeAsStringSync('${timings.line}\n');
    final last = File('$argsFile.status.tmp');
    if (last.existsSync()) last.renameSync(status.path);
  }
}

/// The runs of one command. The status is written as `.status.tmp`; [_renderOne] names it `.status` last.
Future<void> _renderRuns(WidgetTester tester, List<String> lines, String argsFile, File done) async {
  final status = File('${done.path}.tmp');
  if (lines.contains('--sheet')) return _sheetOne(tester, lines, argsFile);
  // `--state <label> <steps…>`, again for each state: one run (one start of
  // Flutter, one compile) captures every state, each from a fresh start
  // with its own steps, as a run with `--label <label>` and those steps
  // would. What comes before the first `--state` is every state's.
  final List<List<String>> runs;
  try {
    runs = stateRuns(lines);
  } on FormatException catch (e) {
    File('$argsFile.report').writeAsStringSync('${e.message}\n');
    status.writeAsStringSync('2');
    return;
  }
  final reports = StringBuffer();
  var worst = 0;
  for (final run in runs) {
    final RenderArgs args;
    try {
      args = parseArgs(run);
    } on FormatException catch (e) {
      File('$argsFile.report').writeAsStringSync('$reports${e.message}\n');
      status.writeAsStringSync('2');
      return;
    }
    final report = await runRender(tester, args);
    if (runs.length > 1) reports.writeln('== state ${args.label}');
    reports.write(formatReport(report));
    if (report.errors > 0) worst = 1;
    // What a state left for the test to find is that state's.
    tester.takeException();
  }
  File('$argsFile.report').writeAsStringSync('$reports');
  status.writeAsStringSync('$worst');
}

/// A request of the render server's, which this worker leads ([lead]) or helps with: the captures of its runs
/// this worker is first to claim are rendered (src/fan.dart); the leader waits for every capture's record and
/// writes the report, the timings and the status, as [_renderOne] does. Returns the verdict and how many
/// captures this worker rendered.
Future<(String, int)> _fanRequest(WidgetTester tester, String argsFile, String worker, {required bool lead}) async {
  final lines = argsFromFile(File(argsFile).readAsStringSync());
  // What one worker does alone, as ever: a contact sheet, and arguments that do not parse (said in the report).
  List<RenderArgs>? runs;
  if (!lines.contains('--sheet')) {
    try {
      runs = [for (final run in stateRuns(lines)) parseArgs(run)];
    } on FormatException {
      runs = null;
    }
  }
  if (runs == null) {
    if (!lead) return ('left', 0);
    await _renderOne(tester, argsFile);
    return ('done', 0);
  }
  final timings = RenderTimings.current = RenderTimings();
  final dir = FanDir.of(argsFile)..create();
  var rendered = 0;
  while (true) {
    // The request's folder is gone: its client left (it takes the folder with it), and nobody reads a report.
    if (!dir.exists) return ('left', rendered);
    var progress = false, complete = true;
    for (var r = 0; r < runs.length; r++) {
      final at = dir.state(r);
      final total = at.total;
      if (total != null && at.recorded >= total) continue;
      complete = false;
      final known = total ?? at.estimate;
      final bool join;
      if (known == null) {
        // Nobody prepared it yet; one who is preparing it says how many captures it has in a moment.
        join = at.entered == 0;
      } else if (at.solo) {
        // One capture after another: only when nobody is on it.
        join = at.claimed == at.recorded && (at.recorded < known || total == null);
      } else {
        // Captures nobody claimed; or all are rendered and no walk said so (its worker stopped first).
        join = at.claimed < known || (lead && total == null && at.claimed == at.recorded);
      }
      if (!join) continue;
      dir.enter(r, worker);
      final fan = FanRun(dir, r, worker);
      await runRender(tester, runs[r], fan: fan);
      rendered += fan.rendered;
      // What a run left for the test to find is that run's.
      tester.takeException();
      progress = true;
      if (fan.stopped) {
        if (DirectoryFontFetcher.engineConflicts.isNotEmpty) return ('retry', rendered);
        return (lead ? 'yield' : 'left', rendered);
      }
    }
    if (complete) break;
    // A helper leaves when nothing is left to claim; the leader waits for the captures others are on.
    if (!lead && !progress) return ('left', rendered);
    if (!progress) await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 4)));
  }
  if (!lead) return ('left', rendered);
  timings.lap('gather');
  final reports = StringBuffer();
  var worst = 0;
  for (var r = 0; r < runs.length; r++) {
    final report = mergeFanRun(dir, r, runs[r]);
    if (runs.length > 1) reports.writeln('== state ${runs[r].label}');
    reports.write(formatReport(report));
    if (report.errors > 0) worst = 1;
  }
  File('$argsFile.report').writeAsStringSync('$reports');
  File('$argsFile.timings').writeAsStringSync('${timings.line}\n');
  File('$argsFile.status.tmp')
    ..writeAsStringSync('$worst')
    ..renameSync('$argsFile.status');
  return ('done', rendered);
}

/// A contact sheet job (`render.sh --sheet <file.png> --out <dir> [--sheet-height n] [--sheet-columns n]
/// [--sheet-title text] [--sheet-base dir] <png | dir>...`): the captures on one image (src/sheet.dart).
Future<void> _sheetOne(WidgetTester tester, List<String> lines, String argsFile) async {
  String? value(String flag) {
    final i = lines.indexOf(flag);
    return i >= 0 && i + 1 < lines.length ? lines[i + 1] : null;
  }

  const valued = {'--sheet', '--out', '--sheet-height', '--sheet-columns', '--sheet-title', '--sheet-base'};
  final inputs = <String>[];
  for (var i = 0; i < lines.length; i++) {
    if (valued.contains(lines[i])) {
      i++;
    } else if (!lines[i].startsWith('--')) {
      inputs.add(lines[i]);
    }
  }
  final out = value('--sheet')!;
  final images = sheetInputs(inputs);
  final made = await tester.runAsync(() => makeSheet(images, out,
      height: int.tryParse(value('--sheet-height') ?? '') ?? 480,
      columns: int.tryParse(value('--sheet-columns') ?? ''),
      title: value('--sheet-title'),
      base: value('--sheet-base'),
      flutterRoot: Platform.environment['FLUTTER_ROOT'] ?? ''));
  File('$argsFile.report').writeAsStringSync(made == null ? 'No PNGs found.\n' : 'wrote $made\n');
  File('$argsFile.status.tmp').writeAsStringSync(made == null ? '1' : '0');
}

/// A request: who asked (null: a request file), how (`lead`, `help` or `solo` from the render server, else a run
/// of its own) and the arguments file.
typedef _Asked = ({Socket? socket, String? role, String argsFile});

Future<void> _serve(WidgetTester tester, String dir) async {
  final idle = Duration(seconds: int.tryParse(Platform.environment['CODELESSLY_RENDER_IDLE'] ?? '') ?? 1800);
  final worker = Platform.environment['CODELESSLY_RENDER_WORKER'] ?? 'w$pid';
  final stop = File('$dir/stop');
  // Requests also come over a socket on this machine (tool/cli's render: no shell, no polling): one line, the
  // token then the arguments file; answered with one line when the run is over. `port` holds the port and the
  // token, which only who can read this checkout's build/ knows.
  final asked = <_Asked>[];
  var wake = Completer<void>();
  final token = [for (var i = 0; i < 16; i++) Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0')].join();
  final listener = await tester.runAsync(() async {
    // A worker of the render server ends with it: the server holds this process's input open, and is gone when
    // it closes.
    if (Platform.environment['CODELESSLY_RENDER_WORKER_STDIN'] == '1') {
      stdin.listen((_) {}, onDone: () => exit(0), onError: (Object _) => exit(0));
    }
    try {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((socket) {
        socket.setOption(SocketOption.tcpNoDelay, true);
        final text = StringBuffer();
        late final StreamSubscription<String> sub;
        sub = utf8.decoder.bind(socket).listen((chunk) {
          text.write(chunk);
          final end = '$text'.indexOf('\n');
          if (end < 0) return;
          sub.cancel();
          final line = '$text'.substring(0, end);
          if (!line.startsWith('$token ')) {
            socket.destroy();
            return;
          }
          final rest = line.substring(token.length + 1);
          final role = RegExp(r'^(lead|help|solo) ').firstMatch(rest)?[1];
          asked.add((socket: socket, role: role, argsFile: role == null ? rest : rest.substring(role.length + 1)));
          if (!wake.isCompleted) wake.complete();
        }, onError: (_) => socket.destroy(), cancelOnError: true);
      }, onError: (_) {});
      File('$dir/port.tmp').writeAsStringSync('${server.port} $token\n');
      File('$dir/port.tmp').renameSync('$dir/port');
      return server;
    } catch (_) {
      return null; // No socket here: the request files alone.
    }
  });
  File('$dir/ready').writeAsStringSync('$pid\n');
  // A worker the render server started on the compiled harness is reached over its socket alone and ends when
  // the server closes its input: it waits for a request without looking for anything (seven idle workers that
  // looked 25 times a second were 7 % of a core).
  final pooled = Platform.environment['CODELESSLY_RENDER_WORKER_STDIN'] == '1';
  var served = 0;
  while (true) {
    // Wait on the real clock (the test's own is fake) for a request, the stop file or the idle limit.
    final next = await tester.runAsync<_Asked?>(() async {
      final since = DateTime.now();
      var looked = DateTime.fromMillisecondsSinceEpoch(0);
      while (DateTime.now().difference(since) < idle) {
        if (asked.isNotEmpty) return asked.removeAt(0);
        if (pooled) {
          // (A new one each wait, made here on the real clock: one made on the test's own would not wake this.)
          final woken = wake = Completer<void>();
          final limit = Timer(idle - DateTime.now().difference(since), () {
            if (!woken.isCompleted) woken.complete();
          });
          await woken.future;
          limit.cancel();
          continue;
        }
        // The stop file and the request files are looked for every 40 ms; a request over the socket wakes at once.
        if (DateTime.now().difference(looked).inMilliseconds >= 40) {
          looked = DateTime.now();
          if (stop.existsSync()) return null;
          final reqs = Directory(dir).listSync().whereType<File>().where((f) => f.path.endsWith('.req')).toList()
            ..sort((a, b) => a.path.compareTo(b.path));
          if (reqs.isNotEmpty) {
            final argsFile = reqs.first.readAsStringSync().trim();
            reqs.first.deleteSync();
            return (socket: null, role: null, argsFile: argsFile);
          }
        }
        if (wake.isCompleted) wake = Completer<void>();
        await Future.any([wake.future, Future<void>.delayed(const Duration(milliseconds: 40))]);
      }
      return null;
    });
    if (next == null) break;
    final (:socket, :role, :argsFile) = next;
    // The socket's caller is told when the run is over, whatever came of it (it reads the files then).
    Future<void> answer(String line) async {
      if (socket == null) return;
      await tester.runAsync(() async {
        try {
          socket.write('$line\n');
          await socket.flush();
          await socket.close();
        } catch (_) {
          socket.destroy();
        }
      });
    }

    var stopServing = false;
    var verdict = 'done';
    var rendered = 0;
    try {
      if (role == null) {
        await _renderOne(tester, argsFile);
      } else if (role == 'solo') {
        await _renderOne(tester, argsFile);
        rendered = 1;
      } else {
        (verdict, rendered) = await _fanRequest(tester, argsFile, worker, lead: role == 'lead');
      }
      if (DirectoryFontFetcher.engineConflicts.isNotEmpty) {
        // A face this run needs is registered with another file from an earlier run, and the engine cannot forget
        // it: this run's capture is not what a run of its own draws. Hand it back and stop serving.
        if (role == null) {
          for (final ext in const ['.status', '.report']) {
            final f = File('$argsFile$ext');
            if (f.existsSync()) f.deleteSync();
          }
          File('$argsFile.retry').writeAsStringSync('${DirectoryFontFetcher.engineConflicts.join('\n')}\n');
        } else {
          // (The render server gives the request to another worker, and starts one in this one's place.)
          verdict = 'retry';
          if (role == 'solo') {
            // What this worker wrote is not the run's: the next worker writes it.
            for (final ext in const ['.status', '.report']) {
              final f = File('$argsFile$ext');
              if (f.existsSync()) f.deleteSync();
            }
          }
          stderr.writeln('Worker $worker stops: it has other files registered for fonts this run draws '
              '(${DirectoryFontFetcher.engineConflicts.join('; ')}).');
        }
        stopServing = true;
      }
    } catch (e, s) {
      // A run that throws answers with the error, and the server stops: what it threw in the middle of (a build,
      // a layout) can leave the widget tree it keeps half torn down, and every later run would draw on that
      // (duplicate GlobalKeys, detached render objects, screens that never load). The next run starts afresh.
      if (role == 'help') {
        // (A helper's: the capture it was on goes back to the request's leader, which says what it comes to.)
        stderr.writeln('Worker $worker failed on a capture of $argsFile and stops: $e\n$s');
        verdict = 'left';
      } else {
        File('$argsFile.report').writeAsStringSync('The render server failed on this run: $e\n$s\n'
            'The render server stopped after it: the next run starts from a fresh Flutter.\n');
        File('$argsFile.status').writeAsStringSync('2');
        verdict = 'done';
      }
      stopServing = true;
    }
    String line() => role == null ? 'done' : '$verdict ${ProcessInfo.currentRss} $rendered${stopServing ? ' bye' : ''}';
    if (stopServing) {
      // No further request is taken: said before the caller is answered, so its next run does not ask.
      _closeDoor(dir);
      await answer(line());
      break;
    }
    // Whatever a run left for the test to find is that run's, not the next one's.
    tester.takeException();
    served++;
    // (The render server counts what its workers served itself.)
    if (!pooled) File('$dir/served').writeAsStringSync('$served\n');
    // The next run gets a sound tree: an empty frame builds and lays out without an error. A run whose failure
    // (a framework assertion in a build) left it broken ends the server rather than the next run's capture.
    // (A worker of the render server looks before it answers, so the server knows it takes no more.)
    if (role != null && !await renderTreeSound(tester)) {
      stderr.writeln('Worker $worker stops: run $served left the widget tree broken.');
      stopServing = true;
      _closeDoor(dir);
      await answer(line());
      break;
    }
    await answer(line());
    if (role == null && !await renderTreeSound(tester)) {
      stderr.writeln('The render server stopped: run $served left the widget tree broken; the next run starts afresh.');
      break;
    }
  }
  _closeDoor(dir);
  await tester.runAsync(() async {
    await listener?.close();
    for (final a in asked) {
      a.socket?.destroy();
    }
  });
}

/// The server takes no more requests: its `port` and `ready` files are gone.
void _closeDoor(String dir) {
  for (final name in const ['port', 'ready']) {
    final f = File('$dir/$name');
    if (f.existsSync()) f.deleteSync();
  }
}
