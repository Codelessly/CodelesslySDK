// The vocabulary record `expand` keeps by default (codelessly_api
// docs/design/19-open-vocabulary.md, section 15): every word a writer's
// files used, open vocabulary or not, with how each resolved, saved beside
// what was expanded and kept across expands, so that a word the writer used
// in a first draft and rewrote before anyone looked is still there, marked
// no longer used.
//
// Where it is saved:
//
//   a site folder (`expand <folder>`), or one file of a site:
//       <the site's folder>/vocabulary.json and VOCABULARY.md (the folder
//       that holds pages/ and components/; a page expanded alone adds to
//       the same record)
//   a file of no site:
//       <file without .txt>.vocabulary.json and .VOCABULARY.md beside it
//   --vocabulary <file.json>: there instead (the .md beside it, named after it)
//   --no-record: nothing is saved
//
// Each word (`words`) is read with vocabulary_words.dart (its kinds and
// resolutions), and keeps:
//
//   kind, on, word   type, text, parameter, flag, event, variant, verb, key
//                    (a shortcut's chord), function, statement; `on` the type
//                    a parameter, flag, event, text or variant is on
//   status           used, defined, not used (a definition no line calls),
//                    or no longer used
//   resolved, how    how its uses resolve now: core, component (a design
//                    system's), site (the site's own component), alias (`to`
//                    what it was read as), definition (`definedBy`: page, a
//                    define in the file itself; site, a define in
//                    components/*.txt; a dictionary's folder name, a word
//                    read from a dictionary (--dictionary, site.json's
//                    `dictionary`); design system), universal, primitive,
//                    unread, refused (`messages`: the issues that refused
//                    it), unknown (a placeholder stands in, or it is left out)
//   origin           for a word the notation has (resolved core) or a
//                    dictionary's: where its meaning is written, base (the
//                    renderer and parser implement it), code (a word of the
//                    page's frames the expander writes out in Dart) or the
//                    dictionary's folder name (a definition in base words)
//   uses, files      its uses now, and by file the lines they are on
//   signatures       a type's shapes as written (`MiniMonth "text" @ days=
//                    onPick ...`), each with its uses now and when it was
//                    first and last written
//   definition       a word the writer defined: the file, the line and the
//                    text of its definition (`current` false once it is gone;
//                    `loaded` false when the site did not load the file)
//   history          each way it ever resolved, with when it first and last
//                    did (a placeholder the writer later defined says so)
//   first, last      when it was first and last seen
//
// and `files` (each file expanded, when, and what was said of it),
// `expands` (when, open or closed, how many files) and `summary` (the
// words now, by kind and resolution, and by status).
//
// `notation.sh vocabulary` reads these records (and site folders, expanding
// them the same way) for the harvest across runs: vocabulary_sites.dart.
import 'dart:convert';
import 'dart:io';

import 'package:codelessly_api/notation.dart';

import 'notation_site.dart';
import 'vocabulary_words.dart';
import 'package:codelessly_api/codelessly_api.dart' show standardCatalog;

/// What a record's `record` field says.
const recordMarker = 'codelessly notation vocabulary record';

/// A definition the writer wrote: its file, its line and its text.
typedef RecordedDefinition = ({String file, int line, String text, String by, bool loaded});

/// [d] as its writer wrote it: its `//` purpose, its `define` (or
/// `primitive`) line and its lines.
String definitionTextOf(NotationDefinition d) => [
      if (d.doc.isNotEmpty) '// ${d.doc}',
      '${d.primitive ? 'primitive' : 'define'} ${d.signature}',
      for (final l in d.body) '  ${' ' * l.indent}${l.text}',
    ].join('\n');

/// One file's words as one expand read them.
final class FileWords {
  FileWords(this.path, this.words, this.definedBy, this.notes, {this.placeholders = const [], this.issues = const []});

  /// Its issues, `line L:C: message`.
  final List<String> issues;

  /// The words of the file that ended as placeholders (or, closed, a type
  /// refused), each as `{word, kind, line, node, page, signature, source}`:
  /// what `tool/codelessly render` and `validate` report.
  final List<Map<String, Object?>> placeholders;

  /// As the record names it (relative to the record's folder).
  final String path;
  final CorpusWords words;

  /// A defined type's definer, by word: page, site or design system.
  final Map<String, String> definedBy;

  /// What was said of the file beyond its grammar issues (a placeholder, a
  /// word left out, a component that did not resolve).
  final List<String> notes;
}

/// The words of the files one expand read, and the definitions the writer
/// wrote ([file], [definition]).
final class RecordSnapshot {
  RecordSnapshot({this.components = const {}, this.site = const {}, this.siteDefined = const {}, this.open = false});

  /// The design system's components.
  final Set<String> components;

  /// The site's own components.
  final Set<String> site;

  /// The words the site's definition files (components/*.txt of `define`
  /// blocks) define.
  final Set<String> siteDefined;

  /// Whether the vocabulary was open.
  final bool open;

  /// Functions the site declares (its variables with parameters).
  Set<String> functions = const {};

  final files = <String, FileWords>{};
  final definitions = <String, RecordedDefinition>{};

  /// Records file [path] ([text], read as [result]); [notes] is what was said
  /// of it beyond its issues. [extra] is the definitions it also read (the
  /// site's).
  void file(String path, String text, NotationResult result, {List<String> notes = const [], String? extra, String? page}) {
    final words = CorpusWords(components: components, site: site)..declaredFunctions = functions;
    final own = readPageDefinitions(text);
    final all = extra == null ? own : readPageDefinitions('$extra\n$text');
    final reads = {
      for (final defs in all.words.values)
        for (final d in defs) d.label: definitionReads(d),
    };
    words.screen(path, text, result, reads: reads);
    for (final e in own.words.entries) {
      final d = e.value.first;
      definitions[e.key] = (file: path, line: d.line, text: e.value.map(definitionTextOf).join('\n\n'), by: 'page', loaded: true);
    }
    files[path] = FileWords(path, words, {
      for (final w in words.words.values)
        if ((w.kind == 'type' || w.kind == 'statement') && w.how.containsKey('definition'))
          w.word: own.words.containsKey(w.word)
              ? 'page'
              : siteDefined.contains(w.word)
                  ? 'site'
                  : w.dictionary ?? 'design system',
    }, notes, issues: [for (final i in result.issues) '$i'], placeholders: [
      for (final p in placeholdersOf(result, path, text: text))
        {
          'word': p.word,
          'kind': p.kind,
          'line': p.line,
          'node': ?p.node,
          'page': ?page,
          if (LineParts.of(p.source) case final parts? when p.kind != 'overlay') 'signature': CorpusWords.lineSignature(parts, children: p.children),
          'source': p.source,
        },
    ]);
  }

  /// A definition the writer wrote outside the files expanded (a site's
  /// components/*.txt: a component, or `define` blocks).
  void definition(String word, RecordedDefinition d) => definitions[word] = d;

  /// The words the writer defined that the notation already has, with what
  /// it has (notationBuiltInWord): the definition is not used, the built-in
  /// word is (resolution `built-in`, the definition kept).
  Map<String, String> get builtIns => {
        for (final w in definitions.keys)
          if (notationBuiltInWord(w, catalog: standardCatalog) case final b?) w: b,
      };
}

String _stamp(DateTime t) => '${t.toUtc().toIso8601String().split('.').first}Z';

/// [old] (a record, or null) with [now] merged into it at [time]: the files
/// [now] read are what they are now (with [whole], every file is: the
/// site's files not read now have no uses left); every word keeps when it
/// was first and last seen, and how it ever resolved.
Map<String, Object?> mergeRecord(Map<String, Object?>? old, RecordSnapshot now, {required DateTime time, bool whole = false, String? folder}) {
  final t = _stamp(time);
  Map<String, Object?> map(Object? v) => v is Map ? v.cast<String, Object?>() : <String, Object?>{};
  final words = <String, Map<String, Object?>>{};
  for (final w in (old?['words'] as List?) ?? const []) {
    final m = map(w);
    words[CorpusWords.keyOf(m['kind'] as String, m['on'] as String?, m['word'] as String)] = {...m, 'files': map(m['files']), 'history': map(m['history']), 'seen': map(m['seen'])};
  }
  final reset = <String>{...now.files.keys};
  if (whole) {
    for (final w in words.values) {
      reset.addAll(map(w['files']).keys);
    }
  }
  for (final w in words.values) {
    map(w['files']).removeWhere((k, _) => reset.contains(k));
    (w['files'] as Map).removeWhere((k, _) => reset.contains(k));
  }
  Map<String, Object?> entry(String kind, String? on, String word) => words.putIfAbsent(
      CorpusWords.keyOf(kind, on, word),
      () => {
            'kind': kind,
            if (on != null) 'on': on,
            'word': word,
            'first': t,
            'files': <String, Object?>{},
            'history': <String, Object?>{},
            'seen': <String, Object?>{},
          });
  void mark(Map<String, Object?> into, String key) {
    final h = map(into[key]);
    into[key] = {'first': h['first'] ?? t, 'last': t};
  }

  for (final fw in now.files.values) {
    for (final cw in fw.words.words.values) {
      final e = entry(cw.kind, cw.on, cw.word);
      (e['files'] as Map)[fw.path] = {
        'lines': (cw.lines[fw.path] ?? const <int>{}).toList()..sort(),
        'how': cw.how,
        if (cw.signatures.isNotEmpty) 'signatures': cw.signatures,
        if (cw.messages.isNotEmpty) 'messages': cw.messages.toList(),
        if (cw.to.isNotEmpty) 'to': cw.to.toList()..sort(),
        if (fw.definedBy[cw.word] case final by? when cw.kind == 'type' || cw.kind == 'statement') 'definedBy': by,
      };
      if (cw.origin case final o?) e['origin'] = o;
      e['last'] = t;
      e['example'] = cw.example;
      for (final r in cw.how.keys) {
        mark(e['history'] as Map<String, Object?>, r);
      }
      for (final s in cw.signatures.keys) {
        mark(e['seen'] as Map<String, Object?>, s);
      }
    }
  }
  // Definitions: those read now are current; one whose file was read now
  // and no longer defines it is not.
  for (final w in words.values) {
    final d = map(w['definition']);
    if (d.isNotEmpty && reset.contains(d['file']) && !now.definitions.containsKey(w['word'])) w['definition'] = {...d, 'current': false};
  }
  for (final e in now.definitions.entries) {
    final w = entry('type', null, e.key);
    final d = e.value;
    w['definition'] = {'file': d.file, 'line': d.line, 'by': d.by, if (!d.loaded) 'loaded': false, if (now.builtIns[e.key] case final b?) 'builtIn': b, 'current': true, 'text': d.text};
    w['last'] = t;
    if (!d.loaded) {
      // Every word's definition is shown; one the site did not load is said.
      mark(w['history'] as Map<String, Object?>, 'not loaded');
    }
  }
  // The totals, from the files.
  for (final w in words.values) {
    final files = map(w['files']);
    final how = <String, int>{}, sigs = <String, int>{};
    final to = <String>{}, messages = <String>{}, by = <String>{};
    var uses = 0;
    for (final f in files.values) {
      final m = map(f);
      for (final h in map(m['how']).entries) {
        how[h.key] = (how[h.key] ?? 0) + (h.value as int);
        uses += h.value as int;
      }
      for (final s in map(m['signatures']).entries) {
        sigs[s.key] = (sigs[s.key] ?? 0) + (s.value as int);
      }
      to.addAll([for (final x in (m['to'] as List?) ?? const []) '$x']);
      messages.addAll([for (final x in (m['messages'] as List?) ?? const []) '$x']);
      if (m['definedBy'] case final String b) by.add(b);
    }
    w['uses'] = uses;
    w['how'] = how;
    if (how.isNotEmpty) {
      w['resolved'] = (how.entries.toList()..sort((a, b) => b.value != a.value ? b.value - a.value : wordResolutions.indexOf(a.key) - wordResolutions.indexOf(b.key))).first.key;
    } else if (w['resolved'] == null) {
      w['resolved'] = map(w['definition']).isNotEmpty ? 'definition' : 'unknown';
    }
    if (to.isNotEmpty) w['to'] = (to.toList()..sort()).join(', ');
    if (messages.isNotEmpty) {
      w['messages'] = messages.toList();
    } else {
      w.remove('messages');
    }
    if (by.isNotEmpty) {
      w['definedBy'] = (by.toList()..sort()).join(', ');
    } else if (map(w['definition']) case final d when d.isNotEmpty) {
      w['definedBy'] = d['by'];
    }
    final seen = map(w['seen']);
    w['signatures'] = [
      for (final s in seen.entries) {'signature': s.key, 'uses': sigs[s.key] ?? 0, 'first': map(s.value)['first'], 'last': map(s.value)['last']},
    ]..sort((a, b) => (b['uses'] as int) != (a['uses'] as int) ? (b['uses'] as int) - (a['uses'] as int) : '${b['last']}'.compareTo('${a['last']}'));
    if ((w['signatures'] as List).isEmpty) w.remove('signatures');
    final defined = map(w['definition'])['current'] == true;
    // The writer defined a word the notation has: the notation's is used,
    // the definition is kept, to see what the writer expected the word to be.
    if (defined && map(w['definition'])['builtIn'] != null) {
      w['resolved'] = 'built-in';
      w['definedBy'] = map(w['definition'])['by'];
    }
    w['status'] = uses > 0
        ? 'used'
        : defined
            ? 'defined, not used'
            : 'no longer used';
  }
  // Files.
  final fileLog = map(old?['files']);
  for (final fw in now.files.values) {
    final f = map(fileLog[fw.path]);
    fileLog[fw.path] = {
      'first': f['first'] ?? t,
      'last': t,
      'expands': ((f['expands'] as int?) ?? 0) + 1,
      if (fw.notes.isNotEmpty) 'said': fw.notes,
      if (fw.placeholders.isNotEmpty) 'placeholders': fw.placeholders,
      if (fw.issues.isNotEmpty) 'issues': fw.issues,
    };
  }
  // A whole expand: a file that is no longer there has nothing now.
  if (whole) {
    for (final k in fileLog.keys.toList()) {
      if (!now.files.containsKey(k)) {
        final f = map(fileLog[k]);
        fileLog[k] = {for (final e in f.entries) if (e.key != 'said' && e.key != 'placeholders' && e.key != 'issues') e.key: e.value, 'gone': true};
      }
    }
  }
  final expands = [...(old?['expands'] as List?) ?? const [], {'at': t, 'vocabulary': now.open ? 'open' : 'closed', 'files': now.files.length}];
  final order = ['used', 'defined, not used', 'no longer used'];
  final sorted = words.values.toList()
    ..sort((a, b) {
      int core(Map<String, Object?> w) => w['resolved'] == 'core' ? 1 : 0;
      var c = order.indexOf(a['status'] as String) - order.indexOf(b['status'] as String);
      if (c != 0) return c;
      c = core(a) - core(b);
      if (c != 0) return c;
      c = wordKinds.indexOf(a['kind'] as String) - wordKinds.indexOf(b['kind'] as String);
      if (c != 0) return c;
      return '${a['on'] ?? ''}.${a['word']}'.compareTo('${b['on'] ?? ''}.${b['word']}');
    });
  final summary = <String, Map<String, int>>{};
  final status = <String, int>{};
  for (final w in sorted) {
    status[w['status'] as String] = (status[w['status']] ?? 0) + 1;
    if (w['status'] != 'used') continue;
    final k = summary.putIfAbsent(w['kind'] as String, () => {});
    k[w['resolved'] as String] = (k[w['resolved']] ?? 0) + 1;
  }
  return {
    'record': recordMarker,
    'version': 1,
    'about': 'Every word the notation files here used, with how each resolved, kept across expands. Written by tool/notation/notation.sh expand '
        '(codelessly_api docs/design/19-open-vocabulary.md, section 15); --no-record leaves it alone.',
    if (folder != null) 'folder': folder,
    'first': old?['first'] ?? t,
    'last': t,
    'expands': expands.length > 200 ? expands.sublist(expands.length - 200) : expands,
    'summary': {'status': status, 'used': summary},
    // Every word that stands in now, by file: what render and validate report.
    'placeholders': [
      for (final f in fileLog.entries)
        for (final p in (map(f.value)['placeholders'] as List?) ?? const []) {'file': f.key, ...map(p)},
    ],
    'files': fileLog,
    'words': [
      for (final w in sorted)
        {
          for (final k in const ['kind', 'on', 'word', 'status', 'resolved', 'origin', 'how', 'to', 'definedBy', 'uses', 'messages', 'signatures', 'definition', 'example', 'first', 'last', 'history', 'files', 'seen'])
            if (w[k] != null) k: w[k],
        },
    ],
  };
}

/// [record] as Markdown: what the writer reached for, placeholders and
/// refusals first.
String recordMarkdown(Map<String, Object?> record) {
  final words = [for (final w in (record['words'] as List?) ?? const []) (w as Map).cast<String, Object?>()];
  String code(Object? s) => '`${'$s'.replaceAll('`', "'").replaceAll('|', r'\|').replaceAll('\n', ' ')}`';
  String name(Map<String, Object?> w) => w['on'] == null ? '${w['word']}' : '${w['on']}.${w['word']}';
  String where(Map<String, Object?> w) => [
        for (final f in ((w['files'] as Map?) ?? const {}).entries)
          '${f.key}:${(((f.value as Map)['lines'] as List?) ?? const []).join(',')}',
      ].join('; ');
  final md = StringBuffer()
    ..writeln('# Vocabulary record')
    ..writeln()
    ..writeln('Written by `tool/notation/notation.sh expand` at every expand (codelessly_api docs/design/19-open-vocabulary.md, section 15); '
        'vocabulary.json beside it holds every word with its lines, signatures and history. Do not edit: expand again.')
    ..writeln()
    ..writeln('${(record['expands'] as List?)?.length ?? 0} expands from ${record['first']} to ${record['last']}; '
        'words: ${((record['summary'] as Map?)?['status'] as Map?)?.entries.map((e) => '${e.value} ${e.key}').join(', ') ?? 'none'}.')
    ..writeln();
  void table(String title, String note, Iterable<Map<String, Object?>> rows, {bool history = false}) {
    final list = rows.toList();
    md
      ..writeln('## $title (${list.length})')
      ..writeln()
      ..writeln(note)
      ..writeln();
    if (list.isEmpty) {
      md
        ..writeln('None.')
        ..writeln();
      return;
    }
    md
      ..writeln('| kind | word | how | uses | where | signature | ${history ? 'first, last seen | ' : ''}what was said |')
      ..writeln('|---|---|---|---|---|---|${history ? '---|' : ''}---|');
    for (final w in list) {
      final sig = ((w['signatures'] as List?) ?? const []).map((s) => '${(s as Map)['signature']}').take(3).join(' / ');
      final how = w['status'] == 'no longer used'
          ? ((w['history'] as Map?) ?? const {}).keys.join(', ')
          : '${w['resolved']}${w['to'] == null ? '' : ' → ${w['to']}'}${w['definedBy'] == null ? '' : ' (${w['definedBy']})'}';
      md.writeln('| ${w['kind']} | ${name(w)} | $how | ${w['uses']} | ${where(w)} | ${sig.isEmpty ? '' : code(sig)} | '
          '${history ? '${w['first']} – ${w['last']} | ' : ''}${((w['messages'] as List?) ?? const []).map((m) => '$m'.replaceAll('|', r'\|')).join(' ')} |');
    }
    md.writeln();
  }

  bool used(Map<String, Object?> w) => w['status'] == 'used';
  table('Placeholders and words left out', 'Words the notation, the design system and the site do not have: a type stands in as a placeholder, anything else is left out (open vocabulary).',
      words.where((w) => used(w) && w['resolved'] == 'unknown'));
  table('Refused', 'Words an issue refused (the vocabulary closed), with the issue.', words.where((w) => used(w) && w['resolved'] == 'refused'));
  table('Defined by the writer, and the site\'s components', 'Words a `define` or `primitive` gives (on the page, or in components/*.txt), and the site\'s components.',
      words.where((w) => w['status'] != 'no longer used' && w['kind'] == 'type' && const {'definition', 'primitive', 'site', 'unread'}.contains(w['resolved'])));
  table('Aliases', 'Names read as a word we have.', words.where((w) => used(w) && w['resolved'] == 'alias'));
  table('Other words beyond the core', 'A design system\'s components, universal words, and words a definition names and never reads.',
      words.where((w) => used(w) && const {'component', 'universal', 'unread'}.contains(w['resolved']) && !(w['kind'] == 'type' && w['resolved'] == 'unread')));
  table('No longer used', 'Words an earlier expand saw that no file uses now, with how they resolved then.', words.where((w) => w['status'] == 'no longer used' && w['kind'] != 'text'),
      history: true);
  final defs = words.where((w) => w['definition'] != null).toList();
  md
    ..writeln('## Definitions (${defs.length})')
    ..writeln();
  for (final w in defs) {
    final d = (w['definition'] as Map).cast<String, Object?>();
    md
      ..writeln('${w['word']}: ${d['file']}:${d['line']} (${d['by']}${d['current'] == false ? ', no longer there' : ''}${d['loaded'] == false ? ', not loaded' : ''}; ${w['status']})')
      ..writeln()
      ..writeln('```')
      ..writeln(d['text'])
      ..writeln('```')
      ..writeln();
  }
  final core = <String, int>{};
  for (final w in words.where((w) => used(w) && w['resolved'] == 'core')) {
    core[w['kind'] as String] = (core[w['kind']] ?? 0) + 1;
  }
  md
    ..writeln('## Core words')
    ..writeln()
    ..writeln(core.isEmpty ? 'None.' : '${core.entries.map((e) => '${e.value} ${e.key}${e.value == 1 ? '' : 's'}').join(', ')}: in vocabulary.json.')
    ..writeln();
  final said = [
    for (final f in ((record['files'] as Map?) ?? const {}).entries)
      for (final s in (((f.value as Map)['said'] as List?) ?? const [])) '${f.key}: $s',
  ];
  md
    ..writeln('## Said at the last expand of each file (${said.length})')
    ..writeln();
  for (final s in said) {
    md.writeln('- ${s.replaceAll('\n', ' ')}');
  }
  return md.toString();
}

/// Reads the record at [path]: null when there is none, or it is not one.
Map<String, Object?>? readRecord(String path) {
  final f = File(path);
  if (!f.existsSync()) return null;
  try {
    final j = jsonDecode(f.readAsStringSync());
    if (j is Map && j['record'] == recordMarker) return j.cast<String, Object?>();
  } on FormatException {
    // Not JSON: not a record.
  }
  return null;
}

/// Merges [now] into the record at [path] and writes it, with its Markdown
/// ([mdPath]). A file at [path] that is not a record is left alone and the
/// record goes to `<path without .json>.record.json`. The path written.
String saveRecord(String path, RecordSnapshot now, {String? mdPath, bool whole = false, DateTime? time, String? folder}) {
  var target = path;
  if (File(path).existsSync() && readRecord(path) == null) {
    target = '${path.replaceFirst(RegExp(r'\.json$'), '')}.record.json';
  }
  final merged = mergeRecord(readRecord(target), now, time: time ?? DateTime.now(), whole: whole, folder: folder);
  File(target)
    ..parent.createSync(recursive: true)
    ..writeAsStringSync('${const JsonEncoder.withIndent(' ').convert(merged)}\n');
  final md = mdPath ?? (target.endsWith('vocabulary.json') ? '${File(target).parent.path}/VOCABULARY.md' : '${target.replaceFirst(RegExp(r'\.json$'), '')}.md');
  File(md).writeAsStringSync(recordMarkdown(merged));
  return target;
}

/// What `expand` says of [r] beyond its issues, one line each: every word
/// that ends as a placeholder (a type that stands in, a primitive, an
/// overlay opened and never written) and every word left out, with the
/// vocabulary open; and, open or closed, a call to a word that a
/// components/*.txt the site did not load would have given. Before, a site's
/// expand said none of it (test 10: `MiniMonth`, `Masthead`).
List<String> vocabularyNotes(NotationResult r, {NotationSite? site}) {
  final skipped = {for (final s in site?.skipped ?? const <SkippedComponent>[]) s.type: s};
  String? notRead(String word) => switch (skipped[word]) {
        final s? => ' ${File(s.path).uri.pathSegments.last} in components/ would give it and is not read (said above).',
        _ => null,
      };
  final out = <String>[];
  for (final u in r.vocabulary) {
    final at = 'line ${u.line}:${u.column}';
    final on = u.on == null ? '' : ' on ${u.on}';
    switch (u.kind) {
      case 'type':
        out.add('$at: "${u.word}" is a word the notation, the design system and the site do not have: a placeholder stands in for it'
            '${u.node == null ? '' : ' (node ${u.node})'}.'
            '${notRead(u.word) ?? ' Define it (`define ${u.word} …` after the page\'s last line, or in components/${u.word}.txt), or write a word the notation has.'}');
      case 'primitive':
        out.add('$at: "${u.word}" is declared a primitive: a labelled box stands in for it.');
      case 'overlay':
        out.add('line ${u.line}: open ${u.word}: nothing over this page has the id ${u.word}: a placeholder sheet opens. Write the overlay (`Dialog#${u.word} …`) or open one the page has.');
      case 'parameter' || 'flag' || 'event' || 'variant':
        out.add('$at: ${u.kind} "${u.word}"$on is not one the notation has there: left out.');
      case 'verb':
        out.add('$at: action "${u.word}"$on is not one the notation has: left out of its event.');
      case 'missing':
        out.add('$at: ${u.on ?? ''} needs ${u.word}, which the line does not give: it is given an empty value.');
      case 'children':
        out.add('$at: ${u.word} takes no lines under it: they are drawn after it.');
    }
  }
  // Closed: the issue `No node type "Masthead"` is said; what would have
  // given it is said too.
  for (final i in r.issues) {
    final m = RegExp(r'^No node type "([A-Za-z0-9_]+)"').firstMatch(i.message);
    if (m == null) continue;
    if (notRead(m[1]!) case final s?) out.add('line ${i.line}:${i.column}: ${m[1]}:$s');
  }
  return out;
}

/// A word that ends as a placeholder: a type that stands in (`type`), a
/// declared `primitive`, an `overlay` opened and never written. [node] is
/// the node that stands in.
typedef Placeholder = ({String word, String kind, String file, int line, String? node, String source, bool children});

/// The placeholders of [r] (the file [file]); with the vocabulary closed,
/// a type refused (`No node type "Masthead"`: kind `refused`), which
/// draws nothing.
List<Placeholder> placeholdersOf(NotationResult r, String file, {String? text}) {
  final lines = text?.split('\n');
  return [
    for (final u in r.vocabulary)
      if (u.kind == 'type' || u.kind == 'primitive' || u.kind == 'overlay') (word: u.word, kind: u.kind, file: file, line: u.line, node: u.node, source: u.source, children: u.children.isNotEmpty),
    for (final i in r.issues)
      if (RegExp(r'^No node type "([A-Za-z0-9_]+)"').firstMatch(i.message) case final m?)
        (
          word: m[1]!,
          kind: 'refused',
          file: file,
          line: i.line,
          node: null,
          children: false,
          source: lines != null && i.line >= 1 && i.line <= lines.length ? lines[i.line - 1].trim() : '',
        ),
  ];
}

/// One line per word in [all] (its kind, where it is, how many uses), and
/// the total, pointing to the record at [record] (null: none saved). [leftOut]
/// is the number of other words left out.
List<String> placeholderLines(List<Placeholder> all, {int leftOut = 0, String? record}) {
  final by = <String, List<Placeholder>>{};
  for (final p in all) {
    by.putIfAbsent('${p.kind} ${p.word}', () => []).add(p);
  }
  return [
    for (final e in by.values)
      '${e.first.kind == 'refused' ? 'refused' : 'placeholder'}: ${e.first.word} (${e.first.kind == 'refused' ? 'type' : e.first.kind}) '
          '${e.map((p) => '${p.file}:${p.line}').toSet().join(', ')} (${e.length} use${e.length == 1 ? '' : 's'})',
    '${by.length} word${by.length == 1 ? '' : 's'} ${all.any((p) => p.kind == 'refused') ? 'stood in as placeholders or were refused' : 'stood in as placeholders'} (${all.length} use${all.length == 1 ? '' : 's'})'
        '${leftOut == 0 ? '' : ', $leftOut more left out'}'
        '${record == null ? '' : '; every word is in the vocabulary record, $record'}.',
  ];
}

/// The words of [r] left out (open vocabulary): parameters, flags, events,
/// variants and verbs it does not have.
int leftOutOf(NotationResult r) => r.vocabulary.where((u) => const {'parameter', 'flag', 'event', 'variant', 'verb'}.contains(u.kind)).length;

/// What `validate` gives (`notation.sh validate`, `tool/codelessly
/// validate`, the MCP tool `codelessly_validate`), as data an orchestrating
/// agent reads without parsing text: the [issues] (`{file, line, column,
/// message}`), the component files [skipped] (`{file, message}`), every
/// word that stood in as a placeholder (or, closed, a type refused), with
/// its kind, its signatures, where and how it resolved, and every other word
/// beyond the core that did not resolve or that the writer defined.
Map<String, Object?> validationOf(RecordSnapshot snap, {List<Map<String, Object?>> issues = const [], List<Map<String, Object?>> skipped = const [], String? record}) {
  final placeholders = <String, Map<String, Object?>>{};
  for (final fw in snap.files.values) {
    for (final p in fw.placeholders) {
      final e = placeholders.putIfAbsent('${p['kind']} ${p['word']}', () => {
            'word': p['word'],
            'kind': p['kind'] == 'refused' ? 'type' : p['kind'],
            'resolution': switch (p['kind']) { 'refused' => 'refused', 'primitive' => 'primitive', 'overlay' => 'placeholder sheet', _ => 'placeholder' },
            'signatures': <String>[],
            'where': <String>[],
            'nodes': <Map<String, Object?>>[],
            'uses': 0,
          });
      e['uses'] = (e['uses'] as int) + 1;
      if (p['signature'] case final String s when !(e['signatures'] as List).contains(s)) (e['signatures'] as List).add(s);
      (e['where'] as List).add('${fw.path}:${p['line']}');
      if (p['node'] != null) (e['nodes'] as List).add({'page': p['page'], 'node': p['node']});
    }
  }
  final words = <String, Map<String, Object?>>{};
  for (final fw in snap.files.values) {
    for (final cw in fw.words.words.values) {
      if (cw.kind == 'text') continue;
      final writer = cw.kind == 'type' && (cw.how.containsKey('site') || (cw.how.containsKey('definition') && fw.definedBy[cw.word] != 'design system'));
      if (!writer && !cw.how.keys.any(unresolvedResolutions.contains) && !cw.how.containsKey('alias')) continue;
      final e = words.putIfAbsent(CorpusWords.keyOf(cw.kind, cw.on, cw.word), () => {
            'word': cw.word,
            'kind': cw.kind,
            'on': ?cw.on,
            'resolution': <String, int>{},
            'signatures': <String>[],
            'where': <String>[],
            'uses': 0,
          });
      for (final h in cw.how.entries) {
        final m = e['resolution'] as Map<String, int>;
        m[h.key] = (m[h.key] ?? 0) + h.value;
      }
      e['uses'] = (e['uses'] as int) + cw.uses;
      for (final s in cw.signatures.keys) {
        if (!(e['signatures'] as List).contains(s)) (e['signatures'] as List).add(s);
      }
      for (final l in (cw.lines[fw.path] ?? const <int>{}).toList()..sort()) {
        (e['where'] as List).add('${fw.path}:$l');
      }
      if (cw.to.isNotEmpty) e['to'] = (cw.to.toList()..sort()).join(', ');
      if (cw.messages.isNotEmpty) e['messages'] = cw.messages.toList();
      if (fw.definedBy[cw.word] case final by? when cw.kind == 'type') e['definedBy'] = by;
    }
  }
  return {
    'ok': issues.isEmpty,
    'vocabulary': snap.open ? 'open' : 'closed',
    'files': snap.files.keys.toList(),
    'placeholders': placeholders.values.toList(),
    'words': words.values.toList(),
    'issues': issues,
    'skipped': skipped,
    'record': ?record,
  };
}

/// [path] relative to [dir], with forward slashes (absolute when outside it).
String recordPath(String path, String dir) {
  final p = File(path).absolute.path.replaceAll(r'\', '/');
  final d = Directory(dir).absolute.path.replaceAll(r'\', '/');
  final base = d.endsWith('/') ? d : '$d/';
  return p.toLowerCase().startsWith(base.toLowerCase()) ? p.substring(base.length) : p;
}

/// A snapshot for files of [site] (null: none) with [designSystem]'s
/// components, with the site's own definitions (its components and its
/// components/*.txt of `define` blocks) added, paths relative to [dir].
RecordSnapshot siteSnapshot(NotationSite? site, {Set<String> components = const {}, required bool open, required String dir}) {
  final snap = RecordSnapshot(
    components: components,
    site: site == null ? const {} : {...site.sources.keys, ...site.expanded.keys},
    siteDefined: site == null ? const {} : site.definedWords.keys.toSet(),
    open: open,
  );
  if (site == null) return snap;
  snap.functions = {for (final e in site.variables.entries) if (e.value['parameters'] != null) e.key};
  for (final s in site.sources.values) {
    final lines = const LineSplitter().convert(s.text);
    snap.definition(s.type, (file: recordPath(s.path, dir), line: 1, text: lines.length > 80 ? '${lines.take(80).join('\n')}\n…' : lines.join('\n'), by: 'site', loaded: true));
  }
  for (final e in site.definitionFiles.entries) {
    for (final w in readPageDefinitions(e.value).words.entries) {
      snap.definition(w.key, (file: recordPath(e.key, dir), line: w.value.first.line, text: w.value.map(definitionTextOf).join('\n\n'), by: 'site', loaded: true));
    }
  }
  // A component file the site did not load: its words' definitions, said.
  for (final k in site.skipped) {
    final f = File(k.path);
    if (!f.existsSync() || !k.path.endsWith('.txt')) continue;
    final text = f.readAsStringSync();
    if (snap.definitions.containsKey(k.type)) continue;
    snap.definition(k.type, (file: recordPath(k.path, dir), line: 1, text: text.trimRight(), by: 'site', loaded: false));
  }
  return snap;
}
