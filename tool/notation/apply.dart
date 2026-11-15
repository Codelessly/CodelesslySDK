// Applies edit operations to a layout document, as a session does to the UI
// it holds (package:codelessly_api `applyOps`): the way a card on screen is
// restyled or changed in place without being written again.
//
//   dart run tool/notation/apply.dart <document.json> <ops.json> [--design-system <folder>] [--out <file.json>]
//   dart run tool/notation/apply.dart --reference     (prints each op's description and example)
//
// <ops.json> is {"ops": [...]} or a bare list (the `ui_apply` tool's input).
// Every op is tried; a rejected one changes nothing and is written to stderr
// with its reason. The exit status is 1 when any op was rejected.
import 'dart:convert';
import 'dart:io';

import 'package:codelessly_api/codelessly_api.dart';

Future<void> main(List<String> args) async {
  String? opt(String name) {
    final i = args.indexOf(name);
    return i < 0 || i + 1 >= args.length ? null : args[i + 1];
  }

  // What an op is, for whoever writes them: each op's own description and example.
  if (args.contains('--reference')) {
    for (final spec in EditOp.specs) {
      stdout.writeln('${spec.op}: ${spec.doc}\n  ${jsonEncode(spec.example)}');
    }
    return;
  }
  final files = [
    for (var i = 0; i < args.length; i++)
      if (!args[i].startsWith('--') && (i == 0 || !const {'--design-system', '--out'}.contains(args[i - 1]))) args[i],
  ];
  if (files.length != 2 || !files.every((f) => File(f).existsSync())) {
    stderr.writeln('usage: apply.dart <document.json> <ops.json> [--design-system <folder>] [--out <file.json>]');
    exit(2);
  }
  var catalog = standardCatalog;
  var profile = TrustProfile.agent;
  if (opt('--design-system') case final dir?) {
    final problems = <String>[];
    final ds = await DesignSystem.load((ref) async {
      final f = File('$dir/$ref');
      return f.existsSync() ? f.readAsStringSync() : null;
    }, problems: problems);
    problems.forEach(stderr.writeln);
    catalog = ds.catalogOver(standardCatalog);
    profile = profile.withComponents(ds.components);
  }
  final json = jsonDecode(File(files[0]).readAsStringSync()) as Map<String, Object?>;
  final ops = jsonDecode(File(files[1]).readAsStringSync());
  final result = Catalog.run(catalog, () {
    final document = LayoutDocument.fromJson(json, catalog: catalog);
    return applyOps(document, ops is Map ? ops['ops'] : ops, catalog: catalog, profile: profile);
  });
  for (final d in result.diagnostics) {
    stderr.writeln('${d.error ? 'ERROR' : 'WARNING'} ${d.code} op ${d.op} ${d.path}: ${d.message}');
  }
  final out = const JsonEncoder.withIndent(' ').convert(result.document.toJson());
  if (opt('--out') case final path?) {
    File(path).writeAsStringSync('$out\n');
  } else {
    stdout.writeln(out);
  }
  stderr.writeln('${result.applied.length} op(s) applied, ${result.rejected.length} rejected.');
  exit(result.rejected.isEmpty ? 0 : 1);
}
