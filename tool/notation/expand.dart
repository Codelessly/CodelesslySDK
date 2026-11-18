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

import 'notation_site.dart';
import 'vocabulary.dart' show loadVocabulary;

const _usage = 'usage: expand.dart <file.txt> [--design-system <folder>] [--named] [--nearest-colors] [--id <canvas id>] [--width <canvas width>] [--no-reflow] '
    '[--site <site.json or folder>] [--no-site] [--out <file.json>] [--open [--vocabulary <file.json>]] [--aliases <file.json>]\n'
    '       expand.dart <site folder or site.json> [--width <page width>] [--no-reflow] [--design-system <folder>] [--named] [--nearest-colors]';

Future<void> main(List<String> args) async {
  String? opt(String name) {
    final i = args.indexOf(name);
    return i < 0 || i + 1 >= args.length ? null : args[i + 1];
  }

  final valued = {'--design-system', '--id', '--width', '--site', '--out', '--vocabulary', '--aliases'};
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

  final sitePath = args.contains('--no-site') && !whole
      ? null
      : whole
          ? findSiteManifest(site: target)
          : findSiteManifest(site: opt('--site'), out: opt('--out'), file: target);
  final site = sitePath == null ? null : await NotationSite.load(sitePath);
  for (final p in site?.problems ?? const <String>[]) {
    stderr.writeln(p);
  }
  if (whole && (site == null || site.manifest.isEmpty)) exit(2);

  ExpandSettings settings(double width) => (
        width: width,
        reflow: !args.contains('--no-reflow'),
        named: args.contains('--named'),
        nearestColors: args.contains('--nearest-colors'),
        open: open,
        aliases: aliases,
      );

  if (whole) {
    exit(_expandSite(site!, ds, settings(double.tryParse(opt('--width') ?? '') ?? 1440)));
  }

  final file = target;
  // One page of a site is expanded as the whole site's expansion expands it:
  // its canvas named after its file and 1440 wide (alone it was `screen` at
  // 390, which the site's render then did not find: test 9, mail).
  String canonical(String p) => File(p).absolute.path.replaceAll(r'\', '/').toLowerCase();
  final page = site == null ? null : site.pageSources.where((p) => canonical(p) == canonical(file)).firstOrNull;
  final pageName = page == null ? null : File(page).uri.pathSegments.last.replaceFirst(RegExp(r'\.txt$'), '');
  final width = double.tryParse(opt('--width') ?? '') ?? (pageName != null ? 1440 : 390);
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
  for (final issue in result.issues) {
    stderr.writeln('$file: $issue');
  }
  for (final m in more) {
    stderr.writeln('$file: $m');
  }
  if (site == null && ds == null && result.issues.any((i) => RegExp(r'^No node type "[A-Z]').hasMatch(i.message))) {
    stderr.writeln('$file: no site.json was found beside this file or above it, so no site\'s components are known: '
        'put the file in the site\'s folder (pages/ or components/ beside site/site.json), or name the site with --site <site.json or folder>.');
  }
  if (opt('--vocabulary') case final record?) {
    File(record).writeAsStringSync('${const JsonEncoder.withIndent(' ').convert([for (final u in result.vocabulary) u.toJson()])}\n');
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
  if (result.issues.isNotEmpty || more.isNotEmpty) exitCode = 1;
}

/// Expands every notation component and page of [site]; the exit status.
int _expandSite(NotationSite site, DesignSystem? ds, ExpandSettings settings) {
  final expander = NotationExpander(site: site, designSystem: ds, settings: settings);
  var issues = 0;
  const encoder = JsonEncoder.withIndent(' ');
  String rel(String path) {
    final p = File(path).absolute.path.replaceAll(r'\', '/');
    final home = File(site.dir).parent.path.replaceAll(r'\', '/');
    return p.startsWith('$home/') ? p.substring(home.length + 1) : p;
  }

  void report(String source, String out, NotationResult r, Json document, List<String> more) {
    File(out).parent.createSync(recursive: true);
    File(out).writeAsStringSync(encoder.convert(document));
    final n = r.issues.length + more.length;
    stdout.writeln('${rel(source)} -> ${rel(out)}${n == 0 ? '' : ' ($n issue${n == 1 ? '' : 's'})'}');
    for (final i in r.issues) {
      stderr.writeln('${rel(source)}: $i');
    }
    for (final m in more) {
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
      issues++;
    }
  }
  for (final (i, p) in expanded.pages.indexed) {
    report(p.path, site.pageOut(p.path), expanded.results[i], p.document, about(p.path));
    if (!site.screens.contains(p.name)) {
      stderr.writeln('${rel(p.path)}: site.json\'s pages do not list ${p.name}: add "${p.name}.json" there, or the site does not have it.');
      issues++;
    }
  }
  // What is about a file not written here (a JSON component).
  for (final e in said.entries) {
    for (final m in e.value) {
      stderr.writeln('${rel(e.key)}: $m');
      issues++;
    }
  }
  if (order.isEmpty && site.pageSources.isEmpty) {
    stderr.writeln('${site.manifestPath}: no pages/*.txt or components/*.txt in the site\'s folder or beside it.');
    return 1;
  }
  return issues == 0 ? 0 : 1;
}
