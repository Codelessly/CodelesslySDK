// The replay command's entry point, run by replay.sh under `flutter test`
// (headless, a virtual clock). Reads its arguments from the file
// CODELESSLY_REPLAY_ARGS names (one per line).
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import 'src/replay.dart';

void main() {
  final argsFile = Platform.environment['CODELESSLY_REPLAY_ARGS'];
  testWidgets('replay', (tester) async {
    if (argsFile == null) return; // Not run by replay.sh.
    final lines = File(argsFile).readAsLinesSync();
    String? opt(String name) {
      final i = lines.indexOf(name);
      return i >= 0 && i + 1 < lines.length ? lines[i + 1] : null;
    }

    final sizes = [
      for (final s in (opt('--sizes') ?? '390x844,1440x900').split(','))
        ui.Size(double.parse(s.split('x')[0]), double.parse(s.split('x')[1])),
    ];
    final fonts = [for (var i = 0; i < lines.length - 1; i++) if (lines[i] == '--fonts') lines[i + 1]];
    final metrics = await runReplay(
        tester,
        ReplayArgs(
          stream: lines.first,
          out: opt('--out')!,
          sizes: sizes,
          fontDirs: fonts,
          frameMs: int.tryParse(opt('--frame-ms') ?? ''),
          frames: int.tryParse(opt('--frames') ?? ''),
          designSystem: opt('--design-system'),
          dark: opt('--theme') == 'dark',
        ));
    File('$argsFile.report').writeAsStringSync(const JsonEncoder.withIndent(' ').convert(metrics));
  }, timeout: const Timeout(Duration(minutes: 30)));
}
