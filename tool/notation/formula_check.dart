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
List<String> formulaNotes(api.Json doc, Map<String, String> texts, {Set<String> said = const {}, Map<String, api.Json> site = const {}}) {
  final out = <String>[];
  for (final f in unreadableFormulas(doc)) {
    final where = _whereWritten(f.expression, texts);
    if (where != null && said.contains(where.substring(0, where.lastIndexOf(':')))) continue;
    out.add('${where ?? 'node ${f.node}'}: the formula does not parse, so ${f.node.startsWith('variable ') ? f.node : 'node ${f.node} (${f.field})'} gets nothing from it: '
        '${f.why}. The expression: ${f.expression}');
  }
  // A call to a function the formulas do not have (`str(badge)`,
  // `substr(name,0,5)`, `has(reply,'id')`): the formula parses, and gives
  // nothing when it runs. Only the render said so (NOCD parts 01, 03, 11).
  for (final f in unknownFunctionCalls(doc, site: site)) {
    final where = _whereWritten(f.expression, texts);
    if (where != null && said.contains(where.substring(0, where.lastIndexOf(':')))) continue;
    final near = nearestFunctions(f.name);
    out.add('${where ?? 'node ${f.node}'}: the formula calls ${f.name}(…), a function the formulas do not have, so ${f.node.startsWith('variable ') ? f.node : 'node ${f.node} (${f.field})'} gets nothing from it'
        '${near.isEmpty ? '' : '. Did you mean ${near.join(', ')}?'} The expression: ${f.expression}');
  }
  return out;
}

/// Where [expression] was written: the first of [texts] (a path and its
/// text) that holds its start, at its line and column (the expansion
/// rewrites some names, `col.id` to `item.id`, so a shorter start is tried
/// too); null when none does.
String? _whereWritten(String expression, Map<String, String> texts) {
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

/// What `expand` says of a variable that starts as null with no type and
/// is read by a field (`replyTo.first_name`): null gives a text variable
/// (`VariableType.of`), so the field reads nothing, and a map set into it
/// is kept as its JSON text (the NOCD chat's reply strip drew no name, with
/// no word). [doc]'s own variables (`state replyTo=null`) and the site's
/// ([site]: name to the variable's JSON, as `NotationSite.variables`), each
/// once, at the first node that reads it so.
List<String> nullTextVariableNotes(api.Json doc, {Map<String, api.Json> site = const {}}) {
  bool nullText(Object? v) => v is Map && v['type'] == 'text' && v['value'] == null && (v['formula'] ?? '') == '';
  final own = <String>{}, declared = <String>{};
  final variables = doc['variables'];
  for (final scope in variables is Map ? variables.values : const []) {
    for (final v in scope is List ? scope : const []) {
      if (v is Map) declared.add('${v['name']}');
      if (nullText(v)) own.add('${v['name']}');
    }
  }
  final shared = {for (final e in site.entries) if (!declared.contains(e.key) && nullText(e.value)) e.key};
  if (own.isEmpty && shared.isEmpty) return const [];
  final out = <String>[];
  final said = <String>{};
  for (final f in formulasOf(doc)) {
    for (final path in FormulaEvaluator.referencedPaths(f.expression.trim())) {
      final dot = path.indexOf('.');
      if (dot <= 0) continue;
      final name = path.substring(0, dot);
      final ofPage = own.contains(name);
      if (!ofPage && !shared.contains(name) || !said.add(name)) continue;
      final where = f.node.startsWith('variable ') ? f.node : 'node ${f.node}';
      out.add('${ofPage ? 'state $name=null' : 'the site\'s variable "$name" (null in site.json)'} has no type, so it is a text variable, and $where reads '
          '$path from it: a field of text is nothing, and a map or list set into it is kept as its JSON text. '
          'Say its type: ${ofPage ? 'state $name:map=null (or :list)' : '"$name": {"type": "map", "value": null} (or "list")'}.');
    }
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
