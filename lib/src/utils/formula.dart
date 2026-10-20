import 'dart:math' as math;

/// Matches a formula written as `${= expression}` in a text.
///
/// The expression can't contain braces, except inside quoted strings.
final RegExp formulaRegex = RegExp(
  r'''(?<!\\)\$\{=(?<expr>(?:[^{}'"]|'[^']*'|"[^"]*")*)\}''',
);

/// Matches a text that is exactly one formula, e.g. `${= qty * price}`.
final RegExp exactFormulaRegex = RegExp(
  r'''^\s*(?<!\\)\$\{=(?<expr>(?:[^{}'"]|'[^']*'|"[^"]*")*)\}\s*$''',
);

/// Resolves a variable path such as `storage.cart` or `item.price` to its
/// value.
typedef FormulaPathResolver = Object? Function(String path);

/// Evaluates small expressions used in `${= ...}` formulas.
///
/// Supports:
///  - numbers, 'single' or "double" quoted strings, true, false, null and
///    `[a, b]` lists.
///  - variable paths like `storage.cart.length` or `item.price`, resolved with
///    the same rules as `${path}`, followed by `[index]` or `.key`.
///  - `+ - * / %`, comparisons `== != < <= > >=`, `&& || !` and
///    `condition ? a : b`. `+` joins text when either side is text.
///  - functions: money, fixed, round, floor, ceil, abs, min, max, sum, count,
///    length, if, plural, join, upper, lower, contains, where, without,
///    number, text, isEmpty and isNotEmpty. See [FormulaEvaluator.functions].
///
/// Null counts as 0 in arithmetic and as empty text when joining text. An
/// invalid expression evaluates to null.
class FormulaEvaluator {
  const FormulaEvaluator._();

  static final Map<String, _Node?> _cache = {};

  /// Evaluates [expression], resolving variable paths with [resolve].
  static Object? evaluate(String expression, FormulaPathResolver resolve) {
    final _Node? node = _parse(expression);
    if (node == null) return null;
    try {
      return node.eval(resolve);
    } catch (_) {
      return null;
    }
  }

  /// The variable paths [expression] reads, e.g. `storage.cart` and `qty`.
  static Set<String> referencedPaths(String expression) {
    final _Node? node = _parse(expression);
    if (node == null) return {};
    final Set<String> paths = {};
    node.collectPaths(paths);
    return paths;
  }

  /// The variable paths read by every formula in [text].
  static Set<String> referencedPathsInText(String text) => {
    for (final match in formulaRegex.allMatches(text))
      ...referencedPaths(match.namedGroup('expr')!),
  };

  /// Replaces every `${= ...}` formula in [text] with its result as text.
  /// A formula that evaluates to null becomes [nullText].
  static String substitute(
    String text,
    FormulaPathResolver resolve, {
    String nullText = '',
  }) {
    if (!text.contains(r'${=')) return text;
    return text.splitMapJoin(
      formulaRegex,
      onMatch: (match) {
        final Object? value = evaluate(
          (match as RegExpMatch).namedGroup('expr')!,
          resolve,
        );
        return value == null ? nullText : stringify(value);
      },
      onNonMatch: (text) => text,
    );
  }

  /// The expression of [text] when it is exactly one formula, else null.
  static String? exactExpression(String text) =>
      exactFormulaRegex.firstMatch(text)?.namedGroup('expr');

  /// Formats [value] as text: whole numbers drop their decimals and other
  /// numbers lose floating point noise, e.g. 17.200000000000003 is "17.2".
  static String stringify(Object? value) {
    if (value == null) return '';
    if (value is num) {
      if (value.isNaN || value.isInfinite) return '';
      if (value == value.roundToDouble()) return value.toInt().toString();
      String text = value.toStringAsFixed(10);
      text = text.replaceFirst(RegExp(r'0+$'), '');
      return text.endsWith('.') ? text.substring(0, text.length - 1) : text;
    }
    if (value is List) return value.map(stringify).join(', ');
    return value.toString();
  }

  /// Parses [expression], caching the result. Returns null when it's invalid.
  static _Node? _parse(String expression) {
    final String key = expression.trim();
    if (_cache.containsKey(key)) return _cache[key];
    _Node? node;
    try {
      node = _Parser(key).parseAll();
    } catch (_) {
      node = null;
    }
    if (_cache.length > 2000) _cache.clear();
    return _cache[key] = node;
  }

  /// Names of the functions formulas can call.
  static Iterable<String> get functions => _functions.keys;

  /// Why [expression] can't be evaluated, such as `Unknown function "sun"`
  /// or `Expected ")" at 12`, or null when it parses.
  static String? errorOf(String expression) {
    try {
      _Parser(expression.trim()).parseAll();
      return null;
    } on FormatException catch (error) {
      final int? offset = error.offset;
      return offset == null || offset >= expression.trim().length
          ? error.message
          : '${error.message} at ${offset + 1}';
    } catch (error) {
      return error.toString();
    }
  }

  /// How to call each function, with an example, for editors to list.
  static const List<FormulaFunctionDoc> functionDocs = [
    FormulaFunctionDoc(
      'money',
      'money(value, symbol)',
      r'money(price) → $1,234.50',
    ),
    FormulaFunctionDoc(
      'fixed',
      'fixed(value, decimals)',
      'fixed(4.5, 2) → 4.50',
    ),
    FormulaFunctionDoc(
      'round',
      'round(value, decimals)',
      'round(4.567, 1) → 4.6',
    ),
    FormulaFunctionDoc('floor', 'floor(value)', 'floor(4.7) → 4'),
    FormulaFunctionDoc('ceil', 'ceil(value)', 'ceil(4.2) → 5'),
    FormulaFunctionDoc('abs', 'abs(value)', 'abs(-3) → 3'),
    FormulaFunctionDoc('min', 'min(a, b, …) or min(list)', 'min(3, 7) → 3'),
    FormulaFunctionDoc('max', 'max(a, b, …) or max(list)', 'max(3, 7) → 7'),
    FormulaFunctionDoc('sum', 'sum(list, field)', 'sum(cart, "price") → 24'),
    FormulaFunctionDoc(
      'count',
      'count(list, field, value)',
      'count(tasks, "done", true) → 2',
    ),
    FormulaFunctionDoc('length', 'length(text or list)', 'length(cart) → 3'),
    FormulaFunctionDoc(
      'if',
      'if(condition, then, else)',
      'if(qty > 1, "items", "item")',
    ),
    FormulaFunctionDoc(
      'plural',
      'plural(count, one, many)',
      'plural(2, "photo") → photos',
    ),
    FormulaFunctionDoc(
      'join',
      'join(list, separator, field)',
      'join(tags, " · ")',
    ),
    FormulaFunctionDoc('upper', 'upper(text)', 'upper("hi") → HI'),
    FormulaFunctionDoc('lower', 'lower(text)', 'lower("Hi") → hi'),
    FormulaFunctionDoc(
      'contains',
      'contains(text or list, value)',
      'contains(tags, "new") → true',
    ),
    FormulaFunctionDoc(
      'where',
      'where(list, field, value)',
      'where(tasks, "done", false)',
    ),
    FormulaFunctionDoc(
      'without',
      'without(list, other)',
      'without(all, picked)',
    ),
    FormulaFunctionDoc('number', 'number(value)', 'number("42") → 42'),
    FormulaFunctionDoc('text', 'text(value)', 'text(42) → "42"'),
    FormulaFunctionDoc(
      'isEmpty',
      'isEmpty(text or list)',
      'isEmpty(cart) → false',
    ),
    FormulaFunctionDoc(
      'isNotEmpty',
      'isNotEmpty(text or list)',
      'isNotEmpty(cart) → true',
    ),
  ];
}

/// How to call a formula function, for editors to list.
class FormulaFunctionDoc {
  /// The function's name, such as `money`.
  final String name;

  /// Its arguments, such as `money(value, symbol)`.
  final String signature;

  /// A call and its result.
  final String example;

  /// Creates a [FormulaFunctionDoc].
  const FormulaFunctionDoc(this.name, this.signature, this.example);
}

// ---------------------------------------------------------------------------
// Values
// ---------------------------------------------------------------------------

bool _truthy(Object? value) => switch (value) {
  null => false,
  bool() => value,
  num() => value != 0,
  String() => value.isNotEmpty && value.toLowerCase() != 'false',
  Iterable() => value.isNotEmpty,
  Map() => value.isNotEmpty,
  _ => true,
};

/// Reads [value] as a number: numbers as is, numeric text parsed, null as 0.
num? _toNum(Object? value) => switch (value) {
  null => 0,
  num() => value,
  bool() => value ? 1 : 0,
  String() => value.trim().isEmpty ? 0 : num.tryParse(value.trim()),
  _ => null,
};

num _num(Object? value) => _toNum(value) ?? double.nan;

/// Keeps whole results as ints so `2 * 3` prints "6".
num _tidy(num value) =>
    value is double && value.isFinite && value == value.roundToDouble()
    ? value.toInt()
    : value;

bool _looseEquals(Object? a, Object? b) {
  if (a == null || b == null) return a == b;
  final num? na = a is String ? num.tryParse(a) : _toNum(a);
  final num? nb = b is String ? num.tryParse(b) : _toNum(b);
  if ((a is num || b is num) && na != null && nb != null) return na == nb;
  if (a is bool || b is bool) return _truthy(a) == _truthy(b);
  return a.toString() == b.toString();
}

int _compare(Object? a, Object? b) {
  final num? na = a is String ? num.tryParse(a) : _toNum(a);
  final num? nb = b is String ? num.tryParse(b) : _toNum(b);
  if (na != null && nb != null) return na.compareTo(nb);
  return (a?.toString() ?? '').compareTo(b?.toString() ?? '');
}

Object? _member(Object? target, Object? key) {
  if (target == null) return null;
  if (target is List) {
    if (key == 'length') return target.length;
    if (key == 'first') return target.isEmpty ? null : target.first;
    if (key == 'last') return target.isEmpty ? null : target.last;
    final num? index = _toNum(key);
    if (index == null) return null;
    final int i = index.toInt();
    return i >= 0 && i < target.length ? target[i] : null;
  }
  if (target is Map) {
    if (target.containsKey(key)) return target[key];
    if (key == 'length') return target.length;
    return target[key.toString()];
  }
  if (target is String) {
    if (key == 'length') return target.length;
    final num? index = _toNum(key);
    if (index == null) return null;
    final int i = index.toInt();
    return i >= 0 && i < target.length ? target[i] : null;
  }
  return null;
}

String _fixed(Object? value, Object? digits) =>
    _num(value).toStringAsFixed(_num(digits ?? 2).toInt().clamp(0, 20));

String _money(Object? value, Object? symbol) {
  final num amount = _num(value);
  if (amount.isNaN) return '';
  final String sign = amount < 0 ? '-' : '';
  final String text = amount.abs().toStringAsFixed(2);
  final int dot = text.indexOf('.');
  final String whole = text
      .substring(0, dot)
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  return '$sign${symbol ?? r'$'}$whole${text.substring(dot)}';
}

num _round(Object? value, Object? digits) {
  final num v = _num(value);
  final int d = _num(digits ?? 0).toInt();
  if (d <= 0) return v.round();
  final num factor = math.pow(10, d);
  return _tidy((v * factor).round() / factor);
}

/// Values of [list], or of each item's [field] when given.
Iterable<Object?> _values(Object? list, Object? field) {
  if (list is! Iterable) return const [];
  if (field == null) return list;
  return list.map((item) => _member(item, field));
}

typedef _Function = Object? Function(List<Object?> args);

Object? _arg(List<Object?> args, int index) =>
    index < args.length ? args[index] : null;

final Map<String, _Function> _functions = {
  'money': (a) => _money(_arg(a, 0), _arg(a, 1)),
  'fixed': (a) => _fixed(_arg(a, 0), _arg(a, 1)),
  'round': (a) => _round(_arg(a, 0), _arg(a, 1)),
  'floor': (a) => _num(_arg(a, 0)).floor(),
  'ceil': (a) => _num(_arg(a, 0)).ceil(),
  'abs': (a) => _num(_arg(a, 0)).abs(),
  'min': (a) => (a.length == 1 && a.first is Iterable ? a.first as Iterable : a)
      .map(_num)
      .reduce(math.min),
  'max': (a) => (a.length == 1 && a.first is Iterable ? a.first as Iterable : a)
      .map(_num)
      .reduce(math.max),
  'sum': (a) => _tidy(
    _values(_arg(a, 0), _arg(a, 1)).fold<num>(0, (s, v) => s + _num(v)),
  ),
  'count': (a) {
    if (a.length < 3) return _values(_arg(a, 0), null).length;
    return _values(
      _arg(a, 0),
      _arg(a, 1),
    ).where((v) => _looseEquals(v, _arg(a, 2))).length;
  },
  'length': (a) => switch (_arg(a, 0)) {
    final String s => s.length,
    final Iterable l => l.length,
    final Map m => m.length,
    _ => 0,
  },
  'if': (a) => _truthy(_arg(a, 0)) ? _arg(a, 1) : _arg(a, 2),
  'plural': (a) =>
      _num(_arg(a, 0)) == 1 ? _arg(a, 1) : (_arg(a, 2) ?? '${_arg(a, 1)}s'),
  'join': (a) => _values(_arg(a, 0), _arg(a, 2))
      .map(FormulaEvaluator.stringify)
      .where((s) => s.isNotEmpty)
      .join((_arg(a, 1) ?? ', ').toString()),
  'upper': (a) => FormulaEvaluator.stringify(_arg(a, 0)).toUpperCase(),
  'lower': (a) => FormulaEvaluator.stringify(_arg(a, 0)).toLowerCase(),
  'contains': (a) => switch (_arg(a, 0)) {
    final String s => s.contains(FormulaEvaluator.stringify(_arg(a, 1))),
    final Iterable l => l.any((v) => _looseEquals(v, _arg(a, 1))),
    final Map m => m.containsKey(_arg(a, 1)),
    _ => false,
  },
  'where': (a) => [
    for (final item in _values(_arg(a, 0), null))
      if (a.length < 3
          ? _truthy(_member(item, _arg(a, 1)))
          : _looseEquals(_member(item, _arg(a, 1)), _arg(a, 2)))
        item,
  ],
  'without': (a) => [
    for (final item in _values(_arg(a, 0), null))
      if (!_values(_arg(a, 1), null).any((other) => _looseEquals(item, other)))
        item,
  ],
  'number': (a) => _toNum(_arg(a, 0)),
  'text': (a) => FormulaEvaluator.stringify(_arg(a, 0)),
  'isEmpty': (a) => !_truthy(_functions['length']!(a)),
  'isNotEmpty': (a) => _truthy(_functions['length']!(a)),
};

// ---------------------------------------------------------------------------
// Syntax tree
// ---------------------------------------------------------------------------

sealed class _Node {
  const _Node();

  Object? eval(FormulaPathResolver resolve);

  void collectPaths(Set<String> paths) {}
}

class _Literal extends _Node {
  final Object? value;

  const _Literal(this.value);

  @override
  Object? eval(FormulaPathResolver resolve) => value;
}

class _Path extends _Node {
  final String path;

  const _Path(this.path);

  @override
  Object? eval(FormulaPathResolver resolve) => resolve(path);

  @override
  void collectPaths(Set<String> paths) => paths.add(path);
}

class _ListLiteral extends _Node {
  final List<_Node> items;

  const _ListLiteral(this.items);

  @override
  Object? eval(FormulaPathResolver resolve) => [
    for (final item in items) item.eval(resolve),
  ];

  @override
  void collectPaths(Set<String> paths) {
    for (final item in items) {
      item.collectPaths(paths);
    }
  }
}

class _Member extends _Node {
  final _Node target;
  final _Node key;

  const _Member(this.target, this.key);

  @override
  Object? eval(FormulaPathResolver resolve) =>
      _member(target.eval(resolve), key.eval(resolve));

  @override
  void collectPaths(Set<String> paths) {
    target.collectPaths(paths);
    key.collectPaths(paths);
  }
}

class _Call extends _Node {
  final String name;
  final List<_Node> args;

  const _Call(this.name, this.args);

  @override
  Object? eval(FormulaPathResolver resolve) {
    // `if` only evaluates the branch it returns.
    if (name == 'if') {
      _Node? arg(int i) => i < args.length ? args[i] : null;
      return _truthy(arg(0)?.eval(resolve))
          ? arg(1)?.eval(resolve)
          : arg(2)?.eval(resolve);
    }
    return _functions[name]!([for (final arg in args) arg.eval(resolve)]);
  }

  @override
  void collectPaths(Set<String> paths) {
    for (final arg in args) {
      arg.collectPaths(paths);
    }
  }
}

class _Unary extends _Node {
  final String op;
  final _Node operand;

  const _Unary(this.op, this.operand);

  @override
  Object? eval(FormulaPathResolver resolve) {
    final Object? value = operand.eval(resolve);
    return op == '!' ? !_truthy(value) : _tidy(-_num(value));
  }

  @override
  void collectPaths(Set<String> paths) => operand.collectPaths(paths);
}

class _Binary extends _Node {
  final String op;
  final _Node left;
  final _Node right;

  const _Binary(this.op, this.left, this.right);

  @override
  Object? eval(FormulaPathResolver resolve) {
    final Object? a = left.eval(resolve);
    if (op == '&&') return _truthy(a) ? right.eval(resolve) : a;
    if (op == '||') return _truthy(a) ? a : right.eval(resolve);
    final Object? b = right.eval(resolve);
    switch (op) {
      case '+':
        final num? na = a is String ? null : _toNum(a);
        final num? nb = b is String ? null : _toNum(b);
        if (na != null && nb != null) return _tidy(na + nb);
        return FormulaEvaluator.stringify(a) + FormulaEvaluator.stringify(b);
      case '-':
        return _tidy(_num(a) - _num(b));
      case '*':
        return _tidy(_num(a) * _num(b));
      case '/':
        final num divisor = _num(b);
        return divisor == 0 ? null : _tidy(_num(a) / divisor);
      case '%':
        final num divisor = _num(b);
        return divisor == 0 ? null : _tidy(_num(a) % divisor);
      case '==':
        return _looseEquals(a, b);
      case '!=':
        return !_looseEquals(a, b);
      case '<':
        return _compare(a, b) < 0;
      case '<=':
        return _compare(a, b) <= 0;
      case '>':
        return _compare(a, b) > 0;
      case '>=':
        return _compare(a, b) >= 0;
    }
    return null;
  }

  @override
  void collectPaths(Set<String> paths) {
    left.collectPaths(paths);
    right.collectPaths(paths);
  }
}

class _Ternary extends _Node {
  final _Node condition;
  final _Node then;
  final _Node otherwise;

  const _Ternary(this.condition, this.then, this.otherwise);

  @override
  Object? eval(FormulaPathResolver resolve) => _truthy(condition.eval(resolve))
      ? then.eval(resolve)
      : otherwise.eval(resolve);

  @override
  void collectPaths(Set<String> paths) {
    condition.collectPaths(paths);
    then.collectPaths(paths);
    otherwise.collectPaths(paths);
  }
}

// ---------------------------------------------------------------------------
// Parser
// ---------------------------------------------------------------------------

class _Parser {
  final String source;
  int pos = 0;

  _Parser(this.source);

  static final RegExp _number = RegExp(r'\d+(\.\d+)?|\.\d+');
  static final RegExp _identifier = RegExp(r'[a-zA-Z_][a-zA-Z0-9_]*');

  _Node parseAll() {
    final _Node node = _ternary();
    _skip();
    if (pos != source.length) {
      throw FormatException('Unexpected "${source[pos]}"', source, pos);
    }
    return node;
  }

  void _skip() {
    while (pos < source.length && source[pos].trim().isEmpty) {
      pos++;
    }
  }

  bool _eat(String token) {
    _skip();
    if (!source.startsWith(token, pos)) return false;
    // Don't read `=` of `==` or `<=` as a separate token.
    if ((token == '<' || token == '>' || token == '!') &&
        source.startsWith('=', pos + 1)) {
      return false;
    }
    pos += token.length;
    return true;
  }

  void _expect(String token) {
    if (!_eat(token)) throw FormatException('Expected "$token"', source, pos);
  }

  _Node _ternary() {
    final _Node condition = _or();
    if (!_eat('?')) return condition;
    final _Node then = _ternary();
    _expect(':');
    return _Ternary(condition, then, _ternary());
  }

  _Node _or() {
    _Node node = _and();
    while (_eat('||')) {
      node = _Binary('||', node, _and());
    }
    return node;
  }

  _Node _and() {
    _Node node = _equality();
    while (_eat('&&')) {
      node = _Binary('&&', node, _equality());
    }
    return node;
  }

  _Node _equality() {
    _Node node = _comparison();
    while (true) {
      if (_eat('==')) {
        node = _Binary('==', node, _comparison());
      } else if (_eat('!=')) {
        node = _Binary('!=', node, _comparison());
      } else {
        return node;
      }
    }
  }

  _Node _comparison() {
    _Node node = _additive();
    while (true) {
      final String? op = ['<=', '>=', '<', '>'].where(_eat).firstOrNull;
      if (op == null) return node;
      node = _Binary(op, node, _additive());
    }
  }

  _Node _additive() {
    _Node node = _multiplicative();
    while (true) {
      final String? op = ['+', '-'].where(_eat).firstOrNull;
      if (op == null) return node;
      node = _Binary(op, node, _multiplicative());
    }
  }

  _Node _multiplicative() {
    _Node node = _unary();
    while (true) {
      final String? op = ['*', '/', '%'].where(_eat).firstOrNull;
      if (op == null) return node;
      node = _Binary(op, node, _unary());
    }
  }

  _Node _unary() {
    if (_eat('!')) return _Unary('!', _unary());
    if (_eat('-')) return _Unary('-', _unary());
    return _postfix(_primary());
  }

  _Node _postfix(_Node node) {
    while (true) {
      if (_eat('[')) {
        node = _Member(node, _ternary());
        _expect(']');
      } else if (_eat('.')) {
        final Match? name = _identifier.matchAsPrefix(source, pos);
        if (name == null) throw FormatException('Expected a name', source, pos);
        pos = name.end;
        node = _Member(node, _Literal(name[0]));
      } else {
        return node;
      }
    }
  }

  _Node _primary() {
    _skip();
    if (pos >= source.length) {
      throw FormatException('Unexpected end', source, pos);
    }
    final String char = source[pos];

    if (char == '(') {
      pos++;
      final _Node node = _ternary();
      _expect(')');
      return node;
    }

    if (char == '[') {
      pos++;
      final List<_Node> items = [];
      if (!_eat(']')) {
        do {
          items.add(_ternary());
        } while (_eat(','));
        _expect(']');
      }
      return _ListLiteral(items);
    }

    if (char == "'" || char == '"') {
      final int end = source.indexOf(char, pos + 1);
      if (end < 0) throw FormatException('Unclosed text', source, pos);
      final String text = source.substring(pos + 1, end);
      pos = end + 1;
      return _Literal(text);
    }

    final Match? number = _number.matchAsPrefix(source, pos);
    if (number != null) {
      pos = number.end;
      return _Literal(num.parse(number[0]!));
    }

    final Match? identifier = _identifier.matchAsPrefix(source, pos);
    if (identifier == null) {
      throw FormatException('Unexpected "$char"', source, pos);
    }
    pos = identifier.end;
    final String name = identifier[0]!;

    switch (name) {
      case 'true':
        return const _Literal(true);
      case 'false':
        return const _Literal(false);
      case 'null':
        return const _Literal(null);
    }

    if (_eat('(')) {
      if (!_functions.containsKey(name)) {
        throw FormatException('Unknown function "$name"', source, pos);
      }
      final List<_Node> args = [];
      if (!_eat(')')) {
        do {
          args.add(_ternary());
        } while (_eat(','));
        _expect(')');
      }
      return _Call(name, args);
    }

    // A variable path: name followed by `.key` and `[digits]` parts, read as
    // one path so accessors like `.length` and `.initial` work as in `${}`.
    final StringBuffer path = StringBuffer(name);
    while (true) {
      final Match? part = RegExp(r'\.[a-zA-Z][a-zA-Z0-9_]*|\[\d+\]')
          .matchAsPrefix(source, pos);
      if (part == null) break;
      path.write(part[0]);
      pos = part.end;
    }
    return _Path(path.toString());
  }
}
