// The API a widget recipe uses to build a node's render objects.
import 'package:codelessly_api/codelessly_api.dart' show Node, SizeFit;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'layout/fit_box.dart';
import 'node_tree.dart';

/// Builds the content of a node of one widget type: appends render objects
/// to [chain], outermost first, below the outer layers (margin, constraints,
/// rotation, opacity) the tree already added. Recipes live in
/// lib/src/widgets, one file per widget group.
typedef WidgetRecipe = void Function(NodeBuilder b, Node n, List<RenderBox> chain);

/// What a [WidgetRecipe] builds with: the node's box in the tree.
abstract interface class NodeBuilder {
  NodeTree get tree;
  String get id;

  /// Repeated-template scope (a list item); null outside one.
  Object? get instance;

  /// How the parent lays this node out.
  Slot get slot;

  /// Another node of the document.
  Node? nodeOf(String id);

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
  /// them (one box per id per instance: list items repeating a template).
  void syncChildren(
    ContainerRenderObjectMixin<RenderBox, ContainerBoxParentData<RenderBox>> container,
    List<String> ids,
    Slot childSlot, {
    Object? instance,
  });

  /// A Flutter widget for (part of) this node, hosted as a render box
  /// ([key] distinguishes several per node). Rebuilt on every apply.
  RenderBox island(String key, WidgetBuilder build);
}

/// A widget showing node [id]'s box, inside an island (a button's label, a
/// list item's content): the island's widgets around, nodes inside.
class NodeChild extends LeafRenderObjectWidget {
  const NodeChild({super.key, required this.tree, required this.id, this.slot = const Slot.root(), this.instance});

  final NodeTree tree;
  final String id;
  final Slot slot;
  final Object? instance;

  NodeBox _box() {
    final box = tree.obtain(id, slot, instance: instance);
    return box;
  }

  @override
  RenderBox createRenderObject(BuildContext context) => _RenderNodeChild().._hold(_box());

  @override
  void updateRenderObject(BuildContext context, _RenderNodeChild renderObject) => renderObject._hold(_box());
}

/// Holds a node's box inside an island. The box belongs to the tree: it's
/// handed over (detached from a previous holder) and let go on dispose.
class _RenderNodeChild extends RenderProxyBox {
  void _hold(NodeBox box) {
    if (identical(child, box)) return;
    if (box.parent != null) box.detachFromParent();
    child = box;
  }

  @override
  void dispose() {
    child = null;
    super.dispose();
  }
}
