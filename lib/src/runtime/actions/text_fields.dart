// The text fields a tree shows, by node: what focus, edit text and submit
// form actions reach. A text field island registers its controller and
// focus node on its node's box while it lives.
import 'package:flutter/widgets.dart';

import '../../render/node_tree.dart';
import '../../render/recipe.dart';

/// A text field's controller and focus node.
class TextFieldHandle {
  TextFieldHandle(this.controller, this.focusNode);

  final TextEditingController controller;
  final FocusNode focusNode;

  static final Expando<TextFieldHandle> _handles = Expando('TextFieldHandle');

  /// The field node [id] of [tree] shows (its first instance), if any.
  static TextFieldHandle? of(NodeTree tree, String id) {
    final box = tree.boxOf(id);
    return box == null ? null : _handles[box];
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
