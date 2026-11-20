// The render command's entry point, run by render.sh under `flutter test`
// (headless: no device, real fonts loaded from files). Reads its arguments
// from the file CODELESSLY_RENDER_ARGS names (one per line) and writes the
// report next to the PNGs; render.sh prints it and exits with its status.
//
// With CODELESSLY_RENDER_SERVE=<dir> it is the render server instead
// (tool/render/serve.sh): it stays up and renders each request dropped in
// <dir> (a `<id>.req` file holding the path of an arguments file, as above),
// one after another, writing that file's `.report` and `.status`. A run then
// costs the rendering alone, not Flutter's start (about 5 s). It writes
// <dir>/ready once it takes requests, and stops when <dir>/stop appears or no
// request came for CODELESSLY_RENDER_IDLE seconds (default 1800).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'src/args.dart';
import 'src/fonts.dart';
import 'src/google_fonts.dart' show renderUsesGoogleFonts;
import 'src/sheet.dart';
import 'src/render.dart';

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
  final lines = File(argsFile).readAsLinesSync();
  final status = File('$argsFile.status');
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
  File('$argsFile.status').writeAsStringSync(made == null ? '1' : '0');
}

Future<void> _serve(WidgetTester tester, String dir) async {
  final idle = Duration(seconds: int.tryParse(Platform.environment['CODELESSLY_RENDER_IDLE'] ?? '') ?? 1800);
  final stop = File('$dir/stop');
  File('$dir/ready').writeAsStringSync('$pid\n');
  var served = 0;
  while (true) {
    // Wait on the real clock (the test's own is fake) for a request, the stop file or the idle limit.
    final next = await tester.runAsync(() async {
      final since = DateTime.now();
      while (!stop.existsSync() && DateTime.now().difference(since) < idle) {
        final reqs = Directory(dir).listSync().whereType<File>().where((f) => f.path.endsWith('.req')).toList()
          ..sort((a, b) => a.path.compareTo(b.path));
        if (reqs.isNotEmpty) return reqs.first;
        await Future<void>.delayed(const Duration(milliseconds: 40));
      }
      return null;
    });
    if (next == null) break;
    final argsFile = next.readAsStringSync().trim();
    next.deleteSync();
    try {
      await _renderOne(tester, argsFile);
      if (DirectoryFontFetcher.engineConflicts.isNotEmpty) {
        // A face this run needs is registered with another file from an earlier run, and the engine cannot forget
        // it: this run's capture is not what a run of its own draws. Hand it back and stop serving.
        for (final ext in const ['.status', '.report']) {
          final f = File('$argsFile$ext');
          if (f.existsSync()) f.deleteSync();
        }
        File('$argsFile.retry').writeAsStringSync('${DirectoryFontFetcher.engineConflicts.join('\n')}\n');
        break;
      }
    } catch (e, s) {
      // A run that throws answers with the error, and the server stops: what it threw in the middle of (a build,
      // a layout) can leave the widget tree it keeps half torn down, and every later run would draw on that
      // (duplicate GlobalKeys, detached render objects, screens that never load). The next run starts afresh.
      File('$argsFile.report').writeAsStringSync('The render server failed on this run: $e\n$s\n'
          'The render server stopped after it: the next run starts from a fresh Flutter.\n');
      File('$argsFile.status').writeAsStringSync('2');
      break;
    }
    // Whatever a run left for the test to find is that run's, not the next one's.
    tester.takeException();
    File('$dir/served').writeAsStringSync('${++served}\n');
    // The next run gets a sound tree: an empty frame builds and lays out without an error. A run whose failure
    // (a framework assertion in a build) left it broken ends the server rather than the next run's capture.
    if (!await renderTreeSound(tester)) {
      stderr.writeln('The render server stopped: run $served left the widget tree broken; the next run starts afresh.');
      break;
    }
  }
  File('$dir/ready').deleteSync();
}
