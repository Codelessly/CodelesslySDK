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
///    length, if, plural, join, upper, lower, trim, contains, startsWith,
///    endsWith, where, without, number, text, isEmpty and isNotEmpty. See
///    [FormulaEvaluator.functions].
///  - list functions that take a predicate or key: filter, where, count,
///    find, any, all, map, sortBy, unique, sum and join. The predicate is a
///    lambda, `item => expression`, or a field name, optionally with a value
///    to match, e.g. `filter(tasks, t => contains(lower(t.title), q))`,
///    `filter(tasks, 'done')` or `count(tasks, 'done', false)`. A lambda's
///    parameter is read like a variable inside its body (`t.title`,
///    `t.tags[0]`, `t.tags.length`) and hides a variable of the same name;
///    the body can read every other variable. Lambdas are only allowed as
///    function arguments.
///  - series and text helpers: range, interpolate, runs, minBy, maxBy, obj,
///    slice, substring, replace and split.
///  - date functions: now, today, wallTime, parseDate, formatDate, addMinutes, addHours,
///    addDays, addMonths, diffMinutes, diffHours, diffDays, year, month, day,
///    hour, minute and weekday. Dates are ISO 8601 text such as
///    `2026-10-21T14:30:00.000`; a date argument can also be epoch
///    milliseconds or a Firestore timestamp.
///  - date-aware comparisons: `== != < <= > >=` compare as dates when one
///    side is a date (ISO 8601 text such as `2026-10-21` or
///    `2026-10-21T09:00:00Z`, a DateTime or a timestamp) and the other reads
///    as one, so `t.due <= today()` and `t.due == today()` work even when
///    `t.due` is a date without a time or a Firestore timestamp. A missing
///    date is neither before nor after a date.
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

  /// Formats [date] (a DateTime, an ISO string, epoch milliseconds or a
  /// timestamp) with a date [pattern] as the `formatDate` formula function
  /// does, e.g. `h:mm a`. Returns null when [date] isn't a date.
  static String? formatDate(Object? date, [String? pattern]) =>
      _formatDate(date, pattern);

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
    FormulaFunctionDoc(
      'sum',
      'sum(list, field or item => value)',
      'sum(cart, i => i.price * i.qty) → 24',
    ),
    FormulaFunctionDoc(
      'count',
      'count(list, item => condition) or count(list, field, value)',
      'count(tasks, t => !t.done) → 2',
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
      'join(list, separator, field or item => value)',
      'join(tags, " · ")',
    ),
    FormulaFunctionDoc('upper', 'upper(text)', 'upper("hi") → HI'),
    FormulaFunctionDoc('lower', 'lower(text)', 'lower("Hi") → hi'),
    FormulaFunctionDoc('trim', 'trim(text)', 'trim("  hi ") → hi'),
    FormulaFunctionDoc(
      'contains',
      'contains(text or list, value)',
      'contains(lower(title), lower(search)) → true',
    ),
    FormulaFunctionDoc(
      'startsWith',
      'startsWith(text, prefix)',
      'startsWith("Buy milk", "Buy") → true',
    ),
    FormulaFunctionDoc(
      'endsWith',
      'endsWith(text, suffix)',
      'endsWith("photo.png", ".png") → true',
    ),
    FormulaFunctionDoc(
      'filter',
      'filter(list, item => condition) or filter(list, field, value)',
      'filter(tasks, t => contains(lower(t.title), lower(search)))',
    ),
    FormulaFunctionDoc(
      'where',
      'where(list, field, value) or where(list, item => condition)',
      'where(tasks, "done", false)',
    ),
    FormulaFunctionDoc(
      'find',
      'find(list, item => condition) or find(list, field, value)',
      'find(users, u => u.id == userId)',
    ),
    FormulaFunctionDoc(
      'any',
      'any(list, item => condition) or any(list, field, value)',
      'any(tasks, t => t.due < today()) → true',
    ),
    FormulaFunctionDoc(
      'all',
      'all(list, item => condition) or all(list, field, value)',
      'all(tasks, "done") → false',
    ),
    FormulaFunctionDoc(
      'map',
      'map(list, field or item => value)',
      'map(cart, i => i.price * i.qty) → [8, 16]',
    ),
    FormulaFunctionDoc(
      'sortBy',
      'sortBy(list, field or item => key, "desc")',
      'sortBy(tasks, "due") (missing keys last)',
    ),
    FormulaFunctionDoc(
      'unique',
      'unique(list, field or item => key)',
      'unique(tags) or unique(tasks, "category")',
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
    FormulaFunctionDoc(
      'now',
      'now(utcOffset?)',
      'now() → 2026-10-21T14:30:00.000, now("-07:00") at UTC−7',
    ),
    FormulaFunctionDoc(
      'today',
      'today(utcOffset?)',
      'today() → 2026-10-21T00:00:00.000',
    ),
    FormulaFunctionDoc(
      'wallTime',
      'wallTime(dateWithOffset)',
      'wallTime("2026-10-22T07:25:17-07:00") → 2026-10-22T07:25:17.000',
    ),
    FormulaFunctionDoc(
      'substring',
      'substring(text, start, end?)',
      'substring("2026-10-22 02:58", 0, 10) → 2026-10-22',
    ),
    FormulaFunctionDoc(
      'replace',
      'replace(text, from, to)',
      'replace("a-b", "-", " ") → a b',
    ),
    FormulaFunctionDoc('split', 'split(text, separator)', 'split("a,b", ",")'),
    FormulaFunctionDoc(
      'slice',
      'slice(list, start, end?)',
      'slice(items, 0, 3) or slice(items, -2)',
    ),
    FormulaFunctionDoc(
      'range',
      'range(start, end, step) (dates: step in minutes)',
      'range(0, 6, 2) → [0, 2, 4, 6]',
    ),
    FormulaFunctionDoc(
      'interpolate',
      'interpolate(points, xField, yField, x)',
      'interpolate(tides, "t", "v", now())',
    ),
    FormulaFunctionDoc(
      'runs',
      'runs(list, item => condition)',
      'runs(steps, s => s.h <= 1) → [{first, last, items, count}]',
    ),
    FormulaFunctionDoc(
      'minBy',
      'minBy(list, field or item => key)',
      'minBy(lows, "v")',
    ),
    FormulaFunctionDoc(
      'maxBy',
      'maxBy(list, field or item => key)',
      'maxBy(highs, "v")',
    ),
    FormulaFunctionDoc(
      'obj',
      'obj(key, value, …)',
      'obj("from", start, "to", end) → {from, to}',
    ),
    FormulaFunctionDoc(
      'parseDate',
      'parseDate(text or millis)',
      'parseDate("2026-10-21") → 2026-10-21T00:00:00.000',
    ),
    FormulaFunctionDoc(
      'formatDate',
      'formatDate(date, pattern)',
      'formatDate(now(), "EEE, MMM d · h:mm a") → Wed, Oct 21 · 2:30 PM',
    ),
    FormulaFunctionDoc(
      'addMinutes',
      'addMinutes(date, minutes)',
      'addMinutes(start, 90)',
    ),
    FormulaFunctionDoc(
      'addHours',
      'addHours(date, hours)',
      'addHours(now(), 2)',
    ),
    FormulaFunctionDoc('addDays', 'addDays(date, days)', 'addDays(today(), 7)'),
    FormulaFunctionDoc(
      'addMonths',
      'addMonths(date, months)',
      'addMonths("2026-01-31", 1) → 2026-02-28T00:00:00.000',
    ),
    FormulaFunctionDoc(
      'diffMinutes',
      'diffMinutes(from, to)',
      'diffMinutes(start, end) → 45',
    ),
    FormulaFunctionDoc(
      'diffHours',
      'diffHours(from, to)',
      'diffHours(start, end) → 3',
    ),
    FormulaFunctionDoc(
      'diffDays',
      'diffDays(from, to)',
      'diffDays(today(), dueDate) → 5',
    ),
    FormulaFunctionDoc('year', 'year(date)', 'year("2026-10-21") → 2026'),
    FormulaFunctionDoc('month', 'month(date)', 'month("2026-10-21") → 10'),
    FormulaFunctionDoc('day', 'day(date)', 'day("2026-10-21") → 21'),
    FormulaFunctionDoc('hour', 'hour(date)', 'hour("2026-10-21T14:30") → 14'),
    FormulaFunctionDoc(
      'minute',
      'minute(date)',
      'minute("2026-10-21T14:30") → 30',
    ),
    FormulaFunctionDoc(
      'weekday',
      'weekday(date)',
      'weekday("2026-10-21") → 3 (Monday is 1)',
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
  if (_asDates(a, b) case (final DateTime da, final DateTime db)) {
    return da.isAtSameMomentAs(db);
  }
  final num? na = a is String ? num.tryParse(a) : _toNum(a);
  final num? nb = b is String ? num.tryParse(b) : _toNum(b);
  if ((a is num || b is num) && na != null && nb != null) return na == nb;
  if (a is bool || b is bool) return _truthy(a) == _truthy(b);
  return a.toString() == b.toString();
}

/// Orders [a] and [b]: as dates when [_asDates] reads them as dates, as
/// numbers when both read as numbers, else as text. Null when they can't be
/// ordered: a missing value against a date.
int? _compare(Object? a, Object? b) {
  if (_asDates(a, b) case (final DateTime da, final DateTime db)) {
    return da.compareTo(db);
  }
  if ((a == null && _isDateLike(b)) || (b == null && _isDateLike(a))) {
    return null;
  }
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

/// Values of [list], or of each item's [selector] when given: a field name
/// such as `'price'` or `'author.name'`, or a lambda such as `t => t.price`.
Iterable<Object?> _values(Object? list, Object? selector) {
  if (list is! Iterable) return const [];
  if (selector == null) return list;
  return list.map((item) => _select(item, selector));
}

/// [item]'s value for [selector]: the item itself when null, the lambda's
/// result for a lambda, else the field [selector] names. A field name with
/// dots, such as `author.name`, reads nested fields.
Object? _select(Object? item, Object? selector) {
  if (selector == null) return item;
  if (selector is _Closure) return selector(item);
  final Object? value = _member(item, selector);
  if (value != null || selector is! String || !selector.contains('.')) {
    return value;
  }
  return selector.split('.').fold(item, _member);
}

/// Whether [item] matches a predicate given as function arguments [rest]:
/// `(lambda)` or `(field)` match when truthy, `(lambda or field, value)`
/// when the selected value equals value. No predicate matches truthy items.
bool _matches(Object? item, List<Object?> rest) => rest.length < 2
    ? _truthy(_select(item, _arg(rest, 0)))
    : _looseEquals(_select(item, rest[0]), rest[1]);

/// Items of `args[0]` that match the predicate in the rest of [args].
Iterable<Object?> _matching(List<Object?> args) {
  final List<Object?> rest = args.skip(1).toList();
  return _values(_arg(args, 0), null).where((item) => _matches(item, rest));
}

/// Items of `args[0]` sorted by the key `args[1]`, descending when `args[2]`
/// is `'desc'`. Equal keys keep their order and missing keys go last.
List<Object?> _sortBy(List<Object?> args) {
  final List<Object?> items = _values(_arg(args, 0), null).toList();
  final Object? selector = _arg(args, 1);
  final bool descending = switch (_arg(args, 2)) {
    final String order => order.trim().toLowerCase().startsWith('desc'),
    _ => false,
  };
  final List<(int, Object?, Object?)> keyed = [
    for (int i = 0; i < items.length; i++)
      (i, items[i], _select(items[i], selector)),
  ];
  keyed.sort((x, y) {
    final bool xMissing = x.$3 == null || x.$3 == '';
    final bool yMissing = y.$3 == null || y.$3 == '';
    if (xMissing || yMissing) {
      return xMissing == yMissing ? x.$1 - y.$1 : (xMissing ? 1 : -1);
    }
    final int order = _compare(x.$3, y.$3) ?? 0;
    if (order != 0) return descending ? -order : order;
    return x.$1 - y.$1;
  });
  return [for (final entry in keyed) entry.$2];
}

/// Items of `args[0]` without repeats, keeping the first of each; repeats
/// are judged by the key `args[1]` when given.
List<Object?> _unique(List<Object?> args) {
  final List<Object?> keys = [];
  final List<Object?> items = [];
  for (final item in _values(_arg(args, 0), null)) {
    final Object? key = _select(item, _arg(args, 1));
    if (keys.any((seen) => _looseEquals(seen, key))) continue;
    keys.add(key);
    items.add(item);
  }
  return items;
}

/// A lambda such as `t => t.price`, ready to call with an item.
class _Closure {
  final String param;
  final _Node body;
  final FormulaPathResolver outer;

  const _Closure(this.param, this.body, this.outer);

  static final RegExp _part = RegExp(r'\.([a-zA-Z_][a-zA-Z0-9_]*)|\[(\d+)\]');

  Object? call(Object? value) => body.eval((path) {
    if (path == param) return value;
    if (path.startsWith(param) &&
        (path.startsWith('.', param.length) ||
            path.startsWith('[', param.length))) {
      Object? result = value;
      for (final Match part in _part.allMatches(path, param.length)) {
        result = _member(result, part[1] ?? int.parse(part[2]!));
      }
      return result;
    }
    return outer(path);
  });

  @override
  String toString() => '';
}

// ---------------------------------------------------------------------------
// Dates
// ---------------------------------------------------------------------------

/// Reads [value] as a date: a [DateTime], ISO 8601 text, epoch milliseconds,
/// a Firestore timestamp (anything with `toDate()`), or a timestamp written
/// as JSON (`{seconds, nanoseconds}` or `{_seconds, _nanoseconds}`).
DateTime? _toDate(Object? value) {
  switch (value) {
    case null:
      return null;
    case DateTime():
      return value;
    case num():
      if (!value.isFinite) return null;
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    case String():
      final String text = value.trim();
      if (text.isEmpty) return null;
      final int? millis = int.tryParse(text);
      if (millis != null && text.length > 8) {
        return DateTime.fromMillisecondsSinceEpoch(millis);
      }
      return DateTime.tryParse(text);
    case Map():
      final Object? seconds = value['seconds'] ?? value['_seconds'];
      if (seconds is! num) return null;
      final Object? nanos = value['nanoseconds'] ?? value['_nanoseconds'];
      return DateTime.fromMicrosecondsSinceEpoch(
        (seconds * 1000000).toInt() + (nanos is num ? nanos ~/ 1000 : 0),
      );
  }
  try {
    final Object? date = (value as dynamic).toDate();
    return date is DateTime ? date : null;
  } catch (_) {
    return null;
  }
}

/// ISO 8601 dates and date-times, such as `2026-10-21`,
/// `2026-10-21T14:30:00.000` or `2026-10-21 14:30Z`.
final RegExp _isoDate = RegExp(
  r'^\d{4}-\d{2}-\d{2}'
  r'(?:[T ]\d{2}:\d{2}(?::\d{2}(?:[.,]\d+)?)?\s*(?:Z|[+-]\d{2}(?::?\d{2})?)?)?$',
);

/// Whether [value] is a date in itself: ISO 8601 text, a [DateTime] or a
/// timestamp. Numbers aren't: they only read as dates against a date.
bool _isDateLike(Object? value) {
  switch (value) {
    case null || num() || bool() || Iterable():
      return false;
    case DateTime():
      return true;
    case String():
      return _isoDate.hasMatch(value.trim());
    case Map():
      return (value.containsKey('seconds') &&
              value.containsKey('nanoseconds')) ||
          (value.containsKey('_seconds') && value.containsKey('_nanoseconds'));
  }
  try {
    return (value as dynamic).toDate() is DateTime;
  } catch (_) {
    return false;
  }
}

/// [a] and [b] as dates when one is a date (see [_isDateLike]) and the other
/// reads as one too, else null.
(DateTime, DateTime)? _asDates(Object? a, Object? b) {
  if (a == null || b == null) return null;
  if (a is num && b is num) return null;
  if (!_isDateLike(a) && !_isDateLike(b)) return null;
  final DateTime? da = _toDate(a);
  final DateTime? db = _toDate(b);
  if (da == null || db == null) return null;
  return (da, db);
}

/// Writes [date] as ISO 8601 text, the form formulas pass dates around in.
String? _dateText(DateTime? date) => date?.toIso8601String();

/// [date] moved by calendar amounts, keeping its wall-clock time across
/// daylight saving changes. Months clamp to the last day of the month, so
/// Jan 31 plus one month is Feb 28 (or 29).
DateTime? _shift(
  Object? value, {
  int months = 0,
  int days = 0,
  int hours = 0,
  int minutes = 0,
}) {
  final DateTime? date = _toDate(value);
  if (date == null) return null;
  int day = date.day;
  if (months != 0) {
    final int lastDay = DateTime.utc(date.year, date.month + months + 1, 0).day;
    if (day > lastDay) day = lastDay;
  }
  final DateTime Function(int, int, int, int, int, int, int, int) make =
      date.isUtc ? DateTime.utc : DateTime.new;
  return make(
    date.year,
    date.month + months,
    day + days,
    date.hour + hours,
    date.minute + minutes,
    date.second,
    date.millisecond,
    date.microsecond,
  );
}

/// Whole calendar days from [from] to [to], ignoring the time of day.
int? _diffDays(Object? from, Object? to) {
  final DateTime? a = _toDate(from);
  final DateTime? b = _toDate(to);
  if (a == null || b == null) return null;
  return DateTime.utc(
    b.year,
    b.month,
    b.day,
  ).difference(DateTime.utc(a.year, a.month, a.day)).inDays;
}

Duration? _difference(Object? from, Object? to) {
  final DateTime? a = _toDate(from);
  final DateTime? b = _toDate(to);
  if (a == null || b == null) return null;
  return b.difference(a);
}

int _intArg(Object? value) {
  final num n = _num(value);
  return n.isFinite ? n.toInt() : 0;
}

const List<String> _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const List<String> _weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// Formats [value] with a date [pattern] using the common ICU letters:
/// `yyyy` `yy` year, `M` `MM` `MMM` `MMMM` month, `d` `dd` day, `EEE` `EEEE`
/// weekday, `H` `HH` hour (0-23), `h` `hh` hour (1-12), `m` `mm` minute,
/// `s` `ss` second, `a` AM/PM. Text in single quotes is kept as is (`''` is
/// a quote) and any other character is copied. English names are used.
String? _formatDate(Object? value, Object? pattern) {
  final DateTime? date = _toDate(value);
  if (date == null) return null;
  final String format = pattern == null
      ? 'yyyy-MM-dd'
      : FormulaEvaluator.stringify(pattern);
  final StringBuffer out = StringBuffer();
  String pad(int n, int width) => n.toString().padLeft(width, '0');
  int i = 0;
  while (i < format.length) {
    final String char = format[i];
    if (char == "'") {
      final int end = format.indexOf("'", i + 1);
      if (end == i + 1) {
        out.write("'");
        i += 2;
        continue;
      }
      out.write(format.substring(i + 1, end < 0 ? format.length : end));
      i = end < 0 ? format.length : end + 1;
      continue;
    }
    int count = 1;
    while (i + count < format.length && format[i + count] == char) {
      count++;
    }
    final int hour12 = date.hour % 12 == 0 ? 12 : date.hour % 12;
    out.write(switch (char) {
      'y' when count == 2 => pad(date.year % 100, 2),
      'y' => pad(date.year, count),
      'M' when count >= 4 => _monthNames[date.month - 1],
      'M' when count == 3 => _monthNames[date.month - 1].substring(0, 3),
      'M' => pad(date.month, count),
      'd' => pad(date.day, count),
      'E' when count >= 4 => _weekdayNames[date.weekday - 1],
      'E' => _weekdayNames[date.weekday - 1].substring(0, 3),
      'H' => pad(date.hour, count),
      'h' => pad(hour12, count),
      'm' => pad(date.minute, count),
      's' => pad(date.second, count),
      'a' => date.hour < 12 ? 'AM' : 'PM',
      _ => char * count,
    });
    i += count;
  }
  return out.toString();
}

// ---------------------------------------------------------------------------
// Series, text and object helpers
// ---------------------------------------------------------------------------

/// The most items [range] returns, so a typo can't build a huge list.
const int _maxRange = 10000;

/// Numbers from [start] through [end] by [step], or, when [start] is a date,
/// dates from [start] through [end] every [step] minutes (default 1).
List<Object?> _range(List<Object?> args) {
  final Object? start = _arg(args, 0), end = _arg(args, 1);
  if (_isDateLike(start)) {
    final DateTime? from = _toDate(start), to = _toDate(end);
    final num step = _num(_arg(args, 2) ?? 1);
    if (from == null || to == null || !(step > 0)) return const [];
    final Duration delta = Duration(microseconds: (step * 60e6).round());
    return [
      for (DateTime t = from; !t.isAfter(to); t = t.add(delta)) _dateText(t),
    ].take(_maxRange).toList();
  }
  final num from = _num(start), to = _num(end);
  final num step = _num(_arg(args, 2) ?? 1);
  if (!from.isFinite || !to.isFinite || step == 0 || !step.isFinite) {
    return const [];
  }
  final List<Object?> out = [];
  for (num v = from; step > 0 ? v <= to + 1e-9 : v >= to - 1e-9; v += step) {
    out.add(_tidy(v));
    if (out.length >= _maxRange) break;
  }
  return out;
}

/// A point's x as a number: dates as epoch milliseconds.
num? _xValue(Object? value) {
  if (_isDateLike(value)) return _toDate(value)?.millisecondsSinceEpoch;
  final num? n = value is String ? num.tryParse(value.trim()) : _toNum(value);
  return n != null && n.isFinite ? n : null;
}

/// The y of the series [list] at [x], interpolated linearly between the two
/// items whose [xField] values surround it. Items must be sorted by x. Null
/// outside the series.
num? _interpolate(List<Object?> args) {
  final Object? list = _arg(args, 0);
  final Object? xField = _arg(args, 1), yField = _arg(args, 2);
  final num? x = _xValue(_arg(args, 3));
  if (list is! List || list.isEmpty || x == null) return null;
  num? xOf(int i) => _xValue(_select(list[i], xField));
  num? yOf(int i) {
    final Object? y = _select(list[i], yField);
    return y is String ? num.tryParse(y.trim()) : _toNum(y);
  }

  int lo = 0, hi = list.length - 1;
  final num? first = xOf(lo), last = xOf(hi);
  if (first == null || last == null || x < first || x > last) return null;
  while (hi - lo > 1) {
    final int mid = (lo + hi) >> 1;
    final num? m = xOf(mid);
    if (m == null) return null;
    if (m <= x) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  final num? x0 = xOf(lo), x1 = xOf(hi), y0 = yOf(lo), y1 = yOf(hi);
  if (x0 == null || x1 == null || y0 == null || y1 == null) return null;
  if (x1 == x0) return y0;
  return y0 + (y1 - y0) * (x - x0) / (x1 - x0);
}

/// Runs of consecutive items of `args[0]` that match the predicate in the
/// rest of [args], each as `{first, last, items, count}`.
List<Object?> _runs(List<Object?> args) {
  final List<Object?> rest = args.skip(1).toList();
  final List<Object?> out = [];
  List<Object?> current = [];
  void close() {
    if (current.isEmpty) return;
    out.add({
      'first': current.first,
      'last': current.last,
      'items': current,
      'count': current.length,
    });
    current = [];
  }

  for (final Object? item in _values(_arg(args, 0), null)) {
    if (_matches(item, rest)) {
      current.add(item);
    } else {
      close();
    }
  }
  close();
  return out;
}

/// The item of `args[0]` with the smallest ([max] false) or largest key
/// `args[1]` (a field or lambda). Items without a key are skipped.
Object? _extremeBy(List<Object?> args, {required bool max}) {
  Object? best;
  int? bestKey;
  Object? bestValue;
  for (final Object? item in _values(_arg(args, 0), null)) {
    final Object? key = _select(item, _arg(args, 1));
    if (key == null) continue;
    if (bestKey == null) {
      best = item;
      bestValue = key;
      bestKey = 0;
      continue;
    }
    final int? order = _compare(key, bestValue);
    if (order != null && (max ? order > 0 : order < 0)) {
      best = item;
      bestValue = key;
    }
  }
  return best;
}

/// A map from key, value pairs: `obj("from", a, "to", b)`. Formulas can't
/// contain braces, so this is how they build objects.
Map<String, Object?> _object(List<Object?> args) => {
  for (int i = 0; i + 1 < args.length; i += 2)
    FormulaEvaluator.stringify(args[i]): args[i + 1],
};

/// The UTC offset [value] gives, as hours (`-7`, `5.5`) or text (`-07:00`,
/// `+0530`, `Z`), or null.
Duration? _offset(Object? value) {
  if (value == null) return null;
  if (value is num) return Duration(minutes: (value * 60).round());
  final String text = value.toString().trim();
  if (text == 'Z' || text.toUpperCase() == 'UTC') return Duration.zero;
  final Match? m = RegExp(r'^([+-])(\d{1,2}):?(\d{2})?$').firstMatch(text);
  if (m == null) {
    final num? hours = num.tryParse(text);
    return hours == null ? null : Duration(minutes: (hours * 60).round());
  }
  final int minutes = int.parse(m[2]!) * 60 + int.parse(m[3] ?? '0');
  return Duration(minutes: m[1] == '-' ? -minutes : minutes);
}

/// The instant formulas take as now (`now()`, `today()`).
///
/// A host can pin it to show an app at a given moment, for previews and
/// reproducible screenshots of date-dependent screens (the Codelessly site
/// pins it from a `?now=` URL parameter).
abstract final class FormulaClock {
  /// The pinned instant, or null for the device clock.
  static DateTime? pinned;

  /// Now: [pinned], or the device clock.
  static DateTime now() => pinned ?? DateTime.now();
}

/// The wall-clock time now at the UTC [offset] (see [_offset]), or local
/// time without one. Returned without a zone, like other formula dates.
DateTime _nowAt(Object? offset) {
  final Duration? delta = _offset(offset);
  if (delta == null) return FormulaClock.now().toLocal();
  final DateTime utc = FormulaClock.now().toUtc().add(delta);
  return DateTime(
    utc.year,
    utc.month,
    utc.day,
    utc.hour,
    utc.minute,
    utc.second,
    utc.millisecond,
  );
}

/// The wall-clock part of an ISO date-time written with an offset, e.g.
/// `2026-10-22T07:25:17-07:00` → `2026-10-22T07:25:17.000`, so a time an
/// API gives in a place's zone reads as that place's local time.
String? _wallTime(Object? value) {
  final String text = FormulaEvaluator.stringify(value).trim();
  final Match? m = RegExp(
    r'^(\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}(?::\d{2}(?:[.,]\d+)?)?)',
  ).firstMatch(text);
  if (m == null) return _dateText(_toDate(text));
  return _dateText(DateTime.tryParse(m[1]!.replaceFirst(' ', 'T')));
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
  'count': (a) =>
      a.length < 2 ? _values(_arg(a, 0), null).length : _matching(a).length,
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
  'trim': (a) => FormulaEvaluator.stringify(_arg(a, 0)).trim(),
  'startsWith': (a) => switch (_arg(a, 0)) {
    final String s => s.startsWith(FormulaEvaluator.stringify(_arg(a, 1))),
    _ => false,
  },
  'endsWith': (a) => switch (_arg(a, 0)) {
    final String s => s.endsWith(FormulaEvaluator.stringify(_arg(a, 1))),
    _ => false,
  },
  'contains': (a) => switch (_arg(a, 0)) {
    final String s => s.contains(FormulaEvaluator.stringify(_arg(a, 1))),
    final Iterable l => l.any((v) => _looseEquals(v, _arg(a, 1))),
    final Map m => m.containsKey(_arg(a, 1)),
    _ => false,
  },
  'where': (a) => _matching(a).toList(),
  'filter': (a) => _matching(a).toList(),
  'find': (a) => _matching(a).firstOrNull,
  'any': (a) => _matching(a).isNotEmpty,
  'all': (a) {
    final List<Object?> rest = a.skip(1).toList();
    return _values(_arg(a, 0), null).every((item) => _matches(item, rest));
  },
  'map': (a) => _values(_arg(a, 0), _arg(a, 1)).toList(),
  'sortBy': _sortBy,
  'unique': _unique,
  'without': (a) => [
    for (final item in _values(_arg(a, 0), null))
      if (!_values(_arg(a, 1), null).any((other) => _looseEquals(item, other)))
        item,
  ],
  'number': (a) => _toNum(_arg(a, 0)),
  'text': (a) => FormulaEvaluator.stringify(_arg(a, 0)),
  'isEmpty': (a) => !_truthy(_functions['length']!(a)),
  'isNotEmpty': (a) => _truthy(_functions['length']!(a)),
  'now': (a) => _dateText(_nowAt(_arg(a, 0))),
  'today': (a) {
    final DateTime now = _nowAt(_arg(a, 0));
    return _dateText(DateTime(now.year, now.month, now.day));
  },
  'wallTime': (a) => _wallTime(_arg(a, 0)),
  'substring': (a) {
    final String text = FormulaEvaluator.stringify(_arg(a, 0));
    final int start = _intArg(_arg(a, 1)).clamp(0, text.length);
    final int end = _arg(a, 2) == null
        ? text.length
        : _intArg(_arg(a, 2)).clamp(start, text.length);
    return text.substring(start, end);
  },
  'replace': (a) => FormulaEvaluator.stringify(_arg(a, 0)).replaceAll(
    FormulaEvaluator.stringify(_arg(a, 1)),
    FormulaEvaluator.stringify(_arg(a, 2)),
  ),
  'split': (a) =>
      FormulaEvaluator.stringify(_arg(a, 0))
          .split(FormulaEvaluator.stringify(_arg(a, 1) ?? ',')),
  'slice': (a) {
    final List<Object?> items = _values(_arg(a, 0), null).toList();
    int index(Object? value, int fallback) {
      if (value == null) return fallback;
      final int i = _intArg(value);
      return (i < 0 ? items.length + i : i).clamp(0, items.length);
    }

    final int start = index(_arg(a, 1), 0);
    final int end = index(_arg(a, 2), items.length);
    return end <= start ? <Object?>[] : items.sublist(start, end);
  },
  'range': _range,
  'interpolate': _interpolate,
  'runs': _runs,
  'minBy': (a) => _extremeBy(a, max: false),
  'maxBy': (a) => _extremeBy(a, max: true),
  'obj': _object,
  'parseDate': (a) => _dateText(_toDate(_arg(a, 0))),
  'formatDate': (a) => _formatDate(_arg(a, 0), _arg(a, 1)),
  'addMinutes': (a) =>
      _dateText(_shift(_arg(a, 0), minutes: _intArg(_arg(a, 1)))),
  'addHours': (a) => _dateText(_shift(_arg(a, 0), hours: _intArg(_arg(a, 1)))),
  'addDays': (a) => _dateText(_shift(_arg(a, 0), days: _intArg(_arg(a, 1)))),
  'addMonths': (a) =>
      _dateText(_shift(_arg(a, 0), months: _intArg(_arg(a, 1)))),
  'diffMinutes': (a) => _difference(_arg(a, 0), _arg(a, 1))?.inMinutes,
  'diffHours': (a) => _difference(_arg(a, 0), _arg(a, 1))?.inHours,
  'diffDays': (a) => _diffDays(_arg(a, 0), _arg(a, 1)),
  'year': (a) => _toDate(_arg(a, 0))?.year,
  'month': (a) => _toDate(_arg(a, 0))?.month,
  'day': (a) => _toDate(_arg(a, 0))?.day,
  'hour': (a) => _toDate(_arg(a, 0))?.hour,
  'minute': (a) => _toDate(_arg(a, 0))?.minute,
  'weekday': (a) => _toDate(_arg(a, 0))?.weekday,
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

/// A lambda argument, `param => body`. Evaluates to a [_Closure] that list
/// functions call once per item.
class _Lambda extends _Node {
  final String param;
  final _Node body;

  const _Lambda(this.param, this.body);

  @override
  Object? eval(FormulaPathResolver resolve) => _Closure(param, body, resolve);

  /// The body's paths, except those of the parameter, which aren't
  /// variables.
  @override
  void collectPaths(Set<String> paths) {
    final Set<String> bodyPaths = {};
    body.collectPaths(bodyPaths);
    paths.addAll(
      bodyPaths.where(
        (path) =>
            path != param &&
            !path.startsWith('$param.') &&
            !path.startsWith('$param['),
      ),
    );
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
      case '<' || '<=' || '>' || '>=':
        final int? order = _compare(a, b);
        if (order == null) return false;
        return switch (op) {
          '<' => order < 0,
          '<=' => order <= 0,
          '>' => order > 0,
          _ => order >= 0,
        };
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
  static final RegExp _lambdaHead = RegExp(
    r'(?:([a-zA-Z_][a-zA-Z0-9_]*)|\(\s*([a-zA-Z_][a-zA-Z0-9_]*)\s*\))\s*=>',
  );

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

  /// A function argument: an expression, or a lambda `item => expression`
  /// (also written `(item) => expression`).
  _Node _argument() {
    _skip();
    final Match? head = _lambdaHead.matchAsPrefix(source, pos);
    if (head == null) return _ternary();
    pos = head.end;
    return _Lambda(head[1] ?? head[2]!, _ternary());
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
          args.add(_argument());
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
