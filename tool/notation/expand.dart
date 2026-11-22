// Expands a UI written in the compact notation
// (package:codelessly_api/notation.dart) into a layout document.
//
//   dart run tool/notation/expand.dart <file.txt> [--design-system <folder>] [--named] [--nearest-colors] [--id <canvas id>] [--width <canvas width>] [--no-reflow] [--site <site.json or folder>] [--no-site] [--out <file.json>]
//   dart run tool/notation/expand.dart <site folder or site.json> [--width <page width>] [--no-reflow] [--design-system <folder>] [--named] [--nearest-colors]
//
// With --design-system (a folder holding design_system.json) the notation
// may call that design system's components by name and takes its looks.
// With --named as well, a look the theme names is written as that name (as
// a UiSession writes it: the document follows dark mode and the theme); a
// color the notation writes stays as written. --nearest-colors (with --named)
// reads a written color as the theme's nearest color too: a dark design on a
// light theme then loses its own panel colors.
// A page (--width 700 or more) is given the media rules that lay it out on a
// tablet and a phone; --no-reflow leaves it written for its one width.
//
// A file that belongs to a site (notation_site.dart: the site.json --site
// names, else the one beside --out, else a site.json or site/site.json
// beside the file or up to two folders above it; --no-site: none) is
// expanded with what the site gives it: its variables (the page and its
// components use them by name and declare none of them), its pages (the
// screens a bare `go name` names), its theme (the looks a line takes when it
// says none, written by the theme's names; `style=` and `from=` name its
// text styles) and its components, callable by name: those written in the
// notation (components/*.txt in the site's folder or beside it, expanded
// first, each after those it calls) and the expanded ones site.json lists.
//
// Given the site itself (its folder, its project folder or its site.json),
// expand writes the whole site: every components/*.txt to the JSON
// site.json lists for it (else site/components/<Name>.json), then every
// pages/*.txt to site/<name>.json (or the page site.json lists by that
// name) with its file name as the canvas id, each page --width wide
// (default 1440). It says one line per file and every issue, and exits 1
// when there is any. An overlay two pages write with one id (`Drawer#nav`)
// and draw differently is made each page's own (`nav--board`, what names it
// on that page following, a component's `open nav` opening the calling
// page's): site_overlays.dart says how.
//
// What the notation could not read is written to stderr, one line each;
// the exit status is 1 when there is any.
//
// With --open the vocabulary is open (codelessly_api
// docs/design/19-open-vocabulary.md): a word the notation does not have is
// not an error, it stands in (a type) or is left out (a parameter, a flag,
// an event, an action verb), and each is said on stderr (a placeholder with
// what to write), without failing the expand. The aliases (names read as a
// word we have) are the built-in ones and the design system's
// vocabulary.json; --aliases <file.json> adds a table over both.
//
// Every expand, open or closed, saves the vocabulary record
// (vocabulary_record.dart says what it holds): every word the files used
// and how each resolved, kept across expands. A site's (the folder, or one
// of its files) is <the site's folder>/vocabulary.json and VOCABULARY.md; a
// file of no site's is <file without .txt>.vocabulary.json and
// .VOCABULARY.md beside it; --vocabulary <file.json> puts it there instead;
// --no-record saves nothing. It does not change what is expanded.
//
// A site's components/*.txt that starts with `define <Name> …` (or
// `primitive`) is the site's definitions: every page and component reads
// them, as a page reads a define written after its last line. A
// components/*.txt that is neither that nor a component, a second file of
// one component, and a component JSON site.json lists that nothing writes
// are an issue in every mode, --open too: they were skipped with no word. A
// definition or a component of a name the notation already has (`Card`,
// `Rail`, `Shortcut`) is not used, the notation's word is, and that is an
// issue at the definition. A page whose first line is one `### Name` is
// read without it.
import 'dart:convert';
import 'dart:io';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_api/notation.dart';
import 'package:codelessly_api/notation_site.dart' show notationBuiltKey;

import 'notation_site.dart';
import 'dictionary.dart';
import 'vocabulary.dart' show loadVocabulary;
import 'formula_check.dart';
import 'vocabulary_record.dart';

const _usage = 'usage: expand.dart <file.txt> [--design-system <folder>] [--named] [--nearest-colors] [--id <canvas id>] [--width <canvas width>] [--no-reflow] '
    '[--site <site.json or folder>] [--no-site] [--out <file.json>] [--open] [--vocabulary <file.json> | --no-record] [--aliases <file.json>]\n'
    '       expand.dart <site folder or site.json> [--width <page width>] [--no-reflow] [--design-system <folder>] [--named] [--nearest-colors] [--open] [--vocabulary <file.json> | --no-record]';

/// Said when a site (or one of its pages) is expanded at the default width.
const _defaultWidthNote = 'note: the site is expanded 1440 wide (the default for a site; no --width given), so every page and component is read as '
    'a desktop design and reflow gives it rules for a tablet (tablet.…, up to 1023 px wide) and a phone (phone.…, up to 699), which hold on a '
    'phone-sized render too (a Row whose children may wrap gets tablet.wrap=true). For a site designed for a phone, expand with --width 390; '
    '--no-reflow keeps 1440 without those rules.';

Future<void> main(List<String> args) async {
  String? opt(String name) {
    final i = args.indexOf(name);
    return i < 0 || i + 1 >= args.length ? null : args[i + 1];
  }

  final valued = {'--design-system', '--id', '--width', '--site', '--out', '--vocabulary', '--aliases', '--dictionary'};
  final positional = <String>[];
  for (var i = 0; i < args.length; i++) {
    if (valued.contains(args[i])) {
      i++;
    } else if (!args[i].startsWith('--')) {
      positional.add(args[i]);
    }
  }
  final target = positional.firstOrNull;
  if (target == null || FileSystemEntity.typeSync(target) == FileSystemEntityType.notFound) {
    stderr.writeln(_usage);
    exit(2);
  }
  final whole = FileSystemEntity.isDirectorySync(target) || target.replaceAll(r'\', '/').endsWith('/${SiteManifest.fileName}') || target == SiteManifest.fileName;

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
  final open = args.contains('--open');
  final NotationVocabulary aliases;
  try {
    aliases = loadVocabulary(dir: opt('--design-system'), file: opt('--aliases'));
  } on Object catch (e) {
    stderr.writeln('The alias table does not load: $e');
    exit(2);
  }
  // The dictionaries --dictionary names (or CODELESSLY_DICTIONARY lists),
  // under the design system's definitions; a site's own are added under
  // these as it is expanded (NotationExpander).
  final dictionaries = dictionaryFolders(args);
  for (final d in dictionaries) {
    if (!FileSystemEntity.isDirectorySync(d)) {
      stderr.writeln('--dictionary $d: no such folder.');
      exit(2);
    }
  }
  final words = withDictionaries(aliases, dictionaries, say: stderr.writeln);

  final sitePath = args.contains('--no-site') && !whole
      ? null
      : whole
          ? findSiteManifest(site: target)
          : findSiteManifest(site: opt('--site'), out: opt('--out'), file: target);
  final site = sitePath == null ? null : await NotationSite.load(sitePath);
  for (final p in site?.problems ?? const <String>[]) {
    stderr.writeln(p);
  }
  // A site is a folder of notation (pages/, components/, app.txt), with a
  // site.json or none.
  if (whole && (site == null || !site.isSite)) {
    if (site != null && site.problems.isEmpty) {
      stderr.writeln('$target: no site here: a site is a folder with pages/<screen>.txt (and components/<Word>.txt, app.txt, site.json as it needs them).');
    }
    exit(2);
  }
  // What the site's components/ has that is not loaded or not used: an
  // issue in every mode, --open too (the owner's decision, 2026-11-18).
  var skippedIssues = 0;
  for (final s in site?.skipped ?? const <SkippedComponent>[]) {
    stderr.writeln(s.message);
    skippedIssues++;
  }
  // What app.txt (the app's shared state) has that is not read.
  final appIssues = <Map<String, Object?>>[
    for (final i in site?.appStateIssues ?? const <({int line, String message})>[]) {'file': recordPath(site!.appStatePath!, site.home), 'line': i.line, 'message': i.message},
  ];
  for (final i in appIssues) {
    stderr.writeln('${i['file']}: line ${i['line']}: ${i['message']}');
    skippedIssues++;
  }
  // --validate: nothing is written (no document, no record); what an expand
  // would say is printed on stdout as JSON (validationOf), and the exit
  // status is the expand's.
  final validate = args.contains('--validate');
  final skipped = [
    for (final s in site?.skipped ?? const <SkippedComponent>[]) {'file': site == null ? s.path : recordPath(s.path, site.home), 'message': s.message},
  ];
  final record = !args.contains('--no-record') && !validate;
  final components = {for (final c in ds?.list ?? const <DesignSystemComponent>[]) c.type, for (final c in site?.designSystem?.list ?? const <DesignSystemComponent>[]) c.type};

  ExpandSettings settings(double width) => (
        width: width,
        reflow: !args.contains('--no-reflow'),
        named: args.contains('--named'),
        nearestColors: args.contains('--nearest-colors'),
        open: open,
        aliases: words,
      );

  // A site has no width of its own: with no --width it is read as a
  // desktop's, and reflow's tablet rules (up to 1023) hold on a phone too
  // (the NOCD chat's quote bars wrapped at 390). Said, not guessed.
  if (whole && opt('--width') == null && !args.contains('--no-reflow')) stderr.writeln(_defaultWidthNote);
  if (whole) {
    // (Not exit: what runs this as a command of its own, tool/notation/main.dart, says its timings after it.)
    exitCode = _expandSite(site!, ds, settings(double.tryParse(opt('--width') ?? '') ?? 1440),
        skippedIssues: skippedIssues, record: record ? opt('--vocabulary') ?? '${site.home}/vocabulary.json' : null, components: components, validate: validate, skipped: skipped, appIssues: appIssues);
    return;
  }

  final file = target;
  // One page of a site is expanded as the whole site's expansion expands it:
  // its canvas named after its file and 1440 wide (alone it was `screen` at
  // 390, which the site's render then did not find: test 9, mail).
  String canonical(String p) => File(p).absolute.path.replaceAll(r'\', '/').toLowerCase();
  final page = site == null ? null : site.pageSources.where((p) => canonical(p) == canonical(file)).firstOrNull;
  final pageName = page == null ? null : File(page).uri.pathSegments.last.replaceFirst(RegExp(r'\.txt$'), '');
  final width = double.tryParse(opt('--width') ?? '') ?? (pageName != null ? 1440 : 390);
  if (pageName != null && opt('--width') == null && !args.contains('--no-reflow')) stderr.writeln(_defaultWidthNote);
  final expander = NotationExpander(site: site, designSystem: ds, settings: settings(width));
  final result = expander.expand(File(file).readAsStringSync(), path: file, screen: opt('--id') ?? pageName ?? 'screen');
  // A page's overlays as the whole site's expansion gives them: one two
  // pages write with one id and draw differently is the page's own
  // (site_overlays.dart), which only the other pages can say.
  var document = result.document;
  final more = <String>[];
  if (page != null && opt('--id') == null) {
    final whole = expandSitePages(NotationExpander(site: site, designSystem: ds, settings: settings(width)), site!);
    final i = whole.pages.indexWhere((p) => canonical(p.path) == canonical(page));
    if (i >= 0) document = whole.pages[i].document;
    for (final s in whole.scoping.issues) {
      if (canonical(s.path) == canonical(page)) more.add(s.message);
    }
  }
  for (final (type, r) in expander.failedComponents) {
    stderr.writeln('${site!.sources[type]!.path}: the component $type does not expand cleanly (${r.issues.length} issue${r.issues.length == 1 ? '' : 's'}; first: ${r.issues.first}): expand it alone to see them all.');
  }
  final text = File(file).readAsStringSync();
  // A formula the engine cannot parse gives nothing: said where it was
  // written (formula_check.dart), unless an issue of its line said it.
  more.addAll(formulaNotes(document, {file: text, for (final e in site?.definitionFiles.entries ?? const <MapEntry<String, String>>[]) e.key: e.value}, site: site?.variables ?? const {},
      said: {for (final i in result.issues) '$file:${i.line}'}));
  // A variable null with no type (text) read by a field: it reads nothing.
  more.addAll(nullTextVariableNotes(document, site: site?.variables ?? const {}));
  for (final i in result.issues) {
    stderr.writeln('$file: line ${i.line}:${i.column}: ${site?.placeDefinitionLine(i.message, text) ?? i.message}');
  }
  for (final m in more) {
    stderr.writeln('$file: $m');
  }
  if (site == null && ds == null && result.issues.any((i) => RegExp(r'^No node type "[A-Z]').hasMatch(i.message))) {
    stderr.writeln('$file: no site.json was found beside this file or above it, so no site\'s components are known: '
        'put the file in the site\'s folder (pages/ or components/ beside site/site.json), or name the site with --site <site.json or folder>.');
  }
  // What the file ends with that is not an issue: a placeholder, a word left
  // out, a page split by `###` lines.
  final notes = [...vocabularyNotes(result, site: site), if (componentTypeOf(text) == null) ?pageHeadingsNote(text)];
  for (final n in notes) {
    stderr.writeln('$file: $n');
  }
  if (validate) {
    final dir = site?.home ?? File(file).parent.path;
    final snap = siteSnapshot(site, components: components, open: open, dir: dir)
      ..file(recordPath(file, dir), text, result, notes: notes, extra: site?.definitionText, page: componentTypeOf(text) ?? opt('--id') ?? pageName ?? 'screen');
    final issues = [
      for (final i in result.issues) {'file': recordPath(file, dir), 'line': i.line, 'column': i.column, 'message': site?.placeDefinitionLine(i.message, text) ?? i.message},
      for (final m in more) {'file': recordPath(file, dir), 'message': m},
      for (final s in skipped) {'file': s['file'], 'message': s['message']},
      ...appIssues,
    ];
    stdout.writeln(const JsonEncoder.withIndent(' ').convert(validationOf(snap, issues: issues, skipped: skipped)));
    if (issues.isNotEmpty) exitCode = 1;
    return;
  }
  if (record) {
    // The record: the site's, or the file's own beside it.
    final dir = site?.home ?? File(file).parent.path;
    final path = opt('--vocabulary') ?? (site != null ? '$dir/vocabulary.json' : '${file.replaceFirst(RegExp(r'\.txt$'), '')}.vocabulary.json');
    final snap = siteSnapshot(site, components: components, open: open, dir: dir)
      ..file(recordPath(file, dir), text, result, notes: notes, extra: site?.definitionText, page: componentTypeOf(text) ?? opt('--id') ?? pageName ?? 'screen');
    final mdPath = opt('--vocabulary') == null && site == null ? '${file.replaceFirst(RegExp(r'\.txt$'), '')}.VOCABULARY.md' : null;
    final saved = saveRecord(path, snap, mdPath: mdPath);
    final held = placeholdersOf(result, file, text: text);
    if (held.isNotEmpty || leftOutOf(result) > 0) {
      for (final l in placeholderLines(held, leftOut: leftOutOf(result), record: saved)) {
        stderr.writeln(l);
      }
    }
  } else if (open) {
    for (final u in result.vocabulary) {
      stderr.writeln('$file: vocabulary: $u');
    }
  }
  final json = const JsonEncoder.withIndent(' ').convert(document);
  if (opt('--out') case final out?) {
    // A folder that is not there yet is made (it was a stack trace).
    File(out)
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(json);
  } else {
    stdout.writeln(json);
  }
  if (result.issues.isNotEmpty || more.isNotEmpty || skippedIssues > 0) exitCode = 1;
}

/// Expands every notation component and page of [site]; the exit status.
/// [skippedIssues]: the component files not loaded that count as issues.
/// [record]: where the vocabulary record goes (null: none).
int _expandSite(NotationSite site, DesignSystem? ds, ExpandSettings settings,
    {int skippedIssues = 0,
    String? record,
    Set<String> components = const {},
    bool validate = false,
    List<Map<String, Object?>> skipped = const [],
    List<Map<String, Object?>> appIssues = const []}) {
  final expander = NotationExpander(site: site, designSystem: ds, settings: settings);
  var issues = skippedIssues;
  // With --validate stdout is the JSON alone: the lines go to stderr.
  final say = validate ? stderr : stdout;
  final found = <Map<String, Object?>>[
    for (final s in skipped) {'file': s['file'], 'message': s['message']},
    ...appIssues,
  ];
  final snap = siteSnapshot(site, components: components, open: settings.open, dir: site.home);
  // The app's state file: read by every page and component, written to no
  // JSON of its own (its variables go in the manifest a render reads).
  if (site.appStatePath case final app?) {
    final names = site.appState!.variables.keys.toList();
    say.writeln('${recordPath(app, site.home)} -> ${names.isEmpty ? 'declares nothing' : 'declares ${names.join(', ')} (every page and component reads ${names.length == 1 ? 'it' : 'them'})'}');
  }
  final held = <Placeholder>[];
  var leftOut = 0;
  const encoder = JsonEncoder.withIndent(' ');
  String rel(String path) {
    final p = File(path).absolute.path.replaceAll(r'\', '/');
    final home = File(site.dir).parent.path.replaceAll(r'\', '/');
    return p.startsWith('$home/') ? p.substring(home.length + 1) : p;
  }

  void report(String source, String out, NotationResult r, Json document, List<String> more) {
    final text = File(source).readAsStringSync();
    // A formula the engine cannot parse gives nothing: said where it was
    // written (formula_check.dart), unless an issue of its line said it.
    more = [
      ...more,
      ...formulaNotes(document, {rel(source): text, for (final e in site.definitionFiles.entries) rel(e.key): e.value}, site: site.variables,
          said: {for (final i in r.issues) '${rel(source)}:${i.line}'}),
      // A variable null with no type (text) read by a field: it reads nothing.
      ...nullTextVariableNotes(document, site: site.variables),
    ];
    final notes = [...vocabularyNotes(r, site: site), if (componentTypeOf(text) == null) ?pageHeadingsNote(text)];
    final type = componentTypeOf(text);
    snap.file(recordPath(source, site.home), text, r, notes: notes, extra: site.definitionText, page: type ?? pageNameOf(source));
    held.addAll(placeholdersOf(r, rel(source), text: text));
    leftOut += leftOutOf(r);
    if (!validate) {
      File(out).parent.createSync(recursive: true);
      File(out).writeAsStringSync(encoder.convert(document));
    }
    final n = r.issues.length + more.length;
    for (final i in r.issues) {
      found.add({'file': recordPath(source, site.home), 'line': i.line, 'column': i.column, 'message': site.placeDefinitionLine(i.message, text)});
    }
    for (final m in more) {
      found.add({'file': recordPath(source, site.home), 'message': m});
    }
    say.writeln('${rel(source)} -> ${rel(out)}${n == 0 ? '' : ' ($n issue${n == 1 ? '' : 's'})'}');
    for (final i in r.issues) {
      stderr.writeln('${rel(source)}: line ${i.line}:${i.column}: ${site.placeDefinitionLine(i.message, text)}');
    }
    for (final m in more) {
      stderr.writeln('${rel(source)}: $m');
    }
    for (final m in notes) {
      stderr.writeln('${rel(source)}: $m');
    }
    issues += n;
  }

  final cycles = <List<String>>[];
  final order = site.ordered(cycles);
  for (final c in cycles) {
    stderr.writeln('The components ${c.join(' -> ')} call each other: each is expanded with the others it can see.');
    issues++;
  }
  final listed = site.componentRefs;
  // The site's definitions (components/*.txt of `define` blocks): read by
  // every page and component, written to no JSON of their own.
  for (final e in site.definitionFiles.entries) {
    final words = site.definedWords.entries.where((w) => w.value == e.key).map((w) => w.key).toList()..sort();
    final builtIn = [for (final w in readPageDefinitions(e.value).words.keys) if (!words.contains(w)) w];
    say.writeln('${rel(e.key)} -> ${words.isEmpty ? 'defines nothing used' : 'defines ${words.join(', ')} (every page and component reads it)'}'
        '${builtIn.isEmpty ? '' : '; ${builtIn.join(', ')}: the notation\'s word, this definition not used'}');
  }
  final expanded = expandSitePages(expander, site, order: order);
  // Overlays two pages write with one id and draw differently are each
  // page's own (site_overlays.dart): before, one page's was every page's
  // (the board's drawer showed the archive page's sidebar: test 9, kanban
  // 9), with no word.
  final said = <String, List<String>>{};
  for (final i in expanded.scoping.issues) {
    said.putIfAbsent(File(i.path).absolute.path, () => []).add(i.message);
  }
  List<String> about(String path) => said.remove(File(path).absolute.path) ?? const [];
  for (final c in expanded.components) {
    report(c.path, site.componentOut(c.type), expanded.componentResults[c.type]!, c.document, about(c.path));
    if (readStrings(site.manifest['components']).isNotEmpty && !listed.containsKey(c.type)) {
      stderr.writeln('${rel(c.path)}: site.json\'s components do not list ${c.type}: add "components/${c.type}.json" there, or the site does not have it.');
      found.add({'file': recordPath(c.path, site.home), 'message': 'site.json\'s components do not list ${c.type}.'});
      issues++;
    }
  }
  for (final (i, p) in expanded.pages.indexed) {
    report(p.path, site.pageOut(p.path), expanded.results[i], p.document, about(p.path));
    // (A site whose manifest lists no pages, or that has none, shows every
    // page there is: `home` first, then by name.)
    if (site.listedScreens.isNotEmpty && !site.listedScreens.contains(p.name)) {
      stderr.writeln('${rel(p.path)}: site.json\'s pages do not list ${p.name}: add "${p.name}.json" there, or the site does not have it.');
      found.add({'file': recordPath(p.path, site.home), 'message': 'site.json\'s pages do not list ${p.name}.'});
      issues++;
    }
  }
  // A notation file site.json lists: its JSON went beside it, not over it (NotationSite.jsonRef).
  for (final r in site.listedNotation) {
    final json = NotationSite.jsonRef(r);
    final m = 'site.json lists "$r", the notation itself: its expansion is written to "$json", not over it. '
        'List "$json" there: site.json names the JSON documents, which the render reads.';
    stderr.writeln('site.json: $m');
    found.add({'file': 'site.json', 'message': m});
    issues++;
  }
  // What is about a file not written here (a JSON component).
  for (final e in said.entries) {
    for (final m in e.value) {
      stderr.writeln('${rel(e.key)}: $m');
      found.add({'file': recordPath(e.key, site.home), 'message': m});
      issues++;
    }
  }
  if (validate) {
    stdout.writeln(const JsonEncoder.withIndent(' ').convert(validationOf(snap, issues: found, skipped: skipped)));
    if (held.isNotEmpty || leftOut > 0) {
      for (final l in placeholderLines(held, leftOut: leftOut)) {
        stderr.writeln(l);
      }
    }
    return issues == 0 ? 0 : 1;
  }
  // The manifest a render reads: the site's own with app.txt's state among
  // its variables, or the whole of it for a site that has none.
  if (site.builtManifest case final built?) {
    final text = '${encoder.convert(built)}\n';
    if (text != site.manifestAsRead) {
      File(site.manifestPath)
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(text);
    }
    say.writeln(site.hasManifest
        ? '${rel(site.manifestPath)}: app.txt\'s state written among its variables (what a render reads)'
        : '${rel(site.manifestPath)}: written (the pages in order${site.appVariables.isEmpty ? '' : ' and app.txt\'s state'}: what a render reads)');
  } else if (site.manifestAsRead != null && site.hasManifest && site.manifestAsRead!.contains('"$notationBuiltKey"')) {
    // What an earlier expand wrote there and app.txt no longer declares.
    File(site.manifestPath).writeAsStringSync('${encoder.convert(site.manifest)}\n');
  }
  if (record != null) {
    final saved = saveRecord(record, snap, whole: true);
    stdout.writeln('vocabulary record: ${rel(saved)}');
    if (held.isNotEmpty || leftOut > 0) {
      for (final l in placeholderLines(held, leftOut: leftOut, record: rel(saved))) {
        stderr.writeln(l);
      }
    }
  } else if (held.isNotEmpty || leftOut > 0) {
    for (final l in placeholderLines(held, leftOut: leftOut)) {
      stderr.writeln(l);
    }
  }
  if (order.isEmpty && site.pageSources.isEmpty) {
    stderr.writeln('${site.manifestPath}: no pages/*.txt or components/*.txt in the site\'s folder or beside it.');
    return 1;
  }
  return issues == 0 ? 0 : 1;
}
