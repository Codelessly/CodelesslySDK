// What a running list (or grid, or table) reads and does beyond its render
// objects: its items, its scope and expressions, its triggers, the variable
// its data is bound to and its cloud query. Used by the islands of a list
// that pages, groups into sections, swipes or reorders.
import 'package:codelessly_api/codelessly_api.dart'
    show CloudQueryDef, CollectionScrollProps, Json, Node, ScrollPhysicsType, SizeFit;
import 'package:flutter/widgets.dart';

import '../render/node_tree.dart';
import '../render/recipe.dart';
import '../runtime/actions/context.dart';
import '../runtime/actions/wiring.dart';
import '../runtime/contracts.dart';
import '../runtime/expressions/bindings.dart';
import '../runtime/expressions/engine.dart';
import '../runtime/expressions/scopes.dart';
import '../runtime/lists/cloud_list_source.dart';

/// A running list node [node] as its box [b] builds it.
class ListRuntime {
  ListRuntime(this.b, this.node);

  final NodeBuilder b;
  final Node node;

  RenderTree get tree => b.tree;
  NodeBinder? get binder => tree.binder;
  ExpressionEngine get engine => _context?.expressions ?? binder?.engine ?? const Expressions();

  ActionContext? get _context {
    final i = tree.interactions;
    final box = b;
    if (i is TreeReactions && box is NodeBox) return i.contextFor(box);
    return null;
  }

  /// The services of the screen's actions (the API, the cloud database).
  CodelesslyServices? get services => _context?.services;

  /// The scope the list itself reads from (a list item's, for a nested
  /// list).
  ValueScope? get scope =>
      binder?.scopeFor(tree.source, node.id, b.instance) ?? binder?.scope ?? _context?.scope;

  /// The items the list is bound to (`data`), else one per index of its
  /// item count, else null.
  List<Object?>? get data {
    final bound = binder?.itemsOf(tree.source, node, b.instance);
    if (bound != null) return bound;
    final count = node.prop(CollectionScrollProps.itemCount);
    if (count != null && !node.bind.containsKey('data')) return List<Object?>.generate(count, (i) => i);
    return null;
  }

  /// [index] / [item] as `${index}` / `${item}` around the list's scope,
  /// and [result] as `${result}`.
  ValueScope? itemScope({int index = 0, Object? item, Json? result}) {
    final s = scope;
    if (s == null) return null;
    final inItem = ItemScope(index: index, item: item, parent: s);
    return result == null ? inItem : ValuesScope({'result': result}, inItem);
  }

  /// [text] with its `${...}` read in [itemScope].
  String text(String text, {int index = 0, Object? item, Json? result}) {
    final s = itemScope(index: index, item: item, result: result);
    return s == null ? text : engine.interpolate(text, s);
  }

  /// Whether [condition] (a `${...}` binding or `${= ...}` formula) holds
  /// for [item] at [index] (and [result]): it reads `true` or `1`. Empty
  /// holds.
  bool holds(String condition, {Object? item, int index = 0, Json? result}) {
    final t = condition.trim();
    if (t.isEmpty) return true;
    final value = text(t, index: index, item: item, result: result).trim();
    return value == 'true' || value == '1';
  }

  /// Runs the list's reactions to [trigger] with [event] as `${result}`,
  /// finishing when they have.
  Future<void> fire(String trigger, {Json event = const {}}) async {
    final i = tree.interactions;
    final box = b;
    if (!tree.animates || box is! NodeBox) return;
    if (i is TreeReactions) return i.fireAndWait(box, trigger, event: event);
    i?.fire(box, trigger, event: event);
  }

  /// The variable the list's data is bound to directly (`${name}`).
  String? get boundVariable {
    final m = RegExp(r'^\$\{\s*([A-Za-z_][A-Za-z0-9_]*)\s*\}$').firstMatch(node.bind['data']?.trim() ?? '');
    return m?.group(1);
  }

  /// The list variable [name]'s value, as a list.
  List<Object?> listVariable(String name) => switch (scope == null ? null : readPath(scope, name)) {
        final List<Object?> l => [...l],
        _ => <Object?>[],
      };

  /// Sets variable [name] in the list's scope.
  bool setVariable(String name, Object? value) {
    final s = scope;
    return s != null && setVariableIn(s, name, value);
  }

  /// The list's cloud query, when it reads from the cloud database.
  CloudQueryDef? get cloudQuery {
    final def = CloudQueryDef.fromJson(node.prop(CollectionScrollProps.query));
    return def.collectionPath.trim().isEmpty ? null : def;
  }

  /// The collection path of [cloudQuery], resolved.
  String get collectionPath {
    final def = cloudQuery, s = scope;
    if (def == null || s == null) return '';
    return cloudCollectionPath(def, engine, s);
  }

  /// The app's cloud database.
  CloudListSource? get database => CloudListSource.of(services);

  /// The name of the variable the list writes its status into.
  String? get statusVariable {
    final status = node.prop(CollectionScrollProps.query)['statusVariable'];
    final name = switch (status) {
      final Map m => m['name'],
      final String s => s,
      _ => null,
    };
    return name is String && name.trim().isNotEmpty ? name.trim() : null;
  }

  /// Writes [status] into the list's status variable, after this frame.
  void reportStatus(String status) {
    final name = statusVariable;
    if (name == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => setVariable(name, status));
  }
}

/// The scroll physics of a list: none
/// when it doesn't scroll, always scrolling when [alwaysScroll].
ScrollPhysics? scrollPhysicsOf(Node n, {bool scrollable = true, bool? alwaysScroll}) {
  if (!scrollable) return const NeverScrollableScrollPhysics();
  final parent = switch (n.prop(CollectionScrollProps.physics)) {
    ScrollPhysicsType.platform => null,
    ScrollPhysicsType.bouncing => const BouncingScrollPhysics(),
    ScrollPhysicsType.clamping => const ClampingScrollPhysics(),
    ScrollPhysicsType.rangeMaintaining => const RangeMaintainingScrollPhysics(),
    ScrollPhysicsType.never => const NeverScrollableScrollPhysics(),
  };
  if (alwaysScroll ?? n.prop(CollectionScrollProps.alwaysScroll)) return AlwaysScrollableScrollPhysics(parent: parent);
  return parent;
}

/// Places a list item as the editor lays it out:
/// at [main] along the list when set (a fixed item extent, or the design
/// extent of an item that fills), at the start of the list and centered
/// across it unless [stretch].
class ListItemBox extends StatelessWidget {
  const ListItemBox({super.key, required this.axis, this.main, this.stretch = false, required this.child});

  final Axis axis;
  final double? main;
  final bool stretch;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final vertical = axis == Axis.vertical;
    var result = child;
    if (main != null) result = SizedBox(width: vertical ? null : main, height: vertical ? main : null, child: result);
    if (stretch) return result;
    return Align(alignment: vertical ? Alignment.topCenter : Alignment.centerLeft, child: result);
  }
}

/// A list item's extent along the list, when the list sets it: its fixed
/// [itemExtent], or the design extent of an item that fills.
double? listItemMain(Node item, {required bool vertical, double? itemExtent}) {
  if (itemExtent != null) return itemExtent;
  final fit = vertical ? item.layout.height.fit : item.layout.width.fit;
  if (fit != SizeFit.fill && fit != SizeFit.flexible) return null;
  // An item that binds its size along the list (each item its own fit or
  // extent) is measured as it resolves, not given the template's.
  if (item.bind.containsKey(vertical ? 'layout.height' : 'layout.width')) return null;
  return vertical
      ? item.layout.height.value + item.layout.margin.vertical
      : item.layout.width.value + item.layout.margin.horizontal;
}

/// The extent every item of [list] takes along it, or null when items may differ and must be measured:
/// the list's `itemExtent`, else the template's outer extent when it isn't
/// hugged and nothing binds its size or visibility.
double? listItemExtent(Node list, Node item, {required bool vertical, double? itemExtent}) {
  if (itemExtent != null) return itemExtent;
  if (!item.visible) return null;
  final fit = vertical ? item.layout.height.fit : item.layout.width.fit;
  if (fit == SizeFit.hug) return null;
  const bound = {'visible', 'layout.width', 'layout.height', 'layout.aspectRatio', 'layout.margin', 'layout.padding'};
  if (item.bind.keys.any((k) => bound.contains(k) || k.startsWith('layout.constraints'))) return null;
  final extent = vertical
      ? item.layout.height.value + item.layout.margin.vertical
      : item.layout.width.value + item.layout.margin.horizontal;
  return extent.isFinite && extent > 0 ? extent : null;
}
