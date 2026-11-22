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
//   has no item template, or is empty while the list it reads is not (a
//   list under another list's row: said once, when every copy is empty);
// * `empty_label`: a control or component whose label resolved to nothing;
// * `expression_not_evaluated`: a text that shows `${` on screen;
// * `value_not_computed`: a text that shows NaN, Infinity, null or a `{name}`
//   left as written;
// * `text_no_color`: a text with no color, or a transparent one;
// * `component_empty`: a component call that rendered nothing.
// * `content_overflows`: a child of a row or a column that reaches past
//   its edge (a warning: it is drawn, clipped or over its neighbor).
// * `low_contrast`: a text drawn in a color too close to the fill it is on
//   to be read (white on a white card, a dark ink on a dark band).
//
// The text checks are shared with the render command (tool/render), which
// reports the same codes for a site.
import 'dart:convert' show jsonEncode;
import 'dart:ui' as ui;

import 'package:codelessly_api/core.dart';
import 'package:flutter/rendering.dart';

import '../render/components.dart' show ComponentInstance, componentInstanceOf;
import '../render/contracts.dart' show ExpressionValues;
import '../render/node_tree.dart' show NodeBox;
import '../runtime/expressions/formula.dart' show FormulaEvaluator;

/// What a text shows when its value did not compute: `NaN`, `Infinity`, a
/// bare `null` or `undefined`, or a `{name}` left as written.
final _brokenValue = RegExp(r'\bNaN\b|\bInfinity\b|(?<![A-Za-z])(?:null|undefined)(?![A-Za-z])|\{[A-Za-z_][A-Za-z0-9_.]*\}');

/// Under this contrast (WCAG's ratio, 1 to 21) a text is not read: white on
/// a white card is 1, a pale grey on white 1.2 to 1.4. (A placeholder's or a
/// disabled label's faint ink is 2 and up: quiet, and meant.)
const double lowContrastBelow = 1.5;

/// What the text [p] of the node [box] is drawn on, when that is known: the
/// nearest fill under it that is one opaque color, with the node that has
/// it. Null where it cannot be told from the tree: a picture or a gradient
/// under it, a Stack (another child may be under the text), a drawing, a
/// translucent fill or an opacity on the way, no fill at all.
({ui.Color color, String id})? groundOfText(NodeBox box) {
  for (RenderObject? o = box.parent; o != null; o = o.parent) {
    if (o is RenderOpacity && o.opacity < 0.99) return null;
    if (o is RenderAnimatedOpacity && o.opacity.value < 0.99) return null;
    if (o is! NodeBox) continue;
    final n = o.node;
    if (n == null) continue;
    if (const {'stack', 'pageView', 'image', 'customPaint'}.contains(n.type)) return null;
    if ((n.behaviors.customPaint?.painter.isNotEmpty ?? false) || (n.behaviors.customPaint?.foregroundPainter.isNotEmpty ?? false)) return null;
    if (n.opacity < 0.99) return null;
    final fills = [for (final f in n.decoration.fills) if (f.visible && f.opacity > 0.02) f];
    if (fills.isEmpty) continue;
    // The topmost fill is what shows.
    final top = fills.last;
    final c = top.color;
    if (c == null || c.name != null) return null;
    final alpha = c.alpha / 255 * top.opacity;
    if (alpha <= 0.02) {
      if (fills.length > 1) return null;
      continue;
    }
    if (alpha < 0.9) return null;
    return (color: ui.Color(0xFF000000 | (c.value & 0xFFFFFF)), id: o.id);
  }
  return null;
}

/// `low_contrast` for the text [p] of the node [box] (named [name] in the
/// message), or null: its color (over its ground, where it is translucent)
/// is too close to the fill it is drawn on ([groundOfText]) to be read.
({String code, String message})? textContrastIssue(NodeBox box, RenderParagraph p, String name) {
  final ink = p.text.style?.color;
  if (ink == null || ink.a < 0.3) return null;
  final ground = groundOfText(box);
  if (ground == null) return null;
  final on = ground.color;
  final shown = ui.Color.alphaBlend(ink, on);
  double lum(ui.Color c) => c.computeLuminance();
  final a = lum(shown), b = lum(on);
  final ratio = a > b ? (a + .05) / (b + .05) : (b + .05) / (a + .05);
  if (ratio >= lowContrastBelow) return null;
  String hex(ui.Color c) => '#${c.toARGB32().toRadixString(16).toUpperCase().padLeft(8, '0')}';
  final text = p.text.toPlainText().trim();
  final short = text.length > 30 ? '${text.substring(0, 30)}…' : text;
  return (
    code: 'low_contrast',
    message: 'The text "$name" ("$short") is drawn in ${hex(ink)} on ${hex(on)} (the fill of "${ground.id}"): a contrast of '
        '${ratio.toStringAsFixed(1)} to 1, too little to read. Give the text a color that reads on that fill (or none: the theme\'s ink), '
        'or give "${ground.id}" another fill; a color of the theme (its ink, its surface, a card) reads in both of its modes.',
  );
}

/// What a text paragraph shows wrong, with the text's [name] (a node id or
/// an instance path) in the message: `expression_not_evaluated` (it shows
/// `${`) and `text_no_color` (no color, or a transparent one). [noColor]
/// says what a text with no color looks like where it renders.
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
  // A value that was computed and came out as nothing a person should see:
  // a sum over a missing field (NaN), a division by zero, a name that was
  // never filled in ({total}), a missing value written out (null).
  final broken = _brokenValue.firstMatch(text)?[0];
  if (broken != null && !text.contains(r'${')) {
    out.add((
      code: 'value_not_computed',
      message: 'Text "$name" shows "$short" on screen: "$broken" is a value that did not compute. Check the formula behind it '
          '(a field the data does not have, a number read from text, a name that is not a variable), and give the variable a '
          'starting value.',
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
      message: 'Text "$name" ("$short") is drawn in a transparent color: nothing of it shows. A color with alpha 0, or a name the '
          'theme does not have: write a color the theme names, or "#FF111827".',
    ));
  }
  return out;
}

/// Reports [child] when it reaches past the right or bottom edge of
/// [parent], a row or a column that does not scroll: the content does not
/// fit where it was put (a block sized for a wider card, a row of fixed
/// cells). More than a pixel, so rounding is not reported.
void _checkFits(
  NodeBox child,
  NodeBox parent,
  void Function(EditCode code, String path, String message, {String? nodeId, bool? error}) report,
  String Function(String id, [String? field]) nodePath,
  String Function(NodeBox b) nameOf,
) {
  final type = parent.node?.type;
  if ((type != 'row' && type != 'column') || !parent.hasSize || !child.hasSize || !child.attached || !parent.attached) return;
  // Under a scroller, or moved by a transform, reaching past is meant.
  for (RenderObject? o = child.parent; o != null && !identical(o, parent); o = o.parent) {
    if (o is RenderAbstractViewport || o is RenderTransform || o is RenderFittedBox || '${o.runtimeType}'.contains('Scroll')) return;
  }
  final double x, y;
  try {
    final t = child.getTransformTo(parent).getTranslation();
    (x, y) = (t.x, t.y);
  } catch (_) {
    return;
  }
  final right = x + child.size.width - parent.size.width, bottom = y + child.size.height - parent.size.height;
  final horizontal = right > 1 && right >= bottom;
  final by = horizontal ? right : bottom;
  if (by <= 1) return;
  String px(double v) => v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1);
  report(
    const EditCode('content_overflows', ''),
    nodePath(child.id, 'layout'),
    '"${nameOf(child)}" reaches ${px(by)} px past the ${horizontal ? 'right' : 'bottom'} edge of "${nameOf(parent)}" '
    '(a $type ${px(parent.size.width)} by ${px(parent.size.height)}): its content does not fit there. '
    'Let it shrink or wrap (a flexible or filling ${horizontal ? 'width' : 'height'}, a text with maxLines), or give the $type room.',
    nodeId: child.id,
    error: false,
  );
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
  // The lists that came out empty, by id: one written under another list is
  // drawn once per row of it.
  final copies = _ListCopies();
  // The document as written (its texts and its data), to tell a word that
  // was written from one a formula gave.
  String? source;
  bool written(String text) {
    final m = _brokenValue.firstMatch(text);
    if (m == null) return false;
    final around = text.substring(m.start < 6 ? 0 : m.start - 6, m.end + 6 > text.length ? text.length : m.end + 6);
    final asJson = jsonEncode(around);
    return (source ??= jsonEncode(document.toJson())).contains(asJson.substring(1, asJson.length - 1));
  }
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

  // [within]: the calls whose boxes are above (a call that only wraps what
  // is put in its slot, a scroller, shows what its slot shows).
  void visit(RenderObject o, bool shown, NodeBox? box, List<String> within) {
    void credit(NodeBox by, String? own) {
      for (final c in {...within, ?own}) {
        calls[c] = (box: calls[c]?.box ?? by, showing: (calls[c]?.showing ?? 0) + 1);
      }
    }

    if (o is NodeBox) {
      final n = o.node;
      final laid = o.hasSize && o.size.width > 0.5 && o.size.height > 0.5;
      // Checked when its parent shows and it is not hidden (a list with no
      // items may lay out with no height: that is what is reported).
      final placed = shown && o.drawn;
      shown = placed && laid;
      final parent = box;
      box = o;
      if (n != null && n.type == CanvasProps.spec.type && o.instance == null && (canvas == null || o.id == canvas)) canvasBox ??= o;
      if (n != null && placed) _checkNode(o, n, document, report, nodePath, nameOf, copies);
      if (n != null && shown && parent != null) _checkFits(o, parent, report, nodePath, nameOf);
      // A leaf that is not a container or a text: an icon, an image, a
      // control, a chart.
      if (shown && n != null && n.type != 'text') {
        final leaf = o.source.node(o.id)?.childIds.isEmpty != false;
        // The view shows a leaf that is content (or a painted leaf); a
        // component shows any box it paints (a checkbox's box, a track).
        if (leaf && (!_quiet.contains(n.type) || _paints(n))) showing++;
        if ((leaf && !_quiet.contains(n.type)) || _paints(n)) credit(o, callOf(o));
      }
      final call = callOf(o);
      if (call != null && shown && o.tree.isInstanceRoot(o.id, o.instance)) calls.putIfAbsent(call, () => (box: o, showing: 0));
      if (call != null && !within.contains(call)) within = [...within, call];
    }
    if (o is RenderParagraph && shown && box != null) {
      final issues = [
        for (final i in paragraphIssues(o, nameOf(box), noColor: 'nothing of it may show'))
          // Words the UI's own text or data has ("null check failed", a
          // template's "{name}") are what was written, not a value that
          // failed.
          if (i.code != 'value_not_computed' || !(written(o.text.toPlainText()) || _fromData(box, o.text.toPlainText()))) i,
      ];
      final text = o.text.toPlainText().trim();
      if (text.isNotEmpty && !issues.any((i) => i.code == EditCodes.textNoColor.name)) {
        showing++;
        credit(box, callOf(box));
      }
      // A component's own texts are its definition's: reported on the call.
      if (componentInstanceOf(box.instance) == null) {
        for (final i in issues) {
          report(EditCode(i.code, ''), nodePath(box.id, i.code == EditCodes.textNoColor.name ? 'props/style' : 'props/text'), i.message,
              nodeId: box.id, error: false);
        }
        if (box.node?.type == 'text' && text.isNotEmpty) {
          if (textContrastIssue(box, o, nameOf(box)) case final i?) {
            report(EditCode(i.code, ''), nodePath(box.id, 'props/style'), i.message, nodeId: box.id, error: false);
          }
        }
      }
    }
    o.visitChildren((c) => visit(c, shown, box, within));
  }

  visit(root, true, null, const []);
  copies.say();

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

/// Whether [n] paints a visible fill or stroke (a progress bar's track, a
/// checkbox's box), or draws with its own painter (a drawn picture, a
/// sparkline): a leaf that shows.
bool _paints(Node n) =>
    n.type != CanvasProps.spec.type &&
    ([...n.decoration.fills, ...n.decoration.strokes].any((p) => p.visible && p.opacity > 0 && (p.color?.alpha ?? 255) > 0) ||
        (n.behaviors.customPaint?.painter.isNotEmpty ?? false) ||
        (n.behaviors.customPaint?.foregroundPainter.isNotEmpty ?? false));

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
    String Function(String, [String?]) nodePath, String Function(NodeBox) nameOf, _ListCopies copies) {
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
  _checkTextValues(b, n, written, report, nodePath);
  _checkLabel(b.id, n, written, report, nodePath);
  if (_repeaters.contains(n.type)) _checkList(b, n, written, document, report, nodePath, copies);
}

/// The copies of each list (a list under another list's row is one copy per
/// row), by its id: an empty list computed from one that is not is said
/// once for the list, and only when every copy of it shown is empty (a
/// month's days, most with no event, are not a filter that matches nothing).
final class _ListCopies {
  /// The lists a copy of which shows items.
  final filled = <String>{};

  /// What to say of a list whose copy is empty, from its first such copy.
  final empty = <String, void Function()>{};

  void say() {
    for (final e in empty.entries) {
      if (!filled.contains(e.key)) e.value();
    }
  }
}

/// Whether the broken-looking word in [text] (`null`, `NaN`…) is in the data
/// [box]'s text reads (a list in the site's variables, a component's
/// parameter): written there, not a value that failed. The document checked
/// is a page's; its data can be the site's.
bool _fromData(NodeBox box, String text) {
  final m = _brokenValue.firstMatch(text);
  if (m == null) return false;
  final values = box.tree.bindings?.valuesFor(box.source, box.id, box.instance);
  if (values is! ExpressionValues) return false;
  final node = box.source.node(box.id)?.toJson();
  final expr = readMap(node?['bind'])?['props.text'] ?? readMap(node?['props'])?['text'];
  if (expr is! String || !expr.contains(r'${')) return false;
  final around = jsonEncode(text.substring(m.start < 6 ? 0 : m.start - 6, m.end + 6 > text.length ? text.length : m.end + 6));
  final needle = around.substring(1, around.length - 1);
  try {
    for (final name in values.namesRead(expr)) {
      // A variable worked out from a formula is what failed, not data.
      if (values.variable(name)?.isComputed ?? false) continue;
      if (jsonEncode(values.read(name)).contains(needle)) return true;
    }
  } catch (_) {}
  return false;
}

/// A text written with values in it (`Total: ${money(total)}`) one of which
/// came out as nothing: the text shows a gap where a number should be. A
/// value that chooses (`cond ? "…" : ""`) may be empty on purpose.
void _checkTextValues(NodeBox b, Node shown, Node written, void Function(EditCode, String, String, {String? nodeId, bool? error}) report,
    String Function(String, [String?]) nodePath) {
  final id = b.id;
  if (shown.type != 'text') return;
  final w = readMap(written.toJson()['props'])?['text'] ?? readMap(written.toJson()['bind'])?['props.text'];
  final value = readMap(shown.toJson()['props'])?['text'];
  if (w is! String || value is! String || !w.contains(r'${') || value.contains(r'${')) return;
  // The written text as literal parts and expressions (braces balanced).
  final pattern = StringBuffer('^');
  final expressions = <String>[];
  // Expressions with no text between them and the next: which of the two
  // gave what shows cannot be told.
  final abuts = <int>{};
  var i = 0;
  while (i < w.length) {
    final at = w.indexOf(r'${', i);
    if (at < 0) {
      pattern.write(RegExp.escape(w.substring(i)));
      break;
    }
    pattern.write(RegExp.escape(w.substring(i, at)));
    var depth = 0, j = at + 1;
    for (; j < w.length; j++) {
      if (w[j] == '{') depth++;
      if (w[j] == '}' && --depth == 0) break;
    }
    if (j >= w.length) return;
    if (at == i && expressions.isNotEmpty) abuts.addAll([expressions.length - 1, expressions.length]);
    expressions.add(w.substring(at + 2, j));
    pattern.write('([\\s\\S]*?)');
    i = j + 1;
  }
  pattern.write(r'$');
  final m = RegExp(pattern.toString()).firstMatch(value);
  if (m == null) return;
  for (var k = 0; k < expressions.length; k++) {
    final e = expressions[k];
    if ((m[k + 1] ?? '').trim().isNotEmpty || e.contains('?') || e.contains('coalesce') || e.contains('""') || e.contains("''")) continue;
    if (abuts.contains(k)) continue;
    // An empty text is a value (nothing picked yet, a field the data
    // leaves empty); nothing at all is a name or a formula that failed.
    final values = b.tree.bindings?.valuesFor(b.source, b.id, b.instance);
    if (values is ExpressionValues) {
      try {
        if (values.evaluate('\${$e}') is String) continue;
      } catch (_) {}
    }
    report(const EditCode('value_not_computed', ''), nodePath(id, 'props/text'),
        'Text "$id" shows "${value.length > 40 ? '${value.substring(0, 40)}...' : value}": "${e.replaceFirst(RegExp(r'^=\s*'), '')}" gave nothing, so there is a '
        'gap where its value should be. Check the names it reads (a field the data does not have, a variable not declared) and '
        'that numbers are numbers, not text.',
        nodeId: id);
    return;
  }
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
    void Function(EditCode, String, String, {String? nodeId, bool? error}) report, String Function(String, [String?]) nodePath,
    _ListCopies copies) {
  final expression = written.bind['data'];
  if (expression == null) return;
  final id = b.id;
  final props = readMap(shown.toJson()['props']) ?? const {};
  final count = props[shown.type == 'tableView' ? 'rowCount' : 'itemCount'];
  if (shown.type == 'tableView') {
    // Its rows are the data; its columns are declared, its cells templates.
    if ((readList(props['columns']) ?? const []).isEmpty && !written.bind.containsKey('props.columns')) {
      report(EditCodes.listEmpty, nodePath(id, 'props/columns'),
          'Table "$id" has data ($expression) but no columns: nothing of it shows. Declare them, "props": {"columns": '
          '[{"key": "name", "label": "Name"}, ...]}, and the cell template in its "cell" slot (reading \${item.value}); '
          'ui_docs "tableView".',
          nodeId: id);
      return;
    }
  } else if (written.childIds.isEmpty) {
    report(EditCodes.listEmpty, nodePath(id, 'children'),
        'List "$id" has data ($expression) but no item template: its first child is drawn once per item. Add one: '
        '{"op": "set", "id": "<item id>", "parent": "$id", "node": {...}} reading \${item.<field>}.',
        nodeId: id);
    return;
  }
  if (count is! num) return;
  if (count > 0) {
    copies.filled.add(id);
    return;
  }
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
    // Said after every copy of the list is seen, and only when none shows
    // an item ([_ListCopies]).
    copies.empty.putIfAbsent(
        id,
        () => () => report(EditCodes.listEmpty, nodePath(id, 'bind/data'),
            'List "$id" shows no items: $expression is empty while ${source.$1} has ${source.$2}. If a filter should keep them, read '
            'each item\'s fields through a lambda: filter(${source.$1}, r => r.status == x), not filter(${source.$1}, status == x).',
            nodeId: id, error: false));
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
