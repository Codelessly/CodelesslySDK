// What a laid-out UI shows, checked after a frame: a document can be valid
// and still show nothing. Recorded generations did: a canvas replaced by a
// column, a card whose only container was rejected, texts bound to a style
// that drew them transparent, a list whose data was not a list. Each check
// reads the render tree a view built and reports, as edit diagnostics a
// model acts on in its retry, what a reader would see wrong:
//
// * `empty_view`: the canvas laid out with no size, or with no text, icon,
//   image or control showing (or there is no canvas root);
// * `list_empty`: a list that shows no items while its data is not a list,
//   has no item template, or is empty while the list it reads is not;
// * `empty_label`: a control or component whose label resolved to nothing;
// * `expression_not_evaluated`: a text that shows `${` on screen;
// * `text_no_color`: a text with no colour, or a transparent one;
// * `component_empty`: a component call that rendered nothing.
//
// The text checks are shared with the render command (tool/render), which
// reports the same codes for a site.
import 'package:codelessly_api/core.dart';
import 'package:flutter/rendering.dart';

import '../render/components.dart' show ComponentInstance, componentInstanceOf;
import '../render/contracts.dart' show ExpressionValues;
import '../render/node_tree.dart' show NodeBox;
import '../runtime/expressions/formula.dart' show FormulaEvaluator;

/// What a text paragraph shows wrong, with the text's [name] (a node id or
/// an instance path) in the message: `expression_not_evaluated` (it shows
/// `${`) and `text_no_color` (no colour, or a transparent one). [noColor]
/// says what a text with no colour looks like where it renders.
List<({String code, String message})> paragraphIssues(RenderParagraph p, String name,
    {String noColor = 'it is painted white (invisible on a light background)'}) {
  final text = p.text.toPlainText();
  if (text.trim().isEmpty) return const [];
  final short = text.length > 30 ? '${text.substring(0, 30)}...' : text;
  final out = <({String code, String message})>[];
  if (text.contains(r'${')) {
    out.add((
      code: EditCodes.expressionNotEvaluated.name,
      message: 'Text "$name" shows "$short" on screen: its expression did not evaluate. Check the formula (names, functions, '
          'quotes); a binding of "props.text" or "props.runs" must not also be written as text, and a "\${...}" inside a formula '
          'is not read.',
    ));
  }
  var colorless = false, transparent = true, any = false;
  final rootStyle = p.text.style;
  p.text.visitChildren((span) {
    if (span is TextSpan && (span.text?.trim().isNotEmpty ?? false)) {
      any = true;
      final style = span.style;
      final color = style?.color ?? rootStyle?.color;
      final foreground = style?.foreground ?? rootStyle?.foreground;
      if (color == null && foreground == null) colorless = true;
      if (foreground != null || (color != null && color.a > 0.01)) transparent = false;
    }
    return true;
  });
  if (colorless && rootStyle?.color == null && rootStyle?.foreground == null) {
    out.add((code: EditCodes.textNoColor.name, message: 'Text "$name" ("$short") has no color, so $noColor: set props.style.color.'));
  } else if (any && transparent) {
    out.add((
      code: EditCodes.textNoColor.name,
      message: 'Text "$name" ("$short") is drawn in a transparent colour: nothing of it shows. A colour with alpha 0, or a name the '
          'theme does not have: write a colour the theme names, or "#FF111827".',
    ));
  }
  return out;
}

/// What the view rendered under [root] shows wrong of [document] (see the
/// file's comment). [canvas]: the canvas the view shows (null: none was
/// found); [pending]: the ids the document lists that never arrived.
List<EditDiagnostic> shownDiagnostics(RenderObject root, LayoutDocument document, {String? canvas, Set<String> pending = const {}}) {
  final out = <EditDiagnostic>[];
  final seen = <(String, String)>{};
  void report(EditCode code, String path, String message, {String? nodeId, bool? error}) {
    if (!seen.add((code.name, path))) return;
    out.add(EditDiagnostic(op: -1, code: code.name, error: error ?? code.error, path: path, message: message, nodeId: nodeId));
  }

  String nodePath(String id, [String? field]) {
    final p = editPointer('/nodes', id);
    return field == null ? p : editPointer(p, field);
  }

  // The canvas the view shows, and whether anything in it shows.
  NodeBox? canvasBox;
  var showing = 0;
  // Per component call (outermost instance root): whether anything in it shows.
  final calls = <String, ({NodeBox box, int showing})>{};
  String nameOf(NodeBox b) => componentInstanceOf(b.instance) != null ? b.tree.pathOf(b.id, b.instance) : b.id;

  // The topmost call an instance root belongs to (its document's call).
  String? callOf(NodeBox b) {
    ComponentInstance? top = componentInstanceOf(b.instance);
    if (top == null) return null;
    for (var outer = componentInstanceOf(top.outer); outer != null; outer = componentInstanceOf(outer.outer)) {
      top = outer;
    }
    return top!.call;
  }

  void visit(RenderObject o, bool shown, NodeBox? box) {
    if (o is NodeBox) {
      final n = o.node;
      final laid = o.hasSize && o.size.width > 0.5 && o.size.height > 0.5;
      // Checked when its parent shows and it is not hidden (a list with no
      // items may lay out with no height: that is what is reported).
      final placed = shown && o.drawn;
      shown = placed && laid;
      box = o;
      if (n != null && n.type == CanvasProps.spec.type && o.instance == null && (canvas == null || o.id == canvas)) canvasBox ??= o;
      if (n != null && placed) _checkNode(o, n, document, report, nodePath, nameOf);
      // A leaf that is not a container or a text: an icon, an image, a
      // control, a chart.
      if (shown && n != null && o.source.node(o.id)?.childIds.isEmpty != false && !_quiet.contains(n.type) && n.type != 'text') {
        showing++;
        final call = callOf(o);
        if (call != null) calls[call] = (box: calls[call]?.box ?? o, showing: (calls[call]?.showing ?? 0) + 1);
      }
      final call = callOf(o);
      if (call != null && shown && o.tree.isInstanceRoot(o.id, o.instance)) calls.putIfAbsent(call, () => (box: o, showing: 0));
    }
    if (o is RenderParagraph && shown && box != null) {
      final issues = paragraphIssues(o, nameOf(box), noColor: 'nothing of it may show');
      final text = o.text.toPlainText().trim();
      if (text.isNotEmpty && !issues.any((i) => i.code == EditCodes.textNoColor.name)) {
        showing++;
        final call = callOf(box);
        if (call != null) calls[call] = (box: calls[call]?.box ?? box, showing: (calls[call]?.showing ?? 0) + 1);
      }
      // A component's own texts are its definition's: reported on the call.
      if (componentInstanceOf(box.instance) == null) {
        for (final i in issues) {
          report(EditCode(i.code, ''), nodePath(box.id, i.code == EditCodes.textNoColor.name ? 'props/style' : 'props/text'), i.message,
              nodeId: box.id, error: false);
        }
      }
    }
    o.visitChildren((c) => visit(c, shown, box));
  }

  visit(root, true, null);

  // The view itself.
  final c = canvasBox;
  final canvasRoots = [for (final r in document.roots) if (document[r]?.type == CanvasProps.spec.type) r];
  // Why a canvas shows nothing, from its document.
  String why(String id) {
    final body = [...?document[id]?.childIds];
    final missing = [for (final b in body) if (pending.contains(b) || document[b] == null) b];
    return missing.isNotEmpty
        ? 'its content ${missing.map((m) => '"$m"').join(', ')} never arrived (its op was rejected or not sent): send it'
        : body.isEmpty
            ? 'it has no body: set a column in its "body" slot'
            : pending.isNotEmpty
                ? 'what it holds is pending (${pending.take(8).map((m) => '"$m"').join(', ')}): send those nodes'
                : 'everything in it is hidden, empty or has no size: check "visible" bindings, the variables they read, and sizes';
  }

  if (c == null) {
    if (canvasRoots.isNotEmpty) {
      // Held back: a canvas whose content has not arrived is not shown.
      final r = canvas ?? canvasRoots.first;
      report(EditCodes.emptyView, nodePath(r), 'The UI shows nothing: canvas "$r" shows no content; ${why(r)}.', nodeId: r);
    } else if (document.roots.isNotEmpty) {
      final r = document.roots.first;
      report(EditCodes.emptyView, nodePath(r, 'type'),
          'The UI shows nothing: no root is a canvas ("$r" is a ${document[r]?.type ?? 'pending node'}), and a view shows a canvas. '
          'Make "$r" a canvas again ({"op": "set", "id": "$r", "node": {"type": "canvas", "slots": {"body": "<content id>"}, ...}}) '
          'and put the content in its body.',
          nodeId: r);
    }
  } else if (!c.hasSize || c.size.width < 0.5 || c.size.height < 0.5 || showing == 0) {
    final size = c.hasSize ? '${c.size.width.toStringAsFixed(0)} × ${c.size.height.toStringAsFixed(0)}' : 'with no size';
    report(EditCodes.emptyView, nodePath(c.id),
        'The UI shows nothing: canvas "${c.id}" laid out $size with no text, icon, image or control showing; ${why(c.id)}.',
        nodeId: c.id);
  }

  // Calls that rendered nothing (and their labels, checked in _checkNode).
  for (final e in calls.entries) {
    if (e.value.showing > 0 || out.any((d) => d.nodeId == e.key && d.code == EditCodes.emptyLabel.name)) continue;
    final b = e.value.box;
    final type = componentInstanceOf(b.instance)?.component;
    if (!b.drawn || !b.hasSize) continue;
    final sized = b.size.width > 0.5 && b.size.height > 0.5;
    report(EditCodes.componentEmpty, nodePath(e.key),
        '"${e.key}" ($type) rendered ${sized ? 'with nothing visible in it' : 'with no size (${b.size.width.toStringAsFixed(0)} × ${b.size.height.toStringAsFixed(0)})'}: '
        '${sized ? 'give it the parameters it shows (its label, title, text or items; ui_docs "$type" lists them)' : 'give it a width and a height, or check that its parent has room'}.',
        nodeId: e.key);
  }
  final missing = _treeOf(root)?.tree.components?.missing;
  for (final e in (missing ?? const <String, Set<String>>{}).entries) {
    for (final path in e.value) {
      report(EditCodes.componentEmpty, nodePath(path.split('/').last),
          '"$path" calls ${e.key}, which rendered without its definition (an empty box): use a component the design system has.',
          nodeId: path.split('/').last);
    }
  }
  return out;
}

/// Containers and decoration: a leaf of these types shows nothing a reader
/// takes for content (a spacer, an empty box or row).
const _quiet = {'canvas', 'box', 'spacer', 'column', 'row', 'stack', 'wrap', 'listView', 'gridView', 'pageView', 'tableView', 'container', 'divider'};

const _repeaters = {'listView', 'gridView', 'pageView', 'tableView'};

/// The labels a control or component call shows (the first one it
/// declares): what `empty_label` checks.
const _labelProps = ['label', 'title', 'text'];

NodeBox? _treeOf(RenderObject root) {
  NodeBox? found;
  void visit(RenderObject o) {
    if (found != null) return;
    if (o is NodeBox) {
      found = o;
      return;
    }
    o.visitChildren(visit);
  }

  visit(root);
  return found;
}

void _checkNode(NodeBox b, Node n, LayoutDocument document, void Function(EditCode, String, String, {String? nodeId, bool? error}) report,
    String Function(String, [String?]) nodePath, String Function(NodeBox) nameOf) {
  // Only the document's own nodes (a component's are its definition's).
  if (componentInstanceOf(b.instance) case final ComponentInstance ci) {
    // A component call: its label, read on the call as bound.
    if (!b.tree.isInstanceRoot(b.id, b.instance) || componentInstanceOf(ci.outer) != null) return;
    final call = b.tree.resolveBound(ci.call, instance: ci.outer)?.node;
    final written = b.tree.sourceOf(ci.outer).node(ci.call);
    if (call != null && written != null) _checkLabel(ci.call, call, written, report, nodePath);
    return;
  }
  final written = b.source.node(b.id);
  if (written == null) return;
  _checkLabel(b.id, n, written, report, nodePath);
  if (_repeaters.contains(n.type)) _checkList(b, n, written, document, report, nodePath);
}

void _checkLabel(String id, Node shown, Node written, void Function(EditCode, String, String, {String? nodeId, bool? error}) report,
    String Function(String, [String?]) nodePath) {
  final declared = shown.spec?.props.map((p) => p.key).toSet() ?? const <String>{};
  final key = _labelProps.where(declared.contains).firstOrNull;
  if (key == null || shown.type == 'text') return;
  final w = written.toJson();
  final writtenValue = readMap(w['props'])?[key];
  final bound = readMap(w['bind'])?['props.$key'];
  if (writtenValue == null && bound == null) return;
  if (writtenValue is String && writtenValue.trim().isEmpty && bound == null) return; // written empty on purpose
  final value = readMap(shown.toJson()['props'])?[key];
  final text = value is String ? value : (value == null ? '' : '$value');
  if (text.contains(r'${')) {
    report(EditCodes.expressionNotEvaluated, nodePath(id, 'props/$key'),
        '"$id" (${shown.type}) shows its $key as "$text": the expression did not evaluate. Check the formula; an expression that '
        'computes the $key goes in "bind": {"props.$key": "\${...}"}.',
        nodeId: id);
  } else if (text.trim().isEmpty) {
    final source = bound ?? writtenValue;
    report(EditCodes.emptyLabel, nodePath(id, 'props/$key'),
        '"$id" (${shown.type}) shows an empty $key: "$source" gave nothing. Check the names it reads (a variable that is not '
        'declared, an item field outside a list), or write the $key as text.',
        nodeId: id);
  }
}

void _checkList(NodeBox b, Node shown, Node written, LayoutDocument document,
    void Function(EditCode, String, String, {String? nodeId, bool? error}) report, String Function(String, [String?]) nodePath) {
  final expression = written.bind['data'];
  if (expression == null) return;
  final id = b.id;
  final props = readMap(shown.toJson()['props']) ?? const {};
  final count = props[shown.type == 'tableView' ? 'rowCount' : 'itemCount'];
  if (written.childIds.isEmpty) {
    report(EditCodes.listEmpty, nodePath(id, 'children'),
        'List "$id" has data ($expression) but no item template: its first child is drawn once per item. Add one: '
        '{"op": "set", "id": "<item id>", "parent": "$id", "node": {...}} reading \${item.<field>}.',
        nodeId: id);
    return;
  }
  if (count is! num || count > 0) return;
  final values = b.tree.bindings?.valuesFor(b.source, b.id, b.instance);
  if (values is! ExpressionValues) return;
  Object? data;
  try {
    data = values.evaluate(expression);
  } catch (_) {
    data = null;
  }
  String describe(Object? v) => switch (v) {
        null => 'nothing (a name that is not declared, or a formula that fails)',
        final String s => 'the text "${s.length > 40 ? '${s.substring(0, 40)}...' : s}"',
        final Map _ => 'an object (a map), not a list',
        _ => 'a ${v.runtimeType}',
      };
  if (data is! List) {
    report(EditCodes.listEmpty, nodePath(id, 'bind/data'),
        'List "$id" shows no items: its data $expression gives ${describe(data)}. Bind "data" to a list variable (or a formula '
        'that gives a list).',
        nodeId: id);
    return;
  }
  if (data.isNotEmpty) {
    report(EditCodes.listEmpty, nodePath(id, 'bind/data'),
        'List "$id" shows no items though its data $expression has ${data.length}: check its item template "${written.childIds.first}" '
        '(its size, its "visible" binding).',
        nodeId: id);
    return;
  }
  // Empty: is it computed from a list that is not?
  final source = _nonEmptySource(values, expression, document);
  if (source != null) {
    report(EditCodes.listEmpty, nodePath(id, 'bind/data'),
        'List "$id" shows no items: $expression is empty while ${source.$1} has ${source.$2}. If a filter should keep them, read '
        'each item\'s fields through a lambda: filter(${source.$1}, r => r.status == x), not filter(${source.$1}, status == x).',
        nodeId: id, error: false);
  }
}

/// A non-empty list (its name and length) that [expression] reads, directly
/// or through the formula of a computed variable it reads.
(String, int)? _nonEmptySource(ExpressionValues values, String expression, LayoutDocument document) {
  final formulas = <String, String>{
    for (final scope in (readMap(document.extra['variables']) ?? const {}).values)
      for (final v in readList(scope) ?? const [])
        if (readMap(v) case final Map m when m['formula'] is String && m['name'] is String) m['name'] as String: m['formula'] as String,
  };
  final seen = <String>{};
  final names = [...values.namesRead(expression)];
  while (names.isNotEmpty) {
    final name = names.removeLast();
    if (!seen.add(name)) continue;
    final v = values.read(name);
    if (v is List && v.isNotEmpty) return (name, v.length);
    final f = formulas[name];
    if (f != null) names.addAll(FormulaEvaluator.referencedPaths(f).map((p) => p.split(RegExp(r'[.\[]')).first));
  }
  return null;
}
