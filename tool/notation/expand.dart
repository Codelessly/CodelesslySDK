// Expands a UI written in the compact notation
// (package:codelessly_api/notation.dart) into a layout document.
//
//   dart run tool/notation/expand.dart <file.txt> [--design-system <folder>] [--id <canvas id>] [--out <file.json>]
//
// With --design-system (a folder holding design_system.json) the notation
// may call that design system's components by name and takes its looks.
// What the notation could not read is written to stderr, one line each;
// the exit status is 1 when there is any.
import 'dart:convert';
import 'dart:io';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_api/notation.dart';

Future<void> main(List<String> args) async {
  String? opt(String name) {
    final i = args.indexOf(name);
    return i < 0 || i + 1 >= args.length ? null : args[i + 1];
  }

  final file = args.where((a) => !a.startsWith('--')).firstOrNull;
  if (file == null || !File(file).existsSync()) {
    stderr.writeln('usage: expand.dart <file.txt> [--design-system <folder>] [--id <canvas id>] [--out <file.json>]');
    exit(2);
  }
  DesignSystem? ds;
  if (opt('--design-system') case final dir?) {
    final problems = <String>[];
    ds = await DesignSystem.load((ref) async {
      final f = File('$dir/$ref');
      return f.existsSync() ? f.readAsStringSync() : null;
    }, problems: problems);
    if (problems.isNotEmpty) {
      stderr.writeln('The design system at $dir does not load cleanly: ${problems.join('; ')}');
      exit(2);
    }
  }
  final catalog = ds?.catalogOver(standardCatalog) ?? standardCatalog;
  final screen = opt('--id') ?? 'screen';
  final options = ds == null ? NotationOptions(screen: screen) : NotationOptions.fromDesignSystem(ds, screen: screen);
  final result = Catalog.run(catalog, () => parseNotation(File(file).readAsStringSync(), catalog: catalog, options: options));
  for (final issue in result.issues) {
    stderr.writeln('$file: $issue');
  }
  final json = const JsonEncoder.withIndent(' ').convert(result.document);
  if (opt('--out') case final out?) {
    File(out).writeAsStringSync(json);
  } else {
    stdout.writeln(json);
  }
  if (result.issues.isNotEmpty) exitCode = 1;
}
