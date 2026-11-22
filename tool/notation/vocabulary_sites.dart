// The harvest across runs (codelessly_api docs/design/19-open-vocabulary.md,
// section 15): `notation.sh vocabulary` given writers' site folders (each
// with pages/, components/, site/site.json, and drafts/ holding screens as
// first written) or the vocabulary records `expand` saved (vocabulary.json),
// or a folder holding any of them, writes one merged report: every word
// beyond the core, how many runs and apps reached for it, the shapes it was
// written in (grouped where they agree), how it resolved, the writers'
// definitions, and a ranked list of candidates to support.
//
//   notation.sh vocabulary <site folder | vocabulary.json | folder of them>...
//       [--design-system <folder>] [--aliases <file.json>] [--out <dir>]
//
// A site folder is expanded as `expand <folder> --open` would (its pages, its
// components, its components/*.txt of `define` blocks) and its drafts too
// (drafts/*.txt but *.issues.txt, drafts/pages/*.txt, drafts/components/*.txt:
// each as a page or a component of the site as it is now), over its own
// record when it has one; nothing in it is written. A run is one site folder
// or record (one writer); its app is the folder above it when the inputs
// are laid out <app>/<run> (the five apps of test 10, four modalities each).
import 'dart:convert';
import 'dart:io';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_api/notation.dart';

import 'notation_site.dart';
import 'vocabulary.dart' show loadVocabulary;
import 'vocabulary_record.dart';
import 'vocabulary_words.dart';

// (A writer's site folder is one that holds notation, pages/ or components/
// or app.txt, with a site.json or none: notation_site.dart's isSiteFolder.)

/// Whether [path] is a vocabulary record (vocabulary_record.dart).
bool isRecordFile(String path) => path.endsWith('.json') && readRecord(path) != null;

/// Whether [given] (the inputs of `notation.sh vocabulary`) are sites and
/// records, for [harvestSites], rather than a corpus of answers.
bool areSitesOrRecords(List<String> given) => given.isNotEmpty && given.every((g) => isRecordFile(g) || (FileSystemEntity.isDirectorySync(g) && _found(g).isNotEmpty));

/// The site folders and records at or under [path] (four folders deep; not
/// inside a site's drafts/, out/ or site/).
List<String> _found(String path) {
  if (isRecordFile(path)) return [path];
  if (!FileSystemEntity.isDirectorySync(path)) return const [];
  if (isSiteFolder(path)) return [path];
  // A folder of answers (*.txt) is a corpus, not sites.
  if (Directory(path).listSync().whereType<File>().any((f) => f.path.endsWith('.txt'))) return const [];
  final out = <String>[];
  void walk(Directory d, int depth) {
    if (depth > 4) return;
    for (final e in d.listSync()..sort((a, b) => a.path.compareTo(b.path))) {
      if (e is! Directory) continue;
      final name = e.uri.pathSegments.where((s) => s.isNotEmpty).last;
      if (const {'drafts', 'out', 'site', 'node_modules', '.git'}.contains(name)) continue;
      if (isSiteFolder(e.path)) {
        out.add(e.path);
      } else if (File('${e.path}/vocabulary.json').existsSync() && isRecordFile('${e.path}/vocabulary.json')) {
        out.add('${e.path}/vocabulary.json');
      } else {
        walk(e, depth + 1);
      }
    }
  }

  walk(Directory(path), 0);
  return out;
}

/// One run's record: a site folder expanded now (over its record), or a
/// record read.
typedef HarvestRun = ({String id, String app, String source, Map<String, Object?> record, List<String> skipped});

/// [site]'s folder expanded as `expand --open` does, with its drafts, into a
/// record (over the one it has), writing nothing.
Future<HarvestRun> expandRun(String folder, {required String id, required String app, DesignSystem? ds, required NotationVocabulary aliases, DateTime? time}) async {
  final site = await NotationSite.load(findSiteManifest(site: folder)!);
  final settings = (width: 1440.0, reflow: true, named: false, nearestColors: false, open: true, aliases: aliases);
  final expander = NotationExpander(site: site, designSystem: ds, settings: settings);
  final components = {for (final c in ds?.list ?? const <DesignSystemComponent>[]) c.type, for (final c in site.designSystem?.list ?? const <DesignSystemComponent>[]) c.type};
  final snap = siteSnapshot(site, components: components, open: true, dir: site.home);
  final expanded = expandSitePages(expander, site);
  for (final c in expanded.components) {
    final text = File(c.path).readAsStringSync();
    snap.file(recordPath(c.path, site.home), text, expanded.componentResults[c.type]!, extra: site.definitionText, page: c.type);
  }
  for (final (i, p) in expanded.pages.indexed) {
    final text = File(p.path).readAsStringSync();
    snap.file(recordPath(p.path, site.home), text, expanded.results[i], extra: site.definitionText, page: p.name);
  }
  // The drafts: each screen as first written, as a page (or a component)
  // of the site as it is now.
  final drafts = <File>[
    for (final d in ['drafts', 'drafts/pages', 'drafts/components'])
      if (Directory('${site.home}/$d').existsSync())
        ...Directory('${site.home}/$d').listSync().whereType<File>().where((f) => f.path.endsWith('.txt') && !f.path.endsWith('.issues.txt')),
  ]..sort((a, b) => a.path.compareTo(b.path));
  for (final f in drafts) {
    final text = f.readAsStringSync();
    if (text.trim().isEmpty) continue;
    final stem = pageNameOf(f.path);
    final NotationResult r;
    try {
      r = expander.expand(text, path: f.path, screen: componentTypeOf(text) ?? stem);
    } on Object {
      continue;
    }
    snap.file(recordPath(f.path, site.home), text, r, extra: site.definitionText, page: componentTypeOf(text) ?? stem);
  }
  final record = mergeRecord(readRecord('${site.home}/vocabulary.json'), snap, time: time ?? DateTime.now(), whole: true);
  return (id: id, app: app, source: folder, record: record, skipped: [for (final s in site.skipped) s.message]);
}

/// A signature's parts after its word, each key without its `=`/`=@`, a
/// text counted by position: `text1`, `text2`.
Set<String> shapeOf(String signature) {
  final parts = signature.split(' ').skip(1);
  var texts = 0;
  return {
    for (final p in parts)
      if (p == '"text"') 'text${++texts}' else if (p.endsWith('=@')) p.substring(0, p.length - 2) else if (p.endsWith('=')) p.substring(0, p.length - 1) else p,
  };
}

double _jaccard(Set<String> a, Set<String> b) => a.isEmpty && b.isEmpty ? 1 : a.intersection(b).length / a.union(b).length;

/// The signature of a definition's text (`define Word "text" key=1 onX`).
String? definitionSignature(String text) {
  for (final l in const LineSplitter().convert(text)) {
    final m = RegExp(r'^(?:define|primitive)\s+(.*)$').firstMatch(l.trim());
    if (m == null) continue;
    final parts = LineParts.of(m[1]!);
    if (parts == null) return null;
    final children = RegExp(r'^\s+\.\.\.\s*$', multiLine: true).hasMatch(text);
    return CorpusWords.lineSignature(parts, children: children);
  }
  return null;
}

/// The words of [runs] beyond the core, merged: by word, each run's uses,
/// resolutions, shapes and definition.
final class HarvestWord {
  HarvestWord(this.kind, this.on, this.word);
  final String kind, word;
  final String? on;
  final byRun = <String, Map<String, Object?>>{};
  final apps = <String>{};

  int get runs => byRun.length;
  int get uses => byRun.values.fold(0, (n, r) => n + (r['uses'] as int));
  String get name => on == null ? word : '$on.$word';

  /// How its uses resolved, over every run (now, and once, for a word no
  /// longer used).
  Map<String, int> get how {
    final out = <String, int>{};
    for (final r in byRun.values) {
      for (final e in (r['how'] as Map<String, int>).entries) {
        out[e.key] = (out[e.key] ?? 0) + e.value;
      }
    }
    return out;
  }

  /// Each run's shape: its definition's signature when it defined the
  /// word, else the signature it wrote most.
  Map<String, String> get shapes => {
        for (final e in byRun.entries)
          if ((e.value['definitionSignature'] ?? (e.value['signatures'] as List).firstOrNull) case final String s) e.key: s,
      };

  /// The most runs whose shapes agree (each two sharing at least half of
  /// their parts, with the one they gather around), and those parts that at
  /// least half of all shapes have.
  ({int agree, List<String> core}) get agreement {
    final s = {for (final e in shapes.entries) e.key: shapeOf(e.value)};
    if (s.isEmpty) return (agree: 0, core: const []);
    var best = 0;
    for (final a in s.values) {
      final n = s.values.where((b) => _jaccard(a, b) >= 0.5).length;
      if (n > best) best = n;
    }
    final counts = <String, int>{};
    for (final v in s.values) {
      for (final p in v) {
        counts[p] = (counts[p] ?? 0) + 1;
      }
    }
    return (agree: best, core: [for (final e in counts.entries) if (e.value * 2 >= s.length) e.key]..sort());
  }

  /// The shapes, grouped where they are the same (a shape: the runs).
  Map<String, List<String>> get shapeGroups {
    final out = <String, List<String>>{};
    for (final e in shapes.entries) {
      final key = (shapeOf(e.value).toList()..sort()).join(' ');
      out.putIfAbsent(key.isEmpty ? '(nothing given)' : key, () => []).add(e.key);
    }
    return Map.fromEntries(out.entries.toList()..sort((a, b) => b.value.length - a.value.length));
  }

  Map<String, Object?> toJson() {
    final a = agreement;
    return {
      'kind': kind,
      'on': ?on,
      'word': word,
      'runs': runs,
      'apps': apps.length,
      'uses': uses,
      'how': how,
      'agree': a.agree,
      'sharedParts': a.core,
      'shapes': shapeGroups,
      'byRun': byRun,
    };
  }
}

const _beyondCore = {'component', 'site', 'alias', 'definition', 'universal', 'primitive', 'unread', 'refused', 'unknown'};

/// The resolutions that make a word a candidate to support: the writer
/// made it up (defined it, wrote a component, or left it a placeholder).
const _candidateHow = {'site', 'definition', 'primitive', 'unread', 'refused', 'unknown'};

/// The harvest of [runs]: every word beyond the core, by word.
Map<String, HarvestWord> mergeRuns(List<HarvestRun> runs) {
  final out = <String, HarvestWord>{};
  for (final run in runs) {
    for (final raw in (run.record['words'] as List?) ?? const []) {
      final w = (raw as Map).cast<String, Object?>();
      final kind = w['kind'] as String;
      if (kind == 'text' || kind == 'statement') continue;
      final how = <String, int>{for (final e in ((w['how'] as Map?) ?? const {}).entries) '${e.key}': e.value as int};
      final ever = ((w['history'] as Map?) ?? const {}).keys.map((k) => '$k').where(_beyondCore.contains).toSet();
      final def = (w['definition'] as Map?)?.cast<String, Object?>();
      final definedBy = '${w['definedBy'] ?? def?['by'] ?? ''}';
      // A word a design system defines is one we have, as a component is.
      final writers = how.keys.any(_beyondCore.contains) || ever.isNotEmpty || (def != null && definedBy != 'design system');
      if (!writers) continue;
      final hw = out.putIfAbsent(CorpusWords.keyOf(kind, w['on'] as String?, w['word'] as String), () => HarvestWord(kind, w['on'] as String?, w['word'] as String));
      hw.apps.add(run.app);
      final files = ((w['files'] as Map?) ?? const {}).cast<String, Object?>();
      final finalFiles = [for (final f in files.keys) if (!f.startsWith('drafts/')) f];
      hw.byRun[run.id] = {
        'status': w['status'],
        'uses': w['uses'] ?? 0,
        'how': how.isEmpty ? {for (final k in ever) k: 0} : how,
        if (ever.difference(how.keys.toSet()).isNotEmpty) 'once': (ever.difference(how.keys.toSet()).toList()..sort()),
        if (definedBy.isNotEmpty) 'definedBy': definedBy,
        'in': finalFiles.isNotEmpty ? 'final' : files.isNotEmpty ? 'drafts only' : 'no longer used',
        'where': [for (final f in files.entries) '${f.key}:${((((f.value as Map)['lines'] as List?) ?? const [])).join(',')}'],
        'signatures': [for (final s in (w['signatures'] as List?) ?? const []) '${(s as Map)['signature']}'],
        if (w['messages'] case final List m) 'messages': m,
        if (def != null) 'definition': def['text'],
        if (def != null) 'definitionFile': '${def['file']}:${def['line']}${def['loaded'] == false ? ' (not loaded)' : ''}',
        if (def == null ? null : definitionSignature('${def['text']}') case final String s) 'definitionSignature': s,
      };
    }
  }
  return out;
}

/// The candidates to support, best first: types the writers made up,
/// reached for by more than one run, ranked by runs, then how many of them
/// agree on a shape, then apps, then uses. With [types] false, the other
/// words that more than one run wrote and the notation left out, refused or
/// never read (a parameter of the writer's own component is its shape, not
/// a candidate of its own).
List<HarvestWord> rankCandidates(Iterable<HarvestWord> words, {bool types = true}) {
  bool candidate(Map<String, Object?> r) {
    final how = {...(r['how'] as Map).keys.map((k) => '$k'), ...((r['once'] as List?) ?? const []).map((k) => '$k')};
    if (!types) return how.any(const {'unknown', 'refused', 'unread'}.contains);
    return how.any(_candidateHow.contains) && r['definedBy'] != 'design system';
  }

  final list = [
    for (final w in words)
      if ((w.kind == 'type') == types && w.runs > 1 && w.byRun.values.where(candidate).length > 1) w,
  ];
  list.sort((a, b) {
    if (b.runs != a.runs) return b.runs - a.runs;
    final aa = a.agreement.agree, ba = b.agreement.agree;
    if (ba != aa) return ba - aa;
    if (b.apps.length != a.apps.length) return b.apps.length - a.apps.length;
    if (b.uses != a.uses) return b.uses - a.uses;
    return a.name.compareTo(b.name);
  });
  return list;
}

/// Reads [given] (site folders, records, folders of them), merges them and
/// writes `<out>/vocabulary.json` and `<out>/VOCABULARY.md`.
Future<void> harvestSites(List<String> given, {String? out, String? designSystem, String? aliasesFile}) async {
  final inputs = [for (final g in given) ..._found(g)];
  if (inputs.isEmpty) {
    stderr.writeln('No site folder (pages/ or components/ beside site/site.json) or vocabulary record in ${given.join(', ')}.');
    exit(2);
  }
  DesignSystem? ds;
  if (designSystem != null) {
    final problems = <String>[];
    ds = await DesignSystem.load((ref) async {
      final f = File('$designSystem/$ref');
      return f.existsSync() ? f.readAsStringSync() : null;
    }, problems: problems);
    if (problems.isNotEmpty) {
      stderr.writeln('The design system at $designSystem does not load cleanly: ${problems.join('; ')}');
      exit(2);
    }
  }
  final aliases = loadVocabulary(dir: designSystem, file: aliasesFile);
  // Runs are named from the folder the inputs share.
  List<String> segs(String p) => File(p).absolute.path.replaceAll(r'\', '/').split('/').where((s) => s.isNotEmpty).toList();
  final folders = [for (final i in inputs) isRecordFile(i) ? (segs(i)..removeLast()) : segs(i)];
  var common = folders.first.length;
  for (final f in folders) {
    var k = 0;
    while (k < common && k < f.length && f[k].toLowerCase() == folders.first[k].toLowerCase()) {
      k++;
    }
    common = k;
  }
  if (folders.length == 1) common = folders.first.length - 1;
  final runs = <HarvestRun>[];
  for (final (n, i) in inputs.indexed) {
    final rel = folders[n].sublist(common);
    final id = rel.isEmpty ? folders[n].last : rel.join('/');
    final app = rel.length >= 2 ? rel.first : id;
    if (isRecordFile(i)) {
      runs.add((id: id, app: app, source: i, record: readRecord(i)!, skipped: const []));
    } else {
      stderr.writeln('expanding $id ...');
      runs.add(await expandRun(i, id: id, app: app, ds: ds, aliases: aliases));
    }
  }
  final words = mergeRuns(runs);
  final candidates = rankCandidates(words.values);
  final otherCandidates = rankCandidates(words.values, types: false);
  final sorted = words.values.toList()
    ..sort((a, b) {
      final k = wordKinds.indexOf(a.kind) - wordKinds.indexOf(b.kind);
      if (k != 0) return k;
      if (b.runs != a.runs) return b.runs - a.runs;
      return a.name.compareTo(b.name);
    });
  bool any(HarvestWord w, String how) => w.byRun.values.any((r) => (r['how'] as Map).containsKey(how) || ((r['once'] as List?) ?? const []).contains(how));
  final outDir = Directory(out ?? (FileSystemEntity.isDirectorySync(given.first) ? given.first : File(given.first).parent.path))..createSync(recursive: true);
  final runRows = [
    for (final r in runs)
      () {
        final ws = [for (final w in (r.record['words'] as List?) ?? const []) (w as Map).cast<String, Object?>()];
        final files = ((r.record['files'] as Map?) ?? const {}).keys.map((k) => '$k').toList();
        int n(bool Function(Map<String, Object?>) f) => ws.where(f).length;
        return {
          'run': r.id,
          'app': r.app,
          'source': r.source,
          'files': files.where((f) => !f.startsWith('drafts/')).length,
          'drafts': files.where((f) => f.startsWith('drafts/')).length,
          'typesDefined': n((w) => w['kind'] == 'type' && w['definition'] != null && w['definedBy'] != 'design system'),
          'placeholders': ((r.record['placeholders'] as List?) ?? const []).length,
          'unknownWords': n((w) => w['kind'] != 'text' && (((w['how'] as Map?) ?? const {}).containsKey('unknown') || ((w['history'] as Map?) ?? const {}).containsKey('unknown'))),
          'refusedWords': n((w) => w['kind'] != 'text' && (((w['how'] as Map?) ?? const {}).containsKey('refused') || ((w['history'] as Map?) ?? const {}).containsKey('refused'))),
          'skipped': r.skipped,
        };
      }(),
  ];
  final json = {
    'harvest': 'every word beyond the core that the runs reached for (tool/notation/vocabulary_sites.dart)',
    'runs': runRows,
    'candidates': [for (final w in candidates) w.toJson()],
    'otherCandidates': [for (final w in otherCandidates) w.toJson()],
    'words': [for (final w in sorted) w.toJson()],
  };
  File('${outDir.path}/vocabulary.json').writeAsStringSync('${const JsonEncoder.withIndent(' ').convert(json)}\n');

  String code(Object? s) => '`${'$s'.replaceAll('`', "'").replaceAll('|', r'\|').replaceAll('\n', ' ')}`';
  String runsOf(HarvestWord w) => w.byRun.entries.map((e) => '${e.key}${e.value['in'] == 'final' ? '' : ' (${e.value['in']})'}').join(', ');
  String howOf(HarvestWord w) => w.how.entries.where((e) => e.value > 0).map((e) => '${e.key} ${e.value}').join(', ');
  final md = StringBuffer()
    ..writeln('# Vocabulary harvest')
    ..writeln()
    ..writeln('Written by `tool/notation/notation.sh vocabulary` from ${runs.length} runs (site folders expanded with `--open`, their drafts included, or vocabulary records): '
        'every word beyond the core they reached for. Do not edit: run it again. A run is one writer; an app is one brief.')
    ..writeln()
    ..writeln('## Runs')
    ..writeln()
    ..writeln('| run | pages and components | drafts | types defined | placeholders now | words ever unknown | words ever refused | component files not loaded |')
    ..writeln('|---|---|---|---|---|---|---|---|');
  for (final r in runRows) {
    md.writeln('| ${r['run']} | ${r['files']} | ${r['drafts']} | ${r['typesDefined']} | ${r['placeholders']} | ${r['unknownWords']} | ${r['refusedWords']} | ${(r['skipped'] as List).length} |');
  }
  void candidateSection(String title, String note, List<HarvestWord> list) {
    md
      ..writeln()
      ..writeln('## $title (${list.length})')
      ..writeln()
      ..writeln(note)
      ..writeln();
    for (final (i, w) in list.indexed) {
      final a = w.agreement;
      md
        ..writeln('### ${i + 1}. ${w.name} (${w.kind}): ${w.runs} runs, ${w.apps.length} apps, ${w.uses} uses; ${a.agree} of ${w.shapes.length} shapes agree')
        ..writeln()
        ..writeln('- runs: ${runsOf(w)}')
        ..writeln('- resolved: ${howOf(w)}')
        ..writeln('- parts at least half the shapes have: ${a.core.isEmpty ? '(none)' : a.core.join(', ')}');
      for (final g in w.shapeGroups.entries) {
        md.writeln('- shape ${code(g.key)}: ${g.value.join(', ')}');
      }
      final defs = [for (final e in w.byRun.entries) if (e.value['definition'] != null) e];
      for (final e in defs.take(3)) {
        md
          ..writeln()
          ..writeln('${e.key}, ${e.value['definitionFile']}:')
          ..writeln()
          ..writeln('```')
          ..writeln(_clip('${e.value['definition']}', 14))
          ..writeln('```');
      }
      if (defs.length > 3) md.writeln('\n(${defs.length - 3} more definitions in vocabulary.json)');
      md.writeln();
    }
  }

  candidateSection(
      'Candidates to support: types',
      'Types the writers made up (defined, wrote as a site component, declared a primitive, or left a placeholder) that more than one run reached for, '
          'ranked by runs, then by how many of their shapes agree (two shapes agree when they share at least half of their parts: strings by position, '
          'parameters, flags, events, `@` for a bound value, `...` for lines under it), then apps, then uses. A run\'s shape is its definition\'s signature when it defined the word, '
          'else the shape it wrote most.',
      candidates);
  candidateSection('Candidates to support: other words', 'Parameters, flags, events, variants, verbs, chords and functions more than one run wrote and the notation does not have (left out, refused, or never read).',
      otherCandidates);
  void table(String title, String note, Iterable<HarvestWord> list) {
    final l = list.toList();
    md
      ..writeln()
      ..writeln('## $title (${l.length})')
      ..writeln()
      ..writeln(note)
      ..writeln()
      ..writeln('| kind | word | runs | apps | uses | resolved | runs (where only in drafts or no longer used, said) | a shape | said |')
      ..writeln('|---|---|---|---|---|---|---|---|---|');
    for (final w in l) {
      final said = {for (final r in w.byRun.values) ...((r['messages'] as List?) ?? const []).map((m) => '$m')}.take(2).join(' ');
      md.writeln('| ${w.kind} | ${w.name} | ${w.runs} | ${w.apps.length} | ${w.uses} | ${howOf(w)}${w.byRun.values.any((r) => r['once'] != null) ? ' (once: ${{for (final r in w.byRun.values) ...((r['once'] as List?) ?? const [])}.join(', ')})' : ''} | ${runsOf(w)} | '
          '${w.shapes.values.isEmpty ? '' : code(w.shapes.values.first)} | ${said.replaceAll('|', r'\|')} |');
    }
  }

  table('Words the writers defined', 'Types a `define` or `primitive` gives (on a page, or in components/*.txt), and the sites\' own components.',
      sorted.where((w) => w.kind == 'type' && w.byRun.values.any((r) => r['definition'] != null && r['definedBy'] != 'design system')));
  table('Unknown: placeholders and words left out', 'Words no run defined where they were used: a type stood in as a placeholder, anything else was left out. "once" is a resolution an earlier expand saw.',
      sorted.where((w) => any(w, 'unknown')));
  table('Refused', 'Words an issue named (the vocabulary closed, or a word a definition\'s lines use that the notation does not have).', sorted.where((w) => any(w, 'refused')));
  // The issues the runs' files have now (grammar, and what a definition's
  // lines use that the notation does not have), the same complaint once.
  final shapes = <String, ({Set<String> runs, List<String> examples})>{};
  for (final r in runs) {
    for (final f in ((r.record['files'] as Map?) ?? const {}).entries) {
      for (final i in (((f.value as Map)['issues'] as List?) ?? const [])) {
        final m = '$i'.replaceFirst(RegExp(r'^line \d+:\d+: '), '');
        final shape = m.replaceAll(RegExp(r'"[^"]*"'), '"…"').replaceAll(RegExp(r'\b\d+\b'), 'N');
        final e = shapes.putIfAbsent(shape, () => (runs: <String>{}, examples: <String>[]));
        e.runs.add(r.id);
        if (e.examples.length < 2) e.examples.add('${r.id}/${f.key}: $i');
      }
    }
  }
  md
    ..writeln()
    ..writeln('## Issues now (${shapes.length} kinds)')
    ..writeln()
    ..writeln('What the runs\' files (drafts included) say when expanded now with `--open`, the same complaint once.')
    ..writeln()
    ..writeln('| runs | message | an example |')
    ..writeln('|---|---|---|');
  for (final e in shapes.entries.toList()..sort((a, b) => b.value.runs.length - a.value.runs.length)) {
    md.writeln('| ${e.value.runs.length} | ${e.key.replaceAll('|', r'\|')} | ${code(e.value.examples.first)} |');
  }
  table('Every word beyond the core', 'All of them, by kind, most runs first.', sorted);
  File('${outDir.path}/VOCABULARY.md').writeAsStringSync(md.toString());
  stdout.writeln('${runs.length} runs, ${words.length} words beyond the core; ${candidates.length} type candidates, ${otherCandidates.length} other candidates.');
  stdout.writeln('${outDir.path}/vocabulary.json, ${outDir.path}/VOCABULARY.md');
}

String _clip(String text, int lines) {
  final l = const LineSplitter().convert(text);
  return l.length <= lines ? text : '${l.take(lines).join('\n')}\n  … (${l.length - lines} more lines)';
}
