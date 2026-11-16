// Looks things up in codelessly_api's reference (docs/reference) from a shell.
//
//   tool/codelessly docs                         the pages, with what each covers
//   tool/codelessly docs <anchor | name>         one section: forms-validation-and-an-error-state, row, navigate
//   tool/codelessly docs <words...>              search needs, topics and names; prints the best section
//   tool/codelessly docs --list <words...>       only the matches, best first (--json for data)
//   tool/codelessly docs --starter               the path of STARTER.md (the base an agent reads in full first)
//
// The reference is generated from the API's declarations (CodelesslyAPI/tool/reference/generate.dart), so a
// section printed here is what the validator and the renderer implement. Sections are cut at the next heading of
// the same level; --full prints a long one whole (otherwise it stops after --max-lines lines and says so).
//
// The reference folder is --ref <dir>, else $CODELESSLY_REFERENCE, else docs/reference of $CODELESSLY_API, else
// of the codelessly_api checkout beside the SDK, else of the codelessly_api the SDK resolved.
import 'dart:convert';
import 'dart:io';

import 'common.dart';

/// The reference folder (the one with index.json), or a UsageError naming where it looked.
Directory findReference([String? explicit]) {
  final env = Platform.environment;
  final candidates = <String>[
    ?explicit,
    if (env['CODELESSLY_REFERENCE'] case final String r when r.isNotEmpty) r,
    if (env['CODELESSLY_API'] case final String a when a.isNotEmpty) '$a/docs/reference',
    for (final sibling in const ['CodelesslyAPI', 'codelessly_api']) '${sdkRoot.parent.path}/$sibling/docs/reference',
  ];
  final config = File('${sdkRoot.path}/.dart_tool/package_config.json');
  if (config.existsSync()) {
    try {
      for (final p in ((jsonDecode(config.readAsStringSync()) as Map)['packages'] as List).cast<Map>()) {
        if (p['name'] != 'codelessly_api') continue;
        final root = '${p['rootUri']}';
        final dir = root.startsWith('file://') ? Uri.parse(root).toFilePath() : config.parent.uri.resolve(root).toFilePath();
        candidates.add('$dir/docs/reference');
      }
    } catch (_) {}
  }
  for (final c in candidates) {
    if (File('$c/index.json').existsSync()) return Directory(c).absolute;
  }
  throw UsageError('No codelessly_api reference found (looked for docs/reference/index.json in: ${candidates.join(', ')}). '
      'Pass --ref <dir> or set CODELESSLY_API.');
}

typedef DocMatch = ({double score, String kind, String label, String file, String anchor});

class Reference {
  Reference(this.root) : index = (jsonDecode(File('${root.path}/index.json').readAsStringSync()) as Map).cast<String, Object?>() {
    final files = root.listSync().whereType<File>().where((f) {
      final n = f.uri.pathSegments.last;
      return n.endsWith('.md') && n != 'API_REFERENCE.md' && !n.startsWith('_');
    }).toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final f in files) {
      for (final m in RegExp(r'<a id="([^"]+)"></a>').allMatches(f.readAsStringSync())) {
        anchors.putIfAbsent(m[1]!, () => f.uri.pathSegments.last);
      }
    }
  }

  final Directory root;
  final Map<String, Object?> index;
  final Map<String, String> anchors = {};
  final Map<String, List<String>> _lines = {};

  List<Map> get topics => (index['topics'] as List? ?? const []).cast<Map>();

  List<String> lines(String file) => _lines[file] ??= File('${root.path}/$file').readAsLinesSync();

  /// The section an anchor starts: its heading and everything to the next heading of its level or above.
  List<String> section(String file, String anchor) {
    final ls = lines(file);
    final marker = '<a id="$anchor"></a>';
    final start = ls.indexWhere((l) => l.trim() == marker);
    if (start < 0) return const [];
    int? level;
    final out = <String>[];
    for (var i = start + 1; i < ls.length; i++) {
      final m = RegExp(r'^(#{1,6})\s').firstMatch(ls[i]);
      if (m != null) {
        if (level == null) {
          level = m[1]!.length;
        } else if (m[1]!.length <= level) {
          break;
        }
      }
      out.add(ls[i]);
    }
    // Drop anchors that belong to the next section.
    while (out.isNotEmpty && (out.last.trim().isEmpty || out.last.startsWith('<a id='))) {
      out.removeLast();
    }
    return out;
  }

  Iterable<(String, String, String, String, String)> _entries() sync* {
    for (final t in topics) {
      yield ('topic', '${t['topic']}', '${t['file']}', '${t['anchor']}', '${t['topic']} ${t['title'] ?? ''} ${t['summary'] ?? ''}');
    }
    for (final t in (index['tasks'] as List? ?? const []).cast<Map>()) {
      yield ('need', '${t['need']}', '${t['file']}', '${t['anchor']}', '${t['need']}');
    }
    for (final kind in ((index['items'] as Map?) ?? const {}).entries) {
      for (final item in (kind.value as Map).entries) {
        final ref = '${item.value}';
        final hash = ref.indexOf('#');
        yield ('${kind.key}', '${item.key}', ref.substring(0, hash), ref.substring(hash + 1), '${item.key}');
      }
    }
    for (final e in anchors.entries) {
      yield ('anchor', e.key, e.value, e.key, e.key.replaceAll('-', ' '));
    }
  }

  /// The file and anchor [q] names exactly: an anchor, a topic, a declared name (any case).
  (String, String)? exact(String q) {
    if (anchors.containsKey(q)) return (anchors[q]!, q);
    for (final t in topics) {
      if (t['topic'] == q) return ('${t['file']}', '${t['anchor']}');
    }
    for (final kind in ((index['items'] as Map?) ?? const {}).values) {
      for (final item in (kind as Map).entries) {
        if (item.key == q || '${item.key}'.toLowerCase() == q.toLowerCase()) {
          final ref = '${item.value}';
          final hash = ref.indexOf('#');
          return (ref.substring(0, hash), ref.substring(hash + 1));
        }
      }
    }
    return null;
  }

  /// Every need, topic, name and anchor matching [words], best first.
  List<DocMatch> search(List<String> words, {int limit = 12}) {
    final terms = [
      for (final m in RegExp(r'[A-Za-z0-9_]+').allMatches(words.join(' ')))
        if (m[0]!.length > 1) m[0]!.toLowerCase(),
    ];
    if (terms.isEmpty) return const [];
    final scored = <String, DocMatch>{};
    for (final (kind, label, file, anchor, text) in _entries()) {
      final hay = text.toLowerCase();
      final tokens = {for (final m in RegExp(r'[a-z0-9_]+').allMatches(hay)) m[0]!};
      var score = 0.0;
      for (final t in terms) {
        if (tokens.contains(t)) {
          score += 2;
        } else if (hay.contains(t)) {
          score += 1;
        }
      }
      if (score == 0) continue;
      // Prefer needs (written as people ask), then topics; shorter texts over longer.
      score += kind == 'need' ? 1.5 : (kind == 'topic' ? 1.0 : 0);
      score -= tokens.length * 0.01;
      final key = '$file#$anchor';
      if (!scored.containsKey(key) || scored[key]!.score < score) {
        scored[key] = (score: score, kind: kind, label: label, file: file, anchor: anchor);
      }
    }
    final ranked = scored.values.toList()..sort((a, b) => b.score.compareTo(a.score));
    return ranked.take(limit).toList();
  }
}

/// What `docs` prints for [argv] (the same text the MCP tool answers), and the exit status.
(int, String) docsText(List<String> argv) {
  final a = Args(argv, valued: {'--ref', '--max-lines'});
  if (a.help) return (0, _doc);
  final ref = Reference(findReference(a['--ref']));
  final out = StringBuffer();
  if (a.has('--starter')) return (0, '${ref.root.path}/STARTER.md');
  if (a.positional.isEmpty) {
    out
      ..writeln('codelessly_api ${ref.index['version']} reference at ${ref.root.path}')
      ..writeln('Read STARTER.md in full first (the base); open a page or a section when you need it.\n');
    for (final t in ref.topics) {
      if (!'${t['anchor']}'.startsWith('page-')) continue;
      final summary = '${t['summary'] ?? ''}';
      out.writeln('  ${'${t['topic']}'.padRight(14)} ${'${t['file']}'.padRight(16)} '
          '${summary.length > 110 ? summary.substring(0, 110) : summary}');
    }
    out.writeln('\n`tool/codelessly docs <words>` searches every need, topic and name.');
    return (0, out.toString());
  }
  final q = a.positional.join(' ');
  if (a.has('--list')) {
    final matches = ref.search(a.positional);
    if (a.has('--json')) {
      return (matches.isEmpty ? 1 : 0, prettyJson([
        for (final m in matches)
          {'kind': m.kind, 'label': m.label, 'file': m.file, 'anchor': m.anchor, 'score': (m.score * 100).round() / 100},
      ]));
    }
    for (final m in matches) {
      out.writeln('  ${m.anchor.padRight(52)} ${m.kind.padRight(10)} ${m.label.length > 80 ? m.label.substring(0, 80) : m.label}');
    }
    return (matches.isEmpty ? 1 : 0, out.toString());
  }
  var hit = ref.exact(q);
  final matches = hit == null ? ref.search(a.positional) : const <DocMatch>[];
  if (hit == null) {
    if (matches.isEmpty) return (1, 'Nothing in the reference matches "$q". `tool/codelessly docs` lists the pages.');
    hit = (matches.first.file, matches.first.anchor);
  }
  final (file, anchor) = hit;
  final body = ref.section(file, anchor);
  final maxLines = int.tryParse(a['--max-lines'] ?? '') ?? 220;
  out.writeln('<!-- $file#$anchor (tool/codelessly docs $anchor) -->');
  if (!a.has('--full') && body.length > maxLines) {
    out
      ..writeln(body.take(maxLines).join('\n'))
      ..writeln('\n... ${body.length - maxLines} more lines: tool/codelessly docs $anchor --full');
  } else {
    out.writeln(body.join('\n'));
  }
  if (matches.length > 1) {
    out.writeln('\nAlso matching:');
    for (final m in matches.skip(1).take(5)) {
      out.writeln('  tool/codelessly docs ${m.anchor.padRight(48)} (${m.kind}: ${m.label.length > 60 ? m.label.substring(0, 60) : m.label})');
    }
  }
  return (0, out.toString());
}

Future<int> docsMain(List<String> argv) async {
  final (code, text) = docsText(argv);
  (code == 1 && !text.startsWith('  ') ? stderr : stdout).write(text.endsWith('\n') ? text : '$text\n');
  return code;
}

const _doc = '''tool/codelessly docs                         the pages, with what each covers
tool/codelessly docs <anchor | name>         one section: forms-validation-and-an-error-state, row, navigate
tool/codelessly docs <words...>              search needs, topics and names; prints the best section
tool/codelessly docs --list <words...>       only the matches, best first (--json for data)
tool/codelessly docs --starter               the path of STARTER.md (the base an agent reads in full first)
Options: --ref <dir> (the docs/reference folder), --full (a long section whole), --max-lines n (default 220).''';
