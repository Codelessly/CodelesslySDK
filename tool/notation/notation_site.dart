// What `expand` knows of the site a notation file belongs to: its variables
// (read by bare name, never declared again on a page or in a component), its
// pages (the screens a bare `go name` names), its theme (the looks a line
// takes when it says none, and the text styles `style=` and `from=` name)
// and its components (callable by name, as components.md says), whether
// they are written in the notation (`components/*.txt`) or expanded
// (`site.json`'s `components`, else `components/*.json`).
//
// A site is a folder of notation: `pages/*.txt`, `components/*.txt` and
// `app.txt` (the state its pages share, as `state` lines), with a
// `site.json` when it wants a theme of its own or a page order, and none
// otherwise. A notation file belongs to the site `--site` names, else the
// one beside `--out`, else the first `site.json` or `site/site.json` found
// beside the file or above it (its folder and the two above it), else the
// folder whose `pages/` or `components/` it is in, or the first with an
// `app.txt`: the layout
//
//   my-site/
//     pages/home.txt          → site/home.json
//     components/Card.txt     → site/components/Card.json
//     app.txt                 → the variables of site/site.json
//     site/site.json          the site's own, or written by expand
//
// and a site folder that holds its notation itself (`site/pages/*.txt`,
// `site/components/*.txt`) both work. The manifest a render reads is the
// site's own with app.txt's state among its variables, or, for a site with
// none, one `expand` writes whole (codelessly_api notationBuiltManifest:
// marked `"expand"`, never read back as the site's source).
import 'dart:convert';
import 'dart:io';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_api/notation.dart';
import 'package:codelessly_api/notation_site.dart'
    show notationAppStatePath, notationBuiltManifest, notationPageOrder, notationSiteVariables, notationSourceManifest;

import '../render/src/site.dart' show sitePath;
import 'dictionary.dart';
import 'site_overlays.dart';

export 'site_overlays.dart';

/// The `site.json` a notation [file] belongs to: [site] (a manifest, or a
/// folder holding one as `site.json` or `site/site.json`), else the one
/// beside [out], else the first beside [file] or up to two folders above it.
/// Null: the file is expanded alone.
///
/// A site needs no site.json: a folder that holds `pages/*.txt`,
/// `components/*.txt` or `app.txt` ([isSiteFolder]) is one, and its manifest
/// is then the one `expand` writes, `site/site.json` in it (not there until
/// the folder is expanded). A file in such a folder's `pages/` or
/// `components/`, or beside or under its `app.txt`, belongs to it when no
/// site.json is found.
String? findSiteManifest({String? site, String? out, String? file}) {
  String? at(String dir) {
    for (final c in ['$dir/${SiteManifest.fileName}', '$dir/site/${SiteManifest.fileName}']) {
      if (File(c).existsSync()) return c;
    }
    return null;
  }

  if (site != null) {
    if (FileSystemEntity.isDirectorySync(site)) {
      return at(site) ?? (isSiteFolder(site) ? '$site/site/${SiteManifest.fileName}' : '$site/${SiteManifest.fileName}');
    }
    return site;
  }
  if (out != null) {
    final beside = '${File(out).absolute.parent.path}/${SiteManifest.fileName}';
    if (File(beside).existsSync()) return beside;
  }
  if (file != null) {
    var d = File(file).absolute.parent;
    for (var i = 0; i < 3; i++) {
      if (at(d.path) case final m?) return m;
      final up = d.parent;
      if (up.path == d.path) break;
      d = up;
    }
    // No site.json: the folder whose pages/ or components/ the file is in,
    // or the first with an app.txt.
    final parent = File(file).absolute.parent;
    final folder = parent.uri.pathSegments.where((s) => s.isNotEmpty).lastOrNull;
    if ((folder == 'pages' || folder == 'components') && isSiteFolder(parent.parent.path)) {
      return '${parent.parent.path}/site/${SiteManifest.fileName}';
    }
    d = parent;
    for (var i = 0; i < 3; i++) {
      if (File('${d.path}/$notationAppStatePath').existsSync()) return '${d.path}/site/${SiteManifest.fileName}';
      final up = d.parent;
      if (up.path == d.path) break;
      d = up;
    }
  }
  return null;
}

/// Whether [dir] holds a site's notation: `pages/*.txt`, `components/*.txt`
/// or `app.txt`. What makes a folder a site when it has no site.json.
bool isSiteFolder(String dir) {
  bool notation(String d) => Directory(d).existsSync() && Directory(d).listSync().any((f) => f is File && f.path.endsWith('.txt'));
  return notation('$dir/pages') || notation('$dir/components') || File('$dir/$notationAppStatePath').existsSync();
}

/// A component written in the notation: its type (the name on its
/// `component` line), its file and its text.
typedef ComponentSource = ({String type, String path, String text});

/// A component file the site does not load: its path, the type it would
/// have been (its `define`'s word, else its file name) and what to write.
typedef SkippedComponent = ({String path, String type, String message});

/// A site as `expand` reads it ([load]).
final class NotationSite {
  NotationSite._(this.manifestPath, this.manifest, this.problems, {this.hasManifest = true, this.manifestAsRead});

  /// Whether the site has a manifest of its own: false when there is no
  /// site.json, or the one there is the one `expand` wrote whole
  /// (codelessly_api `notationSourceManifest`).
  final bool hasManifest;

  /// The text of the manifest's file as it was read; null when there is none.
  final String? manifestAsRead;

  /// The app's state file: `app.txt` beside the pages read, else in the
  /// site's folder or beside it; null when the site has none.
  late final String? appStatePath = () {
    final beside = pageSources.isEmpty ? null : '${File(pageSources.first).parent.parent.path}/$notationAppStatePath';
    for (final p in [?beside, for (final h in _homes.reversed) '$h/$notationAppStatePath']) {
      if (File(p).existsSync()) return p;
    }
    return null;
  }();

  /// What the app's state file declares (codelessly_api
  /// `readNotationAppState`); null when the site has none.
  late final NotationAppState? appState = appStatePath == null ? null : readNotationAppState(File(appStatePath!).readAsStringSync(), catalog: standardCatalog);

  /// What app.txt has that is not read, and each name it declares that
  /// site.json's variables declare too (app.txt's is used), by line.
  late final List<({int line, String message})> appStateIssues = () {
    final out = <({int line, String message})>[for (final i in appState?.issues ?? const <NotationIssue>[]) (line: i.line, message: i.message)];
    notationSiteVariables(manifest['variables'], appState, say: (line, message) => out.add((line: line, message: message)));
    return out..sort((a, b) => a.line - b.line);
  }();

  /// app.txt's state by name, as [variables] has it.
  Map<String, Json> get appVariables => {
        for (final name in appState?.variables.keys ?? const <String>[])
          if (variables[name] case final v?) name: v,
      };

  /// The manifest a render reads the site's variables from when it is not
  /// the site's own as written (codelessly_api `notationBuiltManifest`):
  /// the whole manifest of a site with none, or the site's with app.txt's
  /// state among its variables. Null: nothing to write.
  Json? get builtManifest => notationBuiltManifest(
        source: hasManifest ? manifest : null,
        pages: notationPageOrder([for (final p in pageSources) _stem(p)]),
        appVariables: appVariables,
      );

  /// Whether there is a site here at all: a manifest of its own, or notation.
  bool get isSite => (hasManifest && manifest.isNotEmpty) || pageSources.isNotEmpty || sources.isNotEmpty || definitionFiles.isNotEmpty || appStatePath != null;

  /// The manifest's path.
  final String manifestPath;

  /// The manifest as read (empty when it is not JSON; [problems] says so).
  final Json manifest;

  /// What could not be read, one sentence each.
  final List<String> problems;

  /// The folder the manifest is in.
  String get dir => File(manifestPath).absolute.parent.path;

  /// The site's variables by name, as [NotationOptions.projectVariables]
  /// takes them.
  ///
  /// The manifest's `variables` and app.txt's state (codelessly_api
  /// `notationSiteVariables`): a name both declare is app.txt's
  /// ([appStateIssues] says so).
  late final Map<String, Json> variables = notationSiteVariables(manifest['variables'], appState);

  /// The ids of the pages the manifest lists (each page reference's file
  /// stem).
  late final List<String> listedScreens = [
    for (final p in SiteManifest.pageRefs(manifest['pages'])) _stem(p),
  ];

  /// The ids of its pages: the ones the manifest lists and the ones written
  /// in the notation (`pages/*.txt`), which a manifest with no `pages`
  /// leaves to the folder. A bare `go album` names the page `album` whether
  /// or not site.json lists it (with none listed it read a variable or a
  /// loop's item of that name instead: `"to": "${= item}"`).
  late final List<String> screens = {
    ...listedScreens,
    ...notationPageOrder([for (final p in pageSources) _stem(p)]),
  }.toList();

  /// The dictionaries the manifest names (`dictionary`: folders of
  /// definitions, relative to it), as paths.
  late final List<String> dictionaries = [
    for (final d in SiteManifest.fromJson(manifest).dictionary) File(d).isAbsolute ? d : '$dir/$d',
  ];

  /// The design system the manifest names (`designSystem`), loaded; null
  /// when it names none or it does not load ([problems] says why).
  DesignSystem? designSystem;

  /// The site's theme: its own over its design system's tokens.
  ThemeTokens get theme {
    final own = ThemeTokens.fromJson(manifest['theme']);
    return designSystem?.themeUnder(own) ?? own;
  }

  /// The folders a site's notation sits in: the site's own folder, and the
  /// folder it is in when that is the site's project (`my-site/site/`).
  List<String> get _homes => [dir, File(dir).parent.path];

  /// The folder the site's notation is written in: the one of [_homes]
  /// that holds `pages/` or `components/` (the writer's site folder, where
  /// `expand` keeps the vocabulary record), else the manifest's folder.
  String get home {
    bool notation(String d) => Directory(d).existsSync() && Directory(d).listSync().any((f) => f is File && f.path.endsWith('.txt'));
    for (final h in _homes) {
      if (notation('$h/pages') || notation('$h/components')) return h;
    }
    return dir;
  }

  /// The components written in the notation (`components/*.txt` in the
  /// site's folder or beside it), by type. A file that is not one is in
  /// [skipped], with why.
  late final Map<String, ComponentSource> sources = () {
    final out = <String, ComponentSource>{};
    for (final home in _homes) {
      final folder = Directory('$home/components');
      if (!folder.existsSync()) continue;
      final files = folder.listSync().whereType<File>().where((f) => f.path.endsWith('.txt')).toList()..sort((a, b) => a.path.compareTo(b.path));
      for (final f in files) {
        final text = f.readAsStringSync();
        final type = componentTypeOf(text);
        if (type == null) {
          // A file of `define` (or `primitive`) blocks is the site's
          // definitions: every page and component reads them, as a page
          // reads its own written after its last screen.
          if (_isDefinitions(text)) {
            _definitionFiles[f.path] = text;
            _checkDefinitions(f.path, text);
          } else {
            _skipped.add((path: f.path, type: _stem(f.path), message: _notAComponent(f.path, text)));
          }
          continue;
        }
        if (out[type] case final first?) {
          _skipped.add((
            path: f.path,
            type: type,
            message: '${_name(f.path)} writes component $type, which ${_name(first.path)} already writes: this file is not read. Give one of them another name.',
          ));
          continue;
        }
        out[type] = (type: type, path: f.path, text: text);
        // A component of a name the notation has: the notation's word is read
        // where it is written (a frame word, a core type), so a bare call does
        // not call it. Said at the component, once.
        if (notationBuiltInWord(type, catalog: standardCatalog) case final what?) {
          _skipped.add((
            path: f.path,
            type: type,
            message: '${_name(f.path)}: line 1: ${notationBuiltInDefinition(type, what, kind: 'component')} To call this component, write `$type type=$type`.',
          ));
        }
      }
    }
    return out;
  }();

  final List<SkippedComponent> _skipped = [];
  final Map<String, String> _definitionFiles = {};

  /// The `components/*.txt` that are `define` (or `primitive`) blocks, by
  /// path: each word they define is the site's, read by every page and
  /// component as a definition a page writes after its last screen
  /// (codelessly_api docs/design/20-defined-words.md). Its signature line
  /// is its signature: its strings, parameters with their defaults, `@`
  /// and events. A page's own definition of the word is read over it.
  Map<String, String> get definitionFiles {
    sources;
    return _definitionFiles;
  }

  /// [definitionFiles] as one text, for [parseNotation]'s `definitions`;
  /// null when there are none (the expansion is then as before).
  late final String? definitionText = definitionFiles.isEmpty ? null : definitionFiles.values.join('\n');

  /// [message] (an issue of [text], a file of the site) with a line of the
  /// site's definitions, which the parser names `page:63:` (a line of
  /// [definitionText]), named by its file: `components/KanbanCard.txt:2:`.
  /// A word [text] defines itself is its own line, left as it is.
  String placeDefinitionLine(String message, String text) {
    if (definitionFiles.isEmpty) return message;
    final m = RegExp(r'page:(\d+): ([A-Za-z_][A-Za-z0-9_]*):').firstMatch(message);
    if (m == null || readPageDefinitions(text).words.containsKey(m[2])) return message;
    var line = int.parse(m[1]!);
    for (final e in definitionFiles.entries) {
      final n = const LineSplitter().convert(e.value).length + (e.value.endsWith('\n') ? 1 : 0);
      if (line <= n) return message.replaceRange(m.start, m.start + 'page:${m[1]}'.length, '${_name(e.key)}:$line');
      line -= n;
    }
    return message;
  }

  /// The words [definitionFiles] define, by the file that defines each.
  late final Map<String, String> definedWords = {
    for (final e in definitionFiles.entries)
      for (final w in readPageDefinitions(e.value).words.entries)
        if (notationBuiltInWord(w.key, catalog: standardCatalog, primitive: w.value.every((d) => d.primitive)) == null) w.key: e.key,
  };

  /// The component files the site does not load (a `components/*.txt` that
  /// is neither a component nor definitions, a second file of one type, a
  /// component JSON site.json lists that is not there or does not read),
  /// and what a file of definitions has wrong, each with what to write.
  /// Before, each was skipped with no word (test 10: a `define Masthead` in
  /// components/ drew a placeholder on every page).
  List<SkippedComponent> get skipped {
    sources;
    expanded;
    return _skipped;
  }

  /// Whether [text] is definitions: its first line that is not blank or a
  /// `//` comment starts with `define ` or `primitive `.
  static bool _isDefinitions(String text) {
    final first = const LineSplitter().convert(text).map((l) => l.trim()).where((l) => l.isNotEmpty && !l.startsWith('//')).firstOrNull;
    return first != null && RegExp(r'^(define|primitive)\s+[A-Za-z_]').hasMatch(first);
  }

  /// Says what a file of definitions has wrong: what a definition cannot
  /// read, and a line at the margin that is in no definition (it is not
  /// read: a file of definitions draws nothing itself).
  void _checkDefinitions(String path, String text) {
    final read = readPageDefinitions(text);
    for (final p in read.problems) {
      _skipped.add((path: path, type: _stem(path), message: '${_name(path)}: line ${p.line}: ${p.message}'));
    }
    final lines = const LineSplitter().convert(text);
    for (var i = 0; i < lines.length; i++) {
      final l = lines[i];
      if (l.trim().isEmpty || l.startsWith(' ') || l.startsWith('\t') || l.startsWith('//')) continue;
      if (RegExp(r'^(define|primitive)\s').hasMatch(l)) continue;
      _skipped.add((
        path: path,
        type: _stem(path),
        message: '${_name(path)}: line ${i + 1}: `${l.length > 50 ? '${l.substring(0, 47)}...' : l}` is in no definition, so it is not read: '
            'a file of definitions holds `define` (or `primitive`) lines, each with its lines indented under it.',
      ));
    }
    // A word the notation already has is the notation's: this definition of
    // it is not used (the owner's decision, 2026-11-18).
    for (final e in read.words.entries) {
      if (notationBuiltInWord(e.key, catalog: standardCatalog, primitive: e.value.every((d) => d.primitive)) case final what?) {
        for (final d in e.value) {
          _skipped.add((path: path, type: e.key, message: '${_name(path)}: line ${d.line}: ${notationBuiltInDefinition(e.key, what, kind: d.primitive ? 'primitive' : 'definition')}'));
        }
      }
    }
    // A formula whose brackets do not match (the parser says it where a file
    // is expanded; this one is read by every page, never expanded alone).
    for (final i in notationBracketIssues(text)) {
      _skipped.add((path: path, type: _stem(path), message: '${_name(path)}: line ${i.line}:${i.column}: ${i.message}'));
    }
  }

  /// Why the component file at [path] is not read: what its first line is
  /// and what to write.
  static String _notAComponent(String path, String text) {
    final first = const LineSplitter().convert(text).map((l) => l.trim()).where((l) => l.isNotEmpty && !l.startsWith('//')).firstOrNull;
    final name = _name(path);
    if (first == null) return '$name is empty: it is not read. A component file starts with `component ${_stem(path)}` (or `define ${_stem(path)} …`).';
    return '$name is not read: its first line is `${first.length > 60 ? '${first.substring(0, 57)}...' : first}`, neither `component <Name>` nor `define <Name> …`. '
        'Write `define ${_stem(path)}` (its strings, parameters and events as a line would use it) above its lines indented under it, '
        'or `component ${_stem(path)}` with `param` lines (docs/reference/notation/components.md).';
  }

  /// [path] as `components/<file>`.
  static String _name(String path) {
    final parts = path.replaceAll(r'\', '/').split('/');
    return parts.length < 2 ? path : '${parts[parts.length - 2]}/${parts.last}';
  }

  /// The pages written in the notation (`pages/*.txt` in the site's folder
  /// or beside it), in file order.
  late final List<String> pageSources = () {
    final out = <String>[];
    for (final home in _homes) {
      final folder = Directory('$home/pages');
      if (!folder.existsSync()) continue;
      final files = folder.listSync().whereType<File>().where((f) => f.path.endsWith('.txt')).map((f) => f.path).toList()..sort();
      out.addAll(files);
      if (files.isNotEmpty) break;
    }
    return out;
  }();

  /// The references of the manifest's components, by type (its list, else
  /// every `components/*.json` beside it).
  late final Map<String, String> componentRefs = () {
    final listed = readStrings(manifest['components']);
    if (listed.isNotEmpty) return {for (final r in listed) _stem(r): r};
    final folder = Directory('$dir/components');
    if (!folder.existsSync()) return <String, String>{};
    return {
      for (final f in folder.listSync().whereType<File>().where((f) => f.path.endsWith('.json')))
        _stem(f.path): 'components/${f.uri.pathSegments.last}',
    };
  }();

  /// Where the expansion of component [type] goes: the manifest's reference
  /// for it, else `components/<type>.json` in the site's folder.
  String componentOut(String type) => '$dir/${jsonRef(componentRefs[type] ?? 'components/$type.json')}';

  /// Where the expansion of the page in [source] goes: the manifest's page
  /// of the same name, else `<name>.json` in the site's folder.
  String pageOut(String source) {
    final name = _stem(source);
    // A page listed by its name alone (`"home"`) or as a record
    // (`{"id": "home", "file": "home.json"}`) is that name's JSON.
    final ref = SiteManifest.pageRefs(manifest['pages']).where((p) => _stem(p) == name).firstOrNull;
    return '$dir/${ref == null ? '$name.json' : RegExp(r'\.[A-Za-z0-9]+$').hasMatch(ref) ? jsonRef(ref) : '$ref.json'}';
  }

  /// The JSON a reference of site.json names: a `.txt` it lists is the
  /// notation itself, which an expansion never writes over (NOCD 18: the
  /// listed pages were overwritten with their JSON, the source lost), but
  /// the `.json` beside it.
  static String jsonRef(String ref) => ref.toLowerCase().endsWith('.txt') ? '${ref.substring(0, ref.length - 4)}.json' : ref;

  /// The references site.json lists that are notation files (`pages/home.txt`):
  /// a site lists the JSON documents its notation expands to.
  List<String> get listedNotation => [
        for (final r in [...SiteManifest.pageRefs(manifest['pages']), ...readStrings(manifest['components'])])
          if (r.toLowerCase().endsWith('.txt')) r,
      ];

  /// The site's expanded components, from their JSON (the manifest's
  /// list): each that reads as a component document, by type.
  late final Map<String, LayoutDocument> expanded = () {
    final out = <String, LayoutDocument>{};
    for (final e in componentRefs.entries) {
      final f = File('$dir/${jsonRef(e.value)}');
      // Written from its notation by `expand` when it is not there yet; one
      // that nothing writes is said.
      if (sources.containsKey(e.key)) {
        if (!f.existsSync()) continue;
      } else if (!f.existsSync()) {
        // A word the site's definitions give needs no JSON.
        if (!definedWords.containsKey(e.key) && !_skipped.any((s) => s.type == e.key)) {
          _skipped.add((
            path: f.path,
            type: e.key,
            message: 'site.json lists ${e.value}, which is not there, and no components/*.txt writes `component ${e.key}`: a call to ${e.key} has nothing to draw.',
          ));
        }
        continue;
      }
      try {
        final d = LayoutDocument.fromJson(jsonDecode(f.readAsStringSync()));
        if (d.isComponent) {
          out[d.componentType!] = d;
        } else if (!sources.containsKey(e.key)) {
          _skipped.add((path: f.path, type: e.key, message: '${e.value} is not a component document (no component head): it is not read.'));
        }
      } on Object catch (error) {
        // A component file that does not read is left to its own expand.
        if (!sources.containsKey(e.key)) {
          _skipped.add((path: f.path, type: e.key, message: '${e.value} does not read as a component document (${'$error'.split('\n').first}): it is not read.'));
        }
      }
    }
    return out;
  }();

  /// Reads the manifest at [path] and the design system it names.
  static Future<NotationSite> load(String path) async {
    final problems = <String>[];
    Json manifest = const {};
    final f = File(path);
    var hasManifest = false;
    String? asRead;
    if (!f.existsSync()) {
      // A folder of notation is a site with no manifest.
      final dir = f.absolute.parent;
      if (!isSiteFolder(dir.path) && !isSiteFolder(dir.parent.path)) {
        problems.add('$path: no such file, so no site is known (its variables, theme and components)');
      }
    } else {
      asRead = f.readAsStringSync();
      hasManifest = true;
      try {
        final read = readMap(jsonDecode(asRead)) ?? const <String, Object?>{};
        // What expand wrote in it is not the site's source.
        final source = notationSourceManifest(read);
        hasManifest = source != null;
        manifest = source ?? const {};
      } on FormatException catch (e) {
        problems.add('$path is not JSON (${e.message}): its variables, theme and components were not read');
      }
    }
    final site = NotationSite._(path, manifest, problems, hasManifest: hasManifest, manifestAsRead: asRead);
    if (readString(manifest['designSystem']) case final ref?) {
      final dsDir = sitePath(site.dir, ref);
      try {
        site.designSystem = await DesignSystem.load((r) async {
          final file = File('$dsDir/$r');
          return file.existsSync() ? file.readAsStringSync() : null;
        }, problems: problems);
      } on Object catch (e) {
        problems.add('designSystem "$ref" does not load: $e');
      }
    }
    return site;
  }

  /// The notation components in the order they can be expanded: each after
  /// the components it calls. [cycles] collects the types of a ring of
  /// components calling each other (each expanded with the others it can
  /// see).
  List<ComponentSource> ordered([List<List<String>>? cycles]) {
    final calls = {for (final s in sources.values) s.type: callsIn(s.text, sources.keys.toSet()..remove(s.type))};
    final out = <ComponentSource>[];
    final state = <String, int>{};
    void visit(String t, List<String> path) {
      if (state[t] == 2) return;
      if (state[t] == 1) {
        cycles?.add([...path.sublist(path.indexOf(t)), t]);
        return;
      }
      state[t] = 1;
      for (final c in calls[t]!.toList()..sort()) {
        visit(c, [...path, t]);
      }
      state[t] = 2;
      out.add(sources[t]!);
    }

    for (final t in sources.keys.toList()..sort()) {
      visit(t, const []);
    }
    return out;
  }
}

/// The type a component's notation text declares (`component Name "…"`, its
/// first line that is not blank or a comment); null when it is not one.
String? componentTypeOf(String text) {
  for (final raw in const LineSplitter().convert(text)) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('//') || line.startsWith('#')) continue;
    return RegExp(r'^component\s+([A-Za-z_][A-Za-z0-9_]*)').firstMatch(line)?[1];
  }
  return null;
}

/// The names of [types] that [text] calls: a line written with one as its
/// word (`Card#c "…"`, `Card.compact`), or `type=Card`.
Set<String> callsIn(String text, Set<String> types) {
  if (types.isEmpty) return const {};
  final out = <String>{};
  for (final m in RegExp(r'(?:^[ \t]*|\btype=)([A-Z][A-Za-z0-9_]*)', multiLine: true).allMatches(text)) {
    if (types.contains(m[1])) out.add(m[1]!);
  }
  return out;
}

String _stem(String ref) {
  final name = ref.replaceAll(r'\', '/').split('/').last;
  final dot = name.lastIndexOf('.');
  return dot <= 0 ? name : name.substring(0, dot);
}

/// How [NotationExpander] expands each file.
typedef ExpandSettings = ({
  double width,
  bool reflow,
  bool named,
  bool nearestColors,
  bool open,
  NotationVocabulary aliases,
});

/// Expands notation files with what a site and a design system give them:
/// the site's variables, pages and theme, and every component callable by
/// name (the design system's, the site's expanded ones, and the site's
/// notation components, expanded first in the order they call each other).
final class NotationExpander {
  NotationExpander({this.site, this.designSystem, required this.settings});

  /// The site the files belong to; null: none.
  final NotationSite? site;

  /// The design system `--design-system` names; null: none.
  final DesignSystem? designSystem;
  final ExpandSettings settings;

  /// The site's notation components expanded so far, by type.
  final Map<String, LayoutDocument> _fromSource = {};

  /// [settings]' vocabulary with the site's dictionaries under the ones it
  /// has (site.json's `dictionary`): what each file is read with.
  late final NotationVocabulary _vocabulary = withDictionaries(settings.aliases, site?.dictionaries ?? const [], say: stderr.writeln);

  /// The results of the components expanded so far, by type.
  final Map<String, NotationResult> componentResults = {};

  /// The components [file] (the path of the text being expanded) may call:
  /// every one but itself and those that call it.
  Map<String, LayoutDocument> _libraryFor(String? self) {
    final s = site;
    final out = <String, LayoutDocument>{...?designSystem?.components.definitions, ...?s?.designSystem?.components.definitions};
    if (s == null) return out;
    out.addAll(s.expanded);
    // A notation component is read from its text (what its writer edits),
    // not from a JSON written from an older text.
    final skip = <String>{if (self != null) self};
    if (self != null) {
      // And not the components that call it: they would need it first.
      var grew = true;
      while (grew) {
        grew = false;
        for (final src in s.sources.values) {
          if (!skip.contains(src.type) && callsIn(src.text, skip).isNotEmpty) grew = skip.add(src.type) || grew;
        }
      }
    }
    for (final src in s.ordered()) {
      if (skip.contains(src.type)) {
        out.remove(src.type);
        continue;
      }
      final doc = _fromSource[src.type] ?? _expandComponent(src, out);
      if (doc != null) out[src.type] = doc;
    }
    if (self != null) out.remove(self);
    return out;
  }

  LayoutDocument? _expandComponent(ComponentSource src, Map<String, LayoutDocument> library) {
    final result = _expand(src.text, library, screen: src.type);
    componentResults[src.type] = result;
    try {
      final d = LayoutDocument.fromJson(result.document);
      if (!d.isComponent) return null;
      _fromSource[src.type] = d;
      return d;
    } on Object {
      return null;
    }
  }

  NotationResult _expand(String text, Map<String, LayoutDocument> library, {required String screen}) {
    final s = site;
    final ds = designSystem ?? s?.designSystem;
    final theme = s != null ? s.theme : ds?.tokens ?? ThemeTokens.none;
    final useLooks = ds != null || library.isNotEmpty || !theme.isEmpty;
    final merged = !useLooks
        ? null
        : DesignSystem(
            manifest: DesignSystemManifest.fromJson({
              ...?ds?.manifest.toJson(),
              'id': ds?.id ?? 'site',
              'theme': theme.toJson(),
              'components': [for (final t in library.keys) DesignSystem.componentRef(t)],
            }),
            components: ComponentLibrary(library),
          );
    final catalog = merged?.catalogOver(standardCatalog) ?? standardCatalog;
    final variables = s?.variables ?? const <String, Json>{};
    // A site's documents are shown under its theme: what the notation adds
    // is written by the theme's names (dark mode and an edited token follow).
    final named = settings.named || (s != null && !theme.isEmpty);
    // With no theme anywhere the notation's own looks stay (a site that only
    // adds components looks as it did without them).
    final options = (merged == null || theme.isEmpty
            ? NotationOptions(
                screen: screen,
                width: settings.width,
                reflow: settings.reflow,
                projectVariables: variables,
                components: merged == null ? const {} : NotationOptions.fromDesignSystem(merged).components,
                componentScreenActions: merged == null ? const {} : NotationOptions.fromDesignSystem(merged).componentScreenActions,
                componentScreenOverlays: merged == null ? const {} : NotationOptions.fromDesignSystem(merged).componentScreenOverlays,
              )
            : NotationOptions.fromDesignSystem(merged,
                screen: screen, width: settings.width, named: named, nearestColors: settings.nearestColors, reflow: settings.reflow, projectVariables: variables,
                // A site with no design system: what the notation draws by
                // itself is in the theme's roles, light or dark as it is shown.
                roles: ds == null))
        .open(openVocabulary: settings.open, vocabulary: _vocabulary)
        .withScreens(s?.screens ?? const [])
        .withOwnComponents(s == null ? const [] : {...s.sources.keys, ...s.expanded.keys});
    // The site's definitions (components/*.txt of `define` blocks) hold in
    // every text, as an answer's definitions after its last screen do.
    return Catalog.run(catalog, () => parseNotation(text, catalog: catalog, options: options, definitions: s?.definitionText));
  }

  /// Expands [text] (the file at [path]) as the canvas [screen]. A page
  /// whose first line is one `### Name` (as the open prompt writes a
  /// screen) is read without it: the file names the page
  /// ([pageHeadings] says when there are several).
  NotationResult expand(String text, {required String path, required String screen}) {
    final self = componentTypeOf(text);
    final library = _libraryFor(self);
    return _expand(self == null ? withoutScreenHeading(text) : text, library, screen: screen);
  }

  /// The notation components that did not expand cleanly while reading
  /// others: each with its issues.
  Iterable<(String, NotationResult)> get failedComponents sync* {
    for (final e in componentResults.entries) {
      if (e.value.issues.isNotEmpty) yield (e.key, e.value);
    }
  }
}

final _screenHeading = RegExp(r'^###\s+\S');

/// The lines of [text] that are a `### Name` screen heading (1-based).
List<int> pageHeadings(String text) {
  final lines = const LineSplitter().convert(text);
  return [for (var i = 0; i < lines.length; i++) if (_screenHeading.hasMatch(lines[i])) i + 1];
}

/// [text] without its screen heading when it has exactly one and it is its
/// first line that is not blank or a comment (the open prompt writes each
/// screen under `### Name`; a site's page file is one screen, named by its
/// file). The line is left blank, so every other line keeps its number.
String withoutScreenHeading(String text) {
  final at = pageHeadings(text);
  if (at.length != 1) return text;
  final lines = text.split('\n');
  for (var i = 0; i < at.single - 1; i++) {
    final t = lines[i].trim();
    if (t.isNotEmpty && !t.startsWith('//')) return text;
  }
  lines[at.single - 1] = lines[at.single - 1].endsWith('\r') ? '\r' : '';
  return lines.join('\n');
}

/// What to say of a page whose `### Name` lines split it into several
/// screens (a site's page file is one): one message, or null.
String? pageHeadingsNote(String text) {
  final at = pageHeadings(text);
  if (at.length < 2 && withoutScreenHeading(text) != text) return null;
  if (at.isEmpty) return null;
  return at.length == 1
      ? 'line ${at.single}: `###` names a screen only on a page\'s first line; here it is not read. Drop it (the file\'s name names the page).'
      : 'lines ${at.join(', ')}: `### Name` lines split this file into ${at.length} screens, and a page file is one screen, named by its file: '
          'write each screen in its own pages/<name>.txt and drop the `###` lines.';
}

/// The name of the page in notation file [path]: its file name, its canvas
/// id.
String pageNameOf(String path) => File(path).uri.pathSegments.last.replaceFirst(RegExp(r'\.txt$'), '');

/// [site] expanded whole by [expander]: its notation components ([order],
/// else [NotationSite.ordered]) and its pages, each document as it is
/// written, with each overlay two pages write with one id and draw
/// differently made the page's own (site_overlays.dart: [scopeOverlays]),
/// and what that could not do.
({
  List<ScopedComponent> components,
  Map<String, NotationResult> componentResults,
  List<ScopedPage> pages,
  List<NotationResult> results,
  OverlayScoping scoping,
}) expandSitePages(NotationExpander expander, NotationSite site, {List<ComponentSource>? order}) {
  Json copy(Json d) => jsonDecode(jsonEncode(d)) as Json;
  final components = <ScopedComponent>[];
  final componentResults = <String, NotationResult>{};
  for (final src in order ?? site.ordered()) {
    final r = expander.expand(src.text, path: src.path, screen: 'screen');
    componentResults[src.type] = r;
    components.add((type: src.type, path: src.path, document: copy(r.document)));
  }
  final pages = <ScopedPage>[];
  final results = <NotationResult>[];
  for (final page in site.pageSources) {
    final name = pageNameOf(page);
    final r = expander.expand(File(page).readAsStringSync(), path: page, screen: name);
    results.add(r);
    pages.add((name: name, path: page, document: copy(r.document)));
  }
  final scoping = scopeOverlays(pages, components, otherComponents: {
    for (final e in site.expanded.entries)
      if (!site.sources.containsKey(e.key)) e.key: (path: site.componentOut(e.key), document: e.value.toJson()),
  });
  return (components: components, componentResults: componentResults, pages: pages, results: results, scoping: scoping);
}
