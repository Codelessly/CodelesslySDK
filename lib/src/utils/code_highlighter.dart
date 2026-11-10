import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/painting.dart';

import 'extensions.dart';

/// The kinds of tokens [CodeHighlighter] tells apart. Each but [plain] has
/// a color in [CodeThemeModel], named the same.
enum CodeTokenKind {
  /// Anything else: drawn in the text's own color.
  plain,

  /// See [CodeThemeModel.keyword].
  keyword,

  /// See [CodeThemeModel.string].
  string,

  /// See [CodeThemeModel.comment].
  comment,

  /// See [CodeThemeModel.number].
  number,

  /// See [CodeThemeModel.function].
  function,

  /// See [CodeThemeModel.punctuation].
  punctuation,

  /// See [CodeThemeModel.type].
  type,

  /// See [CodeThemeModel.property].
  property,
}

/// A highlighted run of code: the characters from [start] to [end] are a
/// [kind] of token.
class CodeToken {
  /// Creates a [CodeToken].
  const CodeToken(this.start, this.end, this.kind);

  /// Where the token starts in the code.
  final int start;

  /// Where the token ends in the code (exclusive).
  final int end;

  /// What the token is.
  final CodeTokenKind kind;

  @override
  bool operator ==(Object other) =>
      other is CodeToken &&
      other.start == start &&
      other.end == end &&
      other.kind == kind;

  @override
  int get hashCode => Object.hash(start, end, kind);

  @override
  String toString() => 'CodeToken($start, $end, ${kind.name})';
}

/// A small regex-based syntax highlighter for the languages of
/// [SyntaxLanguage]: keywords, strings (template, backtick and triple-quoted
/// ones included), comments, numbers, function calls, types and built-ins,
/// properties and keys, punctuation, and for shells their `$` prompts,
/// commands, flags and variables.
///
/// It reads code a token at a time and never fails: anything it doesn't
/// recognize stays plain.
class CodeHighlighter {
  const CodeHighlighter._();

  /// The highlighted tokens of [code] read as [language], in order, without
  /// overlaps, and without the plain text between them. Neighbouring
  /// tokens of the same kind are merged.
  static List<CodeToken> highlight(String code, SyntaxLanguage language) {
    final List<CodeToken> tokens = switch (language) {
      SyntaxLanguage.none => const [],
      SyntaxLanguage.bash || SyntaxLanguage.shell => _Shell(code).scan(),
      SyntaxLanguage.json => _Json(code).scan(),
      _ => _CLike(code, _CLikeSpec.of(language)).scan(),
    };
    return _merge(tokens);
  }

  /// [spans] with the tokens of their text, read as [language], drawn in
  /// the colors of [theme] (null takes [CodeThemeModel.defaults]). The
  /// spans keep their own styles: a token only changes the color, and plain
  /// text keeps the span's color.
  ///
  /// The spans' text is read as one piece of code, so a token can run
  /// across spans.
  static List<InlineSpan> highlightSpans(
    List<InlineSpan> spans,
    SyntaxLanguage language, {
    CodeThemeModel? theme,
  }) {
    if (language == SyntaxLanguage.none) return spans;
    final StringBuffer code = StringBuffer();
    void collect(InlineSpan span) {
      if (span is TextSpan) {
        if (span.text case final String text) code.write(text);
        span.children?.forEach(collect);
      } else {
        // A placeholder (a widget in the text) takes one character.
        code.write('￼');
      }
    }

    spans.forEach(collect);
    final List<CodeToken> tokens = highlight(code.toString(), language);
    if (tokens.isEmpty) return spans;

    final CodeThemeModel colors = (theme ?? CodeThemeModel.defaults).resolved;
    final Map<CodeTokenKind, Color?> palette = {
      for (final CodeTokenKind kind in CodeTokenKind.values)
        if (kind != CodeTokenKind.plain)
          kind: colors.colorOf(kind.name)?.toFlutterColor(),
    };

    int offset = 0;
    int next = 0; // The first token that may still overlap [offset].

    InlineSpan rebuild(InlineSpan span) {
      if (span is! TextSpan) {
        offset += 1;
        return span;
      }
      final String? text = span.text;
      final List<InlineSpan> pieces = [];
      if (text != null && text.isNotEmpty) {
        final int start = offset;
        final int end = offset + text.length;
        while (next < tokens.length && tokens[next].end <= start) {
          next++;
        }
        int at = start;
        for (int i = next; i < tokens.length && tokens[i].start < end; i++) {
          final CodeToken token = tokens[i];
          final int from = token.start.clamp(start, end);
          final int to = token.end.clamp(start, end);
          if (from > at) {
            pieces.add(_piece(span, text.substring(at - start, from - start)));
          }
          final Color? color = palette[token.kind];
          pieces.add(
            _piece(
              span,
              text.substring(from - start, to - start),
              color: color,
            ),
          );
          at = to;
        }
        if (at < end) pieces.add(_piece(span, text.substring(at - start)));
        offset = end;
      }
      final List<InlineSpan>? children = span.children?.map(rebuild).toList();
      if (pieces.length <= 1 &&
          (pieces.isEmpty || (pieces.single as TextSpan).style == null) &&
          children == null) {
        return span;
      }
      return TextSpan(
        style: span.style,
        recognizer: span.recognizer,
        mouseCursor: span.mouseCursor,
        onEnter: span.onEnter,
        onExit: span.onExit,
        semanticsLabel: span.semanticsLabel,
        locale: span.locale,
        spellOut: span.spellOut,
        children: [...pieces, ...?children],
      );
    }

    return [for (final InlineSpan span in spans) rebuild(span)];
  }

  /// A piece of [span]'s text, in [color] when given. It inherits the rest
  /// of its style from [span], and keeps its tap recognizer.
  static TextSpan _piece(TextSpan span, String text, {Color? color}) =>
      TextSpan(
        text: text,
        style: color == null ? null : TextStyle(color: color),
        recognizer: span.recognizer,
        mouseCursor: span.mouseCursor,
        onEnter: span.onEnter,
        onExit: span.onExit,
      );

  static List<CodeToken> _merge(List<CodeToken> tokens) {
    final List<CodeToken> merged = [];
    for (final CodeToken token in tokens) {
      if (token.kind == CodeTokenKind.plain || token.end <= token.start) {
        continue;
      }
      final CodeToken? last = merged.isEmpty ? null : merged.last;
      if (last != null && last.kind == token.kind && last.end == token.start) {
        merged[merged.length - 1] = CodeToken(last.start, token.end, last.kind);
      } else {
        merged.add(token);
      }
    }
    return merged;
  }
}

/// Reads code one token at a time.
abstract class _Scanner {
  _Scanner(this.code);

  final String code;
  final List<CodeToken> tokens = [];
  int pos = 0;

  /// Reads the token at [pos], adds it and moves past it. Returns false
  /// when nothing matched, to skip a character.
  bool step();

  List<CodeToken> scan() {
    while (pos < code.length) {
      final int before = pos;
      if (!step() || pos <= before) pos = before + 1;
    }
    return tokens;
  }

  /// The match of [pattern] at [pos], if any.
  Match? at(RegExp pattern) => pattern.matchAsPrefix(code, pos);

  /// Adds [length] characters at [pos] as a [kind] token and moves past
  /// them.
  void emit(int length, CodeTokenKind kind) {
    tokens.add(CodeToken(pos, pos + length, kind));
    pos += length;
  }

  /// The first character after [index] that isn't a space or tab, or ''.
  String nextSignificant(int index) {
    for (int i = index; i < code.length; i++) {
      final String c = code[i];
      if (c != ' ' && c != '\t') return c;
    }
    return '';
  }

  /// The last character before [index] that isn't whitespace, or ''.
  String previousSignificant(int index) {
    for (int i = index - 1; i >= 0; i--) {
      final String c = code[i];
      if (c != ' ' && c != '\t' && c != '\n' && c != '\r') return c;
    }
    return '';
  }
}

final RegExp _whitespace = RegExp(r'\s+');
final RegExp _blockComment = RegExp(r'/\*[\s\S]*?(?:\*/|$)');
final RegExp _slashComment = RegExp(r'//[^\n]*');
final RegExp _hashComment = RegExp(r'#[^\n]*');
final RegExp _doubleQuoted = RegExp(r'"(?:\\[\s\S]|[^"\\\n])*"?');
final RegExp _singleQuoted = RegExp(r"'(?:\\[\s\S]|[^'\\\n])*'?");
final RegExp _backtick = RegExp(r'`(?:\\[\s\S]|[^`\\])*`?');
final RegExp _tripleQuoted = RegExp(
  r'''[rRbBuUfF]{0,2}(?:"""[\s\S]*?(?:"""|$)|\'\'\'[\s\S]*?(?:\'\'\'|$))''',
);
final RegExp _prefixedString = RegExp(
  r'''[rRbBuUfF]{1,2}(?:"(?:\\[\s\S]|[^"\\\n])*"?|'(?:\\[\s\S]|[^'\\\n])*'?)''',
);
final RegExp _number = RegExp(
  r'(?:0[xX][\da-fA-F_]+|0[bB][01_]+|0[oO][0-7_]+|'
  r'(?:\d[\d_]*(?:\.\d[\d_]*)?|\.\d[\d_]*)(?:[eE][+-]?\d+)?)[njLlfF]?',
);
final RegExp _punctuation = RegExp(r'[{}()\[\];,.:?<>=!+\-*/%&|^~\\@#]');

/// The words of a C-like language.
class _CLikeSpec {
  const _CLikeSpec({
    required this.keywords,
    required this.builtins,
    this.slashComments = true,
    this.hashComments = false,
    this.backtickStrings = false,
    this.tripleQuoted = false,
    this.dollarInNames = false,
    this.rubySymbols = false,
    this.decorators = false,
    this.objectKeys = false,
  });

  final Set<String> keywords;
  final Set<String> builtins;
  final bool slashComments;
  final bool hashComments;
  final bool backtickStrings;
  final bool tripleQuoted;
  final bool dollarInNames;
  final bool rubySymbols;
  final bool decorators;

  /// Whether `name:` names a key (JavaScript objects, Ruby hashes).
  final bool objectKeys;

  static _CLikeSpec of(SyntaxLanguage language) => switch (language) {
    SyntaxLanguage.typescript => _typescript,
    SyntaxLanguage.python => _python,
    SyntaxLanguage.go => _go,
    SyntaxLanguage.ruby => _ruby,
    _ => _javascript,
  };

  static const Set<String> _jsKeywords = {
    'as', 'async', 'await', 'break', 'case', 'catch', 'class', 'const', //
    'continue', 'debugger', 'default', 'delete', 'do', 'else', 'export',
    'extends', 'false', 'finally', 'for', 'from', 'function', 'get', 'if',
    'import', 'in', 'instanceof', 'let', 'new', 'null', 'of', 'return',
    'set', 'static', 'super', 'switch', 'this', 'throw', 'true', 'try',
    'typeof', 'undefined', 'var', 'void', 'while', 'with', 'yield',
  };

  static const Set<String> _jsBuiltins = {
    'Array', 'Boolean', 'Buffer', 'console', 'Date', 'document', 'Error', //
    'JSON', 'Map', 'Math', 'module', 'Number', 'Object', 'process',
    'Promise', 'Reflect', 'RegExp', 'require', 'Set', 'String', 'Symbol',
    'URL', 'window', 'exports', 'globalThis',
  };

  static const _CLikeSpec _javascript = _CLikeSpec(
    keywords: _jsKeywords,
    builtins: _jsBuiltins,
    backtickStrings: true,
    dollarInNames: true,
    objectKeys: true,
  );

  static const _CLikeSpec _typescript = _CLikeSpec(
    keywords: {
      ..._jsKeywords,
      'abstract', 'declare', 'enum', 'implements', 'infer', 'interface', //
      'is', 'keyof', 'namespace', 'private', 'protected', 'public',
      'readonly', 'satisfies', 'type',
    },
    builtins: {
      ..._jsBuiltins,
      'any', 'bigint', 'boolean', 'never', 'number', 'object', 'string', //
      'symbol', 'unknown', 'Record', 'Partial', 'Readonly', 'Pick', 'Omit',
    },
    backtickStrings: true,
    dollarInNames: true,
    objectKeys: true,
  );

  static const _CLikeSpec _python = _CLikeSpec(
    keywords: {
      'and', 'as', 'assert', 'async', 'await', 'break', 'case', 'class', //
      'continue', 'def', 'del', 'elif', 'else', 'except', 'False',
      'finally', 'for', 'from', 'global', 'if', 'import', 'in', 'is',
      'lambda', 'match', 'None', 'nonlocal', 'not', 'or', 'pass', 'raise',
      'return', 'True', 'try', 'while', 'with', 'yield',
    },
    builtins: {
      'bool', 'bytes', 'cls', 'dict', 'enumerate', 'Exception', 'float', //
      'int', 'isinstance', 'len', 'list', 'object', 'open', 'print',
      'range', 'self', 'set', 'str', 'super', 'tuple', 'type', 'zip',
    },
    slashComments: false,
    hashComments: true,
    tripleQuoted: true,
    decorators: true,
  );

  static const _CLikeSpec _go = _CLikeSpec(
    keywords: {
      'break', 'case', 'chan', 'const', 'continue', 'default', 'defer', //
      'else', 'fallthrough', 'false', 'for', 'func', 'go', 'goto', 'if',
      'import', 'interface', 'iota', 'map', 'nil', 'package', 'range',
      'return', 'select', 'struct', 'switch', 'true', 'type', 'var',
    },
    builtins: {
      'any', 'append', 'bool', 'byte', 'cap', 'close', 'complex128', //
      'complex64', 'copy', 'delete', 'error', 'float32', 'float64', 'int',
      'int16', 'int32', 'int64', 'int8', 'len', 'make', 'new', 'panic',
      'print', 'println', 'recover', 'rune', 'string', 'uint', 'uint16',
      'uint32', 'uint64', 'uint8', 'uintptr',
    },
    backtickStrings: true,
  );

  static const _CLikeSpec _ruby = _CLikeSpec(
    keywords: {
      'alias', 'and', 'begin', 'break', 'case', 'class', 'def', 'defined?', //
      'do', 'else', 'elsif', 'end', 'ensure', 'false', 'for', 'if', 'in',
      'module', 'next', 'nil', 'not', 'or', 'redo', 'rescue', 'retry',
      'return', 'self', 'super', 'then', 'true', 'undef', 'unless', 'until',
      'when', 'while', 'yield',
    },
    builtins: {
      'attr_accessor', 'attr_reader', 'attr_writer', 'include', 'lambda', //
      'p', 'proc', 'puts', 'raise', 'require', 'require_relative',
    },
    slashComments: false,
    hashComments: true,
    rubySymbols: true,
    objectKeys: true,
  );
}

/// JavaScript, TypeScript, Python, Go and Ruby.
class _CLike extends _Scanner {
  _CLike(super.code, this.spec)
    : _identifier = RegExp(
        spec.dollarInNames
            ? r'[A-Za-z_$][\w$]*'
            : spec.rubySymbols
            ? r'[A-Za-z_]\w*[?!]?'
            : r'[A-Za-z_]\w*',
      );

  final _CLikeSpec spec;
  final RegExp _identifier;

  static final RegExp _decorator = RegExp(r'@[A-Za-z_][\w.]*');
  static final RegExp _rubyInstance = RegExp(r'@@?[A-Za-z_]\w*');
  static final RegExp _rubySymbol = RegExp(r':[A-Za-z_]\w*[?!]?');

  /// The word before the current one, to tell a defined name.
  String _previousWord = '';

  @override
  bool step() {
    Match? m;
    if ((m = at(_whitespace)) != null) {
      pos += m!.end - pos;
      return true;
    }
    if (spec.slashComments) {
      if ((m = at(_slashComment) ?? at(_blockComment)) != null) {
        emit(m!.end - pos, CodeTokenKind.comment);
        return true;
      }
    }
    if (spec.hashComments && (m = at(_hashComment)) != null) {
      emit(m!.end - pos, CodeTokenKind.comment);
      return true;
    }
    if (spec.tripleQuoted &&
        (m = at(_tripleQuoted) ?? at(_prefixedString)) != null) {
      emit(m!.end - pos, CodeTokenKind.string);
      return true;
    }
    if ((m = at(_doubleQuoted) ?? at(_singleQuoted)) != null ||
        (spec.backtickStrings && (m = at(_backtick)) != null)) {
      emit(m!.end - pos, CodeTokenKind.string);
      return true;
    }
    if (spec.decorators && (m = at(_decorator)) != null) {
      emit(m!.end - pos, CodeTokenKind.type);
      return true;
    }
    if (spec.rubySymbols) {
      if ((m = at(_rubyInstance)) != null) {
        emit(m!.end - pos, CodeTokenKind.property);
        return true;
      }
      final String before = pos > 0 ? code[pos - 1] : '';
      if (before != ':' &&
          !RegExp(r'\w').hasMatch(before) &&
          (m = at(_rubySymbol)) != null) {
        emit(m!.end - pos, CodeTokenKind.string);
        return true;
      }
    }
    if ((m = at(_number)) != null) {
      emit(m!.end - pos, CodeTokenKind.number);
      return true;
    }
    if ((m = at(_identifier)) != null) {
      final String word = m![0]!;
      final CodeTokenKind kind = _classify(word, pos, m.end);
      _previousWord = word;
      emit(m.end - pos, kind);
      return true;
    }
    if ((m = at(_punctuation)) != null) {
      emit(1, CodeTokenKind.punctuation);
      return true;
    }
    return false;
  }

  CodeTokenKind _classify(String word, int start, int end) {
    final String after = nextSignificant(end);
    final String before = previousSignificant(start);
    final bool keyOfObject =
        spec.objectKeys &&
        after == ':' &&
        (end + 1 >= code.length || code[end + 1] != ':') &&
        (before == '{' || before == ',' || before == '(' || before == '');
    if (keyOfObject) return CodeTokenKind.property;
    if (before == '.' && after != '(') return CodeTokenKind.property;
    if (spec.keywords.contains(word)) return CodeTokenKind.keyword;
    if (after == '(') return CodeTokenKind.function;
    if (spec.builtins.contains(word)) return CodeTokenKind.type;
    if (_previousWord == 'def' || _previousWord == 'func') {
      return CodeTokenKind.function;
    }
    if (_previousWord == 'function') return CodeTokenKind.function;
    final int first = word.codeUnitAt(0);
    if (first >= 0x41 && first <= 0x5A) return CodeTokenKind.type;
    return CodeTokenKind.plain;
  }
}

/// JSON.
class _Json extends _Scanner {
  _Json(super.code);

  static final RegExp _literal = RegExp(r'(?:true|false|null)\b');
  static final RegExp _jsonNumber = RegExp(r'-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?');
  static final RegExp _jsonPunctuation = RegExp(r'[{}\[\],:]');

  @override
  bool step() {
    Match? m;
    if ((m = at(_whitespace)) != null) {
      pos = m!.end;
      return true;
    }
    if ((m = at(_doubleQuoted)) != null) {
      final bool key = nextSignificantAfterSpace(m!.end) == ':';
      emit(m.end - pos, key ? CodeTokenKind.property : CodeTokenKind.string);
      return true;
    }
    if ((m = at(_jsonNumber)) != null) {
      emit(m!.end - pos, CodeTokenKind.number);
      return true;
    }
    if ((m = at(_literal)) != null) {
      emit(m!.end - pos, CodeTokenKind.keyword);
      return true;
    }
    if ((m = at(_jsonPunctuation)) != null) {
      emit(1, CodeTokenKind.punctuation);
      return true;
    }
    if ((m = at(_slashComment) ?? at(_blockComment)) != null) {
      emit(m!.end - pos, CodeTokenKind.comment);
      return true;
    }
    return false;
  }

  /// The first character after [index] that isn't whitespace, or ''.
  String nextSignificantAfterSpace(int index) {
    for (int i = index; i < code.length; i++) {
      final String c = code[i];
      if (c.trim().isNotEmpty) return c;
    }
    return '';
  }
}

/// Bash and other shells.
class _Shell extends _Scanner {
  _Shell(super.code);

  static final RegExp _prompt = RegExp(r'[$%>](?=[ \t])');
  static final RegExp _variable = RegExp(
    r'\$(?:\{[^}\n]*\}?|[A-Za-z_]\w*|[0-9@#?*!$-])',
  );
  static final RegExp _ansiString = RegExp(r"\$'(?:\\[\s\S]|[^'\\])*'?");
  static final RegExp _flag = RegExp(r'--?[A-Za-z0-9][\w-]*|--(?=\s|$)');
  static final RegExp _word = RegExp(r'[A-Za-z0-9_./~:@%+,\-]+');
  static final RegExp _assignment = RegExp(r'[A-Za-z_]\w*(?==)');
  static final RegExp _shellNumber = RegExp(r'\d+(?:\.\d+)?(?![\w./:-])');
  static final RegExp _operator = RegExp(r'&&|\|\||[|&;()<>={}\[\]!\\]');
  static final RegExp _multilineString = RegExp(r'"(?:\\[\s\S]|[^"\\])*"?');
  static final RegExp _multilineSingle = RegExp(r"'[^']*'?");

  static const Set<String> _keywords = {
    'case', 'do', 'done', 'elif', 'else', 'esac', 'exit', 'export', 'fi', //
    'for', 'function', 'if', 'in', 'local', 'readonly', 'return', 'select',
    'source', 'then', 'time', 'until', 'while',
  };

  /// Keywords after which a command follows.
  static const Set<String> _commandKeywords = {
    'do', 'else', 'elif', 'if', 'then', 'time', 'until', 'while', //
  };

  /// Whether the next word is a command name.
  bool _expectCommand = true;

  /// Whether the current position starts a word (not inside one).
  bool get _wordStart {
    if (pos == 0) return true;
    final String c = code[pos - 1];
    return c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == '(';
  }

  /// Whether only spaces come before [pos] on its line.
  bool get _lineStart {
    for (int i = pos - 1; i >= 0; i--) {
      final String c = code[i];
      if (c == '\n') return true;
      if (c != ' ' && c != '\t') return false;
    }
    return true;
  }

  @override
  bool step() {
    Match? m;
    if ((m = at(_whitespace)) != null) {
      final String space = m![0]!;
      if (space.contains('\n') && previousSignificant(pos) != '\\') {
        _expectCommand = true;
      }
      pos = m.end;
      return true;
    }
    if (_wordStart && (m = at(_hashComment)) != null) {
      emit(m!.end - pos, CodeTokenKind.comment);
      return true;
    }
    if (_lineStart && (m = at(_prompt)) != null) {
      emit(1, CodeTokenKind.punctuation);
      _expectCommand = true;
      return true;
    }
    if ((m = at(_ansiString)) != null ||
        (m = at(_multilineString)) != null ||
        (m = at(_multilineSingle)) != null) {
      emit(m!.end - pos, CodeTokenKind.string);
      _expectCommand = false;
      return true;
    }
    if ((m = at(_variable)) != null) {
      emit(m!.end - pos, CodeTokenKind.property);
      _expectCommand = false;
      return true;
    }
    if (_wordStart && !_expectCommand && (m = at(_flag)) != null) {
      emit(m!.end - pos, CodeTokenKind.property);
      return true;
    }
    if (_expectCommand && (m = at(_assignment)) != null) {
      // `TOKEN=abc command`: the command still follows.
      emit(m!.end - pos, CodeTokenKind.property);
      return true;
    }
    if (_wordStart && (m = at(_shellNumber)) != null) {
      emit(m!.end - pos, CodeTokenKind.number);
      _expectCommand = false;
      return true;
    }
    if ((m = at(_word)) != null) {
      final String word = m![0]!;
      final CodeTokenKind kind;
      if (_keywords.contains(word)) {
        kind = CodeTokenKind.keyword;
        _expectCommand = _commandKeywords.contains(word);
      } else if (_expectCommand) {
        kind = CodeTokenKind.function;
        _expectCommand = false;
      } else {
        kind = CodeTokenKind.plain;
      }
      emit(m.end - pos, kind);
      return true;
    }
    if ((m = at(_operator)) != null) {
      final String op = m![0]!;
      if (op == '&&' || op == '||' || op == '|' || op == ';' || op == '(') {
        _expectCommand = true;
      }
      emit(op.length, CodeTokenKind.punctuation);
      return true;
    }
    return false;
  }
}
