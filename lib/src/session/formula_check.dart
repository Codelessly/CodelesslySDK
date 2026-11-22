// The formulas of a document the engine cannot read: one that does not
// parse (`sortBy(filter(…))),x=>…)`: a list with no rows, a text with no
// value, with no word at run time) and one that calls a function the
// formulas do not have. A render reports each (formula_invalid), `expand`
// says each where it was written, and an editor says each of the text it
// reads.
import 'package:codelessly_api/core.dart' as api;

import '../runtime/expressions/formula.dart' show FormulaEvaluator;

/// Where [expression] was written: the first of [texts] (a path and its
/// text) that holds its start, at its line and column (the expansion
/// rewrites some names, `col.id` to `item.id`, so a shorter start is tried
/// too); null when none does.
String? formulaWhereWritten(String expression, Map<String, String> texts) {
  for (final n in [40, 24, 12]) {
    final probe = expression.length <= n ? expression : expression.substring(0, n);
    for (final t in texts.entries) {
      final at = t.value.indexOf(probe);
      if (at < 0) continue;
      final before = t.value.substring(0, at);
      final line = '\n'.allMatches(before).length + 1;
      return '${t.key}:$line:${at - before.lastIndexOf('\n')}';
    }
  }
  return null;
}

/// The calls in [doc]'s formulas to a name that is neither one of the
/// engine's functions nor a variable of the document or of [site] (a page's
/// own function, `state digits(v)=…`, is a variable), each formula once.
List<({String node, String field, String expression, String name})> unknownFunctionCalls(api.Json doc, {Map<String, api.Json> site = const {}}) {
  final known = <String>{...site.keys};
  final variables = doc['variables'];
  for (final scope in variables is Map ? variables.values : const []) {
    for (final v in scope is List ? scope : const []) {
      if (v is Map && v['name'] is String) known.add(v['name'] as String);
    }
  }
  final out = <({String node, String field, String expression, String name})>[];
  final seen = <String>{};
  for (final f in formulasOf(doc)) {
    final e = f.expression.trim();
    if (e.isEmpty || !FormulaEvaluator.parses(e)) continue;
    for (final name in FormulaEvaluator.userFunctionCalls(e)) {
      if (known.contains(name) || name.contains('.') || !seen.add('$name|$e')) continue;
      out.add((node: f.node, field: f.field, expression: e.length > 300 ? '${e.substring(0, 297)}...' : e, name: name));
    }
  }
  return out;
}

/// Up to three of the engine's functions nearest [name]: those whose name
/// holds it or is held by it, then the fewest edits away (at most a third
/// of its length, and 3).
List<String> nearestFunctions(String name) {
  final lower = name.toLowerCase();
  int edits(String a, String b) {
    var prev = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      final cur = <int>[i];
      for (var j = 1; j <= b.length; j++) {
        cur.add([prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1)].reduce((x, y) => x < y ? x : y));
      }
      prev = cur;
    }
    return prev[b.length];
  }

  // Other languages' names for what the formulas call otherwise.
  const other = {
    'str': 'text', 'tostring': 'text', 'totext': 'text', 'string': 'text', 'substr': 'substring', 'len': 'length',
    'has': 'contains', 'haskey': 'contains', 'int': 'number', 'parseint': 'number', 'parsefloat': 'number', 'tonumber': 'number',
  };
  final scored = <(int, String)>[
    if (other[lower] case final String o when FormulaEvaluator.functions.contains(o)) (-1, o),
  ];
  for (final f in FormulaEvaluator.functions) {
    if (scored.any((s) => s.$2 == f)) continue;
    final l = f.toLowerCase();
    if (lower.length >= 3 && (l.contains(lower) || lower.contains(l) && l.length >= 3)) {
      scored.add((0, f));
      continue;
    }
    final d = edits(lower, l);
    if (d <= 3 && d <= (lower.length / 3).ceil()) scored.add((d, f));
  }
  scored.sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.length.compareTo(b.$2.length));
  return [for (final s in scored.take(3)) s.$2];
}

/// The formulas of [doc] the engine cannot parse: each `${…}` (or
/// `${= …}`) in a node's strings, by the node and the field it is in, and
/// each variable's `formula`, with why it does not parse.
List<({String node, String field, String expression, String why})> unreadableFormulas(api.Json doc) {
  final out = <({String node, String field, String expression, String why})>[];
  final seen = <String>{};
  for (final f in formulasOf(doc)) {
    final e = f.expression.trim();
    if (e.isEmpty || FormulaEvaluator.parses(e) || !seen.add('${f.node}|$e')) continue;
    final why = FormulaEvaluator.errorOf(e, functionNames: FormulaEvaluator.functions) ?? 'it does not parse';
    out.add((node: f.node, field: f.field, expression: e.length > 300 ? '${e.substring(0, 297)}...' : e, why: why));
  }
  return out;
}

/// Every formula of [doc]: each `${…}` (or `${= …}`, without its `=`) in a
/// node's strings, by the node and the field it is in, and each variable's
/// `formula` (its node `variable <name>`).
List<({String node, String field, String expression})> formulasOf(api.Json doc) {
  final out = <({String node, String field, String expression})>[];
  void check(String node, String field, String expression) => out.add((node: node, field: field, expression: expression));

  // The `${…}` of [s]: what is between the braces, quotes and nested braces
  // read past.
  void strings(String node, String field, String s) {
    var i = s.indexOf(r'${');
    while (i >= 0) {
      var depth = 0;
      String? quote;
      var end = -1;
      for (var k = i + 1; k < s.length; k++) {
        final c = s[k];
        if (quote != null) {
          if (c == r'\') {
            k++;
          } else if (c == quote) {
            quote = null;
          }
          continue;
        }
        if (c == '"' || c == "'") {
          quote = c;
        } else if (c == '{') {
          depth++;
        } else if (c == '}' && --depth == 0) {
          end = k;
          break;
        }
      }
      if (end < 0) return;
      final inner = s.substring(i + 2, end);
      check(node, field, inner.startsWith('=') ? inner.substring(1) : inner);
      i = s.indexOf(r'${', end + 1);
    }
  }

  void walk(String node, String field, Object? v) {
    if (v is String) {
      if (v.contains(r'${')) strings(node, field, v);
    } else if (v is Map) {
      for (final e in v.entries) {
        walk(node, field.isEmpty ? '${e.key}' : '$field.${e.key}', e.value);
      }
    } else if (v is List) {
      for (final (n, x) in v.indexed) {
        walk(node, '$field[$n]', x);
      }
    }
  }

  for (final e in (api.readMap(doc['nodes']) ?? const {}).entries) {
    walk(e.key, '', e.value);
  }
  final variables = doc['variables'];
  for (final scope in variables is Map ? variables.values : const []) {
    for (final v in scope is List ? scope : const []) {
      if (v is Map && v['formula'] is String) check('variable ${v['name']}', 'formula', v['formula'] as String);
    }
  }
  return out;
}
