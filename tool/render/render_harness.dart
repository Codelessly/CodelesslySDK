// The render command's entry point, run by render.sh under `flutter test`
// (headless: no device, real fonts loaded from files). Reads its arguments
// from the file CODELESSLY_RENDER_ARGS names (one per line) and writes the
// report next to the PNGs; render.sh prints it and exits with its status.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'src/args.dart';
import 'src/render.dart';

void main() {
  final argsFile = Platform.environment['CODELESSLY_RENDER_ARGS'];
  testWidgets('render', (tester) async {
    if (argsFile == null) return; // Not run by render.sh.
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
  }, timeout: const Timeout(Duration(minutes: 20)));
}
