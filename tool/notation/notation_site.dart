// What `expand` knows of the site a notation file belongs to: its variables
// (read by bare name, never declared again on a page or in a component), its
// pages (the screens a bare `go name` names), its theme (the looks a line
// takes when it says none, and the text styles `style=` and `from=` name)
// and its components (callable by name, as components.md says), whether
// they are written in the notation (`components/*.txt`) or expanded
// (`site.json`'s `components`, else `components/*.json`).
//
// A site is a folder with a `site.json`. A notation file belongs to the one
// `--site` names, else the one beside `--out`, else the first found beside
// the file or above it (its folder and the two above it), as `site.json` or
// `site/site.json`: the layout
//
//   my-site/
//     pages/home.txt          → site/home.json
//     components/Card.txt     → site/components/Card.json
//     site/site.json
//
// and a site folder that holds its notation itself (`site/pages/*.txt`,
// `site/components/*.txt`) both work.
import 'dart:convert';
import 'dart:io';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_api/notation.dart';

/// The `site.json` a notation [file] belongs to: [site] (a manifest, or a
/// folder holding one as `site.json` or `site/site.json`), else the one
/// beside [out], else the first beside [file] or up to two folders above it.
/// Null: the file is expanded alone.
String? findSiteManifest({String? site, String? out, String? file}) {
  String? at(String dir) {
    for (final c in ['$dir/${SiteManifest.fileName}', '$dir/site/${SiteManifest.fileName}']) {
      if (File(c).existsSync()) return c;
    }
    return null;
  }

  if (site != null) {
    if (FileSystemEntity.isDirectorySync(site)) return at(site) ?? '$site/${SiteManifest.fileName}';
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
  }
  return null;
}

/// A component written in the notation: its type (the name on its
/// `component` line), its file and its text.
typedef ComponentSource = ({String type, String path, String text});

/// A site as `expand` reads it ([load]).
final class NotationSite {
  NotationSite._(this.manifestPath, this.manifest, this.problems);

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
  late final Map<String, Json> variables = {
    for (final v in Variable.declarationsFromJson(manifest['variables'])) v.name: {'type': v.type.name, ...v.toJson()},
  };

  /// The ids of its pages (each page reference's file stem).
  late final List<String> screens = [
    for (final p in readList(manifest['pages']) ?? const [])
      if (p is String) _stem(p),
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

  /// The components written in the notation (`components/*.txt` in the
  /// site's folder or beside it), by type.
  late final Map<String, ComponentSource> sources = () {
    final out = <String, ComponentSource>{};
    for (final home in _homes) {
      final folder = Directory('$home/components');
      if (!folder.existsSync()) continue;
      final files = folder.listSync().whereType<File>().where((f) => f.path.endsWith('.txt')).toList()..sort((a, b) => a.path.compareTo(b.path));
      for (final f in files) {
        final text = f.readAsStringSync();
        final type = componentTypeOf(text);
        if (type == null) continue;
        out.putIfAbsent(type, () => (type: type, path: f.path, text: text));
      }
    }
    return out;
  }();

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
  String componentOut(String type) => '$dir/${componentRefs[type] ?? 'components/$type.json'}';

  /// Where the expansion of the page in [source] goes: the manifest's page
  /// of the same name, else `<name>.json` in the site's folder.
  String pageOut(String source) {
    final name = _stem(source);
    final ref = readStrings(manifest['pages']).where((p) => _stem(p) == name).firstOrNull;
    return '$dir/${ref ?? '$name.json'}';
  }

  /// The site's expanded components, from their JSON (the manifest's
  /// list): each that reads as a component document, by type.
  late final Map<String, LayoutDocument> expanded = () {
    final out = <String, LayoutDocument>{};
    for (final e in componentRefs.entries) {
      final f = File('$dir/${e.value}');
      if (!f.existsSync()) continue;
      try {
        final d = LayoutDocument.fromJson(jsonDecode(f.readAsStringSync()));
        if (d.isComponent) out[d.componentType!] = d;
      } on Object {
        // A component file that does not read is left to its own expand.
      }
    }
    return out;
  }();

  /// Reads the manifest at [path] and the design system it names.
  static Future<NotationSite> load(String path) async {
    final problems = <String>[];
    Json manifest = const {};
    final f = File(path);
    if (!f.existsSync()) {
      problems.add('$path: no such file, so no site is known (its variables, theme and components)');
    } else {
      try {
        manifest = readMap(jsonDecode(f.readAsStringSync())) ?? const {};
      } on FormatException catch (e) {
        problems.add('$path is not JSON (${e.message}): its variables, theme and components were not read');
      }
    }
    final site = NotationSite._(path, manifest, problems);
    if (readString(manifest['designSystem']) case final ref?) {
      final dsDir = '${site.dir}/$ref';
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
              )
            : NotationOptions.fromDesignSystem(merged,
                screen: screen, width: settings.width, named: named, nearestColors: settings.nearestColors, reflow: settings.reflow, projectVariables: variables))
        .open(openVocabulary: settings.open, vocabulary: settings.aliases)
        .withScreens(s?.screens ?? const [])
        .withOwnComponents(s == null ? const [] : {...s.sources.keys, ...s.expanded.keys});
    return Catalog.run(catalog, () => parseNotation(text, catalog: catalog, options: options));
  }

  /// Expands [text] (the file at [path]) as the canvas [screen].
  NotationResult expand(String text, {required String path, required String screen}) {
    final self = componentTypeOf(text);
    final library = _libraryFor(self);
    return _expand(text, library, screen: screen);
  }

  /// The notation components that did not expand cleanly while reading
  /// others: each with its issues.
  Iterable<(String, NotationResult)> get failedComponents sync* {
    for (final e in componentResults.entries) {
      if (e.value.issues.isNotEmpty) yield (e.key, e.value);
    }
  }
}

/// What is wrong with the canvases of page [name] (its expansion [r]) given
/// [canvasOf], the canvases of the pages before it by id (added to): a page
/// and its overlays are screens of the whole site, so an id two pages give
/// a canvas makes one screen of the two (test 9, kanban 9: the board's
/// `Drawer#nav` showed the archive page's sidebar, with no word).
List<String> canvasClashes(Map<String, String> canvasOf, String name, NotationResult r) => [
      for (final id in readStrings(r.document['roots']))
        if (canvasOf.putIfAbsent(id, () => name) case final other when other != name)
          '${id != name ? 'the overlay' : 'the page'} "$id" has the id of ${other == id ? 'the page' : 'an overlay of'} $other: '
              'a page and its overlays are screens of the whole site, so the two are one and only one of them is shown. '
              '${id != name ? 'Give this one an id of its own (#$id${name[0].toUpperCase()}${name.substring(1).replaceAll(RegExp(r'[^A-Za-z0-9]'), '')}) and open it by that.' : 'Rename the overlay on $other.'}',
    ];
