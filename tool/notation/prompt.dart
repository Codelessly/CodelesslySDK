// Prints what a model is told to write UI in the compact notation
// (package:codelessly_api/notation.dart): the grammar, the words, and, with
// a design system, its components.
//
//   dart run tool/notation/prompt.dart [--design-system <folder>] [--width <canvas width>] [--open [--no-define] [--no-glossary | --glossary=names|signatures]]
import 'dart:io';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_api/notation.dart' show NotationVocabulary, definitionLines, readDefinitions;

import 'vocabulary.dart' show loadDefinitionTexts;

/// What the open prompt says last: the words written are recorded, and
/// where (codelessly_api docs/design/19-open-vocabulary.md, section 15).
const openRecordNote = 'WHAT IS RECORDED\n'
    'Every expand (tool/notation/notation.sh expand <site folder or file> --open) saves a record of every word you wrote and how it '
    'resolved: for a site folder <folder>/vocabulary.json and VOCABULARY.md, for a file of no site <file>.vocabulary.json beside it. '
    'It is kept across expands, so a word you later rewrote is still there; you need do nothing for it. A word that stood in as a '
    'placeholder is said by expand (placeholder: Word …), by tool/codelessly render (placeholder_word) and by tool/codelessly validate: '
    'define it, or leave it and it is recorded for support. A components/<Name>.txt is a component (`component Name` first) or '
    'definitions (`define Name …` first, read by every page).';

/// What the open prompt says of the site's manifest: its shape in a few
/// lines, and the reference page that has the whole of it (test 10: the
/// manifest's shapes were the most looked-up thing the prompt did not say).
const openSiteNote = 'THE SITE (site.json)\n'
    '{"schema": 3, "pages": ["home.json", "cart.json"], "variables": {"cart": [], "favourites": {"value": [], "persist": true}}, '
    '"theme": {"primary": "#FF2F6B4F", "colors": {"ink": "#FF1F2A24", "paper": "#FFFBF8F2"}, '
    '"textStyles": {"body": {"fontSize": 15, "color": "ink"}, "title": {"fontSize": 28, "fontWeight": 600}}, '
    '"spacing": {"md": 16}, "radii": {"card": 10}, "dark": {"colors": {"ink": "#FFE8EDE9", "paper": "#FF141815"}}}}\n'
    "Every page reads the variables by name (persist keeps one on the device) and the theme's names (color=ink, style=title); "
    'the theme\'s "fontFamily": "Georgia" is the font of every text ("titleFontFamily" the headings\', a text style\'s "fontFamily" its own); '
    'pages/<name>.txt expands to the page <name>.json. The whole manifest: docs/reference/notation/site.md.';

Future<void> main(List<String> args) async {
  // --open: the open-vocabulary prompt (the grammar and the core only; a
  // design system's components are not listed), which asks the model to
  // define every word it invents after its last screen; --no-define leaves
  // that out (the prompt the first corpus was written with). With a design
  // system the open prompt lists its components and defined words, the
  // glossary (the vocabulary loop's Review 6, D29): by default one line per
  // word as a line uses it, its signature (Review 7, D33);
  // --glossary=names gives their names on one line (the prompt corpus-define
  // d03 was written with); --no-glossary leaves it out (the prompt the
  // self-defining corpora d01 and d02 were written with).
  final open = args.contains('--open');
  final define = !args.contains('--no-define');
  final glossary = !args.contains('--no-glossary');
  final form = [for (final a in args) if (a.startsWith('--glossary=')) a.substring(11)].lastOrNull ?? 'signatures';
  if (form != 'names' && form != 'signatures') {
    stderr.writeln('--glossary= takes names or signatures, not $form.');
    exit(2);
  }
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
  // The words the design system defines in the notation (its
  // vocabulary/*.txt): the taught prompt lists their signatures, as it lists
  // components; the open prompt does not (a definition gives a meaning to
  // the word a model writes unprompted).
  final defined = i >= 0 && i + 1 < args.length && !open ? definitionLines(NotationVocabulary(definitions: readDefinitions(loadDefinitionTexts(args[i + 1])).words)) : const <String>[];
  stdout.writeln(Catalog.run(
    catalog,
    () => notationPrompt(
      catalog: catalog,
      // The design system's defined words, for the glossary to name.
      options: ds == null ? NotationOptions(width: width) : NotationOptions.fromDesignSystem(ds, width: width).define(loadDefinitionTexts(args[i + 1])),
      designSystem: ds,
      open: open,
      define: define,
      glossary: glossary,
      signatures: form == 'signatures',
    ),
  ));
  // Where what the writer reached for goes: the record every expand saves
  // (vocabulary_record.dart). Said after the prompt, which the API writes.
  if (open) {
    stdout
      ..writeln()
      ..writeln(openRecordNote)
      ..writeln()
      ..writeln(openSiteNote);
  }
  if (defined.isNotEmpty) {
    stdout
      ..writeln()
      ..writeln('WORDS (${ds?.name ?? 'defined'}: written like a component; each stands for plain lines)')
      ..writeln('  Written like any node: Name "text" key=value onEvent={actions}; the values shown are the defaults. One with (children) takes lines indented under it; (children: Front: Back) takes them under a Front and a Back line.')
      ..writeAll(defined.map((l) => '  $l\n'));
  }
}
