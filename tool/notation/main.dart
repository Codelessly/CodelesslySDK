// The notation's commands as one program, which tool/notation/notation.sh compiles to a native executable
// (build/codelessly_notation, again whenever a source of it changes) and runs: a command then costs its own work,
// not the five seconds `dart run` takes to compile it from source each time.
//
//   build/codelessly_notation prompt|expand|print|apply|vocabulary [arguments]
//
// Each command is its own file's main (expand.dart, print.dart, ...), which `dart run tool/notation/<command>.dart`
// still runs from source.
//
// --timings (or CODELESSLY_TIMINGS set to anything but 0) says on stderr, after the command, how long it took:
// `timings: expand run 180 ms; total 230 ms` (total: since notation.sh started).
import 'dart:io';

import 'apply.dart' as apply;
import 'expand.dart' as expand;
import 'print.dart' as print_;
import 'prompt.dart' as prompt;
import 'vocabulary.dart' as vocabulary;

Future<void> main(List<String> argv) async {
  if (argv.isEmpty) {
    stderr.writeln('usage: tool/notation/notation.sh prompt|expand|validate|print|apply|vocabulary [arguments]');
    exit(2);
  }
  final command = argv.first;
  final timings = argv.contains('--timings') || !const {'', '0'}.contains(Platform.environment['CODELESSLY_TIMINGS'] ?? '');
  final args = [for (final a in argv.skip(1)) if (a != '--timings') a];
  final clock = Stopwatch()..start();
  final started = double.tryParse((Platform.environment['CODELESSLY_STARTED'] ?? '').replaceAll(',', '.'));
  // (A command that ends with `exit`, as one given a file that is not there does, says none.)
  void say() {
    if (!timings) return;
    final total = started == null ? clock.elapsedMilliseconds : DateTime.now().millisecondsSinceEpoch - (started * 1000).round();
    stderr.writeln('timings: $command start ${total - clock.elapsedMilliseconds} ms, run ${clock.elapsedMilliseconds} ms; total $total ms');
  }

  switch (command) {
    case 'apply':
      await apply.main(args);
    case 'expand':
      await expand.main(args);
    case 'print':
      await print_.main(args);
    case 'prompt':
      await prompt.main(args);
    case 'vocabulary':
      await vocabulary.main(args);
    default:
      stderr.writeln('usage: tool/notation/notation.sh prompt|expand|validate|print|apply|vocabulary [arguments]');
      exit(2);
  }
  await stdout.flush();
  await stderr.flush();
  say();
  exit(exitCode);
}
