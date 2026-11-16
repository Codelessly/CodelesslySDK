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
import 'src/render.dart';

void main() {
  final argsFile = Platform.environment['CODELESSLY_RENDER_ARGS'];
  final serveDir = Platform.environment['CODELESSLY_RENDER_SERVE'];
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
  final RenderArgs args;
  try {
    args = parseArgs(lines);
  } on FormatException catch (e) {
    File('$argsFile.report').writeAsStringSync('${e.message}\n');
    status.writeAsStringSync('2');
    return;
  }
  final report = await runRender(tester, args);
  File('$argsFile.report').writeAsStringSync(formatReport(report));
  status.writeAsStringSync(report.errors > 0 ? '1' : '0');
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
    } catch (e, s) {
      // A run that throws answers with the error; the server keeps serving.
      File('$argsFile.report').writeAsStringSync('The render server failed on this run: $e\n$s\n');
      File('$argsFile.status').writeAsStringSync('2');
    }
    // Whatever a run left for the test to find is that run's, not the next one's.
    tester.takeException();
    File('$dir/served').writeAsStringSync('${++served}\n');
  }
  File('$dir/ready').deleteSync();
}
