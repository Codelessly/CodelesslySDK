// The harvest of a corpus of self-defining answers (the vocabulary loop's
// journal, Review 3 D15 and Review 4 D22): every word defined in more than one
// answer, its definitions side by side (signature and body), what each body
// leans on (core words, universal words, other definitions), and where the
// signatures disagree; and the words one answer defined that other answers
// used without a definition (a definition that would resolve them).
//
// Promotion of a definition to a design system's vocabulary/ is a fixer's
// judgment, not this tool's.
import 'package:codelessly_api/notation.dart';

/// The words review 2 named as meaning the same on every line (D7): a
/// parameter, flag or event a body uses from this list is listed apart.
const universalWords = {
  'color', 'size', 'icon', 'selected', 'disabled', 'readonly', 'tooltip', 'required', //
  'reorder', 'sortable', 'onReorder', 'removable', 'onRemove', 'selectable', 'onSelect',
};

/// One answer's definition of a word.
final class HarvestedDefinition {
  HarvestedDefinition(this.file, this.definition);
  final String file;
  final NotationDefinition definition;

  /// What its body leans on, by kind: `core`, `component`, `defined`,
  /// `unknown` (first words of its lines) and `universal` (its parameters,
  /// flags and events in [universalWords]).
  final uses = <String, Set<String>>{};

  Map<String, Object?> toJson() => {
        'file': file,
        'signature': definition.signature,
        if (definition.doc.isNotEmpty) 'doc': definition.doc,
        'body': [for (final l in definition.body) '${' ' * l.indent}${l.text}'],
        'uses': {for (final e in uses.entries) if (e.value.isNotEmpty) e.key: (e.value.toList()..sort())},
      };
}

const _statements = {'state', 'if', 'else', 'each', 'for', 'every', 'key', 'project', 'let', 'derived', 'computed'};

/// Gathers the definitions of each answer, then [words] and [wouldResolve].
final class Harvest {
  Harvest({required this.kindOf});

  /// How a first word of a body line resolves outside any definition:
  /// `core`, `component` or `unknown`.
  final String Function(String word) kindOf;

  /// By word, each answer's definitions (one answer may define a word with
  /// several meanings).
  final byWord = <String, List<HarvestedDefinition>>{};

  /// The answers that used a word as a type nobody had defined for them.
  final unknownIn = <String, Set<String>>{};

  /// The definitions [file] wrote (its `define` blocks, anywhere in it).
  void answer(String file, String text) {
    final read = readPageDefinitions(text);
    for (final e in read.words.entries) {
      for (final d in e.value) {
        final h = HarvestedDefinition(file, d);
        for (final l in d.body) {
          if (l.text.startsWith('...')) continue;
          final p = LineParts.of(l.text);
          if (p == null) continue;
          if (!_statements.contains(p.word)) {
            final kind = read.words.containsKey(p.word) ? 'defined' : kindOf(p.word);
            h.uses.putIfAbsent(kind, () => {}).add(p.word);
          }
          for (final x in _parts(p.parts)) {
            final name = x.kind == 'pair' ? x.key : x.kind == 'word' ? x.raw : null;
            if (name != null && universalWords.contains(name)) h.uses.putIfAbsent('universal', () => {}).add(name);
          }
        }
        byWord.putIfAbsent(e.key, () => []).add(h);
      }
    }
  }

  /// [parts], with a value written where the text goes (`Ring {share} w=56
  /// color={c}`) read past: the line goes on after it.
  static Iterable<LinePart> _parts(List<LinePart> parts) sync* {
    for (final x in parts) {
      if (x.kind != 'tail' || x.raw.startsWith('{"')) {
        yield x;
        continue;
      }
      var depth = 0, end = x.raw.length;
      for (var i = 0; i < x.raw.length; i++) {
        if (x.raw[i] == '{') depth++;
        if (x.raw[i] == '}' && --depth == 0) {
          end = i + 1;
          break;
        }
      }
      final rest = LineParts.of('X ${x.raw.substring(end).trim()}');
      if (rest != null) yield* _parts(rest.parts);
    }
  }

  /// [word] was used in [file] and nothing defined it there.
  void unknown(String word, String file) => unknownIn.putIfAbsent(word, () => {}).add(file);

  /// The words defined in more than one answer, most answers first.
  List<MapEntry<String, List<HarvestedDefinition>>> get words {
    int answers(List<HarvestedDefinition> l) => l.map((h) => h.file).toSet().length;
    return byWord.entries.where((e) => answers(e.value) > 1).toList()
      ..sort((a, b) => answers(b.value) != answers(a.value) ? answers(b.value) - answers(a.value) : a.key.compareTo(b.key));
  }

  /// Where the signatures of [defs] disagree: their strings, a parameter some
  /// name and others do not, and a parameter that may be one under two names
  /// (the same default, each name in other answers only).
  static List<String> disagreements(List<HarvestedDefinition> defs) {
    final notes = <String>[];
    final strings = {for (final h in defs) h.definition.strings.join(', ')};
    if (strings.length > 1) notes.add('strings differ: ${strings.map((s) => s.isEmpty ? '(none)' : '"$s"').join(' / ')}');
    final files = {for (final h in defs) h.file};
    final named = <String, Set<String>>{};
    for (final h in defs) {
      for (final p in [...h.definition.parameters.keys, ...h.definition.events, if (h.definition.bind != null) '@${h.definition.bind}']) {
        named.putIfAbsent(p, () => {}).add(h.file);
      }
    }
    final partial = [for (final e in named.entries) if (e.value.length < files.length) e.key]..sort();
    if (partial.isNotEmpty) notes.add('named by some answers only: ${partial.map((p) => '$p (${named[p]!.length})').join(', ')}');
    // The same default under two names, never in the same answer.
    final byDefault = <String, Set<String>>{};
    for (final h in defs) {
      for (final e in h.definition.parameters.entries) {
        if (e.value == null || e.value == 'true' || e.value == 'false') continue;
        byDefault.putIfAbsent(e.value!, () => {}).add(e.key);
      }
    }
    for (final e in byDefault.entries) {
      final names = e.value.where((n) => named[n]!.length < files.length).toList()..sort();
      for (var i = 0; i < names.length; i++) {
        for (var j = i + 1; j < names.length; j++) {
          if (named[names[i]]!.intersection(named[names[j]]!).isEmpty) notes.add('maybe one parameter under two names: ${names[i]} / ${names[j]} (both default ${e.key})');
        }
      }
    }
    return notes;
  }

  /// The words one or more answers defined that other answers used with no
  /// definition: a definition that would resolve them.
  List<({String word, List<String> definedIn, List<String> unknownIn})> get wouldResolve => [
        for (final e in byWord.entries)
          if (unknownIn[e.key] case final Set<String> u when u.difference(e.value.map((h) => h.file).toSet()).isNotEmpty)
            (
              word: e.key,
              definedIn: (e.value.map((h) => h.file).toSet().toList()..sort()),
              unknownIn: (u.difference(e.value.map((h) => h.file).toSet()).toList()..sort()),
            ),
      ]..sort((a, b) => b.unknownIn.length != a.unknownIn.length ? b.unknownIn.length - a.unknownIn.length : a.word.compareTo(b.word));

  Map<String, Object?> toJson() => {
        'definedInMoreThanOne': [
          for (final e in words)
            {
              'word': e.key,
              'answers': e.value.map((h) => h.file).toSet().length,
              'definitions': [for (final h in e.value) h.toJson()],
              'disagree': disagreements(e.value),
            },
        ],
        'wouldResolve': [
          for (final w in wouldResolve) {'word': w.word, 'definedIn': w.definedIn, 'unknownIn': w.unknownIn},
        ],
      };

  /// The two sections of VOCABULARY.md.
  String markdown() {
    final md = StringBuffer()
      ..writeln()
      ..writeln('## Words defined in more than one answer')
      ..writeln()
      ..writeln('Each answer\'s definition side by side (signature and the lines it stands for), with what its lines use: core '
          'words, ${'universal words (${universalWords.join(', ')})'}, other definitions, words nobody has. A note says where '
          'the signatures disagree. Promoting one to a design system\'s vocabulary is a fixer\'s judgment.')
      ..writeln();
    final ws = words;
    if (ws.isEmpty) md.writeln('None.');
    for (final e in ws) {
      final answers = e.value.map((h) => h.file).toSet().length;
      md
        ..writeln('### ${e.key} ($answers answers)')
        ..writeln();
      for (final n in disagreements(e.value)) {
        md.writeln('- $n');
      }
      if (disagreements(e.value).isNotEmpty) md.writeln();
      for (final h in e.value) {
        final uses = [
          for (final k in const ['core', 'component', 'universal', 'defined', 'unknown'])
            if (h.uses[k] case final Set<String> s when s.isNotEmpty) '$k: ${(s.toList()..sort()).join(', ')}',
        ];
        md
          ..writeln('${h.file}${uses.isEmpty ? '' : ' (${uses.join('; ')})'}:')
          ..writeln()
          ..writeln('```')
          ..writeln([
            if (h.definition.doc.isNotEmpty) '// ${h.definition.doc}',
            'define ${h.definition.signature}',
            for (final l in h.definition.body) '  ${' ' * l.indent}${l.text}',
          ].join('\n'))
          ..writeln('```')
          ..writeln();
      }
    }
    md
      ..writeln('## Words one answer defined that others used without a definition')
      ..writeln()
      ..writeln('A definition from the first list would resolve the word in the second.')
      ..writeln()
      ..writeln('| word | defined in | used with none in |')
      ..writeln('|---|---|---|');
    for (final w in wouldResolve) {
      md.writeln('| ${w.word} | ${w.definedIn.join(', ')} | ${w.unknownIn.join(', ')} |');
    }
    return md.toString();
  }
}
