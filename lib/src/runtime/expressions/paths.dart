// The `${...}` syntax and value paths (`user.name`, `cart[0].qty`,
// `title.length`): how an expression names a value and how a path walks
// into it.
import 'dart:convert';

import 'package:characters/characters.dart';

import 'formula.dart';
import 'formula_clock.dart';

/// Every `${...}` in a text: a formula (`${= ...}`, braces of its object
/// literals included) or a path (`${user.name}`).
final RegExp expressionSyntax = RegExp(
  r'(?<!\\)\$\{(?<value>=' + _formulaBody + r'|[^}]+)\}',
);

const String _atom = r'''[^{}'"]|'[^']*'|"[^"]*"''';
const String _body0 = '(?:$_atom)*';
const String _body1 = '(?:$_atom|\\{$_body0\\})*';
const String _body2 = '(?:$_atom|\\{$_body1\\})*';
const String _formulaBody = '(?:$_atom|\\{$_body2\\})*';

/// A `${path}`: a name, then `[n]` indices and `.key`s.
final RegExp pathSyntax = RegExp(
  r'(?<!\\)\$\{(?<value>(?<name>[a-zA-Z][a-zA-Z0-9_]*)((?<accessor>(?:\[\d+\])+)?(?:\.(?<path>[a-zA-Z]+[a-zA-Z0-9_]*(?:\[\d+\])*))*)?)\}',
);

/// A text that is exactly one `${path}`.
final RegExp _exactPath = RegExp(r'^\s*\$\{([^{}]+)\}\s*$');

/// The path of [text] when it is exactly one `${path}` (not a formula).
String? exactPath(String text) {
  final m = _exactPath.firstMatch(text);
  if (m == null) return null;
  final p = m[1]!.trim();
  return p.startsWith('=') ? null : p;
}

/// What a `${path}` that reads nothing becomes in a text.
enum NullSubstitution {
  /// Nothing (a running app).
  emptyString,

  /// The `${path}` stays as written.
  noChange,

  /// The text `null`.
  nullValue,
}

/// A path: a root name and the keys after it (`String` keys, `int`
/// indices).
final class ValuePath {
  const ValuePath(this.root, this.keys);

  final String root;
  final List<Object> keys;

  static final Map<String, ValuePath?> _cache = {};
  static final RegExp _token = RegExp(r'''\.?\s*([A-Za-z_$][\w$]*)|\[\s*(\d+)\s*\]|\[\s*'([^']*)'\s*\]|\[\s*"([^"]*)"\s*\]''');

  /// Parses `a.b[0]['c d']`; null when [path] isn't a plain path (an
  /// index by a variable, `pal[item.key]`, is a formula).
  static ValuePath? parse(String path) {
    final key = path.trim();
    if (_cache.containsKey(key)) return _cache[key];
    ValuePath? out;
    final keys = <Object>[];
    var pos = 0;
    var ok = key.isNotEmpty;
    while (ok && pos < key.length) {
      final m = _token.matchAsPrefix(key, pos);
      if (m == null || m.end == pos) {
        ok = false;
        break;
      }
      if (pos == 0 && (m[1] == null || key.startsWith('.'))) {
        ok = false;
        break;
      }
      keys.add(m[1] ?? (m[2] != null ? int.parse(m[2]!) : (m[3] ?? m[4])!));
      pos = m.end;
    }
    if (ok && keys.isNotEmpty) out = ValuePath(keys.first as String, keys.sublist(1));
    if (_cache.length > 4000) _cache.clear();
    return _cache[key] = out;
  }

  /// The value at this path's keys, starting from [value] (the root's).
  Object? readFrom(Object? value) {
    var v = value;
    for (final k in keys) {
      if (v == null) return null;
      v = member(v, k);
    }
    return v;
  }

  @override
  String toString() => [root, ...keys.map((k) => k is int ? '[$k]' : k)].join('.');
}

/// [key] of [value]: a map's key, a list's index (or `first`/`last`), a
/// text's character, or a computed property (`length`, `isEmpty`,
/// `upcase`, `isEven`, `timeAgo`...). A map's own key wins over a computed
/// property of the same name.
Object? member(Object? value, Object key) {
  switch (value) {
    case null:
      return null;
    case final Map<Object?, Object?> m:
      if (m.containsKey(key)) return m[key];
      if (key is int && m.containsKey('$key')) return m['$key'];
      break;
    case final List<Object?> l:
      if (key is int) return key >= 0 && key < l.length ? l[key] : null;
      if (int.tryParse('$key') case final int i) return i >= 0 && i < l.length ? l[i] : null;
      if (key == 'first') return l.isEmpty ? null : l.first;
      if (key == 'last') return l.isEmpty ? null : l.last;
    case final String s:
      if (key is int) {
        final chars = s.characters;
        return key >= 0 && key < chars.length ? chars.elementAt(key) : null;
      }
  }
  if (key is! String) return null;
  return computedProperty(value, key);
}

/// The computed properties a value has.
Object? computedProperty(Object value, String name) => switch (value) {
      final String s => switch (name) {
          'length' => s.length,
          'isEmpty' => s.isEmpty,
          'isNotEmpty' => s.isNotEmpty,
          'isBlank' => s.trim().isEmpty,
          'upcase' => s.toUpperCase(),
          'downcase' => s.toLowerCase(),
          'capitalize' => s.characters.isEmpty
              ? s
              : s.characters.first.toUpperCase() + s.characters.skip(1).string.toLowerCase(),
          'initial' => s.trim().isEmpty ? '' : s.trim().characters.first.toUpperCase(),
          'timeAgo' => DateTime.tryParse(s)?.let(formatTimeAgo),
          'date' => DateTime.tryParse(s)?.let(formatDay),
          _ => null,
        },
      final int i => switch (name) {
          'isEven' => i.isEven,
          'isOdd' => i.isOdd,
          'isFinite' => true,
          'isInfinite' => false,
          'isNegative' => i.isNegative,
          'isPositive' => !i.isNegative,
          _ => null,
        },
      final double d => switch (name) {
          'isFinite' => d.isFinite,
          'isInfinite' => d.isInfinite,
          'isNegative' => d.isNegative,
          'isPositive' => !d.isNegative,
          'isNaN' => d.isNaN,
          'whole' => d.isFinite ? d.toInt() : null,
          'floor' => d.isFinite ? d.floor() : null,
          'ceil' => d.isFinite ? d.ceil() : null,
          _ => null,
        },
      final bool b => name == 'toggled' ? !b : null,
      final DateTime t => switch (name) {
          'timeAgo' => formatTimeAgo(t),
          'date' => formatDay(t),
          _ => null,
        },
      final Map<Object?, Object?> m => switch (name) {
          'length' => m.length,
          'isEmpty' => m.isEmpty,
          'isNotEmpty' => m.isNotEmpty,
          'keys' => m.keys.toList(),
          'values' => m.values.toList(),
          _ => null,
        },
      final List<Object?> l => switch (name) {
          'length' => l.length,
          'isEmpty' => l.isEmpty,
          'isNotEmpty' => l.isNotEmpty,
          _ => null,
        },
      _ => null,
    };

const List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', //
];

/// `Mar 4, 2026`.
String formatDay(DateTime date) {
  final local = date.toLocal();
  return '${_months[local.month - 1]} ${local.day}, ${local.year}';
}

/// `Just now`, `5 min ago`, `2 hours ago`, `3 days ago`, then [formatDay].
String formatTimeAgo(DateTime date, {DateTime? now}) {
  final diff = (now ?? FormulaClock.now()).difference(date);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inHours < 1) return '${diff.inMinutes} min ago';
  if (diff.inDays < 1) return '${diff.inHours} ${diff.inHours == 1 ? 'hour' : 'hours'} ago';
  if (diff.inDays < 7) return '${diff.inDays} ${diff.inDays == 1 ? 'day' : 'days'} ago';
  return formatDay(date);
}

/// [value] as a `${path}` puts it in a text: lists and maps as JSON, a
/// whole number without decimals (3, not 3.0: what a formula and the web
/// print), the rest as Dart prints it.
String pathText(Object? value) => switch (value) {
      null => '',
      List() || Map() => _json(value),
      final double d when d.isFinite && d == d.roundToDouble() && d.abs() < 1e15 => d.toInt().toString(),
      _ => value.toString(),
    };

/// [value] as a formula puts it in a text ([FormulaEvaluator.stringify]).
String formulaText(Object? value) => FormulaEvaluator.stringify(value);

String _json(Object value) {
  try {
    return jsonEncode(value, toEncodable: (v) => v.toString());
  } catch (_) {
    return value.toString();
  }
}

/// [text] read loosely as a value: `null` and empty text are null, numbers
/// are numbers, `true`/`false` booleans, JSON lists and objects are
/// decoded; anything else stays text.
Object? parseLoose(String text) {
  if (text == 'null' || text.isEmpty) return null;
  final n = num.tryParse(text);
  if (n != null) return n is double && n == n.roundToDouble() && !text.contains('.') ? n.toInt() : n;
  final lower = text.toLowerCase();
  if (lower == 'true') return true;
  if (lower == 'false') return false;
  final t = text.trimLeft();
  if (t.startsWith('[') || t.startsWith('{')) {
    try {
      final v = jsonDecode(text);
      if (v is List || v is Map) return v;
    } catch (_) {}
  }
  return text;
}

extension<T> on T {
  R let<R>(R Function(T) f) => f(this);
}
