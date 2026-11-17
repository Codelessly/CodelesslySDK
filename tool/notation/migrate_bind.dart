// Rewrites notation written for codelessly_api 33 (a control's variable as
// `bind=name`, a range's end as `bindEnd=name`, a block's other variable as
// `key=name`, an undeclared variable created for the writer) in the form 34
// reads (`@name` for the line's value, `@low @high` for a range, `key=@name`
// for any other property, and a `state name=value` line for each variable a
// screen binds that nothing declares). The rewrite of one line is
// codelessly_api's own (`notationBindRewrite`, which the parser's message for
// a line that still writes `bind=` shows too); this file finds the notation in
// a file and places the state lines.
//
// Every rewrite is idempotent: a line already in the 34 form is left as it is,
// and a variable already declared gets no second state line. Everything but
// the rewritten words and the added lines is kept byte for byte, line endings
// included.
import 'dart:convert';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_api/notation.dart';

/// What a file holds, by its extension.
String? bindKindOf(String path) {
  final dot = path.lastIndexOf('.');
  final ext = dot < 0 ? '' : path.substring(dot + 1).toLowerCase();
  return switch (ext) {
    'txt' || 'notation' => 'notation',
    'md' || 'markdown' => 'markdown',
    'dart' => 'dart',
    'py' => 'python',
    'json' => 'json',
    'html' || 'htm' => 'html',
    _ => null,
  };
}

/// One file's rewrite: [log] says what changed, [left] the lines that still
/// write `bind=` and could not be rewritten (by their 1-based line).
final class BindMigration {
  BindMigration(this.catalog, {this.declared = const {}, this.definitionFile = false});

  /// The file is a design system's definitions (`vocabulary/<Word>.txt`):
  /// its texts are read as definitions whatever they look like.
  final bool definitionFile;

  /// The types the lines are read with (the standard catalog with the design
  /// systems' blocks): which line shows a value, which block keeps which
  /// variable.
  final Catalog catalog;

  /// Variables declared outside the file (a site's, in its site.json).
  final Set<String> declared;

  final log = <String>[];

  /// [text], a file of [kind] ([bindKindOf]), rewritten.
  String file(String text, String kind) => switch (kind) {
        'notation' => notation(text),
        'markdown' => markdown(text),
        'dart' => code(text, python: false),
        'python' => code(text, python: true),
        'json' => json(text),
        'html' => loose(text),
        _ => text,
      };

  static final _head = RegExp(r'^[A-Z][A-Za-z0-9]*(\.[A-Za-z][A-Za-z0-9]*)*(#[A-Za-z_][A-Za-z0-9_-]*)?(?=\s|$)');
  static final _headAt = RegExp(r'[A-Z][A-Za-z0-9]*(\.[A-Za-z][A-Za-z0-9]*)*(#[A-Za-z_][A-Za-z0-9_-]*)?(?=\s|$)');
  static final _stateLine = RegExp(r'^(?:state|project|let|derived|const|var|computed)\s+([A-Za-z_][A-Za-z0-9_]*)');
  static final _bareState = RegExp(r'^([a-z_][A-Za-z0-9_]*)\s*=(?!=)');
  static final _old = RegExp(r'(?<![A-Za-z0-9_.@-])bind(?:[A-Z][A-Za-z0-9]*)?=');

  /// Whether [text] is a file of definitions as a design system keeps them
  /// (each signature at the margin without `define`, its lines indented
  /// under it), not a page.
  ///
  /// Each line at the margin must read as a signature: a word that is no type
  /// of the notation, no block of a design system and no page word, with lines
  /// under it, strings that are names (`"label"`, not prose), and something
  /// only a signature writes (a bare event `onPick`, a parameter with no value,
  /// `min`, the value it keeps, `bind=value`).
  bool definitions(List<String> lines) {
    if (definitionFile) return true;
    var signatures = 0;
    for (var i = 0; i < lines.length; i++) {
      final l = lines[i].trimRight();
      if (l.isEmpty || l.startsWith('//') || l.startsWith(' ')) continue;
      final head = _head.stringMatch(l);
      if (head == null) return false;
      final word = RegExp(r'^[A-Z][A-Za-z0-9]*').stringMatch(head)!;
      if (notationTypes.containsKey(word) ||
          catalog.widget('${word[0].toLowerCase()}${word.substring(1)}') != null ||
          catalog.widget(word) != null ||
          const {'Page', 'App', 'Section', 'Screen', 'Main', 'Sidebar', 'Nav', 'Dialog', 'Sheet', 'Drawer', 'Menu', 'Popover', 'Lightbox'}.contains(word)) {
        return false;
      }
      final next = lines.skip(i + 1).firstWhere((n) => n.trim().isNotEmpty && !n.trim().startsWith('//'), orElse: () => '');
      if (!next.startsWith(' ')) return false;
      final parts = LineParts.of(l);
      if (parts == null || parts.strings.any((p) => !RegExp(r'^"[A-Za-z_][A-Za-z0-9_]*"$').hasMatch(p.raw))) return false;
      final signs = parts.parts.any((p) =>
          (p.kind == 'word' && (RegExp(r'^(on[A-Z][A-Za-z0-9]*|[a-z][A-Za-z0-9_]*!?|bind|@[A-Za-z_][A-Za-z0-9_]*(=.*)?)$').hasMatch(p.raw))) ||
          (p.kind == 'pair' && (p.key == 'bind' || p.value == '@')));
      if (!signs) return false;
      signatures++;
    }
    return signatures > 0;
  }

  /// A text that is notation through and through: a page (or an answer of
  /// several screens, each under its `###` line) or a file of definitions.
  /// [states]: whether the variables a screen binds and nothing declares
  /// get a state line. [at] names where the text is, for [log].
  String notation(String text, {bool states = true, String at = 'line'}) {
    final lines = text.split('\n');
    final cr = [for (final l in lines) l.endsWith('\r')];
    final raw = [for (final l in lines) l.endsWith('\r') ? l.substring(0, l.length - 1) : l];
    final defs = definitions(raw);
    final out = <String>[];
    // Each screen: where it starts, the state lines at its head, what it
    // declares and what its lines bind.
    final screens = <_Screen>[_Screen(0, null)];
    var inDefine = false;
    for (var i = 0; i < raw.length; i++) {
      var line = raw[i];
      final trimmed = line.trimLeft();
      final indent = line.length - trimmed.length;
      final screen = screens.last;
      if (indent == 0 && trimmed.startsWith('###')) {
        screens.add(_Screen(out.length, out.length));
        inDefine = false;
      } else if (indent == 0 && trimmed.isNotEmpty && !trimmed.startsWith('//')) {
        inDefine = defs || trimmed.startsWith('define ') || trimmed.startsWith('primitive ');
      }
      if (trimmed.isNotEmpty && !trimmed.startsWith('//') && !trimmed.startsWith('```') && !trimmed.startsWith('###')) {
        final signature = inDefine && indent == 0;
        // A line of a string literal may open with what the code puts in
        // (`${state}Column …`): the notation is after it.
        final lead = RegExp(r'^\s*(?:\$\{[^{}]*\}|\$[A-Za-z_][A-Za-z0-9_]*)*').stringMatch(line)!;
        final rest = line.substring(lead.length);
        final r = notationBindRewrite(signature && defs ? 'define $rest' : rest, catalog: catalog);
        var next = '$lead${signature && defs ? r.line.replaceFirst('define ', '') : r.line}';
        if (next != line) {
          log.add('$at ${i + 1}: ${line.trim()}  →  ${next.trim()}');
          line = next;
        }
        if (!inDefine) {
          if (_stateLine.firstMatch(trimmed) case final m?) {
            screen.declared.add(m[1]!);
            if (indent == 0 && screen.firstNode == null) screen.lastState = out.length;
          } else if (indent == 0 && screen.firstNode == null && _bareState.hasMatch(trimmed)) {
            screen.declared.add(_bareState.firstMatch(trimmed)![1]!);
            screen.lastState = out.length;
          } else if (RegExp(r'^(?:each|for)\s+([A-Za-z_][A-Za-z0-9_]*)\s+in\s').firstMatch(trimmed) case final m?) {
            screen.declared.add(m[1]!);
          } else if (indent == 0) {
            screen.firstNode ??= out.length;
          }
          for (final b in r.bound) {
            screen.bound.putIfAbsent(b.name, () => b.start);
          }
        }
      }
      out.add('$line${cr[i] ? '\r' : ''}');
    }
    if (states && !defs) {
      for (final s in screens.reversed) {
        final missing = [
          for (final e in s.bound.entries)
            if (!s.declared.contains(e.key) && !declared.contains(e.key)) e,
        ];
        if (missing.isEmpty) continue;
        var place = s.lastState != null ? s.lastState! + 1 : (s.heading != null ? s.heading! + 1 : s.start);
        if (s.lastState == null) {
          // Past the blank lines, comments and a fence that open it.
          while (place < out.length && (out[place].trim().isEmpty || out[place].trim().startsWith('//') || out[place].trim().startsWith('```'))) {
            place++;
          }
        }
        final end = cr.any((c) => c) ? '\r' : '';
        final added = [for (final e in missing) 'state ${e.key}=${jsonEncode(e.value)}'];
        out.insertAll(place, [for (final a in added) '$a$end']);
        log.add('$at ${place + 1}: + ${added.join(', ')}');
      }
    }
    return out.join('\n');
  }

  /// One line of something else that holds notation (a code span, a string
  /// of a JSON file, a line of an HTML page): each notation line in it from
  /// its word to its end (or the code span's), rewritten; a `bind=name` with
  /// no line around it is `@name`.
  String loose(String text) {
    final lines = text.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final l = lines[i];
      if (!_old.hasMatch(l)) continue;
      final next = _looseLine(l);
      if (next != l) {
        log.add('line ${i + 1}: ${l.trim()}  →  ${next.trim()}');
        lines[i] = next;
      }
    }
    return lines.join('\n');
  }

  String _looseLine(String l) {
    var line = l;
    for (var guard = 0; guard < 20; guard++) {
      final m = _old.firstMatch(line);
      if (m == null) break;
      // The notation line the key is on: from the nearest word before it
      // that starts a line of the notation (after a space, a quote, a
      // backtick, a parenthesis or a colon, and not inside one of the line's
      // strings), to the end of its code span.
      var start = -1;
      for (var p = m.start - 1; p >= 0; p--) {
        if (line[p] == '`' && p < m.start - 1) break;
        if ((p == 0 || ' `"(\'>:'.contains(line[p - 1])) &&
            _headAt.matchAsPrefix(line, p) != null &&
            RegExp(r'(?<!\\)"').allMatches(line.substring(p, m.start)).length.isEven) {
          start = p;
          break;
        }
      }
      String rewritten;
      int from, to;
      if (start >= 0) {
        final tick = line.indexOf('`', m.end);
        to = tick < 0 ? line.length : tick;
        from = start;
        rewritten = notationBindRewrite(line.substring(from, to), catalog: catalog).line;
      } else {
        rewritten = '';
        from = to = 0;
      }
      if (start < 0 || rewritten == line.substring(from, to)) {
        // No line around it: the key alone.
        // Its value: braced, or a word up to what ends it in prose.
        final value = RegExp(r'^(\{[^{}\s]*(\{[^{}\s]*\}[^{}\s]*)*\}|[A-Za-z_][^\s`|,;]*)').stringMatch(line.substring(m.end));
        if (value == null) break;
        final name = value.startsWith('{') ? value.substring(1, value.length - 1) : value.replaceFirst(RegExp(r'[.)]+$'), '');
        if (!value.startsWith('{') && name.length < value.length) {
          line = line.replaceRange(m.start, m.end + name.length, '@$name');
          continue;
        }
        line = line.replaceRange(m.start, m.end + value.length, '@$name');
        continue;
      }
      line = line.replaceRange(from, to, rewritten);
    }
    return line;
  }

  /// A Markdown file: its fenced blocks of notation (no language, `text`,
  /// `txt`, `notation`) as notation, the rest line by line ([loose]: code
  /// spans and the prose that writes `bind=`).
  String markdown(String source) {
    final lines = source.split('\n');
    final out = <String>[];
    for (var i = 0; i < lines.length; i++) {
      final fence = RegExp(r'^(\s*)(```+|~~~+)\s*(\w*)\s*$').firstMatch(lines[i].trimRight());
      if (fence != null) {
        final end = lines.indexWhere((l) => l.trim() == fence[2], i + 1);
        if (end < 0) {
          out.add(lines[i]);
          continue;
        }
        out.add(lines[i]);
        final body = lines.sublist(i + 1, end).join('\n');
        if (const {'', 'text', 'notation', 'txt'}.contains(fence[3])) {
          out.add(notation(body, at: 'block at line ${i + 2}, line'));
        } else if (_old.hasMatch(body)) {
          out.add(loose(body));
        } else {
          out.add(body);
        }
        out.add(lines[end]);
        i = end;
        continue;
      }
      out.add(_old.hasMatch(lines[i]) ? _looseLine(lines[i]) : lines[i]);
      if (out.last != lines[i]) log.add('line ${i + 1}: ${lines[i].trim()}  →  ${out.last.trim()}');
    }
    return out.join('\n');
  }

  /// A Dart or Python file: the notation in its string literals. A literal
  /// of several lines is a text of its own (state lines are added at its
  /// top); one of a single line is rewritten alone.
  String code(String source, {required bool python}) {
    final out = StringBuffer();
    var i = 0;
    final comment = python ? '#' : '//';
    while (i < source.length) {
      final c = source[i];
      if (source.startsWith(comment, i)) {
        final end = source.indexOf('\n', i);
        final to = end < 0 ? source.length : end;
        out.write(source.substring(i, to));
        i = to;
        continue;
      }
      if (c != "'" && c != '"') {
        out.write(c);
        i++;
        continue;
      }
      // A raw string (r'…' in either language) has no escapes.
      final prefix = RegExp(r'([A-Za-z]{1,2})$').stringMatch(source.substring(i > 2 ? i - 2 : 0, i)) ?? '';
      final raw = prefix.toLowerCase().contains('r') && (i - prefix.length == 0 || !RegExp(r'[A-Za-z0-9_]').hasMatch(source[i - prefix.length - 1]));
      final triple = source.startsWith(c * 3, i);
      final quote = triple ? c * 3 : c;
      var j = i + quote.length;
      while (j < source.length && !source.startsWith(quote, j)) {
        if (!raw && source[j] == r'\') j++;
        if (!python && !raw && source.startsWith(r'${', j)) {
          var depth = 0;
          while (j < source.length) {
            if (source[j] == '{') depth++;
            if (source[j] == '}' && --depth == 0) break;
            j++;
          }
        }
        if (j >= source.length || (!triple && source[j] == '\n')) break;
        j++;
      }
      // A literal that does not close (on its line, or at all) is not read
      // as one: what was taken for its quote is written as it is.
      if (j >= source.length || !source.startsWith(quote, j)) {
        out.write(source.substring(i, i + quote.length));
        i += quote.length;
        continue;
      }
      final body = source.substring(i + quote.length, j);
      var next = body;
      if (_old.hasMatch(body) || body.contains('@')) {
        // `\n` in a one-line literal is a line of the notation.
        final escaped = !triple && !raw && body.contains(r'\n');
        final text = escaped ? body.replaceAll(r'\n', '\n') : body;
        final before = log.length;
        final several = text.trim().contains('\n');
        final migrated = several ? notation(text, at: 'literal at offset $i, line') : loose(text);
        if (migrated != text) {
          next = escaped ? migrated.replaceAll('\n', r'\n') : migrated;
        } else {
          log.removeRange(before, log.length);
        }
      }
      out.write('$quote$next$quote');
      i = j + quote.length;
    }
    return out.toString();
  }

  /// A JSON file: its strings that hold notation (a line, or several joined
  /// by newlines), each re-encoded only when it changes.
  String json(String source) {
    final out = StringBuffer();
    var i = 0;
    while (i < source.length) {
      if (source[i] != '"') {
        out.write(source[i]);
        i++;
        continue;
      }
      var j = i + 1;
      while (j < source.length && source[j] != '"') {
        if (source[j] == r'\') j++;
        j++;
      }
      final literal = source.substring(i, j + 1 > source.length ? source.length : j + 1);
      var next = literal;
      if (_old.hasMatch(literal)) {
        try {
          final value = jsonDecode(literal) as String;
          // A string of Markdown (a design system's patterns, a block's doc
          // with code spans) as Markdown; one of several lines as a page;
          // one line alone.
          final migrated = value.contains('`')
              ? markdown(value)
              : value.contains('\n')
                  ? notation(value, states: false, at: 'string at offset $i, line')
                  : loose(value);
          if (migrated != value) next = jsonEncode(migrated);
        } on FormatException {
          // Not a string of JSON after all: as it is.
        }
      }
      out.write(next);
      i = j + 1;
    }
    return out.toString();
  }

  /// The lines of [text], a file of [kind], that still write `bind=` as a
  /// key after the rewrite (by their 1-based number): in a Dart or Python
  /// file only in its string literals, in a JSON file only in its strings;
  /// a key at the top of its line, not one in braces (`onTap={bindX=1}`).
  static List<int> left(String text, [String kind = 'notation']) {
    final lines = <int>{};
    // [lined]: the body's lines are the file's (else it is on one line).
    void scan(String body, int firstLine, {bool lined = true}) {
      for (final (i, l) in body.split('\n').indexed) {
        var depth = 0;
        String? quote;
        for (var k = 0; k < l.length; k++) {
          final c = l[k];
          if (quote != null) {
            if (c == r'\') {
              k++;
            } else if (c == quote) {
              quote = null;
            }
            continue;
          }
          if (c == '"') {
            quote = c;
          } else if (c == '{' || c == '[') {
            depth++;
          } else if ((c == '}' || c == ']') && depth > 0) {
            depth--;
          } else if (depth == 0 && (k == 0 || ' \t`(|'.contains(l[k - 1])) && _old.matchAsPrefix(l, k) != null) {
            lines.add(firstLine + (lined ? i : 0));
            break;
          }
        }
      }
    }

    if (kind == 'dart' || kind == 'python' || kind == 'json') {
      for (final r in _literals(text, kind)) {
        scan(r.body, '\n'.allMatches(text.substring(0, r.start)).length + 1, lined: r.lined);
      }
    } else {
      scan(text, 1);
    }
    return lines.toList()..sort();
  }

  /// The string literals of a Dart, Python or JSON file: where each starts
  /// and its text (a one-line literal's `\n` read as a newline).
  static List<({int start, String body, bool lined})> _literals(String source, String kind) {
    final out = <({int start, String body, bool lined})>[];
    final python = kind == 'python', json = kind == 'json';
    var i = 0;
    while (i < source.length) {
      final c = source[i];
      if (!json && source.startsWith(python ? '#' : '//', i)) {
        final end = source.indexOf('\n', i);
        i = end < 0 ? source.length : end;
        continue;
      }
      if (c != '"' && (json || c != "'")) {
        i++;
        continue;
      }
      final triple = !json && source.startsWith(c * 3, i);
      final quote = triple ? c * 3 : c;
      var j = i + quote.length;
      while (j < source.length && !source.startsWith(quote, j)) {
        if (source[j] == r'\') j++;
        if (!triple && j < source.length && source[j] == '\n') break;
        j++;
      }
      final body = source.substring(i + quote.length, j > source.length ? source.length : j);
      out.add((start: i, body: triple ? body : body.replaceAll(r'\n', '\n').replaceAll(r'\"', '"'), lined: triple));
      i = j + quote.length;
    }
    return out;
  }
}

/// A screen of a text: where it starts (its `###` line), where its head of
/// state lines ends, what it declares and what its lines bind.
final class _Screen {
  _Screen(this.start, this.heading);
  final int start;
  final int? heading;
  int? lastState, firstNode;
  final declared = <String>{};
  final bound = <String, Object?>{};
}
