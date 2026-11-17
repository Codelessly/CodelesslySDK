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
// What it rewrites is only what 33 read as a binding: a value in braces
// (`value={s}`) was shown, one way, and is left as written. A state line is
// added only for a variable this rewrite itself turned into `@name`, only in a
// text that is a page (its lines at the margin are lines of the notation),
// with the value the control, the block or the definition it binds starts at.
// What it leaves for a hand is said in [BindMigration.notes]: a binding of a
// name the runtime reserves (`theme`, `device`), prose that mentions bind=,
// bind= put together by code, a page it would not add state lines to.
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

/// What a definition binds, read from its signature and its lines (in 33's
/// form or 34's): the name of the value it keeps, and what each variable it
/// keeps starts at as written (`0`, `[0, 100]`), for the state line of a page
/// variable a use binds to it.
final class BindDefinition {
  BindDefinition(this.value, this.starts);

  /// The value a use's bare `@name` binds (`@value`, 33's `bind=value`), or
  /// null.
  final String? value;

  /// By the name the definition keeps it under: its start, as written.
  final Map<String, String> starts;

  /// What a page variable bound to [key] of a use starts at (`value` or
  /// null: the word's value), or null when the definition says nothing.
  Object? start(String? key) {
    final raw = key == null || (key == 'value' && value != null) ? starts[value ?? 'value'] : starts[key];
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null;
    }
  }

  static final _state = RegExp(r'^state\s+([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.+?)(\s+saved)?\s*$');

  /// The definitions of [text] by word: each signature at the margin
  /// (`define Word …`, `primitive Word …`; in a file of definitions
  /// [definitionFile], every line at the margin), with the lines under it.
  static Map<String, BindDefinition> read(String text, {bool definitionFile = false}) {
    final out = <String, BindDefinition>{};
    final lines = [for (final l in text.split('\n')) l.endsWith('\r') ? l.substring(0, l.length - 1) : l];
    for (var i = 0; i < lines.length; i++) {
      final l = lines[i];
      if (l.isEmpty || l.startsWith(' ') || l.startsWith('//')) continue;
      final m = RegExp(r'^(?:define|primitive)\s+').firstMatch(l);
      if (m == null && !definitionFile) continue;
      final parts = LineParts.of(m == null ? l : l.substring(m.end));
      if (parts == null || out.containsKey(parts.word)) continue;
      final body = <String, String>{};
      for (var k = i + 1; k < lines.length && (lines[k].trim().isEmpty || lines[k].startsWith(' ')); k++) {
        if (_state.firstMatch(lines[k].trim()) case final s?) body.putIfAbsent(s[1]!, () => s[2]!);
      }
      String? value;
      final starts = <String, String?>{};
      String? unbraced(String v) => v.startsWith('{') && v.endsWith('}') ? v.substring(1, v.length - 1).trim() : v;
      for (final p in parts.parts) {
        if (p.kind == 'pair' && !p.isEvent) {
          final k = p.key!, v = p.value!;
          final old = RegExp(r'^bind([A-Z][A-Za-z0-9]*)?$').firstMatch(k);
          if (k == 'bind') {
            value = unbraced(v);
          } else if (old != null) {
            starts['${old[1]![0].toLowerCase()}${old[1]!.substring(1)}'] = v;
          } else if (v.startsWith('@')) {
            starts[k] = v.length > 1 ? v.substring(1) : null;
          } else {
            starts[k] = v;
          }
        } else if (p.kind == 'word' && p.raw.startsWith('@')) {
          final w = RegExp(r'^@([A-Za-z_][A-Za-z0-9_]*)(?:=(.+))?$').firstMatch(p.raw);
          if (w != null) {
            value = w[1];
            starts[w[1]!] = w[2];
          }
        }
      }
      if (value != null) starts.putIfAbsent(value, () => null);
      out[parts.word] = BindDefinition(value, {
        for (final e in starts.entries)
          if ((e.value != null && notationIsLiteral(e.value!) ? e.value : body[e.key]) case final String s when notationIsLiteral(s)) e.key: s,
      });
    }
    return out;
  }
}

/// One file's rewrite: [log] says what changed, [notes] what is left for a
/// hand, each by its 1-based line.
final class BindMigration {
  BindMigration(this.catalog, {this.declared = const {}, this.definitionFile = false, this.definitions = const {}});

  /// The file is a design system's definitions (`vocabulary/<Word>.txt`):
  /// its texts are read as definitions whatever they look like.
  final bool definitionFile;

  /// The types the lines are read with (the standard catalog with the design
  /// systems' blocks): which line shows a value, which block keeps which
  /// variable.
  final Catalog catalog;

  /// Variables declared outside the file (a site's, in its site.json).
  final Set<String> declared;

  /// The design systems' definitions ([BindDefinition.read] of their
  /// `vocabulary/` files): what a variable bound to one of their words
  /// starts at. A file's own definitions are read from it, and come first.
  final Map<String, BindDefinition> definitions;

  final log = <String>[];

  /// What the rewrite left for a hand, each with its line: a binding of a
  /// name the runtime reserves, prose that mentions bind=, bind= put
  /// together by code, the state lines a text that is no page would need.
  final notes = <String>[];

  /// The definitions of the file being rewritten.
  Map<String, BindDefinition> _own = const {};

  /// [text], a file of [kind] ([bindKindOf]), rewritten.
  String file(String text, String kind) {
    _own = kind == 'notation' ? BindDefinition.read(text, definitionFile: definitionFile) : const {};
    return switch (kind) {
      'notation' => notation(text),
      'markdown' => markdown(text),
      'dart' => code(text, python: false),
      'python' => code(text, python: true),
      'json' => json(text),
      'html' => loose(text),
      _ => text,
    };
  }

  static final _head = RegExp(r'^[A-Z][A-Za-z0-9]*(\.[A-Za-z][A-Za-z0-9]*)*(#[A-Za-z_][A-Za-z0-9_-]*)?(?=\s|$)');
  static final _headAt = RegExp(r'[A-Z][A-Za-z0-9]*(\.[A-Za-z][A-Za-z0-9]*)*(#[A-Za-z_][A-Za-z0-9_-]*)?(?=\s|$)');
  static final _stateLine = RegExp(r'^(?:state|project|let|derived|const|var|computed)\s+([A-Za-z_][A-Za-z0-9_]*)');
  static final _bareState = RegExp(r'^([a-z_][A-Za-z0-9_]*)\s*=(?!=)');
  static final _old = RegExp(r'(?<![A-Za-z0-9_.@-])bind(?:[A-Z][A-Za-z0-9]*)?=');
  static final _statement = RegExp(r'^(?:state|project|let|derived|const|var|computed|define|primitive|each|for|if|else|every|key)\b');
  static const _pageWords = {'Page', 'App', 'Section', 'Screen', 'Main', 'Sidebar', 'Nav', 'Dialog', 'Sheet', 'Drawer', 'Menu', 'Popover', 'Lightbox', 'Header', 'Footer', 'Hero'};

  /// Whether [word] is the word of a line of the notation: a type of ours, a
  /// block of a design system, a page word, an alias, a defined word, or a
  /// word of the open vocabulary written as one (`CropFrame`: two capitals).
  bool typeWord(String word) =>
      notationTypes.containsKey(word) ||
      catalog.widget(word) != null ||
      catalog.widget('${word[0].toLowerCase()}${word.substring(1)}') != null ||
      _pageWords.contains(word) ||
      NotationVocabulary.core.types.containsKey(word) ||
      _own.containsKey(word) ||
      definitions.containsKey(word) ||
      RegExp(r'^[A-Z][a-z0-9]+[A-Z][A-Za-z0-9]*$').hasMatch(word);

  /// Whether [lines] are a page (or an answer of several screens, or
  /// definitions): every line at the margin is a line of the notation (a
  /// node line whose word is a type word, a statement, a `###` heading, a
  /// comment), and one at least is a node line. A docstring or a block of
  /// prose that quotes the notation is none.
  bool isPage(List<String> lines) {
    var nodes = 0;
    for (final raw in lines) {
      final l = raw.endsWith('\r') ? raw.substring(0, raw.length - 1) : raw;
      final t = l.trimLeft();
      if (t.isEmpty || t.startsWith('//') || t.startsWith('```') || t.startsWith('###')) continue;
      if (l.length != t.length) continue;
      final rest = t.substring(RegExp(r'^(?:\$\{[^{}]*\}|\$[A-Za-z_][A-Za-z0-9_]*)*').stringMatch(t)!.length);
      if (rest.isEmpty || _statement.hasMatch(rest) || _bareState.hasMatch(rest)) continue;
      final head = _head.stringMatch(rest);
      if (head == null || !typeWord(RegExp(r'^[A-Z][A-Za-z0-9]*').stringMatch(head)!) || LineParts.of(rest) == null) return false;
      nodes++;
    }
    return nodes > 0;
  }

  /// Whether [lines] are a file of definitions as a design system keeps them
  /// (each signature at the margin without `define`, its lines indented
  /// under it), not a page.
  ///
  /// Each line at the margin must read as a signature: a word that is no type
  /// of the notation, no block of a design system and no page word, with lines
  /// under it, strings that are names (`"label"`, not prose), and something
  /// only a signature writes (a bare event `onPick`, a parameter with no value,
  /// `min`, the value it keeps, `bind=value`).
  bool isDefinitions(List<String> lines) {
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
  /// [states]: whether the variables a screen's rewritten lines bind and
  /// nothing declares get a state line; [pageOnly]: only when the text
  /// [isPage] (else they are said in [notes]). [firstLine] is the file's line
  /// the text starts on, [at] names where the text is, for [log].
  String notation(String text, {bool states = true, bool pageOnly = false, String at = 'line', int firstLine = 1}) {
    final lines = text.split('\n');
    final cr = [for (final l in lines) l.endsWith('\r')];
    final raw = [for (final l in lines) l.endsWith('\r') ? l.substring(0, l.length - 1) : l];
    final defs = isDefinitions(raw);
    final own = BindDefinition.read(text, definitionFile: defs);
    final out = <String>[];
    // Each screen: where it starts, the state lines at its head, what it
    // declares and what its lines bind.
    final screens = <_Screen>[_Screen(0, null)];
    var inDefine = false;
    // A signature's `bindX=0.5` is `x=@0.5`: its lines' bindX is x.
    var renames = const <String, String>{};
    for (var i = 0; i < raw.length; i++) {
      var line = raw[i];
      final trimmed = line.trimLeft();
      final indent = line.length - trimmed.length;
      final screen = screens.last;
      if (indent == 0 && trimmed.startsWith('###')) {
        screens.add(_Screen(out.length, out.length));
        inDefine = false;
        renames = const {};
      } else if (indent == 0 && trimmed.isNotEmpty && !trimmed.startsWith('//')) {
        inDefine = defs || trimmed.startsWith('define ') || trimmed.startsWith('primitive ');
        renames = inDefine ? _renames(raw, i, defs, at, firstLine) : const {};
      }
      if (trimmed.isNotEmpty && !trimmed.startsWith('//') && !trimmed.startsWith('```') && !trimmed.startsWith('###')) {
        final signature = inDefine && indent == 0;
        // A line of a string literal may open with what the code puts in
        // (`${state}Column …`): the notation is after it.
        final lead = RegExp(r'^\s*(?:\$\{[^{}]*\}|\$[A-Za-z_][A-Za-z0-9_]*)*').stringMatch(line)!;
        final rest = line.substring(lead.length);
        final r = notationBindRewrite(signature && defs ? 'define $rest' : rest, catalog: catalog);
        var next = '$lead${signature && defs ? r.line.replaceFirst('define ', '') : r.line}';
        if (inDefine && !signature) {
          for (final e in renames.entries) {
            next = next.replaceAll(RegExp('(?<![A-Za-z0-9_.])${e.key}(?![A-Za-z0-9_])'), e.value);
          }
        }
        if (next != line) {
          log.add('$at ${firstLine + i}: ${line.trim()}  →  ${next.trim()}');
          line = next;
        }
        for (final name in r.refused) {
          notes.add('$at ${firstLine + i}: binds $name, a name the runtime reserves (no state line declares it): rename it by hand: ${line.trim()}');
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
          final starts = _definedStarts(r.line.trimLeft(), own);
          for (final b in r.bound) {
            screen.bound.putIfAbsent(b.name, () => starts.containsKey(b.name) ? starts[b.name] : b.start);
            screen.lines.putIfAbsent(b.name, () => firstLine + i);
          }
        }
      }
      out.add('$line${cr[i] ? '\r' : ''}');
    }
    final page = !pageOnly || isPage(raw);
    if (states && !defs) {
      for (final s in screens.reversed) {
        final missing = [
          for (final e in s.bound.entries)
            if (!s.declared.contains(e.key) && !declared.contains(e.key)) e,
        ];
        if (missing.isEmpty) continue;
        if (!page) {
          for (final e in missing) {
            notes.add('$at ${s.lines[e.key]}: not a page (its lines at the margin are not all notation), so no state line was added: state ${e.key}=${jsonEncode(e.value)} if it is one');
          }
          continue;
        }
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
        log.add('$at ${firstLine + place}: + ${added.join(', ')}');
      }
    }
    return out.join('\n');
  }

  /// The renames a definition's signature at [i] asks of its lines: 33's
  /// `bindX=0.5` is `x=@0.5`, so the lines' `bindX` is `x`. One whose new
  /// name the definition already uses is said in [notes] and not made.
  Map<String, String> _renames(List<String> raw, int i, bool defs, String at, int firstLine) {
    final sig = raw[i].replaceFirst(RegExp(r'^(?:define|primitive)\s+'), '');
    final parts = LineParts.of(sig);
    if (parts == null) return const {};
    final body = [for (var k = i + 1; k < raw.length && (raw[k].trim().isEmpty || raw[k].startsWith(' ')); k++) raw[k]].join('\n');
    final out = <String, String>{};
    for (final p in parts.parts) {
      if (p.kind != 'pair' || p.isEvent) continue;
      final m = RegExp(r'^bind([A-Z][A-Za-z0-9]*)$').firstMatch(p.key!);
      if (m == null) continue;
      final to = '${m[1]![0].toLowerCase()}${m[1]!.substring(1)}';
      final used = RegExp('(?<![A-Za-z0-9_.])$to(?![A-Za-z0-9_])');
      if (used.hasMatch(body) || parts.parts.any((x) => x.key == to || x.raw == to || x.raw.startsWith('@$to'))) {
        notes.add('$at ${firstLine + i}: ${p.key} is $to=@ in 34, and the definition already uses the name $to: rename ${p.key} in its lines by hand');
        continue;
      }
      out[p.key!] = to;
    }
    return out;
  }

  /// What the page variables [line] (rewritten) binds to a defined word
  /// start at, by the definition ([own] first, then the design systems'):
  /// its value's or the named variable's default.
  Map<String, Object?> _definedStarts(String line, Map<String, BindDefinition> own) {
    final parts = LineParts.of(line);
    if (parts == null) return const {};
    final d = own[parts.word] ?? _own[parts.word] ?? definitions[parts.word];
    if (d == null) return const {};
    final bare = [for (final p in parts.parts) if (p.kind == 'word' && p.raw.startsWith('@')) p.raw.substring(1)];
    final out = <String, Object?>{};
    // Two bare marks are a range (our Slider), not the definition's value.
    if (bare.length == 1) {
      if (d.start(null) case final Object v) out[bare.single] = v;
    }
    for (final p in parts.parts) {
      if (p.kind == 'pair' && p.value!.startsWith('@') && p.value!.length > 1) {
        if (d.start(p.key) case final Object v) out[p.value!.substring(1)] = v;
      }
    }
    return out;
  }

  /// One line of something else that holds notation (a line of an HTML page,
  /// a string of a JSON file, a one-line literal of code): each notation line
  /// in it, from its type word to its end (or its code span's), rewritten.
  /// A bind= in no such line (prose that names the old form) is left, and
  /// said.
  String loose(String text, {int firstLine = 1}) {
    final lines = text.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final l = lines[i];
      if (!_old.hasMatch(l)) continue;
      final next = _looseLine(l, firstLine + i);
      if (next != l) {
        log.add('line ${firstLine + i}: ${l.trim()}  →  ${next.trim()}');
        lines[i] = next;
      }
    }
    return lines.join('\n');
  }

  String _looseLine(String l, int lineNo) {
    var line = l;
    var from = 0;
    for (var guard = 0; guard < 20; guard++) {
      final m = _old.allMatches(line, from).firstOrNull;
      if (m == null) break;
      // The notation line the key is on: from the nearest type word before
      // it that starts a line of the notation (after a space, a quote, a
      // backtick, a parenthesis or a colon, and not inside one of the line's
      // strings), to the end of its code span.
      var start = -1;
      for (var p = m.start - 1; p >= 0; p--) {
        if (line[p] == '`' && p < m.start - 1) break;
        if ((p == 0 || ' `"(\'>:}'.contains(line[p - 1])) &&
            _headAt.matchAsPrefix(line, p) != null &&
            typeWord(RegExp(r'[A-Z][A-Za-z0-9]*').matchAsPrefix(line, p)![0]!) &&
            RegExp(r'(?<!\\)"').allMatches(line.substring(p, m.start)).length.isEven) {
          start = p;
          break;
        }
      }
      if (start >= 0) {
        final tick = line.indexOf('`', m.end);
        final to = tick < 0 ? line.length : tick;
        final r = notationBindRewrite(line.substring(start, to), catalog: catalog);
        for (final name in r.refused) {
          notes.add('line $lineNo: binds $name, a name the runtime reserves (no state line declares it): rename it by hand: ${l.trim()}');
        }
        if (r.line != line.substring(start, to)) {
          line = line.replaceRange(start, to, r.line);
          from = start;
          continue;
        }
        if (r.refused.isNotEmpty) {
          from = to;
          continue;
        }
      }
      notes.add('line $lineNo: mentions bind= in prose, left: ${l.trim()}');
      from = m.end;
    }
    return line;
  }

  /// Prose (a Markdown line out of a fence, a docstring): only a code span
  /// that is a whole notation line (it starts with a type word) is
  /// rewritten; any other bind= (`bind=name` is gone) is left, and said.
  String prose(String text, {int firstLine = 1}) {
    final lines = text.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final l = lines[i];
      if (!_old.hasMatch(l)) continue;
      var said = false;
      final next = l.replaceAllMapped(RegExp(r'(`+)(.+?)\1'), (s) {
        final span = s[2]!;
        if (!_old.hasMatch(span)) return s[0]!;
        final head = _head.stringMatch(span);
        if (head != null && typeWord(RegExp(r'^[A-Z][A-Za-z0-9]*').stringMatch(head)!)) {
          final r = notationBindRewrite(span, catalog: catalog);
          for (final name in r.refused) {
            notes.add('line ${firstLine + i}: binds $name, a name the runtime reserves (no state line declares it): rename it by hand: ${l.trim()}');
          }
          if (r.line != span) return '${s[1]}${r.line}${s[1]}';
          if (r.refused.isNotEmpty) return s[0]!;
        }
        said = true;
        return s[0]!;
      });
      if (said || _old.hasMatch(next.replaceAll(RegExp(r'(`+).+?\1'), ''))) {
        notes.add('line ${firstLine + i}: mentions bind= in prose, left: ${l.trim()}');
      }
      if (next != l) {
        log.add('line ${firstLine + i}: ${l.trim()}  →  ${next.trim()}');
        lines[i] = next;
      }
    }
    return lines.join('\n');
  }

  /// A Markdown file: its fenced blocks of notation (no language, `text`,
  /// `txt`, `notation`) as notation (state lines only in one that is a
  /// page), any other fence that writes bind= line by line ([loose]), and its
  /// prose by its code spans ([prose]).
  String markdown(String source, {int firstLine = 1}) {
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
          out.add(notation(body, pageOnly: true, at: 'line', firstLine: firstLine + i + 1));
        } else if (_old.hasMatch(body)) {
          out.add(loose(body, firstLine: firstLine + i + 1));
        } else {
          out.add(body);
        }
        out.add(lines[end]);
        i = end;
        continue;
      }
      out.add(_old.hasMatch(lines[i]) ? prose(lines[i], firstLine: firstLine + i) : lines[i]);
    }
    return out.join('\n');
  }

  /// A Dart or Python file: the notation in its string literals. A literal
  /// of several lines that is a page is a text of its own (state lines are
  /// added at its top); one that is not (a docstring) is prose; one of a
  /// single line is rewritten alone. A literal that puts bind= together
  /// (`' bind=$key'`, `f"bind={name}"`) is left, and said.
  String code(String source, {required bool python}) {
    final out = StringBuffer();
    var i = 0;
    final comment = python ? '#' : '//';
    int lineAt(int offset) => '\n'.allMatches(source.substring(0, offset)).length + 1;
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
      final standalone = i - prefix.length == 0 || !RegExp(r'[A-Za-z0-9_]').hasMatch(source[i - prefix.length - 1]);
      final raw = prefix.toLowerCase().contains('r') && standalone;
      final formatted = python && prefix.toLowerCase().contains('f') && standalone;
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
      if (_old.hasMatch(body)) {
        final line = lineAt(i);
        // bind= whose value the code puts in (`bind=$key`, `bind=${k}`,
        // f"bind={name}", 'bind=%s', or a literal that ends at bind=): no
        // line of notation to rewrite here.
        final built = [
          for (final m in _old.allMatches(body))
            if (m.end == body.length ||
                RegExp(r'^[\s%]').hasMatch(body.substring(m.end)) ||
                (!python && !raw && body.startsWith(r'$', m.end)) ||
                (formatted && body.startsWith('{', m.end) && !body.startsWith('{{', m.end)) ||
                body.startsWith('{}', m.end))
              m,
        ];
        if (built.isNotEmpty) {
          for (final m in built) {
            notes.add('line ${line + '\n'.allMatches(body.substring(0, m.start)).length}: bind= built in code: rewrite by hand: ${body.trim().split('\n').first}');
          }
        } else {
          // `\n` in a one-line literal is a line of the notation.
          final escaped = !triple && !raw && body.contains(r'\n');
          final text = escaped ? body.replaceAll(r'\n', '\n') : body;
          final before = log.length;
          final several = text.trim().contains('\n');
          final migrated = !several
              ? loose(text, firstLine: line)
              : isPage(text.split('\n'))
                  ? notation(text, at: 'line', firstLine: line)
                  : prose(text, firstLine: line);
          if (migrated != text) {
            next = escaped ? migrated.replaceAll('\n', r'\n') : migrated;
          } else {
            log.removeRange(before, log.length);
          }
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
        final line = '\n'.allMatches(source.substring(0, i)).length + 1;
        try {
          final value = jsonDecode(literal) as String;
          // A string of Markdown (a design system's patterns, a block's doc
          // with code spans) as Markdown; one of several lines as a page;
          // one line alone.
          final migrated = value.contains('`')
              ? markdown(value, firstLine: line)
              : value.contains('\n')
                  ? notation(value, states: false, at: 'string at line $line, line')
                  : loose(value, firstLine: line);
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
/// state lines ends, what it declares, what its lines bind and where each is
/// first bound.
final class _Screen {
  _Screen(this.start, this.heading);
  final int start;
  final int? heading;
  int? lastState, firstNode;
  final declared = <String>{};
  final bound = <String, Object?>{};
  final lines = <String, int>{};
}
