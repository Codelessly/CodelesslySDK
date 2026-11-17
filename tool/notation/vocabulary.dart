// The vocabulary loop's count (codelessly_api docs/design/19-open-vocabulary.md):
// reads a corpus of answers written with an open vocabulary, expands every
// screen with the Cards design system, and says which words the answers
// reached for and how each resolved: a core word, a component of the design
// system, an alias of a word we have, or a word we do not have.
//
//   dart run tool/notation/vocabulary.dart <folder or files>
//       [--design-system <folder>] [--aliases <file.json>] [--no-aliases]
//       [--width <canvas width>] [--out <dir>] [--sites <dir>] [--no-definitions]
//
// A corpus file may hold several screens, each under a `### name` line; a
// file without one is a single screen. A folder is read for its *.txt (and
// those of its answers/ folder). The design system is design_systems/cards
// unless named; its vocabulary.json (aliases) is read over the built-in
// table, then --aliases over both; --no-aliases reads none (the count before
// any alias). The words the design system defines in the notation (its
// vocabulary/*.txt, codelessly_api docs/design/20-defined-words.md) are read
// as words we have; --no-definitions reads none. A word an answer defines
// (`define Word …`, anywhere in it) holds for all of its screens. Every word an answer used is
// recorded with how it resolved (vocabulary_words.dart), known or not, in
// `words` and the summary; the other sections rank what is unknown.
// It writes <out>/vocabulary.json and <out>/VOCABULARY.md (<out>:
// the folder given, or the first file's). With --sites it also writes, for
// each file, <sites>/<file>/<screen>.json and a site.json, ready for
// tool/render/render.sh.
import 'dart:convert';
import 'dart:io';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_api/notation.dart';
import 'package:codelessly_api/validate.dart';
import 'package:codelessly_sdk/src/runtime/expressions/formula.dart' show FormulaEvaluator;

import 'vocabulary_harvest.dart';
import 'vocabulary_words.dart';

/// The aliases of the design system at [dir] (its vocabulary.json) over the
/// built-in table, then those of [file] over both; and, with [definitions],
/// the words the design system defines in the notation (its vocabulary/*.txt,
/// codelessly_api docs/design/20-defined-words.md). What a definition gets
/// wrong is said on stderr.
NotationVocabulary loadVocabulary({String? dir, String? file, bool builtIn = true, bool definitions = true}) {
  var table = builtIn ? NotationVocabulary.core : NotationVocabulary.none;
  final texts = definitions && dir != null ? loadDefinitionTexts(dir) : const <String, String>{};
  if (texts.isNotEmpty) {
    final read = readDefinitions(texts);
    for (final p in read.problems) {
      stderr.writeln('$dir/vocabulary/$p');
    }
    table = table.merge(NotationVocabulary(definitions: read.words));
  }
  for (final path in [if (dir != null) '$dir/vocabulary.json', ?file]) {
    final f = File(path);
    if (!f.existsSync()) {
      if (path == file) throw FileSystemException('No such alias table', path);
      continue;
    }
    final json = jsonDecode(f.readAsStringSync());
    if (json is Map) table = table.merge(NotationVocabulary.fromJson(json.cast<String, Object?>()));
  }
  return table;
}

/// The texts of the words the design system at [dir] defines in the
/// notation: its vocabulary/*.txt, by file name.
Map<String, String> loadDefinitionTexts(String dir) {
  final folder = Directory('$dir/vocabulary');
  if (!folder.existsSync()) return const {};
  final files = folder.listSync().whereType<File>().where((f) => f.path.endsWith('.txt')).toList()..sort((a, b) => a.path.compareTo(b.path));
  return {for (final f in files) f.uri.pathSegments.last: f.readAsStringSync()};
}

/// The screens of [text]: each `### name` line starts one; a text without
/// one is a single screen called [fallback]. `from` is the 1-based line of
/// the screen's first line in the file.
List<({String name, String id, String text, int from})> screensOf(String text, String fallback) {
  final lines = const LineSplitter().convert(text);
  final out = <({String name, String id, String text, int from})>[];
  final ids = <String>{};
  String slug(String name) {
    var s = name.toLowerCase().replaceAll(RegExp("['’]"), '').replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
    if (s.isEmpty || !RegExp(r'^[a-z_]').hasMatch(s)) s = 's-$s';
    var id = s;
    for (var n = 2; !ids.add(id); n++) {
      id = '$s-$n';
    }
    return id;
  }

  String? name;
  var from = 1;
  final body = <String>[];
  void close() {
    if (body.any((l) => l.trim().isNotEmpty)) {
      final n = name ?? fallback;
      out.add((name: n, id: slug(n), text: body.join('\n'), from: from));
    }
    body.clear();
  }

  for (var i = 0; i < lines.length; i++) {
    final m = RegExp(r'^###\s+(.+?)\s*$').firstMatch(lines[i]);
    if (m != null) {
      close();
      name = m[1];
      from = i + 2;
    } else {
      body.add(lines[i]);
    }
  }
  close();
  return out;
}

class _Word {
  _Word(this.word, this.kind);
  final String word, kind;
  String resolved = 'unknown';
  String? to, on;
  int uses = 0;
  final files = <String>{};
  final parameters = <String, int>{}, flags = <String, int>{}, events = <String, int>{}, children = <String, int>{}, values = <String, int>{};
  final examples = <String>[];

  void example(String line) {
    final l = line.length > 220 ? '${line.substring(0, 217)}...' : line;
    if (examples.length < 3 && !examples.contains(l)) examples.add(l);
  }

  Map<String, Object?> toJson() => {
        'word': word,
        if (on != null) 'on': on,
        'resolved': resolved,
        if (to != null) 'to': to,
        'files': files.length,
        'uses': uses,
        'in': files.toList()..sort(),
        if (parameters.isNotEmpty) 'parameters': _ranked(parameters),
        if (flags.isNotEmpty) 'flags': _ranked(flags),
        if (events.isNotEmpty) 'events': _ranked(events),
        if (children.isNotEmpty) 'children': _ranked(children),
        if (values.isNotEmpty) 'values': _ranked(values),
        'examples': examples,
      };
}

Map<String, int> _ranked(Map<String, int> m) => Map.fromEntries(m.entries.toList()..sort((a, b) => b.value != a.value ? b.value - a.value : a.key.compareTo(b.key)));

List<_Word> _sorted(Iterable<_Word> words) => words.toList()
  ..sort((a, b) => b.files.length != a.files.length
      ? b.files.length - a.files.length
      : b.uses != a.uses
          ? b.uses - a.uses
          : '${a.on ?? ''}.${a.word}'.compareTo('${b.on ?? ''}.${b.word}'));

/// An issue's message with what is particular to its line taken out, so the
/// same complaint counts as one.
String _shape(String message) => message
    .replaceAll(RegExp(r'"[^"]*"'), '"…"')
    .replaceAll(RegExp(r'\{[^{}]*\}'), '{…}')
    .replaceAll(RegExp(r'\b\d+(\.\d+)?\b'), 'N')
    .replaceAllMapped(RegExp(r'^(A|An|No) [A-Z][A-Za-z0-9.]*'), (m) => '${m[1]} <Type>');

const _statements = {'state', 'if', 'each', 'else', 'for', 'key', 'every', 'project', 'node', 'document', 'let', 'derived', 'const', 'var'};

/// The parts of [name] as its capitals split it (`MiniCalendar`: mini, calendar).
List<String> _stems(String name) =>
    [for (final m in RegExp(r'[A-Z]+(?![a-z])|[A-Z]?[a-z]+|\d+').allMatches(name)) m[0]!.toLowerCase()];

/// Parts too general to say two words mean the same thing.
const _plainStems = {
  'list', 'view', 'item', 'row', 'card', 'bar', 'button', 'input', 'text', 'panel', 'picker', 'field', 'group', 'box', 'area', 'grid', 'line', 'cell', 'tile', //
  'icon', 'label', 'header', 'title', 'state', 'action', 'control', 'mini', 'map', 'pane', 'page', 'tab', 'tabs', 'menu', 'chip', 'image', 'table', 'badge', 'block', 'section',
};

/// The folder [to] as a path from the folder [from].
String _relative(String to, String from) {
  List<String> parts(String p) => Directory(p).absolute.uri.normalizePath().pathSegments.where((s) => s.isNotEmpty).toList();
  final a = parts(from), b = parts(to);
  var same = 0;
  while (same < a.length && same < b.length && a[same].toLowerCase() == b[same].toLowerCase()) {
    same++;
  }
  return [...List.filled(a.length - same, '..'), ...b.skip(same)].join('/');
}

Future<void> main(List<String> args) async {
  String? opt(String name) {
    final i = args.indexOf(name);
    return i < 0 || i + 1 >= args.length ? null : args[i + 1];
  }

  const valued = {'--design-system', '--aliases', '--width', '--out', '--sites'};
  final given = <String>[];
  for (var i = 0; i < args.length; i++) {
    if (valued.contains(args[i])) {
      i++;
    } else if (!args[i].startsWith('--')) {
      given.add(args[i]);
    }
  }
  if (given.isEmpty) {
    stderr.writeln('usage: vocabulary.dart <folder or files> [--design-system <folder>] [--aliases <file.json>] [--no-aliases] [--width <canvas width>] [--out <dir>] [--sites <dir>]');
    exit(2);
  }
  final sdk = File.fromUri(Platform.script).parent.parent.parent.path;
  final dsDir = opt('--design-system') ?? '$sdk/design_systems/cards';
  final problems = <String>[];
  final ds = await DesignSystem.load((ref) async {
    final f = File('$dsDir/$ref');
    return f.existsSync() ? f.readAsStringSync() : null;
  }, problems: problems);
  if (problems.isNotEmpty) {
    stderr.writeln('The design system at $dsDir does not load cleanly: ${problems.join('; ')}');
    exit(2);
  }
  final files = <File>[];
  for (final g in given) {
    if (FileSystemEntity.isDirectorySync(g)) {
      for (final d in [Directory(g), Directory('$g/answers')]) {
        if (!d.existsSync()) continue;
        files.addAll(d.listSync().whereType<File>().where((f) => f.path.endsWith('.txt') && !RegExp(r'(prompt|README)[^/\\]*$').hasMatch(f.path)));
      }
    } else if (File(g).existsSync()) {
      files.add(File(g));
    } else {
      stderr.writeln('$g: no such file or folder');
      exit(2);
    }
  }
  files.sort((a, b) => a.path.compareTo(b.path));
  final first = given.first;
  final outDir = Directory(opt('--out') ?? (FileSystemEntity.isDirectorySync(first) ? first : File(first).parent.path))..createSync(recursive: true);
  final sites = opt('--sites');
  final width = double.tryParse(opt('--width') ?? '') ?? 1280;
  final table = loadVocabulary(dir: dsDir, file: opt('--aliases'), builtIn: !args.contains('--no-aliases'), definitions: !args.contains('--no-definitions'));
  final catalog = ds.catalogOver(standardCatalog);
  final components = {for (final c in ds.list) c.type};
  final corpus = CorpusWords(components: components);
  final theme = ThemeTokens.fromJson(ds.manifest.theme.toJson());

  final types = <String, _Word>{};
  // What a first word of a definition's line is outside it: core, a
  // component, a word the design system defines, or nobody's.
  final kinds = <String, String>{};
  final closed = NotationOptions.fromDesignSystem(ds, width: width).open(openVocabulary: false, vocabulary: table);
  final harvest = Harvest(
    kindOf: (w) => kinds[w] ??= table.definitions.containsKey(w)
        ? 'defined'
        : components.contains(w) && !notationTypes.containsKey(w)
            ? 'component'
            : Catalog.run(catalog, () => parseNotation('Column\n  $w', catalog: catalog, options: closed)).issues.any((i) => i.message.startsWith('No node type'))
                ? 'unknown'
                : 'core',
  );
  final others = <String, Map<String, _Word>>{'parameter': {}, 'flag': {}, 'event': {}, 'verb': {}, 'variant': {}, 'missing': {}, 'children': {}, 'function': {}, 'alias': {}, 'overlay': {}};
  final issueShapes = <String, ({int count, Set<String> files, List<String> examples})>{};
  final invalidShapes = <String, ({int count, Set<String> files, List<String> examples})>{};
  final perFile = <Map<String, Object?>>[];
  final total = {'core': 0, 'component': 0, 'alias': 0, 'definition': 0, 'unknown': 0};
  var screenCount = 0, statementLines = 0;

  for (final file in files) {
    final name = file.uri.pathSegments.last.replaceFirst(RegExp(r'\.txt$'), '');
    final whole = file.readAsStringSync();
    harvest.answer(name, whole);
    final screens = screensOf(whole, name);
    final count = {'core': 0, 'component': 0, 'alias': 0, 'definition': 0, 'unknown': 0};
    var issues = 0, invalid = 0, standIns = 0, lines = 0;
    final pages = <String>[];
    final written = <String, Map<String, Object?>>{};
    // The state one screen declares and another of the same app reads or
    // sets without declaring it is the app's (site.json's variables): the
    // screens are expanded once to find it, then again with it.
    var shared = <String, Map<String, Object?>>{};

    NotationResult? expand(({String name, String id, String text, int from}) screen) {
      final options = NotationOptions.fromDesignSystem(ds, width: width, screen: screen.id, projectVariables: shared).open(vocabulary: table);
      try {
        // A word the answer defines anywhere (models write the definitions
        // after the last screen) holds for every one of its screens.
        return Catalog.run(catalog, () => parseNotation(screen.text, catalog: catalog, options: options, definitions: whole));
      } catch (e) {
        return null;
      }
    }

    // What a screen writes `project name=value` is the app's too.
    for (final screen in screens) {
      for (final m in RegExp(r'^project\s+([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.+?)(\s+saved)?\s*$', multiLine: true).allMatches(screen.text)) {
        Object? value;
        try {
          value = jsonDecode(m[2]!);
        } on FormatException {
          value = m[2];
        }
        shared.putIfAbsent(m[1]!, () => {
              'name': m[1],
              'type': switch (value) { bool _ => 'boolean', int _ => 'integer', num _ => 'decimal', List _ => 'list', Map _ => 'map', _ => 'text' },
              'value': value,
              if (m[3] != null) 'persist': true,
            });
      }
    }
    {
      // A name one screen declares (state name=…) that another's values
      // and actions use without declaring it.
      final declared = <String, Map<String, Object?>>{};
      final stated = <String, Set<String>>{}, used = <String, Set<String>>{};
      for (final screen in screens) {
        // The names this screen declares itself, on a state line.
        final own = stated[screen.id] = {
          for (final m in RegExp(r'^(?:state|computed)\s+([A-Za-z_][A-Za-z0-9_]*)\s*=', multiLine: true).allMatches(screen.text)) m[1]!,
        };
        final r = expand(screen);
        if (r == null) continue;
        for (final scope in ((r.document['variables'] as Map?) ?? const {}).values) {
          for (final v in scope as List) {
            if (own.contains((v as Map)['name'])) declared.putIfAbsent(v['name'] as String, () => v.cast<String, Object?>());
          }
        }
        // The names its values and actions use.
        final names = used[screen.id] = <String>{};
        void walk(Object? v) {
          if (v is Map) {
            if (v['type'] == 'setVariable' && v['variable'] is String) names.add(v['variable'] as String);
            v.values.forEach(walk);
          } else if (v is List) {
            v.forEach(walk);
          } else if (v is String && v.contains(r'${')) {
            for (final m in RegExp(r'(?<![.A-Za-z0-9_])[A-Za-z_][A-Za-z0-9_]*').allMatches(v.replaceAll(RegExp(r'"[^"]*"' "|'[^']*'"), '""'))) {
              names.add(m[0]!);
            }
          }
        }

        walk(r.document['nodes']);
      }
      shared = {
        ...shared,
        for (final screen in screens)
          for (final n in used[screen.id] ?? const <String>{})
            if (!stated[screen.id]!.contains(n) && declared[n] != null) n: declared[n]!,
      };
    }
    for (final screen in screens) {
      screenCount++;
      final result = expand(screen);
      if (result == null) {
        issues++;
        const shape = 'THROWN: the parser threw on this screen';
        final at = issueShapes[shape] ?? (count: 0, files: <String>{}, examples: <String>[]);
        issueShapes[shape] = (count: at.count + 1, files: at.files..add(name), examples: at.examples..add('$name / ${screen.name}'));
        continue;
      }
      final source = const LineSplitter().convert(screen.text);
      // Grammar issues: what the notation could not read, vocabulary aside.
      for (final i in result.issues) {
        issues++;
        final shape = _shape(i.message);
        final at = issueShapes[shape] ?? (count: 0, files: <String>{}, examples: <String>[]);
        final line = i.line >= 1 && i.line <= source.length ? source[i.line - 1].trim() : '';
        if (at.examples.length < 3) at.examples.add('$name:${screen.from + i.line - 1}: ${line.length > 200 ? '${line.substring(0, 197)}...' : line}');
        issueShapes[shape] = (count: at.count + 1, files: at.files..add(name), examples: at.examples);
      }

      corpus.screen(name, screen.text, result);
      // Every use recorded, by its line.
      final unknownAt = <int>{}, aliasAt = <int, VocabularyUse>{}, definedAt = <int, VocabularyUse>{};
      for (final u in result.vocabulary) {
        if (u.kind == 'definition') {
          definedAt[u.line] = u;
          continue;
        }
        // A universal word read (codelessly_api docs/design/21): counted with
        // every word (vocabulary_words.dart), not a word we lack.
        if (u.kind == 'universal') continue;
        if (u.kind == 'type') {
          unknownAt.add(u.line);
          standIns++;
          final w = types.putIfAbsent('${u.word} unknown', () => _Word(u.word, 'type'));
          w.files.add(name);
          w.uses++;
          w.example(u.source);
          for (final k in u.parameters.keys) {
            w.parameters[k] = (w.parameters[k] ?? 0) + 1;
          }
          for (final k in u.flags) {
            w.flags[k] = (w.flags[k] ?? 0) + 1;
          }
          for (final k in u.events.keys) {
            w.events[k] = (w.events[k] ?? 0) + 1;
          }
          for (final k in u.children) {
            w.children[k] = (w.children[k] ?? 0) + 1;
          }
          if (u.texts.isNotEmpty) w.parameters['"text"'] = (w.parameters['"text"'] ?? 0) + 1;
          continue;
        }
        if (u.kind == 'alias' && (u.of == 'type' || u.of == 'line')) aliasAt[u.line] = u;
        final target = u.kind != 'alias' ? null : u.of == 'line' ? u.to!.split(RegExp(r'[ #]')).first : u.to;
        final key = u.kind == 'alias' ? '${u.of}:${u.on ?? ''}.${u.word}>$target' : '${u.kind == 'verb' || u.kind == 'children' ? '' : u.on ?? ''}.${u.word}';
        final w = others[u.kind]!.putIfAbsent(key, () => _Word(u.word, u.kind == 'alias' ? 'alias:${u.of}' : u.kind));
        if (u.kind != 'verb') w.on = u.on;
        w.resolved = u.kind == 'alias' ? 'alias' : 'unknown';
        if (u.kind == 'alias') w.to = target;
        w.files.add(name);
        w.uses++;
        w.example(u.source);
        if (u.kind == 'verb' && u.on != null) w.parameters[u.on!] = (w.parameters[u.on!] ?? 0) + 1;
        if (u.kind == 'parameter' && u.value != null) {
          final v = u.value!.startsWith('{') ? '{…}' : u.value!.startsWith('"') ? '"…"' : u.value!.startsWith('[') ? '[…]' : u.value!;
          w.values[v] = (w.values[v] ?? 0) + 1;
        }
      }
      // Every line that starts with a word, by how the word resolved.
      for (var i = 0; i < source.length; i++) {
        final line = source[i].trim();
        final parts = LineParts.of(line);
        if (parts == null) continue;
        if (_statements.contains(parts.word)) {
          statementLines++;
          continue;
        }
        lines++;
        final alias = aliasAt[i + 1];
        final String how;
        if (unknownAt.contains(i + 1)) {
          how = 'unknown';
        } else if (definedAt.containsKey(i + 1)) {
          how = 'definition';
        } else if (alias != null) {
          how = 'alias';
        } else if (components.contains(parts.word) && !notationTypes.containsKey(parts.word)) {
          how = 'component';
        } else {
          how = 'core';
        }
        count[how] = count[how]! + 1;
        total[how] = total[how]! + 1;
        if (how == 'unknown') continue;
        final w = types.putIfAbsent('${parts.word} $how', () => _Word(parts.word, 'type'));
        w.resolved = how;
        if (alias != null) w.to = alias.of == 'line' ? alias.to!.split(RegExp(r'[ #]')).first : alias.to;
        if (definedAt[i + 1] case final d?) w.to = {...?w.to?.split(', '), d.to!}.join(', ');
        w.files.add(name);
        w.uses++;
        w.example(line);
        for (final p in parts.parts) {
          final into = p.kind == 'word' ? w.flags : p.isEvent ? w.events : p.kind == 'pair' ? w.parameters : null;
          final k = p.kind == 'word' ? p.raw : p.key;
          if (into != null && k != null) into[k] = (into[k] ?? 0) + 1;
        }
      }
      pages.add(screen.id);
      written[screen.id] = result.document;
    }
    // A page named by part of its name (go cook: "Cook mode"; go add-recipe:
    // "Add a recipe") is that page.
    String page(String to) {
      if (pages.contains(to)) return to;
      // `go decks_and_mixer`: a screen's id here is its name with hyphens.
      final t = to.replaceAll('_', '-').toLowerCase();
      if (pages.contains(t)) return t;
      final words = t.split('-');
      final near = pages.where((p) => p.startsWith('$t-') || words.every(p.split('-').contains)).toList();
      return near.length == 1 ? near.first : to;
    }

    void walk(Object? v) {
      if (v is Map) {
        if (v['type'] == 'navigate' && v['to'] is String) v['to'] = page(v['to'] as String);
        v.values.forEach(walk);
      } else if (v is List) {
        v.forEach(walk);
      }
    }

    written.values.forEach(walk);
    // What does not validate, as a site (an open-vocabulary page always
    // should): each page against the others' screens and the app's state.
    final manifest = SiteManifest.fromJson({'schema': 3, 'pages': [for (final p in pages) '$p.json'], if (shared.isNotEmpty) 'variables': shared.values.toList()});
    final invalidHere = Catalog.run(
            catalog,
            () => validateProject({for (final e in written.entries) '${e.key}.json': e.value},
                options: ValidateOptions(
                    theme: theme,
                    components: ds.components,
                    // Formulas are parsed as the renderer parses them.
                    formulas: (formula) => (error: FormulaEvaluator.errorOf(formula), paths: FormulaEvaluator.referencedPaths(formula))),
                manifest: manifest))
        .where((d) => d.severity == Severity.error)
        .toList();
    invalid = invalidHere.length;
    for (final d in invalidHere) {
      // A function a formula calls that we do not have is vocabulary too.
      if (RegExp(r'Unknown function "([A-Za-z_][A-Za-z0-9_]*)"').firstMatch(d.message) case final RegExpMatch m) {
        final w = others['function']!.putIfAbsent(m[1]!, () => _Word(m[1]!, 'function'));
        w.files.add(name);
        w.uses++;
        w.example(RegExp(r'The formula "(.*)" does not parse').firstMatch(d.message)?[1] ?? d.message);
      }
      final shape = '${d.code.name}: ${_shape(d.message)}';
      final at = invalidShapes[shape] ?? (count: 0, files: <String>{}, examples: <String>[]);
      if (at.examples.length < 3) at.examples.add('$name/${d.file ?? ''} ${d.path}: ${d.message.length > 160 ? '${d.message.substring(0, 157)}...' : d.message}');
      invalidShapes[shape] = (count: at.count + 1, files: at.files..add(name), examples: at.examples);
    }
    if (sites != null) {
      final dir = Directory('$sites/$name')..createSync(recursive: true);
      for (final e in written.entries) {
        File('${dir.path}/${e.key}.json').writeAsStringSync(const JsonEncoder.withIndent(' ').convert(e.value));
      }
      File('${dir.path}/site.json').writeAsStringSync(const JsonEncoder.withIndent(' ').convert({
        'schema': 3,
        'pages': [for (final p in pages) '$p.json'],
        'designSystem': _relative(dsDir, dir.path),
        if (shared.isNotEmpty) 'variables': shared.values.toList(),
      }));
    }
    perFile.add({
      'file': name,
      'screens': screens.length,
      'lines': lines,
      ...count,
      'standIns': standIns,
      'issues': issues,
      'invalid': invalid,
    });
  }

  final typeWords = _sorted(types.values);
  for (final w in typeWords.where((w) => w.resolved == 'unknown')) {
    for (final f in w.files) {
      harvest.unknown(w.word, f);
    }
  }
  final unknownTypes = typeWords.where((w) => w.resolved == 'unknown').toList();
  // Words that share a part of their name may be one word under several names.
  final byStem = <String, List<_Word>>{};
  for (final w in unknownTypes) {
    for (final s in _stems(w.word).toSet()) {
      if (s.length < 4 || _plainStems.contains(s)) continue;
      byStem.putIfAbsent(s, () => []).add(w);
    }
  }
  final synonyms = byStem.entries.where((e) => e.value.length > 1).toList()
    ..sort((a, b) {
      int f(List<_Word> l) => l.expand((w) => w.files).toSet().length;
      return f(b.value) != f(a.value) ? f(b.value) - f(a.value) : a.key.compareTo(b.key);
    });
  final shapes = issueShapes.entries.toList()..sort((a, b) => b.value.count - a.value.count);
  final nodeLines = total.values.reduce((a, b) => a + b);

  final json = {
    'designSystem': ds.name,
    'aliasTable': args.contains('--no-aliases') ? 'none' : 'built-in${File('$dsDir/vocabulary.json').existsSync() ? ' + ${ds.name}' : ''}${opt('--aliases') == null ? '' : ' + ${opt('--aliases')}'}',
    'width': width,
    'files': files.length,
    'screens': screenCount,
    'lines': {'nodes': nodeLines, 'statements': statementLines, ...total},
    'perFile': perFile,
    'issues': [
      for (final e in shapes) {'message': e.key, 'count': e.value.count, 'files': e.value.files.length, 'examples': e.value.examples},
    ],
    'invalid': [
      for (final e in invalidShapes.entries.toList()..sort((a, b) => b.value.count - a.value.count))
        {'message': e.key, 'count': e.value.count, 'files': e.value.files.length, 'examples': e.value.examples},
    ],
    'types': [for (final w in typeWords) w.toJson()],
    for (final k in const ['parameter', 'flag', 'event', 'verb', 'function', 'variant', 'missing', 'children', 'alias', 'overlay'])
      switch (k) { 'alias' => 'aliases', 'missing' => 'missing', 'children' => 'children', _ => '${k}s' }: [for (final w in _sorted(others[k]!.values)) w.toJson()],
    'summary': corpus.summary(),
    'words': [for (final w in corpus.sorted()) w.toJson()],
    'harvest': harvest.toJson(),
    'synonyms': [
      for (final e in synonyms) {'stem': e.key, 'words': [for (final w in _sorted(e.value)) w.word]},
    ],
  };
  File('${outDir.path}/vocabulary.json').writeAsStringSync('${const JsonEncoder.withIndent(' ').convert(json)}\n');

  final summary = corpus.summary();
  final allWords = corpus.words.length;
  final resolvedWords = allWords - summary.values.fold<int>(0, (a, m) => a + m['unknown']!);
  String pct(int n) => nodeLines == 0 ? '0%' : '${(100 * n / nodeLines).toStringAsFixed(1)}%';
  String code(String s) => '`${s.replaceAll('`', "'").replaceAll('|', r'\|')}`';
  String top(Map<String, int> m, [int n = 8]) => _ranked(m).entries.take(n).map((e) => e.value > 1 ? '${e.key} ×${e.value}' : e.key).join(', ');
  final md = StringBuffer()
    ..writeln('# Vocabulary')
    ..writeln()
    ..writeln('Written by `tool/notation/notation.sh vocabulary` (codelessly_api docs/design/19-open-vocabulary.md). Do not edit: run it again.')
    ..writeln()
    ..writeln('${files.length} files, $screenCount screens, expanded ${width.round()} wide with ${ds.name}; aliases: ${json['aliasTable']}.')
    ..writeln()
    ..writeln('$nodeLines lines start with a word: ${total['core']} a core word (${pct(total['core']!)}), ${total['component']} a ${ds.name} component (${pct(total['component']!)}), '
        '${total['alias']} an alias of a word we have (${pct(total['alias']!)}), ${total['definition']} a word defined in the notation (${pct(total['definition']!)}), '
        '${total['unknown']} a word we do not have (${pct(total['unknown']!)}), which stands in. '
        '$statementLines more are statements (state, if, each, key, every).')
    ..writeln()
    ..writeln('## Every word used, by kind and how it resolved')
    ..writeln()
    ..writeln('Distinct words, each once (a text, parameter, flag, event or variant once per type it is on; `vocabulary_words.dart` says how each kind is read). '
        'Resolved: ${resolvedWords} of ${allWords} (${allWords == 0 ? 0 : (100 * resolvedWords / allWords).toStringAsFixed(1)}%).')
    ..writeln()
    ..writeln('| kind | words | ${wordResolutions.join(' | ')} |')
    ..writeln('|---|---|${wordResolutions.map((_) => '---|').join()}');
  for (final k in wordKinds) {
    final row = summary[k]!;
    md.writeln('| $k | ${row.values.fold<int>(0, (a, b) => a + b)} | ${wordResolutions.map((r) => row[r]).join(' | ')} |');
  }
  md
    ..writeln('| all | $allWords | ${wordResolutions.map((r) => summary.values.fold<int>(0, (a, m) => a + m[r]!)).join(' | ')} |')
    ..writeln()
    ..writeln('## By file')
    ..writeln()
    ..writeln('| file | screens | lines | core | component | alias | definition | unknown | grammar issues | does not validate |')
    ..writeln('|---|---|---|---|---|---|---|---|---|---|');
  for (final f in perFile) {
    md.writeln('| ${f['file']} | ${f['screens']} | ${f['lines']} | ${f['core']} | ${f['component']} | ${f['alias']} | ${f['definition']} | ${f['unknown']} | ${f['issues']} | ${f['invalid']} |');
  }
  md
    ..writeln()
    ..writeln('## Words we do not have, by how many files reached for them')
    ..writeln()
    ..writeln('| files | uses | word | given (strings, key=value) | flags | events | lines under it | an example |')
    ..writeln('|---|---|---|---|---|---|---|---|');
  for (final w in unknownTypes) {
    md.writeln('| ${w.files.length} | ${w.uses} | ${w.word} | ${top(w.parameters)} | ${top(w.flags, 5)} | ${top(w.events, 5)} | ${top(w.children, 5)} | ${w.examples.isEmpty ? '' : code(w.examples.first)} |');
  }
  md
    ..writeln()
    ..writeln('## Names that may be one word')
    ..writeln()
    ..writeln('Unknown words that share a part of their name, side by side (files each).')
    ..writeln();
  for (final e in synonyms) {
    md.writeln('- **${e.key}**: ${_sorted(e.value).map((w) => '${w.word} (${w.files.length})').join(', ')}');
  }
  md.write(harvest.markdown());
  void section(String title, String note, Iterable<_Word> words, {bool withOn = true, bool target = false}) {
    md
      ..writeln()
      ..writeln('## $title')
      ..writeln()
      ..writeln(note)
      ..writeln()
      ..writeln('| files | uses | ${withOn ? 'on | ' : ''}word | ${target ? 'read as | ' : ''}an example |')
      ..writeln('|---|---|${withOn ? '---|' : ''}---|${target ? '---|' : ''}---|');
    for (final w in words) {
      md.writeln('| ${w.files.length} | ${w.uses} | ${withOn ? '${w.on ?? ''} | ' : ''}${w.word} | ${target ? '${w.to == null ? '' : code(w.to!)} | ' : ''}${w.examples.isEmpty ? '' : code(w.examples.first)} |');
    }
  }

  section('Aliases used', 'Names read as a word we have (the alias table).', _sorted(others['alias']!.values), target: true);
  section('Parameters we do not have, on words we have', 'Left out of the document.', _sorted(others['parameter']!.values));
  section('Flags we do not have, on words we have', 'Left out of the document.', _sorted(others['flag']!.values));
  section('Events we do not have, on words we have', 'Their actions are read; the event is left out.', _sorted(others['event']!.values));
  section('Action verbs we do not have', 'Left out of the event they are in.', _sorted(others['verb']!.values), withOn: false);
  section('Formula functions we do not have', 'Counted where a formula that calls one does not parse (once per formula): the value it gives is empty.', _sorted(others['function']!.values), withOn: false);
  section('Variants we do not have', 'The plain type is drawn.', _sorted(others['variant']!.values), withOn: false);
  section('Parameters a component needs that the line did not give', 'The answer\'s idea of the word is not the component\'s: it is given an empty value.', _sorted(others['missing']!.values));
  section('Words given lines under them that take none', 'The lines are drawn after the word, not in it.', _sorted(others['children']!.values), withOn: false);
  section('Overlays opened and never written', 'An `open <id>` of a dialog the answer did not write: a placeholder sheet titled with the id opens (wanted, not an issue).',
      _sorted(others['overlay']!.values),
      withOn: false);
  md
    ..writeln()
    ..writeln('## Words we have, as the answers used them')
    ..writeln()
    ..writeln('| files | uses | word | how | parameters | flags | events |')
    ..writeln('|---|---|---|---|---|---|---|');
  for (final w in typeWords.where((w) => w.resolved != 'unknown')) {
    md.writeln('| ${w.files.length} | ${w.uses} | ${w.word} | ${w.resolved}${w.to == null ? '' : ' → ${w.to}'} | ${top(w.parameters)} | ${top(w.flags, 5)} | ${top(w.events, 5)} |');
  }
  // What each word we have was given, from every use: the parameters,
  // flags and events written on it with how many uses, those it does not
  // take marked ✗; for a component and a defined word, what it takes that no
  // answer wrote.
  final givenOn = <String, List<CorpusWord>>{};
  for (final w in corpus.words.values) {
    if (w.on != null && w.kind != 'variant' && w.kind != 'text') givenOn.putIfAbsent(w.on!, () => []).add(w);
  }
  final takes = <String, Set<String>>{
    for (final c in ds.list) c.type: {for (final p in c.spec.props) p.key, for (final e in c.spec.events) e.key},
    for (final e in table.definitions.entries) e.key: {for (final d in e.value) ...[...d.parameters.keys, ...d.events, ...d.strings, if (d.bind != null) 'bind']},
  };
  md
    ..writeln()
    ..writeln('## What each word we have was given')
    ..writeln()
    ..writeln('Every parameter, flag and event written on a type the notation reads (core, component, alias or definition), with its uses; ✗: one it does not take (left out). '
        'For a component or a defined word, what it takes that no answer wrote.')
    ..writeln()
    ..writeln('| uses | type | how | given | never given |')
    ..writeln('|---|---|---|---|---|');
  for (final t in corpus.sorted().where((w) => w.kind == 'type' && w.resolved != 'unknown')) {
    final on = (givenOn[t.word] ?? <CorpusWord>[])..sort((a, b) => b.uses - a.uses);
    final written = {for (final w in on) w.word};
    final never = [for (final k in (t.resolved == 'component' || t.resolved == 'definition' ? takes[t.word] : null) ?? const <String>{}) if (!written.contains(k)) k]..sort();
    md.writeln('| ${t.uses} | ${t.word} | ${t.resolved}${t.to.isEmpty ? '' : ' → ${t.to.join(', ')}'} | '
        '${on.map((w) => '${w.word}${w.resolved == 'unknown' ? ' ✗' : ''}${w.uses > 1 ? ' ×${w.uses}' : ''}').join(', ')} | ${never.join(', ')} |');
  }
  md
    ..writeln()
    ..writeln('## Grammar issues')
    ..writeln()
    ..writeln('What the notation could not read, vocabulary aside (the grammar is not open). The same complaint counts once per line it was made on.')
    ..writeln()
    ..writeln('| count | files | message | an example |')
    ..writeln('|---|---|---|---|');
  for (final e in shapes) {
    md.writeln('| ${e.value.count} | ${e.value.files.length} | ${e.key.replaceAll('|', r'\|')} | ${e.value.examples.isEmpty ? '' : code(e.value.examples.first)} |');
  }
  md
    ..writeln()
    ..writeln('## What does not validate')
    ..writeln()
    ..writeln('Each file\'s screens checked together as a site, with the state one screen declares and another uses taken as the site\'s.')
    ..writeln()
    ..writeln('| count | files | problem | an example |')
    ..writeln('|---|---|---|---|');
  for (final e in invalidShapes.entries.toList()..sort((a, b) => b.value.count - a.value.count)) {
    md.writeln('| ${e.value.count} | ${e.value.files.length} | ${e.key.replaceAll('|', r'\|')} | ${e.value.examples.isEmpty ? '' : code(e.value.examples.first)} |');
  }
  File('${outDir.path}/VOCABULARY.md').writeAsStringSync(md.toString());

  stdout.writeln('${files.length} files, $screenCount screens, $nodeLines node lines: core ${total['core']}, component ${total['component']}, alias ${total['alias']}, definition ${total['definition']}, unknown ${total['unknown']}; '
      '$allWords words, $resolvedWords resolved; '
      '${unknownTypes.length} unknown words; ${shapes.fold<int>(0, (n, e) => n + e.value.count)} grammar issues; '
      '${others['overlay']!.values.fold<int>(0, (n, w) => n + w.uses)} overlays opened and never written; '
      '${harvest.words.length} words defined in more than one answer; '
      '${perFile.fold<int>(0, (n, f) => n + (f['invalid']! as int))} validation errors.');
  stdout.writeln('${outDir.path}/vocabulary.json, ${outDir.path}/VOCABULARY.md');
}
