// The formulas of a document the engine cannot parse (test 10's kanban
// board: `sortBy(filter(…))),x=>…)` drew no cards, with no word). The render
// reports each (formula_invalid, on its node); `notation.sh expand` says each
// where it was written.
import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/src/runtime/expressions/formula.dart' show FormulaEvaluator;
import 'package:codelessly_sdk/src/session/formula_check.dart';

export 'package:codelessly_sdk/src/session/formula_check.dart';

/// What `expand` says of the formulas of [doc] that do not parse, each at
/// where it was written: the first of [texts] (a path and its text) that
/// holds the expression's start, at its line and column (the expansion
/// rewrites some names, `col.id` to `item.id`, so a shorter start is tried
/// too), else the node. A line in [said] (`path:line`, already given an
/// issue, as its brackets) is not said again.
List<String> formulaNotes(api.Json doc, Map<String, String> texts, {Set<String> said = const {}, Map<String, api.Json> site = const {}}) {
  final out = <String>[];
  for (final f in unreadableFormulas(doc)) {
    final where = formulaWhereWritten(f.expression, texts);
    if (where != null && said.contains(where.substring(0, where.lastIndexOf(':')))) continue;
    out.add('${where ?? 'node ${f.node}'}: the formula does not parse, so ${f.node.startsWith('variable ') ? f.node : 'node ${f.node} (${f.field})'} gets nothing from it: '
        '${f.why}. The expression: ${f.expression}');
  }
  // A call to a function the formulas do not have (`str(badge)`,
  // `substr(name,0,5)`, `has(reply,'id')`): the formula parses, and gives
  // nothing when it runs. Only the render said so (NOCD parts 01, 03, 11).
  for (final f in unknownFunctionCalls(doc, site: site)) {
    final where = formulaWhereWritten(f.expression, texts);
    if (where != null && said.contains(where.substring(0, where.lastIndexOf(':')))) continue;
    final near = nearestFunctions(f.name);
    out.add('${where ?? 'node ${f.node}'}: the formula calls ${f.name}(…), a function the formulas do not have, so ${f.node.startsWith('variable ') ? f.node : 'node ${f.node} (${f.field})'} gets nothing from it'
        '${near.isEmpty ? '' : '. Did you mean ${near.join(', ')}?'} The expression: ${f.expression}');
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
