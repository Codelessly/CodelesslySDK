// Expands a UI written in the compact notation
// (package:codelessly_api/notation.dart) into a layout document.
//
//   dart run tool/notation/expand.dart <file.txt> [--design-system <folder>] [--named] [--id <canvas id>] [--width <canvas width>] [--no-reflow] [--site <site.json>] [--out <file.json>]
//
// With --design-system (a folder holding design_system.json) the notation
// may call that design system's components by name and takes its looks.
// With --named as well, a look the theme names is written as that name (as
// a UiSession writes it: the document follows dark mode and the theme).
// A page (--width 700 or more) is given the media rules that lay it out on a
// tablet and a phone; --no-reflow leaves it written for its one width.
// The variables of the site.json beside --out (or of --site) are the site's:
// the page uses them by name and declares none of them on its screen.
// What the notation could not read is written to stderr, one line each;
// the exit status is 1 when there is any.
//
// With --open the vocabulary is open (codelessly_api
// docs/design/19-open-vocabulary.md): a word the notation does not have is
// not an error, it stands in (a type) or is left out (a parameter, a flag,
// an event, an action verb), and every such word is recorded. --vocabulary
// <file.json> writes the record (each use: its kind, the word, the line it
// is on, and for a type what it was given); without it the uses are listed
// on stderr. The aliases (names read as a word we have) are the built-in
// ones and the design system's vocabulary.json; --aliases <file.json> adds a
// table over both.
import 'dart:convert';
import 'dart:io';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_api/notation.dart';
import 'package:codelessly_api/validate.dart' show validateSiteVariables;

import 'vocabulary.dart' show loadVocabulary;

Future<void> main(List<String> args) async {
  String? opt(String name) {
    final i = args.indexOf(name);
    return i < 0 || i + 1 >= args.length ? null : args[i + 1];
  }

  final file = args.where((a) => !a.startsWith('--')).firstOrNull;
  if (file == null || !File(file).existsSync()) {
    stderr.writeln('usage: expand.dart <file.txt> [--design-system <folder>] [--named] [--id <canvas id>] [--width <canvas width>] [--no-reflow] [--site <site.json>] [--out <file.json>] [--open [--vocabulary <file.json>]] [--aliases <file.json>]');
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
  final width = double.tryParse(opt('--width') ?? '') ?? 390;
  // The site's variables (site.json's `variables`): a page reads and sets
  // them by name, with no copy of its own that would hide them. From
  // --site <site.json>, else the site.json beside --out.
  final sitePath = opt('--site') ?? (opt('--out') == null ? null : '${File(opt('--out')!).parent.path}/site.json');
  final projectVariables = <String, Map<String, Object?>>{};
  if (sitePath != null && File(sitePath).existsSync()) {
    try {
      final manifest = jsonDecode(File(sitePath).readAsStringSync());
      // As the manifest's reader takes them: a list of records or an object
      // of name to value, each typed by its value when it names no type.
      final declared = manifest is Map ? manifest['variables'] : null;
      for (final v in Variable.declarationsFromJson(declared)) {
        projectVariables[v.name] = {'type': v.type.name, ...v.toJson()};
      }
      for (final d in validateSiteVariables(declared)) {
        stderr.writeln('$sitePath: ${d.path}: ${d.message}');
      }
    } on FormatException catch (e) {
      stderr.writeln('$sitePath is not JSON (${e.message}): its variables were not read.');
    }
  }
  final open = args.contains('--open');
  final NotationVocabulary aliases;
  try {
    aliases = loadVocabulary(dir: opt('--design-system'), file: opt('--aliases'));
  } on Object catch (e) {
    stderr.writeln('The alias table does not load: $e');
    exit(2);
  }
  final options = (ds == null
          ? NotationOptions(screen: screen, width: width, reflow: !args.contains('--no-reflow'), projectVariables: projectVariables)
          : NotationOptions.fromDesignSystem(ds, screen: screen, width: width, named: args.contains('--named'), reflow: !args.contains('--no-reflow'), projectVariables: projectVariables))
      .open(openVocabulary: open, vocabulary: aliases);
  final result = Catalog.run(catalog, () => parseNotation(File(file).readAsStringSync(), catalog: catalog, options: options));
  for (final issue in result.issues) {
    stderr.writeln('$file: $issue');
  }
  if (opt('--vocabulary') case final record?) {
    File(record).writeAsStringSync('${const JsonEncoder.withIndent(' ').convert([for (final u in result.vocabulary) u.toJson()])}\n');
  } else if (open) {
    for (final u in result.vocabulary) {
      stderr.writeln('$file: vocabulary: $u');
    }
  }
  final json = const JsonEncoder.withIndent(' ').convert(result.document);
  if (opt('--out') case final out?) {
    File(out).writeAsStringSync(json);
  } else {
    stdout.writeln(json);
  }
  if (result.issues.isNotEmpty) exitCode = 1;
}
