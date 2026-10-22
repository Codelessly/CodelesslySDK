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
///  - math: sqrt, pow, sin, cos, tan, asin, acos, atan, atan2 (radians),
///    pi, radians, degrees, clamp, and distance(lat1, lng1, lat2, lng2,
///    unit) for the great-circle distance in 'km' (default) or 'mi'.
///  - building data: object(key, value, …), merge, set, keys, values,
///    flatten, compact (drops nulls and empty text), and
///    list edits that return a new list: append, setAt, insertAt, removeAt
///    and move. Set variable actions use them to change nested data, e.g.
///    `setAt(trip.stops, index, merge(item, object('nights', 3)))`.
///  - list slicing: first, last, slice(list, start, end), take, skip,
///    reverse, range(end) or range(start, end, step), and indexOf(list,
///    value or predicate), which is -1 when nothing matches.
///  - date functions: now, today, parseDate, formatDate, addMinutes, addHours,
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
    FormulaFunctionDoc('sqrt', 'sqrt(value)', 'sqrt(16) → 4'),
    FormulaFunctionDoc('pow', 'pow(base, exponent)', 'pow(2, 10) → 1024'),
    FormulaFunctionDoc('sin', 'sin(radians)', 'sin(pi() / 2) → 1'),
    FormulaFunctionDoc('cos', 'cos(radians)', 'cos(0) → 1'),
    FormulaFunctionDoc('tan', 'tan(radians)', 'tan(0) → 0'),
    FormulaFunctionDoc('asin', 'asin(value)', 'asin(1) → 1.5708'),
    FormulaFunctionDoc('acos', 'acos(value)', 'acos(1) → 0'),
    FormulaFunctionDoc('atan', 'atan(value)', 'atan(1) → 0.7854'),
    FormulaFunctionDoc('atan2', 'atan2(y, x)', 'atan2(1, 1) → 0.7854'),
    FormulaFunctionDoc('pi', 'pi()', 'pi() → 3.14159…'),
    FormulaFunctionDoc(
      'radians',
      'radians(degrees)',
      'radians(180) → 3.14159…',
    ),
    FormulaFunctionDoc('degrees', 'degrees(radians)', 'degrees(pi()) → 180'),
    FormulaFunctionDoc(
      'clamp',
      'clamp(value, min, max)',
      'clamp(12, 0, 10) → 10',
    ),
    FormulaFunctionDoc(
      'distance',
      "distance(lat1, lng1, lat2, lng2, 'km' or 'mi')",
      "distance(a.lat, a.lng, b.lat, b.lng, 'mi') → 362.4",
    ),
    FormulaFunctionDoc('first', 'first(list)', 'first(stops) → the first stop'),
    FormulaFunctionDoc('last', 'last(list)', 'last(stops) → the last stop'),
    FormulaFunctionDoc(
      'slice',
      'slice(list, start, end)',
      "slice(['a', 'b', 'c', 'd'], 1, 3) → ['b', 'c']",
    ),
    FormulaFunctionDoc(
      'take',
      'take(list, n)',
      'take(stops, index) → stops before this one',
    ),
    FormulaFunctionDoc(
      'skip',
      'skip(list, n)',
      'skip(stops, 1) → all but the first',
    ),
    FormulaFunctionDoc(
      'reverse',
      'reverse(list or text)',
      'reverse([1, 2, 3]) → [3, 2, 1]',
    ),
    FormulaFunctionDoc(
      'range',
      'range(end) or range(start, end, step)',
      'range(0, 70, 10) → [0, 10, …, 60]',
    ),
    FormulaFunctionDoc(
      'indexOf',
      'indexOf(list, value) or indexOf(list, item => test)',
      "indexOf(trips, t => t.id == id) → 2",
    ),
    FormulaFunctionDoc(
      'object',
      'object(key, value, key, value, …)',
      "object('nights', 2, 'cg', id) → {nights: 2, cg: id}",
    ),
    FormulaFunctionDoc(
      'merge',
      'merge(map, map, …)',
      "merge(stop, object('nights', 3)) → stop with 3 nights",
    ),
    FormulaFunctionDoc(
      'set',
      'set(map, key, value)',
      "set(rig, 'length', 36) → rig, 36 ft long",
    ),
    FormulaFunctionDoc('keys', 'keys(map)', 'keys(rig) → [name, length, …]'),
    FormulaFunctionDoc('values', 'values(map)', 'values(totals) → [3, 5]'),
    FormulaFunctionDoc(
      'flatten',
      'flatten(list of lists)',
      'flatten([[1, 2], [3]]) → [1, 2, 3]',
    ),
    FormulaFunctionDoc(
      'compact',
      'compact(list)',
      "compact([1, null, '', 2]) → [1, 2]",
    ),
    FormulaFunctionDoc(
      'append',
      'append(list, item, …)',
      "append(stops, object('cg', id, 'nights', 2))",
    ),
    FormulaFunctionDoc(
      'setAt',
      'setAt(list, index, item)',
      'setAt([1, 2, 3], 1, 9) → [1, 9, 3]',
    ),
    FormulaFunctionDoc(
      'insertAt',
      'insertAt(list, index, item)',
      'insertAt([1, 3], 1, 2) → [1, 2, 3]',
    ),
    FormulaFunctionDoc(
      'removeAt',
      'removeAt(list, index)',
      'removeAt([1, 2, 3], 0) → [2, 3]',
    ),
    FormulaFunctionDoc(
      'move',
      'move(list, from, to)',
      'move([a, b, c], 2, 0) → [c, a, b]',
    ),
    FormulaFunctionDoc(
      'thousands',
      'thousands(value, decimals)',
      'thousands(1094) → 1,094',
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
    FormulaFunctionDoc('now', 'now()', 'now() → 2026-10-21T14:30:00.000'),
    FormulaFunctionDoc('today', 'today()', 'today() → 2026-10-21T00:00:00.000'),
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

typedef _Function = Object? Function(List<Object?> args);

/// A list index from [value]: negative counts from the end, and the result
/// is clamped to `0..length`. [fallback] when [value] isn't a number.
int _index(Object? value, int length, int fallback) {
  if (value == null) return fallback;
  final num? n = _toNum(value);
  if (n == null || n.isNaN) return fallback;
  final int i = n.toInt();
  return (i < 0 ? length + i : i).clamp(0, length);
}

int _count(Object? value) {
  final num? n = _toNum(value);
  return n == null || n.isNaN || n < 0 ? 0 : n.toInt();
}

/// `range(end)` is 0 up to [end], `range(start, end, step)` counts by step.
/// Capped at 10,000 items.
List<num> _range(List<Object?> a) {
  final bool single = a.length < 2;
  final num start = single ? 0 : _num(_arg(a, 0));
  final num end = single ? _num(_arg(a, 0)) : _num(_arg(a, 1));
  final num step = a.length > 2 ? _num(_arg(a, 2)) : (end < start ? -1 : 1);
  if (start.isNaN || end.isNaN || step.isNaN || step == 0) return [];
  return [for (num v = start; step > 0 ? v < end : v > end; v += step) _tidy(v)]
      .take(10000)
      .toList();
}

/// Great-circle distance between two points in degrees, in km, or in miles
/// when the fifth argument is 'mi'.
Object? _distance(List<Object?> a) {
  final List<num> v = [for (int i = 0; i < 4; i++) _num(_arg(a, i))];
  if (v.any((n) => n.isNaN)) return null;
  double rad(num d) => d * math.pi / 180;
  final double dLat = rad(v[2] - v[0]);
  final double dLng = rad(v[3] - v[1]);
  final double h =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(v[0])) *
          math.cos(rad(v[2])) *
          math.pow(math.sin(dLng / 2), 2);
  final double km = 2 * 6371.0088 * math.asin(math.min(1, math.sqrt(h)));
  final String unit = FormulaEvaluator.stringify(_arg(a, 4)).toLowerCase();
  return unit.startsWith('mi') ? km / 1.609344 : km;
}

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
  'sqrt': (a) => _tidy(math.sqrt(_num(_arg(a, 0)))),
  'pow': (a) => _tidy(math.pow(_num(_arg(a, 0)), _num(_arg(a, 1)))),
  'sin': (a) => math.sin(_num(_arg(a, 0))),
  'cos': (a) => math.cos(_num(_arg(a, 0))),
  'tan': (a) => math.tan(_num(_arg(a, 0))),
  'asin': (a) => math.asin(_num(_arg(a, 0))),
  'acos': (a) => math.acos(_num(_arg(a, 0))),
  'atan': (a) => math.atan(_num(_arg(a, 0))),
  'atan2': (a) => math.atan2(_num(_arg(a, 0)), _num(_arg(a, 1))),
  'pi': (a) => math.pi,
  'radians': (a) => _num(_arg(a, 0)) * math.pi / 180,
  'degrees': (a) => _num(_arg(a, 0)) * 180 / math.pi,
  'clamp': (a) =>
      _tidy(_num(_arg(a, 0)).clamp(_num(_arg(a, 1)), _num(_arg(a, 2)))),
  'distance': _distance,
  'first': (a) => _values(_arg(a, 0), null).firstOrNull,
  'last': (a) => _values(_arg(a, 0), null).lastOrNull,
  'slice': (a) {
    final List<Object?> items = List<Object?>.of(_values(_arg(a, 0), null));
    final int start = _index(_arg(a, 1), items.length, 0);
    final int end = _index(_arg(a, 2), items.length, items.length);
    return end <= start ? <Object?>[] : items.sublist(start, end);
  },
  'take': (a) => _values(_arg(a, 0), null).take(_count(_arg(a, 1))).toList(),
  'skip': (a) => _values(_arg(a, 0), null).skip(_count(_arg(a, 1))).toList(),
  'reverse': (a) => switch (_arg(a, 0)) {
    final String s => s.split('').reversed.join(),
    final Iterable l => l.toList().reversed.toList(),
    _ => null,
  },
  'range': _range,
  'indexOf': (a) {
    final List<Object?> items = List<Object?>.of(_values(_arg(a, 0), null));
    final List<Object?> rest = a.skip(1).toList();
    final bool predicate = rest.length > 1 || _arg(rest, 0) is _Closure;
    return items.indexWhere(
      (item) =>
          predicate ? _matches(item, rest) : _looseEquals(item, _arg(rest, 0)),
    );
  },
  'object': (a) => <String, Object?>{
    for (int i = 0; i + 1 < a.length; i += 2)
      FormulaEvaluator.stringify(a[i]): a[i + 1],
  },
  'merge': (a) => <String, Object?>{
    for (final Object? m in a)
      if (m is Map) ...m.map((k, v) => MapEntry(k.toString(), v)),
  },
  'set': (a) => <String, Object?>{
    if (_arg(a, 0) case final Map m) ...m.map((k, v) => MapEntry('$k', v)),
    FormulaEvaluator.stringify(_arg(a, 1)): _arg(a, 2),
  },
  'keys': (a) => switch (_arg(a, 0)) {
    final Map m => m.keys.map((k) => k.toString()).toList(),
    _ => <Object?>[],
  },
  'values': (a) => switch (_arg(a, 0)) {
    final Map m => m.values.toList(),
    _ => <Object?>[],
  },
  'flatten': (a) => [
    for (final Object? item in _values(_arg(a, 0), null))
      if (item is Iterable) ...item else item,
  ],
  'compact': (a) => [
    for (final Object? item in _values(_arg(a, 0), null))
      if (item != null && item != '') item,
  ],
  'append': (a) => [..._values(_arg(a, 0), null), ...a.skip(1)],
  'setAt': (a) {
    final List<Object?> items = List<Object?>.of(_values(_arg(a, 0), null));
    final int i = _index(_arg(a, 1), items.length, -1);
    if (i < 0 || i >= items.length) return items;
    items[i] = _arg(a, 2);
    return items;
  },
  'insertAt': (a) {
    final List<Object?> items = List<Object?>.of(_values(_arg(a, 0), null));
    items.insert(_index(_arg(a, 1), items.length, items.length), _arg(a, 2));
    return items;
  },
  'removeAt': (a) {
    final List<Object?> items = List<Object?>.of(_values(_arg(a, 0), null));
    final int i = _index(_arg(a, 1), items.length, -1);
    if (i >= 0 && i < items.length) items.removeAt(i);
    return items;
  },
  'move': (a) {
    final List<Object?> items = List<Object?>.of(_values(_arg(a, 0), null));
    final int from = _index(_arg(a, 1), items.length, -1);
    if (from < 0 || from >= items.length) return items;
    final Object? item = items.removeAt(from);
    items.insert(_index(_arg(a, 2), items.length, items.length), item);
    return items;
  },
  'thousands': (a) {
    final num n = _num(_arg(a, 0));
    if (n.isNaN) return null;
    final int decimals = _count(_arg(a, 1));
    final String fixed = n.abs().toStringAsFixed(decimals);
    final List<String> parts = fixed.split('.');
    final String whole = parts[0].replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (m) => '${m[1]},',
    );
    return '${n < 0 ? '-' : ''}$whole${parts.length > 1 ? '.${parts[1]}' : ''}';
  },
  'number': (a) => _toNum(_arg(a, 0)),
  'text': (a) => FormulaEvaluator.stringify(_arg(a, 0)),
  'isEmpty': (a) => !_truthy(_functions['length']!(a)),
  'isNotEmpty': (a) => _truthy(_functions['length']!(a)),
  'now': (a) => _dateText(DateTime.now()),
  'today': (a) {
    final DateTime now = DateTime.now();
    return _dateText(DateTime(now.year, now.month, now.day));
  },
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
