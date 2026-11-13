// What the render core needs from the layers above it, as interfaces it
// owns. The render core draws nodes; values, variables, reactions, gestures
// that act on data and the network belong to the runtime, which implements
// these and hands them to the tree ([RenderTree]):
//
// * [TreeBindings]: each node as shown (bound values applied), and the
//   values a node's render objects read, write and publish ([BoundValues]).
//   The runtime's `NodeBinder` is one.
// * [NodeGestures]: the gesture layers that act on data (a node that
//   follows the pointer, drag and drop).
// * [ImageBytesLoader]: fetches the images Flutter's image cache doesn't.
//
// `NodeInteractions` (node_tree.dart) is the fourth: a running app's
// reactions.
import 'package:codelessly_api/core.dart' show Node, WidgetState;
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart' show RenderBox;

import 'node_tree.dart' show NodeBox;
import 'source.dart';

/// A node as shown: its bound values applied.
@immutable
final class BoundNode {
  const BoundNode(this.node, {this.collapsed = false, this.watch = const [], this.states = const {}});

  final Node node;

  /// Interaction states its bindings or conditions turn on or off
  /// (`selected`, `disabled`); the node tree holds them as it holds hover.
  final Map<WidgetState, bool> states;

  /// Hidden by a binding or condition: takes no space (Flutter's
  /// `Visibility` without `maintainSize`). A node hidden in its own data
  /// keeps its space.
  final bool collapsed;

  /// What tells the node it may show differently: one per name it read.
  final List<Listenable> watch;
}

/// Gives a tree each node as shown, and its render objects the values they
/// read and write. Without one a tree renders its nodes as stored.
abstract interface class TreeBindings {
  /// [node] (in repeat [instance]) as shown.
  BoundNode bind(NodeSource source, Node node, Object? instance);

  /// Whether names can be read at all (there are values to read them from).
  bool get hasValues;

  /// The values node [id] (in [instance]) reads and writes: the variables
  /// around it, its list item; null when there are none.
  BoundValues? valuesFor(NodeSource source, String id, Object? instance);

  /// Sets [name] (`track`, `flip`, `tilt`, `transform`, `sticky`, `view`)
  /// of the names node [id] (in [instance]) gives the nodes inside it, to
  /// what its render objects show now. Nothing when the node gives none.
  void publish(NodeSource source, String id, Object? instance, String name, Object? value);
}

/// [TreeBindings] that keep state per component instance (its scopes): told
/// when an instance leaves the tree, so they let go of it.
abstract interface class InstanceBindings {
  /// Component instance [instance] (and every instance nested in it) left
  /// the tree: release what was kept for it.
  void releaseInstance(Object instance);
}

/// The values one node reads and writes, by name or path (`volume`,
/// `item.price`, `draft.title`).
abstract interface class BoundValues {
  /// The value at [path], or null.
  Object? read(String path);

  /// What tells that the value at [path] changed (the same object each
  /// time, for the same name), or null when nothing declares its name.
  Listenable? watch(String path);

  /// The variable [path]'s name declares, or null when it's none (a list
  /// item, an undeclared name).
  BoundVariable? variable(String path);

  /// Sets [path] in the variable that declares it; whether one changed.
  bool write(String path, Object? value);

  /// [text] with every `${...}` replaced by its value's text.
  String interpolate(String text);
}

/// [BoundValues] that also work out expressions with names of the
/// caller's own over the node's: a draw list's `item`, `index` and `size`
/// (render/custom_paint.dart). The runtime's values are these.
abstract interface class ExpressionValues implements BoundValues {
  /// The value of [expression] (`${path}`, `${= formula}`, or text holding
  /// them), [locals] read before the node's names.
  Object? evaluate(String expression, [Map<String, Object?> locals = const {}]);

  /// The root names [expression] reads (`cells` for `${cells[index]}`).
  Set<String> namesRead(String expression);
}

/// A variable a node's render objects write.
abstract interface class BoundVariable {
  /// Worked out from a formula: it can't be written.
  bool get isComputed;

  /// Holds whole numbers.
  bool get isInteger;

  /// Holds an animation playing the variable where it is (a drag takes
  /// over).
  void pauseAnimation();
}

/// The gesture layers the runtime adds to a node's box: gestures that move
/// data (a dragged node's `drag` values, a drop's reactions), not only
/// pixels. Given to a tree ([RenderTree.gestures]).
abstract interface class NodeGestures {
  /// Adds the layer of a node that follows the pointer to [chain],
  /// outermost (it moves with its margin).
  void addMotionLayers(NodeBox box, Node n, List<RenderBox> chain);

  /// Adds [n]'s drag and drop layers (a drag source, a drop target) to
  /// [chain], between its rotation and its reactions.
  void addDragAndDropLayers(NodeBox box, Node n, List<RenderBox> chain);
}

/// A layer drawn away from where its node is laid out (a node that follows
/// the pointer): the node's box hit tests it wherever it is, not only
/// inside the box's own bounds.
abstract interface class HitTestedWhereDrawn {}

/// Fetches the bytes of the image at a URL, for what Flutter's image cache
/// doesn't load (SVG documents). Throws when it can't.
abstract interface class ImageBytesLoader {
  Future<Uint8List> load(String url);
}
