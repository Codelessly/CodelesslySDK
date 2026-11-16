// The Codelessly toolkit's commands written in Dart, run by tool/codelessly (which compiles this file to a native
// executable, build/codelessly_cli, whenever its sources change). See tool/README.md.
import 'dart:io';

import 'src/common.dart';
import 'src/docs.dart';
import 'src/flatten.dart';
import 'src/mcp.dart';
import 'src/outline.dart';
import 'src/render_cmd.dart';
import 'src/states.dart';

Future<void> main(List<String> argv) async {
  if (argv.isEmpty) {
    stderr.writeln('usage: tool/codelessly <command> [arguments] (tool/codelessly help lists them)');
    exit(2);
  }
  final command = argv.first;
  final rest = argv.sublist(1);
  int code;
  try {
    code = await switch (command) {
      'docs' => docsMain(rest),
      'flatten' => flattenMain(rest),
      'outline' => outlineMain(rest),
      'states' => statesMain(rest),
      'render' => renderMain(rest, validate: false),
      'validate' => renderMain(rest, validate: true),
      'sheet' => sheetMain(rest),
      'mcp' => mcpMain(rest),
      _ => throw UsageError('Unknown command: $command. tool/codelessly help lists them.'),
    };
  } on UsageError catch (e) {
    stderr.writeln(e.message);
    code = 2;
  }
  await stdout.flush();
  exit(code);
}
