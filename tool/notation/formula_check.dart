// The formulas of a document the engine cannot parse (test 10's kanban
// board: `sortBy(filter(…))),x=>…)` drew no cards, with no word). The render
// reports each (formula_invalid, on its node); `notation.sh expand` says each
// where it was written.
import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/src/runtime/expressions/formula.dart' show FormulaEvaluator;

/// What `expand` says of the formulas of [doc] that do not parse, each at
/// where it was written: the first of [texts] (a path and its text) that
/// holds the expression's start, at its line and column (the expansion
/// rewrites some names, `col.id` to `item.id`, so a shorter start is tried
/// too), else the node. A line in [said] (`path:line`, already given an
/// issue, as its brackets) is not said again.
List<String> formulaNotes(api.Json doc, Map<String, String> texts, {Set<String> said = const {}}) {
  final out = <String>[];
  for (final f in unreadableFormulas(doc)) {
    String? where;
    for (final n in [40, 24, 12]) {
      final probe = f.expression.length <= n ? f.expression : f.expression.substring(0, n);
      for (final t in texts.entries) {
        final at = t.value.indexOf(probe);
        if (at < 0) continue;
        final before = t.value.substring(0, at);
        final line = '\n'.allMatches(before).length + 1;
        where = '${t.key}:$line:${at - before.lastIndexOf('\n')}';
        break;
      }
      if (where != null) break;
    }
    if (where != null && said.contains(where.substring(0, where.lastIndexOf(':')))) continue;
    out.add('${where ?? 'node ${f.node}'}: the formula does not parse, so ${f.node.startsWith('variable ') ? f.node : 'node ${f.node} (${f.field})'} gets nothing from it: '
        '${f.why}. The expression: ${f.expression}');
  }
  return out;
}

/// The formulas of [doc] the engine cannot parse: each `${…}` (or
/// `${= …}`) in a node's strings, by the node and the field it is in, and
/// each variable's `formula`, with why it does not parse.
List<({String node, String field, String expression, String why})> unreadableFormulas(api.Json doc) {
  final out = <({String node, String field, String expression, String why})>[];
  final seen = <String>{};
  void check(String node, String field, String expression) {
    final e = expression.trim();
    if (e.isEmpty || FormulaEvaluator.parses(e) || !seen.add('$node|$e')) return;
    final why = FormulaEvaluator.errorOf(e, functionNames: FormulaEvaluator.functions) ?? 'it does not parse';
    out.add((node: node, field: field, expression: e.length > 300 ? '${e.substring(0, 297)}...' : e, why: why));
  }

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
