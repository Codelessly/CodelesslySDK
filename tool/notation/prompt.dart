// Prints what a model is told to write UI in the compact notation
// (package:codelessly_api/notation.dart): the grammar, the words, and, with
// a design system, its components.
//
//   dart run tool/notation/prompt.dart [--design-system <folder>] [--width <canvas width>]
import 'dart:io';

import 'package:codelessly_api/codelessly_api.dart';

Future<void> main(List<String> args) async {
  final w = args.indexOf('--width');
  final width = w >= 0 && w + 1 < args.length ? double.tryParse(args[w + 1]) ?? 390.0 : 390.0;
  final i = args.indexOf('--design-system');
  DesignSystem? ds;
  if (i >= 0 && i + 1 < args.length) {
    final dir = args[i + 1];
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
  stdout.writeln(Catalog.run(
    catalog,
    () => notationPrompt(
      catalog: catalog,
      options: ds == null ? NotationOptions(width: width) : NotationOptions.fromDesignSystem(ds, width: width),
      designSystem: ds,
    ),
  ));
}
