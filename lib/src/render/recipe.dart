// The API a widget recipe uses to build a node's render objects.
import 'package:codelessly_api/core.dart' show Node, SizeFit;
import 'package:codelessly_api/core.dart' as api show TextStyle;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'islands.dart';
import 'layout/fit_box.dart';
import 'node_tree.dart';
import 'source.dart';

/// Builds the content of a node of one widget type: appends render objects
/// to [chain], outermost first, below the outer layers (margin, constraints,
/// rotation, opacity) the tree already added. Recipes live in
/// lib/src/widgets, one file per widget group.
typedef WidgetRecipe = void Function(NodeBuilder b, Node n, List<RenderBox> chain);

/// The recipes a tree builds its nodes with, beyond the core layout types
/// (which the tree builds itself) and under the app's own
/// ([RenderTree.recipes]). The SDK's catalog is in lib/src/widgets.
@immutable
final class RecipeCatalog {
  const RecipeCatalog({this.recipes = const {}, this.inputs = const {}});

  /// No recipes: every other type draws as its box, at its size.
  static const RecipeCatalog none = RecipeCatalog();

  /// The recipe of each node type.
  final Map<String, WidgetRecipe> recipes;

  /// The types that are inputs: one the model lets carry a fill, border,
  /// shadow or padding (a dropdown, a date input) is drawn inside the
  /// node's shell.
  final Set<String> inputs;
}

/// What a [WidgetRecipe] builds with: the node's box in the tree.
abstract interface class NodeBuilder {
  RenderTree get tree;
  String get id;

  /// Repeated-template scope (a list item); null outside one.
  Object? get instance;

  /// How the parent lays this node out.
  Slot get slot;

  /// Another node of the document.
  Node? nodeOf(String id);

  /// The document this node is in: the tree's, or (inside a component
  /// instance) the definition's. What bindings resolve its ids with.
  NodeSource get source;

  /// The render object made under [key] on the last build if it has type
  /// T, else a new one: reuse keeps layout and paint state across edits.
  T obtain<T extends RenderBox>(String key, T Function() create);

  /// Sizes per the node's fits: fixed → [size], fill → the incoming max
  /// (else [size]), hug → the child's size.
  RenderFitBox fitBox(String key, SizeFit h, SizeFit v, Size size);

  /// The box shell: fit box, shadows, decoration, stroke, clip, padding,
  /// then [content] (null: a leaf box).
  void shell(Node n, List<RenderBox> chain, {void Function(List<RenderBox> inner)? content, bool padded = true});

  /// Row/column content of [n] (its flex props and children).
  void flex(Node n, List<RenderBox> chain);

  /// Freeform (stack) content: [children] (default the node's own) placed by
  /// their layout.x/y.
  void freeform(Node n, List<RenderBox> chain, {List<String>? children});

  /// Places the boxes of [ids] in [container], in order. [instance] scopes
  /// them (one box per id per instance: list items repeating a template);
  /// [instances], one per id, scopes each on its own (null: [instance]).
  void syncChildren(
    ContainerRenderObjectMixin<RenderBox, ContainerBoxParentData<RenderBox>> container,
    List<String> ids,
    Slot childSlot, {
    Object? instance,
    List<Object?>? instances,
  });

  /// A Flutter widget for (part of) this node, hosted as a render box
  /// ([key] distinguishes several per node). Rebuilt on every apply.
  RenderBox island(String key, WidgetBuilder build);
}

/// A widget showing node [id]'s box, inside an island (a button's label, a
/// list item's content): the island's widgets around, nodes inside. Like a
/// [NodeView], it owns the islands of the boxes it shows, so they inherit
/// from the island around.
class NodeChild extends RenderObjectWidget {
  const NodeChild({super.key, required this.tree, required this.id, this.slot = const Slot.root(), this.instance});

  final RenderTree tree;
  final String id;
  final Slot slot;
  final Object? instance;

  /// Its box, inheriting the default text style of the node whose island it
  /// is in ([TextDefaultScope]) unless [slot] gives one.
  NodeBox _box(BuildContext context) =>
      tree.obtain(id, slot.textDefault != null ? slot : slot.inheriting(TextDefaultScope.of(context)), instance: instance);

  @override
  IslandOwnerElement createElement() => IslandOwnerElement(this);

  @override
  RenderBox createRenderObject(BuildContext context) => _RenderNodeChild().._hold(_box(context));

  @override
  void updateRenderObject(BuildContext context, RenderBox renderObject) => (renderObject as _RenderNodeChild)._hold(_box(context));
}

/// The default text style of the node an island belongs to (its
/// `defaultTextStyle`, inherited: Flutter's `DefaultTextStyle`), for the
/// nodes the island shows again ([NodeChild]: a list's items, a button's
/// label).
class TextDefaultScope extends InheritedWidget {
  const TextDefaultScope({super.key, required this.style, required super.child});

  final api.TextStyle? style;

  static api.TextStyle? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<TextDefaultScope>()?.style;

  @override
  bool updateShouldNotify(TextDefaultScope oldWidget) => style != oldWidget.style;
}

/// Holds a node's box inside an island. The box belongs to the tree: it's
/// handed over (detached from a previous holder) and let go on dispose.
class _RenderNodeChild extends RenderProxyBox with RenderObjectWithLayoutCallbackMixin, IslandParent {
  void _hold(NodeBox box) {
    final old = child;
    if (identical(old, box)) return;
    if (box.parent != null) box.detachFromParent();
    child = box;
    if (old is NodeBox) old.tree.orphan(old);
  }

  @override
  void dispose() {
    final old = child;
    child = null;
    if (old is NodeBox) old.tree.orphan(old);
    super.dispose();
  }
}
