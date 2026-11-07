// Bindings, compiled once: per node, what each bound path evaluates and
// which names it reads; per layout, which conditions set which node's
// properties. [NodeBinder] gives the node tree each node as shown (bound
// values, conditions, interpolated text) and what to watch for it, so a
// change re-applies only the boxes that read it. No JSON round trips:
// values land through `BindPaths.apply` on the typed node.
import 'package:codelessly_api_v2/codelessly_api.dart' as api;
import 'package:codelessly_api_v2/codelessly_api.dart'
    show BindPaths, BindValue, Condition, ConditionOperand, LayoutLogic, Node, PropertySet, SizeFit, TextProps, TextRun;
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show TextStyle;

import '../../render/convert.dart' as convert;
import '../../render/source.dart' show NodeSource;
import '../contracts.dart';
import 'engine.dart';
import 'formula_clock.dart';
import 'paths.dart';
import 'preview.dart';
import 'scopes.dart';

/// One bound property: a path of the node and the expression giving it.
@immutable
final class BoundProperty {
  BoundProperty(this.path, this.expression)
      : reads = Expressions.readsOf(expression),
        readsClock = Expressions.readsClock(expression);

  final String path;
  final String expression;

  /// The paths it reads.
  final Set<String> reads;
  final bool readsClock;

  Object? valueIn(Expressions e, ValueScope scope) => e.evaluate(expression, scope);

  Node applyTo(Node n, Expressions e, ValueScope scope) => BindPaths.apply(n, path, valueIn(e, scope));
}

/// A node's bindings ([Node.bind]), compiled once per node instance.
final class NodeBindings {
  NodeBindings._(Node n)
      : properties = [
          for (final e in n.bind.entries)
            if (e.key != BindPaths.visible && e.key != BindPaths.data) BoundProperty(e.key, e.value),
        ],
        visible = n.bind[BindPaths.visible]?.let((e) => BoundProperty(BindPaths.visible, e)),
        data = n.bind[BindPaths.data]?.let((e) => BoundProperty(BindPaths.data, e)),
        text = n.type == TextProps.spec.type && n.prop(TextProps.text).contains(r'${') && !n.bind.containsKey('props.text')
            ? n.prop(TextProps.text)
            : null;

  static final Expando<NodeBindings> _cache = Expando('NodeBindings');

  /// [n]'s bindings (compiled on first use, kept while [n] lives).
  static NodeBindings of(Node n) => _cache[n] ??= NodeBindings._(n);

  /// Every bound path but [visible] and [data].
  final List<BoundProperty> properties;

  /// Runtime visibility: false collapses the node (it takes no space).
  final BoundProperty? visible;

  /// The items a repeating widget builds one per.
  final BoundProperty? data;

  /// A text node's own text when it holds `${...}` (interpolated).
  final String? text;

  late final Set<String> textReads = text == null ? const {} : Expressions.readsOf(text!);
  late final bool textReadsClock = text != null && Expressions.readsClock(text!);

  bool get isEmpty => properties.isEmpty && visible == null && data == null && text == null;
}

/// The properties a layout's conditions set, by node: (path, the first
/// condition that sets it), in the conditions' order.
final class ConditionIndex {
  ConditionIndex(LayoutLogic logic) {
    for (final list in logic.conditions.values) {
      for (final c in list) {
        for (final (node, path) in c.targets) {
          final targets = byNode[node] ??= [];
          if (!targets.any((t) => t.path == path)) targets.add(ConditionTarget(node, path, c));
        }
      }
    }
  }

  static final ConditionIndex none = ConditionIndex(LayoutLogic.none);

  final Map<String, List<ConditionTarget>> byNode = {};
}

/// One property a condition sets.
final class ConditionTarget {
  ConditionTarget(this.node, this.path, this.condition)
      : reads = {
          for (final b in condition.branches) ...[
            if (b.when != null) ...Expressions.readsOfPredicate(b.when!),
            for (final s in b.sets)
              if (s.node == node && s.path == path && s.value is String) ...Expressions.readsOf(s.value! as String),
          ],
        };

  final String node;
  final String path;
  final Condition condition;
  final Set<String> reads;

  /// The value the first branch that holds (and sets this property) gives
  /// it; null when none does. A text value is read like a condition
  /// operand (`true` is a bool, `${= n * 2}` a number).
  Object? valueIn(Expressions e, ValueScope scope) {
    for (final b in condition.branches) {
      if (b.when != null && !e.test(b.when!, scope)) continue;
      PropertySet? set;
      for (final s in b.sets) {
        if (s.node == node && s.path == path) set = s;
      }
      final v = set?.value;
      final value = v is String ? e.operand(ConditionOperand(v), scope) : v;
      if (value != null) return value;
    }
    return null;
  }
}

/// A node as shown: its bound values applied.
@immutable
final class BoundNode {
  const BoundNode(this.node, {this.collapsed = false, this.watch = const []});

  final Node node;

  /// Hidden by a binding or condition: takes no space (SDK 8.x's
  /// `Visibility` without `maintainSize`). A node hidden in its own data
  /// keeps its space.
  final bool collapsed;

  /// What tells the node it may show differently: one per name it read.
  final List<Listenable> watch;
}

/// Applies bindings, conditions and text interpolation to the nodes of a
/// node tree (from its [NodeSource]), reading from [scope] (a screen's variables, with the app's
/// values around them) and, inside data-bound lists, from each item's
/// [ItemScope].
///
/// [preview] is a design canvas: a text's `${...}` shows the value the
/// [scope] (the variables' defaults, if the editor gives one) has, else a
/// placeholder (`${user.name}` shows "Name"); nothing ticks.
class NodeBinder {
  NodeBinder({this.scope, LayoutLogic logic = LayoutLogic.none, this.engine = const Expressions(), this.preview = false})
      : _conditions = ConditionIndex(logic);

  /// Where names are read; null: no bindings apply (a canvas without
  /// defaults still shows placeholders in [preview]).
  final ValueScope? scope;
  final Expressions engine;
  final bool preview;
  ConditionIndex _conditions;

  /// Replaces the conditions (an edit); the tree re-applies its boxes.
  set logic(LayoutLogic logic) => _conditions = ConditionIndex(logic);

  /// [node] (in repeat [instance]) as shown.
  BoundNode bind(NodeSource source, Node node, Object? instance) {
    final b = NodeBindings.of(node);
    final targets = _conditions.byNode[node.id] ?? const [];
    if (b.isEmpty && targets.isEmpty) return BoundNode(node);
    final s = scope == null ? null : scopeFor(source, node.id, instance);
    final reads = <String>{};
    var clock = false;
    var out = node;
    bool? visible;
    if (s != null) {
      for (final p in b.properties) {
        reads.addAll(p.reads);
        clock |= p.readsClock;
        out = p.applyTo(out, engine, s);
      }
      if (b.visible case final BoundProperty v) {
        reads.addAll(v.reads);
        clock |= v.readsClock;
        visible = BindValue.boolean(v.valueIn(engine, s));
      }
      if (b.data case final BoundProperty d) {
        reads.addAll(d.reads);
        clock |= d.readsClock;
        out = _withItems(source, out, instance, d.valueIn(engine, s));
      }
      // Conditions win over bindings (v1's precedence).
      for (final t in targets) {
        reads.addAll(t.reads);
        final v = t.valueIn(engine, s);
        if (v == null) continue;
        if (t.path == BindPaths.visible) {
          visible = BindValue.boolean(v) ?? visible;
        } else if (t.path == BindPaths.data) {
          out = _withItems(source, out, instance, v);
        } else {
          out = BindPaths.apply(out, t.path, v);
        }
      }
    }
    if (b.text != null && (s != null || preview)) {
      reads.addAll(b.textReads);
      clock |= b.textReadsClock;
      out = _withText(out, s);
    }
    if (visible != null && visible != out.visible) out = out.copyWith(visible: visible);
    return BoundNode(
      out,
      collapsed: visible == false,
      watch: s == null ? const [] : _watchers(s, reads, clock && !preview),
    );
  }

  List<Listenable> _watchers(ValueScope s, Set<String> reads, bool clock) {
    final roots = {for (final r in reads) rootOf(r)};
    final out = <Listenable>{};
    for (final r in roots) {
      final w = watchName(s, r);
      if (w != null) out.add(w);
      // A computed variable that reads names of other scopes (an item).
      for (ValueScope? x = s; x != null; x = x.parent) {
        if (x is VariableScope && x.declares(r)) {
          for (final f in x.foreignReads(r)) {
            watchName(s, f)?.let(out.add);
          }
          break;
        }
      }
    }
    if (clock) out.add(FormulaClock.instance);
    return out.toList();
  }

  // --- text ---------------------------------------------------------------------

  Node _withText(Node n, ValueScope? s) {
    final text = n.prop(TextProps.text);
    final runs = n.prop(TextProps.runs);
    String f(String part) {
      if (!part.contains(r'${')) return part;
      if (!preview) return engine.interpolate(part, s!);
      final fixed = n.layout.width.fit != SizeFit.hug;
      final width = fixed ? n.layout.width.value - n.layout.padding.horizontal : null;
      final style = convert.textStyle(n.prop(TextProps.style).merge(runs.firstOrNull?.style ?? api.TextStyle.empty));
      return part.replaceAllMapped(
        expressionSyntax,
        (m) => VariablePreview.textFor(m[0]!, scope: s, width: width, style: _sized(style), engine: engine),
      );
    }

    final (nextText, nextRuns) = interpolateRuns(text, runs, f);
    return n.withProp(TextProps.text, nextText).withProp(TextProps.runs, nextRuns);
  }

  static TextStyle _sized(TextStyle s) => s.fontSize == null ? s.copyWith(fontSize: 14) : s;

  // --- items ----------------------------------------------------------------------

  /// A repeating widget bound to [items]: one item per element (its item
  /// count, unless bound on its own); item scopes already made follow.
  Node _withItems(NodeSource source, Node n, Object? instance, Object? items) {
    final list = _listOf(items);
    if (list == null) return n;
    for (final e in _items.entries) {
      if (e.key.$1 == n.id && e.key.$2 == instance) {
        final i = e.key.$3;
        e.value.update(index: i, item: i < list.length ? list[i] : null);
      }
    }
    final def = n.spec?.prop('itemCount');
    if (def == null || n.bind.containsKey('props.itemCount')) return n;
    return n.copyWith(props: n.props.set<Object?>(def, list.length));
  }

  static List<Object?>? _listOf(Object? v) => switch (v) {
        final List<Object?> l => l,
        final Map<Object?, Object?> m => m.values.toList(),
        final String s => switch (parseLoose(s)) { final List<Object?> l => l, _ => null },
        _ => null,
      };

  final Map<(String, Object?, int), ItemScope> _items = {};

  static const _repeaters = {'listView', 'gridView', 'pageView'};

  bool _repeats(Node n) =>
      _repeaters.contains(n.type) &&
      (n.bind.containsKey(BindPaths.data) ||
          (_conditions.byNode[n.id]?.any((t) => t.path == BindPaths.data) ?? false));

  /// The scope node [id] (in [instance]) reads from: [scope], or the item
  /// scope of the data-bound list it repeats in.
  ValueScope? scopeFor(NodeSource source, String id, Object? instance) {
    final root = scope;
    if (root == null) return null;
    String? listId;
    for (var p = source.parentOf(id); p != null; p = source.parentOf(p)) {
      final pn = source.node(p);
      if (pn != null && _repeats(pn)) {
        listId = p;
        break;
      }
    }
    if (listId == null) return root;
    // The collections give item k > 0 its own instance, ('item', outer,
    // list, k); the first item is the list's own (unscoped).
    final (int index, Object? outer) = switch (instance) {
      (final String tag, final Object? o, final String l, final int k) when tag == 'item' && l == listId => (k, o),
      _ => (0, instance),
    };
    final key = (listId, outer, index);
    final existing = _items[key];
    if (existing != null) return existing;
    final parent = scopeFor(source, listId, outer) ?? root;
    final listNode = source.node(listId)!;
    final items = _listOf(_dataOf(listNode, parent));
    return _items[key] = ItemScope(
      index: index,
      item: items != null && index < items.length ? items[index] : null,
      parent: parent,
    );
  }

  Object? _dataOf(Node list, ValueScope s) {
    for (final t in _conditions.byNode[list.id] ?? const <ConditionTarget>[]) {
      if (t.path == BindPaths.data) {
        final v = t.valueIn(engine, s);
        if (v != null) return v;
      }
    }
    return NodeBindings.of(list).data?.valueIn(engine, s);
  }

  /// Lets go of the item scopes.
  void dispose() {
    for (final s in _items.values) {
      s.dispose();
    }
    _items.clear();
  }
}

/// [text] with [f] applied to each styled run (and the plain text between
/// runs) on its own, the runs moved to where their text now is: a run's
/// `${...}` stays in its style.
(String, List<TextRun>) interpolateRuns(String text, List<TextRun> runs, String Function(String) f) {
  if (runs.isEmpty) return (f(text), runs);
  final sorted = [...runs]..sort((a, b) => a.start.compareTo(b.start));
  final out = StringBuffer();
  final next = <TextRun>[];
  var pos = 0;
  for (final r in sorted) {
    final start = r.start.clamp(pos, text.length);
    final end = r.end.clamp(start, text.length);
    out.write(f(text.substring(pos, start)));
    final s = out.length;
    out.write(f(text.substring(start, end)));
    next.add(TextRun(s, out.length, r.style, link: r.link));
    pos = end;
  }
  out.write(f(text.substring(pos)));
  return (out.toString(), next);
}
