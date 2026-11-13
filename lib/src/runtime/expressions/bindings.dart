// Bindings, compiled once: per node, what each bound path evaluates and
// which names it reads; per layout, which conditions set which node's
// properties. [NodeBinder] gives the node tree each node as shown (bound
// values, conditions, interpolated text) and what to watch for it, so a
// change re-applies only the boxes that read it. No JSON round trips:
// values land through `BindPaths.apply` on the typed node.
import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_api/codelessly_api.dart'
    show BindPaths, BindValue, Condition, ConditionOperand, LayoutLogic, Node, PropertySet, SizeFit, TextProps, TextRun;
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show TextStyle;

import '../../render/contracts.dart';
import '../../render/convert.dart' as convert;
import '../../render/node_tree.dart' show RenderTree;
import '../../render/source.dart' show NodeSource;
import '../actions/variable_animator.dart';
import '../contracts.dart';
import 'engine.dart';
import 'formula_clock.dart';
import 'node_scopes.dart';
import 'paths.dart';
import 'preview.dart';
import 'scopes.dart';
import 'variable_writes.dart';

export '../../render/contracts.dart' show BoundNode;

/// The instance of a repeated box whose item its widget gives itself
/// ([NodeBinder.provideItem]): repeat [key] (a row's item key, a section, a
/// table cell) of [owner]'s nodes, inside [outer] (the owner's own
/// instance). Box keys print it, so [key] prints as what tells repeats
/// apart.
@immutable
final class ProvidedItem {
  const ProvidedItem(this.tag, this.outer, this.owner, this.key);

  final String tag;
  final Object? outer;
  final String owner;
  final Object? key;

  @override
  bool operator ==(Object other) =>
      other is ProvidedItem && other.tag == tag && other.outer == outer && other.owner == owner && other.key == key;

  @override
  int get hashCode => Object.hash(tag, outer, owner, key);

  @override
  String toString() => '($tag, $outer, $owner, ${_printed(key)})';

  /// [key] as box keys tell repeats apart: a map or list item (a row
  /// without an id is keyed by its item) by identity, as it compares. Its
  /// contents printed alike for an equal item from a newer answer (a script
  /// answering again for new inputs), so the new row found the old row's
  /// box, still reading the old row's scope, which was then let go: the
  /// row's texts fell back to the template's.
  static String _printed(Object? key) =>
      key is Map || key is Iterable ? '${key.runtimeType}#${identityHashCode(key)}' : '$key';
}

/// One bound property: a path of the node and the expression giving it.
@immutable
final class BoundProperty {
  BoundProperty(this.path, this.expression)
      : reads = Expressions.readsOf(expression),
        clock = Expressions.clockTick(expression);

  final String path;
  final String expression;

  /// The paths it reads.
  final Set<String> reads;

  /// How often its value changes as time passes; null: it doesn't.
  final ClockTick? clock;

  Object? valueIn(Expressions e, ValueScope scope) => e.evaluate(expression, scope);

  Node applyTo(Node n, Expressions e, ValueScope scope) => BindPaths.apply(n, path, valueIn(e, scope));
}

/// A node's bindings ([Node.bind]), compiled once per node instance.
final class NodeBindings {
  NodeBindings._(Node n)
      : properties = [
          for (final e in n.bind.entries)
            if (e.key != BindPaths.visible && e.key != BindPaths.data && BindPaths.stateOf(e.key) == null)
              BoundProperty(e.key, e.value),
          ..._imageUrls(n),
        ],
        states = {
          for (final e in n.bind.entries)
            if (BindPaths.stateOf(e.key) case final api.WidgetState state) state: BoundProperty(e.key, e.value),
        },
        visible = n.bind[BindPaths.visible]?.let((e) => BoundProperty(BindPaths.visible, e)),
        data = n.bind[BindPaths.data]?.let((e) => BoundProperty(BindPaths.data, e)),
        text = n.type == TextProps.spec.type && n.prop(TextProps.text).contains(r'${') && !n.bind.containsKey('props.text')
            ? n.prop(TextProps.text)
            : null;

  /// An image paint whose own URL holds `${...}` (`${item.cover}`), bound
  /// to that URL as a text node's own text is: filled in from the scope, as
  /// v1 drew it, unless the node binds the paint or its URL itself.
  static Iterable<BoundProperty> _imageUrls(Node n) sync* {
    final d = n.decoration;
    for (final (key, paints) in [('fills', d.fills), ('foregroundFills', d.foregroundFills)]) {
      for (var i = 0; i < paints.length; i++) {
        final url = paints[i].image?.url;
        if (url == null || !url.contains(r'${')) continue;
        final id = paints[i].id;
        final bound = n.bind.keys.any((k) =>
            k == 'decoration.$key' ||
            k.startsWith('decoration.$key[$i]') ||
            (id != null && id.isNotEmpty && k.startsWith('decoration.$key.$id')) ||
            k.startsWith('decoration.$key.*'));
        if (!bound) yield BoundProperty('decoration.$key[$i].image.url', url);
      }
    }
  }

  static final Expando<NodeBindings> _cache = Expando('NodeBindings');

  /// [n]'s bindings (compiled on first use, kept while [n] lives).
  static NodeBindings of(Node n) => _cache[n] ??= NodeBindings._(n);

  /// Every bound path but [visible] and [data].
  final List<BoundProperty> properties;

  /// Runtime visibility: false collapses the node (it takes no space).
  final BoundProperty? visible;

  /// The items a repeating widget builds one per.
  final BoundProperty? data;

  /// Interaction states bound to data (`selected`, `disabled`).
  final Map<api.WidgetState, BoundProperty> states;

  /// A text node's own text when it holds `${...}` (interpolated).
  final String? text;

  late final Set<String> textReads = text == null ? const {} : Expressions.readsOf(text!);
  late final ClockTick? textClock = text == null ? null : Expressions.clockTick(text!);

  bool get isEmpty => properties.isEmpty && visible == null && data == null && text == null && states.isEmpty;
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
        },
        clock = _clockOf(node, path, condition);

  final String node;
  final String path;
  final Condition condition;
  final Set<String> reads;

  /// How often its value changes as time passes; null: it doesn't.
  final ClockTick? clock;

  static ClockTick? _clockOf(String node, String path, Condition condition) {
    ClockTick? out;
    for (final b in condition.branches) {
      if (b.when != null) out = Expressions.clockTickOfPredicate(b.when!)?.finer(out) ?? out;
      for (final s in b.sets) {
        if (s.node == node && s.path == path && s.value is String) {
          out = Expressions.clockTick(s.value! as String)?.finer(out) ?? out;
        }
      }
    }
    return out;
  }

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

/// Applies bindings, conditions and text interpolation to the nodes of a
/// node tree (from its [NodeSource]), reading from [scope] (a screen's variables, with the app's
/// values around them) and, inside data-bound lists, from each item's
/// [ItemScope].
///
/// [preview] is a design canvas: a text's `${...}` shows the value the
/// [scope] (the variables' defaults, if the editor gives one) has, else a
/// placeholder (`${user.name}` shows "Name"); nothing ticks.
///
/// It is the runtime's [TreeBindings]: what a [RenderTree] takes its nodes
/// as shown from, and its render objects their values.
class NodeBinder implements TreeBindings {
  NodeBinder({
    this.scope,
    this.scopeOf,
    LayoutLogic logic = LayoutLogic.none,
    this.engine = const Expressions(),
    this.preview = false,
  }) : _conditions = ConditionIndex(logic);

  /// Where names are read; null: no bindings apply (a canvas without
  /// defaults still shows placeholders in [preview]).
  final ValueScope? scope;

  /// Where node `id` reads names, when that depends on the node: a design
  /// board holds every screen, each with its own variables, so a node reads
  /// its canvas's scope. Null (or a null result): [scope].
  final ValueScope? Function(String id)? scopeOf;

  bool get _binds => scope != null || scopeOf != null;

  /// The scope node [id] reads names from, outside its lists and node
  /// scopes: [scopeOf]'s, else [scope].
  ValueScope? rootScopeOf(String id) => scopeOf?.call(id) ?? scope;
  final Expressions engine;
  final bool preview;
  ConditionIndex _conditions;

  /// Replaces the conditions (an edit); the tree re-applies its boxes.
  set logic(LayoutLogic logic) => _conditions = ConditionIndex(logic);

  @override
  bool get hasValues => scope != null;

  @override
  BoundValues? valuesFor(NodeSource source, String id, Object? instance) {
    final s = scopeFor(source, id, instance);
    return s == null ? null : _ScopeValues(s, engine);
  }

  @override
  void publish(NodeSource source, String id, Object? instance, String name, Object? value) =>
      nodeScope(source, id, instance: instance)?.update(name, value);

  /// [node] (in repeat [instance]) as shown.
  @override
  BoundNode bind(NodeSource source, Node node, Object? instance) {
    final b = NodeBindings.of(node);
    final targets = _conditions.byNode[node.id] ?? const [];
    if (b.isEmpty && targets.isEmpty) return BoundNode(node);
    final s = _binds ? scopeFor(source, node.id, instance) : null;
    final reads = <String>{};
    ClockTick? clock;
    var out = node;
    bool? visible;
    final states = <api.WidgetState, bool>{};
    if (s != null) {
      for (final e in b.states.entries) {
        reads.addAll(e.value.reads);
        clock = e.value.clock?.finer(clock) ?? clock;
        if (BindValue.boolean(e.value.valueIn(engine, s)) case final bool on) states[e.key] = on;
      }
      for (final p in b.properties) {
        reads.addAll(p.reads);
        clock = p.clock?.finer(clock) ?? clock;
        out = p.applyTo(out, engine, s);
      }
      if (b.visible case final BoundProperty v) {
        reads.addAll(v.reads);
        clock = v.clock?.finer(clock) ?? clock;
        visible = BindValue.boolean(v.valueIn(engine, s));
      }
      if (b.data case final BoundProperty d) {
        reads.addAll(d.reads);
        clock = d.clock?.finer(clock) ?? clock;
        out = _withItems(source, out, instance, d.valueIn(engine, s));
      }
      // Conditions win over bindings.
      for (final t in targets) {
        reads.addAll(t.reads);
        clock = t.clock?.finer(clock) ?? clock;
        final v = t.valueIn(engine, s);
        if (v == null) continue;
        if (t.path == BindPaths.visible) {
          visible = BindValue.boolean(v) ?? visible;
        } else if (BindPaths.stateOf(t.path) case final api.WidgetState state) {
          if (BindValue.boolean(v) case final bool on) states[state] = on;
        } else if (t.path == BindPaths.data) {
          out = _withItems(source, out, instance, v);
        } else {
          out = BindPaths.apply(out, t.path, v);
        }
      }
    }
    if (b.text != null && (s != null || preview)) {
      reads.addAll(b.textReads);
      clock = b.textClock?.finer(clock) ?? clock;
      out = _withText(out, s);
    }
    if (visible != null && visible != out.visible) out = out.copyWith(visible: visible);
    return BoundNode(
      out,
      collapsed: visible == false,
      watch: s == null ? const [] : _watchers(s, reads, preview ? null : clock),
      states: states,
    );
  }

  // A name whose computed or function variable reads the clock brings its
  // clock in through [watchName].
  List<Listenable> _watchers(ValueScope s, Set<String> reads, ClockTick? clock) {
    final roots = {for (final r in reads) rootOf(r)};
    final out = <Listenable>{};
    for (final r in roots) {
      final w = watchName(s, r);
      if (w != null) out.add(w);
    }
    if (clock != null) out.add(FormulaClock.of(clock));
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
    if (list == null) {
      // A running app shows no items while its data isn't there yet (a
      // script still answering), not the bare template with `${item...}`
      // in it; a design preview keeps showing the template.
      final countProp = n.type == 'tableView' ? 'rowCount' : 'itemCount';
      final def = n.spec?.prop(countProp);
      if (preview || def == null || n.bind.containsKey('props.$countProp')) return n;
      return n.copyWith(props: n.props.set<Object?>(def, 0));
    }
    // This list's item scopes only (a list of thousands of cells used to
    // scan every item scope of every list, per bind). A snapshot: an item's
    // update can rebind nodes that make or drop item scopes (a list inside
    // the item), changing the map mid-loop.
    final scopes = _items[(n.id, instance)];
    if (scopes != null) {
      for (final e in scopes.entries.toList(growable: false)) {
        final i = e.key;
        e.value.update(index: i, item: i < list.length ? list[i] : null);
      }
    }
    _itemRefreshers[(n.id, instance)]?.call(list);
    // A list's item count, a table's row count: as many as the items.
    final countProp = n.type == 'tableView' ? 'rowCount' : 'itemCount';
    final def = n.spec?.prop(countProp);
    if (def == null || n.bind.containsKey('props.$countProp')) return n;
    return n.copyWith(props: n.props.set<Object?>(def, list.length));
  }

  static List<Object?>? _listOf(Object? v) => switch (v) {
        final List<Object?> l => l,
        final Map<Object?, Object?> m => m.values.toList(),
        final String s => switch (parseLoose(s)) { final List<Object?> l => l, _ => null },
        _ => null,
      };

  /// Item scopes by list (its id and instance), then by index.
  final Map<(String, Object?), Map<int, ItemScope>> _items = {};

  static const _repeaters = {'listView', 'gridView', 'pageView'};

  bool _repeats(Node n) =>
      _repeaters.contains(n.type) &&
      (n.bind.containsKey(BindPaths.data) ||
          (_conditions.byNode[n.id]?.any((t) => t.path == BindPaths.data) ?? false));

  /// The names a node gives itself and the nodes inside it, by what gives
  /// them: a node that follows the pointer shares its drag as `drag`
  /// ([api.DragMotion], not a track or a list's reorder handle). Each such
  /// node reads from a [LocalScope] of its own ([localScopeOf]), which the
  /// behavior sets.
  static final Map<String, bool Function(Node n)> localNames = {
    'drag': (n) => switch (n.behaviors.drag) {
          final api.DragMotion d => d.track == null && !d.reorder,
          null => false,
        },
  };

  static Set<String> _localNamesOf(Node n) => {
        for (final e in localNames.entries)
          if (e.value(n)) e.key,
      };

  final Map<(String, Object?), LocalScope> _locals = {};

  /// The [LocalScope] node [id] (in [instance]) gives itself and the nodes
  /// inside it, or null when it gives none ([localNames]) or nothing binds.
  LocalScope? localScopeOf(NodeSource source, String id, Object? instance) {
    final n = source.node(id);
    if (n == null || !_binds) return null;
    final names = _localNamesOf(n);
    if (names.isEmpty) return null;
    final existing = _locals[(id, instance)];
    if (existing != null && setEquals(existing.names, names)) return existing;
    existing?.dispose();
    final parentId = source.parentOf(id);
    final parentNode = parentId == null ? null : source.node(parentId);
    // An item's root reads around it what the item does.
    final around = parentId == null || parentNode == null || _repeats(parentNode)
        ? _itemScopeFor(source, id, instance)
        : scopeFor(source, parentId, instance);
    return _locals[(id, instance)] = LocalScope(names, parent: around);
  }

  /// The scope node [id] (in [instance]) reads from: [scope], the item scope
  /// of the data-bound list it repeats in, or the [LocalScope] of the
  /// nearest node around it (or itself) that gives one ([localNames]).
  ValueScope? scopeFor(NodeSource source, String id, Object? instance) {
    final base = _itemScopeFor(source, id, instance);
    if (base == null || localNames.isEmpty) return base;
    for (String? p = id; p != null; p = source.parentOf(p)) {
      final pn = source.node(p);
      if (pn == null) break;
      // Past the list it repeats in, the item scope reads what's around.
      if (p != id && _repeats(pn)) break;
      if (_localNamesOf(pn).isNotEmpty) return localScopeOf(source, p, instance) ?? base;
    }
    return base;
  }

  ValueScope? _itemScopeFor(NodeSource source, String id, Object? instance) {
    final root = rootScopeOf(id);
    if (root == null) return null;
    String? listId;
    // The item a repeat's widget gives it (a paged list's row, a section
    // header, a table cell), when [id] is in one.
    ValueScope? provided;
    // The nodes around (and including) [id] below the list it repeats in
    // that declare names for the nodes inside them (a drag track's
    // `track`, a flip card's `flip`; node_scopes.dart), innermost first.
    List<String>? scoped;
    if (source.node(id) case final Node self when declaresNodeScope(self)) scoped = [id];
    for (var p = source.parentOf(id); p != null; p = source.parentOf(p)) {
      if (instance is ProvidedItem && instance.owner == p) {
        provided = _provided[instance] ??= ItemScope(index: 0, parent: scopeFor(source, p, instance.outer) ?? root);
        break;
      }
      final pn = source.node(p);
      if (pn != null && _repeats(pn)) {
        listId = p;
        break;
      }
      if (pn != null && declaresNodeScope(pn)) (scoped ??= []).add(p);
    }
    final base = provided ?? (listId == null ? root : _itemScope(source, listId, instance, root));
    if (scoped == null) return base;
    var out = base;
    for (final p in scoped.reversed) {
      out = _nodeScopes[(p, instance)] ??= nodeValuesScopeFor(source.node(p)!, out);
    }
    return out;
  }

  final Map<(String, Object?), NodeValuesScope> _nodeScopes = {};

  /// The names node [id] (in [instance]) gives the nodes inside it, which
  /// its render objects write; null when it declares none, or there's no
  /// [scope].
  NodeValuesScope? nodeScope(NodeSource source, String id, {Object? instance}) {
    final node = source.node(id);
    if (node == null || !declaresNodeScope(node)) return null;
    scopeFor(source, id, instance);
    return _nodeScopes[(id, instance)];
  }

  ValueScope _itemScope(NodeSource source, String listId, Object? instance, ValueScope root) {
    // The collections give item k > 0 its own instance, ('item', outer,
    // list, k); the first item is the list's own (unscoped).
    final listNode = source.node(listId)!;
    final isPages = listNode.type == 'pageView';
    final (int index, Object? outer) = switch (instance) {
      (final String tag, final Object? o, final String l, final int k) when tag == 'item' && l == listId => (k, o),
      _ => (-1, instance),
    };
    final scopes = _items[(listId, outer)] ??= {};
    // Known without reading the data: an item by index, or any list's first.
    if (index >= 0 || !isPages) {
      final known = scopes[index < 0 ? 0 : index];
      if (known != null) return known;
    }
    final parent = scopeFor(source, listId, outer) ?? root;
    final items = _listOf(_dataOf(listNode, parent));
    // The list's own (first built) item: item 0, or a page view's page at rest.
    final restPage = isPages
        ? (items == null || items.isEmpty
              ? listNode.prop(api.PageViewProps.initialPage)
              : listNode.prop(api.PageViewProps.initialPage).clamp(0, items.length - 1))
        : 0;
    final at = index < 0 ? restPage : index;
    final existing = scopes[at];
    if (existing != null) return existing;
    final scope = scopes[at] = ItemScope(
      index: at,
      item: items != null && at < items.length ? items[at] : null,
      parent: parent,
    );
    // A page view's pages read their distance from the page at rest, as
    // they do at runtime (parallax, held entrances).
    if (isPages) scope.setPageOffset((at - restPage).toDouble());
    return scope;
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

  final Map<ProvidedItem, ItemScope> _provided = {};

  /// Gives repeat [instance] (of a widget whose items it gives itself) its
  /// [item] at [index]: the scope its nodes read `item` and `index` from,
  /// made or moved to them (the boxes that read them re-apply).
  ItemScope? provideItem(NodeSource source, ProvidedItem instance, {required int index, Object? item}) {
    final root = rootScopeOf(instance.owner);
    if (root == null) return null;
    final existing = _provided[instance];
    if (existing != null) {
      existing.update(index: index, item: item, deferNotifications: true);
      return existing;
    }
    return _provided[instance] = ItemScope(
      index: index,
      item: item,
      parent: scopeFor(source, instance.owner, instance.outer) ?? root,
    );
  }

  /// Lets go of the scope of repeat [instance] (its widget no longer shows
  /// it). Not disposed: a box leaving with it may still listen.
  void forgetItem(ProvidedItem instance) => _provided.remove(instance);

  /// What re-gives the items of widgets that provide their own item scopes
  /// ([provideItem]: a table at rest), by node and instance: called with the
  /// node's new items whenever its bound data changes, as a list's item
  /// scopes are moved to theirs. Without it a table whose data changed but
  /// kept its size (the same node) kept showing its old cells.
  final Map<(String, Object?), void Function(List<Object?> items)> _itemRefreshers = {};

  /// Registers (or with null, drops) [refresh] for node [owner] in [instance].
  void onItemsChanged(String owner, Object? instance, void Function(List<Object?> items)? refresh) {
    if (refresh == null) {
      _itemRefreshers.remove((owner, instance));
    } else {
      _itemRefreshers[(owner, instance)] = refresh;
    }
  }

  /// The items node [list] (in [instance]) is bound to: its `data` binding or
  /// a condition setting it, as a list; null when it has none.
  List<Object?>? itemsOf(NodeSource source, Node list, Object? instance) {
    final s = _binds ? scopeFor(source, list.id, instance) : null;
    if (s == null) return null;
    return _listOf(_dataOf(list, s));
  }

  /// Lets go of the item, local and node scopes.
  void dispose() {
    for (final s in [for (final m in _items.values) ...m.values, ..._provided.values]) {
      s.dispose();
    }
    _items.clear();
    for (final s in _locals.values) {
      s.dispose();
    }
    _locals.clear();
    for (final s in _nodeScopes.values) {
      s.dispose();
    }
    _nodeScopes.clear();
    _provided.clear();
  }
}

/// The binder a tree was given, when it is the runtime's.
extension RenderTreeBinder on RenderTree {
  /// Applies the nodes' bindings (variables, conditions, `${...}` text) when
  /// set; null renders the nodes as stored. Setting it re-applies every box.
  NodeBinder? get binder {
    final b = bindings;
    return b is NodeBinder ? b : null;
  }

  set binder(NodeBinder? value) => bindings = value;
}

/// A [ValueScope] as the values a node's render objects read and write.
final class _ScopeValues implements BoundValues {
  const _ScopeValues(this.scope, this.engine);

  final ValueScope scope;
  final Expressions engine;

  @override
  Object? read(String path) => readPath(scope, path);

  @override
  Listenable? watch(String path) => watchName(scope, rootOf(path));

  @override
  BoundVariable? variable(String path) {
    final found = variableOf(scope, path);
    return found == null ? null : _ScopeVariable(found.$1, found.$2, rootOf(path));
  }

  @override
  bool write(String path, Object? value) => setVariableIn(scope, path, value);

  @override
  String interpolate(String text) => engine.interpolate(text, scope);
}

final class _ScopeVariable implements BoundVariable {
  const _ScopeVariable(this.scope, this.variable, this.name);

  final VariableScope scope;
  final api.Variable variable;
  final String name;

  @override
  bool get isComputed => variable.isComputed;

  @override
  bool get isInteger => variable.type == api.VariableType.integer;

  @override
  void pauseAnimation() => VariableAnimator.pause(scope, name);
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
