// Every word a corpus of answers used, known or not, with how it resolved
// (the vocabulary loop's journal, Review 1, D1): read from the answers' own
// lines, and resolved with what the parser recorded for each line (the words
// it did not have, the aliases it read, the words defined in the notation)
// and what it has (the design system's components, the formula engine's
// functions). It costs the parser nothing: the parser records only what it
// did not know, as before; what it knew is everything else on the line.
//
// A word is one of these kinds, each counted once per type it is on for the
// kinds that are on a type:
//
//   type        a line's first word                       SeatMap, Card
//   text        a string written on a type, by position   Button.text1
//   parameter   a key=value on a type                     Slider.min
//   flag        a bare word on a type (layout words too)  Row.between
//   event       an on… key on a type                      Button.onTap
//   variant     the word after a type's dot               Text.caption
//   verb        an action's first word                    toast, go, set
//   function    a function a formula calls                filter, fuzzyMatch
//   statement   a line's first word that is not a type    state, each, if
//
// and resolves as one of: core, component, alias (with what it was read
// as), definition (a word defined in the notation, with which meaning),
// universal (a word every line understands, read where the type has no word
// of that name, or honoured by a stand-in for a type we do not have:
// codelessly_api docs/design/21-universal-words.md), primitive (a word
// declared with `primitive`, for what no line can express, and what its uses
// were given: it stands in), unread (a string, parameter, flag or event a
// definition names and its lines never read or fire: codelessly_api
// docs/design/20 section 12), or unknown. Resolved is the first five.
import 'package:codelessly_api/notation.dart';
import 'package:codelessly_sdk/src/runtime/expressions/formula.dart' show FormulaEvaluator;

/// The words a line starts with that are not a type.
const vocabularyStatements = {'state', 'if', 'each', 'else', 'for', 'key', 'every', 'project', 'node', 'document', 'let', 'derived', 'const', 'var', 'computed', 'shortcut', 'define', 'primitive'};

/// The kinds, in the order they are listed.
const wordKinds = ['type', 'text', 'parameter', 'flag', 'event', 'variant', 'verb', 'function', 'statement'];

/// The resolutions, in the order they are listed.
const wordResolutions = ['core', 'component', 'alias', 'definition', 'universal', 'primitive', 'unread', 'unknown'];

/// The resolutions that are not resolved: a stand-in, a word named and never
/// read, a word we do not have.
const unresolvedResolutions = {'primitive', 'unread', 'unknown'};

final class CorpusWord {
  CorpusWord(this.kind, this.on, this.word);
  final String kind, word;
  final String? on;

  /// Uses by how they resolved, and what each alias or definition was read
  /// as.
  final how = <String, int>{};
  final to = <String>{};
  final files = <String>{};
  String? example;

  int get uses => how.values.fold(0, (a, b) => a + b);

  /// How most of its uses resolved.
  String get resolved => (how.entries.toList()..sort((a, b) => b.value != a.value ? b.value - a.value : wordResolutions.indexOf(a.key) - wordResolutions.indexOf(b.key))).first.key;

  Map<String, Object?> toJson() => {
        'kind': kind,
        if (on != null) 'on': on,
        'word': word,
        'resolved': resolved,
        if (how.length > 1) 'how': how,
        if (to.isNotEmpty) 'to': (to.toList()..sort()).join(', '),
        'files': files.length,
        'in': files.toList()..sort(),
        'uses': uses,
        if (example != null) 'example': example,
      };
}

/// The headline numbers of [corpus], each distinct word once: resolved (core,
/// component, alias, definition or universal), stand-in (a primitive and what
/// its uses were given; [primitives] were declared), never read (named by a
/// definition whose lines do not read it) and unknown, the types apart from
/// the rest (parameters, texts, flags, events, variants, verbs, functions).
Map<String, int> countOf(CorpusWords corpus, {int primitives = 0}) {
  final all = corpus.words.values;
  int n(String r) => all.where((w) => w.resolved == r).length;
  final unknownTypes = all.where((w) => w.resolved == 'unknown' && w.kind == 'type').length;
  return {
    'words': all.length,
    'resolved': all.where((w) => !unresolvedResolutions.contains(w.resolved)).length,
    'standIn': n('primitive'),
    'primitivesDeclared': primitives,
    'primitiveUses': corpus.primitiveTypes.uses,
    'unread': n('unread'),
    'unknown': n('unknown'),
    'unknownTypes': unknownTypes,
    'unknownOther': n('unknown') - unknownTypes,
  };
}

/// [count] ([countOf]) as one line: `1069 words: resolved 1001 (93.6%),
/// stand-in 12 (2 primitives declared, 9 uses), never read 56, unknown 0 (0
/// types, 0 other words)`.
String countLine(Map<String, Object?> count) {
  int n(String k) => (count[k] as int?) ?? 0;
  final words = n('words');
  return '$words words: resolved ${n('resolved')} (${words == 0 ? '0.0' : (100 * n('resolved') / words).toStringAsFixed(1)}%), '
      'stand-in ${n('standIn')} (${n('primitivesDeclared')} primitives declared, ${n('primitiveUses')} uses), '
      'never read ${n('unread')}, '
      'unknown ${n('unknown')} (${n('unknownTypes')} types, ${n('unknownOther')} other words: parameters, texts, flags, events, variants, verbs, functions)';
}

/// What the parser recorded for one line of a screen.
final class _LineRecord {
  String? type; // unknown, alias or definition
  String? typeTo;
  final unknown = <String>{}; // kind:word
  final alias = <String, String>{}; // kind:word -> to
  final universal = <String>{}; // kind:word
}

final class CorpusWords {
  CorpusWords({required this.components, Set<String>? functions}) : functions = functions ?? FormulaEvaluator.functions.toSet();

  /// The design system's components (a type written with one of these
  /// names that the notation does not have itself is a component).
  final Set<String> components;

  /// The functions a formula may call.
  final Set<String> functions;

  final words = <String, CorpusWord>{};

  void _add(String kind, String? on, String word, String how, String file, String example, {String? to}) {
    final w = words.putIfAbsent('$kind ${on ?? ''} $word', () => CorpusWord(kind, on, word));
    w.how[how] = (w.how[how] ?? 0) + 1;
    if (to != null && to.isNotEmpty) w.to.add(to);
    w.files.add(file);
    w.example ??= example.length > 200 ? '${example.substring(0, 197)}...' : example;
  }

  /// The words of one screen ([text], as written) of [file], which the
  /// parser read as [result]. [reads] is what each definition the answer
  /// reads leaves unused, by its label (`Timeline#events`): a word given to a
  /// use that its definition names and never reads is `unread`.
  void screen(String file, String text, NotationResult result, {Map<String, DefinitionReads> reads = const {}}) {
    final records = <int, _LineRecord>{};
    for (final u in result.vocabulary) {
      final r = records.putIfAbsent(u.line, _LineRecord.new);
      switch (u.kind) {
        case 'type':
          r.type = 'unknown';
        case 'definition' || 'primitive':
          r.type = u.kind;
          r.typeTo = u.to;
        case 'universal':
          r.universal.add('${u.of}:${u.word}');
        case 'alias':
          if (u.of == 'type' || u.of == 'line') {
            r.type = 'alias';
            r.typeTo = u.of == 'line' ? u.to!.split(RegExp(r'[ #]')).first : u.to;
          } else {
            r.alias['${u.of}:${u.word}'] = u.to ?? '';
          }
        default:
          r.unknown.add('${u.kind}:${u.word}');
      }
    }
    final lines = text.split(RegExp(r'\r?\n'));
    var defining = false;
    for (var i = 0; i < lines.length; i++) {
      final raw = lines[i];
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('//') || line.startsWith('```')) continue;
      final indent = raw.length - raw.trimLeft().length;
      // A `define` (or `primitive`) in the answer is the definition's, not the answer's.
      if (indent == 0) defining = line.startsWith('define ') || line.startsWith('primitive ');
      if (defining) continue;
      final parts = LineParts.of(line);
      if (parts == null) continue;
      final r = records[i + 1] ?? _LineRecord();
      String how(String kind, String word, String typeHow) {
        if (r.unknown.contains('$kind:$word')) return 'unknown';
        if (r.alias.containsKey('$kind:$word')) return 'alias';
        if (r.universal.contains('$kind:$word')) return 'universal';
        return typeHow;
      }

      if (vocabularyStatements.contains(parts.word)) {
        _add('statement', null, parts.word, r.type == 'alias' ? 'alias' : 'core', file, line, to: r.type == 'alias' ? r.typeTo : null);
        if (parts.word == 'state' || parts.word == 'project') {
          for (final p in parts.parts.where((p) => p.kind == 'word')) {
            _add('flag', parts.word, p.raw, how('flag', p.raw, 'core'), file, line, to: r.alias['flag:${p.raw}']);
          }
        }
        _actions(line, r, file);
        continue;
      }
      final type = parts.word;
      final String typeHow;
      if (r.type case final String t) {
        typeHow = t;
      } else if (components.contains(type) && !notationTypes.containsKey(type)) {
        typeHow = 'component';
      } else {
        typeHow = 'core';
      }
      _add('type', null, type, typeHow, file, line, to: r.typeTo);
      // On a word we do not have, what it was given has no meaning either;
      // on a defined word, a name its definition never reads has none.
      final partsHow = typeHow == 'alias' ? 'core' : typeHow;
      final unused = typeHow == 'definition' ? reads[r.typeTo] : null;
      String given(String word, String how) {
        if (how != 'definition' || unused == null) return how;
        // `bind=x` gives the variable the definition calls by its own name.
        final name = word == 'bind' ? unused.definition.bind : word;
        return unused.unread.contains(name) || unused.unfired.contains(name) ? 'unread' : how;
      }
      for (final v in parts.variant.split('.').where((v) => v.isNotEmpty)) {
        _add('variant', type, v, r.unknown.contains('variant:$type.$v') ? 'unknown' : partsHow, file, line);
      }
      var strings = 0;
      // A bare number before any key or word is in the text position (D9:
      // codelessly_api docs/design/21 section 8), counted as a text.
      var keyed = false;
      for (final p in parts.parts) {
        final number = p.kind == 'word' && !keyed && num.tryParse(p.raw) != null;
        if (p.kind == 'pair' || (p.kind == 'word' && !number)) keyed = true;
        switch (number ? 'string' : p.kind) {
          case 'string':
            strings++;
            final word = 'text$strings';
            final name = unused == null || strings > unused.definition.strings.length ? '' : unused.definition.strings[strings - 1];
            _add('text', type, word, r.unknown.contains('parameter:string$strings') ? 'unknown' : given(name, partsHow), file, line);
          case 'pair':
            final kind = p.isEvent ? 'event' : 'parameter';
            _add(kind, type, p.key!, given(p.key!, how(kind, p.key!, partsHow)), file, line, to: r.alias['$kind:${p.key}']);
          case 'word':
            _add('flag', type, p.raw, given(p.raw, how('flag', p.raw, partsHow)), file, line, to: r.alias['flag:${p.raw}']);
        }
      }
      _actions(line, r, file);
    }
  }

  /// The verbs of the actions on [line] and the functions its formulas call.
  void _actions(String line, _LineRecord r, String file) {
    for (final m in RegExp(r'\bon[A-Z][A-Za-z0-9]*=\{').allMatches(line)) {
      final close = _braceEnd(line, m.end - 1);
      final inner = line.substring(m.end, close - 1 < m.end ? m.end : close - 1);
      for (final action in _split(inner)) {
        final a = action.trim();
        if (a.isEmpty) continue;
        final String verb;
        if (RegExp(r'^[A-Za-z_][A-Za-z0-9_.\[\]]*\s*(=(?!=)|\+=|-=|\+\+|--)').hasMatch(a)) {
          verb = 'set';
        } else if (RegExp(r'^[A-Za-z_][A-Za-z0-9_.]*').stringMatch(a) case final String w) {
          verb = w;
        } else {
          continue;
        }
        final how = r.unknown.contains('verb:$verb') ? 'unknown' : r.alias.containsKey('verb:$verb') ? 'alias' : 'core';
        _add('verb', null, verb, how, file, a, to: r.alias['verb:$verb']);
      }
    }
    // A function a formula calls: a name before `(` that is not a field's.
    for (final m in RegExp(r'(?<![.A-Za-z0-9_])([A-Za-z_][A-Za-z0-9_]*)\(').allMatches(_formulas(line))) {
      final f = m[1]!;
      if (vocabularyStatements.contains(f) || f == 'if') continue;
      _add('function', null, f, functions.contains(f) ? 'core' : 'unknown', file, line);
    }
  }

  /// The formulas of [line]: what is in its braces, strings left out except
  /// their own braces.
  static String _formulas(String line) {
    final out = StringBuffer();
    var depth = 0;
    var quoted = false;
    for (var i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"' && (i == 0 || line[i - 1] != r'\')) {
        quoted = !quoted;
        if (depth > 0) out.write(' ');
        continue;
      }
      if (c == '{') {
        depth++;
        out.write(' ');
        continue;
      }
      if (c == '}') {
        if (depth > 0) depth--;
        out.write(' ');
        continue;
      }
      if (depth > 0 && !quoted) out.write(c);
      if (depth > 0 && quoted) out.write(' ');
    }
    return out.toString();
  }

  static List<String> _split(String actions) {
    final out = <String>[];
    var depth = 0, from = 0;
    var quoted = false;
    for (var i = 0; i < actions.length; i++) {
      final c = actions[i];
      if (c == '"' && (i == 0 || actions[i - 1] != r'\')) quoted = !quoted;
      if (quoted) continue;
      if ('([{'.contains(c)) depth++;
      if (')]}'.contains(c)) depth--;
      if (c == ';' && depth == 0) {
        out.add(actions.substring(from, i));
        from = i + 1;
      }
    }
    out.add(actions.substring(from));
    return out;
  }

  static int _braceEnd(String text, int open) {
    var depth = 0;
    var quoted = false;
    for (var k = open; k < text.length; k++) {
      final c = text[k];
      if (c == '"' && text[k - 1] != r'\') quoted = !quoted;
      if (quoted) continue;
      if (c == '{') depth++;
      if (c == '}' && --depth == 0) return k + 1;
    }
    return text.length;
  }

  /// Distinct words by kind and resolution.
  Map<String, Map<String, int>> summary() {
    final out = <String, Map<String, int>>{for (final k in wordKinds) k: {for (final r in wordResolutions) r: 0}};
    for (final w in words.values) {
      out[w.kind]![w.resolved] = out[w.kind]![w.resolved]! + 1;
    }
    return out;
  }

  /// The words used as a line's first word that resolved as a primitive,
  /// and their uses.
  ({int words, int uses}) get primitiveTypes {
    final types = [for (final w in words.values) if (w.kind == 'type' && w.how.containsKey('primitive')) w];
    return (words: types.length, uses: types.fold(0, (n, w) => n + w.how['primitive']!));
  }

  List<CorpusWord> sorted() => words.values.toList()
    ..sort((a, b) {
      final k = wordKinds.indexOf(a.kind) - wordKinds.indexOf(b.kind);
      if (k != 0) return k;
      if (b.files.length != a.files.length) return b.files.length - a.files.length;
      if (b.uses != a.uses) return b.uses - a.uses;
      return '${a.on}.${a.word}'.compareTo('${b.on}.${b.word}');
    });
}
