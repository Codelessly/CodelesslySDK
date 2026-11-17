// Expands many notation files at once, for comparing two parsers (or a file
// before and after `format`): the proof that a change to the grammar, or a
// conversion, leaves the documents as they were.
//
//   dart run tool/notation/expand_all.dart <list.txt> <out folder> [--migrate]
//
// With --migrate each file is rewritten from the original grammar first (as
// `notation.sh migrate` writes it, knowing every design system here), in
// memory.
//
// <list.txt> names one notation file per line, optionally followed by a tab
// and the key to file its result under (else the path itself): a converted
// copy is filed under the original's key, so the two runs line up. Each file
// is expanded twice: as a card (390 wide, no design system) and as a page
// (1280 wide, the Cards design system, reflow on). For each it writes
// <out>/<n>.<config>.json (the document) and one line in <out>/index.tsv:
// key, config, the document's md5, its node count and its issue count.
// Compare two runs with tool/notation/compare_runs.dart.
import 'dart:convert';
import 'dart:io';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_api/notation.dart';
import 'package:crypto/crypto.dart';

import 'migrate.dart' show migrateNotation;

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    stderr.writeln('usage: expand_all.dart <list.txt> <out folder>');
    exit(2);
  }
  final sdk = File.fromUri(Platform.script).parent.parent.parent.path;
  final ds = await DesignSystem.load((ref) async {
    final f = File('$sdk/design_systems/cards/$ref');
    return f.existsSync() ? f.readAsStringSync() : null;
  });
  final catalogs = [
    ds.catalogOver(standardCatalog),
    for (final name in const ['ssui', 'skip', 'harbor', 'paper'])
      (await DesignSystem.load((ref) async {
        final f = File('$sdk/design_systems/$name/$ref');
        return f.existsSync() ? f.readAsStringSync() : null;
      }))
          .catalogOver(standardCatalog),
  ];
  final out = Directory(args[1])..createSync(recursive: true);
  final index = StringBuffer();
  var n = 0;
  for (final line in File(args[0]).readAsLinesSync()) {
    if (line.trim().isEmpty) continue;
    final parts = line.split('\t');
    final path = parts[0], key = parts.length > 1 ? parts[1] : parts[0];
    var text = File(path).readAsStringSync();
    if (args.contains('--migrate')) {
      text = migrateNotation(text, catalogs: catalogs);
      if (migrateNotation(text, catalogs: catalogs) != text) stderr.writeln('$path: migrating it twice changes it again');
    }
    n++;
    for (final config in const ['card', 'page']) {
      final catalog = config == 'page' ? ds.catalogOver(standardCatalog) : standardCatalog;
      final options = config == 'page' ? NotationOptions.fromDesignSystem(ds, width: 1280) : const NotationOptions();
      String json;
      int nodes = 0, issues = 0;
      final said = <String>[];
      try {
        final result = Catalog.run(catalog, () => parseNotation(text, catalog: catalog, options: options));
        json = const JsonEncoder.withIndent(' ').convert(result.document);
        nodes = (result.document['nodes'] as Map).length;
        issues = result.issues.length;
        said.addAll(result.issues.map((i) => '$i'));
      } catch (e) {
        json = 'THROWN: $e';
        issues = -1;
      }
      File('${out.path}/$n.$config.json').writeAsStringSync(json);
      if (said.isNotEmpty) File('${out.path}/$n.$config.issues.txt').writeAsStringSync(said.join('\n'));
      index.writeln('$key\t$config\t${md5.convert(utf8.encode(json))}\t$nodes\t$issues\t$n');
    }
  }
  File('${out.path}/index.tsv').writeAsStringSync(index.toString());
  stdout.writeln('$n files expanded twice each into ${out.path}');
}
