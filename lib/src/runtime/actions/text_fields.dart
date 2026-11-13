// The text fields a tree shows, by node: what focus, edit text and submit
// form actions reach. A text field island registers its controller and
// focus node on its node's box while it lives.
import 'package:flutter/widgets.dart';

import '../../render/node_tree.dart';
import '../../render/recipe.dart';
import '../expressions/bindings.dart' show ProvidedItem;

/// A text field's controller and focus node.
class TextFieldHandle {
  TextFieldHandle(this.controller, this.focusNode);

  final TextEditingController controller;
  final FocusNode focusNode;

  static final Expando<TextFieldHandle> _handles = Expando('TextFieldHandle');

  /// The field node [id] of [tree] shows (its first instance), if any.
  static TextFieldHandle? of(RenderTree tree, String id) {
    final box = tree.boxOf(id);
    return box == null ? null : _handles[box];
  }

  /// The field node [id] of [tree] shows nearest [instance] (the repeat of
  /// the node whose trigger fired): in the same list item, else one inside
  /// it or around it, else the first. A field in a kanban column's repeated
  /// quick add is the one of the column whose button was pressed.
  static TextFieldHandle? near(RenderTree tree, String id, Object? instance) {
    if (instance == null) return of(tree, id);
    bool within(Object? inner, Object? outer) {
      for (Object? i = inner; i != null; i = i is ProvidedItem ? i.outer : null) {
        if (i == outer) return true;
      }
      return false;
    }

    TextFieldHandle? related;
    for (final box in tree.boxesOf(id)) {
      final handle = _handles[box];
      if (handle == null) continue;
      if (box.instance == instance) return handle;
      if (related == null && (within(box.instance, instance) || within(instance, box.instance))) related = handle;
    }
    return related ?? of(tree, id);
  }

  static void register(NodeBuilder box, TextFieldHandle handle) => _handles[box] = handle;

  static void unregister(NodeBuilder box, TextEditingController controller) {
    if (identical(_handles[box]?.controller, controller)) _handles[box] = null;
  }

  /// Takes the focus from every text field.
  static void unfocusAll() => FocusManager.instance.primaryFocus?.unfocus();
}

/// [box]'s tree's text field handle (for tests and tools).
TextFieldHandle? textFieldOf(NodeBox box) => TextFieldHandle.of(box.tree, box.id);
