// Rewrites notation files to the canonical grammar (the one the prompt
// teaches; CodelesslyAPI docs/design/15-notation-grammar-audit.md sets it
// out and 16-notation-grammar-migration.md lists what changed): =name as
// bind:name, key:=expression as key:{expression}, a handler on a line of
// its own onto its node's line, a page worked out after go in braces.
//
//   dart run tool/notation/format.dart <file.txt> [more files] [--design-system <folder>] [--check] [--stdout] [--force]
//
// Each file is rewritten in place (--stdout prints the one file instead;
// --check changes nothing and exits 1 when a file is not in the canonical
// grammar). A file is left as it is, and named, when the rewritten text
// would expand to a different document than the text as written, as a card
// or as a page: the formatter never changes what a file means. Pass
// --design-system when the files call a design system's blocks, so the
// comparison reads them as they are read; --force writes without comparing.
import 'dart:convert';
import 'dart:io';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_api/notation.dart';

Future<void> main(List<String> args) async {
  String? opt(String name) {
    final i = args.indexOf(name);
    return i < 0 || i + 1 >= args.length ? null : args[i + 1];
  }

  final dsDir = opt('--design-system');
  final files = [
    for (var i = 0; i < args.length; i++)
      if (!args[i].startsWith('--') && (i == 0 || args[i - 1] != '--design-system')) args[i],
  ];
  if (files.isEmpty) {
    stderr.writeln('usage: format.dart <file.txt> [more files] [--design-system <folder>] [--check] [--stdout] [--force]');
    exit(2);
  }
  DesignSystem? ds;
  if (dsDir != null) {
    final problems = <String>[];
    ds = await DesignSystem.load((ref) async {
      final f = File('$dsDir/$ref');
      return f.existsSync() ? f.readAsStringSync() : null;
    }, problems: problems);
    if (problems.isNotEmpty) {
      stderr.writeln('The design system at $dsDir does not load cleanly: ${problems.join('; ')}');
      exit(2);
    }
  }
  final catalog = ds?.catalogOver(standardCatalog) ?? standardCatalog;
  // The document a text expands to, as a card and as a page.
  String expanded(String text, double width) {
    final options = ds == null ? NotationOptions(width: width) : NotationOptions.fromDesignSystem(ds, width: width);
    return jsonEncode(Catalog.run(catalog, () => parseNotation(text, catalog: catalog, options: options).document));
  }

  final check = args.contains('--check'), print = args.contains('--stdout'), force = args.contains('--force');
  var changed = 0, unsafe = 0;
  for (final path in files) {
    final file = File(path);
    if (!file.existsSync()) {
      stderr.writeln('$path: no such file');
      exitCode = 2;
      continue;
    }
    final text = file.readAsStringSync();
    final formatted = formatNotation(text);
    if (formatted == text) {
      if (print) stdout.write(text);
      continue;
    }
    if (!force && (expanded(text, 390) != expanded(formatted, 390) || expanded(text, 1280) != expanded(formatted, 1280))) {
      unsafe++;
      stderr.writeln('$path: left as it is (rewritten, it would expand to a different document: rewrite its lines by hand${ds == null ? ', or pass --design-system if it calls the blocks of a design system' : ''})');
      if (print) stdout.write(text);
      exitCode = 1;
      continue;
    }
    changed++;
    if (print) {
      stdout.write(formatted);
    } else if (check) {
      stderr.writeln('$path: not in the canonical grammar');
      exitCode = 1;
    } else {
      file.writeAsStringSync(formatted);
    }
  }
  if (!print) stderr.writeln('${files.length} files: $changed ${check ? 'to rewrite' : 'rewritten'}, $unsafe left as they are, ${files.length - changed - unsafe} already in the canonical grammar');
}
