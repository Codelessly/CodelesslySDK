import 'dart:math' as math;

import 'formula_clock.dart';

/// The body of a formula: text and quoted strings, with braces only in
/// balanced pairs nested up to [depth] deep, such as the object literal in
/// `merge(r, {tags: {a: 1}})`. Braces inside quoted strings don't count.
String _formulaBody(int depth) {
  const String atom = r'''[^{}'"]|'[^']*'|"[^"]*"''';
  String body = '(?:$atom)*';
  for (int i = 0; i < depth; i++) {
    body = '(?:$atom|\\{$body\\})*';
  }
  return body;
}

/// Matches a formula written as `${= expression}` in a text.
///
/// The expression can contain braces in balanced pairs, three levels deep,
/// for object literals such as `${= merge(r, {favorite: true})}`.
final RegExp formulaRegex = RegExp(
  r'(?<!\\)\$\{=(?<expr>' + _formulaBody(3) + r')\}',
);

/// Matches a text that is exactly one formula, e.g. `${= qty * price}`.
final RegExp exactFormulaRegex = RegExp(
  r'^\s*(?<!\\)\$\{=(?<expr>' + _formulaBody(3) + r')\}\s*$',
);

/// Resolves a variable path such as `storage.cart` or `item.price` to its
/// value.
typedef FormulaPathResolver = Object? Function(String path);

/// Evaluates small expressions used in `${= ...}` formulas.
///
/// Supports:
///  - numbers, 'single' or "double" quoted strings, true, false, null,
///    `[a, b]` lists and `{id: 'a', 'full name': n + 1}` objects, whose keys
///    are names or quoted text.
///  - variable paths like `storage.cart.length` or `item.price`, resolved with
///    the same rules as `${path}`, followed by `[index]` or `.key`.
///  - `+ - * / %`, comparisons `== != < <= > >=`, `&& || !` and
///    `condition ? a : b`. `+` joins text when either side is text.
///  - functions: money, fixed, thousands, round, floor, ceil, abs, min, max, sum, count,
///    length, if, plural, join, upper, lower, trim, contains, startsWith,
///    endsWith, where, without, number, text, isEmpty, isNotEmpty, clamp,
///    sin, cos, sqrt, pow, pad, alpha, take, skip, padLeft, padRight,
///    substring, split, replace and coalesce. See
///    [FormulaEvaluator.functions].
///  - text functions: indexOf, matches and slug; durations: seconds
///    ('3:45' → 225) and duration (225 → '3:45'); colors: luminance.
///  - maps: `obj('id', 1)`, `object('id', 1)` or `{id: 1}` builds one;
///    `set(map, key, value)`, `with(map, key, value, …)` and `merge(a, b)`
///    return changed copies; `keys` and `values` read them. `map` can update
///    one list item: `map(units, u => with(u, 'hours', h))`.
///  - more list functions: range, slice, first, last, concat, indexOf,
///    at(list, index) and flatMap(list, lambda).
///  - list functions that take a predicate or key: filter, where, count,
///    find, findIndex, any, all, map, sortBy, sortByDesc, unique, sum and
///    join. The predicate is a lambda, `item => expression`, or a field name,
///    optionally with a value to match, e.g.
///    `filter(tasks, t => contains(lower(t.title), q))`,
///    `filter(tasks, 'done')` or `count(tasks, 'done', false)`. A lambda's
///    parameter is read like a variable inside its body (`t.title`,
///    `t.tags[0]`, `t.tags.length`) and hides a variable of the same name;
///    the body can read every other variable. A lambda can take the item's
///    index as a second parameter, `(t, i) => i < 3`. Lambdas are only
///    allowed as function arguments.
///  - left(text, n), right(text, n) and toMap (a map built from a list,
///    `toMap(items, i => i.id, i => "pass")`).
///  - math: sqrt, pow, sin, cos, tan, asin, acos, atan, atan2 (radians),
///    pi, radians, degrees, clamp, and distance(lat1, lng1, lat2, lng2,
///    unit) for the great-circle distance in 'km' (default) or 'mi'.
///  - building data: object(key, value, …) or `{key: value}` literals,
///    merge, set, keys, values, flatten, compact (drops nulls and empty
///    text), and list edits that return a new list: append, setAt,
///    insertAt, removeAt and move. Set variable actions use them to change
///    nested data, e.g.
///    `setAt(trip.stops, index, merge(item, object('nights', 3)))`.
///  - list slicing: first, last, slice(list, start, end), take, skip,
///    reverse (these also work on text), range(end) or range(start, end,
///    step), and indexOf(list, value or predicate), which is -1 when nothing
///    matches.
///  - text helpers: padLeft, replace, substring and split.
///  - record helpers: unset, prepend, updateWhere, removeWhere, findIndex
///    and newId; set also takes a list and an index, and indexOf and slice
///    also take text. Like the list edits they return new values.
///  - series helpers: interpolate, runs, minBy and maxBy.
///  - date functions: now, today, wallTime, parseDate, formatDate,
///    addMinutes, addHours,
///    addDays, addMonths, diffMinutes, diffHours, diffDays, year, month, day,
///    hour, minute, second, weekday and daysInMonth, plus addSeconds,
///    diffSeconds and formatDuration. Formulas using now() or today() rebuild
///    every second while listened to. Dates are ISO 8601 text such as
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

  /// Whether [expression] is a well-formed formula.
  static bool parses(String expression) => _parse(expression) != null;

  /// The variable paths [expression] reads, e.g. `storage.cart` and `qty`.
  static Set<String> referencedPaths(String expression) {
    final _Node? node = _parse(expression);
    if (node == null) return {};
    final Set<String> paths = {};
    node.collectPaths(paths);
    return paths;
  }

  /// Whether [expression] reads the clock (`now()` or `today()`), so its
  /// value changes as time passes.
  static bool readsClock(String expression) =>
      _clockCall.hasMatch(expression.replaceAll(_quoted, ''));

  /// Whether any formula in [text] reads the clock.
  static bool textReadsClock(String text) => formulaRegex
      .allMatches(text)
      .any((match) => readsClock(match.namedGroup('expr')!));

  static final RegExp _clockCall = RegExp(r'\b(now|today)\s*\(');

  static final RegExp _quoted = RegExp(
    r'"[^"]*"'
    '|'
    r"'[^']*'",
  );

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
    FormulaFunctionDoc('left', 'left(text, count)', 'left("MX4821", 2) → MX'),
    FormulaFunctionDoc(
      'right',
      'right(text, count)',
      'right("1FUJGLDR5MX4821", 6) → MX4821',
    ),
    FormulaFunctionDoc(
      'toMap',
      'toMap(list, item => key, item => value)',
      'toMap(items, i => i.id, i => "pass") → {1a: pass, 1b: pass}',
    ),
    FormulaFunctionDoc(
      'money',
      'money(value, symbol, decimals) or money(value, decimals)',
      r'money(price) → $1,234.50',
    ),
    FormulaFunctionDoc(
      'formatNumber',
      'formatNumber(value, digits?)',
      'formatNumber(2481.64, 1) → 2,481.6',
    ),
    FormulaFunctionDoc(
      'feetInches',
      'feetInches(feet)',
      'feetInches(6.67) → 6′ 8″',
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
      'padLeft',
      'padLeft(value, width, char)',
      'padLeft(4, 2) → 04 (numbers pad with 0, text with spaces)',
    ),
    FormulaFunctionDoc(
      'padRight',
      'padRight(value, width, char)',
      'padRight("A", 3, ".") → A..',
    ),
    FormulaFunctionDoc(
      'substring',
      'substring(text, start, end)',
      'substring("Vinyl", 0, 3) → Vin',
    ),
    FormulaFunctionDoc(
      'replace',
      'replace(text, from, to)',
      'replace("a-b-c", "-", " ") → a b c',
    ),
    FormulaFunctionDoc(
      'split',
      'split(text, separator)',
      'split("rock, jazz", ", ") → [rock, jazz]',
    ),
    FormulaFunctionDoc(
      'matches',
      'matches(text, pattern)',
      r'matches(code, "^\d{4}$") → true',
    ),
    FormulaFunctionDoc(
      'slug',
      'slug(text)',
      'slug("Kind of Blue!") → kind-of-blue',
    ),
    FormulaFunctionDoc(
      'seconds',
      'seconds("m:ss" or "h:mm:ss")',
      'seconds("3:45") → 225',
    ),
    FormulaFunctionDoc('duration', 'duration(seconds)', 'duration(225) → 3:45'),
    FormulaFunctionDoc(
      'luminance',
      'luminance(color)',
      'luminance("#FFFFFF") → 1',
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
      'map(list, field or item => value or (item, index) => value)',
      'map(cart, i => i.price * i.qty) → [8, 16]',
    ),
    FormulaFunctionDoc(
      'sortBy',
      'sortBy(list, field or item => key, "desc", more keys…)',
      'sortBy(records, r => r.artist, r => r.year, "desc") (missing keys last)',
    ),
    FormulaFunctionDoc(
      'sortByDesc',
      'sortByDesc(list, field or item => key, more keys…)',
      'sortByDesc(records, "year")',
    ),
    FormulaFunctionDoc(
      'findIndex',
      'findIndex(list, item => condition) or findIndex(list, field, value)',
      'findIndex(records, r => r.id == selectedId) → 2 (-1 when none)',
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
    FormulaFunctionDoc(
      'concat',
      'concat(list or item, ...)',
      'concat([record.art], sleeves) or list1 + list2',
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
      'concat',
      'concat(list, list2, ...)',
      'concat(range(2), [9]) → [0, 1, 9]',
    ),
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
      'range(count) or range(start, end, step), end included (dates: step '
          'in minutes)',
      'range(3, 7) → [3, 4, 5, 6, 7]; range(3) → [0, 1, 2]',
    ),
    FormulaFunctionDoc(
      'indexOf',
      'indexOf(list, value) or indexOf(list, item => test)',
      'indexOf(trips, t => t.id == id) → 2',
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
      'set(map, key, value, …) or set(list, index, value)',
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
      'moveItems',
      'moveItems(list, ids, beforeId, changes)',
      "moveItems(cards, drag.ids, drag.beforeId, object('lane', drag.over)) "
          '→ the cards with those ids (or values) moved before the one with '
          "beforeId ('' = to the end), with the changes merged in",
    ),
    FormulaFunctionDoc(
      'thousands',
      'thousands(value, decimals)',
      'thousands(1094) → 1,094',
    ),
    FormulaFunctionDoc('unset', 'unset(map, key)', 'unset(task, "draft")'),
    FormulaFunctionDoc(
      'prepend',
      'prepend(list, item)',
      'prepend(notes, note)',
    ),
    FormulaFunctionDoc(
      'updateWhere',
      'updateWhere(list, item => condition, item => newItem) or '
          'updateWhere(list, field, value, item => newItem or map to merge)',
      'updateWhere(tasks, "id", id, t => set(t, "done", !t.done))',
    ),
    FormulaFunctionDoc(
      'removeWhere',
      'removeWhere(list, item => condition) or removeWhere(list, field, value)',
      'removeWhere(tasks, "id", id)',
    ),
    FormulaFunctionDoc(
      'findIndex',
      'findIndex(list, item => condition) or findIndex(list, field, value)',
      'findIndex(tasks, "id", id) → 2 (-1 when missing)',
    ),
    FormulaFunctionDoc('newId', 'newId(prefix)', 'newId("task") → task_k3x9f2'),
    FormulaFunctionDoc(
      'get',
      'get(map or list, key)',
      "get(lineNames, item.line) → 'Weld'",
    ),
    FormulaFunctionDoc('take', 'take(list, count)', 'take(pareto, index + 1)'),
    FormulaFunctionDoc('range', 'range(count)', 'range(3) → [0, 1, 2]'),
    FormulaFunctionDoc('skip', 'skip(list, count)', 'skip(events, 25)'),
    FormulaFunctionDoc('number', 'number(value)', 'number("42") → 42'),
    FormulaFunctionDoc(
      'alpha',
      'alpha(color, opacity)',
      "alpha('#FF4D4F', 0.12) → #1FFF4D4F",
    ),
    FormulaFunctionDoc('pad', 'pad(value, width, fill)', 'pad(5, 2) → 05'),
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
      'addSeconds',
      'addSeconds(date, seconds)',
      'addSeconds(start, 90)',
    ),
    FormulaFunctionDoc(
      'diffSeconds',
      'diffSeconds(from, to)',
      'diffSeconds(startedAt, now()) → 240',
    ),
    FormulaFunctionDoc(
      'formatDuration',
      'formatDuration(seconds, pattern)',
      "formatDuration(6480, 'h:mm:ss') → 1:48:00 · 'mm:ss' → 108:00 · 'compact' → 1h 48m",
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
      'second',
      'second(date)',
      'second("2026-10-21T14:30:15") → 15',
    ),
    FormulaFunctionDoc(
      'weekday',
      'weekday(date)',
      'weekday("2026-10-21") → 3 (Monday is 1)',
    ),
    FormulaFunctionDoc(
      'daysInMonth',
      'daysInMonth(date)',
      'daysInMonth("2026-02-10") → 28',
    ),
    FormulaFunctionDoc(
      'obj',
      'obj(key, value, key2, value2, ...)',
      'obj("id", "ex1", "hours", 12) → {id: ex1, hours: 12}',
    ),
    FormulaFunctionDoc(
      'padLeft',
      'padLeft(text, width, char?)',
      'padLeft(42, 5, "0") → 00042',
    ),
    FormulaFunctionDoc(
      'padRight',
      'padRight(text, width, char?)',
      'padRight("ab", 4, ".") → ab..',
    ),
    FormulaFunctionDoc(
      'substring',
      'substring(text, start, end?)',
      'substring("EX-102", 3) → 102',
    ),
    FormulaFunctionDoc(
      'split',
      'split(text, separator?)',
      'split("2481") → [2, 4, 8, 1]',
    ),
    FormulaFunctionDoc(
      'replace',
      'replace(text, from, to)',
      'replace("1,402", ",", "") → 1402',
    ),
    FormulaFunctionDoc(
      'coalesce',
      'coalesce(value, fallback, ...)',
      'coalesce(route.date, today())',
    ),
    FormulaFunctionDoc(
      'with',
      'with(map, key, value, …)',
      "with(item, 'x', item.x + 1) → item with x changed",
    ),
    FormulaFunctionDoc('at', 'at(list, index)', 'at(tasks, 2)'),
    FormulaFunctionDoc(
      'flatMap',
      'flatMap(list, item => list)',
      'flatMap(orders, o => o.items) → every item',
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

/// Formats [value] as money with [symbol] (`$` by default) and [decimals]
/// (2 by default). A number in place of the symbol is the decimals, so
/// `money(38, 0)` is "$38". Decimals `'auto'` drop them for whole amounts:
/// "$38" but "$38.50".
String _money(Object? value, Object? symbol, Object? decimals) {
  if (symbol is num) (symbol, decimals) = (null, symbol);
  final bool auto =
      decimals is String && decimals.trim().toLowerCase() == 'auto';
  final num amount = _num(value);
  if (!amount.isFinite) return '';
  int digits = auto || decimals == null ? 2 : _intArg(decimals).clamp(0, 20);
  if (auto && (amount * 100).round() % 100 == 0) digits = 0;
  final String sign = amount < 0 ? '-' : '';
  final String text = amount.abs().toStringAsFixed(digits);
  final int dot = text.contains('.') ? text.indexOf('.') : text.length;
  final String whole = text
      .substring(0, dot)
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  return '$sign${symbol ?? r'$'}$whole${text.substring(dot)}';
}

/// [value] with [digits] decimals (default 0) and thousands separators,
/// e.g. 2481.64 with 1 digit is "2,481.6".
String _grouped(Object? value, Object? digits) {
  final num amount = _num(value);
  if (amount.isNaN) return '';
  final String text = amount.toStringAsFixed(
    _num(digits ?? 0).toInt().clamp(0, 20),
  );
  final int dot = text.contains('.') ? text.indexOf('.') : text.length;
  final String whole = text
      .substring(0, dot)
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  return '$whole${text.substring(dot)}';
}

/// [value] as text padded to [width] with the first character of [fill]:
/// zeros for numbers and spaces for text by default. A negative number keeps
/// its sign in front of zeros, so `padLeft(-4, 3)` is "-04".
String _pad(Object? value, Object? width, Object? fill, {required bool left}) {
  final String text = FormulaEvaluator.stringify(value);
  final int size = _intArg(width);
  final String char = fill == null
      ? (value is num ? '0' : ' ')
      : FormulaEvaluator.stringify(fill);
  if (char.isEmpty) return text;
  if (left && char[0] == '0' && text.startsWith('-')) {
    return '-${text.substring(1).padLeft(size - 1, '0')}';
  }
  return left ? text.padLeft(size, char[0]) : text.padRight(size, char[0]);
}

/// The part of [value]'s text from [start] up to, not including, [end] (the
/// end of the text when null). A negative index counts from the end, so
/// `substring(vin, -6)` is the last six characters. Indexes past either end
/// are clamped.
String _substring(Object? value, Object? start, Object? end) {
  final String text = FormulaEvaluator.stringify(value);
  final (int from, int to) = _bounds(text.length, start, end);
  return text.substring(from, to);
}

/// [start] and [end] as bounds of something [length] long, counting
/// negative values from the end, like JavaScript's `slice`.
(int, int) _bounds(int length, Object? start, Object? end) {
  int bound(Object? value, int fallback) {
    if (value == null) return fallback;
    final int i = _intArg(value);
    return (i < 0 ? length + i : i).clamp(0, length);
  }

  final int from = bound(start, 0);
  return (from, math.max(from, bound(end, length)));
}

/// The items of a list, or characters of a text, from [start] up to [end].
Object? _slice(Object? value, Object? start, Object? end) {
  if (value is String) {
    final (int from, int to) = _bounds(value.length, start, end);
    return value.substring(from, to);
  }
  final List<Object?> items = _values(value, null).toList();
  final (int from, int to) = _bounds(items.length, start, end);
  return items.sublist(from, to);
}

/// [value], a list or text, reversed.
Object? _reverse(Object? value) => switch (value) {
  final String text => text.split('').reversed.join(),
  final Iterable<Object?> items => items.toList().reversed.toList(),
  _ => null,
};

/// Lowercase [value] with every run of other characters than letters and
/// digits turned into one dash, e.g. "Kind of Blue!" is "kind-of-blue".
String _slug(Object? value) =>
    FormulaEvaluator.stringify(value)
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');

/// Seconds in a duration written `m:ss` or `h:mm:ss` (or plain seconds),
/// e.g. "3:45" is 225. Null when it isn't one.
int? _seconds(Object? value) {
  if (value is num) return value.isFinite ? value.round() : null;
  if (value is! String) return null;
  String text = value.trim();
  final bool negative = text.startsWith('-');
  if (negative) text = text.substring(1);
  final List<String> parts = text.split(':');
  if (parts.length > 3 || parts.any((p) => !RegExp(r'^\d+$').hasMatch(p))) {
    return null;
  }
  int total = 0;
  for (int i = 0; i < parts.length; i++) {
    final int n = int.parse(parts[i]);
    if (i > 0 && (parts[i].length != 2 || n >= 60)) return null;
    total = total * 60 + n;
  }
  return negative ? -total : total;
}

/// [value] seconds written `m:ss`, or `h:mm:ss` from an hour, e.g. 225 is
/// "3:45" and 3725 is "1:02:05". Text such as "3:45" is read with [_seconds].
String? _duration(Object? value) {
  if (value == null) return null;
  final num? total = value is String && value.contains(':')
      ? _seconds(value)
      : _toNum(value);
  if (total == null || !total.isFinite) return null;
  final int all = total.abs().round();
  String two(int n) => n.toString().padLeft(2, '0');
  final String sign = total < 0 && all > 0 ? '-' : '';
  final int hours = all ~/ 3600;
  final int minutes = all % 3600 ~/ 60;
  return hours > 0
      ? '$sign$hours:${two(minutes)}:${two(all % 60)}'
      : '$sign$minutes:${two(all % 60)}';
}

/// The relative luminance of a color, from 0 (black) to 1 (white), as WCAG
/// defines it. Reads `#RGB`, `#RRGGBB` and `#AARRGGBB` text (the `#` is
/// optional) and `{r, g, b}` objects with channels from 0 to 1. Null when
/// [value] isn't a color.
num? _luminance(Object? value) {
  final List<double> channels;
  if (value is Map) {
    final List<num?> rgb = [
      for (final key in ['r', 'g', 'b']) _toNum(value[key]),
    ];
    if (rgb.any((c) => c == null)) return null;
    channels = [for (final c in rgb) c!.toDouble().clamp(0, 1)];
  } else {
    String hex = FormulaEvaluator.stringify(value).trim();
    if (hex.startsWith('#')) hex = hex.substring(1);
    if (hex.length == 3) hex = hex.split('').map((c) => c * 2).join();
    if (hex.length == 8) hex = hex.substring(2);
    if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(hex)) return null;
    final int rgb = int.parse(hex, radix: 16);
    channels = [
      for (final shift in [16, 8, 0]) ((rgb >> shift) & 0xff) / 255,
    ];
  }
  final List<double> linear = [
    for (final c in channels)
      c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble(),
  ];
  return _round(
    0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2],
    4,
  );
}

/// The objects [maps] combined into a new one, later keys winning. Values
/// that aren't objects are skipped.
Map<String, Object?> _merge(Iterable<Object?> maps) => {
  for (final map in maps)
    if (map is Map)
      for (final MapEntry(:key, :value) in map.entries) key.toString(): value,
};

/// A copy of [target] with [key] set to [value]: an object's field, or a
/// list's item at an index. Out-of-range indices leave lists unchanged.
Object? _set(Object? target, Object? key, Object? value) {
  if (target is List) {
    final List<Object?> list = [...target];
    final num? index = _toNum(key);
    if (index == null || !index.isFinite || index < 0) return list;
    if (index >= list.length) return list;
    return list..[index.toInt()] = value;
  }
  return {
    ..._merge([target]),
    FormulaEvaluator.stringify(key): value,
  };
}

/// Feet as feet and inches rounded to the inch: 6.67 -> 6′ 8″, 7 -> 7′.
String _feetInches(Object? value) {
  final num feet = _num(value);
  if (feet.isNaN || feet.isInfinite) return '';
  final int inches = (feet * 12).round();
  final String sign = inches < 0 ? '-' : '';
  final int f = inches.abs() ~/ 12, i = inches.abs() % 12;
  return i == 0 ? '$sign$f′' : '$sign$f′ $i″';
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
/// A lambda gets each item's index as its second parameter.
Iterable<Object?> _values(Object? list, Object? selector) {
  if (list is! Iterable) return const [];
  if (selector == null) return list;
  return list.indexed.map((entry) => _select(entry.$2, selector, entry.$1));
}

/// [item]'s value for [selector]: the item itself when null, the lambda's
/// result for a lambda (given the item and its [index]), else the field
/// [selector] names. A field name with dots, such as `author.name`, reads
/// nested fields.
Object? _select(Object? item, Object? selector, [int? index]) {
  if (selector == null) return item;
  if (selector is _Closure) return selector(item, index);
  final Object? value = _member(item, selector);
  if (value != null || selector is! String || !selector.contains('.')) {
    return value;
  }
  return selector.split('.').fold(item, _member);
}

/// Whether [item] matches a predicate given as function arguments [rest]:
/// `(lambda)` or `(field)` match when truthy, `(lambda or field, value)`
/// when the selected value equals value. No predicate matches truthy items.
bool _matches(Object? item, List<Object?> rest, [int? index]) => rest.length < 2
    ? _truthy(_select(item, _arg(rest, 0), index))
    : _looseEquals(_select(item, rest[0], index), rest[1]);

/// Items of `args[0]` with their indexes, in order.
Iterable<(int, Object?)> _indexed(List<Object?> args) =>
    _values(_arg(args, 0), null).indexed;

/// Items of `args[0]` that match the predicate in the rest of [args].
Iterable<Object?> _matching(List<Object?> args) {
  final List<Object?> rest = args.skip(1).toList();
  return _indexed(args)
      .where((entry) => _matches(entry.$2, rest, entry.$1))
      .map((e) => e.$2);
}

/// The index of the first item of `args[0]` that matches the predicate in
/// the rest of [args], or -1.
int _findIndex(List<Object?> args) {
  final List<Object?> rest = args.skip(1).toList();
  for (final (int i, Object? item) in _indexed(args)) {
    if (_matches(item, rest, i)) return i;
  }
  return -1;
}

/// Whether [value] is a sort order: true for `'desc'`, false for `'asc'`,
/// null for anything else.
bool? _sortOrder(Object? value) => switch (value) {
  final String order => switch (order.trim().toLowerCase()) {
    'desc' || 'descending' => true,
    'asc' || 'ascending' => false,
    _ => null,
  },
  _ => null,
};

/// Items of `args[0]` sorted by the keys in the rest of [args], each a field
/// name or lambda; later keys break ties of earlier ones. A key is followed
/// by `'desc'` (or `'asc'`) to sort it descending, and every key is
/// descending by default when [descending]. `args[1]` is always a key, so
/// `sortBy(list, null, 'desc')` sorts plain values descending. Equal keys
/// keep their order and missing keys go last.
List<Object?> _sortBy(List<Object?> args, {bool descending = false}) {
  final List<Object?> items = _values(_arg(args, 0), null).toList();
  final List<(Object?, bool)> keys = [(_arg(args, 1), descending)];
  for (final arg in args.skip(2)) {
    if (_sortOrder(arg) case final bool desc) {
      keys.last = (keys.last.$1, desc);
    } else {
      keys.add((arg, descending));
    }
  }
  final List<(int, Object?, List<Object?>)> keyed = [
    for (int i = 0; i < items.length; i++)
      (i, items[i], [for (final key in keys) _select(items[i], key.$1, i)]),
  ];
  keyed.sort((x, y) {
    for (int k = 0; k < keys.length; k++) {
      final Object? a = x.$3[k];
      final Object? b = y.$3[k];
      final bool aMissing = a == null || a == '';
      final bool bMissing = b == null || b == '';
      if (aMissing || bMissing) {
        if (aMissing == bMissing) continue;
        return aMissing ? 1 : -1;
      }
      final int order = _compare(a, b) ?? 0;
      if (order != 0) return keys[k].$2 ? -order : order;
    }
    return x.$1 - y.$1;
  });
  return [for (final entry in keyed) entry.$2];
}

/// Items of `args[0]` without repeats, keeping the first of each; repeats
/// are judged by the key `args[1]` when given.
List<Object?> _unique(List<Object?> args) {
  final List<Object?> keys = [];
  final List<Object?> items = [];
  for (final (int i, Object? item) in _indexed(args)) {
    final Object? key = _select(item, _arg(args, 1), i);
    if (keys.any((seen) => _looseEquals(seen, key))) continue;
    keys.add(key);
    items.add(item);
  }
  return items;
}

/// A lambda such as `t => t.price` or `(t, i) => i + 1`, ready to call
/// with an item and its index.
class _Closure {
  final String param;
  final String? indexParam;
  final _Node body;
  final FormulaPathResolver outer;

  const _Closure(this.param, this.indexParam, this.body, this.outer);

  static final RegExp _part = RegExp(r'\.([a-zA-Z_][a-zA-Z0-9_]*)|\[(\d+)\]');

  Object? call(Object? value, [int? index]) => body.eval((path) {
    for (final (String? name, Object? bound) in [
      (param, value),
      (indexParam, index),
    ]) {
      if (name == null) continue;
      if (path == name) return bound;
      if (path.startsWith(name) &&
          (path.startsWith('.', name.length) ||
              path.startsWith('[', name.length))) {
        Object? result = bound;
        for (final Match part in _part.allMatches(path, name.length)) {
          result = _member(result, part[1] ?? int.parse(part[2]!));
        }
        return result;
      }
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
  int seconds = 0,
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
    date.second + seconds,
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

/// [seconds] as a duration: `h:mm:ss` (1:48:00), `mm:ss` (04:00, minutes
/// keep counting past 59), `m:ss` (4:00) or, by default, `compact` (1h 48m,
/// 25m, 40s). Negative durations read as their size.
String? _formatDuration(Object? seconds, Object? pattern) {
  final num? value = _toNum(seconds);
  if (value == null || !value.isFinite) return null;
  final int total = value.abs().floor();
  final int h = total ~/ 3600, m = (total % 3600) ~/ 60, s = total % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  return switch (pattern?.toString().trim()) {
    'h:mm:ss' => '$h:${two(m)}:${two(s)}',
    'mm:ss' => '${two(total ~/ 60)}:${two(s)}',
    'm:ss' => '${total ~/ 60}:${two(s)}',
    _ =>
      h > 0 ? (m == 0 ? '${h}h' : '${h}h ${m}m') : (m > 0 ? '${m}m' : '${s}s'),
  };
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
/// The times from [start] to [end], both included, [step] minutes apart
/// (default 1), as ISO 8601 text: `range(sunrise, sunset, 5)`.
List<Object?> _dateRange(Object? start, Object? end, Object? step) {
  final DateTime? from = _toDate(start), to = _toDate(end);
  final num minutes = _num(step ?? 1);
  if (from == null || to == null || !(minutes > 0)) return const [];
  final Duration delta = Duration(microseconds: (minutes * 60e6).round());
  return [
    for (DateTime t = from; !t.isAfter(to); t = t.add(delta)) _dateText(t),
  ].take(_maxRange).toList();
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

/// [value] as a list: a copy of a list, an empty list for null, else a list
/// of that one value.
List<Object?> _listOf(Object? value) => switch (value) {
  null => [],
  final Iterable l => [...l],
  _ => [value],
};

/// [value] as a map with text keys: a copy of a map, else empty.
Map<String, Object?> _mapOf(Object? value) => switch (value) {
  final Map m => {for (final e in m.entries) '${e.key}': e.value},
  _ => {},
};

/// `updateWhere(list, predicate…, update)`: items matching the predicate
/// (a lambda, or a field and value) are replaced by `update(item)` when it
/// is a lambda, or merged with it when it is a map.
List<Object?> _updateWhere(List<Object?> args) {
  if (args.length < 3) return _listOf(_arg(args, 0));
  final Object? update = args.last;
  final List<Object?> predicate = args.sublist(1, args.length - 1);
  return [
    for (final item in _values(_arg(args, 0), null))
      if (!_matches(item, predicate))
        item
      else if (update is _Closure)
        update(item)
      else if (update is Map)
        {..._mapOf(item), ..._mapOf(update)}
      else
        update,
  ];
}

/// A list index from [value]: negative counts from the end, and the result
/// is clamped to `0..length`. [fallback] when [value] isn't a number.
int _index(Object? value, int length, int fallback) {
  if (value == null) return fallback;
  final num? n = _toNum(value);
  if (n == null || n.isNaN) return fallback;
  final int i = n.toInt();
  return (i < 0 ? length + i : i).clamp(0, length);
}

final math.Random _idRandom = math.Random();

/// A short random id, such as `log_k3x9f2a1`, for new records.
String _newId(Object? prefix) {
  const String chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final String id = String.fromCharCodes([
    for (int i = 0; i < 8; i++)
      chars.codeUnitAt(_idRandom.nextInt(chars.length)),
  ]);
  final String p = FormulaEvaluator.stringify(prefix);
  return p.isEmpty ? id : '${p}_$id';
}

int _count(Object? value) {
  final num? n = _toNum(value);
  return n == null || n.isNaN || n < 0 ? 0 : n.toInt();
}

/// `range(n)`: n numbers from 0, `[0, 1, …, n - 1]`. `range(start, end,
/// step)`: from [start] to [end], both included, [step] apart (default 1, or
/// -1 counting down). Dates step in minutes. Capped at 10,000 items.
List<Object?> _range(List<Object?> a) {
  if (a.length < 2) {
    final num count = _num(_arg(a, 0));
    if (count.isNaN) return [];
    return [for (int i = 0; i < count; i++) i].take(_maxRange).toList();
  }
  if (_isDateLike(_arg(a, 0))) {
    return _dateRange(_arg(a, 0), _arg(a, 1), _arg(a, 2));
  }
  final num start = _num(_arg(a, 0));
  final num end = _num(_arg(a, 1));
  final num step = a.length > 2 ? _num(_arg(a, 2)) : (end < start ? -1 : 1);
  if (!start.isFinite || !end.isFinite || !step.isFinite || step == 0) {
    return [];
  }
  // A little slack keeps an end reached by fractional steps (0.1) in.
  return [
    for (num v = start; step > 0 ? v <= end + 1e-9 : v >= end - 1e-9; v += step)
      _tidy(v),
  ].take(_maxRange).toList();
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

/// [color] (`#RRGGBB` or `#AARRGGBB`) at [opacity] (0 to 1), as
/// `#AARRGGBB`.
String? _alpha(Object? color, num opacity) {
  final String hex = FormulaEvaluator.stringify(color).replaceAll('#', '');
  if (hex.length != 6 && hex.length != 8) return null;
  final String rgb = hex.substring(hex.length - 6).toUpperCase();
  final int a = (opacity.clamp(0, 1) * 255).round();
  return '#${a.toRadixString(16).padLeft(2, '0').toUpperCase()}$rgb';
}

Object? _arg(List<Object?> args, int index) =>
    index < args.length ? args[index] : null;

/// A map from each item of `args[0]` to a value: the key is the item's
/// `args[1]` (a field name or lambda) and the value its `args[2]`, or the
/// item itself when that's missing. A later item with the same key wins.
Map<String, Object?> _toMap(List<Object?> args) {
  final Object? list = _arg(args, 0);
  if (list is! Iterable) return {};
  final Object? keySelector = _arg(args, 1);
  final Object? valueSelector = _arg(args, 2);
  final Map<String, Object?> map = {};
  int index = 0;
  for (final Object? item in list) {
    final Object? key = _select(item, keySelector, index);
    if (key != null) {
      map[FormulaEvaluator.stringify(key)] = _select(
        item,
        valueSelector,
        index,
      );
    }
    index++;
  }
  return map;
}

final Map<String, _Function> _functions = {
  'money': (a) => _money(_arg(a, 0), _arg(a, 1), _arg(a, 2)),
  'formatNumber': (a) => _grouped(_arg(a, 0), _arg(a, 1)),
  'feetInches': (a) => _feetInches(_arg(a, 0)),
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
  'padLeft': (a) => _pad(_arg(a, 0), _arg(a, 1), _arg(a, 2), left: true),
  'padRight': (a) => _pad(_arg(a, 0), _arg(a, 1), _arg(a, 2), left: false),
  'substring': (a) => _substring(_arg(a, 0), _arg(a, 1), _arg(a, 2)),
  'replace': (a) {
    final String text = FormulaEvaluator.stringify(_arg(a, 0));
    final String from = FormulaEvaluator.stringify(_arg(a, 1));
    return from.isEmpty
        ? text
        : text.replaceAll(from, FormulaEvaluator.stringify(_arg(a, 2)));
  },
  'split': (a) {
    final String text = FormulaEvaluator.stringify(_arg(a, 0));
    if (text.isEmpty) return <Object?>[];
    // Without a separator, the text splits into its characters.
    final Object? separator = _arg(a, 1);
    return text.split(
      separator == null ? '' : FormulaEvaluator.stringify(separator),
    );
  },
  'matches': (a) {
    final Object? text = _arg(a, 0);
    if (text == null) return false;
    try {
      return RegExp(FormulaEvaluator.stringify(_arg(a, 1)))
          .hasMatch(FormulaEvaluator.stringify(text));
    } on FormatException {
      return false;
    }
  },
  'slug': (a) => _slug(_arg(a, 0)),
  'seconds': (a) => _seconds(_arg(a, 0)),
  'duration': (a) => _duration(_arg(a, 0)),
  'luminance': (a) => _luminance(_arg(a, 0)),
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
  'findIndex': _findIndex,
  'any': (a) => _matching(a).isNotEmpty,
  'all': (a) {
    final List<Object?> rest = a.skip(1).toList();
    return _indexed(a).every((entry) => _matches(entry.$2, rest, entry.$1));
  },
  'map': (a) => _values(_arg(a, 0), _arg(a, 1)).toList(),
  'sortBy': _sortBy,
  'sortByDesc': (a) => _sortBy(a, descending: true),
  'slice': (a) => _slice(_arg(a, 0), _arg(a, 1), _arg(a, 2)),
  'take': (a) => _slice(_arg(a, 0), 0, math.max(0, _intArg(_arg(a, 1)))),
  'skip': (a) => _slice(_arg(a, 0), math.max(0, _intArg(_arg(a, 1))), null),
  'reverse': (a) => _reverse(_arg(a, 0)),
  'merge': _merge,
  'set': (a) {
    Object? result = _arg(a, 0);
    for (int i = 1; i + 1 < a.length; i += 2) {
      result = _set(result, a[i], a[i + 1]);
    }
    return result;
  },
  'unique': _unique,
  'concat': (a) => [
    for (final value in a)
      if (value is Iterable) ...value else ?value,
  ],
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
  'range': _range,
  'indexOf': (a) {
    if (_arg(a, 0) case final String text) {
      return text.indexOf(FormulaEvaluator.stringify(_arg(a, 1)));
    }
    final List<Object?> items = List<Object?>.of(_values(_arg(a, 0), null));
    final List<Object?> rest = a.skip(1).toList();
    final bool predicate = rest.length > 1 || _arg(rest, 0) is _Closure;
    for (int i = 0; i < items.length; i++) {
      if (predicate
          ? _matches(items[i], rest, i)
          : _looseEquals(items[i], _arg(rest, 0))) {
        return i;
      }
    }
    return -1;
  },
  'object': (a) => <String, Object?>{
    for (int i = 0; i + 1 < a.length; i += 2)
      FormulaEvaluator.stringify(a[i]): a[i + 1],
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
  'moveItems': (a) {
    String idOf(Object? v) =>
        FormulaEvaluator.stringify(v is Map && v['id'] != null ? v['id'] : v);
    final Object? idsArg = _arg(a, 1);
    final Set<String> ids = {
      if (idsArg is Iterable)
        for (final Object? v in idsArg) idOf(v)
      else if (idsArg != null)
        idOf(idsArg),
    };
    final Object? changes = _arg(a, 3);
    final List<Object?> moving = [];
    final List<Object?> rest = [];
    for (final Object? item in _values(_arg(a, 0), null)) {
      if (!ids.contains(idOf(item))) {
        rest.add(item);
      } else if (changes is Map && item is Map) {
        moving.add({...item, ...changes});
      } else {
        moving.add(item);
      }
    }
    final String before = FormulaEvaluator.stringify(_arg(a, 2));
    int at = before.isEmpty ? -1 : rest.indexWhere((i) => idOf(i) == before);
    if (at < 0) at = rest.length;
    rest.insertAll(at, moving);
    return rest;
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
  'left': (a) => _substring(_arg(a, 0), 0, _count(_arg(a, 1))),
  'right': (a) {
    final int n = _count(_arg(a, 1));
    return n <= 0 ? '' : _substring(_arg(a, 0), -n, null);
  },
  'toMap': _toMap,
  'unset': (a) =>
      _mapOf(_arg(a, 0))..remove(FormulaEvaluator.stringify(_arg(a, 1))),
  'prepend': (a) => [_arg(a, 1), ..._listOf(_arg(a, 0))],
  'updateWhere': _updateWhere,
  'removeWhere': (a) {
    final List<Object?> rest = a.skip(1).toList();
    return [
      for (final item in _values(_arg(a, 0), null))
        if (!_matches(item, rest)) item,
    ];
  },
  'newId': (a) => _newId(_arg(a, 0)),
  'get': (a) => _member(_arg(a, 0), _arg(a, 1)),
  'number': (a) => _toNum(_arg(a, 0)),
  'alpha': (a) => _alpha(_arg(a, 0), _num(_arg(a, 1))),
  'pad': (a) => FormulaEvaluator.stringify(_arg(a, 0)).padLeft(
    _arg(a, 1) == null ? 2 : _intArg(_arg(a, 1)),
    FormulaEvaluator.stringify(_arg(a, 2) ?? '0'),
  ),
  'text': (a) => FormulaEvaluator.stringify(_arg(a, 0)),
  'isEmpty': (a) => !_truthy(_functions['length']!(a)),
  'isNotEmpty': (a) => _truthy(_functions['length']!(a)),
  // Map and list editing beyond obj/set/concat below, for formulas that build
  // the value a set variable action stores.
  'with': (a) => <Object?, Object?>{
    if (_arg(a, 0) case final Map m) ...m,
    for (int i = 1; i + 1 < a.length; i += 2)
      FormulaEvaluator.stringify(a[i]): a[i + 1],
  },
  'at': (a) {
    final int index = _intArg(_arg(a, 1));
    // indexOf's -1 (not found) reads nothing rather than failing.
    return index < 0 ? null : _values(_arg(a, 0), null).elementAtOrNull(index);
  },
  'flatMap': (a) => [
    for (final v in _values(_arg(a, 0), _arg(a, 1)))
      if (v is Iterable) ...v else ?v,
  ],
  'now': (a) => _dateText(_nowAt(_arg(a, 0))),
  'today': (a) {
    final DateTime now = _nowAt(_arg(a, 0));
    return _dateText(DateTime(now.year, now.month, now.day));
  },
  'wallTime': (a) => _wallTime(_arg(a, 0)),
  'interpolate': _interpolate,
  'runs': _runs,
  'minBy': (a) => _extremeBy(a, max: false),
  'maxBy': (a) => _extremeBy(a, max: true),
  'parseDate': (a) => _dateText(_toDate(_arg(a, 0))),
  'formatDate': (a) => _formatDate(_arg(a, 0), _arg(a, 1)),
  'addMinutes': (a) =>
      _dateText(_shift(_arg(a, 0), minutes: _intArg(_arg(a, 1)))),
  'addHours': (a) => _dateText(_shift(_arg(a, 0), hours: _intArg(_arg(a, 1)))),
  'addDays': (a) => _dateText(_shift(_arg(a, 0), days: _intArg(_arg(a, 1)))),
  'addMonths': (a) =>
      _dateText(_shift(_arg(a, 0), months: _intArg(_arg(a, 1)))),
  'addSeconds': (a) =>
      _dateText(_shift(_arg(a, 0), seconds: _intArg(_arg(a, 1)))),
  'diffSeconds': (a) => _difference(_arg(a, 0), _arg(a, 1))?.inSeconds,
  'formatDuration': (a) => _formatDuration(_arg(a, 0), _arg(a, 1)),
  'diffMinutes': (a) => _difference(_arg(a, 0), _arg(a, 1))?.inMinutes,
  'diffHours': (a) => _difference(_arg(a, 0), _arg(a, 1))?.inHours,
  'diffDays': (a) => _diffDays(_arg(a, 0), _arg(a, 1)),
  'year': (a) => _toDate(_arg(a, 0))?.year,
  'month': (a) => _toDate(_arg(a, 0))?.month,
  'day': (a) => _toDate(_arg(a, 0))?.day,
  'hour': (a) => _toDate(_arg(a, 0))?.hour,
  'minute': (a) => _toDate(_arg(a, 0))?.minute,
  'second': (a) => _toDate(_arg(a, 0))?.second,
  'weekday': (a) => _toDate(_arg(a, 0))?.weekday,
  'daysInMonth': (a) {
    final DateTime? date = _toDate(_arg(a, 0));
    return date == null ? null : DateTime.utc(date.year, date.month + 1, 0).day;
  },
  // Maps: formulas can't write `{...}` literals, so these build and change
  // maps. Each returns a new map and leaves its input alone.
  'obj': (a) => <String, Object?>{
    for (int i = 0; i + 1 < a.length; i += 2)
      FormulaEvaluator.stringify(a[i]): a[i + 1],
  },
  // The first argument that is neither null nor empty text.
  'coalesce': (a) => a.firstWhere(
    (v) => v != null && !(v is String && v.isEmpty),
    orElse: () => null,
  ),
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

/// A lambda argument, `param => body` or `(param, index) => body`.
/// Evaluates to a [_Closure] that list functions call once per item.
class _Lambda extends _Node {
  final String param;
  final String? indexParam;
  final _Node body;

  const _Lambda(this.param, this.indexParam, this.body);

  @override
  Object? eval(FormulaPathResolver resolve) =>
      _Closure(param, indexParam, body, resolve);

  /// The body's paths, except those of the parameters, which aren't
  /// variables.
  @override
  void collectPaths(Set<String> paths) {
    final Set<String> bodyPaths = {};
    body.collectPaths(bodyPaths);
    bool isParam(String path, String? name) =>
        name != null &&
        (path == name ||
            path.startsWith('$name.') ||
            path.startsWith('$name['));
    paths.addAll(
      bodyPaths.where(
        (path) => !isParam(path, param) && !isParam(path, indexParam),
      ),
    );
  }
}

/// An object literal, `{id: 'a', 'full name': n + 1}`.
class _MapLiteral extends _Node {
  final List<(String, _Node)> entries;

  const _MapLiteral(this.entries);

  @override
  Object? eval(FormulaPathResolver resolve) => <String, Object?>{
    for (final (String key, _Node value) in entries) key: value.eval(resolve),
  };

  @override
  void collectPaths(Set<String> paths) {
    for (final (_, _Node value) in entries) {
      value.collectPaths(paths);
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
        // Lists join, and a list plus a value appends it.
        if (a is Iterable) return [...a, if (b is Iterable) ...b else b];
        final num? na = a is String ? null : _toNum(a);
        final num? nb = b is String ? null : _toNum(b);
        if (na != null && nb != null) return _tidy(na + nb);
        // Lists join: [first] + rest.
        if (a is List && b is List) return [...a, ...b];
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
    r'(?:([a-zA-Z_][a-zA-Z0-9_]*)'
    r'|\(\s*([a-zA-Z_][a-zA-Z0-9_]*)\s*(?:,\s*([a-zA-Z_][a-zA-Z0-9_]*)\s*)?\))'
    r'\s*=>',
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
  /// (also written `(item) => expression`, or `(item, index) => expression`
  /// to read the item's index).
  _Node _argument() {
    _skip();
    final Match? head = _lambdaHead.matchAsPrefix(source, pos);
    if (head == null) return _ternary();
    pos = head.end;
    return _Lambda(head[1] ?? head[2]!, head[3], _ternary());
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

  /// An object literal's key: a name or quoted text.
  String _key() {
    _skip();
    if (pos < source.length && (source[pos] == "'" || source[pos] == '"')) {
      final int end = source.indexOf(source[pos], pos + 1);
      if (end < 0) throw FormatException('Unclosed text', source, pos);
      final String key = source.substring(pos + 1, end);
      pos = end + 1;
      return key;
    }
    final Match? name = _identifier.matchAsPrefix(source, pos);
    if (name == null) throw FormatException('Expected a key', source, pos);
    pos = name.end;
    return name[0]!;
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

    if (char == '{') {
      pos++;
      final List<(String, _Node)> entries = [];
      if (!_eat('}')) {
        do {
          final String key = _key();
          _expect(':');
          entries.add((key, _ternary()));
        } while (_eat(','));
        _expect('}');
      }
      return _MapLiteral(entries);
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
